# Coasterna — Full Code Audit

Date: 2026-08-31
Scope: `lib/`, `firestore.rules`, `pubspec.yaml`, `test/`. Facts only — no fixes, no priorities, no architectural decisions made.

## 1. Architecture (feature-first, layered)

Rule checked: no file outside `lib/core` or `lib/features/*/[data|domain|presentation]`; every feature has data/domain/presentation.

- `lib/main.dart` — outside `lib/core` and `lib/features/*` (standard Flutter entry point).
- `lib/firebase_options.dart` — outside `lib/core` and `lib/features/*` (FlutterFire-generated, not hand-written).
- CLAUDE.md states "no `domain/` layer in any feature folder — only `data/` and `presentation/`", but `domain/` directories physically exist (each containing only a `.gitkeep`, no `.dart` files) in:
  - `lib/features/admin/domain/`
  - `lib/features/auth/domain/`
  - `lib/features/search/domain/`
  - `lib/features/trip/domain/`
- Features missing a `data/` and/or `domain/` directory entirely (not even a `.gitkeep`):
  - `lib/features/about/` — has `presentation/` only.
  - `lib/features/splash/` — has `presentation/` only.
- Features with a `data/` directory present but empty (`.gitkeep` only, no `.dart` code):
  - `lib/features/admin/data/.gitkeep`
  - `lib/features/trip/data/.gitkeep`
- Features with a populated `data/` directory: `auth` (`auth_repository.dart`), `search` (`route_repository.dart`).

## 2. No Firebase calls inside widgets

Grep for `FirebaseFirestore`, `FirebaseAuth`, `.collection(`, `.doc(` across `lib/`.

Every match is confined to two files, both under a feature's `data/` directory:
- `lib/features/auth/data/auth_repository.dart` — lines 18-20, 22-23, 38, 58, 84.
- `lib/features/search/data/route_repository.dart` — lines 36-37, 39, 44, 83, 127, 138, 177, 197-198, 206, 213, 222-223, 231-232, 242, 263, 269.

No violations found — no `FirebaseFirestore`, `FirebaseAuth`, `.collection(`, or `.doc(` usage appears in any `presentation/` file.

## 3. State management

Grep for `riverpod`, `flutter_bloc`/`Bloc`/`Cubit`, `package:provider`, `GetX`, `get_it` across `lib/` and `pubspec.yaml`.

No violations found. `pubspec.yaml` dependencies are: `cupertino_icons`, `firebase_core`, `cloud_firestore`, `google_fonts`, `url_launcher`, `firebase_auth`, `shared_preferences` (plus dev deps `flutter_test`, `flutter_lints`, `flutter_launcher_icons`). No state-management package is declared or imported. All screens use `setState` + `FutureBuilder` (e.g. `lib/features/admin/presentation/admin_manage_screen.dart:595,765`) or a hand-rolled `_LoadState` enum + `setState` (e.g. `lib/features/search/presentation/all_routes_screen.dart:22-87`).

## 4. Models — fromJson/toJson

- `lib/core/models/route_model.dart` — `RouteModel` (lines 91-200) has **no `fromJson`/`toJson`**. It exposes `RouteModel.fromFirestore(DocumentSnapshot<Map<String,dynamic>>)` (line 137) and `toFirestore()` (line 178) instead — both take/return Firestore-specific types (`DocumentSnapshot`, `Timestamp`), so the model is not unit-testable without a Firestore document/timestamp object.
- `lib/core/models/route_model.dart` — `RouteStop` (lines 61-87), the one nested/embedded type in this file, **does** have `fromJson` (line 72) and `toJson` (line 80), both operating on plain `Map<String, dynamic>` with no Firestore types.
- `lib/core/models/stop_model.dart` — `StopModel` (lines 5-52) has **no `fromJson`/`toJson`**. It exposes `StopModel.fromFirestore(DocumentSnapshot<Map<String,dynamic>>)` (line 23) and `toFirestore()` (line 43) instead, same pattern as `RouteModel`.
- Enums `DepartureType` and `RouteDirection` (`route_model.dart` lines 5-56) use `fromFirestore`/`toFirestore` naming, operating on plain `String`, not `fromJson`/`toJson`.

Violations: `RouteModel` and `StopModel`, the two top-level Firestore-backed models, are both missing `fromJson`/`toJson`.

## 5. Screen quality bar (loading / empty / error)

Screens that load a remote (Firestore) list and their state coverage:

