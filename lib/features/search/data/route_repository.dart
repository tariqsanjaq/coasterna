// lib/features/search/data/route_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';

/// A query result together with where the data actually came from.
///
/// Firestore keeps a copy of everything it has already downloaded on
/// the phone. When there is no connection, get() does NOT throw an
/// error — it quietly answers from that saved copy instead. If the
/// saved copy is empty (fresh install, or the student cleared the app
/// data), the result is an EMPTY list with no error at all.
///
/// That is why the app used to tell the student "No routes yet." while
/// the real problem was no internet. The list was genuinely empty; the
/// app just could not tell the two situations apart.
///
/// [isFromCache] is the flag that separates them. Firestore sets it on
/// every result. The screens use it to decide between "there is
/// nothing here" and "I cannot reach the server".
class RepoResult<T> {
  const RepoResult({required this.data, required this.isFromCache});

  /// The rows that came back. May be empty.
  final T data;

  /// true  = answered from the phone's saved copy (offline)
  /// false = answered by the Firestore server (online)
  final bool isFromCache;
}

/// Reads stops and routes from Firestore. This is the ONLY class in
/// the app allowed to call Firestore directly for this feature — no
/// widget should ever call FirebaseFirestore.instance itself.
class RouteRepository {
  RouteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns every active stop, for the Stop Picker screen (artboard 3).
  Future<RepoResult<List<StopModel>>> getAllStops() async {
    final snapshot = await _firestore
        .collection('stops')
        .where('isActive', isEqualTo: true)
        .get();

    return RepoResult(
      data: snapshot.docs.map((doc) => StopModel.fromFirestore(doc)).toList(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }

  /// Returns every active route that passes through [originStopId] —
  /// as the official origin OR as any waypoint along the way — for
  /// the Search Results screen (artboard 4). Does NOT sort by next
  /// departure — that happens later, in the presentation layer.
  ///
  /// WAYPOINT-AWARE SEARCH (D38, Task #10) — this used to be a plain
  /// `==` match on `originStopId` only. A student boarding from a
  /// stop in the middle of the route (not the official first stop)
  /// would get zero results, even though the bus genuinely passes
  /// there. The fix matches against `waypointStopIds`, a derived
  /// index field built in createRoute()/updateRoute() from
  /// `route.stops` — see the doc comment there. `stops` itself stays
  /// the source of truth; `waypointStopIds` exists only so Firestore
  /// can run this array-contains query.
  ///
  /// [destinationStopId] is optional. When the student picked a "To"
  /// stop, pass it here and the query adds a third filter so only
  /// routes matching both origin and destination come back. When
  /// null (student left "To" empty), every active route touching
  /// [originStopId] comes back, any destination.
  ///
  /// This now requires a composite index (arrayContains + isEqualTo
  /// together needs one) — Firestore will reject the first live query
  /// with a link to create it automatically. See docs/data-model.md.
  Future<RepoResult<List<RouteModel>>> searchRoutesByOrigin(
      String originStopId, {
        String? destinationStopId,
      }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('routes')
        .where('waypointStopIds', arrayContains: originStopId)
        .where('isActive', isEqualTo: true);

    if (destinationStopId != null) {
      query = query.where('destinationStopId', isEqualTo: destinationStopId);
    }

    final snapshot = await query.get();

    return RepoResult(
      data: snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }

  /// Creates a new route document in Firestore. Same admin-only
  /// enforcement as createStop — via Security Rules, not this code.
  ///
  /// WAYPOINT INDEX FIELD (D38, Task #10) — `waypointStopIds` is a
  /// derived index field: a flat list of boardable stopIds on this
  /// route, built here from `route.stops` right before the write.
  /// It exists ONLY so Firestore can run `array-contains` search
  /// queries — it is never the source of truth. `route.stops` stays
  /// the source of truth; if the two ever disagree, `stops` wins.
  ///
  /// FIX (Tariq code review, post-Task #10) — the FINAL stop (highest
  /// `order`, the route's destination) is deliberately EXCLUDED here.
  /// A student cannot board a bus at the exact stop where that bus's
  /// journey ends — there is nowhere further for it to take them.
  /// Including the destination made routes appear as false search
  /// results when a student searched from their own route's final
  /// stop (e.g. "Mahes to Sweileh" wrongly appearing when searching
  /// from Sweileh, even though that bus terminates there). Only the
  /// official origin and any true intermediate stops are boardable.
  Future<String> createRoute(RouteModel route) async {
    final sortedStops = [...route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));
    final boardableStops = sortedStops.take(sortedStops.length - 1);

    final data = {
      ...route.toFirestore(),
      'waypointStopIds': boardableStops.map((s) => s.stopId).toList(),
    };
    final docRef = await _firestore.collection('routes').add(data);
    return docRef.id;
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

  /// Overwrites one existing document in `routes`.
  ///
  /// Uses update() rather than set(): update() fails if the document
  /// has been deleted by another admin in the meantime, which is the
  /// correct outcome. set() would silently recreate a route somebody
  /// deliberately removed, and nothing would ever report that it had.
  ///
  /// [route.id] is ignored on purpose. The document id is the key in
  /// Firestore and is passed separately as [routeId]; writing it into
  /// the body as well would leave two copies that can drift apart.
  /// RouteModel.toFirestore() already omits it.
  ///
  /// DENORMALISATION NOTE — the mirror image of updateStop().
  /// A route stores `originStopName` and `destinationStopName` as
  /// copies of the stop names, so a student search costs one query
  /// instead of three. Those copies are rebuilt here from whichever
  /// StopModel the admin picked in the form, so changing a route's
  /// origin or destination DOES correct them. The hazard runs the
  /// other way: renaming a stop still does not rewrite the copies
  /// held by routes that point at it. The admin is warned about that
  /// in the stop edit form, and an automatic cascade is a Chapter 7
  /// item.
  ///
  /// WAYPOINT INDEX FIELD (D38, Task #10) — same `waypointStopIds`
  /// rebuild as createRoute, same reasoning, same FINAL-stop
  /// exclusion (see the comment there for why).
  Future<void> updateRoute(String routeId, RouteModel route) async {
    final sortedStops = [...route.stops]
      ..sort((a, b) => a.order.compareTo(b.order));
    final boardableStops = sortedStops.take(sortedStops.length - 1);

    final data = {
      ...route.toFirestore(),
      'waypointStopIds': boardableStops.map((s) => s.stopId).toList(),
    };
    await _firestore.collection('routes').doc(routeId).update(data);
  }

  /// Overwrites the editable fields of an existing stop document.
  /// Satisfies the "update" half of FR-07.
  ///
  /// Uses update(), not set(): update() fails with a not-found error
  /// if [stopId] no longer exists, while set() would silently create a
  /// brand-new document with that ID. Failing loudly is correct here —
  /// a stop the admin is editing must already exist.
  ///
  /// IMPORTANT — denormalisation: routes store originStopName and
  /// destinationStopName as copies of the stop's name, so that a
  /// search costs one query. Renaming a stop here does NOT rewrite
  /// those copies; the route cards keep showing the old name until an
  /// admin edits the route as well. This is a deliberate MVP
  /// simplification, logged for Ch.7 Future Work alongside the
  /// referential-integrity check in deleteStop.
  Future<void> updateStop(String stopId, StopModel stop) async {
    await _firestore
        .collection('stops')
        .doc(stopId)
        .update(stop.toFirestore());
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
    await _firestore
        .collection('stops')
        .doc(stopId)
        .update({'isActive': isActive});
  }

  /// Flips a route's isActive flag. Same admin-only enforcement,
  /// already covered by the existing rules.
  Future<void> setRouteActive(String routeId, bool isActive) async {
    await _firestore
        .collection('routes')
        .doc(routeId)
        .update({'isActive': isActive});
  }

  /// Returns EVERY active route regardless of origin, for the
  /// "Browse all routes" screen. Single equality filter on isActive
  /// — same reasoning as the old searchRoutesByOrigin, no composite
  /// index needed for this specific method.
  Future<RepoResult<List<RouteModel>>> getAllActiveRoutes() async {
    final snapshot = await _firestore
        .collection('routes')
        .where('isActive', isEqualTo: true)
        .get();

    return RepoResult(
      data: snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }

  /// Permanently deletes a stop document. This is a real delete, not
  /// a deactivation — there is no undo. The existing Security Rule
  /// `allow write: if isAdmin();` on /stops already covers delete
  /// (Firestore's "write" permission means create + update + delete
  /// together), so no rules changes were needed for this method.
  ///
  /// This does NOT check whether any route still references this
  /// stop's ID as an originStopId or destinationStopId — that check
  /// is a deliberate simplification for the MVP. Logged for Ch.7
  /// Future Work as "referential integrity checks before deletion".
  Future<void> deleteStop(String stopId) async {
    await _firestore.collection('stops').doc(stopId).delete();
  }

  /// Permanently deletes a route document. Same admin-only
  /// enforcement and same "no undo" warning as deleteStop.
  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('routes').doc(routeId).delete();
  }
}