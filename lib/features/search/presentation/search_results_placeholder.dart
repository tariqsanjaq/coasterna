import 'package:flutter/material.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';

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
      final routes =
      await widget.repository.searchRoutesByOrigin(widget.fromStop.id);
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
      // Matches the certified Empty State illustration from
      // Coasterna_UI_Design_v8.7.pdf (Ch.4.3). Asset registered in
      // pubspec.yaml as assets/images/empty_results.png.
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
                ],
              ),
            );
          },
        );
    }
  }
}