| Screen | Loading | Empty | Error |
|---|---|---|---|
| `lib/features/search/presentation/all_routes_screen.dart` (`_AllRoutesScreenState`, lines 32-194) | yes (line 132-136) | yes (line 156-163) | yes, with retry (line 138-153) |
| `lib/features/search/presentation/search_results_placeholder.dart` (`_SearchResultsPlaceholderState`, lines 30-192) | yes (line 121-125) | yes (line 145-166) | yes, with retry (line 127-143) |
| `lib/features/search/presentation/widgets/stop_picker_sheet.dart` (`_StopPickerSheetState`, lines 24-153) | yes (line 107-109) | yes, "No stops match your search." (line 125-129) | yes, with retry (line 110-123) |
| `lib/features/admin/presentation/admin_manage_screen.dart` — `StopsManageList`/`_buildBody` (line 620-670) | yes (line 621-625) | yes (line 635-637) | yes, with retry (line 626-632) |
| `lib/features/admin/presentation/admin_manage_screen.dart` — `RoutesManageList`/`_buildBody` (line 791-846) | yes (line 792-796) | yes (line 806-808) | yes, with retry (line 797-803) |
| `lib/features/admin/presentation/add_route_screen.dart` (`RouteFormPanel`, loads stops in `_loadStops`, lines 149-186) | yes (`_isLoadingStops`, line 342-346) | yes, "No active stops exist yet…" (line 373-385) | yes, with retry (`_loadFailed`, line 347-372) |

Screens with an async data step that show **fewer than three states**:

- `lib/features/search/presentation/home_page.dart` (`_HomeViewState`) — loads "recent searches" from `SharedPreferences` in `_loadRecentSearches()` (line 48-57). No loading indicator is shown while this resolves, no error handling exists if `jsonDecode` (line 52) throws on malformed stored JSON, and there is no explicit "empty" UI state — an empty `_recentSearches` list is handled only by omitting the "RECENT" section (line 344 `if (_recentSearches.isNotEmpty)`), with no dedicated empty-state message.

Screens with no asynchronous list-loading step (form/static screens — loading/empty/error states as defined by this check do not apply in the same sense):
- `lib/features/admin/presentation/add_stop_screen.dart` (`StopFormPanel`) — pre-fills synchronously from a passed-in `StopModel?`; shows an error state on save failure (line 128-134) but no loading/empty state for data reads (none performed).
- `lib/features/admin/presentation/admin_login_screen.dart` — shows loading (button spinner, line 182-188) and error (`_errorMessage`, line 162-168); no "empty" state (not applicable to a login form).
- `lib/features/auth/presentation/student_login_screen.dart` — shows loading (line 137-143) and error (line 126-133); no "empty" state (not applicable).
- `lib/features/auth/presentation/student_signup_screen.dart` — shows loading (line 140-146) and error (line 129-136); no "empty" state (not applicable).
- `lib/features/splash/presentation/splash_screen.dart`, `lib/features/about/presentation/about_page.dart` — static content, no data fetch, no loading/empty/error states present.
- `lib/features/admin/presentation/admin_home_screen.dart` — pure navigation shell; delegates data loading to `RoutesManageList`/`StopsManageList`.
- `lib/features/trip/presentation/trip_details_screen.dart` — receives its `RouteModel` directly from the caller (no Firestore read of its own, per its own doc comment lines 76-80); no loading/empty/error states present or applicable.

## 6. Offline handling — catch blocks around Firestore reads

- `lib/features/auth/data/auth_repository.dart:79-89` (`isCurrentUserAdmin()`) — wraps a single-document `.get()` in `try { ... } catch (_) { return false; }` (line 86-88). The method's own doc comment (line 76-78) states: "Fails CLOSED: if nobody is signed in, if the read is denied, or if **anything else goes wrong (offline, etc.)**, this returns false." This explicitly names "offline" as a condition the catch is meant to handle.
- `lib/features/search/data/route_repository.dart:1-30` (class-level doc comment on `RepoResult`) documents the project's own established model of Firestore behavior: "get() does NOT throw an error [when offline] — it quietly answers from that saved copy instead ... the result is an EMPTY list with no error at all," with `isFromCache` used as the actual offline signal throughout the repository and its callers (`all_routes_screen.dart:73-81`, `search_results_placeholder.dart:65-73`, `stop_picker_sheet.dart:47-49`). Under this documented model, an offline read never throws, so `auth_repository.dart:76-78`'s inclusion of "offline" among the reasons for its catch is inconsistent with the rest of the codebase's own stated Firestore behavior.

Other `catch` blocks around Firestore reads found in the codebase (`all_routes_screen.dart:60-67,83-86`, `search_results_placeholder.dart` implicit via `_loadRoutes`, `stop_picker_sheet.dart:51-54`, `add_route_screen.dart:179-185`) are not documented as targeting an offline condition — their surrounding comments and code (`RepoResult.isFromCache`) attribute failure handling to parse/permission errors, not offline detection, so they are not flagged here.

