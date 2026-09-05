import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coasterna_project/core/models/report_model.dart';

ReportModel _baseReport({
  ReportReason reason = ReportReason.priceIncorrect,
  String? otherText,
  ReportStatus status = ReportStatus.open,
  String? reportedByName,
}) {
  return ReportModel(
    id: 'r1',
    routeId: 'route1',
    routeName: 'Sweileh to AAU Main Gate',
    reason: reason,
    otherText: otherText,
    reportedByUid: 'uid-student-abc123',
    reportedByName: reportedByName,
    status: status,
    createdAt: DateTime(2026, 9, 3, 14, 5),
  );
}

void main() {
  group('ReportReason', () {
    test('fromFirestore maps every SCREAMING_SNAKE_CASE value', () {
      expect(ReportReason.fromFirestore('PRICE_INCORRECT'),
          ReportReason.priceIncorrect);
      expect(ReportReason.fromFirestore('SCHEDULE_INCORRECT'),
          ReportReason.scheduleIncorrect);
      expect(ReportReason.fromFirestore('ROUTE_NOT_OPERATING'),
          ReportReason.routeNotOperating);
      expect(ReportReason.fromFirestore('STOP_INFO_INCORRECT'),
          ReportReason.stopInfoIncorrect);
      expect(ReportReason.fromFirestore('OTHER'), ReportReason.other);
    });

    test('toFirestore is the exact inverse of fromFirestore', () {
      for (final reason in ReportReason.values) {
        expect(ReportReason.fromFirestore(reason.toFirestore()), reason);
      }
    });

    test('fromFirestore throws ArgumentError on an unknown value', () {
      expect(() => ReportReason.fromFirestore('BOGUS'), throwsArgumentError);
    });
  });

  group('ReportStatus', () {
    test('fromFirestore maps OPEN and RESOLVED correctly', () {
      expect(ReportStatus.fromFirestore('OPEN'), ReportStatus.open);
      expect(ReportStatus.fromFirestore('RESOLVED'), ReportStatus.resolved);
    });

    test('toFirestore is the exact inverse of fromFirestore', () {
      expect(ReportStatus.open.toFirestore(), 'OPEN');
      expect(ReportStatus.resolved.toFirestore(), 'RESOLVED');
    });

    test('fromFirestore throws ArgumentError on an unknown value', () {
      expect(() => ReportStatus.fromFirestore('BOGUS'), throwsArgumentError);
    });
  });

  group('ReportModel.reasonLabel', () {
    test('returns the exact display string for every reason', () {
      expect(
        _baseReport(reason: ReportReason.priceIncorrect).reasonLabel,
        'Price is incorrect',
      );
      expect(
        _baseReport(reason: ReportReason.scheduleIncorrect).reasonLabel,
        'Schedule or times are incorrect',
      );
      expect(
        _baseReport(reason: ReportReason.routeNotOperating).reasonLabel,
        'Route no longer operates',
      );
      expect(
        _baseReport(reason: ReportReason.stopInfoIncorrect).reasonLabel,
        'Stop information is incorrect',
      );
      expect(_baseReport(reason: ReportReason.other).reasonLabel, 'Other');
    });
  });

  group('ReportModel.otherText', () {
    test('is null when reason is not "other" and none was given', () {
      final report = _baseReport(reason: ReportReason.priceIncorrect);
      expect(report.otherText, isNull);
      expect(report.toFirestore()['otherText'], isNull);
    });

    test('carries the free-text reason through toFirestore when set', () {
      final report = _baseReport(
        reason: ReportReason.other,
        otherText: 'Bus was cancelled without notice',
      );
      expect(report.otherText, 'Bus was cancelled without notice');
      expect(
        report.toFirestore()['otherText'],
        'Bus was cancelled without notice',
      );
    });
  });

  group('ReportModel.reportedByName (decision D53)', () {
    test('is null when not given, and toFirestore() writes it as null '
        '(key present, not omitted)', () {
      final report = _baseReport();
      expect(report.reportedByName, isNull);
      final data = report.toFirestore();
      expect(data['reportedByName'], isNull);
      expect(data.containsKey('reportedByName'), isTrue);
    });

    test('carries the display-name snapshot through toFirestore when set',
        () {
      final report = _baseReport(reportedByName: 'Gaith Al-Omari');
      expect(report.reportedByName, 'Gaith Al-Omari');
      expect(report.toFirestore()['reportedByName'], 'Gaith Al-Omari');
    });
  });

  group('ReportModel.toFirestore()', () {
    test('does not write the document id into the document body', () {
      final data = _baseReport().toFirestore();
      expect(data.containsKey('id'), isFalse);
    });

    test('writes createdAt as a Firestore Timestamp, not a DateTime', () {
      final data = _baseReport().toFirestore();
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('writes reason and status as their Firestore strings', () {
      final data = _baseReport(
        reason: ReportReason.scheduleIncorrect,
        status: ReportStatus.resolved,
      ).toFirestore();
      expect(data['reason'], 'SCHEDULE_INCORRECT');
      expect(data['status'], 'RESOLVED');
    });

    test(
        'round-trips every field through the Firestore string/enum '
        'conversions (no real DocumentSnapshot available in this '
        'project\'s tests — see the RouteModel/StopModel note in '
        'CLAUDE.md — so ReportModel.fromFirestore() itself is not '
        'called here; its actual parsing logic is exercised instead, '
        'field by field, against toFirestore()\'s real output)', () {
      final original = _baseReport(
        reason: ReportReason.other,
        otherText: 'Driver refused to stop at the listed stop',
        status: ReportStatus.open,
        reportedByName: 'Gaith Al-Omari',
      );
      final data = original.toFirestore();

      expect(data['routeId'], original.routeId);
      expect(data['routeName'], original.routeName);
      expect(
        ReportReason.fromFirestore(data['reason'] as String),
        original.reason,
      );
      expect(data['otherText'], original.otherText);
      expect(data['reportedByUid'], original.reportedByUid);
      expect(data['reportedByName'], original.reportedByName);
      expect(
        ReportStatus.fromFirestore(data['status'] as String),
        original.status,
      );
      expect((data['createdAt'] as Timestamp).toDate(), original.createdAt);
    });
  });
}
