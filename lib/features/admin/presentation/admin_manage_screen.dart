import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/report_model.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../search/data/route_repository.dart';
import '../../reports/data/reports_repository.dart';

// Spec v8.7 page 3, colour tokens. Declared locally so this file does
// not depend on token names that may not exist in app_theme.dart yet.
// If AppColors gains `success`, swap these for it.
const Color _kSuccess = Color(0xFF3B6D11); // Active status pill
const Color _kSuccessBg = Color(0xFFEDF3E7);
const Color _kMutedBg = Color(0xFFEDECE8); // Inactive status pill

/// Minimum width the tables need before their columns start to crush.
/// Below this the whole table scrolls sideways instead of squeezing.
const double _kTableMinWidth = 940;

// ---------------------------------------------------------------------
// Shared pieces used by both the Stops and the Routes list
// ---------------------------------------------------------------------

/// The page heading: title, a live count line, and one primary action
/// on the right — the layout used for "Routes" on spec page 17.
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                // The app theme makes every ElevatedButton full-width,
                // which is right inside the vertical forms but fatal
                // here: a Row measures a non-flex child with unbounded
                // width first, and "as wide as possible" has no answer
                // when the space is infinite. Overriding minimumSize
                // lets the button size to its label instead. Height
                // stays at the 48px minimum touch target.
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// One column-header cell: small, upper-case, letter-spaced grey text.
class _HeadCell extends StatelessWidget {
  const _HeadCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// One body cell. [mono] switches to IBM Plex Mono, which the design
/// system reserves for prices, times, durations and coordinates.
class _Cell extends StatelessWidget {
  const _Cell(
      this.text, {
        required this.flex,
        this.bold = false,
        this.mono = false,
      });

  final String text;
  final int flex;
  final bool bold;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: mono
            ? AppTextStyles.monoData(
          fontSize: 12.5,
          color: AppColors.textSecondary,
        )
            : TextStyle(
          fontSize: 13.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: bold ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// The Active / Inactive pill from spec page 17. The design system
/// forbids the word "Paused" — these are the only two labels.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive, required this.flex});

  final bool isActive;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? _kSuccessBg : _kMutedBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? _kSuccess : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "..." overflow menu at the end of each row. The approved design
/// hides row actions behind this menu rather than exposing a delete
/// icon on every row, which also removes the one-click path to a
/// permanent delete during a live demonstration.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.isActive,
    required this.onToggleActive,
    required this.onDelete,
    required this.deleteLabel,
    this.onEdit,
  });

  final bool isActive;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final String deleteLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_horiz,
          size: 20,
          color: AppColors.textSecondary,
        ),
        tooltip: 'Actions',
        onSelected: (value) {
          if (value == 'edit') {
            final edit = onEdit;
            if (edit != null) edit();
          } else if (value == 'toggle') {
            onToggleActive();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => [
          if (onEdit != null)
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text('Edit'),
            ),
          PopupMenuItem<String>(
            value: 'toggle',
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(
              deleteLabel,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// The centred destructive-confirmation dialog from spec page 20:
/// red trash mark on top, centred title and body, a plain Cancel and
/// a filled red confirm button.
Future<bool> _confirmDestructive(
    BuildContext context, {
      required String title,
      required String body,
      required String confirmLabel,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 30,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      // Same reason as the header button above: this
                      // one also lives inside a Row.
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result == true;
}

/// White surface card holding a header row and the data rows, with a
/// horizontal scroll for narrow windows so columns never crush.
class _TableCard extends StatelessWidget {
  const _TableCard({required this.headerCells, required this.rows});

  final List<Widget> headerCells;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < _kTableMinWidth
                ? _kTableMinWidth
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom:
                            BorderSide(color: AppColors.surfaceBorder),
                          ),
                        ),
                        child: Row(children: headerCells),
                      ),
                      ...rows,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One data row: minimum touch height, light bottom divider.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: kMinTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: cells,
      ),
    );
  }
}

/// Error and empty states. The design system requires loading, data,
/// empty and error on every screen that reads data.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    this.icon,
    this.onRetry,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Stops
// ---------------------------------------------------------------------

/// What the Stops table needs in one object: the stops themselves plus
/// how many routes reference each one.
class _StopsData {
  const _StopsData({required this.stops, required this.routeCounts});

  final List<StopModel> stops;
  final Map<String, int> routeCounts;
}