## 7. Route uniqueness invariant (originStopId + destinationStopId + direction, never operatorName)

Grep for `operatorName` across `lib/` (10 matches, all reviewed):
- `lib/core/models/route_model.dart:94,115,150,181` — field declaration/serialization only.
- `lib/features/trip/presentation/trip_details_screen.dart:162` — displayed as text in the AppBar subtitle.
- `lib/features/search/presentation/all_routes_screen.dart:295-296` — used only as a display fallback subtitle string (`_subtitleFor`), not for comparison/identity.
- `lib/features/admin/presentation/admin_manage_screen.dart:770` — `routes.map((r) => r.operatorName.toLowerCase()).toSet().length` computes a distinct-operator **count for a subtitle string** ("N routes · M operators"), not a uniqueness/identity check.
- `lib/features/admin/presentation/admin_manage_screen.dart:825` — displayed as a table cell.
- `lib/features/admin/presentation/add_route_screen.dart:87,294` — form pre-fill/read, written to the model field.

No code compares `operatorName` between two routes, and no duplicate/uniqueness check in the codebase references it. `add_route_screen.dart:396-403` shows an `AdminNoticeBanner` instructing the admin to manually check for an existing route with the same origin/destination before saving — it names "origin and destination," not operator. No violations found.

## 8. Denormalization (`originStopName`/`destinationStopName` auto-update assumption)

- `lib/features/search/data/route_repository.dart:154-163` (doc comment on `updateRoute`) and `:188-194` (doc comment on `updateStop`) both explicitly state the opposite of an auto-update assumption: renaming a stop via `updateStop` does **not** rewrite `originStopName`/`destinationStopName` on routes that reference it, and this is called out as a deliberate MVP simplification logged for "Ch.7 Future Work."
- `lib/features/admin/presentation/add_stop_screen.dart:179-189` shows an `AdminNoticeBanner` (visible only in edit mode) telling the admin directly: "Changing the Name does not rename this stop on routes that already use it. Update those routes as well, or their cards will keep showing the old name." — the UI itself warns against the assumption.
- No code path was found that reads a `stops/{id}` document's `name` and expects it to match a route's stored `originStopName`/`destinationStopName`, and no code re-derives those fields from live stop data at render time.

No violations found — no code assumes the denormalized copies auto-update.

## 9. Dead code

- `test/route_status_test.dart:1-7` — the file's opening comment block is leftover task-assignment scaffolding, not a code comment about the test itself: "COASTERNA — Abdallah Task #7 / File to CREATE: test/route_status_test.dart / This is a COMPLETE file. Create it exactly as it is, do not edit anything else in the project, then run: flutter test".
- No `// TODO`, `//TODO`, `TODO:`, `FIXME`, or `XXX:` markers found anywhere under `lib/`.
- No commented-out code statements (e.g. `// final ...`, `// return ...`, `// if (...)`) found under `lib/`.
- `flutter analyze` (flutter_lints ruleset, which includes `unused_import`/`unused_element`/`dead_code` lints) reports **"No issues found!"** — no unused-import or dead-code lint warnings.
- Every `.dart` file under `lib/` (excluding `main.dart` and `firebase_options.dart`) is referenced by filename from at least one other file in `lib/` — no orphaned/unused files found.

## 10. REST API leftovers

Grep for `http.get`, `http.post`, `package:http`, `package:dio`, `Dio(` across `lib/` and `pubspec.yaml`.

No violations found. No `http` or `dio` package is declared in `pubspec.yaml`, and no matching code exists in `lib/`. The only network-adjacent calls in the codebase are Firestore/Firebase Auth SDK calls (see item 2) and `url_launcher`'s `launchUrl()` in `lib/features/trip/presentation/trip_details_screen.dart:125` (opens an external Google Maps URL, not a REST API client call).

## 11. Naming consistency ("Route", not "Trip"/"Bus"/"Line")

- Core data-model and repository layer consistently use "Route": `RouteModel`, `RouteStop`, `RouteDirection`, `DepartureType`, `RouteRepository`, `RoutesManageList`, `RouteFormPanel`, `RouteStatusBadge`, `routeDepartureRank`, `routeRunsToday`, `searchRoutesByOrigin`, `getAllActiveRoutes`, `getAllRoutesForAdmin`, `createRoute`/`updateRoute`/`deleteRoute`/`setRouteActive`.
- "Trip" is used as the feature/screen name: `lib/features/trip/presentation/trip_details_screen.dart` — `TripDetailsScreen`/`_TripDetailsScreenState` (lines 81, 95). It does not substitute for the `Route` model — the screen's own parameter is `required this.route` typed `RouteModel` (line 88), and internal references use `route.` throughout (e.g. lines 139, 154, 162, 273).
- "Line" appears in `lib/features/admin/presentation/add_route_screen.dart:716` as the private widget class `_StopLine` (a single row in the stops editor UI, unrelated to the Route entity) and in test fixture string data `'Test Line'` (`test/route_status_test.dart:41`, a `routeName` value, not a type/class name).
- "Bus" appears only in user-facing copy/strings, not as a class, model, or variable name representing the Route entity, e.g. `'Search buses'` (`home_page.dart:310`), `'No buses found from...'` (`search_results_placeholder.dart:155`), `'Could not load buses...'` (`search_results_placeholder.dart:135`), `'Next bus in about...'`/`'First bus at...'` (`route_status_badge.dart:212,219`).

