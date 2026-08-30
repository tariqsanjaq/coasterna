# Gaith Fix Context — 2026-08-26

Read-only verbatim file-context extraction for the Coasterna repository.
All file content below is the exact, complete, current content on disk at extraction time.

---

## Part 1 — Search & Trip presentation files

### `lib/features/search/presentation/search_results_placeholder.dart`

```dart
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
}```

### `lib/features/search/presentation/widgets/route_status_badge.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/models/route_model.dart';

/// Parses a "HH:mm" string into a DateTime on the same calendar day
/// as [reference]. Returns null when the string is malformed, so a
/// single bad data entry can never crash the results screen.
DateTime? parseTimeOnDay(String raw, DateTime reference) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return DateTime(
    reference.year,
    reference.month,
    reference.day,
    hour,
    minute,
  );
}

/// Normalises a hand-entered "H:mm" or "HH:mm" value into a padded
/// "HH:mm" label, so "4:30" is displayed as "04:30" and every badge
/// reads consistently. Returns the original text when it cannot be
/// parsed, rather than hiding the value from the student.
String formatTimeLabel(String raw, DateTime reference) {
  final parsed = parseTimeOnDay(raw, reference);
  if (parsed == null) return raw;

  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// True when today's weekday appears in the route's operatingDays
/// list. Accepts both short ("Sun") and full ("Sunday") spellings and
/// ignores letter case, because the field data was entered by hand
/// and is not perfectly consistent. An empty list means "runs daily".
bool routeRunsToday(RouteModel route, DateTime now) {
  if (route.operatingDays.isEmpty) return true;

  const shortNames = {
    DateTime.monday: 'mon',
    DateTime.tuesday: 'tue',
    DateTime.wednesday: 'wed',
    DateTime.thursday: 'thu',
    DateTime.friday: 'fri',
    DateTime.saturday: 'sat',
    DateTime.sunday: 'sun',
  };

  final todayShort = shortNames[now.weekday]!;

  for (final day in route.operatingDays) {
    if (day.trim().toLowerCase().startsWith(todayShort)) return true;
  }
  return false;
}

/// Minutes the student must wait for the next bus on a SCHEDULED
/// route, or null when that cannot be known.
///
/// Buses are assumed to leave at fixed intervals starting from
/// firstDeparture. Returns null when frequencyMinutes is missing,
/// when the service has not started yet, or when the computed next
/// bus would fall after lastDeparture.
int? minutesUntilNextDeparture(RouteModel route, DateTime now) {
  final frequency = route.frequencyMinutes;
  if (frequency == null || frequency <= 0) return null;

  final first = parseTimeOnDay(route.firstDeparture, now);
  final last = parseTimeOnDay(route.lastDeparture, now);
  if (first == null) return null;

  final elapsed = now.difference(first).inMinutes;
  if (elapsed < 0) return null;

  final sinceLastBus = elapsed % frequency;
  final wait = frequency - sinceLastBus;

  if (last != null && now.add(Duration(minutes: wait)).isAfter(last)) {
    return null;
  }
  return wait;
}

/// Sort key used by the search results screen to show routes
/// "soonest departure first". A lower number is shown higher in the
/// list. Routes that cannot be used today sink to the bottom.
int routeDepartureRank(RouteModel route, DateTime now) {
  if (!routeRunsToday(route, now)) return 100000;
  if (route.departureType != DepartureType.scheduled) return 50000;

  final first = parseTimeOnDay(route.firstDeparture, now);
  final last = parseTimeOnDay(route.lastDeparture, now);

  if (first != null && now.isBefore(first)) {
    return first.difference(now).inMinutes;
  }
  if (last != null && now.isAfter(last)) return 90000;

  return minutesUntilNextDeparture(route, now) ?? 60000;
}

/// A small coloured pill shown inside each search result card,
/// telling the student at a glance whether this bus runs today and
/// when it leaves. Implements all five states of the approved design.
class RouteStatusBadge extends StatelessWidget {
  const RouteStatusBadge({super.key, required this.route});

  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus(DateTime.now());
    if (status == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.border),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.text,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Decides which of the five badges to show, or null for none.
  ///
  /// Order matters and is deliberate: the most restrictive case is
  /// tested first, so a bus that does not run today can never be
  /// displayed as if it were available.
  _BadgeStyle? _resolveStatus(DateTime now) {
    if (!routeRunsToday(route, now)) return _BadgeStyle.noService;

    if (route.departureType != DepartureType.scheduled) {
      return _BadgeStyle.whenFull;
    }

    final first = parseTimeOnDay(route.firstDeparture, now);
    final last = parseTimeOnDay(route.lastDeparture, now);

    if (first != null && now.isBefore(first)) {
      return _BadgeStyle.firstBusAt(
        formatTimeLabel(route.firstDeparture, now),
      );
    }
    if (last != null && now.isAfter(last)) return _BadgeStyle.serviceEnded;

    final wait = minutesUntilNextDeparture(route, now);
    if (wait != null) return _BadgeStyle.nextBus(wait);

    // Scheduled, inside operating hours, but frequencyMinutes is
    // missing. Showing an invented time would mislead the student,
    // so no badge is shown and the operating hours line stands alone.
    return null;
  }
}

/// The visual styles a badge can take. Colours live here rather than
/// in AppColors so this task never edits the shared theme file that
/// every other screen depends on.
class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.background,
    required this.border,
    required this.text,
  });

  final String label;
  final Color background;
  final Color border;
  final Color text;

  static const _greenBackground = Color(0xFFE9F4EA);
  static const _greenBorder = Color(0xFFBFDCC2);
  static const _greenText = Color(0xFF2F6B37);

  static const _amberBackground = Color(0xFFFDF4E0);
  static const _amberBorder = Color(0xFFE5D5A8);
  static const _amberText = Color(0xFF8A6D1B);

  factory _BadgeStyle.nextBus(int minutes) => _BadgeStyle(
    label: 'Next bus in about $minutes min',
    background: _greenBackground,
    border: _greenBorder,
    text: _greenText,
  );

  factory _BadgeStyle.firstBusAt(String time) => _BadgeStyle(
    label: 'First bus at $time',
    background: _greenBackground,
    border: _greenBorder,
    text: _greenText,
  );

  static const whenFull = _BadgeStyle(
    label: 'Departs when full',
    background: _amberBackground,
    border: _amberBorder,
    text: _amberText,
  );

  static const serviceEnded = _BadgeStyle(
    label: 'Service ended today',
    background: _amberBackground,
    border: _amberBorder,
    text: _amberText,
  );

  static const noService = _BadgeStyle(
    label: 'No service today',
    background: Color(0xFFFDECEC),
    border: Color(0xFFE9C0C0),
    text: Color(0xFFB03A32),
  );
}```

### `lib/features/trip/presentation/trip_details_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/theme/app_theme.dart';