/// Every stop, active and inactive, as the data table on spec page 18:
/// NAME, AREA, LATITUDE, LONGITUDE, ROUTES.
///
/// Two columns go beyond the spec, and the reason is recorded here so
/// it can be defended: STATUS, because a stop can be deactivated and
/// the admin has to see which ones are, and the "..." menu, which is
/// the spec's own row-action pattern from page 17.
class StopsManageList extends StatefulWidget {
  const StopsManageList({
    super.key,
    required this.onAddStop,
    required this.onEditStop,
  });

  /// The Admin shell owns navigation now: the forms open as panels in
  /// the same content area, so this list asks the shell to swap the
  /// panel instead of pushing a route itself.
  final VoidCallback onAddStop;
  final ValueChanged<StopModel> onEditStop;

  @override
  State<StopsManageList> createState() => _StopsManageListState();
}

class _StopsManageListState extends State<StopsManageList> {
  final _repository = RouteRepository();
  late Future<_StopsData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// The ROUTES column counts how many route documents use a stop as
  /// their origin or destination. Both collections are already fetched
  /// for the admin lists, so the count is computed on the device — no
  /// extra query and no composite index.
  Future<_StopsData> _load() async {
    final stops = await _repository.getAllStopsForAdmin();
    final routes = await _repository.getAllRoutesForAdmin();

    final counts = <String, int>{};
    for (final route in routes) {
      counts[route.originStopId] = (counts[route.originStopId] ?? 0) + 1;
      counts[route.destinationStopId] =
          (counts[route.destinationStopId] ?? 0) + 1;
    }
    return _StopsData(stops: stops, routeCounts: counts);
  }