No violations found — no model, widget class, or variable substitutes "Trip"/"Bus"/"Line" for the `Route` entity itself.

## 12. Security Rules (firestore.rules)

Full rule set, by collection:

- `stops/{stopId}` (lines 16-19): `allow read: if true;` / `allow write: if isAdmin();`
- `routes/{routeId}` (lines 24-27): `allow read: if true;` / `allow write: if isAdmin();`
- `admins/{adminId}` (lines 33-35): `allow read: if request.auth != null && request.auth.uid == adminId;` (self-read only) / `allow write: if false;` (fully denied both directions)
- Catch-all `{document=**}` (lines 40-42): `allow read, write: if false;`

`isAdmin()` (lines 6-9) is defined as `request.auth != null && exists(/databases/$(database)/documents/admins/$(request.auth.uid))`.

No `allow read, write: if true;` (fully open) rule exists on any named collection. `stops` and `routes` allow unauthenticated/public read (`if true`), matching the documented intent that student search requires no sign-in; both restrict write to `isAdmin()`. `admins` restricts read to the caller's own document and blocks all writes. The catch-all denies everything for any collection not explicitly listed. No rule was found missing for `routes`, `stops`, or `admins` — all three collections named in CLAUDE.md have explicit rules present.

## 13. Full-width button landmine (ElevatedButton in a Row without `minimumSize: const Size(0, 48)`)

All 6 `ElevatedButton` usages in `lib/`, checked against their parent layout:

| Location | Parent widget | `minimumSize: const Size(0, 48)` present |
|---|---|---|
| `lib/features/search/presentation/home_page.dart:298` | `SizedBox(width: double.infinity, ...)`, not inside a `Row` | n/a (full-width intended) |
| `lib/features/admin/presentation/admin_login_screen.dart:173` | `SizedBox(width: double.infinity, height: kMinTouchTarget, ...)`, not inside a `Row` | n/a (full-width intended) |
| `lib/features/trip/presentation/trip_details_screen.dart:188` | `SizedBox(width: double.infinity, ...)` inside `Padding`, not inside a `Row` | n/a (full-width intended) |
| `lib/features/admin/presentation/admin_manage_screen.dart:73` | inside `Row` (`_ListHeader`, line 46) | yes — line 85 |
| `lib/features/admin/presentation/admin_manage_screen.dart:324` | inside `Row` (destructive-confirm dialog actions, line 310) | yes — line 331 |
| `lib/features/admin/presentation/admin_form_widgets.dart:249` | inside `Row` (`AdminFormActions`, line 234) | yes — line 254 |

No violations found — every `ElevatedButton` placed inside a `Row` sets `minimumSize: const Size(0, 48)`; the three not inside a `Row` are intentionally full-width (matching the default `elevatedButtonTheme` in `lib/core/theme/app_theme.dart:84-93`, which itself sets `minimumSize: const Size.fromHeight(kMinTouchTarget)`).

## 14. Git authorship sanity

`git log --all --pretty=format:"%an|%ae"` distinct authors:

| Author name | Email | Commit count |
|---|---|---|
| TariqSanjaq | tariqms.ed@gmail.com | 32 |
| Abdalla_Abufara | abdallaabufara@gmail.com | 15 |
| Gaith Swaidan | gaioothswaidan@gmail.com | 11 |
| unknown | abdallaabufara@gmail.com | 2 |
| zOx_k | 143870963+tariqsanjaq@users.noreply.github.com | 1 |

Commits attributed to a non-real-name author (3 total, out of 61):
- `0a8016a` — author "unknown" — 2026-08-07 — "feat(security): finalize Firestore rules — deny direct admin reads, add default-deny catch-all" (email matches Abdalla Abufara's other commits)
- `f18174d` — author "unknown" — 2026-08-04 — "docs: document Firestore data model for Ch.4.2.4" (email matches Abdalla Abufara's other commits)
- `37eab2c` — author "zOx_k" — 2026-08-01 — "Initial commit" (email is a GitHub noreply address containing "tariqsanjaq")
