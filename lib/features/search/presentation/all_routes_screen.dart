import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';

/// Browse screen — lists every active route without requiring the
/// student to pick a "From" stop first. Reached from Home via the
/// "Browse all routes" button.
///
/// NOTE: unlike the search results screen, these cards do NOT have a
/// map link. RouteModel does not store the origin stop's
/// latitude/longitude (only StopModel does), so opening Google Maps
/// from here would need an extra Firestore read per route. Left out
/// deliberately to keep this screen simple — a known simplification,
/// not a bug.
class AllRoutesScreen extends StatefulWidget {
  const AllRoutesScreen({super.key, required this.repository});

  final RouteRepository repository;

  @override
  State<AllRoutesScreen> createState() => _AllRoutesScreenState();
}

enum _LoadState { loading, loaded, empty, error }

class _AllRoutesScreenState extends State<AllRoutesScreen> {
  _LoadState _state = _LoadState.loading;
  List<RouteModel> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _state = _LoadState.loading);
    try {
      final routes = await widget.repository.getAllActiveRoutes();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _state = routes.isEmpty ? _LoadState.empty : _LoadState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        title: const Text('All routes'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
            child: CircularProgressIndicator(color: AppColors.primary));
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.sm),
              const Text('Could not load routes. Check your connection.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _loadRoutes, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.empty:
        return const Center(
          child: Text('No routes yet.',
              style: TextStyle(color: AppColors.textSecondary)),
        );
      case _LoadState.loaded:
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _routes.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final route = _routes[index];
            return Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.routeName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      '${route.originStopName} -> ${route.destinationStopName}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        route.departureType == DepartureType.scheduled
                            ? '${route.firstDeparture} - ${route.lastDeparture}'
                            : 'Departs when full',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        '${route.priceJD.toStringAsFixed(2)} JD',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
    }
  }
}