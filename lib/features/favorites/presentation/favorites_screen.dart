import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../search/data/route_repository.dart';
import '../../search/presentation/widgets/route_status_badge.dart';
import '../../trip/presentation/trip_details_screen.dart';
import '../data/favorites_repository.dart';
import 'favorite_button.dart';

/// Pill backgrounds for the frequency label. Duplicated from
/// all_routes_screen.dart rather than shared, for the same reason its
/// own doc comment gives: they are private to that file, and copying
/// a couple of consts is a smaller footprint than exporting them.
const Color _frequencyGreenBackground = Color(0xFFE9F4EA);
const Color _frequencyAmberBackground = Color(0xFFFDF4E0);

/// A student's favorited routes (device-local — see
/// FavoritesRepository's class doc comment). Reached from Home via
/// the star icon, shown only when signed in.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.repository});

  /// Same `RouteRepository` instance Home already holds, passed in
  /// the same way `AllRoutesScreen(repository: _repository)` is
  /// constructed from home_page.dart.
  final RouteRepository repository;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

enum _LoadState { loading, loaded, empty, error }

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesRepository _favoritesRepository = FavoritesRepository();

  _LoadState _state = _LoadState.loading;
  List<RouteModel> _routes = [];

  /// Same purpose as all_routes_screen.dart's `_stopsById`: lets a
  /// tapped card hand TripDetailsScreen the origin StopModel (and its
  /// coordinates) instead of just a name string.
  Map<String, StopModel> _stopsById = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _state = _LoadState.loading);

    try {
      final favoriteIds = await _favoritesRepository.getFavoriteRouteIds();
      final result = await widget.repository.getAllActiveRoutes();

      // Same deliberately-tolerant pattern as all_routes_screen.dart:
      // if this second read fails, the favorite routes still render,
      // just without precise Maps coordinates on the trip screen.
      Map<String, StopModel> stopsById = {};
      try {
        final stopsResult = await widget.repository.getAllStops();
        stopsById = {
          for (final stop in stopsResult.data) stop.id: stop,
        };
      } catch (_) {
        stopsById = {};
      }

      final favoriteRoutes = result.data
          .where((route) => favoriteIds.contains(route.id))
          .toList();

      final now = DateTime.now();
      favoriteRoutes.sort(
        (a, b) =>
            routeDepartureRank(a, now).compareTo(routeDepartureRank(b, now)),
      );

      if (!mounted) return;
      setState(() {
        _routes = favoriteRoutes;
        _stopsById = stopsById;

        // Same isFromCache-while-empty heuristic as
        // all_routes_screen.dart's _loadRoutes: an empty result that
        // came from the offline cache means the read likely failed
        // rather than the backend genuinely having zero routes, so it
        // gets the error/retry state instead of "no favorites yet".
        if (result.data.isEmpty && result.isFromCache) {
          _state = _LoadState.error;
        } else if (favoriteRoutes.isEmpty) {
          _state = _LoadState.empty;
        } else {
          _state = _LoadState.loaded;
        }
      });
    } catch (e) {
      debugPrint('Could not load favorite routes: $e');
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  /// Optimistic removal, not a full reload — see the FavoriteButton's
  /// onChanged doc comment. A favorites list is short and this is a
  /// purely local toggle, so re-running getAllActiveRoutes() +
  /// getAllStops() and flashing the loading spinner just to reflect
  /// one unfavorite would be slower and more jarring than simply
  /// dropping the row the student just unstarred.
  void _removeFromList(String routeId) {
    setState(() {
      _routes.removeWhere((route) => route.id == routeId);
      if (_routes.isEmpty) _state = _LoadState.empty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Favorites',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
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
      // Same error/retry pattern as all_routes_screen.dart's
      // _buildBody, so a failed load isn't indistinguishable from a
      // genuinely empty favorites list.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Could not load favorites. Check your connection.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _loadFavorites, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_state == _LoadState.empty) {
      // Same text style as home_page.dart's "No recent searches yet."
      // empty state, centred here because this is a whole screen
      // rather than a section inside a longer page.
      return const Center(
        child: Text(
          'No favorite routes yet.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final route = _routes[index];
        return InkWell(
          key: ValueKey(route.id),
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
          child: _buildRouteCard(route),
        );
      },
    );
  }

  /// Duplicated from all_routes_screen.dart's `_buildRouteCard`
  /// (with a FavoriteButton added), rather than extracted into a
  /// shared widget — that method is private to that file, and
  /// duplicating a few dozen lines here is less invasive than
  /// changing an existing, already-working screen just to export it.
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
              FavoriteButton(
                routeId: route.id,
                onChanged: (isFavorite) {
                  if (!isFavorite) _removeFromList(route.id);
                },
              ),
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

  /// Same fallback rule as all_routes_screen.dart's `_subtitleFor`.
  String _subtitleFor(RouteModel route) {
    final operatorName = route.operatorName.trim();
    if (operatorName.isNotEmpty) return operatorName;
    return '${route.originStopName} to ${route.destinationStopName}';
  }

  /// Same rules as all_routes_screen.dart's `_buildFrequencyLabel`.
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
