import 'package:flutter_test/flutter_test.dart';
import 'package:coasterna_project/core/models/route_model.dart';

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
}