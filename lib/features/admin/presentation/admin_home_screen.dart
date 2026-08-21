import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/models/route_model.dart';
import 'admin_manage_screen.dart';
import 'admin_login_screen.dart';
import 'add_stop_screen.dart';
import 'add_route_screen.dart';

/// Landing screen after a successful admin sign-in.
///
/// Built to spec v8.7 pages 17, 18 and 19: a persistent navy sidebar
/// holding exactly three items — Routes, Stops, Sign out — beside a
/// content area that swaps in place.
///
/// The forms are panels inside that content area, not separate
/// screens, which is why the sidebar stays visible while a route or a
/// stop is being entered. This screen owns which panel is showing;
/// the lists and the forms only report events back to it.
///
/// "Overview" was removed (decision D4, 2026-08-16): it does not exist
/// in the approved design. Its two quick-add actions became the
/// "+ Add route" and "+ Add stop" buttons in the list headers.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

/// Which sidebar item is selected.
enum _AdminSection { routes, stops }

/// What the content area is showing right now.
enum _AdminView { list, stopForm, routeForm }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Routes first, matching the spec, where Routes is the selected item
  // on the first admin page.
  _AdminSection _section = _AdminSection.routes;
  _AdminView _view = _AdminView.list;

  /// The stop being edited. null in add mode.
  StopModel? _editingStop;

  /// The route being edited. null in add mode. Both forms follow the
  /// same shape: one widget, one nullable "existing" object, and this
  /// screen deciding which mode it opens in.
  RouteModel? _editingRoute;

  /// Bumped after every successful save. It goes into the list's key,
  /// which makes Flutter build a brand-new list State — so initState
  /// runs again and the data is re-fetched. Without this the list
  /// would come back holding the Future it resolved before the edit,
  /// and the row would still show the old values.
  int _reloadToken = 0;

  bool _isSigningOut = false;

  void _openStopForm({StopModel? stop}) {
    setState(() {
      _editingStop = stop;
      _view = _AdminView.stopForm;
    });
  }

  void _openRouteForm({RouteModel? route}) {
    setState(() {
      _editingRoute = route;
      _view = _AdminView.routeForm;
    });
  }

  /// Back to the list. [reload] is true only after a successful save.
  void _closeForm({required bool reload}) {
    setState(() {
      _view = _AdminView.list;
      _editingStop = null;
      _editingRoute = null;
      if (reload) _reloadToken++;
    });
  }

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
              // Changing section always leaves an open form. Keeping a
              // half-typed form alive behind a sidebar click would let
              // the admin lose work without ever being asked.
              onSelect: (section) => setState(() {
                _section = section;
                _view = _AdminView.list;
                _editingStop = null;
                _editingRoute = null;
              }),
              onSignOut: _signOut,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_view) {
      case _AdminView.stopForm:
        return StopFormPanel(
          existingStop: _editingStop,
          onSaved: () => _closeForm(reload: true),
          onCancel: () => _closeForm(reload: false),
        );
      case _AdminView.routeForm:
        return RouteFormPanel(
          // A ValueKey on the route id forces a fresh State when the
          // admin closes one route and opens another. Without it the
          // panel would keep the first route's controllers, and the
          // second route would open showing the first one's values.
          key: ValueKey('route-form-${_editingRoute?.id ?? 'new'}'),
          existingRoute: _editingRoute,
          onSaved: () => _closeForm(reload: true),
          onCancel: () => _closeForm(reload: false),
        );
      case _AdminView.list:
        if (_section == _AdminSection.routes) {
          return RoutesManageList(
            key: ValueKey('routes-$_reloadToken'),
            onAddRoute: () => _openRouteForm(),
            onEditRoute: (route) => _openRouteForm(route: route),
          );
        }
        return StopsManageList(
          key: ValueKey('stops-$_reloadToken'),
          onAddStop: () => _openStopForm(),
          onEditStop: (stop) => _openStopForm(stop: stop),
        );
    }
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
            // Spec page 3: minimum touch target 48 x 48.
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