  Future<void> _toggle(StopModel stop) async {
    try {
      await _repository.setStopActive(stop.id, !stop.isActive);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _delete(StopModel stop) async {
    final confirmed = await _confirmDestructive(
      context,
      title: 'Delete this stop?',
      body: 'This removes "${stop.name}" from every stop picker. Any '
          'route that still refers to it by ID keeps that reference, so '
          'check the ROUTES count first. This cannot be undone.',
      confirmLabel: 'Delete stop',
    );
    if (!confirmed) return;

    try {
      await _repository.deleteStop(stop.id);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${stop.name}" deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StopsData>(
      future: _future,
      builder: (context, snapshot) {
        final stops = snapshot.data?.stops ?? const <StopModel>[];
        final areas = stops.map((s) => s.area.toLowerCase()).toSet().length;
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListHeader(
              title: 'Stops',
              subtitle: isLoading
                  ? 'Loading...'
                  : '${stops.length} stops \u00B7 $areas areas',
              actionLabel: '+ Add stop',
              onAction: widget.onAddStop,
            ),
            Expanded(child: _buildBody(snapshot)),
          ],
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<_StopsData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (snapshot.hasError) {
      return _StateMessage(
        message: 'Could not load stops. Check your connection.',
        icon: Icons.wifi_off,
        onRetry: _reload,
      );
    }

    final data = snapshot.data!;
    if (data.stops.isEmpty) {
      return const _StateMessage(message: 'No stops yet.');
    }

    return _TableCard(
      headerCells: const [
        _HeadCell('Name', flex: 4),
        _HeadCell('Area', flex: 2),
        _HeadCell('Latitude', flex: 2),
        _HeadCell('Longitude', flex: 2),
        _HeadCell('Routes', flex: 1),
        _HeadCell('Status', flex: 2),
        SizedBox(width: 48),
      ],
      rows: [
        for (final stop in data.stops)
          _TableRow(
            cells: [
              _Cell(stop.name, flex: 4, bold: true),
              _Cell(stop.area, flex: 2),
              _Cell(stop.latitude.toStringAsFixed(4), flex: 2, mono: true),
              _Cell(stop.longitude.toStringAsFixed(4), flex: 2, mono: true),
              _Cell('${data.routeCounts[stop.id] ?? 0}', flex: 1),
              _StatusPill(isActive: stop.isActive, flex: 2),
              _RowMenu(
                isActive: stop.isActive,
                onEdit: () => widget.onEditStop(stop),
                onToggleActive: () => _toggle(stop),
                onDelete: () => _delete(stop),
                deleteLabel: 'Delete stop',
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------

/// Every route, active and inactive, as the data table on spec page 17:
/// ROUTE, OPERATOR, ORIGIN, DESTINATION, PRICE, STATUS, and a "..."
/// row menu.
///
/// Documented spec deviation #3 is now closed: the menu carries an Edit
/// entry, because the route edit form exists. It was left out until the
/// form was built, on the principle that a dead menu item is worse than
/// an absent one.
class RoutesManageList extends StatefulWidget {
  const RoutesManageList({
    super.key,
    required this.onAddRoute,
    required this.onEditRoute,
  });

  /// Same reason as StopsManageList: the shell opens the form panel.
  final VoidCallback onAddRoute;

  /// Hands the whole RouteModel up to the shell, not just its id. The
  /// form needs every field to pre-fill, and this list has already
  /// fetched them — passing the id alone would mean a second read of a
  /// document that is already in memory.
  final ValueChanged<RouteModel> onEditRoute;

  @override
  State<RoutesManageList> createState() => _RoutesManageListState();
}

class _RoutesManageListState extends State<RoutesManageList> {
  final _repository = RouteRepository();
  late Future<List<RouteModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _repository.getAllRoutesForAdmin();
    });
  }

  Future<void> _toggle(RouteModel route) async {
    try {
      await _repository.setRouteActive(route.id, !route.isActive);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _delete(RouteModel route) async {
    final confirmed = await _confirmDestructive(
      context,
      title: 'Delete this route?',
      body: 'This removes "${route.routeName}" for every student '
          'searching from its stops. This cannot be undone unless the '
          'route is re-entered.',
      confirmLabel: 'Delete route',
    );
    if (!confirmed) return;

    try {
      await _repository.deleteRoute(route.id);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${route.routeName}" deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete failed. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteModel>>(
      future: _future,
      builder: (context, snapshot) {
        final routes = snapshot.data ?? const <RouteModel>[];
        final operators =
            routes.map((r) => r.operatorName.toLowerCase()).toSet().length;
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListHeader(
              title: 'Routes',
              subtitle: isLoading
                  ? 'Loading...'
                  : '${routes.length} routes \u00B7 $operators operators',
              actionLabel: '+ Add route',
              onAction: widget.onAddRoute,
            ),
            Expanded(child: _buildBody(snapshot)),
          ],
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<List<RouteModel>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (snapshot.hasError) {
      return _StateMessage(
        message: 'Could not load routes. Check your connection.',
        icon: Icons.wifi_off,
        onRetry: _reload,
      );
    }

    final routes = snapshot.data!;
    if (routes.isEmpty) {
      return const _StateMessage(message: 'No routes yet.');
    }

    return _TableCard(
      headerCells: const [
        _HeadCell('Route', flex: 3),
        _HeadCell('Operator', flex: 3),
        _HeadCell('Origin', flex: 3),
        _HeadCell('Destination', flex: 3),
        _HeadCell('Price', flex: 2),
        _HeadCell('Status', flex: 2),
        SizedBox(width: 48),
      ],
      rows: [
        for (final route in routes)
          _TableRow(
            cells: [
              _Cell(route.routeName, flex: 3, bold: true),
              _Cell(route.operatorName, flex: 3),
              _Cell(route.originStopName, flex: 3),
              _Cell(route.destinationStopName, flex: 3),
              _Cell(
                '${route.priceJD.toStringAsFixed(2)} JD',
                flex: 2,
                mono: true,
              ),
              _StatusPill(isActive: route.isActive, flex: 2),
              _RowMenu(
                isActive: route.isActive,
                onEdit: () => widget.onEditRoute(route),
                onToggleActive: () => _toggle(route),
                onDelete: () => _delete(route),
                deleteLabel: 'Delete route',
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Reports (decision D52, part 1 — read/resolve only; submitting a
// report is part 2, not built yet)
// ---------------------------------------------------------------------

/// Light tint of the accent gold (#AF9064), for the Open status pill.
/// Not an explicit spec token — derived the same way _kSuccessBg above
/// is derived from _kSuccess.
const Color _kOpenBg = Color(0xFFF4EEE3);

/// "first 8 chars…" — there is no user-lookup mechanism in this
/// project (no `users` collection, no admin SDK call from the app), so
/// the REPORTED BY column can only ever show the raw uid. Truncating
/// keeps the column from dominating the table's width.
String _truncateUid(String uid) =>
    uid.length <= 8 ? uid : '${uid.substring(0, 8)}…';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "2026-09-03 14:05" — date AND time, unlike the admin forms'
/// date-only fields, because more than one report can land on the
/// same day and the admin needs to tell them apart.
String _formatReportDate(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} '
    '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

/// The Open / Resolved pill for one report row. Same shape as
/// _StatusPill's Active/Inactive pill, different colours and labels:
/// Open in accent gold, Resolved in the same success green Active
/// already uses (spec v8.7 page 3 colour tokens).
class _ReportStatusPill extends StatelessWidget {
  const _ReportStatusPill({required this.status, required this.flex});

  final ReportStatus status;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final isResolved = status == ReportStatus.resolved;
    return Expanded(
      flex: flex,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isResolved ? _kSuccessBg : _kOpenBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isResolved ? 'Resolved' : 'Open',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isResolved ? _kSuccess : AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "..." row menu for one report. Only one action exists —
/// "Mark resolved" — unlike _RowMenu's Edit/Deactivate/Delete set, so
/// this is its own small widget rather than a variant of _RowMenu.
/// Disabled (greyed, not tappable) once the report is already
/// resolved, since there is nothing left to do to it — reports have
/// no "reopen" action.
class _ReportRowMenu extends StatelessWidget {
  const _ReportRowMenu({
    required this.isResolved,
    required this.onMarkResolved,
  });

  final bool isResolved;
  final VoidCallback onMarkResolved;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: PopupMenuButton<String>(
        enabled: !isResolved,
        icon: Icon(
          Icons.more_horiz,
          size: 20,
          color:
              isResolved ? AppColors.surfaceBorder : AppColors.textSecondary,
        ),
        tooltip: isResolved ? 'Already resolved' : 'Actions',
        onSelected: (_) => onMarkResolved(),
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'resolve',
            child: Text('Mark resolved'),
          ),
        ],
      ),
    );
  }
}

/// Every student-submitted data-error report, newest first, as
/// ROUTE · REASON · REPORTED BY · DATE · STATUS · a "..." row menu
/// whose only action is "Mark resolved".
///
/// Read-only otherwise — there is no add/edit form here, unlike
/// RoutesManageList/StopsManageList, so this section needs none of
/// AdminHomeScreen's form-panel states. See AdminHomeScreen's
/// `_AdminSection.reports`.
class ReportsManageList extends StatefulWidget {
  const ReportsManageList({
    super.key,
    required this.onOpenCountChanged,
  });

  /// Called after every successful load with the number of reports
  /// still OPEN, so the sidebar's "Reports (N)" label stays in sync
  /// without AdminHomeScreen issuing a second query of its own — the
  /// one getAllReports() call this view already needs is the only
  /// read, the count is just relayed from its result.
  final ValueChanged<int> onOpenCountChanged;

  @override
  State<ReportsManageList> createState() => _ReportsManageListState();
}

class _ReportsManageListState extends State<ReportsManageList> {
  final _repository = ReportsRepository();
  late Future<RepoResult<List<ReportModel>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<RepoResult<List<ReportModel>>> _load() async {
    final result = await _repository.getAllReports();
    widget.onOpenCountChanged(
      result.data.where((r) => r.status == ReportStatus.open).length,
    );
    return result;
  }

  Future<void> _markResolved(ReportModel report) async {
    try {
      await _repository.resolveReport(report.id);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoResult<List<ReportModel>>>(
      future: _future,
      builder: (context, snapshot) {
        final reports = snapshot.data?.data ?? const <ReportModel>[];
        final openCount =
            reports.where((r) => r.status == ReportStatus.open).length;
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListHeader(
              title: 'Reports',
              subtitle: isLoading
                  ? 'Loading...'
                  : '${reports.length} reports · $openCount open',
            ),
            Expanded(child: _buildBody(snapshot)),
          ],
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<RepoResult<List<ReportModel>>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (snapshot.hasError) {
      return _StateMessage(
        message: 'Could not load reports. Check your connection.',
        icon: Icons.wifi_off,
        onRetry: _reload,
      );
    }

    final result = snapshot.data!;
    final reports = result.data;
    if (reports.isEmpty) {
      return const _StateMessage(message: 'No reports yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.isFromCache) const OfflineBanner(),
        Expanded(
          child: _TableCard(
            headerCells: const [
              _HeadCell('Route', flex: 3),
              _HeadCell('Reason', flex: 3),
              _HeadCell('Reported by', flex: 2),
              _HeadCell('Date', flex: 2),
              _HeadCell('Status', flex: 2),
              SizedBox(width: 48),
            ],
            rows: [
              for (final report in reports)
                _TableRow(
                  cells: [
                    _Cell(report.routeName, flex: 3, bold: true),
                    _Cell(report.reasonLabel, flex: 3),
                    _Cell(
                      _truncateUid(report.reportedByUid),
                      flex: 2,
                      mono: true,
                    ),
                    _Cell(
                      _formatReportDate(report.createdAt),
                      flex: 2,
                      mono: true,
                    ),
                    _ReportStatusPill(status: report.status, flex: 2),
                    _ReportRowMenu(
                      isResolved: report.status == ReportStatus.resolved,
                      onMarkResolved: () => _markResolved(report),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
