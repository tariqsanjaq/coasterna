import 'package:flutter/material.dart';
import '../../../../core/models/route_model.dart';

/// A small coloured pill shown under each search result card,
/// telling the student at a glance whether this bus runs today
/// and how it departs.
///
/// Only three states are implemented. "Next bus in X min" and
/// "First bus at HH:MM" from the design spec are deliberately NOT
/// built: they require fixed timetable data, and the field survey
/// showed most coasters depart when full rather than on a schedule.
/// See Chapter 7 (Future Work) for the full justification.
class RouteStatusBadge extends StatelessWidget {
  const RouteStatusBadge({super.key, required this.route});

  final RouteModel route;

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();

    // A scheduled route still inside its operating hours needs no
    // badge — the existing "04:30 - 19:30" line already says it.
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

  /// Decides which badge to show. Returns null when no badge is
  /// needed. Order matters: the most restrictive case is checked
  /// first, so a bus that does not run today can never be shown as
  /// if it were available.
  _BadgeStyle? _resolveStatus() {
    if (!_runsToday()) return _BadgeStyle.noService;

    if (route.departureType != DepartureType.scheduled) {
      return _BadgeStyle.whenFull;
    }

    if (_serviceEndedForToday()) return _BadgeStyle.serviceEnded;

    return null;
  }

  /// True when today's weekday appears in the route's operatingDays
  /// list. Accepts both short ("Sun") and full ("Sunday") spellings,
  /// and ignores letter case, because the field data was entered by
  /// hand and may not be perfectly consistent.
  bool _runsToday() {
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

    final todayShort = shortNames[DateTime.now().weekday]!;

    for (final day in route.operatingDays) {
      final normalised = day.trim().toLowerCase();
      if (normalised.startsWith(todayShort)) return true;
    }
    return false;
  }

  /// True when the last departure time for today has already passed.
  /// lastDeparture is stored as a "HH:mm" string. If it cannot be
  /// parsed we return false rather than throwing, so a single bad
  /// data entry never crashes the results screen.
  bool _serviceEndedForToday() {
    final parts = route.lastDeparture.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return false;

    final now = DateTime.now();
    final lastToday =
    DateTime(now.year, now.month, now.day, hour, minute);

    return now.isAfter(lastToday);
  }
}

/// The three visual styles a badge can take. Colours are declared
/// here rather than in AppColors so this task does not need to edit
/// the shared theme file that other screens depend on.
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

  static const noService = _BadgeStyle(
    label: 'No service today',
    background: Color(0xFFFDECEC),
    border: Color(0xFFE9C0C0),
    text: Color(0xFFB03A32),
  );

  static const whenFull = _BadgeStyle(
    label: 'Departs when full',
    background: Color(0xFFFDF4E0),
    border: Color(0xFFE5D5A8),
    text: Color(0xFF8A6D1B),
  );

  static const serviceEnded = _BadgeStyle(
    label: 'Service ended today',
    background: Color(0xFFFDF4E0),
    border: Color(0xFFE5D5A8),
    text: Color(0xFF8A6D1B),
  );
}