import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/report_model.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/pending_intent.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/student_login_screen.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../reports/data/reports_repository.dart';

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

  return DateTime(reference.year, reference.month, reference.day, hour, minute);
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

  final indexes =
      days
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
  const TripDetailsScreen({super.key, required this.route, this.originStop});

  final RouteModel route;
  final StopModel? originStop;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  bool _showAllStops = false;

  final AuthRepository _authRepository = AuthRepository();

  /// The full ordered timeline, taken straight from the route's own
  /// `stops` array sorted by `order`.
  List<String> get _allStopNames {
    final sortedStops = [...widget.route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));

    return sortedStops.map((s) => s.stopName).toList();
  }

  /// D51 — path points, not stop pins. When the route has a recorded
  /// path ([RouteModel.pathPoints], at least 2 points), this opens a
  /// Google Maps DIRECTIONS link strung through those points in order,
  /// so the line Google draws follows the bus's actual road. The
  /// points are sampled from the route's recorded GPX track, never
  /// from stop coordinates: stop coordinates sit at the roadside and
  /// were field-tested to make Google detour to reach them (21.9 km
  /// shown vs 11.2 km real), while GPX-sampled mid-road points hold
  /// Google to the real path (7.2 km shown vs 7.32 km real).
  ///
  /// When there is no recorded path — two of the four routes today,
  /// and every future demonstration route until it is surveyed — this
  /// falls back to the original single-pin behaviour below, unchanged.
  ///
  /// ACCEPTED TRADE-OFF, NOT UNHANDLED — [widget.originStop] can be
  /// null here for two reasons: the origin stop was deactivated after
  /// this route was created (Browse all routes only maps active stops
  /// to their coordinates, see `all_routes_screen.dart`'s `_stopsById`),
  /// or the stops fetch that would have supplied it failed upstream.
  /// When that happens the query below falls back to the stop's name
  /// string instead of `latitude,longitude` — Maps still opens, it is
  /// just a text search instead of a precise pin. This fallback is
  /// deliberate, not a missed case.
  Future<void> _openInMaps() async {
    final pathPoints = widget.route.pathPoints;

    final Uri uri;
    if (pathPoints != null && pathPoints.length >= 2) {
      final legs = pathPoints.map((p) => '${p.lat},${p.lng}').join('/');
      uri = Uri.parse('https://www.google.com/maps/dir/$legs');
    } else {
      // نبني نص "query" لرابط الخرائط: إحداثيات دقيقة إذا توفرت (عند الدخول من
      // نتائج البحث)، أو اسم المحطة كنص بحث إذا لم تتوفر الإحداثيات (عند الدخول
      // من "Browse all routes"، حيث originStop يكون null حاليًا).
      final String query = widget.originStop != null
          ? '${widget.originStop!.latitude},${widget.originStop!.longitude}'
          : widget.route.originStopName;

      // صيغة "بحث" (دبوس واحد على الموقع) — وليس صيغة "اتجاهات". هذا يطابق
      // الهدف الفعلي المطلوب: نُري الطالب أين تقع محطة الانطلاق، لا نحسب له
      // طريقًا كاملًا من موقعه الحالي.
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(query)}',
      );
    }

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

  /// "Report an issue" tap handler — decision D52 part 2. Shown to
  /// everyone, signed in or not. A guest tap stores a [PendingReport]
  /// and sends the student to sign in instead of opening the form;
  /// see `pending_intent_completion.dart` for what happens after they
  /// sign in (a SnackBar telling them to come back, NOT an automatic
  /// reopen — reopening would need navigating to this specific route's
  /// screen from Home, which is exactly the "return to a prior screen"
  /// problem the sign-in nav-stack fix deliberately avoids).
  void _openReportForm() {
    if (_authRepository.currentUser == null) {
      PendingIntentHolder.set(
        PendingReport(widget.route.id, widget.route.routeName),
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StudentLoginScreen()));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => _ReportFormSheet(
        routeId: widget.route.id,
        routeName: widget.route.routeName,
      ),
    );
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
        actions: [
          FavoriteButton(routeId: route.id, routeName: route.routeName),
        ],
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
              child: Column(
                children: [
                  SizedBox(
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
                  if (route.pathPoints != null &&
                      route.pathPoints!.length >= 2) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Opens the road path in Google Maps. Stop names are '
                      'listed above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: _openReportForm,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Report an issue'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, kMinTouchTarget),
                    ),
                  ),
                ],
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
                  child: Container(width: 1.5, color: AppColors.surfaceBorder),
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

