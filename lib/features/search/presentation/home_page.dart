import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/stop_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/route_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/student_login_screen.dart';
import 'all_routes_screen.dart';
import 'search_results_placeholder.dart';
import 'widgets/stop_picker_sheet.dart';

/// Artboard 2 — Home / Search.
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
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 5;

  final RouteRepository _repository = RouteRepository();
  final AuthRepository _authRepository = AuthRepository();

  StopModel? _fromStop;
  StopModel? _toStop;
  List<Map<String, dynamic>> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentSearchesKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _recentSearches = decoded.cast<Map<String, dynamic>>();
    });
  }

  // Saves the search that was JUST run to the front of the recent
  // list, removing any earlier entry for the same From/To pair so we
  // don't show duplicates, then caps the list at 5 entries.
  Future<void> _saveRecentSearch(StopModel from, StopModel? to) async {
    final entry = {
      'fromId': from.id,
      'fromName': from.name,
      'toId': to?.id,
      'toName': to?.name,
    };
    final updated = [
      entry,
      ..._recentSearches.where(
              (e) => e['fromId'] != from.id || e['toId'] != to?.id),
    ].take(_maxRecentSearches).toList();

    setState(() => _recentSearches = updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, jsonEncode(updated));
  }

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

  void _clearToStop() {
    setState(() => _toStop = null);
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
    _saveRecentSearch(_fromStop!, _toStop);
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

  void _openAllRoutes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AllRoutesScreen(repository: _repository),
      ),
    );
  }

  // Re-runs a saved recent search. We only stored stop IDs and names
  // (not full StopModel objects), so we re-fetch the current stop
  // list and match by ID. If a stop was deleted or deactivated since
  // the search was saved, we tell the student instead of crashing.
  Future<void> _useRecentSearch(Map<String, dynamic> entry) async {
    final result = await _repository.getAllStops();
    final stops = result.data;

    StopModel? findById(String? id) {
      if (id == null) return null;
      for (final stop in stops) {
        if (stop.id == id) return stop;
      }
      return null;
    }

    final from = findById(entry['fromId'] as String?);
    if (from == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That stop is no longer available.')),
      );
      return;
    }
    final to = findById(entry['toId'] as String?);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsPlaceholder(
          fromStop: from,
          toStop: to,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use a saved account. '
              'You can still search buses as a guest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _authRepository.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
          (route) => false,
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
        actions: [
          if (_authRepository.currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _signOut,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
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
                      'Find your bus',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Pick where you are starting from',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                      onClear: _toStop != null ? _clearToStop : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                            borderRadius:
                            BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        child: const Text(
                          'Search buses',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (!canSearch) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Pick a From stop to continue.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: kMinTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: _openAllRoutes,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Browse all routes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
              if (_recentSearches.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'RECENT',
                  style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                ..._recentSearches.map((entry) {
                  final label = entry['toName'] != null
                      ? '${entry['fromName']} to ${entry['toName']}'
                      : 'From ${entry['fromName']}';
                  return InkWell(
                    onTap: () => _useRecentSearch(entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.history,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }),
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
    this.onClear,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

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
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                tooltip: 'Clear $label',
                onPressed: onClear,
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}