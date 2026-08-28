import 'package:flutter/material.dart';
import '../../../../core/models/stop_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/route_repository.dart';

/// Artboard 3 — Stop Picker. A bottom sheet listing every active
/// stop from Firestore. Returns the tapped stop via Navigator.pop.
class StopPickerSheet extends StatefulWidget {
  const StopPickerSheet({
    super.key,
    required this.title,
    required this.repository,
  });

  final String title;
  final RouteRepository repository;

  @override
  State<StopPickerSheet> createState() => _StopPickerSheetState();
}

enum _LoadState { loading, loaded, error }

class _StopPickerSheetState extends State<StopPickerSheet> {
  _LoadState _state = _LoadState.loading;
  List<StopModel> _stops = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() => _state = _LoadState.loading);
    try {
      final result = await widget.repository.getAllStops();
      if (!mounted) return;
      setState(() {
        _stops = result.data;

        // An empty list from the cache means "no connection and
        // nothing saved", not "this university has no bus stops".
        // Without this the sheet showed "No stops match your search."
        // to a student who simply had no signal — TC-11.
        _state = (result.isFromCache && result.data.isEmpty)
            ? _LoadState.error
            : _LoadState.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _stops
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select ${widget.title} stop',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search stops',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildBody(filtered, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
      List<StopModel> filtered, ScrollController scrollController) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
            child: CircularProgressIndicator(color: AppColors.primary));
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.sm),
              const Text('Could not load stops.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _loadStops, child: const Text('Retry')),
            ],
          ),
        );
      case _LoadState.loaded:
        if (filtered.isEmpty) {
          return const Center(
            child: Text('No stops match your search.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.separated(
          controller: scrollController,
          itemCount: filtered.length,
          separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.surfaceBorder),
          itemBuilder: (context, index) {
            final stop = filtered[index];
            return ListTile(
              minVerticalPadding: AppSpacing.md,
              leading:
              const Icon(Icons.location_on_outlined, color: AppColors.accent),
              title: Text(stop.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: Text(stop.area,
                  style: const TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.of(context).pop(stop),
            );
          },
        );
    }
  }
}