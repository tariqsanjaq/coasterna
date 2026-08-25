# D38 — Waypoint-aware origin search matching (review report)

**Author:** Abdalla Abufara
**Date:** 2026-08-25
**Scope:** `lib/features/search/data/route_repository.dart` only (per D38 Task #10 spec).

## Summary

Origin search matching was extended so `searchRoutesByOrigin` matches any stop along a
route (a waypoint), not just the official `originStopId`. This required:

1. A new derived index field, `waypointStopIds`, written to Firestore alongside every
   route document (computed from `route.stops`, never hand-authored, never the source
   of truth).
2. Changing the origin filter in `searchRoutesByOrigin` from an equality match on
   `originStopId` to an `arrayContains` match on `waypointStopIds`.

At the time this report was written, the working tree already contained this exact
change, applied to `lib/features/search/data/route_repository.dart` (uncommitted,
matching `git status` at session start). No further code edits were needed — the diff
below was captured via `git diff HEAD` against the last commit and reflects work already
done in this branch, verified here to match the D38 spec line for line.

## Diff applied to `route_repository.dart`

### `searchRoutesByOrigin`

**Before:**
```dart
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
  Future<RepoResult<List<RouteModel>>> searchRoutesByOrigin(
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

    return RepoResult(
      data: snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList(),
      isFromCache: snapshot.metadata.isFromCache,
    );
  }
```

**After:**
```dart
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
```

Note: the pre-existing code had no `order`/direction-comparison logic inside
`searchRoutesByOrigin` to preserve — direction (OUTBOUND vs RETURN) is not
disambiguated in this method either before or after the change. The `isActive` filter
and the optional `destinationStopId` filter are untouched, as required.

### `createRoute`

**Before:**
```dart
  /// Creates a new route document in Firestore. Same admin-only
  /// enforcement as createStop — via Security Rules, not this code.
  Future<String> createRoute(RouteModel route) async {
    final docRef =
    await _firestore.collection('routes').add(route.toFirestore());
    return docRef.id;
  }
```

**After:**
```dart
  /// Creates a new route document in Firestore. Same admin-only
  /// enforcement as createStop — via Security Rules, not this code.
  ///
  /// WAYPOINT INDEX FIELD (D38, Task #10) — `waypointStopIds` is a
  /// derived index field: a flat list of every stopId on this route,
  /// built here from `route.stops` right before the write. It exists
  /// ONLY so Firestore can run `array-contains` search queries — it is
  /// never the source of truth. `route.stops` stays the source of
  /// truth; if the two ever disagree, `stops` wins. This is added
  /// directly to the outgoing Map rather than inside RouteModel itself,
  /// so route_model.dart stays untouched.
  Future<String> createRoute(RouteModel route) async {
    final data = {
      ...route.toFirestore(),
      'waypointStopIds': route.stops.map((s) => s.stopId).toList(),
    };
    final docRef = await _firestore.collection('routes').add(data);
    return docRef.id;
  }
```

### `updateRoute`

**Before:**
```dart
  Future<void> updateRoute(String routeId, RouteModel route) async {
    await _firestore
        .collection('routes')
        .doc(routeId)
        .update(route.toFirestore());
  }
```

**After:**
```dart
  /// WAYPOINT INDEX FIELD (D38, Task #10) — same `waypointStopIds`
  /// rebuild as createRoute, same reasoning: derived from
  /// `route.stops`, never hand-edited, never the source of truth.
  Future<void> updateRoute(String routeId, RouteModel route) async {
    final data = {
      ...route.toFirestore(),
      'waypointStopIds': route.stops.map((s) => s.stopId).toList(),
    };
    await _firestore.collection('routes').doc(routeId).update(data);
  }
```

(Doc-comment-only wording tweaks elsewhere in the file — e.g. on
`getAllActiveRoutes` referring to "the old searchRoutesByOrigin" — are cosmetic and
not reproduced above; the full diff is available via `git diff HEAD -- lib/features/search/data/route_repository.dart`.)

`route_model.dart` was read for reference (per Step 1) but was **not modified** —
`waypointStopIds` is intentionally only ever added to the outgoing `Map` in the
repository layer, not to `RouteModel` itself, exactly as specified.

## `flutter analyze` output

```
Analyzing coasterna...

   info - Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' - lib\features\admin\presentation\admin_form_widgets.dart:236:9 - use_null_aware_elements
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\all_routes_screen.dart:110:35 - unnecessary_underscores
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\widgets\stop_picker_sheet.dart:134:33 - unnecessary_underscores

3 issues found. (ran in 2.0s)
```

All three findings are pre-existing `info`-level lints in unrelated files
(`admin_form_widgets.dart`, `all_routes_screen.dart`, `stop_picker_sheet.dart`).
**No errors or warnings were raised against `route_repository.dart`.**

## Composite-index error

**Not observed in this session.** No live query against `searchRoutesByOrigin` was
executed — see "Live verification" below for why. The doc comment on
`searchRoutesByOrigin` already anticipates this: an `arrayContains` filter combined
with an `isEqualTo` filter on `isActive` requires a Firestore composite index, and the
first live call is expected to fail with a `FAILED_PRECONDITION` error containing a
console link of the form `https://console.firebase.google.com/project/coasterna-fa940/firestore/indexes?create_composite=...`.

**This must still be captured from an actual run** (Android device/emulator or any
environment that can exercise the student search flow against the live
`coasterna-fa940` Firestore project) and the exact error text/link recorded here before
this item can be considered closed. Do not create the index proactively from the
console link without Tariq's confirmation, per the D38 task instructions.

## Live device / waypoint search verification

**Not performed — still required.** This environment only exposes three
`flutter devices` targets: `windows` (desktop), `chrome`, and `edge`. Per
`CLAUDE.md`, no Windows desktop target is supported or planned for this project, and
the web build routes exclusively to the Admin Dashboard (`kIsWeb` branch in
`main.dart`) — it does not expose the student search flow that calls
`searchRoutesByOrigin`. No Android device or emulator was available to this session.

Additionally, no local seed/sample data file exists in the repository for the four
route documents (route data lives only in the live `coasterna-fa940` Firestore
project), so a specific mid-route waypoint stop for an existing route could not be
identified from static inspection alone.

**Live device verification is still required**: run the app on an Android
device/emulator, pick a stop that is a mid-route waypoint (not the official
`originStopId`) for one of the four existing routes, and confirm the route now
appears in search results.

## Mandatory follow-up — re-save existing route documents

The four existing route documents in Firestore must each be re-opened and re-saved
through the Admin Dashboard edit form after this code is deployed, so they receive the
new waypointStopIds field. This does not happen automatically for documents that
already existed before this change — search for those four routes will silently stop
returning results otherwise.
