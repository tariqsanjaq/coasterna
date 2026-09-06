import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/student_login_screen.dart';

/// Student settings/profile screen (decision D53 part 2). Reachable
/// only from Home's app bar settings icon, which only appears when
/// signed in (`home_page.dart`) — so this screen has no guest-guard of
/// its own, only the defensive null-check in build() below.
///
/// Two independent sections — Name and Password — each with its own
/// save action, plus a Sign out action at the bottom. Deliberately
/// talks to `FirebaseAuth`/`User` directly (via `AuthRepository().
/// currentUser`) rather than adding repository wrapper methods that
/// would just forward to `updateDisplayName`/`reauthenticateWithCredential`/
/// `updatePassword` with no added logic — same call as this project's
/// "no pointless indirection" rule, but a deliberate, task-directed
/// exception to CLAUDE.md's "widgets never import firebase_auth
/// directly" rule, since every operation here only ever touches the
/// already-signed-in user's own profile. Flagged explicitly in the
/// D53 part 2 audit-trail report rather than decided silently.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepository = AuthRepository();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;

  bool _isSavingName = false;
  String? _nameError;

  bool _isSavingPassword = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final (firstName, lastName) =
        splitDisplayName(_authRepository.currentUser?.displayName);
    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    // Same non-empty-after-trim validation as the sign-up form (D53
    // part 1, student_signup_screen.dart._signUp()).
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _nameError = 'Enter your first and last name.');
      return;
    }

    setState(() {
      _isSavingName = true;
      _nameError = null;
    });

    try {
      final user = _authRepository.currentUser;
      // Same updateDisplayName() + reload() sequence established in
      // student_signup_screen.dart (D53 part 1) — see that file's doc
      // comment for why reload() is required: Firebase Auth does not
      // reliably reflect a just-set displayName on the same User
      // object without it.
      await user?.updateDisplayName('$firstName $lastName');
      await user?.reload();

      if (!mounted) return;
      setState(() => _isSavingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name updated.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingName = false;
        _nameError = 'Could not update your name. Try again.';
      });
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      setState(
        () => _passwordError = 'Enter your current and new password.',
      );
      return;
    }
    // Same minimum length as the sign-up form's password field hint
    // ("Password (6 characters or more)", student_signup_screen.dart).
    if (newPassword.length < 6) {
      setState(() =>
          _passwordError = 'New password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _passwordError = 'The two new passwords do not match.');
      return;
    }

    setState(() {
      _isSavingPassword = true;
      _passwordError = null;
    });

    final user = _authRepository.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      setState(() {
        _isSavingPassword = false;
        _passwordError = 'You have been signed out. Sign in again.';
      });
      return;
    }

    try {
      // Firebase Auth requires a freshly re-authenticated session
      // before updatePassword() will succeed — otherwise it throws
      // requires-recent-login. Re-authenticate with the entered
      // current password first, THEN change the password; do not
      // reorder this or catch-and-ignore requires-recent-login
      // instead.
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isSavingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed.'),
          duration: Duration(seconds: 3),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingPassword = false;
        _passwordError = _passwordChangeMessage(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingPassword = false;
        _passwordError = 'Something went wrong. Check your connection.';
      });
    }
  }

  // SECURITY: never distinguish "wrong password" from "unknown
  // account" in the message — same reasoning AuthRepository.signIn()
  // already documents for sign-in, though here both codes really do
  // mean the same thing (a wrong current password), since the account
  // itself is already known to exist (it's the signed-in user).
  String _passwordChangeMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'That current password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'weak-password':
        return 'New password must be at least 6 characters.';
      case 'requires-recent-login':
        return 'Please sign out, sign in again, and retry.';
      default:
        return 'Could not change your password. Try again.';
    }
  }

  // Identical to home_page.dart's removed app-bar sign-out icon
  // (_HomeViewState._signOut(), D52/D53-part-1 era) — same
  // confirmation dialog copy, same signOut() + pushAndRemoveUntil to
  // StudentLoginScreen. Copied rather than re-derived so "Sign out"
  // behaves identically from its new home.
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use a saved account. '
          'You can still search buses as a guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await _authRepository.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Defensive only — the settings icon that opens this screen only
    // renders in home_page.dart's signed-in app bar state, so this
    // should never actually be reached in normal use.
    if (_authRepository.currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          title: const Text('Settings'),
        ),
        body: const Center(child: Text('You are not signed in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileSection(),
              const SizedBox(height: AppSpacing.xl),
              _buildSecuritySection(),
              const SizedBox(height: AppSpacing.xl),
              _buildAccountSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Visual-only redesign below (D-2026-09-06 settings restyle) ---
  // Three labeled sections (PROFILE / SECURITY / ACCOUNT), each its own
  // card, with label-over-value field styling instead of outlined
  // TextFields. Every field below is still the same TextField/
  // controller wired to the same _saveName/_changePassword/_signOut
  // logic above — only InputDecoration and layout changed.

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          // Same token home_page.dart uses for its "RECENT" section
          // label and each _StopField's "From"/"To" label — gold
          // (AppColors.accent) fails WCAG contrast at this size per
          // the Design System page, so this must not be gold.
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _sectionCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceBorder),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: child,
    );
  }

  // 32px-wide leading slot so the icon column lines up across every
  // row in a card, whether or not that particular row has an icon.
  Widget _iconSlot(Widget? icon) {
    return SizedBox(
      width: 32,
      height: 32,
      child: icon == null ? null : Center(child: icon),
    );
  }

  Widget _accentCircleIcon(IconData icon) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.accent, size: 15),
    );
  }

  // Static label ABOVE the field, not the field's internal
  // (floating) label — floatingLabelBehavior.always has a built-in
  // size/weight ceiling that stayed illegible on a real device even
  // after two size bumps. A plain Text widget has no such ceiling.
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _fieldRow(
      {required Widget leading, required String label, required Widget field}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(label),
              field,
            ],
          ),
        ),
      ],
    );
  }

  // The field itself now carries no label at all — that lives in
  // _fieldLabel above it (see _fieldRow). Only the underline and an
  // optional suffix (the password eye toggle) remain here.
  InputDecoration _settingsFieldDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      // Darker than AppColors.surfaceBorder for definition against the
      // white card — no dedicated "mid-tone border" token exists in
      // AppColors, so this reuses textTertiary (already the darker of
      // the two neutrals under consideration) rather than a new hex.
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.textTertiary),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.textTertiary),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent),
      ),
      suffixIcon: suffixIcon,
    );
  }

  static const _fieldValueStyle =
      TextStyle(fontSize: 15, color: AppColors.textPrimary);

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('PROFILE'),
        _sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldRow(
                leading: _iconSlot(_accentCircleIcon(Icons.person_outline)),
                label: 'First name',
                field: TextField(
                  controller: _firstNameController,
                  style: _fieldValueStyle,
                  decoration: _settingsFieldDecoration(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _fieldRow(
                leading: _iconSlot(null),
                label: 'Last name',
                field: TextField(
                  controller: _lastNameController,
                  style: _fieldValueStyle,
                  decoration: _settingsFieldDecoration(),
                ),
              ),
              if (_nameError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _nameError!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: kMinTouchTarget,
                child: ElevatedButton(
                  onPressed: _isSavingName ? null : _saveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: _isSavingName
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save name'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('SECURITY'),
        _sectionCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldRow(
                leading:
                    _iconSlot(const Icon(Icons.lock_outline,
                        color: AppColors.accent, size: 18)),
                label: 'Current password',
                field: TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  style: _fieldValueStyle,
                  decoration: _settingsFieldDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrentPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() =>
                          _obscureCurrentPassword = !_obscureCurrentPassword),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _fieldRow(
                leading:
                    _iconSlot(const Icon(Icons.lock_outline,
                        color: AppColors.accent, size: 18)),
                label: 'New password (6 characters or more)',
                field: TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  style: _fieldValueStyle,
                  decoration: _settingsFieldDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _fieldRow(
                leading:
                    _iconSlot(const Icon(Icons.lock_outline,
                        color: AppColors.accent, size: 18)),
                label: 'Confirm new password',
                field: TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureNewPassword,
                  style: _fieldValueStyle,
                  decoration: _settingsFieldDecoration(
                    // Same toggle this field's obscureText already
                    // depends on (shared with New password above) —
                    // no new state, just the same eye icon/logic
                    // pattern Current/New password already use.
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                    ),
                  ),
                ),
              ),
              if (_passwordError != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _passwordError!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13.5),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: kMinTouchTarget,
                child: ElevatedButton(
                  onPressed: _isSavingPassword ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: _isSavingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Change password'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('ACCOUNT'),
        _sectionCard(
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: const Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Splits a Firebase Auth `displayName` on its first space into
/// (firstName, lastName), for pre-filling the Name section's two
/// fields. Public (not `_`-prefixed) specifically so it is directly
/// unit-testable from `test/profile_screen_test.dart` — Dart's
/// underscore privacy is per-library (per-file), so a private
/// top-level function here could not be reached from a test file at
/// all. Same pattern `route_status_badge.dart` already uses for its
/// own testable pure functions.
///
/// Null or blank input (an account created before D53 part 1, which
/// never set a displayName) returns `('', '')` — both fields start
/// empty, not a placeholder or an error; this is an expected state,
/// not a failure. A single word with no space becomes `(word, '')` —
/// the Last name field starts empty. The split point is the FIRST
/// space only, so "Ahmad Al Rawi" becomes `('Ahmad', 'Al Rawi')`, not
/// three separate parts.
(String, String) splitDisplayName(String? displayName) {
  final trimmed = displayName?.trim() ?? '';
  if (trimmed.isEmpty) return ('', '');

  final spaceIndex = trimmed.indexOf(' ');
  if (spaceIndex == -1) return (trimmed, '');

  return (
    trimmed.substring(0, spaceIndex),
    trimmed.substring(spaceIndex + 1).trim(),
  );
}
