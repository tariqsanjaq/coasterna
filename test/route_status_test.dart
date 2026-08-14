// =====================================================================
// COASTERNA — Abdallah Task #7
// File to CREATE: test/route_status_test.dart
//
// This is a COMPLETE file. Create it exactly as it is, do not edit
// anything else in the project, then run:   flutter test
// =====================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coasterna_project/core/models/route_model.dart';
import 'package:coasterna_project/features/search/presentation/widgets/route_status_badge.dart';
import 'package:coasterna_project/features/trip/presentation/trip_details_screen.dart';

// ---------------------------------------------------------------------
// Test helper.
//
// Every test below needs a RouteModel, but each test only cares about
// two or three of its fields. Building the full object by hand inside
// every test would bury the one value that actually matters under
// eighteen irrelevant ones. This helper fills every field with a safe
// default and lets each test override only what it is testing.
//
// This is the standard "object mother" pattern for test data. It is
// the difference between a test that reads as a sentence and a test
// nobody can review.
// ---------------------------------------------------------------------
RouteModel buildRoute({
  DepartureType departureType = DepartureType.scheduled,
  String firstDeparture = '06:00',
  String lastDeparture = '22:00',
  int? frequencyMinutes = 30,
  List<String> operatingDays = const ['SUN', 'MON', 'TUE', 'WED', 'THU'],
  List<RouteStop> stops = const [],
  bool isActive = true,
}) {
  return RouteModel(
    id: 'route-test-1',
    routeName: 'Test Line',
    operatorName: 'Test Operator',
    direction: RouteDirection.outbound,
    originStopId: 'stop-a',
    originStopName: 'Stop A',
    destinationStopId: 'stop-b',
    destinationStopName: 'Stop B',
    priceJD: 0.50,
    durationMinutes: 25,
    departureType: departureType,
    firstDeparture: firstDeparture,
    lastDeparture: lastDeparture,
    frequencyMinutes: frequencyMinutes,
    operatingDays: operatingDays,
    stops: stops,
    isActive: isActive,
    collectedBy: 'tester',
    collectedOn: DateTime(2026, 8, 1),
  );
}

// Fixed calendar dates used across the tests, so no test ever depends
// on the day it happens to be run. A test that passes on Tuesday and
// fails on Friday is worse than no test at all.
final sunday = DateTime(2026, 8, 16, 12, 0);
final monday = DateTime(2026, 8, 17, 12, 0);
final friday = DateTime(2026, 8, 14, 12, 0);
final saturday = DateTime(2026, 8, 15, 12, 0);

