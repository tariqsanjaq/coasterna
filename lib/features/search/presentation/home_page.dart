import 'package:flutter/material.dart';
import '../../../../core/models/stop_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';
import 'search_results_placeholder.dart';
import 'widgets/stop_picker_sheet.dart';

/// Artboard 2 — Home / Search. The student picks a FROM stop
/// (required) and taps Search to see every active route departing
/// from it. TO is optional and informational only — see the scope
/// note in this task's Why/Warning callout.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeView();
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final RouteRepository _repository = RouteRepository();

  StopModel? _fromStop;
  StopModel? _toStop;

  Future _pickFromStop() async {
    final selected = await _openStopPicker(title: 'From');
    if (selected != null) {
      setState(() => _fromStop = selected);
    }
  }

  Future _pickToStop() async {
    final selected = await _openStopPicker(title: 'To');
    if (selected != null) {
      setState(() => _toStop = selected);
    }
  }

  Future<StopModel?> _openStopPicker({required String title}) {
    return showModalBottomSheet<StopModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) =>
          StopPickerSheet(title: title, repository: _repository),
    );
  }

  void _search() {
    if (_fromStop == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsPlaceholder(
          fromStop: _fromStop!,
          toStop: _toStop,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = _fromStop != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        title: const Text('Coasterna'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where are you headed?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _StopField(
                label: 'From',
                value: _fromStop?.name,
                icon: Icons.trip_origin,
                onTap: _pickFromStop,
              ),
              const SizedBox(height: AppSpacing.md),
              _StopField(
                label: 'To (optional)',
                value: _toStop?.name,
                icon: Icons.place_outlined,
                onTap: _pickToStop,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: kMinTouchTarget,
                child: ElevatedButton(
                  onPressed: canSearch ? _search : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    disabledBackgroundColor: AppColors.surfaceBorder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: const Text(
                    'Search buses',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (!canSearch) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Pick a From stop to continue.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable row that opens the Stop Picker. Shows the picked
/// stop's name once selected, or a placeholder before that.
class _StopField extends StatelessWidget {
  const _StopField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                  ),
                  Text(
                    value ?? 'Select a stop',
                    style: TextStyle(
                      color: value == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}