import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';
import 'widgets/route_status_badge.dart';
import '../../trip/presentation/trip_details_screen.dart';
import '../../../core/widgets/offline_banner.dart';

/// Artboard 4 - Search Results.
class SearchResultsPlaceholder extends StatefulWidget {
  const SearchResultsPlaceholder({
    super.key,
    required this.fromStop,
    required this.toStop,
    required this.repository,
  });

  final StopModel fromStop;
  final StopModel? toStop;
  final RouteRepository repository;

  @override
  State<SearchResultsPlaceholder> createState() =>
      _SearchResultsPlaceholderState();
}

enum _LoadState { loading, loaded, empty, error }

class _SearchResultsPlaceholderState extends State<SearchResultsPlaceholder> {
  _LoadState _state = _LoadState.loading;
  List<RouteModel> _routes = [];

  /// See all_routes_screen.dart — same meaning.
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _state = _LoadState.loading);
    try {
      final result = await widget.repository.searchRoutesByOrigin(
        widget.fromStop.id,
        destinationStopId: widget.toStop?.id,
      );
      final routes = result.data;

      // Sorted here in the app, not in the query. Firestore would
      // need a composite index to order by a computed departure time,
      // and the result set for one origin is small enough that
      // sorting on the device costs nothing measurable.
      final now = DateTime.now();
      routes.sort(
            (a, b) =>
            routeDepartureRank(a, now).compareTo(routeDepartureRank(b, now)),
      );

      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isOffline = result.isFromCache;

        if (routes.isNotEmpty) {
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
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Search results',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (_state == _LoadState.loaded)
              Text(
                '${_routes.length} ${_routes.length == 1 ? "route" : "routes"}'
                    ' \u00B7 soonest departure first',
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
              'Could not load buses. Check your connection.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _loadRoutes, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_state == _LoadState.empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/empty_results.png', width: 240),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No buses found from ${widget.fromStop.name} yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
            itemBuilder: (context, index) => InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripDetailsScreen(
                    route: _routes[index],
                    originStop: widget.fromStop,
                  ),
                ),
              ),
              child: _buildRouteCard(_routes[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(RouteModel route) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  route.routeName,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _DirectionChip(route: route),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Board at: ${widget.fromStop.name}',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${route.priceJD.toStringAsFixed(2)} JD'
                ' \u00B7 about ${route.durationMinutes} min',
            style: AppTextStyles.monoData(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          RouteStatusBadge(route: route),
        ],
      ),
    );
  }
}

/// The small outlined pill on the right of each card showing whether
/// this route travels towards the university or away from it.
class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.route});

  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (route.destinationStopName.toLowerCase().contains('aau')) {
      label = 'To AAU';
    } else if (route.direction == RouteDirection.outbound) {
      label = 'Towards AAU';
    } else {
      label = 'From AAU';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}