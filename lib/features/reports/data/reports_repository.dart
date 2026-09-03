import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/report_model.dart';
import '../../search/data/route_repository.dart' show RepoResult;

/// Reads and writes the `reports` collection — decision D52, part 1.
/// Same repository-pattern style as RouteRepository/AuthRepository:
/// constructor takes an optional FirebaseFirestore (no singleton), and
/// this is the only class allowed to touch `reports` in Firestore
/// directly — no widget should call FirebaseFirestore.instance itself.
///
/// Reuses [RepoResult] from `route_repository.dart` rather than
/// defining a second copy of the same isFromCache wrapper.
class ReportsRepository {
  ReportsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Submits a new report. [report.id] is ignored — Firestore assigns
  /// the document id, the same convention RouteRepository.createRoute()
  /// and createStop() already follow.
  ///
  /// Security Rules (not this method) enforce that
  /// `reportedByUid` matches the caller's own uid and that `status` is
  /// written as `"OPEN"` — see the `reports` match block in
  /// `firestore.rules`. An unauthenticated caller, or one trying to
  /// submit a report under someone else's uid or as already-resolved,
  /// gets a PERMISSION_DENIED FirebaseException from this call.
  Future<void> createReport(ReportModel report) async {
    await _firestore.collection('reports').add(report.toFirestore());
  }

  /// Returns every report, newest first, for the admin Reports tab.
  /// Admin-only per Security Rules — an unauthenticated or non-admin
  /// caller gets a PERMISSION_DENIED FirebaseException.
  Future<RepoResult<List<ReportModel>>> getAllReports() async {
    final snapshot = await _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .get();

    return RepoResult(
      data: snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }

  /// Marks one report resolved. Same admin-only enforcement as
  /// [getAllReports], via Security Rules.
  Future<void> resolveReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': ReportStatus.resolved.toFirestore(),
    });
  }
}
