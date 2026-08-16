import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_manage_screen.dart';
import 'admin_login_screen.dart';

/// Landing screen after a successful admin sign-in.
///
/// Rebuilt to match spec v8.7 pages 17 and 18: a persistent navy
/// sidebar holding exactly three items — Routes, Stops, Sign out —
/// beside a content area that swaps in place.
///
/// The "Overview" section was removed (decision D4, 2026-08-16): it
/// does not exist in the approved design. The two quick-add actions it
/// carried now live as "+ Add route" and "+ Add stop" buttons in the
/// headers of their own lists, which is where the spec puts "+ Add
/// route" on page 17.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _AdminSection { routes, stops }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Routes first, matching the spec, where Routes is the selected
  // item on the first admin page.
  _AdminSection _section = _AdminSection.routes;
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to manage stops and routes.',
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

    setState(() => _isSigningOut = true);
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              selected: _section,
              isSigningOut: _isSigningOut,
              onSelect: (section) => setState(() => _section = section),
              onSignOut: _signOut,
            ),
            Expanded(
              child: _section == _AdminSection.routes
                  ? const RoutesManageList()
                  : const StopsManageList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The persistent left navigation column.
///
/// Text-only, no icons: the approved design shows plain labels, and
/// the selected item is marked by a lighter panel behind the text.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.isSigningOut,
    required this.onSelect,
    required this.onSignOut,
  });

  final _AdminSection selected;
  final bool isSigningOut;
  final ValueChanged<_AdminSection> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              'Coasterna admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SidebarItem(
            label: 'Routes',
            isSelected: selected == _AdminSection.routes,
            onTap: () => onSelect(_AdminSection.routes),
          ),
          _SidebarItem(
            label: 'Stops',
            isSelected: selected == _AdminSection.stops,
            onTap: () => onSelect(_AdminSection.stops),
          ),
          const SizedBox(height: AppSpacing.md),
          _SidebarItem(
            label: isSigningOut ? 'Signing out...' : 'Sign out',
            isSelected: false,
            onTap: isSigningOut ? null : onSignOut,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Container(
            // Spec: minimum touch target 48 x 48.
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}