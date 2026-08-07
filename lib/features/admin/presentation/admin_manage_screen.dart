import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../search/data/route_repository.dart';

/// Admin screen for viewing and toggling every Stop and Route,
/// including inactive ones. This is the ONLY screen in the app that
/// can see inactive documents — student-facing search always filters
/// isActive: true.
class AdminManageScreen extends StatelessWidget {
  const AdminManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          title: const Text('Manage Stops & Routes'),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Stops'),
              Tab(text: 'Routes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StopsTab(),
            _RoutesTab(),
          ],
        ),
      ),
    );
  }
}

class _StopsTab extends StatefulWidget {
  const _StopsTab();

  @override
  State<_StopsTab> createState() => _StopsTabState();
}

class _StopsTabState extends State<_StopsTab> {
  final _repository = RouteRepository();
  late Future<List<StopModel>> _stopsFuture;

  @override
  void initState() {
    super.initState();
    _stopsFuture = _repository.getAllStopsForAdmin();
  }

  void _reload() {
    setState(() {
      _stopsFuture = _repository.getAllStopsForAdmin();
    });
  }

  Future<void> _toggle(StopModel stop, bool value) async {
    try {
      await _repository.setStopActive(stop.id, value);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StopModel>>(
      future: _stopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
                const SizedBox(height: AppSpacing.sm),
                const Text('Could not load stops.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final stops = snapshot.data ?? [];
        if (stops.isEmpty) {
          return const Center(
              child: Text('No stops yet.',
                  style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: stops.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 20),
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
                trailing: Switch(
                  value: stop.isActive,
                  activeColor: AppColors.accent,
                  onChanged: (value) => _toggle(stop, value),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RoutesTab extends StatefulWidget {
  const _RoutesTab();

  @override
  State<_RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<_RoutesTab> {
  final _repository = RouteRepository();
  late Future<List<RouteModel>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getAllRoutesForAdmin();
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
        const SnackBar(content: Text('Could not update. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteModel>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
                const SizedBox(height: AppSpacing.sm),
                const Text('Could not load routes.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final routes = snapshot.data ?? [];
        if (routes.isEmpty) {
          return const Center(
              child: Text('No routes yet.',
                  style: TextStyle(color: AppColors.textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: routes.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final route = routes[index];
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
                  child: const Icon(Icons.route,
                      color: Colors.white, size: 20),
                ),
                title: Text(
                  route.routeName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  route.originStopName + ' -> ' + route.destinationStopName,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Switch(
                  value: route.isActive,
                  activeColor: AppColors.accent,
                  onChanged: (value) => _toggle(route, value),
                ),
              ),
            );
          },
        );
      },
    );
  }
}