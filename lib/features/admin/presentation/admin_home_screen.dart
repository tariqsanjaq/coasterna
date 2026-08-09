import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import 'add_stop_screen.dart';
import 'add_route_screen.dart';
import 'admin_manage_screen.dart';
import 'admin_login_screen.dart';

/// Landing screen after a successful admin sign-in. Rebuilt (Task #8)
/// as a persistent left sidebar plus a content area that swaps
/// in-place, matching the desktop admin-dashboard layout in the
/// approved design — replacing the earlier version, which was just
/// three stacked buttons and did not match the spec at all.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _AdminSection { overview, stops, routes }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  _AdminSection _section = _AdminSection.overview;
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    // Same confirm-before-irreversible-action pattern as the delete
    // dialogs in admin_manage_screen.dart — signing out isn't
    // destructive to data, but it does drop the admin back to the
    // login screen, which is disruptive enough mid-task to deserve
    // one extra tap rather than firing on a single misclick.
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
          children: [
            _Sidebar(
              selected: _section,
              isSigningOut: _isSigningOut,
              onSelect: (section) => setState(() => _section = section),
              onSignOut: _signOut,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _AdminSection.overview:
        return _OverviewContent(
          onAddStop: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddStopScreen()),
          ),
          onAddRoute: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddRouteScreen()),
          ),
        );
      case _AdminSection.stops:
        return const _ContentPage(
          title: 'Manage Stops',
          child: StopsManageList(),
        );
      case _AdminSection.routes:
        return const _ContentPage(
          title: 'Manage Routes',
          child: RoutesManageList(),
        );
    }
  }
}

/// The persistent left navigation column. Stays on screen for every
/// section — only the content area to its right changes — which is
/// the specific behaviour the Design Fidelity Audit flagged as
/// missing from the original three-button version.
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Coasterna Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Overview',
            isSelected: selected == _AdminSection.overview,
            onTap: () => onSelect(_AdminSection.overview),
          ),
          _SidebarItem(
            icon: Icons.location_on_outlined,
            label: 'Stops',
            isSelected: selected == _AdminSection.stops,
            onTap: () => onSelect(_AdminSection.stops),
          ),
          _SidebarItem(
            icon: Icons.route_outlined,
            label: 'Routes',
            isSelected: selected == _AdminSection.routes,
            onTap: () => onSelect(_AdminSection.routes),
          ),
          const Spacer(),
          const Divider(color: Colors.white24, height: 1),
          _SidebarItem(
            icon: Icons.logout,
            label: isSigningOut ? 'Signing out...' : 'Sign out',
            isSelected: false,
            onTap: isSigningOut ? null : onSignOut,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.accent : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Overview section: a short welcome plus the two quick-add
/// actions that used to be the entire home screen.
class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.onAddStop,
    required this.onAddRoute,
  });

  final VoidCallback onAddStop;
  final VoidCallback onAddRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _QuickActionCard(
                icon: Icons.add_location_alt_outlined,
                label: 'Add Stop',
                onTap: onAddStop,
              ),
              _QuickActionCard(
                icon: Icons.route_outlined,
                label: 'Add Route',
                onTap: onAddRoute,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple heading + body wrapper shared by the Stops and Routes
/// sections so both use the same header style without repeating it.
class _ContentPage extends StatelessWidget {
  const _ContentPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}