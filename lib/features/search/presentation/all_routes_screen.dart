import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/offline_banner.dart';
import '../data/route_repository.dart';
import '../../trip/presentation/trip_details_screen.dart';

/// Browse screen — lists every active route without requiring the
/// student to pick a "From" stop first. Reached from Home via the
/// "Browse all routes" button.
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
  bool _isOffline = false;

  /// Active stops keyed by document id, so tapping a route card can
  /// hand TripDetailsScreen the origin StopModel — and with it the
  /// real latitude/longitude the Google Maps link needs. Loaded once
  /// alongside the routes, using the repository's existing
  /// getAllStops(). The search flow already passes its own fromStop,
  /// so this map only serves the browse flow.
  Map<String, StopModel> _stopsById = {};

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _state = _LoadState.loading);
    try {
      final result = await widget.repository.getAllActiveRoutes();

      // Read separately and deliberately tolerant: if the stops read
      // fails, the routes list still renders and TripDetailsScreen
      // falls back to the stop name exactly as it did before.
      Map<String, StopModel> stopsById = {};
      try {
        final stopsResult = await widget.repository.getAllStops();
        stopsById = {
          for (final stop in stopsResult.data) stop.id: stop,
        };
      } catch (_) {
        stopsById = {};
      }

      if (!mounted) return;
      setState(() {
        _routes = result.data;
        _stopsById = stopsById;
        _isOffline = result.isFromCache;

        if (result.data.isNotEmpty) {
          _state = _LoadState.loaded;
        } else if (result.isFromCache) {
          _state = _LoadState.error;
        } else {
          _state = _LoadState.empty;
        }
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
    if (_state == _LoadState.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_state == _LoadState.error) {
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
            TextButton(onPressed: _loadRoutes, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_state == _LoadState.empty) {
      return const Center(
        child: Text(
          'No routes yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        if (_isOffline) const OfflineBanner(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _routes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final route = _routes[index];
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TripDetailsScreen(
                        route: route,
                        originStop: _stopsById[route.originStopId],
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.routeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${route.originStopName} -> ${route.destinationStopName}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            route.departureType == DepartureType.scheduled
                                ? '${route.firstDeparture} - ${route.lastDeparture}'
                                : 'Departs when full',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${route.priceJD.toStringAsFixed(2)} JD',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}