void main() {
  // -------------------------------------------------------------------
  group('parseTimeOnDay', () {
    test('parses a valid HH:mm string onto the reference date', () {
      final result = parseTimeOnDay('06:30', DateTime(2026, 8, 16));

      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 8);
      expect(result.day, 16);
      expect(result.hour, 6);
      expect(result.minute, 30);
    });

    test('accepts a single-digit hour', () {
      final result = parseTimeOnDay('6:30', DateTime(2026, 8, 16));
      expect(result?.hour, 6);
      expect(result?.minute, 30);
    });

    test('returns null when the colon is missing', () {
      expect(parseTimeOnDay('0630', DateTime(2026, 8, 16)), isNull);
    });

    test('returns null on non-numeric text', () {
      expect(parseTimeOnDay('morning', DateTime(2026, 8, 16)), isNull);
    });

    test('returns null when the hour is out of range', () {
      expect(parseTimeOnDay('25:00', DateTime(2026, 8, 16)), isNull);
    });

    test('returns null when the minute is out of range', () {
      expect(parseTimeOnDay('10:75', DateTime(2026, 8, 16)), isNull);
    });
  });

  // -------------------------------------------------------------------
  group('routeRunsToday', () {
    test('returns true when today is in operatingDays', () {
      final route = buildRoute(operatingDays: ['SUN', 'MON']);
      expect(routeRunsToday(route, sunday), isTrue);
    });

    test('returns false when today is not in operatingDays', () {
      final route = buildRoute(operatingDays: ['SUN', 'MON']);
      expect(routeRunsToday(route, friday), isFalse);
    });

    test('is not confused by lowercase values in the data', () {
      final route = buildRoute(operatingDays: ['sun', 'mon']);
      expect(routeRunsToday(route, monday), isTrue);
    });

    // An empty operatingDays list is documented to mean "runs every
    // day". If this test FAILS, do not change the test — report it.
    // A failure here means the code and the data model disagree, and
    // the data model is the signed document.
    test('an empty operatingDays list means the route runs every day', () {
      final route = buildRoute(operatingDays: const []);
      expect(routeRunsToday(route, saturday), isTrue);
      expect(routeRunsToday(route, monday), isTrue);
    });
  });

  // -------------------------------------------------------------------
  group('minutesUntilNextDeparture', () {
    test('returns null when frequencyMinutes is null', () {
      final route = buildRoute(frequencyMinutes: null);
      final now = DateTime(2026, 8, 16, 7, 0);
      expect(minutesUntilNextDeparture(route, now), isNull);
    });

    test('returns null when frequencyMinutes is zero or negative', () {
      final zero = buildRoute(frequencyMinutes: 0);
      final negative = buildRoute(frequencyMinutes: -10);
      final now = DateTime(2026, 8, 16, 7, 0);

      expect(minutesUntilNextDeparture(zero, now), isNull);
      expect(minutesUntilNextDeparture(negative, now), isNull);
    });

    test('returns null when firstDeparture cannot be parsed', () {
      final route = buildRoute(firstDeparture: 'six oclock');
      final now = DateTime(2026, 8, 16, 7, 0);
      expect(minutesUntilNextDeparture(route, now), isNull);
    });

    test('returns null before the service has started for the day', () {
      final route = buildRoute(firstDeparture: '06:00');
      final now = DateTime(2026, 8, 16, 5, 30);
      expect(minutesUntilNextDeparture(route, now), isNull);
    });

    test('computes the wait from firstDeparture and frequency', () {
      final route = buildRoute(firstDeparture: '06:00', frequencyMinutes: 30);
      final now = DateTime(2026, 8, 16, 6, 10);

      // 10 minutes past the 06:00 bus, buses every 30 minutes,
      // so the next one is the 06:30 bus: 20 minutes away.
      expect(minutesUntilNextDeparture(route, now), 20);
    });

    test('returns a full interval when standing exactly at a departure', () {
      final route = buildRoute(firstDeparture: '06:00', frequencyMinutes: 30);
      final now = DateTime(2026, 8, 16, 6, 30);

      // Deliberate: at exactly 06:30 the 06:30 bus is treated as
      // already gone, so the answer is the 07:00 bus. Showing
      // "in 0 min" for a bus that is leaving right now would be
      // worse for the student than showing the next reliable one.
      expect(minutesUntilNextDeparture(route, now), 30);
    });

    test('returns null when the next bus would fall after lastDeparture', () {
      final route = buildRoute(
        firstDeparture: '06:00',
        lastDeparture: '07:45',
        frequencyMinutes: 30,
      );
      final now = DateTime(2026, 8, 16, 7, 40);

      // Next slot would be 08:00, which is after the last bus, so
      // there is no next bus today.
      expect(minutesUntilNextDeparture(route, now), isNull);
    });
  });

  // -------------------------------------------------------------------
  group('routeDepartureRank', () {
    test('a route that does not run today ranks below everything else', () {
      final notToday = buildRoute(operatingDays: ['SUN']);
      final runsToday = buildRoute(operatingDays: ['FRI']);

      expect(
        routeDepartureRank(notToday, friday) >
            routeDepartureRank(runsToday, friday),
        isTrue,
      );
    });

    test('a WHEN_FULL route ranks below any scheduled route today', () {
      final whenFull = buildRoute(
        departureType: DepartureType.whenFull,
        operatingDays: ['SUN'],
      );
      final scheduled = buildRoute(
        departureType: DepartureType.scheduled,
        firstDeparture: '06:00',
        frequencyMinutes: 30,
        operatingDays: ['SUN'],
      );
      final now = DateTime(2026, 8, 16, 7, 0);

      expect(
        routeDepartureRank(whenFull, now) >
            routeDepartureRank(scheduled, now),
        isTrue,
      );
    });

    test('a WHEN_FULL route still ranks above a route not running today', () {
      final whenFull = buildRoute(
        departureType: DepartureType.whenFull,
        operatingDays: ['SUN'],
      );
      final notToday = buildRoute(operatingDays: ['MON']);
      final now = DateTime(2026, 8, 16, 7, 0);

      expect(
        routeDepartureRank(whenFull, now) < routeDepartureRank(notToday, now),
        isTrue,
      );
    });

    test('before service starts, the rank is the wait until the first bus', () {
      final route = buildRoute(
        firstDeparture: '06:00',
        operatingDays: ['SUN'],
      );
      final now = DateTime(2026, 8, 16, 5, 30);

      expect(routeDepartureRank(route, now), 30);
    });

    test('sorting a mixed list puts the soonest bus first', () {
      final now = DateTime(2026, 8, 16, 7, 0);

      final soon = buildRoute(
        firstDeparture: '06:00',
        frequencyMinutes: 30,
        operatingDays: ['SUN'],
      );
      final whenFull = buildRoute(
        departureType: DepartureType.whenFull,
        operatingDays: ['SUN'],
      );
      final notToday = buildRoute(operatingDays: ['MON']);

      final list = [notToday, whenFull, soon];
      list.sort(
            (a, b) => routeDepartureRank(a, now).compareTo(
          routeDepartureRank(b, now),
        ),
      );

      expect(list[0], same(soon));
      expect(list[1], same(whenFull));
      expect(list[2], same(notToday));
    });
  });

  // -------------------------------------------------------------------
  group('formatOperatingDays', () {
    test('collapses an unbroken run of days into a range', () {
      expect(
        formatOperatingDays(['SUN', 'MON', 'TUE', 'WED', 'THU']),
        'Sun to Thu',
      );
    });

    test('lists days separately when there is a gap', () {
      expect(formatOperatingDays(['SUN', 'TUE', 'THU']), 'Sun, Tue, Thu');
    });

    test('sorts into week order regardless of the order in Firestore', () {
      expect(formatOperatingDays(['THU', 'SUN', 'TUE']), 'Sun, Tue, Thu');
    });

    test('an empty list reads as every day', () {
      expect(formatOperatingDays(const []), 'Every day');
    });

    test('a single day is shown on its own', () {
      expect(formatOperatingDays(['FRI']), 'Fri');
    });

    test('unknown day codes do not crash the screen', () {
      // Bad data must degrade, never throw. A crash here would take
      // down the whole Trip Details screen for one typo in Firestore.
      expect(() => formatOperatingDays(['XYZ']), returnsNormally);
    });
  });

  // -------------------------------------------------------------------
  group('RouteModel.toFirestore', () {
    test('writes enums as their agreed Firestore strings', () {
      final map = buildRoute(
        departureType: DepartureType.whenFull,
      ).toFirestore();

      expect(map['departureType'], 'WHEN_FULL');
      expect(map['direction'], 'OUTBOUND');
    });

    test('writes collectedOn as a Firestore Timestamp, not a DateTime', () {
      final map = buildRoute().toFirestore();
      expect(map['collectedOn'], isA<Timestamp>());
    });

    test('does not write the document id into the document body', () {
      // The id is the document key in Firestore. Writing it inside
      // the document as well would give us two copies that can drift
      // apart, and nothing would ever tell us they had.
      final map = buildRoute().toFirestore();
      expect(map.containsKey('id'), isFalse);
    });

    test('keeps a null frequencyMinutes as null', () {
      final map = buildRoute(frequencyMinutes: null).toFirestore();
      expect(map['frequencyMinutes'], isNull);
    });

    test('serialises embedded waypoints in the order given', () {
      final map = buildRoute(
        stops: const [
          RouteStop(stopId: 'wp-1', stopName: 'First', order: 1),
          RouteStop(stopId: 'wp-2', stopName: 'Second', order: 2),
        ],
      ).toFirestore();

      final stops = map['stops'] as List<dynamic>;
      expect(stops.length, 2);
      expect((stops[0] as Map<String, dynamic>)['stopName'], 'First');
      expect((stops[1] as Map<String, dynamic>)['order'], 2);
    });
  });
}