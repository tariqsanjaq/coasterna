# Gaith — student-facing UI fixes applied (2026-08-26)

Four already-approved fixes (D40, D41, D39, D39-secondary) applied to the
student-facing flow. Every fix was verified against the exact text on disk
BEFORE editing. No file outside the four named below was created, deleted, or
modified. No git write command was run.

**Summary**

| Fix | File | Exact-match check | Result |
|-----|------|-------------------|--------|
| 1 (D40) | `lib/features/search/presentation/search_results_placeholder.dart` | PASSED | Applied |
| 2A (D41) | `lib/features/search/presentation/widgets/route_status_badge.dart` | PASSED | Applied |
| 2B (D41) | `lib/features/search/presentation/widgets/route_status_badge.dart` | PASSED | Applied |
| 3 (D39) | `lib/features/trip/presentation/trip_details_screen.dart` | PASSED | Applied |
| 4 (D39 secondary) | `lib/features/search/presentation/all_routes_screen.dart` | N/A (no exact block specified) | Applied — no out-of-scope file touched |

`flutter analyze` → **3 issues, all pre-existing `info` lints, none introduced
by these fixes.** Full output at the end of this file.

---

## FIX 1 (D40) — show the destination on each search result card

**File touched:** `lib/features/search/presentation/search_results_placeholder.dart`

**Exact-match check: PASSED.**

The block specified in the task was found verbatim inside `_buildRouteCard`
(lines 223–236 of the pre-edit file). The only difference from the task text is
the base indentation: the task quoted the block at 4-space base indent, while
inside `_buildRouteCard`'s `Column.children` list the same block sits at
10-space base indent. The token sequence is otherwise character-for-character
identical, including the literal `·` escape (a real backslash in the
source, not the `·` character — confirmed byte-by-byte: `0x5c 0x75 0x30 0x30
0x42 0x37`).

**Diff actually applied:**

```diff
@@ -229,6 +229,15 @@ class _SearchResultsPlaceholderState extends State<SearchResultsPlaceholder> {
             ),
           ),
           const SizedBox(height: AppSpacing.xs),
+          Text(
+            'To: ${route.destinationStopName}',
+            style: const TextStyle(
+              color: AppColors.textSecondary,
+              fontWeight: FontWeight.w500,
+              fontSize: 12.5,
+            ),
+          ),
+          const SizedBox(height: AppSpacing.xs),
           Text(
             '${route.priceJD.toStringAsFixed(2)} JD'
                 ' · about ${route.durationMinutes} min',
```

Net effect: purely additive. The `Board at:` line and the price/duration line
are unchanged; a `To: <destinationStopName>` line and its spacer were inserted
between them. `AppColors.textSecondary` was already imported and in use in this
same file, so no new import was needed.

---

## FIX 2 (D41) — never show an empty badge on a SCHEDULED route with no `frequencyMinutes`

**File touched:** `lib/features/search/presentation/widgets/route_status_badge.dart`

### Part A — `_resolveStatus` fallback

**Exact-match check: PASSED.** Found verbatim at lines 161–169 of the pre-edit
file, including the closing brace of `_resolveStatus` and the closing brace of
`RouteStatusBadge`.

**Diff actually applied:**

```diff
@@ -162,9 +162,12 @@ class RouteStatusBadge extends StatelessWidget {
     if (wait != null) return _BadgeStyle.nextBus(wait);
 
     // Scheduled, inside operating hours, but frequencyMinutes is
-    // missing. Showing an invented time would mislead the student,
-    // so no badge is shown and the operating hours line stands alone.
-    return null;
+    // missing. We can't invent a wait time, so fall back to showing
+    // the operating-hours range instead of an empty card.
+    return _BadgeStyle.operatingHours(
+      formatTimeLabel(route.firstDeparture, now),
+      formatTimeLabel(route.lastDeparture, now),
+    );
   }
 }
```

### Part B — the new `_BadgeStyle.operatingHours` factory

**Exact-match check: PASSED.** Found verbatim at lines 202–209 of the pre-edit
file (the `firstBusAt` factory followed by a blank line and the opening of the
`whenFull` const).

**Diff actually applied:**

```diff
@@ -206,6 +209,14 @@ class _BadgeStyle {
     text: _greenText,
   );
 
+  factory _BadgeStyle.operatingHours(String first, String last) =>
+      _BadgeStyle(
+        label: '$first - $last',
+        background: _greenBackground,
+        border: _greenBorder,
+        text: _greenText,
+      );
+
   static const whenFull = _BadgeStyle(
     label: 'Departs when full',
     background: _amberBackground,
```