/// Parses a "HH:mm" string into a DateTime on today's date. Returns
/// null when the string is malformed, so one bad data entry can
/// never crash this screen. Kept local to this file (not shared with
/// route_status_badge.dart) so this task never touches Gaith's
/// already-closed Task #6 files — a few duplicated lines are a fair
/// trade for that isolation on a four-week deadline.
DateTime? _parseTimeOnDay(String raw, DateTime reference) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return DateTime(
    reference.year,
    reference.month,
    reference.day,
    hour,
    minute,
  );
}

/// Normalises "4:30" to "04:30" for display. Falls back to the raw
/// text when it cannot be parsed.
String _formatTimeLabel(String raw, DateTime reference) {
  final parsed = _parseTimeOnDay(raw, reference);
  if (parsed == null) return raw;
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Turns a list like ["SUN","MON","TUE","WED","THU"] into "Sun to Thu"
/// when the days form one unbroken run of the week, or a comma-joined
/// list otherwise. An empty list means the route runs every day.
String formatOperatingDays(List<String> days) {
  if (days.isEmpty) return 'Every day';

  const weekOrder = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  const display = {
    'SUN': 'Sun',
    'MON': 'Mon',
    'TUE': 'Tue',
    'WED': 'Wed',
    'THU': 'Thu',
    'FRI': 'Fri',
    'SAT': 'Sat',
  };

  final indexes = days
      .map((d) => weekOrder.indexOf(d.trim().toUpperCase()))
      .where((i) => i != -1)
      .toList()
    ..sort();

  if (indexes.isEmpty) return days.join(', ');

  final isContiguous =
      indexes.length > 1 && indexes.last - indexes.first == indexes.length - 1;

  if (isContiguous) {
    return '${display[weekOrder[indexes.first]]} to ${display[weekOrder[indexes.last]]}';
  }

  return indexes.map((i) => display[weekOrder[i]]).join(', ');
}

/// Artboard 5 - Trip Details. Reached by tapping a search result
/// card. Receives the route AND the stop the student searched from
/// directly from the previous screen — both are already sitting in
/// memory from the search that got the student here, so this screen
/// makes zero Firestore reads of its own.
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.route,
    this.originStop, // أصبح اختيارياً
  });

  final RouteModel route;
  final StopModel? originStop; // إمكانية استقبال null

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  bool _showAllStops = false;

  /// The full ordered timeline, taken straight from the route's own
  /// `stops` array sorted by `order`.
  ///
  /// That array already holds the terminals: origin at order 0 and
  /// destination last, with the waypoints in between. Nothing is
  /// stitched on at either end. Adding originStopName and
  /// destinationStopName around it — which this getter used to do —
  /// drew both terminals twice on every route.
  ///
  /// Sorting by `order` rather than trusting the stored array order
  /// means a document edited by hand in the Firebase Console still
  /// renders in sequence, and it is what makes the first and last
  /// entries reliably the two terminals for the endpoint styling.
  List<String> get _allStopNames {
    final sortedStops = [...widget.route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));

    return sortedStops.map((s) => s.stopName).toList();
  }

  Future<void> _openInMaps() async {
    // تحديد نقطة البداية (إما الإحداثيات إذا توفرت أو اسم محطة الانطلاق)
    final String originParam = widget.originStop != null
        ? '${widget.originStop!.latitude},${widget.originStop!.longitude}'
        : widget.route.originStopName;

    // تحديد نقطة النهاية (اسم المحطة النهائية للمسار)
    final String destinationParam = widget.route.destinationStopName;

    // استخدام رابط الاتجاهات (dir) بدلاً من البحث الفردي (search)
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=${Uri.encodeComponent(originParam)}'
          '&destination=${Uri.encodeComponent(destinationParam)}',
    );

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

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
            Text(
              route.routeName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              route.operatorName,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _buildStopsCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildDetailsCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openInMaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  child: const Text(
                    'Open in Google Maps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsCard() {
    final names = _allStopNames;
    final lastIndex = names.length - 1;

    // Collapsed view: origin, the first two waypoints, the last two
    // waypoints, then the destination. Only offered when there is
    // actually something to hide — a short route just lists every
    // stop with no toggle at all.
    final canCollapse = names.length > 6;
    final visibleIndexes = (!canCollapse || _showAllStops)
        ? List<int>.generate(names.length, (i) => i)
        : [0, 1, 2, lastIndex - 2, lastIndex - 1, lastIndex];

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
          const Text(
            'STOPS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < visibleIndexes.length; i++) ...[
            _StopRow(
              name: names[visibleIndexes[i]],
              isEndpoint:
                  visibleIndexes[i] == 0 || visibleIndexes[i] == lastIndex,
              isLast: i == visibleIndexes.length - 1,
            ),
            // The "Show all N stops" toggle sits right after the
            // third visible row (the last row before the gap),
            // matching the approved design exactly.
            if (canCollapse && !_showAllStops && i == 2)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2, bottom: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _showAllStops = true),
                  child: Text(
                    'Show all ${names.length} stops',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final route = widget.route;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          _DetailRow('Price', '${route.priceJD.toStringAsFixed(2)} JD'),
          _DetailRow('Duration', 'about ${route.durationMinutes} min'),
          _DetailRow(
            'Operating days',
            formatOperatingDays(route.operatingDays),
          ),
          if (route.departureType == DepartureType.scheduled) ...[
            _DetailRow(
              'First departure',
              _formatTimeLabel(route.firstDeparture, now),
            ),
            _DetailRow(
              'Last departure',
              _formatTimeLabel(route.lastDeparture, now),
              isLast: true,
            ),
          ] else
            _DetailRow('Departs', 'When full', isLast: true),
        ],
      ),
    );
  }
}

