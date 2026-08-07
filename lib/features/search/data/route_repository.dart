import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';

/// Reads stops and routes from Firestore. This is the ONLY class in
/// the app allowed to call Firestore directly for this feature — no
/// widget should ever call FirebaseFirestore.instance itself.
class RouteRepository {
  RouteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns every active stop, for the Stop Picker screen (artboard 3).
  Future<List<StopModel>> getAllStops() async {
    final snapshot = await _firestore
        .collection('stops')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => StopModel.fromFirestore(doc)).toList();
  }

  /// Returns every active route departing from [originStopId], for the
  /// Search Results screen (artboard 4). Does NOT sort by next
  /// departure — that happens later, in the presentation layer.
  ///
  /// [destinationStopId] is optional. When the student picked a "To"
  /// stop, pass it here and the query adds a third equality filter so
  /// only routes matching BOTH origin and destination come back. When
  /// null (student left "To" empty), the query behaves exactly as
  /// before — every active route from [originStopId], any destination.
  ///
  /// Still a single-collection query with only `==` filters, so no
  /// composite index is required — see docs/data-model.md.
  Future<List<RouteModel>> searchRoutesByOrigin(
      String originStopId, {
        String? destinationStopId,
      }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('routes')
        .where('originStopId', isEqualTo: originStopId)
        .where('isActive', isEqualTo: true);

    if (destinationStopId != null) {
      query = query.where('destinationStopId', isEqualTo: destinationStopId);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
  }

  /// Creates a new stop document in Firestore. Firestore Security
  /// Rules (not this method) enforce that only a signed-in admin can
  /// succeed here — an unauthenticated or non-admin call throws a
  /// PERMISSION_DENIED FirebaseException.
  /// Returns the new document's auto-generated ID.
  Future<String> createStop(StopModel stop) async {
    final docRef =
    await _firestore.collection('stops').add(stop.toFirestore());
    return docRef.id;
  }

  /// Creates a new route document in Firestore. Same admin-only
  /// enforcement as createStop — via Security Rules, not this code.
  Future<String> createRoute(RouteModel route) async {
    final docRef =
    await _firestore.collection('routes').add(route.toFirestore());
    return docRef.id;
  }
  /// Returns EVERY stop regardless of isActive, for the Admin
  /// management list. Do NOT use this for student-facing search —
  /// use getAllStops() there, which already filters to isActive only.
  Future<List<StopModel>> getAllStopsForAdmin() async {
    final snapshot = await _firestore.collection('stops').get();
    return snapshot.docs.map((doc) => StopModel.fromFirestore(doc)).toList();
  }

  /// Returns EVERY route regardless of isActive, for the Admin
  /// management list.
  Future<List<RouteModel>> getAllRoutesForAdmin() async {
    final snapshot = await _firestore.collection('routes').get();
    return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
  }

  /// Flips a stop's isActive flag. Security Rules (Task #4) already
  /// restrict this write to signed-in admins only — no rules changes
  /// needed for this method to work.
  Future<void> setStopActive(String stopId, bool isActive) async {
    await _firestore.collection('stops').doc(stopId).update({'isActive': isActive});
  }

  /// Flips a route's isActive flag. Same admin-only enforcement,
  /// already covered by the existing rules.
  Future<void> setRouteActive(String routeId, bool isActive) async {
    await _firestore.collection('routes').doc(routeId).update({'isActive': isActive});
  }
}