/// The exact five display strings from `ReportModel.reasonLabel`,
/// duplicated here rather than called on a real ReportModel — this
/// task's constraints forbid touching ReportModel (part 1 is already
/// verified closed), and reasonLabel is an instance getter, not a
/// free function, so reading it for every possible reason before the
/// student has picked one would mean building five throwaway
/// ReportModel instances just to read a string off each. If
/// `ReportModel.reasonLabel`'s wording ever changes, this list must be
/// updated to match by hand.
String _reasonLabel(ReportReason reason) {
  switch (reason) {
    case ReportReason.priceIncorrect:
      return 'Price is incorrect';
    case ReportReason.scheduleIncorrect:
      return 'Schedule or times are incorrect';
    case ReportReason.routeNotOperating:
      return 'Route no longer operates';
    case ReportReason.stopInfoIncorrect:
      return 'Stop information is incorrect';
    case ReportReason.other:
      return 'Other';
  }
}

/// The "Report an issue" form — decision D52 part 2. A modal bottom
/// sheet, the same shape `StopPickerSheet` (home_page.dart's stop
/// picker) already establishes: surface background, top-rounded
/// corners, `isScrollControlled` so the keyboard doesn't cover the
/// "Other" text field once it appears.
///
/// Only ever opened for a signed-in student — `_openReportForm()`
/// redirects a guest to sign in instead. The `currentUser` re-check in
/// [_submit] is defensive only, for the edge case of a session ending
/// while this sheet happens to be open.
class _ReportFormSheet extends StatefulWidget {
  const _ReportFormSheet({required this.routeId, required this.routeName});

  final String routeId;
  final String routeName;

  @override
  State<_ReportFormSheet> createState() => _ReportFormSheetState();
}

class _ReportFormSheetState extends State<_ReportFormSheet> {
  final _repository = ReportsRepository();
  final _authRepository = AuthRepository();
  final _otherController = TextEditingController();

  ReportReason _reason = ReportReason.priceIncorrect;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) {
      setState(
        () => _errorMessage =
            'You have been signed out. Close this and sign in again.',
      );
      return;
    }

    // Null for an account that signed up before decision D53 and
    // never set a display name — expected, and must not block
    // submission.
    final displayName = _authRepository.currentUser?.displayName;
    final reportedByName =
        (displayName == null || displayName.isEmpty) ? null : displayName;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repository.createReport(
        ReportModel(
          id: '',
          routeId: widget.routeId,
          routeName: widget.routeName,
          reason: _reason,
          otherText: _reason == ReportReason.other
              ? _otherController.text.trim()
              : null,
          reportedByUid: uid,
          reportedByName: reportedByName,
          status: ReportStatus.open,
          createdAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      // Snackbar first, then close — same order RouteFormPanel's
      // _save() already uses for its own post-save confirmation.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Could not submit. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Root-caused overflow fix, not a guess: `isScrollControlled: true`
      // on the showModalBottomSheet call (see _openReportForm) only lets
      // the sheet grow taller than the default ~half-screen cap — it
      // does not make the CONTENT scrollable. Before this wrapper, the
      // Column below was laid out directly inside Padding with no
      // scrolling ancestor at all, so once "Other" adds its 3-line
      // TextField and the keyboard's viewInsets.bottom eats into the
      // available height, the Column's intrinsic height can exceed what
      // the modal route gives it — a RenderFlex overflow, not a keyboard
      // positioning bug (the bottom padding above was already correct).
      // SingleChildScrollView fixes this without changing the
      // keyboard-closed appearance: under the loose (min 0) height
      // constraint the modal route provides, it shrink-wraps to the
      // Column's own height exactly like before when content fits, and
      // only clamps-and-scrolls once content is taller than the
      // available space — i.e. only once the keyboard is actually open
      // and "Other" is actually selected.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report an issue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.routeName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value!),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      title: Text(_reasonLabel(reason)),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            if (_reason == ReportReason.other) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _otherController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue',
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