/// One row inside the stops timeline: a dot connected by a vertical
/// line, and the stop's name. Origin and destination are drawn
/// bolder with a filled dot so the route's two ends stand out from
/// the stops in between, matching the approved design.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.name,
    required this.isEndpoint,
    required this.isLast,
  });

  final String name;
  final bool isEndpoint;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEndpoint ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
              if (!isLast)
                Expanded(
                  child:
                      Container(width: 1.5, color: AppColors.surfaceBorder),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "label ....... value" line inside the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
          Text(value, style: AppTextStyles.monoData(fontSize: 13.5)),
        ],
      ),
    );
  }
}
```

---

## Part 2 — Core model files

### `lib/core/models/route_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether a route runs on a fixed timetable or leaves once full.
/// Matches the `departureType` field documented in Ch.4.2.4.
enum DepartureType {
  scheduled,
  whenFull;

  static DepartureType fromFirestore(String value) {
    switch (value) {
      case 'SCHEDULED':
        return DepartureType.scheduled;
      case 'WHEN_FULL':
        return DepartureType.whenFull;
      default:
        throw ArgumentError('Unknown departureType value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case DepartureType.scheduled:
        return 'SCHEDULED';
      case DepartureType.whenFull:
        return 'WHEN_FULL';
    }
  }
}

/// Whether this document is the outbound trip (towards AAU) or the
/// return trip (away from AAU). Each direction is a separate document —
/// this is not a toggle on a single shared route.
enum RouteDirection {
  outbound,
  returnTrip;

