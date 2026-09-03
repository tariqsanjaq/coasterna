import 'package:flutter_test/flutter_test.dart';
import 'package:coasterna_project/core/models/route_model.dart';

RouteModel _baseRoute({List<LatLngPoint>? pathPoints}) {
  return RouteModel(
    id: 'r1',
    routeName: 'Sweileh to AAU Main Gate',
    operatorName: 'Al-Nasr Coaster Lines',
    direction: RouteDirection.outbound,
    originStopId: 's1',
    originStopName: 'Sweileh',
    destinationStopId: 's2',
    destinationStopName: 'AAU Main Gate',
    priceJD: 0.55,
    durationMinutes: 35,
    departureType: DepartureType.whenFull,
    firstDeparture: '06:30',
    lastDeparture: '19:30',
    operatingDays: const [],
    stops: const [],
    isActive: true,
    collectedBy: 'Tariq Sanjaq',
    collectedOn: DateTime(2026, 6, 14),
    pathPoints: pathPoints,
  );
}

void main() {
  group('RouteStop', () {
    test('fromJson and toJson round-trip preserves all fields', () {
      final json = {
        'stopId': 'wp-01',
        'stopName': 'Roundabout 3',
        'order': 2,
      };
      final stop = RouteStop.fromJson(json);

      expect(stop.stopId, 'wp-01');
      expect(stop.stopName, 'Roundabout 3');
      expect(stop.order, 2);
      expect(stop.toJson(), json);
    });
  });

  group('DepartureType', () {
    test('fromFirestore maps SCHEDULED and WHEN_FULL correctly', () {
      expect(DepartureType.fromFirestore('SCHEDULED'),
          DepartureType.scheduled);
      expect(DepartureType.fromFirestore('WHEN_FULL'),
          DepartureType.whenFull);
    });

    test('toFirestore is the exact inverse of fromFirestore', () {
      expect(DepartureType.scheduled.toFirestore(), 'SCHEDULED');
      expect(DepartureType.whenFull.toFirestore(), 'WHEN_FULL');
    });

    test('fromFirestore throws ArgumentError on an unknown value', () {
      expect(() => DepartureType.fromFirestore('BOGUS'),
          throwsArgumentError);
    });
  });

  group('RouteDirection', () {
    test('fromFirestore maps OUTBOUND and RETURN correctly', () {
      expect(RouteDirection.fromFirestore('OUTBOUND'),
          RouteDirection.outbound);
      expect(RouteDirection.fromFirestore('RETURN'),
          RouteDirection.returnTrip);
    });

    test('toFirestore is the exact inverse of fromFirestore', () {
      expect(RouteDirection.outbound.toFirestore(), 'OUTBOUND');
      expect(RouteDirection.returnTrip.toFirestore(), 'RETURN');
    });

    test('fromFirestore throws ArgumentError on an unknown value', () {
      expect(() => RouteDirection.fromFirestore('SIDEWAYS'),
          throwsArgumentError);
    });
  });

  group('RouteModel.pathPoints (decision D51)', () {
    test('parsePathPoints parses a valid "lat,lng;lat,lng" string', () {
      final points = RouteModel.parsePathPoints(
        '32.043402,35.778540;32.035934,35.790880',
      );

      expect(points, isNotNull);
      expect(points!.length, 2);
      expect(points[0].lat, 32.043402);
      expect(points[0].lng, 35.778540);
      expect(points[1].lat, 32.035934);
      expect(points[1].lng, 35.790880);
    });

    test('parsePathPoints returns null for a malformed string', () {
      // Missing the comma inside one pair.
      expect(RouteModel.parsePathPoints('32.043402;35.790880'), isNull);
      // Non-numeric coordinate.
      expect(
        RouteModel.parsePathPoints('32.043402,not-a-number'),
        isNull,
      );
      // A pair with three components instead of two.
      expect(
        RouteModel.parsePathPoints('32.04,35.77,extra;32.03,35.79'),
        isNull,
      );
    });

    test('parsePathPoints returns null for empty or missing input', () {
      expect(RouteModel.parsePathPoints(null), isNull);
      expect(RouteModel.parsePathPoints(''), isNull);
      expect(RouteModel.parsePathPoints('   '), isNull);
    });

    test('pathPointsToFirestore returns null for null or empty points', () {
      expect(RouteModel.pathPointsToFirestore(null), isNull);
      expect(RouteModel.pathPointsToFirestore(const []), isNull);
    });

    test('parsePathPoints(pathPointsToFirestore(points)) round-trips', () {
      const original = [
        LatLngPoint(32.043402, 35.778540),
        LatLngPoint(32.041123, 35.782001),
        LatLngPoint(32.035934, 35.790880),
      ];

      final serialized = RouteModel.pathPointsToFirestore(original);
      expect(serialized, isNotNull);

      final reparsed = RouteModel.parsePathPoints(serialized);
      expect(reparsed, isNotNull);
      expect(reparsed!.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(reparsed[i].lat, original[i].lat);
        expect(reparsed[i].lng, original[i].lng);
      }
    });

    test('RouteModel.toFirestore() round-trips through parsePathPoints', () {
      const points = [
        LatLngPoint(32.043402, 35.778540),
        LatLngPoint(32.035934, 35.790880),
      ];
      final route = _baseRoute(pathPoints: points);

      final data = route.toFirestore();
      expect(data['pathPoints'], isA<String>());

      final reparsed = RouteModel.parsePathPoints(data['pathPoints'] as String);
      expect(reparsed, isNotNull);
      expect(reparsed!.length, 2);
      expect(reparsed[0].lat, 32.043402);
      expect(reparsed[0].lng, 35.778540);
      expect(reparsed[1].lat, 32.035934);
      expect(reparsed[1].lng, 35.790880);
    });

    test('RouteModel.toFirestore() writes null pathPoints as null', () {
      final route = _baseRoute();
      final data = route.toFirestore();
      expect(data['pathPoints'], isNull);
      expect(data.containsKey('pathPoints'), isTrue);
    });
  });
}