Notes on the resulting behaviour (observations, not changes):

- `formatTimeLabel` is already a top-level function in this same file and
  already used by the `firstBusAt` branch a few lines above, so no import or
  helper was added.
- `_resolveStatus` can still return `null` in principle (its return type is
  `_BadgeStyle?`), but with this change no code path inside it returns `null`
  any more. The `if (status == null) return const SizedBox.shrink();` guard in
  `build` was left exactly as it was — it is now unreachable but harmless, and
  removing it was not part of the approved fix.
- The green palette (`_greenBackground` / `_greenBorder` / `_greenText`) is
  reused as specified; no colour constants were added and `app_theme.dart` was
  not touched.

---

## FIX 3 (D39) — Maps link uses a search pin, not a directions route

**File touched:** `lib/features/trip/presentation/trip_details_screen.dart`

**Exact-match check: PASSED.** The whole `_openInMaps()` method was found
verbatim at lines 118–146 of the pre-edit file, Arabic comments included.

**Diff actually applied:**

```diff
@@ -116,19 +116,19 @@ class _TripDetailsScreenState extends State<TripDetailsScreen> {
   }
 
   Future<void> _openInMaps() async {
-    // تحديد نقطة البداية (إما الإحداثيات إذا توفرت أو اسم محطة الانطلاق)
-    final String originParam = widget.originStop != null
+    // نبني نص "query" لرابط الخرائط: إحداثيات دقيقة إذا توفرت (عند الدخول من
+    // نتائج البحث)، أو اسم المحطة كنص بحث إذا لم تتوفر الإحداثيات (عند الدخول
+    // من "Browse all routes"، حيث originStop يكون null حاليًا).
+    final String query = widget.originStop != null
         ? '${widget.originStop!.latitude},${widget.originStop!.longitude}'
         : widget.route.originStopName;
 
-    // تحديد نقطة النهاية (اسم المحطة النهائية للمسار)
-    final String destinationParam = widget.route.destinationStopName;
-
-    // استخدام رابط الاتجاهات (dir) بدلاً من البحث الفردي (search)
+    // صيغة "بحث" (دبوس واحد على الموقع) — وليس صيغة "اتجاهات". هذا يطابق
+    // الهدف الفعلي المطلوب: نُري الطالب أين تقع محطة الانطلاق، لا نحسب له
+    // طريقًا كاملًا من موقعه الحالي.
     final uri = Uri.parse(
-      'https://www.google.com/maps/dir/?api=1'
-          '&origin=${Uri.encodeComponent(originParam)}'
-          '&destination=${Uri.encodeComponent(destinationParam)}',
+      'https://www.google.com/maps/search/?api=1'
+          '&query=${Uri.encodeComponent(query)}',
     );
 
     var opened = false;
```

The `launchUrl` call, the `try`/`catch`, and the `Could not open Google Maps.`
SnackBar fallback below this hunk are byte-for-byte unchanged.

The emitted URL now matches the locked target format documented in `CLAUDE.md`
(`https://www.google.com/maps/search/?api=1&query=LAT,LON`, `url_launcher`
only, no `google_maps_flutter`).

---

## FIX 4 (D39, secondary) — pass the origin stop's coordinates from "Browse all routes" too

**File touched:** `lib/features/search/presentation/all_routes_screen.dart` — and
only that file.

**Exact-match check: N/A.** This fix specified behaviour, not a literal
find/replace block. The whole file was read first, as instructed.

**Pre-condition checks that decided whether to proceed (all cleared, so the fix
was NOT stopped):**

1. An existing repository method returning the active stops exists:
   `Future<RepoResult<List<StopModel>>> getAllStops()` at
   `lib/features/search/data/route_repository.dart:42`. It queries
   `stops` filtered to `isActive == true`, and is already used elsewhere in the
   app (`home_page.dart:139`, `widgets/stop_picker_sheet.dart:38`). No new
   repository method was added.
2. `RouteModel.originStopId` already exists
   (`lib/core/models/route_model.dart:96`) and `StopModel.id` already exists
   (`lib/core/models/stop_model.dart:6`), so nothing in `route_model.dart` or
   `route_repository.dart` needed changing.
3. `TripDetailsScreen` already accepts an optional `originStop`
   (`this.originStop`, type `StopModel?`), so no change was needed on the trip
   side either.