  static RouteDirection fromFirestore(String value) {
    switch (value) {
      case 'OUTBOUND':
        return RouteDirection.outbound;
      case 'RETURN':
        return RouteDirection.returnTrip;
      default:
        throw ArgumentError('Unknown direction value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case RouteDirection.outbound:
        return 'OUTBOUND';
      case RouteDirection.returnTrip:
        return 'RETURN';
    }
  }
}

/// One intermediate stop inside a route's ordered stop list.
/// This is NOT a separate Firestore document — it is a map embedded
/// directly inside the route document's `stops` array.
class RouteStop {
  final String stopId;
  final String stopName;
  final int order;

  const RouteStop({
    required this.stopId,
    required this.stopName,
    required this.order,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stopId'] as String,
      stopName: json['stopName'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopId': stopId,
      'stopName': stopName,
      'order': order,
    };
  }
}

/// One coaster line, in one direction. Matches the `routes` collection
/// documented in Chapter 4.2.4 of the report.
class RouteModel {
  final String id;
  final String routeName;
  final String operatorName;
  final RouteDirection direction;
  final String originStopId;
  final String originStopName;
  final String destinationStopId;
  final String destinationStopName;
  final double priceJD;
  final int durationMinutes;
  final DepartureType departureType;
  final String firstDeparture;
  final String lastDeparture;
  final int? frequencyMinutes;
  final List<String> operatingDays;
  final List<RouteStop> stops;
  final bool isActive;
  final String collectedBy;
  final DateTime collectedOn;

  const RouteModel({
    required this.id,
    required this.routeName,
    required this.operatorName,
    required this.direction,
    required this.originStopId,
    required this.originStopName,
    required this.destinationStopId,
    required this.destinationStopName,
    required this.priceJD,
    required this.durationMinutes,
    required this.departureType,
    required this.firstDeparture,
    required this.lastDeparture,
    this.frequencyMinutes,
    required this.operatingDays,
    required this.stops,
    required this.isActive,
    required this.collectedBy,
    required this.collectedOn,
  });

  /// Builds a RouteModel from a Firestore document snapshot.
  /// Call this when reading data that came directly from Firestore
  /// (for example, inside the repository layer's search query).
  factory RouteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Route document ${doc.id} has no data.');
    }

    final rawStops = data['stops'] as List<dynamic>? ?? [];

    return RouteModel(
      id: doc.id,
      routeName: data['routeName'] as String,
      operatorName: data['operatorName'] as String,
      direction: RouteDirection.fromFirestore(data['direction'] as String),
      originStopId: data['originStopId'] as String,
      originStopName: data['originStopName'] as String,
      destinationStopId: data['destinationStopId'] as String,
      destinationStopName: data['destinationStopName'] as String,
      priceJD: (data['priceJD'] as num).toDouble(),
      durationMinutes: data['durationMinutes'] as int,
      departureType:
          DepartureType.fromFirestore(data['departureType'] as String),
      firstDeparture: data['firstDeparture'] as String,
      lastDeparture: data['lastDeparture'] as String,
      frequencyMinutes: data['frequencyMinutes'] as int?,
      operatingDays: List<String>.from(data['operatingDays'] as List<dynamic>),
      stops: rawStops
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      isActive: data['isActive'] as bool,
      collectedBy: data['collectedBy'] as String,
      collectedOn: (data['collectedOn'] as Timestamp).toDate(),
    );
  }

