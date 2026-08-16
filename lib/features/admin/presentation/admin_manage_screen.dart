import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/models/route_model.dart';
import '../../search/data/route_repository.dart';
import 'add_stop_screen.dart';

/// The list of every stop (active and inactive), with a button to edit
/// it, a switch to toggle isActive, and a button for a real, permanent
/// delete. This widget has no Scaffold or AppBar of its own — it is
/// embedded directly inside the Admin sidebar shell's content area.
class StopsManageList extends StatefulWidget {
  const StopsManageList({super.key});

  @override
  State<StopsManageList> createState() => _StopsManageListState();
}

class _StopsManageListState extends State<StopsManageList> {
  final _repository = RouteRepository();
  late Future<List<StopModel>> _stopsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _stopsFuture = _repository.getAllStopsForAdmin();
    });
  }

  /// Opens the stop form in EDIT mode. AddStopScreen pops with `true`
  /// only when a save actually succeeded, so we reload the list only
  /// then — cancelling or backing out leaves the list untouched.
  Future<void> _edit(StopModel stop) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddStopScreen(existingStop: stop),
      ),
    );
    if (saved == true) {
      _reload();
    }
  }

  Future<void> _toggle(StopModel stop, bool value) async {
    try {
      await _repository.setStopActive(stop.id, value);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(StopModel stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this stop?'),
        content: Text(
          '"${stop.name}" will be permanently deleted. This cannot be '
              'undone. Any route that still refers to this stop by ID will '
              'keep that reference — deleting a stop does not update routes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteStop(stop.id);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${stop.name}" deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StopModel>>(
      future: _stopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Could not load stops. Check your connection.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }

        final stops = snapshot.data ?? [];
        if (stops.isEmpty) {
          return const Center(
            child: Text(
              'No stops yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: stops.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final stop = stops[index];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  stop.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  stop.area,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Edit stop',
                      onPressed: () => _edit(stop),
                    ),
                    Switch(
                      value: stop.isActive,
                      activeThumbColor: AppColors.accent,
                      onChanged: (value) => _toggle(stop, value),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete stop',
                      onPressed: () => _confirmDelete(stop),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The list of every route (active and inactive), with a switch to
/// toggle isActive and a button for a real, permanent delete. Same
/// embedding rule as StopsManageList — no Scaffold/AppBar here.
class RoutesManageList extends StatefulWidget {
  const RoutesManageList({super.key});

  @override
  State<RoutesManageList> createState() => _RoutesManageListState();
}

class _RoutesManageListState extends State<RoutesManageList> {
  final _repository = RouteRepository();
  late Future<List<RouteModel>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _routesFuture = _repository.getAllRoutesForAdmin();
    });
  }

  Future<void> _toggle(RouteModel route, bool value) async {
    try {
      await _repository.setRouteActive(route.id, value);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(RouteModel route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this route?'),
        content: Text(
          '"${route.routeName}" will be permanently deleted. This '
              'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteRoute(route.id);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${route.routeName}" deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteModel>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Could not load routes. Check your connection.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }

        final routes = snapshot.data ?? [];
        if (routes.isEmpty) {
          return const Center(
            child: Text(
              'No routes yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: routes.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final route = routes[index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.routeName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${route.priceJD.toStringAsFixed(2)} JD'
                              ' \u00B7 ${route.durationMinutes} min',
                          style: AppTextStyles.monoData(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: route.isActive,
                    activeThumbColor: AppColors.accent,
                    onChanged: (value) => _toggle(route, value),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    tooltip: 'Delete route',
                    onPressed: () => _confirmDelete(route),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}