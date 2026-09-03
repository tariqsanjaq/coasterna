# D51 — Route path points (Open in Google Maps)

Implements decision D51: pass GPX-sampled path points, not stop coordinates,
as Google Maps directions waypoints so "Open in Google Maps" traces the
bus's real road. Read-and-write task on `dev` — see the four-part scope in
the task prompt.

## Changes made

### 1. `RouteModel` — new optional `pathPoints` field

- Added `LatLngPoint` (`double lat`, `double lng`), an immutable class next
  to `RouteModel` in the same file, following `RouteStop`'s existing
  plain-fields-plus-`const`-constructor style.
- Added `final List<LatLngPoint>? pathPoints` to `RouteModel`, optional in
  the constructor (`this.pathPoints`, no `required`), null by default.
- Storage format is a single Firestore string field, `"lat,lng;lat,lng;..."`
  — matches the format given in the task prompt exactly.
- `RouteModel.parsePathPoints(String? raw)` — parses that string into
  `List<LatLngPoint>?`. Never throws: missing, empty/whitespace-only, or
  malformed input (wrong pair count, non-numeric component) all return
  `null` inside a `try/catch`, so a bad string can never stop a route
  document from loading.
- `RouteModel.pathPointsToFirestore(List<LatLngPoint>? points)` — the
  inverse; `null` or an empty list serialize to `null` (field is written
  as unset, never an empty string).
- `fromFirestore` reads `data['pathPoints']`, guarding the cast
  (`data['pathPoints'] is String ? ... : null`) before handing it to
  `parsePathPoints` — a non-string value (bad manual edit, wrong type)
  degrades to `null` rather than throwing a cast error.
- `toFirestore` always writes the `pathPoints` key, with `null` when there
  are no path points — matches the existing convention already used for
  `frequencyMinutes` (a nullable field written unconditionally, not
  omitted).
- **Naming**: kept `fromFirestore`/`toFirestore` exactly as they are per
  the task's explicit instruction not to "fix" that naming — this is the
  same pre-existing discrepancy from the CLAUDE.md/`docs/project-status.md`
  note about `RouteModel` not having unit-testable `fromJson`/`toJson`.
  `parsePathPoints`/`pathPointsToFirestore` are new, narrowly-scoped helper
  methods (not renames of the existing pair) — made **public** rather than
  private specifically so they're unit-testable directly (see Verification
  below) and so the admin form (#4) can reuse the exact same parsing logic
  instead of duplicating the "lat,lng;..." grammar in two places.

### 2. `trip_details_screen.dart` — `_openInMaps()` uses `pathPoints`

- If `route.pathPoints != null && route.pathPoints!.length >= 2`: builds
  `https://www.google.com/maps/dir/lat,lng/lat,lng/...` in point order.
- Otherwise: the **original** single-pin `maps/search/?api=1&query=...`
  logic runs completely unchanged (same Arabic comments, same
  `originStop`-or-name fallback, same `ACCEPTED TRADE-OFF` doc comment).
- Added a new doc comment above `_openInMaps()` explaining path points are
  GPX-track samples, not stop coordinates, with the field-measured numbers
  from the task prompt (21.9 km vs 11.2 km real for stop coords; 7.2 km vs
  7.32 km real for GPX samples).
- The existing `launchUrl` + `PlatformException`/generic-catch guard and
  the "Could not open Google Maps." snackbar are untouched — they run
  identically regardless of which `uri` was built.

### 3. `trip_details_screen.dart` — caption under the button

- The button is now wrapped in a `Column`; when
  `route.pathPoints != null && route.pathPoints!.length >= 2`, a caption
  `"Opens the road path in Google Maps. Stop names are listed above."`
  renders directly beneath it, centered.
- Styled `fontSize: 12.5, color: AppColors.textSecondary` — matches this
  same file's existing secondary-text convention (the operator subtitle in
  the app bar uses the identical `12.5`/`textSecondary` pairing), not a new
  style.
- Hidden entirely (not just blank) for the two routes with no recorded
  path — `Column`'s `if` spread only adds the `Text` widget when the
  condition holds.

### 4. Admin route form — "Route path points" field

- New `_pathPointsController`, disposed alongside the other controllers.
- New `TextFormField` under `AdminLabeledField(label: 'Route path points')`
  — `AdminFieldLabel` upper-cases automatically, so this renders as
  "ROUTE PATH POINTS" the same way every other label in this form does
  (none of the existing labels are typed upper-case in source).
- Multi-line (`minLines: 2, maxLines: 4`), optional, placed after the
  Stops/waypoints block and before the error-message / `AdminFormActions`
  row, per the task's placement instruction.
- Helper text is exactly the string given in the task prompt, styled
  `11.5`/`textSecondary` via `.copyWith()` on `adminInputDecoration()`.
- Input text uses `AppTextStyles.monoData(fontSize: 13)` — coordinate data,
  per the task's constraint that monospace is reserved for
  prices/times/durations/coordinates.