  /// Converts this route into a Map ready to write to Firestore.
  /// Does not include `id` (Firestore assigns that) and does not
  /// include `createdAt`/`updatedAt` — the repository layer should
  /// set those with FieldValue.serverTimestamp() at write time,
  /// not here, so the server clock is always the source of truth.
  Map<String, dynamic> toFirestore() {
    return {
      'routeName': routeName,
      'operatorName': operatorName,
      'direction': direction.toFirestore(),
      'originStopId': originStopId,
      'originStopName': originStopName,
      'destinationStopId': destinationStopId,
      'destinationStopName': destinationStopName,
      'priceJD': priceJD,
      'durationMinutes': durationMinutes,
      'departureType': departureType.toFirestore(),
      'firstDeparture': firstDeparture,
      'lastDeparture': lastDeparture,
      'frequencyMinutes': frequencyMinutes,
      'operatingDays': operatingDays,
      'stops': stops.map((s) => s.toJson()).toList(),
      'isActive': isActive,
      'collectedBy': collectedBy,
      'collectedOn': Timestamp.fromDate(collectedOn),
    };
  }
}
```

### `lib/core/models/stop_model.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// One physical bus stop or terminal. Matches the `stops` collection
/// documented in Chapter 4.2.4 of the report.
class StopModel {
  final String id;
  final String name;
  final String area;
  final double latitude;
  final double longitude;
  final bool isActive;

  const StopModel({
    required this.id,
    required this.name,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  /// Builds a StopModel from a Firestore document snapshot.
  factory StopModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Stop document ${doc.id} has no data.');
    }

    return StopModel(
      id: doc.id,
      name: data['name'] as String,
      area: data['area'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      isActive: data['isActive'] as bool,
    );
  }

  /// Converts this stop into a Map ready to write to Firestore.
  /// Does not include `id` — Firestore assigns that separately.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'area': area,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
    };
  }
}
```

---

## Part 3 — Every occurrence of the literal text `TripDetailsScreen(` in `lib/`

Search performed fresh against the current working tree:

```
grep -rn "TripDetailsScreen(" lib/
```

Three matches exist right now. Two are construction sites; the third is the constructor
declaration inside `TripDetailsScreen` itself, included for completeness because it matches
the literal search text.

| # | File | Line | Kind |
| - | ---- | ---- | ---- |
| 1 | `lib/features/search/presentation/all_routes_screen.dart` | 118 | Construction site |
| 2 | `lib/features/search/presentation/search_results_placeholder.dart` | 180 | Construction site |
| 3 | `lib/features/trip/presentation/trip_details_screen.dart` | 82 | Constructor declaration (not a construction site) |

### Match 1 — `lib/features/search/presentation/all_routes_screen.dart`, line 118

Kind: Construction site.

Context shown: lines 111–125 of 177 (7 lines before, the match line, 7 lines after).
The match is at line 118.

```dart
            itemBuilder: (context, index) {
              final route = _routes[index];
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TripDetailsScreen(route: route),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
```

### Match 2 — `lib/features/search/presentation/search_results_placeholder.dart`, line 180

Kind: Construction site.

Context shown: lines 173–187 of 279 (7 lines before, the match line, 7 lines after).
The match is at line 180.

```dart
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
```

### Match 3 — `lib/features/trip/presentation/trip_details_screen.dart`, line 82

Kind: Constructor declaration (not a construction site).

Context shown: lines 75–89 of 412 (7 lines before, the match line, 7 lines after).
The match is at line 82.

```dart

/// Artboard 5 - Trip Details. Reached by tapping a search result
/// card. Receives the route AND the stop the student searched from
/// directly from the previous screen — both are already sitting in
/// memory from the search that got the student here, so this screen
/// makes zero Firestore reads of its own.
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.route,
    this.originStop, // أصبح اختيارياً
  });

  final RouteModel route;
  final StopModel? originStop; // إمكانية استقبال null
```

---

## Part 4 — SDK constraint and `url_launcher` dependency check (`pubspec.yaml`)

### `environment:` block — exact, verbatim

```yaml
environment:
  sdk: ^3.12.2
```

That is the entire `environment:` block (pubspec.yaml lines 21–22). The Dart SDK
constraint is `^3.12.2`. There is **no** separate `flutter:` constraint line inside the
`environment:` block — only the Dart `sdk:` constraint is declared.

### `url_launcher`

`url_launcher` **is** listed as a direct dependency in `pubspec.yaml`.
Verbatim line (pubspec.yaml line 40):

```yaml
  url_launcher: ^6.3.1
```

Pinned version: `^6.3.1` (caret constraint — resolves `>=6.3.1 <7.0.0`).

### Full `dependencies:` block for reference (pubspec.yaml lines 30–42)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  firebase_core: ^4.12.1
  cloud_firestore: ^6.7.1
  google_fonts: ^8.2.1
  url_launcher: ^6.3.1
  firebase_auth: ^6.5.7
  shared_preferences: ^2.3.2
```

### `dev_dependencies:` block for reference (pubspec.yaml lines 44–49)

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
```
