# "All routes" screen — spec page 14 fix (2026-08-29)

Step 1 findings are in `docs/all_routes_investigation_2026-08-29.md`.
Neither stop condition fired:

- The Route model already has `operatorName`, `durationMinutes` and
  `frequencyMinutes` — **no model or repository change**, so Abdallah's
  sign-off was not required.
- The navy AppBar was a **local override on this screen only**
  (`appTheme` defines no `appBarTheme` at all) — **`app_theme.dart` was not
  touched**, and no other screen changed.

## Files touched

| # | Full path | Change |
|---|---|---|
| 1 | `C:\Users\Tariq\coasterna_project\lib\features\search\presentation\all_routes_screen.dart` | AppBar restyled + route card rebuilt (only lib file modified) |
| 2 | `C:\Users\Tariq\coasterna_project\docs\all_routes_investigation_2026-08-29.md` | New — Step 1 investigation report |
| 3 | `C:\Users\Tariq\coasterna_project\docs\all_routes_fix_2026-08-29.md` | New — this report |

`lib/features/search/data/route_repository.dart` and `lib/main.dart` were
**not** opened for edit and are unchanged.

## What was changed in `all_routes_screen.dart`

1. **Import added:** `import 'widgets/route_status_badge.dart';` — the same
   `RouteStatusBadge` the Search Results cards use.
2. **AppBar** (was `backgroundColor: AppColors.primary` navy /
   `foregroundColor: AppColors.surface`, single-line title):
   now `backgroundColor: AppColors.background`,
   `foregroundColor: AppColors.textPrimary`, `elevation: 0`,
   `scrolledUnderElevation: 0`, `titleSpacing: 0`, and a two-line `Column`
   title — `All routes` (19px, w700) over a live count
   `"${_routes.length} active route(s)"` (12.5px, textSecondary), shown only
   in the `loaded` state. This is byte-for-byte the same AppBar recipe as
   `search_results_placeholder.dart:85-113`, so the two screens now match.
3. **Card extracted** out of the inline `itemBuilder` into
   `_buildRouteCard(RouteModel route)`. The `InkWell`, `borderRadius`,
   `onTap` → `TripDetailsScreen(route:, originStop: _stopsById[...])`
   navigation, the `_stopsById` lookup, offline banner, loading / empty /
   error states and `_loadRoutes()` are all unchanged.