- Validation (`_pathPointsValidator`): empty is always valid. Non-empty is
  split on `;`; each segment must split into exactly two comma-separated
  numeric parts, `lat` in `-90..90`, `lng` in `-180..180`. On failure the
  message names the offending point by position and shows the bad
  substring, e.g. `Point 2 must be "lat,lng" — got "35.79".`
- Wired into `_save()`: `pathPoints: RouteModel.parsePathPoints(_pathPointsController.text)`
  — reuses the model's own parser (see #1) rather than a third copy of the
  parsing logic. Since the form validator already rejected anything
  malformed, this call cannot itself produce an unexpected `null` from bad
  input at save time.
- Pre-populated in edit mode via
  `RouteModel.pathPointsToFirestore(existing.pathPoints) ?? ''` in
  `initState`, immediately after the existing waypoint-name population.

## Files modified

- `lib/core/models/route_model.dart`
- `lib/features/trip/presentation/trip_details_screen.dart`
- `lib/features/admin/presentation/add_route_screen.dart`
- `test/route_model_test.dart` (new tests only)

No other files touched. `StopModel`, the `stops` collection, and
`searchRoutesByOrigin` were not modified. `route_repository.dart` was not
touched — D48 pre-granted permission was not needed for this task.

```
 lib/core/models/route_model.dart                   |  64 +++++++++
 lib/features/admin/presentation/add_route_screen.dart |  65 ++++++++
 lib/features/trip/presentation/trip_details_screen.dart | 101 ++++++++----
 test/route_model_test.dart                         | 110 ++++++++++++
 4 files changed, 309 insertions(+), 31 deletions(-)
```

## flutter analyze output

Ran clean, no new issues. Raw output saved to
`docs/audit-trail/d51-route-path-points-analyze.txt`.

```
Analyzing coasterna_project...
No issues found! (ran in 68.0s)
```

## flutter test output

All 53 tests passed (46 pre-existing + 7 new `RouteModel.pathPoints` unit
tests). Raw output saved to
`docs/audit-trail/d51-route-path-points-test.txt`.

```
00:00 +53: All tests passed!
```

New tests added, under `group('RouteModel.pathPoints (decision D51)')` in
`test/route_model_test.dart`:

1. `parsePathPoints parses a valid "lat,lng;lat,lng" string`
2. `parsePathPoints returns null for a malformed string` (missing comma,
   non-numeric coordinate, three-component pair)
3. `parsePathPoints returns null for empty or missing input` (`null`,
   `''`, whitespace-only)
4. `pathPointsToFirestore returns null for null or empty points`
5. `parsePathPoints(pathPointsToFirestore(points)) round-trips`
6. `RouteModel.toFirestore() round-trips through parsePathPoints` —
   exercises the real instance method, not just the static helper
7. `RouteModel.toFirestore() writes null pathPoints as null` — confirms
   the key is present with a `null` value, not omitted

Note on scope: `RouteModel.fromFirestore()` itself was **not** exercised
directly in these tests, because it requires a real
`DocumentSnapshot<Map<String, dynamic>>` and this project has no
Firestore-faking package installed (adding one — e.g.
`fake_cloud_firestore` — would violate the "no new package" constraint).
This is the same pre-existing gap the CLAUDE.md/`docs/project-status.md`
notes describe for `RouteModel`/`StopModel` not being unit-testable
without a real Firestore object. Instead, `fromFirestore`'s actual parsing
logic (`parsePathPoints`, exercised on the strings `fromFirestore` would
hand it, including the `is String` type guard's `null`-fallback path via
test #3's `null` case) and `toFirestore`'s actual output (tests #6–7, via
the real instance method) are both covered directly.

## What still needs manual verification

- **No path-point data exists yet in Firestore.** All four routes in the
  `coasterna-fa940` project currently have no `pathPoints` field, so
  `_openInMaps()` will take the unchanged single-pin fallback for every
  route until an admin enters real GPX-sampled points through the new
  form field. The directions-URL branch is therefore untested against a
  live Google Maps response in this session — only the URL-building logic
  and the unit tests above were verified.
- **Opening the directions URL on a device.** `flutter analyze`/`flutter
  test` don't launch a browser or the Maps app. Once a real route has
  `pathPoints` set (via the new admin field), tapping "Open in Google
  Maps" on a device/emulator should be checked to confirm: the link opens
  Maps in directions mode strung through the given points, the caption
  appears under the button, and the caption is absent for the two routes
  with no recorded path.
- **Admin form field, live.** The validator logic and save-wiring are
  covered by `flutter analyze` (no static issues) but not by a widget
  test. Manually check in the running admin dashboard: entering a bad
  segment shows the expected inline message, saving a valid string
  persists and reloads correctly (edit mode re-populates the field), and
  leaving it empty still saves successfully.
- **Firestore Security Rules** were not touched and don't need to be —
  `pathPoints` is just another field on an existing `routes/{routeId}`
  document, covered by whatever rule already governs writes to that
  collection. Not re-verified this pass since the task scope didn't call
  for it.
