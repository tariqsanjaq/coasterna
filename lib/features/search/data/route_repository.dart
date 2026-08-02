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
}