4. **New card layout** (`Row` with a 3:2 `Expanded` split, so the right-hand
   column can never overflow on a narrow phone):
   - Left: route name (16px, w700) → operator subtitle (13px,
     textSecondary) → `"N min"` duration in
     `AppTextStyles.monoData(fontSize: 13.5)` — the exact style Search
     Results and `trip_details_screen.dart:383` already use for durations
     and prices.
   - Right, top: price moved here into a bordered chip —
     `BorderRadius.circular(AppRadius.chip)` (4px design token),
     `Border.all(color: AppColors.surfaceBorder)`, text in
     `AppTextStyles.monoData(fontSize: 13.5)`.
   - Right, under the price: frequency label, right-aligned, 12px w600 —
     `"Every N min"` in `AppColors.success` (#3B6D11) for SCHEDULED routes,
     `"Departs when full"` in `AppColors.warning` (#A66300) for WHEN_FULL.
   - Bottom: `RouteStatusBadge(route: route)` wrapped in
     `SizedBox(width: double.infinity)` so it spans the full card width.
     The badge widget itself is **reused unmodified** — same five states,
     same wording, same D41 operating-hours fallback for a SCHEDULED route
     with a missing `frequencyMinutes`.
   - Card corner radius left as `AppRadius.card` (12px) and the card border
     as `AppColors.surfaceBorder` — both already correct.
5. **Helpers added:** `_subtitleFor(route)` and `_buildFrequencyLabel(route)`
   (both private to the State class).

### Two judgement calls worth your review

- **`_subtitleFor` fallback.** The spec asks for the operator name on the
  subtitle line, and `RouteModel.operatorName` exists, so that is what the
  card shows. But the field is a plain non-null `String` that could still be
  empty in Firestore, so when it trims to empty the card falls back to
  `"Origin to Destination"` rather than rendering a blank row. Note the
  fallback joins with **"to"**, per the frozen terminology rule — the old
  code used `->`, which was off-spec.
- **Frequency label omitted, not faked, for SCHEDULED + null
  `frequencyMinutes`.** There is no interval to state, and inventing one
  would contradict the D41 logic. In that case the full-width status chip
  below already shows the `HH:MM - HH:MM` operating-hours range, so the card
  is never bare.

### Colour note (not changed — flagging for your call)

The task described the status chip as "light green bg / Success text" and
"light amber bg / Warning text". `RouteStatusBadge` uses its own greens
(`#2F6B37` text on `#E9F4EA`) and ambers (`#8A6D1B` on `#FDF4E0`), not the
`AppColors.success` / `AppColors.warning` tokens. Since the instruction was
to **reuse the exact widget from Search Results, not reimplement it**, I left
the badge untouched — changing its palette would change Search Results too.
The **frequency label**, which is new to this screen, does use the exact
`#3B6D11` / `#A66300` tokens as specified.

## Step 3.1 — `flutter analyze` (full, unedited output)

```
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.76 (1.3.77 available)
  cli_util 0.4.2 (0.6.0 available)
  clock 1.1.2 (1.1.3 available)
  cloud_firestore 6.8.0 (6.9.0 available)
  cloud_firestore_platform_interface 8.0.6 (8.0.7 available)
  cloud_firestore_web 5.7.2 (5.7.3 available)
  code_assets 1.2.1 (2.0.0 available)
  firebase_auth 6.5.7 (6.6.1 available)
  firebase_auth_platform_interface 9.0.6 (9.0.7 available)
  firebase_auth_web 6.2.6 (6.2.7 available)
  firebase_core 4.13.0 (4.14.0 available)
  firebase_core_platform_interface 8.1.0 (8.1.1 available)
  firebase_core_web 3.10.0 (3.11.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  pub_semver 2.2.0 (2.2.1 available)
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.27 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  test_api 0.7.11 (0.7.13 available)
  url_launcher_android 6.3.32 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...

No issues found! (ran in 2.6s)
```

**0 issues.**

## Step 3.2 — `flutter run` (full restart, not hot reload)

`flutter devices` found no Android device or emulator on this machine — only
Windows desktop, Chrome and Edge. Chrome/Edge are not usable for this check:
`main.dart` gates the home route on `kIsWeb`, so a web run lands on
`AdminLoginScreen` and never reaches the student "All routes" screen.
So the run target was **Windows desktop** (`kIsWeb == false` → student flow).

This was a cold `flutter run`, i.e. a fresh process and a full build, not a
hot reload of an already-running app.

```
$ flutter run -d windows
...
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib\main.dart on Windows in debug mode...
Building Windows application...                                    11.2s
√ Built build\windows\x64\runner\Debug\coasterna_project.exe
Syncing files to device Windows...                                 114ms

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on Windows is available at: http://127.0.0.1:54385/AYZoF8nUEQ4=/
The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:54385/AYZoF8nUEQ4=/devtools/?uri=ws://127.0.0.1:54385/AYZoF8nUEQ4=/ws
```

Built and launched with no compile errors and no runtime exceptions in the
run log. The app window is left open so you can navigate to the screen and
screenshot it. Note I did not drive the UI or look at the rendered pixels —
the list below is what the code now produces, not a visual sign-off.

## Step 3.3 — What to look for when you screenshot

Open the app → Home → **Browse all routes**. Compared with the previous
build, on that screen only:

1. The top bar is no longer a dark navy strip with white text. It is now the
   same cream page background (#F7F4EE) with dark title text, flat (no
   shadow or scroll elevation), matching the Search Results bar.
2. Under the "All routes" title there is a second, smaller grey line reading
   e.g. `12 active routes` — the number is `_routes.length`, the real loaded
   count, and it singularises to `1 active route`.
3. Each card's price is no longer bottom-right plain navy text. It is
   top-right, inside a thin-outlined 4px-corner chip, in IBM Plex Mono.
4. Under the route name, the `Origin -> Destination` line is replaced by the
   operator name (unless that route's `operatorName` is blank in Firestore,
   in which case you will see `Origin to Destination` — with the word "to",
   not an arrow).
5. A third left-hand line appears: the duration, e.g. `35 min`, in IBM Plex
   Mono.
6. Under the price chip, right-aligned: a green `Every N min` or an amber
   `Departs when full`. Routes that are SCHEDULED but have no
   `frequencyMinutes` show nothing here.
7. The `HH:MM - HH:MM` operating-hours text that used to sit bottom-left is
   gone from that position. In its place, across the **full width** of the
   card bottom, is a coloured status chip — the same one Search Results
   shows: green `Next bus in about X min` / `First bus at HH:MM` /
   `HH:MM - HH:MM`, amber `Departs when full` / `Service ended today`, red
   `No service today`.
8. Card corners, card border, list spacing, the offline banner and the tap
   target (still opens Trip Details) are unchanged.

I have not judged whether this matches the spec artwork — please compare the
screenshot against page 14 yourself.

---

# Round 2 — Fix 1 & Fix 2 (2026-08-29)

Two pixel-level corrections against spec page 14, on top of the Round 1 work
documented above.

- **Fix 1 — header colour.** The AppBar title and back arrow were rendering in
  plain dark text (`AppColors.textPrimary`). Both are now navy
  (`AppColors.primary`). The AppBar `backgroundColor` was left at
  `AppColors.background` exactly as Round 1 set it.
- **Fix 2 — WHEN_FULL wording, All Routes only.** `RouteStatusBadge` gained an
  optional `showWhenFullDetail` flag defaulting to `false`. When true *and* the
  resolved state is the amber WHEN_FULL state, the label reads
  `Departs when full - no fixed time`. All other states (green / red) are
  unaffected by the flag. Only the All Routes card passes `true`; Search
  Results does not pass it and therefore keeps the short `Departs when full`
  wording per spec page 7.

## Files touched in Round 2

| # | Full path |
|---|---|
| 1 | `C:\Users\Tariq\coasterna_project\lib\features\search\presentation\all_routes_screen.dart` |
| 2 | `C:\Users\Tariq\coasterna_project\lib\features\search\presentation\widgets\route_status_badge.dart` |

No other file was modified. `route_repository.dart`, `main.dart`,
`app_theme.dart` and `search_results_placeholder.dart` are all untouched.

## Correction to the Round 2 task brief

The brief said not to touch how `RouteStatusBadge` is instantiated in
`search_results_placeholder.dart` **or `trip_details_screen.dart`**. In fact
`trip_details_screen.dart` never instantiates `RouteStatusBadge` at all — there
were only ever two call sites, not three. See the grep in the previous section
of this round's verification.

## 1. `git diff` — full, unedited output

Command run:

```
git diff -- lib/features/search/presentation/all_routes_screen.dart lib/features/search/presentation/widgets/route_status_badge.dart
```

Note: Round 1 was never committed, so this diff is against the last commit
(`f081ce2`) and therefore shows **Round 1 and Round 2 changes combined**, not
Round 2 in isolation. The Round 2 hunks are the `foregroundColor` /
`color: AppColors.primary` lines and everything involving
`showWhenFullDetail` / `whenFullDetailed`.

```diff
warning: in the working copy of 'lib/features/search/presentation/all_routes_screen.dart', LF will be replaced by CRLF the next time Git touches it
diff --git a/lib/features/search/presentation/all_routes_screen.dart b/lib/features/search/presentation/all_routes_screen.dart
index eeb66b0..922428b 100644
--- a/lib/features/search/presentation/all_routes_screen.dart
+++ b/lib/features/search/presentation/all_routes_screen.dart
@@ -5,6 +5,7 @@ import '../../../core/theme/app_theme.dart';
 import '../../../core/widgets/offline_banner.dart';
 import '../data/route_repository.dart';
 import '../../trip/presentation/trip_details_screen.dart';
+import 'widgets/route_status_badge.dart';
 
 /// Browse screen — lists every active route without requiring the
 /// student to pick a "From" stop first. Reached from Home via the
@@ -82,9 +83,38 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
     return Scaffold(
       backgroundColor: AppColors.background,
       appBar: AppBar(
-        backgroundColor: AppColors.primary,
-        foregroundColor: AppColors.surface,
-        title: const Text('All routes'),
+        backgroundColor: AppColors.background,
+        // Navy title + back arrow on the plain background, per spec
+        // page 14. Only the foreground changes here — the background
+        // stays AppColors.background.
+        foregroundColor: AppColors.primary,
+        elevation: 0,
+        scrolledUnderElevation: 0,
+        titleSpacing: 0,
+        title: Column(
+          crossAxisAlignment: CrossAxisAlignment.start,
+          mainAxisSize: MainAxisSize.min,
+          children: [
+            const Text(
+              'All routes',
+              style: TextStyle(
+                fontSize: 19,
+                fontWeight: FontWeight.w700,
+                color: AppColors.primary,
+              ),
+            ),
+            if (_state == _LoadState.loaded)
+              Text(
+                '${_routes.length} active'
+                    ' ${_routes.length == 1 ? "route" : "routes"}',
+                style: const TextStyle(
+                  fontSize: 12.5,
+                  fontWeight: FontWeight.w400,
+                  color: AppColors.textSecondary,
+                ),
+              ),
+          ],
+        ),
       ),
       body: SafeArea(child: _buildBody()),
     );
@@ -146,59 +176,143 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
                     ),
                   );
                 },
-                child: Container(
-                  padding: const EdgeInsets.all(AppSpacing.lg),
-                  decoration: BoxDecoration(
-                    color: AppColors.surface,
-                    borderRadius: BorderRadius.circular(AppRadius.card),
-                    border: Border.all(color: AppColors.surfaceBorder),
-                  ),
-                  child: Column(
-                    crossAxisAlignment: CrossAxisAlignment.start,
-                    children: [
-                      Text(
-                        route.routeName,
-                        style: const TextStyle(
-                          fontSize: 16,
-                          fontWeight: FontWeight.w700,
-                          color: AppColors.textPrimary,
-                        ),
+                child: _buildRouteCard(route),
+              );
+            },
+          ),
+        ),
+      ],
+    );
+  }
+
+  /// One route card, matching page 14 of the certified spec: name,
+  /// operator and duration on the left; price chip and frequency
+  /// label on the right; a full-width status chip across the bottom.
+  Widget _buildRouteCard(RouteModel route) {
+    final frequencyLabel = _buildFrequencyLabel(route);
+
+    return Container(
+      padding: const EdgeInsets.all(AppSpacing.lg),
+      decoration: BoxDecoration(
+        color: AppColors.surface,
+        borderRadius: BorderRadius.circular(AppRadius.card),
+        border: Border.all(color: AppColors.surfaceBorder),
+      ),
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.start,
+            children: [
+              Expanded(
+                flex: 3,
+                child: Column(
+                  crossAxisAlignment: CrossAxisAlignment.start,
+                  children: [
+                    Text(
+                      route.routeName,
+                      style: const TextStyle(
+                        fontSize: 16,
+                        fontWeight: FontWeight.w700,
+                        color: AppColors.textPrimary,
                       ),
-                      const SizedBox(height: AppSpacing.xs),
-                      Text(
-                        '${route.originStopName} -> ${route.destinationStopName}',
-                        style: const TextStyle(color: AppColors.textSecondary),
+                    ),
+                    const SizedBox(height: AppSpacing.xs),
+                    Text(
+                      _subtitleFor(route),
+                      style: const TextStyle(
+                        color: AppColors.textSecondary,
+                        fontSize: 13,
                       ),
-                      const SizedBox(height: AppSpacing.md),
-                      Row(
-                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
-                        children: [
-                          Text(
-                            route.departureType == DepartureType.scheduled
-                                ? '${route.firstDeparture} - ${route.lastDeparture}'
-                                : 'Departs when full',
-                            style: const TextStyle(
-                              color: AppColors.textSecondary,
-                              fontSize: 13,
-                            ),
-                          ),
-                          Text(
-                            '${route.priceJD.toStringAsFixed(2)} JD',
-                            style: const TextStyle(
-                              color: AppColors.primary,
-                              fontWeight: FontWeight.w700,
-                            ),
-                          ),
-                        ],
+                    ),
+                    const SizedBox(height: AppSpacing.xs),
+                    Text(
+                      '${route.durationMinutes} min',
+                      style: AppTextStyles.monoData(fontSize: 13.5),
+                    ),
+                  ],
+                ),
+              ),
+              const SizedBox(width: AppSpacing.sm),
+              Expanded(
+                flex: 2,
+                child: Column(
+                  crossAxisAlignment: CrossAxisAlignment.end,
+                  children: [
+                    Container(
+                      padding: const EdgeInsets.symmetric(
+                        horizontal: AppSpacing.sm,
+                        vertical: AppSpacing.xs,
                       ),
+                      decoration: BoxDecoration(
+                        borderRadius: BorderRadius.circular(AppRadius.chip),
+                        border: Border.all(color: AppColors.surfaceBorder),
+                      ),
+                      child: Text(
+                        '${route.priceJD.toStringAsFixed(2)} JD',
+                        style: AppTextStyles.monoData(fontSize: 13.5),
+                      ),
+                    ),
+                    if (frequencyLabel != null) ...[
+                      const SizedBox(height: AppSpacing.xs),
+                      frequencyLabel,
                     ],
-                  ),
+                  ],
                 ),
-              );
-            },
+              ),
+            ],
           ),
-        ),
-      ],
+          const SizedBox(height: AppSpacing.md),
+          // Same badge widget the Search Results cards use, so the
+          // wording, the five states and the D41 operating-hours
+          // fallback stay identical across both screens. Stretched to
+          // the full card width per the spec.
+          SizedBox(
+            width: double.infinity,
+            child: RouteStatusBadge(
+              route: route,
+              showWhenFullDetail: true,
+            ),
+          ),
+        ],
+      ),
     );
   }
-}
\ No newline at end of file
+
+  /// Line under the route name. The spec asks for the operator here;
+  /// the origin -> destination line is kept as a fallback so a route
+  /// whose operatorName was left blank never shows an empty row.
+  String _subtitleFor(RouteModel route) {
+    final operatorName = route.operatorName.trim();
+    if (operatorName.isNotEmpty) return operatorName;
+    return '${route.originStopName} to ${route.destinationStopName}';
+  }
+
+  /// Right-aligned frequency line under the price chip. Null for a
+  /// SCHEDULED route with no frequencyMinutes - there is no interval
+  /// to state, and the status chip already shows the operating hours.
+  Widget? _buildFrequencyLabel(RouteModel route) {
+    final String label;
+    final Color color;
+
+    if (route.departureType == DepartureType.whenFull) {
+      label = 'Departs when full';
+      color = AppColors.warning;
+    } else {
+      final frequency = route.frequencyMinutes;
+      if (frequency == null || frequency <= 0) return null;
+      label = 'Every $frequency min';
+      color = AppColors.success;
+    }
+
+    return Text(
+      label,
+      textAlign: TextAlign.right,
+      style: TextStyle(
+        fontSize: 12,
+        fontWeight: FontWeight.w600,
+        color: color,
+      ),
+    );
+  }
+}
diff --git a/lib/features/search/presentation/widgets/route_status_badge.dart b/lib/features/search/presentation/widgets/route_status_badge.dart
index 32bbffa..69bafb4 100644
--- a/lib/features/search/presentation/widgets/route_status_badge.dart
+++ b/lib/features/search/presentation/widgets/route_status_badge.dart
@@ -109,10 +109,21 @@ int routeDepartureRank(RouteModel route, DateTime now) {
 /// telling the student at a glance whether this bus runs today and
 /// when it leaves. Implements all five states of the approved design.
 class RouteStatusBadge extends StatelessWidget {
-  const RouteStatusBadge({super.key, required this.route});
+  const RouteStatusBadge({
+    super.key,
+    required this.route,
+    this.showWhenFullDetail = false,
+  });
 
   final RouteModel route;
 
+  /// Opt-in to the longer "Departs when full - no fixed time" wording
+  /// for the amber WHEN_FULL state. Defaults to false because the
+  /// certified spec shows the short form on Search Results (page 7)
+  /// and the long form only on All Routes (page 14). No other state
+  /// is affected by this flag.
+  final bool showWhenFullDetail;
+
   @override
   Widget build(BuildContext context) {
     final status = _resolveStatus(DateTime.now());
@@ -145,7 +156,9 @@ class RouteStatusBadge extends StatelessWidget {
     if (!routeRunsToday(route, now)) return _BadgeStyle.noService;
 
     if (route.departureType != DepartureType.scheduled) {
-      return _BadgeStyle.whenFull;
+      return showWhenFullDetail
+          ? _BadgeStyle.whenFullDetailed
+          : _BadgeStyle.whenFull;
     }
 
     final first = parseTimeOnDay(route.firstDeparture, now);
@@ -224,6 +237,15 @@ class _BadgeStyle {
     text: _amberText,
   );
 
+  /// Same state and same colours as [whenFull], only spelled out in
+  /// full. Selected by RouteStatusBadge.showWhenFullDetail.
+  static const whenFullDetailed = _BadgeStyle(
+    label: 'Departs when full - no fixed time',
+    background: _amberBackground,
+    border: _amberBorder,
+    text: _amberText,
+  );
+
   static const serviceEnded = _BadgeStyle(
     label: 'Service ended today',
     background: _amberBackground,
```

## 2. Confirmation — `showWhenFullDetail: true` at the All Routes call site

**Confirmed: yes, it is present.** `grep -n "showWhenFullDetail"
lib/features/search/presentation/all_routes_screen.dart` returns exactly one
hit, line 274. The call site reads, verbatim, lines 268-277 of
`lib/features/search/presentation/all_routes_screen.dart`:

```dart
          // Same badge widget the Search Results cards use, so the
          // wording, the five states and the D41 operating-hours
          // fallback stay identical across both screens. Stretched to
          // the full card width per the spec.
          SizedBox(
            width: double.infinity,
            child: RouteStatusBadge(
              route: route,
              showWhenFullDetail: true,
            ),
          ),
```

For contrast, the Search Results call site is unchanged and passes no flag, so
it takes the `false` default —
`lib/features/search/presentation/search_results_placeholder.dart:247`:

```dart
          RouteStatusBadge(route: route),
```

## 3. Confirmation — AppBar title / icon colour now reads `AppColors.primary`

**Confirmed: yes, both the icon (via `foregroundColor`) and the title text
colour now read `AppColors.primary`.** Verbatim, lines 85-104 of
`lib/features/search/presentation/all_routes_screen.dart`:

```dart
      appBar: AppBar(
        backgroundColor: AppColors.background,
        // Navy title + back arrow on the plain background, per spec
        // page 14. Only the foreground changes here — the background
        // stays AppColors.background.
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'All routes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
```

The two decisive lines are:

- line 90 — `        foregroundColor: AppColors.primary,` (back arrow)
- line 103 — `                color: AppColors.primary,` (title text)

And the line that was deliberately **not** changed:

- line 86 — `        backgroundColor: AppColors.background,`

The subtitle count line below the title still reads
`color: AppColors.textSecondary` — the Round 2 brief scoped Fix 1 to the title
and back button only, so that was left alone. Flagging it in case the spec
wants it navy too.

## Round 2 verification results

- `flutter analyze` → **No issues found!** (ran in 6.8s), 0 issues.
- `flutter run -d windows` → cold full run, not a hot reload (the previous
  `flutter run` process was stopped first, since it holds a lock on the built
  `.exe`). Built in 16.5s,
  `√ Built build\windows\x64\runner\Debug\coasterna_project.exe`, synced and
  launched with no compile errors and no runtime exceptions in the run log.
  Visual result not judged here — that is for your screenshot.
- `grep -rn "RouteStatusBadge(" lib/`:

```
lib/features/search/presentation/all_routes_screen.dart:272:            child: RouteStatusBadge(
lib/features/search/presentation/search_results_placeholder.dart:247:          RouteStatusBadge(route: route),
lib/features/search/presentation/widgets/route_status_badge.dart:112:  const RouteStatusBadge({
```

Two call sites plus the constructor declaration. Only `all_routes_screen.dart`
passes `showWhenFullDetail: true`.

---

# Round 3 — badge width, price border, frequency pill (2026-08-29)

Three pixel-level corrections against spec page 14, on top of Round 1 and
Round 2 above. All changes are local to `all_routes_screen.dart` only, per
the task brief — `route_status_badge.dart` was opened **read-only** and
`search_results_placeholder.dart` was not opened at all.

## 0. Colour lookup in `route_status_badge.dart` (read-only)

Confirmed from `_BadgeStyle`'s private static constants:

| State | background | border | text |
|---|---|---|---|
| Green (Next bus / First bus / operating hours) | `0xFFE9F4EA` | `0xFFBFDCC2` | `0xFF2F6B37` |
| Amber (When full / Service ended) | `0xFFFDF4E0` | `0xFFE5D5A8` | `0xFF8A6D1B` |

The amber background guess in the brief (`#FDF4E0`) was exactly right. Both
values are `static const`, **private** to `_BadgeStyle` — not importable —
so Fix 3 below duplicates the two background hex values as local constants
in `all_routes_screen.dart`, with a comment pointing back at this table's
source. `route_status_badge.dart` itself was not modified in this round.

## Fix 1 — status badge no longer stretches full width

`Align(alignment: Alignment.centerLeft, ...)` replaced the
`SizedBox(width: double.infinity)` wrapper around `RouteStatusBadge`, so the
badge now hugs its own content width and stays left-aligned — matching
Search Results. (Plain removal without a wrapper would have let the `Row`
fall back to its own cross-axis default inside a `Column`, i.e. still
stretch, so the `Align` wrapper was needed, per the brief's fallback
instruction.) The stale doc comment above `_buildRouteCard` that said
"full-width status chip across the bottom" was also corrected to
"content-width status chip along the bottom" so the comment doesn't lie
about the layout it documents.

## Fix 2 — price chip border

`Border.all(color: AppColors.surfaceBorder)` →
`Border.all(color: AppColors.primary, width: 1.5)` on the price chip's
`BoxDecoration`. Background (none — chip was already unfilled) and the
`AppTextStyles.monoData(fontSize: 13.5)` text style are unchanged.

## Fix 3 — frequency label gets a pill background

`_buildFrequencyLabel` now wraps its `Text` in a `Container`:

```dart
return Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.xs,
  ),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppRadius.chip),
    color: background,
  ),
  child: Text(label, textAlign: TextAlign.right, style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color,
  )),
);
```

- Padding reuses `AppSpacing.sm` / `AppSpacing.xs` — the same constants the
  price chip already uses, so the two right-column chips share sizing.
- `background` is `_frequencyAmberBackground` (`0xFFFDF4E0`) for the
  WHEN_FULL case and `_frequencyGreenBackground` (`0xFFE9F4EA`) for the
  SCHEDULED case — both copied by value from the table in step 0 above, via
  two new file-level `const Color` constants in `all_routes_screen.dart`.
- Text colour/style (`AppColors.warning` / `AppColors.success`, 12px w600)
  is byte-for-byte unchanged from Round 1/2 — only the container is new.

This does **not** touch the Round 1 note under "Colour note (not
changed...)" above: that note was about the status badge's own palette
(`RouteStatusBadge`, untouched again this round), not the frequency label,
which was always specified to use `AppColors.success` / `AppColors.warning`
and still does.

## Files touched in Round 3

| # | Full path | Change |
|---|---|---|
| 1 | `C:\Users\Tariq\coasterna_project\lib\features\search\presentation\all_routes_screen.dart` | Fix 1 (badge alignment), Fix 2 (price border), Fix 3 (frequency pill) + two new private colour constants |
| 2 | `C:\Users\Tariq\coasterna_project\docs\all_routes_fix_2026-08-29.md` | This section |

`route_status_badge.dart` and `search_results_placeholder.dart` — **not
modified**. See verification step 4 below.

## 1. `flutter analyze` — full, unedited output

```
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.76 (1.3.77 available)
  cli_util 0.4.2 (0.6.0 available)
  clock 1.1.2 (1.1.3 available)
  cloud_firestore 6.8.0 (6.9.0 available)
  cloud_firestore_platform_interface 8.0.6 (8.0.7 available)
  cloud_firestore_web 5.7.2 (5.7.3 available)
  code_assets 1.2.1 (2.0.0 available)
  firebase_auth 6.5.7 (6.6.1 available)
  firebase_auth_platform_interface 9.0.6 (9.0.7 available)
  firebase_auth_web 6.2.6 (6.2.7 available)
  firebase_core 4.13.0 (4.14.0 available)
  firebase_core_platform_interface 8.1.0 (8.1.1 available)
  firebase_core_web 3.10.0 (3.11.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  pub_semver 2.2.0 (2.2.1 available)
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.27 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  test_api 0.7.11 (0.7.13 available)
  url_launcher_android 6.3.32 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...                                  
No issues found! (ran in 4.1s)
```

**0 issues.**

## 2. `flutter run` — full restart

`flutter devices` again found only Windows desktop, Chrome and Edge (no
Android emulator running). Same reasoning as Round 1: Chrome/Edge boot
straight to `AdminLoginScreen` under `kIsWeb`, so Windows desktop is the
only reachable target for the student "All routes" screen.

This was a cold `flutter run`, i.e. a fresh process and a full build, not a
hot reload of an already-running app. (A first attempt was terminated by an
over-cautious wrapper `timeout` before it produced output; the retry below is
the real result and shows the process was never actually stuck.)

```
$ flutter run -d windows
...
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib\main.dart on Windows in debug mode...
Building Windows application...                                    11.2s
√ Built build\windows\x64\runner\Debug\coasterna_project.exe
Syncing files to device Windows...                                 137ms

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on Windows is available at: http://127.0.0.1:61193/L6AKxnMwtyY=/
The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:61193/L6AKxnMwtyY=/devtools/?uri=ws://127.0.0.1:61193/L6AKxnMwtyY=/ws
```

Built and launched with no compile errors and no runtime exceptions in the
run log. The app window is left open so you can navigate to Home → Browse
all routes and check the three fixes against page 14 yourself — I did not
drive the UI or look at rendered pixels, only confirm the build is clean.

## 3. `git diff -- lib/features/search/presentation/all_routes_screen.dart` — full, unedited output

Note: like Round 2, this is against the last commit (`f081ce2`), so it shows
**Round 1 + Round 2 + Round 3 combined**, not Round 3 in isolation. The
Round-3-only hunks are: the new `import 'widgets/route_status_badge.dart';`
line was already present from Round 2 (unchanged this round); the two new
`_frequencyGreenBackground` / `_frequencyAmberBackground` constants; the
`SizedBox(width: double.infinity)` → `Align(...)` swap around the status
badge; the price chip's `Border.all` args; and `_buildFrequencyLabel`'s
`Text` → `Container(...)` wrap.

```diff
diff --git a/lib/features/search/presentation/all_routes_screen.dart b/lib/features/search/presentation/all_routes_screen.dart
index eeb66b0..8d4eaa8 100644
--- a/lib/features/search/presentation/all_routes_screen.dart
+++ b/lib/features/search/presentation/all_routes_screen.dart
@@ -5,6 +5,7 @@ import '../../../core/theme/app_theme.dart';
 import '../../../core/widgets/offline_banner.dart';
 import '../data/route_repository.dart';
 import '../../trip/presentation/trip_details_screen.dart';
+import 'widgets/route_status_badge.dart';
 
 /// Browse screen — lists every active route without requiring the
 /// student to pick a "From" stop first. Reached from Home via the
@@ -20,6 +21,14 @@ class AllRoutesScreen extends StatefulWidget {
 
 enum _LoadState { loading, loaded, empty, error }
 
+/// Pill backgrounds for the frequency label, copied by value from
+/// _BadgeStyle in widgets/route_status_badge.dart so the two chips on
+/// a card read as one family. They are duplicated rather than
+/// imported because _BadgeStyle's colours are private to that file,
+/// which this task must leave untouched.
+const Color _frequencyGreenBackground = Color(0xFFE9F4EA);
+const Color _frequencyAmberBackground = Color(0xFFFDF4E0);
+
 class _AllRoutesScreenState extends State<AllRoutesScreen> {
   _LoadState _state = _LoadState.loading;
   List<RouteModel> _routes = [];
@@ -82,9 +91,38 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
     return Scaffold(
       backgroundColor: AppColors.background,
       appBar: AppBar(
-        backgroundColor: AppColors.primary,
-        foregroundColor: AppColors.surface,
-        title: const Text('All routes'),
+        backgroundColor: AppColors.background,
+        // Navy title + back arrow on the plain background, per spec
+        // page 14. Only the foreground changes here — the background
+        // stays AppColors.background.
+        foregroundColor: AppColors.primary,
+        elevation: 0,
+        scrolledUnderElevation: 0,
+        titleSpacing: 0,
+        title: Column(
+          crossAxisAlignment: CrossAxisAlignment.start,
+          mainAxisSize: MainAxisSize.min,
+          children: [
+            const Text(
+              'All routes',
+              style: TextStyle(
+                fontSize: 19,
+                fontWeight: FontWeight.w700,
+                color: AppColors.primary,
+              ),
+            ),
+            if (_state == _LoadState.loaded)
+              Text(
+                '${_routes.length} active'
+                    ' ${_routes.length == 1 ? "route" : "routes"}',
+                style: const TextStyle(
+                  fontSize: 12.5,
+                  fontWeight: FontWeight.w400,
+                  color: AppColors.textSecondary,
+                ),
+              ),
+          ],
+        ),
       ),
       body: SafeArea(child: _buildBody()),
     );
@@ -146,59 +184,160 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
                     ),
                   );
                 },
-                child: Container(
-                  padding: const EdgeInsets.all(AppSpacing.lg),
-                  decoration: BoxDecoration(
-                    color: AppColors.surface,
-                    borderRadius: BorderRadius.circular(AppRadius.card),
-                    border: Border.all(color: AppColors.surfaceBorder),
-                  ),
-                  child: Column(
-                    crossAxisAlignment: CrossAxisAlignment.start,
-                    children: [
-                      Text(
-                        route.routeName,
-                        style: const TextStyle(
-                          fontSize: 16,
-                          fontWeight: FontWeight.w700,
-                          color: AppColors.textPrimary,
-                        ),
+                child: _buildRouteCard(route),
+              );
+            },
+          ),
+        ),
+      ],
+    );
+  }
+
+  /// One route card, matching page 14 of the certified spec: name,
+  /// operator and duration on the left; price chip and frequency
+  /// pill on the right; a content-width status chip along the bottom.
+  Widget _buildRouteCard(RouteModel route) {
+    final frequencyLabel = _buildFrequencyLabel(route);
+
+    return Container(
+      padding: const EdgeInsets.all(AppSpacing.lg),
+      decoration: BoxDecoration(
+        color: AppColors.surface,
+        borderRadius: BorderRadius.circular(AppRadius.card),
+        border: Border.all(color: AppColors.surfaceBorder),
+      ),
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.start,
+            children: [
+              Expanded(
+                flex: 3,
+                child: Column(
+                  crossAxisAlignment: CrossAxisAlignment.start,
+                  children: [
+                    Text(
+                      route.routeName,
+                      style: const TextStyle(
+                        fontSize: 16,
+                        fontWeight: FontWeight.w700,
+                        color: AppColors.textPrimary,
                       ),
-                      const SizedBox(height: AppSpacing.xs),
-                      Text(
-                        '${route.originStopName} -> ${route.destinationStopName}',
-                        style: const TextStyle(color: AppColors.textSecondary),
+                    ),
+                    const SizedBox(height: AppSpacing.xs),
+                    Text(
+                      _subtitleFor(route),
+                      style: const TextStyle(
+                        color: AppColors.textSecondary,
+                        fontSize: 13,
                       ),
-                      const SizedBox(height: AppSpacing.md),
-                      Row(
-                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
-                        children: [
-                          Text(
-                            route.departureType == DepartureType.scheduled
-                                ? '${route.firstDeparture} - ${route.lastDeparture}'
-                                : 'Departs when full',
-                            style: const TextStyle(
-                              color: AppColors.textSecondary,
-                              fontSize: 13,
-                            ),
-                          ),
-                          Text(
-                            '${route.priceJD.toStringAsFixed(2)} JD',
-                            style: const TextStyle(
-                              color: AppColors.primary,
-                              fontWeight: FontWeight.w700,
-                            ),
-                          ),
-                        ],
+                    ),
+                    const SizedBox(height: AppSpacing.xs),
+                    Text(
+                      '${route.durationMinutes} min',
+                      style: AppTextStyles.monoData(fontSize: 13.5),
+                    ),
+                  ],
+                ),
+              ),
+              const SizedBox(width: AppSpacing.sm),
+              Expanded(
+                flex: 2,
+                child: Column(
+                  crossAxisAlignment: CrossAxisAlignment.end,
+                  children: [
+                    Container(
+                      padding: const EdgeInsets.symmetric(
+                        horizontal: AppSpacing.sm,
+                        vertical: AppSpacing.xs,
                       ),
+                      decoration: BoxDecoration(
+                        borderRadius: BorderRadius.circular(AppRadius.chip),
+                        border: Border.all(
+                          color: AppColors.primary,
+                          width: 1.5,
+                        ),
+                      ),
+                      child: Text(
+                        '${route.priceJD.toStringAsFixed(2)} JD',
+                        style: AppTextStyles.monoData(fontSize: 13.5),
+                      ),
+                    ),
+                    if (frequencyLabel != null) ...[
+                      const SizedBox(height: AppSpacing.xs),
+                      frequencyLabel,
                     ],
-                  ),
+                  ],
                 ),
-              );
-            },
+              ),
+            ],
+          ),
+          const SizedBox(height: AppSpacing.md),
+          // Same badge widget the Search Results cards use, so the
+          // wording, the five states and the D41 operating-hours
+          // fallback stay identical across both screens. It hugs its
+          // own content width and sits left-aligned, exactly as it
+          // does on Search Results - never stretched full width.
+          Align(
+            alignment: Alignment.centerLeft,
+            child: RouteStatusBadge(
+              route: route,
+              showWhenFullDetail: true,
+            ),
           ),
+        ],
+      ),
+    );
+  }
+
+  /// Line under the route name. The spec asks for the operator here;
+  /// the origin -> destination line is kept as a fallback so a route
+  /// whose operatorName was left blank never shows an empty row.
+  String _subtitleFor(RouteModel route) {
+    final operatorName = route.operatorName.trim();
+    if (operatorName.isNotEmpty) return operatorName;
+    return '${route.originStopName} to ${route.destinationStopName}';
+  }
+
+  /// Right-aligned frequency line under the price chip. Null for a
+  /// SCHEDULED route with no frequencyMinutes - there is no interval
+  /// to state, and the status chip already shows the operating hours.
+  Widget? _buildFrequencyLabel(RouteModel route) {
+    final String label;
+    final Color color;
+    final Color background;
+
+    if (route.departureType == DepartureType.whenFull) {
+      label = 'Departs when full';
+      color = AppColors.warning;
+      background = _frequencyAmberBackground;
+    } else {
+      final frequency = route.frequencyMinutes;
+      if (frequency == null || frequency <= 0) return null;
+      label = 'Every $frequency min';
+      color = AppColors.success;
+      background = _frequencyGreenBackground;
+    }
+
+    return Container(
+      padding: const EdgeInsets.symmetric(
+        horizontal: AppSpacing.sm,
+        vertical: AppSpacing.xs,
+      ),
+      decoration: BoxDecoration(
+        borderRadius: BorderRadius.circular(AppRadius.chip),
+        color: background,
+      ),
+      child: Text(
+        label,
+        textAlign: TextAlign.right,
+        style: TextStyle(
+          fontSize: 12,
+          fontWeight: FontWeight.w600,
+          color: color,
         ),
-      ],
+      ),
     );
   }
-}
\ No newline at end of file
+}
```

## 4. Confirmation — the other two files are untouched

```
$ git status --short
 M lib/features/search/presentation/all_routes_screen.dart
 M lib/features/search/presentation/widgets/route_status_badge.dart
 ...(untracked docs/*.md, unrelated to this task)
```

`route_status_badge.dart` shows as modified — but `git diff` against it
confirms that diff is **entirely the pre-existing Round 2 change**
(`showWhenFullDetail` param + `whenFullDetailed` style, see the Round 2
diff above), with zero new hunks from Round 3:

```diff
diff --git a/lib/features/search/presentation/widgets/route_status_badge.dart b/lib/features/search/presentation/widgets/route_status_badge.dart
index 32bbffa..69bafb4 100644
--- a/lib/features/search/presentation/widgets/route_status_badge.dart
+++ b/lib/features/search/presentation/widgets/route_status_badge.dart
@@ -109,10 +109,21 @@ int routeDepartureRank(RouteModel route, DateTime now) {
 /// telling the student at a glance whether this bus runs today and
 /// when it leaves. Implements all five states of the approved design.
 class RouteStatusBadge extends StatelessWidget {
-  const RouteStatusBadge({super.key, required this.route});
+  const RouteStatusBadge({
+    super.key,
+    required this.route,
+    this.showWhenFullDetail = false,
+  });
 
   final RouteModel route;
 
+  /// Opt-in to the longer "Departs when full - no fixed time" wording
+  /// for the amber WHEN_FULL state. Defaults to false because the
+  /// certified spec shows the short form on Search Results (page 7)
+  /// and the long form only on All Routes (page 14). No other state
+  /// is affected by this flag.
+  final bool showWhenFullDetail;
+
   @override
   Widget build(BuildContext context) {
     final status = _resolveStatus(DateTime.now());
@@ -145,7 +156,9 @@ class RouteStatusBadge extends StatelessWidget {
     if (!routeRunsToday(route, now)) return _BadgeStyle.noService;
 
     if (route.departureType != DepartureType.scheduled) {
-      return _BadgeStyle.whenFull;
+      return showWhenFullDetail
+          ? _BadgeStyle.whenFullDetailed
+          : _BadgeStyle.whenFull;
     }
 
     final first = parseTimeOnDay(route.firstDeparture, now);
@@ -224,6 +237,15 @@ class _BadgeStyle {
     text: _amberText,
   );
 
+  /// Same state and same colours as [whenFull], only spelled out in
+  /// full. Selected by RouteStatusBadge.showWhenFullDetail.
+  static const whenFullDetailed = _BadgeStyle(
+    label: 'Departs when full - no fixed time',
+    background: _amberBackground,
+    border: _amberBorder,
+    text: _amberText,
+  );
+
   static const serviceEnded = _BadgeStyle(
     label: 'Service ended today',
     background: _amberBackground,
```

`search_results_placeholder.dart`:

```
$ git diff -- lib/features/search/presentation/search_results_placeholder.dart
(no output — identical to HEAD)
```

Both confirmed untouched by Round 3, as required.

---

# Round 4 — frequency label / duration row alignment (2026-08-30)

One pixel-level correction against spec page 14, on top of Rounds 1-3
above. `Get-Date` confirmed the actual session date is **2026-08-30**, not
2026-08-29 as in the old filenames the running log lives under — this
section is dated correctly regardless of the file's name.

## Root cause

`_buildRouteCard` built two independent `Column`s side by side in one
`Row`: the left column had three lines (route name, operator subtitle,
duration), the right column only two (price chip, frequency label). With
both columns top-aligned, the frequency label landed level with the
*operator* line instead of the *duration* line — one row too high versus
spec page 14, where `Every 20 min` sits exactly level with `35 min`.

## Fix

Replaced the single two-column `Row` with three explicit row-pairs, each
holding one left line and its right counterpart, so they can never drift
out of level with each other:

- Row 1: route name (`Expanded`) + price chip.
- Row 2: operator subtitle (`Expanded`) + `SizedBox.shrink()`.
- Row 3: duration (`Expanded`) + frequency label, or `SizedBox.shrink()`
  when `_buildFrequencyLabel` returns null.

Each `Row` uses `CrossAxisAlignment.center` so the price chip's extra
height (it has padding + a border) doesn't pull the route-name text off
centre. The same `AppSpacing.xs` vertical gaps from before now sit
*between* the three rows instead of inside a single column. Colors, fonts,
and the `Align`-wrapped `RouteStatusBadge` below are byte-for-byte
unchanged — only the row/column structure moved.

One deliberate simplification versus the original: the previous `flex: 3` /
`flex: 2` split on the two columns is gone. Each row now has exactly one
`Expanded` child (the left text), so any flex ratio would resolve to the
same "take all remaining space" result — the right-hand item (price chip /
frequency pill / `SizedBox.shrink()`) always renders at its natural width,
pinned to the row's right edge, exactly as `CrossAxisAlignment.end` did
inside the old two-column layout.

## Files touched in Round 4

| # | Full path | Change |
|---|---|---|
| 1 | `C:\Users\Tariq\coasterna_project\lib\features\search\presentation\all_routes_screen.dart` | `_buildRouteCard`'s top `Row` replaced with three row-pairs |
| 2 | `C:\Users\Tariq\coasterna_project\docs\audit-trail\all_routes_fix_2026-08-29.md` | This section (also: file moved to `docs/audit-trail/` in the same session — see the accompanying docs-reorg note) |

`route_status_badge.dart` and `search_results_placeholder.dart` — **not
modified**, confirmed again below.

## 1. `Get-Date` — actual session date

```
Sunday, August 30, 2026 7:42:09 AM
```

Used as **2026-08-30** for this section's heading, per the task's explicit
instruction not to copy 2026-08-29 forward from old filenames.

## 2. `flutter analyze` — full, unedited output

```
Resolving dependencies...
Downloading packages...
  _flutterfire_internals 1.3.76 (1.3.77 available)
  cli_util 0.4.2 (0.6.0 available)
  clock 1.1.2 (1.1.3 available)
  cloud_firestore 6.8.0 (6.9.0 available)
  cloud_firestore_platform_interface 8.0.6 (8.0.7 available)
  cloud_firestore_web 5.7.2 (5.7.3 available)
  code_assets 1.2.1 (2.0.0 available)
  firebase_auth 6.5.7 (6.6.1 available)
  firebase_auth_platform_interface 9.0.6 (9.0.7 available)
  firebase_auth_web 6.2.6 (6.2.7 available)
  firebase_core 4.13.0 (4.14.0 available)
  firebase_core_platform_interface 8.1.0 (8.1.1 available)
  firebase_core_web 3.10.0 (3.11.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  hooks 2.0.2 (2.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.5.0 (9.6.0 available)
  pub_semver 2.2.0 (2.2.1 available)
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.27 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  test_api 0.7.11 (0.7.13 available)
  url_launcher_android 6.3.32 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing coasterna_project...                                  
No issues found! (ran in 55.6s)
```

## 3. `flutter run` — full restart

```
$ flutter run -d windows
...
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib\main.dart on Windows in debug mode...
Building Windows application...                                    12.7s
√ Built build\windows\x64\runner\Debug\coasterna_project.exe
unner\Debug\coasterna_project.exe
unner\Debug\coasterna_project.exe
Syncing files to device Windows...                                  60ms

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on Windows is available at: http://127.0.0.1:55139/V0oJeqhS1K4=/
The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:55139/V0oJeqhS1K4=/devtools/?uri=ws://127.0.0.1:55139/V0oJeqhS1K4=/ws
```

Cold `flutter run` (fresh process, full build, not a hot reload of an
already-running app). Built and launched with no compile errors and no
runtime exceptions in the run log.

## 4. `git diff -- lib/features/search/presentation/all_routes_screen.dart`

```diff
diff --git a/lib/features/search/presentation/all_routes_screen.dart b/lib/features/search/presentation/all_routes_screen.dart
index eeb66b0..0c0b943 100644
--- a/lib/features/search/presentation/all_routes_screen.dart
+++ b/lib/features/search/presentation/all_routes_screen.dart
@@ -5,6 +5,7 @@ import '../../../core/theme/app_theme.dart';
 import '../../../core/widgets/offline_banner.dart';
 import '../data/route_repository.dart';
 import '../../trip/presentation/trip_details_screen.dart';
+import 'widgets/route_status_badge.dart';
 
 /// Browse screen — lists every active route without requiring the
 /// student to pick a "From" stop first. Reached from Home via the
@@ -20,6 +21,14 @@ class AllRoutesScreen extends StatefulWidget {
 
 enum _LoadState { loading, loaded, empty, error }
 
+/// Pill backgrounds for the frequency label, copied by value from
+/// _BadgeStyle in widgets/route_status_badge.dart so the two chips on
+/// a card read as one family. They are duplicated rather than
+/// imported because _BadgeStyle's colours are private to that file,
+/// which this task must leave untouched.
+const Color _frequencyGreenBackground = Color(0xFFE9F4EA);
+const Color _frequencyAmberBackground = Color(0xFFFDF4E0);
+
 class _AllRoutesScreenState extends State<AllRoutesScreen> {
   _LoadState _state = _LoadState.loading;
   List<RouteModel> _routes = [];
@@ -82,9 +91,38 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
     return Scaffold(
       backgroundColor: AppColors.background,
       appBar: AppBar(
-        backgroundColor: AppColors.primary,
-        foregroundColor: AppColors.surface,
-        title: const Text('All routes'),
+        backgroundColor: AppColors.background,
+        // Navy title + back arrow on the plain background, per spec
+        // page 14. Only the foreground changes here — the background
+        // stays AppColors.background.
+        foregroundColor: AppColors.primary,
+        elevation: 0,
+        scrolledUnderElevation: 0,
+        titleSpacing: 0,
+        title: Column(
+          crossAxisAlignment: CrossAxisAlignment.start,
+          mainAxisSize: MainAxisSize.min,
+          children: [
+            const Text(
+              'All routes',
+              style: TextStyle(
+                fontSize: 19,
+                fontWeight: FontWeight.w700,
+                color: AppColors.primary,
+              ),
+            ),
+            if (_state == _LoadState.loaded)
+              Text(
+                '${_routes.length} active'
+                    ' ${_routes.length == 1 ? "route" : "routes"}',
+                style: const TextStyle(
+                  fontSize: 12.5,
+                  fontWeight: FontWeight.w400,
+                  color: AppColors.textSecondary,
+                ),
+              ),
+          ],
+        ),
       ),
       body: SafeArea(child: _buildBody()),
     );
@@ -146,54 +184,7 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
                     ),
                   );
                 },
-                child: Container(
-                  padding: const EdgeInsets.all(AppSpacing.lg),
-                  decoration: BoxDecoration(
-                    color: AppColors.surface,
-                    borderRadius: BorderRadius.circular(AppRadius.card),
-                    border: Border.all(color: AppColors.surfaceBorder),
-                  ),
-                  child: Column(
-                    crossAxisAlignment: CrossAxisAlignment.start,
-                    children: [
-                      Text(
-                        route.routeName,
-                        style: const TextStyle(
-                          fontSize: 16,
-                          fontWeight: FontWeight.w700,
-                          color: AppColors.textPrimary,
-                        ),
-                      ),
-                      const SizedBox(height: AppSpacing.xs),
-                      Text(
-                        '${route.originStopName} -> ${route.destinationStopName}',
-                        style: const TextStyle(color: AppColors.textSecondary),
-                      ),
-                      const SizedBox(height: AppSpacing.md),
-                      Row(
-                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
-                        children: [
-                          Text(
-                            route.departureType == DepartureType.scheduled
-                                ? '${route.firstDeparture} - ${route.lastDeparture}'
-                                : 'Departs when full',
-                            style: const TextStyle(
-                              color: AppColors.textSecondary,
-                              fontSize: 13,
-                            ),
-                          ),
-                          Text(
-                            '${route.priceJD.toStringAsFixed(2)} JD',
-                            style: const TextStyle(
-                              color: AppColors.primary,
-                              fontWeight: FontWeight.w700,
-                            ),
-                          ),
-                        ],
-                      ),
-                    ],
-                  ),
-                ),
+                child: _buildRouteCard(route),
               );
             },
           ),
@@ -201,4 +192,149 @@ class _AllRoutesScreenState extends State<AllRoutesScreen> {
       ],
     );
   }
-}
\ No newline at end of file
+
+  /// One route card, matching page 14 of the certified spec: name,
+  /// operator and duration on the left; price chip and frequency
+  /// pill on the right; a content-width status chip along the bottom.
+  Widget _buildRouteCard(RouteModel route) {
+    final frequencyLabel = _buildFrequencyLabel(route);
+
+    return Container(
+      padding: const EdgeInsets.all(AppSpacing.lg),
+      decoration: BoxDecoration(
+        color: AppColors.surface,
+        borderRadius: BorderRadius.circular(AppRadius.card),
+        border: Border.all(color: AppColors.surfaceBorder),
+      ),
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.center,
+            children: [
+              Expanded(
+                child: Text(
+                  route.routeName,
+                  style: const TextStyle(
+                    fontSize: 16,
+                    fontWeight: FontWeight.w700,
+                    color: AppColors.textPrimary,
+                  ),
+                ),
+              ),
+              const SizedBox(width: AppSpacing.sm),
+              Container(
+                padding: const EdgeInsets.symmetric(
+                  horizontal: AppSpacing.sm,
+                  vertical: AppSpacing.xs,
+                ),
+                decoration: BoxDecoration(
+                  borderRadius: BorderRadius.circular(AppRadius.chip),
+                  border: Border.all(color: AppColors.primary, width: 1.5),
+                ),
+                child: Text(
+                  '${route.priceJD.toStringAsFixed(2)} JD',
+                  style: AppTextStyles.monoData(fontSize: 13.5),
+                ),
+              ),
+            ],
+          ),
+          const SizedBox(height: AppSpacing.xs),
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.center,
+            children: [
+              Expanded(
+                child: Text(
+                  _subtitleFor(route),
+                  style: const TextStyle(
+                    color: AppColors.textSecondary,
+                    fontSize: 13,
+                  ),
+                ),
+              ),
+              const SizedBox(width: AppSpacing.sm),
+              const SizedBox.shrink(),
+            ],
+          ),
+          const SizedBox(height: AppSpacing.xs),
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.center,
+            children: [
+              Expanded(
+                child: Text(
+                  '${route.durationMinutes} min',
+                  style: AppTextStyles.monoData(fontSize: 13.5),
+                ),
+              ),
+              const SizedBox(width: AppSpacing.sm),
+              frequencyLabel ?? const SizedBox.shrink(),
+            ],
+          ),
+          const SizedBox(height: AppSpacing.md),
+          // Same badge widget the Search Results cards use, so the
+          // wording, the five states and the D41 operating-hours
+          // fallback stay identical across both screens. It hugs its
+          // own content width and sits left-aligned, exactly as it
+          // does on Search Results - never stretched full width.
+          Align(
+            alignment: Alignment.centerLeft,
+            child: RouteStatusBadge(
+              route: route,
+              showWhenFullDetail: true,
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+
+  /// Line under the route name. The spec asks for the operator here;
+  /// the origin -> destination line is kept as a fallback so a route
+  /// whose operatorName was left blank never shows an empty row.
+  String _subtitleFor(RouteModel route) {
+    final operatorName = route.operatorName.trim();
+    if (operatorName.isNotEmpty) return operatorName;
+    return '${route.originStopName} to ${route.destinationStopName}';
+  }
+
+  /// Right-aligned frequency line under the price chip. Null for a
+  /// SCHEDULED route with no frequencyMinutes - there is no interval
+  /// to state, and the status chip already shows the operating hours.
+  Widget? _buildFrequencyLabel(RouteModel route) {
+    final String label;
+    final Color color;
+    final Color background;
+
+    if (route.departureType == DepartureType.whenFull) {
+      label = 'Departs when full';
+      color = AppColors.warning;
+      background = _frequencyAmberBackground;
+    } else {
+      final frequency = route.frequencyMinutes;
+      if (frequency == null || frequency <= 0) return null;
+      label = 'Every $frequency min';
+      color = AppColors.success;
+      background = _frequencyGreenBackground;
+    }
+
+    return Container(
+      padding: const EdgeInsets.symmetric(
+        horizontal: AppSpacing.sm,
+        vertical: AppSpacing.xs,
+      ),
+      decoration: BoxDecoration(
+        borderRadius: BorderRadius.circular(AppRadius.chip),
+        color: background,
+      ),
+      child: Text(
+        label,
+        textAlign: TextAlign.right,
+        style: TextStyle(
+          fontSize: 12,
+          fontWeight: FontWeight.w600,
+          color: color,
+        ),
+      ),
+    );
+  }
+}
```

## 5. `git status --short` — confirming renames, not delete+add

```
$ git status --short
R  docs/abdallah-d38-search-matching-review.md -> docs/audit-trail/abdallah-d38-search-matching-review.md
R  docs/design-audit-2026-08-22.md -> docs/audit-trail/design-audit-2026-08-22.md
R  docs/fr10-code-review-input.md -> docs/audit-trail/fr10-code-review-input.md
R  docs/fr10-fix-verification.md -> docs/audit-trail/fr10-fix-verification.md
R  docs/security-rules-verification.md -> docs/audit-trail/security-rules-verification.md
 M lib/features/search/presentation/all_routes_screen.dart
 M lib/features/search/presentation/widgets/route_status_badge.dart
?? docs/audit-trail/about_entry_point_investigation_2026-08-29.md
?? docs/audit-trail/all_routes_fix_2026-08-29.md
?? docs/audit-trail/all_routes_investigation_2026-08-29.md
?? docs/audit-trail/gaith-fix-context-2026-08-26.md
?? docs/audit-trail/gaith-fixes-2026-08-26-applied.md
?? docs/audit-trail/main_dart_review_2026-08-29.md
?? docs/audit-trail/project-gap-audit.md
?? docs/audit-trail/task14_audit_2026-08-29.md
?? docs/audit-trail/task14_fix_verification_2026-08-29.md
```

Every one of the 14 audit-trail files shows as **`R`** (rename) when it was
already tracked (5 files: `abdallah-d38-search-matching-review.md`,
`design-audit-2026-08-22.md`, `fr10-code-review-input.md`,
`fr10-fix-verification.md`, `security-rules-verification.md`) — confirming
`git mv` preserved rename tracking as required. The other 9 files show as
`??` (untracked) **at their new path only** — these were already untracked
before this session (never committed), so there is nothing in git's index
for a rename to pair against; a plain `mv` was the correct tool for them,
not a tracking failure. `lib/features/search/presentation/all_routes_screen.dart`
and `lib/features/search/presentation/widgets/route_status_badge.dart` are
the only modified (`M`) files, both accounted for above.

## 6. Confirmation — `route_status_badge.dart` / `search_results_placeholder.dart` untouched

`search_results_placeholder.dart`:

```
$ git diff -- lib/features/search/presentation/search_results_placeholder.dart
(no output — identical to HEAD)
```

`route_status_badge.dart` shows as modified in `git status`, but its diff
against HEAD is **still exactly the pre-existing Round 2 change**
(`showWhenFullDetail` param + `whenFullDetailed` style) — zero new hunks
from Round 4:

```diff
diff --git a/lib/features/search/presentation/widgets/route_status_badge.dart b/lib/features/search/presentation/widgets/route_status_badge.dart
index 32bbffa..69bafb4 100644
--- a/lib/features/search/presentation/widgets/route_status_badge.dart
+++ b/lib/features/search/presentation/widgets/route_status_badge.dart
@@ -109,10 +109,21 @@ int routeDepartureRank(RouteModel route, DateTime now) {
 /// telling the student at a glance whether this bus runs today and
 /// when it leaves. Implements all five states of the approved design.
 class RouteStatusBadge extends StatelessWidget {
-  const RouteStatusBadge({super.key, required this.route});
+  const RouteStatusBadge({
+    super.key,
+    required this.route,
+    this.showWhenFullDetail = false,
+  });
 
   final RouteModel route;
 
+  /// Opt-in to the longer "Departs when full - no fixed time" wording
+  /// for the amber WHEN_FULL state. Defaults to false because the
+  /// certified spec shows the short form on Search Results (page 7)
+  /// and the long form only on All Routes (page 14). No other state
+  /// is affected by this flag.
+  final bool showWhenFullDetail;
+
   @override
   Widget build(BuildContext context) {
     final status = _resolveStatus(DateTime.now());
@@ -145,7 +156,9 @@ class RouteStatusBadge extends StatelessWidget {
     if (!routeRunsToday(route, now)) return _BadgeStyle.noService;
 
     if (route.departureType != DepartureType.scheduled) {
-      return _BadgeStyle.whenFull;
+      return showWhenFullDetail
+          ? _BadgeStyle.whenFullDetailed
+          : _BadgeStyle.whenFull;
     }
 
     final first = parseTimeOnDay(route.firstDeparture, now);
@@ -224,6 +237,15 @@ class _BadgeStyle {
     text: _amberText,
   );
 
+  /// Same state and same colours as [whenFull], only spelled out in
+  /// full. Selected by RouteStatusBadge.showWhenFullDetail.
+  static const whenFullDetailed = _BadgeStyle(
+    label: 'Departs when full - no fixed time',
+    background: _amberBackground,
+    border: _amberBorder,
+    text: _amberText,
+  );
+
   static const serviceEnded = _BadgeStyle(
     label: 'Service ended today',
     background: _amberBackground,
```

Both confirmed untouched by Round 4, as required.

## Final folder listing

`docs/`:

```
audit-trail/
data-model.md
```

`docs/audit-trail/`:

```
abdallah-d38-search-matching-review.md
about_entry_point_investigation_2026-08-29.md
all_routes_fix_2026-08-29.md
all_routes_investigation_2026-08-29.md
design-audit-2026-08-22.md
fr10-code-review-input.md
fr10-fix-verification.md
gaith-fix-context-2026-08-26.md
gaith-fixes-2026-08-26-applied.md
main_dart_review_2026-08-29.md
project-gap-audit.md
security-rules-verification.md
task14_audit_2026-08-29.md
task14_fix_verification_2026-08-29.md
```

`data-model.md` is the only file left in `docs/` root — it is durable
schema/field reference material (the frozen `routes`/`stops`/`admins`
collection shapes), not a one-off session report, so it stays per the task
brief. Every file in the brief's 14-item list matched a real file in
`docs/`; no extra files needed a judgement call.
