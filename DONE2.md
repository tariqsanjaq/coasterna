# Fix — duplicate terminals in the STOPS timeline

The whole defect lived in the `_allStopNames` getter. It built the
timeline as `originStopName` + the sorted `stops` array +
`destinationStopName`, but `route.stops` already contains both
terminals — origin at order 0, destination last — so each end was
emitted twice.

Nothing downstream needed touching. `_buildStopsCard()` already derives
`lastIndex` from `names.length - 1` and passes
`isEndpoint: visibleIndexes[i] == 0 || visibleIndexes[i] == lastIndex`,
so the filled-vs-hollow dot and the bold label in `_StopRow` are keyed
to the first and last index of the sorted array rather than to separate
origin/destination widgets. Removing the stitched-on entries leaves that
treatment landing on the array's own terminals, which is what was asked
for.

One file changed. No other file was touched.

## Diff

```diff
diff --git a/lib/features/trip/presentation/trip_details_screen.dart b/lib/features/trip/presentation/trip_details_screen.dart
index 6b10db0..8141b2a 100644
--- a/lib/features/trip/presentation/trip_details_screen.dart
+++ b/lib/features/trip/presentation/trip_details_screen.dart
@@ -95,20 +95,24 @@ class TripDetailsScreen extends StatefulWidget {
 class _TripDetailsScreenState extends State<TripDetailsScreen> {
   bool _showAllStops = false;
 
-  /// The full ordered timeline: the route's origin, every embedded
-  /// waypoint in order, then the route's destination. The waypoints
-  /// array only ever holds the stops IN BETWEEN — origin and
-  /// destination live in their own RouteModel fields, not as entries
-  /// in the array, so they are stitched on at each end here.
+  /// The full ordered timeline, taken straight from the route's own
+  /// `stops` array sorted by `order`.
+  ///
+  /// That array already holds the terminals: origin at order 0 and
+  /// destination last, with the waypoints in between. Nothing is
+  /// stitched on at either end. Adding originStopName and
+  /// destinationStopName around it — which this getter used to do —
+  /// drew both terminals twice on every route.
+  ///
+  /// Sorting by `order` rather than trusting the stored array order
+  /// means a document edited by hand in the Firebase Console still
+  /// renders in sequence, and it is what makes the first and last
+  /// entries reliably the two terminals for the endpoint styling.
   List<String> get _allStopNames {
-    final sortedWaypoints = [...widget.route.stops]
+    final sortedStops = [...widget.route.stops]
       ..sort((a, b) => a.order.compareTo(b.order));
 
-    return [
-      widget.route.originStopName,
-      ...sortedWaypoints.map((s) => s.stopName),
-      widget.route.destinationStopName,
-    ];
+    return sortedStops.map((s) => s.stopName).toList();
   }
 
   Future<void> _openInMaps() async {
```

## flutter analyze

Full verbatim output:

```
Resolving dependencies...
Downloading packages...
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  record_use 0.6.0 (1.1.1 available)
  test_api 0.7.11 (0.7.13 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies!
9 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...

   info - Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' - lib\features\admin\presentation\admin_form_widgets.dart:236:9 - use_null_aware_elements
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\all_routes_screen.dart:110:35 - unnecessary_underscores
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\widgets\stop_picker_sheet.dart:134:33 - unnecessary_underscores

3 issues found. (ran in 43.3s)
```

The same 3 pre-existing info lints, no new ones. The command exits 1 on
those lints, as it did before this change.

## git log

Output of `git log --oneline -3`:

```
47c58c5 fix(trip): stop rendering origin and destination twice in the stops timeline
c0cd827 feat(admin): add route edit form, waypoint reordering, and every-day operating days
bea1de7 feat(admin): add an Edit entry to route rows
```

Committed, not pushed — no push was requested for this change.

## One thing worth a look, not changed

`route.originStopName` and `route.destinationStopName` are now unread by
this screen's timeline. They are still used by `_openInMaps()`, so
nothing is dead, but the two fields and the array's terminals are now
two copies of the same fact being displayed from different places. If a
route's origin is edited such that the array and the denormalised names
disagree, the timeline and the Maps link will disagree with each other.
That is pre-existing and out of scope here; flagging it rather than
touching it.

The app was not run.
