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
}