**Conclusion: no file outside `lib/features/search/presentation/` was edited by
this fix.** `route_repository.dart` and `route_model.dart` (Abdallah's files)
were read only, never written.

**Diff actually applied:**

```diff
@@ -1,5 +1,6 @@
 import 'package:flutter/material.dart';
 import '../../../core/models/route_model.dart';
+import '../../../core/models/stop_model.dart';
 import '../../../core/theme/app_theme.dart';
 import '../../../core/widgets/offline_banner.dart';
 import '../data/route_repository.dart';
@@ -24,6 +25,14 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
   List<RouteModel> _routes = [];
   bool _isOffline = false;
 
+  /// Active stops keyed by document id, so tapping a route card can
+  /// hand TripDetailsScreen the origin StopModel — and with it the
+  /// real latitude/longitude the Google Maps link needs. Loaded once
+  /// alongside the routes, using the repository's existing
+  /// getAllStops(). The search flow already passes its own fromStop,
+  /// so this map only serves the browse flow.
+  Map<String, StopModel> _stopsById = {};
+
   @override
   void initState() {
     super.initState();
@@ -34,9 +43,24 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
     setState(() => _state = _LoadState.loading);
     try {
       final result = await widget.repository.getAllActiveRoutes();
+
+      // Read separately and deliberately tolerant: if the stops read
+      // fails, the routes list still renders and TripDetailsScreen
+      // falls back to the stop name exactly as it did before.
+      Map<String, StopModel> stopsById = {};
+      try {
+        final stopsResult = await widget.repository.getAllStops();
+        stopsById = {
+          for (final stop in stopsResult.data) stop.id: stop,
+        };
+      } catch (_) {
+        stopsById = {};
+      }
+
       if (!mounted) return;
       setState(() {
         _routes = result.data;
+        _stopsById = stopsById;
         _isOffline = result.isFromCache;
 
         if (result.data.isNotEmpty) {
@@ -115,7 +139,10 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
                 onTap: () {
                   Navigator.of(context).push(
                     MaterialPageRoute(
-                      builder: (context) => TripDetailsScreen(route: route),
+                      builder: (context) => TripDetailsScreen(
+                        route: route,
+                        originStop: _stopsById[route.originStopId],
+                      ),
                     ),
                   );
                 },
```

Design notes on what was chosen and why:

- `getAllStops()` is called **once** per load of the browse screen, not once per
  card, exactly as specified. One extra Firestore read for the whole screen.
- The stops read is wrapped in its own `try`/`catch`. If it fails while the
  routes read succeeded, the browse list still renders and
  `_stopsById[route.originStopId]` simply returns `null` — which is the same
  input `TripDetailsScreen` received before this fix, so the Maps button
  degrades to the stop-name search it already did. Without this inner guard, a
  stops failure would have pushed the whole screen into `_LoadState.error` and
  hidden routes that had loaded fine, which would be a regression.
- `getAllStops()` returns active stops only. If a route's origin stop has been
  deactivated, the lookup misses and the name fallback applies — again, the
  pre-fix behaviour, never worse.
- No behavioural change to `search_results_placeholder.dart`'s navigation: it
  already passed `originStop: widget.fromStop`.

**A note on line endings (no code impact).** The repo checks these files out as
CRLF (`core.autocrlf=true`). An intermediate step of this task rewrote
`route_status_badge.dart` and `trip_details_screen.dart` with LF endings. That
was detected and reverted before finishing — all four files are back to `w/crlf`
per `git ls-files --eol`, so the only content in the working-tree diff is the
intended edits above.

---

## `flutter analyze` — full output

```
Resolving dependencies...
Downloading packages...
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  record_use 0.6.0 (1.1.1 available)
  test_api 0.7.11 (0.7.13 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies!
10 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...                                  

   info - Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' - lib\features\admin\presentation\admin_form_widgets.dart:236:9 - use_null_aware_elements
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\all_routes_screen.dart:134:35 - unnecessary_underscores
   info - Unnecessary use of multiple underscores. Try using '_' - lib\features\search\presentation\widgets\stop_picker_sheet.dart:134:33 - unnecessary_underscores

3 issues found. (ran in 4.5s)
```

**Zero errors, zero warnings. All 3 `info` lints are pre-existing and unrelated
to these fixes:**

- `admin_form_widgets.dart:236` — a file none of these fixes touched.
- `all_routes_screen.dart:134` — the `separatorBuilder: (_, __)` closure. This
  line existed before this task (it was line 110 pre-edit) and was not modified;
  it only shifted down by 24 lines because of the additions above it. Left
  as-is, since it is outside the approved scope of these four fixes.
- `stop_picker_sheet.dart:134` — a file none of these fixes touched.
