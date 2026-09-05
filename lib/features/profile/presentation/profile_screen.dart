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
        const SnackBar(content: Text('Name updated.')),
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
        const SnackBar(content: Text('Password changed.')),
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
              _buildNameSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildPasswordSection(),
              const SizedBox(height: AppSpacing.lg),
              _buildSignOutSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Name',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              hintText: 'First name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              hintText: 'Last name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          if (_nameError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _nameError!,
              style: const TextStyle(color: AppColors.error, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSavingName ? null : _saveName,
            child: _isSavingName
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save name'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Password',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrentPassword,
            decoration: InputDecoration(
              hintText: 'Current password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrentPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              hintText: 'New password (6 characters or more)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureNewPassword,
            decoration: const InputDecoration(
              hintText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_passwordError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _passwordError!,
              style: const TextStyle(color: AppColors.error, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSavingPassword ? null : _changePassword,
            child: _isSavingPassword
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Change password'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutSection() {
    return SizedBox(
      width: double.infinity,
      height: kMinTouchTarget,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, color: AppColors.error),
        label:
            const Text('Sign out', style: TextStyle(color: AppColors.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
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
