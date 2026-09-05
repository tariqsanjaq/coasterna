import 'package:cloud_firestore/cloud_firestore.dart';

/// Why a student flagged a route's data as wrong. Matches the `reason`
/// field documented for the `reports` collection (decision D52).
enum ReportReason {
  priceIncorrect,
  scheduleIncorrect,
  routeNotOperating,
  stopInfoIncorrect,
  other;

  static ReportReason fromFirestore(String value) {
    switch (value) {
      case 'PRICE_INCORRECT':
        return ReportReason.priceIncorrect;
      case 'SCHEDULE_INCORRECT':
        return ReportReason.scheduleIncorrect;
      case 'ROUTE_NOT_OPERATING':
        return ReportReason.routeNotOperating;
      case 'STOP_INFO_INCORRECT':
        return ReportReason.stopInfoIncorrect;
      case 'OTHER':
        return ReportReason.other;
      default:
        throw ArgumentError('Unknown reason value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case ReportReason.priceIncorrect:
        return 'PRICE_INCORRECT';
      case ReportReason.scheduleIncorrect:
        return 'SCHEDULE_INCORRECT';
      case ReportReason.routeNotOperating:
        return 'ROUTE_NOT_OPERATING';
      case ReportReason.stopInfoIncorrect:
        return 'STOP_INFO_INCORRECT';
      case ReportReason.other:
        return 'OTHER';
    }
  }
}

/// Whether a report still needs admin attention. Matches the `status`
/// field documented for the `reports` collection (decision D52). The
/// Security Rule on `reports` requires every newly created report to
/// be written as `open` — see `firestore.rules`.
enum ReportStatus {
  open,
  resolved;

  static ReportStatus fromFirestore(String value) {
    switch (value) {
      case 'OPEN':
        return ReportStatus.open;
      case 'RESOLVED':
        return ReportStatus.resolved;
      default:
        throw ArgumentError('Unknown status value: $value');
    }
  }

  String toFirestore() {
    switch (this) {
      case ReportStatus.open:
        return 'OPEN';
      case ReportStatus.resolved:
        return 'RESOLVED';
    }
  }
}

/// One student-submitted data-error report against a route — decision
/// D52, a deliberate and documented deviation from the project's
/// otherwise-locked "three collections only" rule (routes, stops,
/// admins). See `docs/project-status.md` for the decision record.
///
/// D52 is split into two parts. This model, its repository, and the
/// admin review screen are part 1. The student-facing "submit a
/// report" form is part 2 — not built yet, so nothing outside the
/// admin dashboard reads or writes this collection today.
class ReportModel {
  final String id;
  final String routeId;

  /// Denormalized snapshot of the route's display name at report
  /// time, the same pattern RouteModel already uses for
  /// originStopName/destinationStopName — so the admin table needs no
  /// extra lookup against `routes` to show which route a report is
  /// about, even if that route is later renamed or deleted.
  final String routeName;
  final ReportReason reason;

  /// Only meaningful when [reason] is [ReportReason.other]. Null
  /// otherwise.
  final String? otherText;
  final String reportedByUid;

  /// Snapshot of the reporting student's Firebase Auth `displayName`
  /// at submit time (decision D53) — the same denormalized-snapshot
  /// pattern [routeName] already uses, captured at write time rather
  /// than looked up later because client code cannot query another
  /// user's Auth profile by uid (that needs the Admin SDK, which this
  /// project has no server for). Null for the 9 reports that existed
  /// before D53, and for any account that signed up before D53 and
  /// never sets a name — the admin table falls back to the truncated
  /// uid display in both cases.
  final String? reportedByName;
  final ReportStatus status;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.reason,
    this.otherText,
    required this.reportedByUid,
    this.reportedByName,
    required this.status,
    required this.createdAt,
  });

  /// The exact display string for [reason], used wherever the app
  /// lists reports (currently only the admin Reports table).
  String get reasonLabel {
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

  /// Builds a ReportModel from a Firestore document snapshot.
  factory ReportModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Report document ${doc.id} has no data.');
    }

    return ReportModel(
      id: doc.id,
      routeId: data['routeId'] as String,
      routeName: data['routeName'] as String,
      reason: ReportReason.fromFirestore(data['reason'] as String),
      otherText: data['otherText'] as String?,
      reportedByUid: data['reportedByUid'] as String,
      reportedByName: data['reportedByName'] is String
          ? data['reportedByName'] as String
          : null,
      status: ReportStatus.fromFirestore(data['status'] as String),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Converts this report into a Map ready to write to Firestore.
  /// Does not include `id` — Firestore assigns that separately, same
  /// convention RouteModel and StopModel already follow.
  Map<String, dynamic> toFirestore() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'reason': reason.toFirestore(),
      'otherText': otherText,
      'reportedByUid': reportedByUid,
      'reportedByName': reportedByName,
      'status': status.toFirestore(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
