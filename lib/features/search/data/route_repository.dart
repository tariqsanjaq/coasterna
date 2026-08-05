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
  Future<List<RouteModel>> searchRoutesByOrigin(String originStopId) async {
    final snapshot = await _firestore
        .collection('routes')
        .where('originStopId', isEqualTo: originStopId)
        .where('isActive', isEqualTo: true)
        .get();

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
}