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
