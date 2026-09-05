import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../data/route_repository.dart';
import '../../trip/presentation/trip_details_screen.dart';
import 'widgets/route_status_badge.dart';

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

/// Pill backgrounds for the frequency label, copied by value from
/// _BadgeStyle in widgets/route_status_badge.dart so the two chips on
/// a card read as one family. They are duplicated rather than
/// imported because _BadgeStyle's colours are private to that file,
/// which this task must leave untouched.
const Color _frequencyGreenBackground = Color(0xFFE9F4EA);
const Color _frequencyAmberBackground = Color(0xFFFDF4E0);

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

      // Same ordering as the search-results screen: soonest departure
      // first. See route_status_badge.dart's routeDepartureRank doc
      // comment for the ranking rules.
      final now = DateTime.now();
      result.data.sort(
        (a, b) =>
            routeDepartureRank(a, now).compareTo(routeDepartureRank(b, now)),
      );

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
        backgroundColor: AppColors.background,
        // Navy title + back arrow on the plain background, per spec
        // page 14. Only the foreground changes here — the background
        // stays AppColors.background.
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'All routes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            if (_state == _LoadState.loaded)
              Text(
                '${_routes.length} active'
                    ' ${_routes.length == 1 ? "route" : "routes"}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
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
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final route = _routes[index];
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TripDetailsScreen(
                        route: route,
                        originStop: _stopsById[route.originStopId],
                      ),
                    ),
                  );
                },
                child: _buildRouteCard(route),
              );
            },
          ),
        ),
      ],
    );
  }

  /// One route card, matching page 14 of the certified spec: name,
  /// operator and duration on the left; price chip and frequency
  /// pill on the right; a content-width status chip along the bottom.
  Widget _buildRouteCard(RouteModel route) {
    final frequencyLabel = _buildFrequencyLabel(route);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  route.routeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Text(
                  '${route.priceJD.toStringAsFixed(2)} JD',
                  style: AppTextStyles.monoData(fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _subtitleFor(route),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FavoriteButton(routeId: route.id, routeName: route.routeName),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${route.durationMinutes} min',
                  style: AppTextStyles.monoData(fontSize: 13.5),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              frequencyLabel ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Same badge widget the Search Results cards use, so the
          // wording, the five states and the D41 operating-hours
          // fallback stay identical across both screens. It hugs its
          // own content width and sits left-aligned, exactly as it
          // does on Search Results - never stretched full width.
          Align(
            alignment: Alignment.centerLeft,
            child: RouteStatusBadge(
              route: route,
              showWhenFullDetail: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Line under the route name. The spec asks for the operator here;
  /// the origin -> destination line is kept as a fallback so a route
  /// whose operatorName was left blank never shows an empty row.
  String _subtitleFor(RouteModel route) {
    final operatorName = route.operatorName.trim();
    if (operatorName.isNotEmpty) return operatorName;
    return '${route.originStopName} to ${route.destinationStopName}';
  }

  /// Right-aligned frequency line under the price chip. Null for a
  /// SCHEDULED route with no frequencyMinutes - there is no interval
  /// to state, and the status chip already shows the operating hours.
  Widget? _buildFrequencyLabel(RouteModel route) {
    final String label;
    final Color color;
    final Color background;

    if (route.departureType == DepartureType.whenFull) {
      label = 'Departs when full';
      color = AppColors.warning;
      background = _frequencyAmberBackground;
    } else {
      final frequency = route.frequencyMinutes;
      if (frequency == null || frequency <= 0) return null;
      label = 'Every $frequency min';
      color = AppColors.success;
      background = _frequencyGreenBackground;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        color: background,
      ),
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
