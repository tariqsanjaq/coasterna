import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';
import 'widgets/route_status_badge.dart';

/// Artboard 4 — Search Results.
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

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _state = _LoadState.loading);
    try {
      final routes = await widget.repository.searchRoutesByOrigin(
        widget.fromStop.id,
        destinationStopId: widget.toStop?.id,
      );
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

  /// Opens Google Maps.
  /// If a destination (toStop) is selected, it shows the route/directions from start to end.
  /// Otherwise, it centers on the departure station (fromStop) only.
  Future<void> _openMap() async {
    final fromLat = widget.fromStop.latitude;
    final fromLng = widget.fromStop.longitude;

    final Uri uri;
    if (widget.toStop != null) {
      final toLat = widget.toStop!.latitude;
      final toLng = widget.toStop!.longitude;
      // رابط الاتجاهات (Directions) من نقطة البداية إلى نقطة النهاية
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng&destination=$toLat,$toLng&travelmode=driving',
      );
    } else {
      // رابط البحث العادي على نقطة البداية فقط في حال عدم اختيار وجهة
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$fromLat,$fromLng',
      );
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        title: Text('From ${widget.fromStop.name}'),
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
              const Text('Could not load buses. Check your connection.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _loadRoutes, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/empty_results.png',
                  width: 240,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No buses found from ${widget.fromStop.name} yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
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
                  Text('To ${route.destinationStopName}',
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
                  const SizedBox(height: AppSpacing.sm),
                  RouteStatusBadge(route: route),
                  const Divider(
                      height: AppSpacing.xl, color: AppColors.surfaceBorder),
                  InkWell(
                    onTap: _openMap,
                    child: const Row(
                      children: [
                        Icon(Icons.map_outlined,
                            color: AppColors.accent, size: 18),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'View on map',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }
}