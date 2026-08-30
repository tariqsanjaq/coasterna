# Coasterna — Project Gap Audit

Read-only audit. Everything below was verified against files in this repository on branch `dev`. Nothing under `.claude/worktrees/` was searched or reported. No file was modified except this one.

Files inspected in full: `lib/main.dart`, `lib/core/presentation/splash_screen.dart`, `lib/core/widgets/offline_banner.dart`, `lib/core/models/route_model.dart`, `lib/core/models/stop_model.dart`, `lib/features/search/data/route_repository.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/student_login_screen.dart`, `lib/features/auth/presentation/student_signup_screen.dart`, `lib/features/search/presentation/home_page.dart`, `lib/features/search/presentation/search_results_placeholder.dart`, `lib/features/search/presentation/all_routes_screen.dart`, `lib/features/search/presentation/widgets/stop_picker_sheet.dart`, `lib/features/search/presentation/widgets/route_status_badge.dart`, `lib/features/trip/presentation/trip_details_screen.dart`. Admin files surveyed by structural grep: `lib/features/admin/presentation/*.dart`.

Full file list under `lib/` (23 files), from `find lib -name '*.dart' | sort`:

```
lib/core/models/route_model.dart
lib/core/models/stop_model.dart
lib/core/presentation/splash_screen.dart
lib/core/theme/app_theme.dart
lib/core/widgets/offline_banner.dart
lib/features/admin/presentation/add_route_screen.dart
lib/features/admin/presentation/add_stop_screen.dart
lib/features/admin/presentation/admin_form_widgets.dart
lib/features/admin/presentation/admin_home_screen.dart
lib/features/admin/presentation/admin_login_screen.dart
lib/features/admin/presentation/admin_manage_screen.dart
lib/features/auth/data/auth_repository.dart
lib/features/auth/presentation/student_login_screen.dart
lib/features/auth/presentation/student_signup_screen.dart
lib/features/search/data/route_repository.dart
lib/features/search/presentation/all_routes_screen.dart
lib/features/search/presentation/home_page.dart
lib/features/search/presentation/search_results_placeholder.dart
lib/features/search/presentation/widgets/route_status_badge.dart
lib/features/search/presentation/widgets/stop_picker_sheet.dart
lib/features/trip/presentation/trip_details_screen.dart
lib/firebase_options.dart
lib/main.dart
```

---

## 1. FR-by-FR coverage check

### FR-01 — searchable list of all active bus stops near AAU

**PARTIALLY IMPLEMENTED.**

Implemented by:
- `lib/features/search/presentation/widgets/stop_picker_sheet.dart` — `StopPickerSheet` (line 8) / `_StopPickerSheetState` (line 24). Loads via `_loadStops()` (line 35).
- Type-to-filter search field: `TextField` at line 82, `onChanged: (value) => setState(() => _query = value)` at line 83; the filter itself at lines 59-61:
  ```dart
  final filtered = _stops
      .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();
  ```
- The "active only" part is enforced in the repository, `lib/features/search/data/route_repository.dart:42-52`, `getAllStops()`:
  ```dart
  final snapshot = await _firestore
      .collection('stops')
      .where('isActive', isEqualTo: true)
      .get();
  ```

Missing: there is **no "near AAU" / proximity element of any kind**. `getAllStops()` returns every active stop with no distance, radius, or location filter, and the sheet applies only the name substring filter above. Command run:

```
grep -rn -i -E "distance|radius|nearby|proximity|geopoint|haversine" lib --include='*.dart'
```

Every hit returned was `BorderRadius` / `AppRadius` styling (e.g. `lib/core/theme/app_theme.dart:40`, `lib/features/search/presentation/home_page.dart:384`). No distance or proximity computation exists anywhere in `lib/`. `StopModel` does store `latitude` and `longitude` (`lib/core/models/stop_model.dart:9-10`), but nothing in `lib/` reads them for filtering or sorting.

Also note: the list is a modal bottom sheet opened from Home (`lib/features/search/presentation/home_page.dart:98-110`, `_openStopPicker`), not a standalone browsable stops screen.

### FR-02 — search for routes by origin stop and destination stop

**IMPLEMENTED.**

- Origin and destination selection: `lib/features/search/presentation/home_page.dart` — `_pickFromStop()` (line 80), `_pickToStop()` (line 87), `_clearToStop()` (line 94), the two `_StopField` widgets at lines 258-263 (`label: 'From'`) and 265-271 (`label: 'To (optional)'`), and `_search()` (line 112).
- Query: `lib/features/search/data/route_repository.dart:66-85`, `searchRoutesByOrigin(String originStopId, {String? destinationStopId})`:
  ```dart
  Query<Map<String, dynamic>> query = _firestore
      .collection('routes')
      .where('originStopId', isEqualTo: originStopId)
      .where('isActive', isEqualTo: true);

  if (destinationStopId != null) {
    query = query.where('destinationStopId', isEqualTo: destinationStopId);
  }
  ```
- Called from `lib/features/search/presentation/search_results_placeholder.dart:46-49`.

Factual note on scope: the query matches on `originStopId` equality only. A route whose `stops` array contains the chosen stop as an intermediate waypoint, but whose `originStopId` is a different stop, is not returned. Nothing in `lib/` queries or filters against the route's embedded `stops` array — verified by reading `route_repository.dart` in full; the only reads of `route.stops` in `lib/` are for display (`lib/features/trip/presentation/trip_details_screen.dart:111-116`) and for the admin form (`lib/features/admin/presentation/add_route_screen.dart:104`, `:127`, `:278-287`).

Destination is optional in the UI: the field is labelled `'To (optional)'` (`home_page.dart:266`) and `_search()` only requires `_fromStop != null` (`home_page.dart:113`).

### FR-03 — result card shows route name, destination, price (JD), and departure information

**PARTIALLY IMPLEMENTED.**

The search-results card is built by `_buildRouteCard(RouteModel route)` at `lib/features/search/presentation/search_results_placeholder.dart:194-242`. What it renders:

| Required element | Present? | Evidence |
| --- | --- | --- |
| Route name | Yes | `search_results_placeholder.dart:210` — `route.routeName` |
| Destination | **No** | see below |
| Price (JD) | Yes | `search_results_placeholder.dart:233` — `'${route.priceJD.toStringAsFixed(2)} JD'` |
| Departure information | Partial | `search_results_placeholder.dart:238` — `RouteStatusBadge(route: route)`; see below |

Missing part 1 — **destination is not printed on the search-result card**. The card's second line is the *origin*, not the destination: `search_results_placeholder.dart:224` renders `'Board at: ${widget.fromStop.name}'`. The only other element on the card is `_DirectionChip` (used at `search_results_placeholder.dart:219`, class at line 247), which reads `route.destinationStopName` at line 255 but prints one of three fixed labels — `'To AAU'` (line 256), `'Towards AAU'` (line 258), `'From AAU'` (line 260) — never the destination stop's name. `route.destinationStopName` exists on the model (`lib/core/models/route_model.dart:99`) and is displayed on the *Browse all routes* card (`lib/features/search/presentation/all_routes_screen.dart:142`), but not on the search-result card.

Missing part 2 — **departure information is not shown as operating hours, and can be absent entirely**. The badge shows a computed status, not the `firstDeparture`–`lastDeparture` range: `'Next bus in about $minutes min'` (`route_status_badge.dart:196`), `'First bus at $time'` (line 203), `'Departs when full'` (line 210), `'Service ended today'` (line 217), `'No service today'` (line 224). For a SCHEDULED route that is inside its operating hours but has `frequencyMinutes == null`, `_resolveStatus` returns `null` (`route_status_badge.dart:161-167`) and `build` then returns `const SizedBox.shrink()` (line 119) — the card shows **no departure information at all** in that case. The code comment at lines 164-166 says "the operating hours line stands alone", but `_buildRouteCard` contains no operating-hours line; the card's only other text lines are lines 210, 224 and 233 above.

### FR-04 — Google Maps link on Trip Details built from stored latitude/longitude of the departure stop

**PARTIALLY IMPLEMENTED.**

Implemented by `_openInMaps()` in `lib/features/trip/presentation/trip_details_screen.dart:118-146`, wired to the "Open in Google Maps" button at lines 199-216. It uses `url_launcher` (import at line 2, `launchUrl(...)` at line 136).

The URL actually built, lines 120-132:

```dart
final String originParam = widget.originStop != null
    ? '${widget.originStop!.latitude},${widget.originStop!.longitude}'
    : widget.route.originStopName;

// تحديد نقطة النهاية (اسم المحطة النهائية للمسار)
final String destinationParam = widget.route.destinationStopName;

// استخدام رابط الاتجاهات (dir) بدلاً من البحث الفردي (search)
final uri = Uri.parse(
  'https://www.google.com/maps/dir/?api=1'
      '&origin=${Uri.encodeComponent(originParam)}'
      '&destination=${Uri.encodeComponent(destinationParam)}',
);
```

Three factual divergences from the FR as worded:

1. The link is a **directions** link (`/maps/dir/?api=1&origin=…&destination=…`), not the `https://www.google.com/maps/search/?api=1&query=LAT,LON` form.
2. Coordinates are used for the departure stop **only when `originStop` is non-null**. `originStop` is declared optional at `trip_details_screen.dart:85` (`this.originStop, // أصبح اختيارياً`) and `:89` (`final StopModel? originStop;`). When it is null the origin falls back to the stop *name* string (line 122) — no coordinates. That null path is reachable: `lib/features/search/presentation/all_routes_screen.dart:118` constructs `TripDetailsScreen(route: route)` with no `originStop`. The search path does pass it (`search_results_placeholder.dart:180-183`).
3. The destination half of the link is always a **name string** (`route.destinationStopName`, line 125), never coordinates — the destination stop's stored `latitude`/`longitude` are not read here.

### FR-05 — sort search results by soonest departure after data arrives from Firestore

**IMPLEMENTED.**

`lib/features/search/presentation/search_results_placeholder.dart`, inside `_loadRoutes()`, after the `await` on the repository call (line 46) and before `setState` (line 63) — lines 56-60:

```dart
final now = DateTime.now();
routes.sort(
      (a, b) =>
      routeDepartureRank(a, now).compareTo(routeDepartureRank(b, now)),
);
```

Sort key: `routeDepartureRank(RouteModel route, DateTime now)` at `lib/features/search/presentation/widgets/route_status_badge.dart:93-106`, which uses `routeRunsToday` (line 42), `parseTimeOnDay` (line 7) and `minutesUntilNextDeparture` (line 70). The screen header states the ordering to the user: `' · soonest departure first'` at `search_results_placeholder.dart:106`.

Factual note, in scope of the wording "search results": the *Browse all routes* screen does not sort. `_loadRoutes()` at `lib/features/search/presentation/all_routes_screen.dart:33-54` assigns `_routes = result.data;` (line 39) with no `.sort(` call anywhere in that file.

### FR-06 — remain usable offline by loading previously cached route and stop data

**IMPLEMENTED.**

- Cache provenance is carried out of the data layer by `RepoResult<T>` with its `isFromCache` flag: `lib/features/search/data/route_repository.dart:21-30`, set from `snapshot.metadata.isFromCache` at lines 50, 83 and 203.
- Search results consume it: `lib/features/search/presentation/search_results_placeholder.dart:65` (`_isOffline = result.isFromCache;`) and lines 67-73, which distinguish "empty" from "offline with an empty cache".
- Browse all routes consumes it: `lib/features/search/presentation/all_routes_screen.dart:40` and lines 42-48.
- Stop picker consumes it: `lib/features/search/presentation/widgets/stop_picker_sheet.dart:47-49`.
- Offline banner widget: `lib/core/widgets/offline_banner.dart` — `OfflineBanner` (line 5), text `'You are offline. Showing cached routes.'` (line 20). Rendered at `search_results_placeholder.dart:170` and `all_routes_screen.dart:105`.

Factual note: no explicit Firestore persistence configuration exists in `lib/`. Command run:

```
grep -rn "persistenceEnabled\|Settings(\|enablePersistence\|CACHE_SIZE\|cacheSizeBytes" lib --include='*.dart'
```

Result: no matches. `lib/main.dart:12-18` calls only `Firebase.initializeApp(...)`. The caching behaviour therefore relies entirely on the Firestore SDK default for whichever platform the app runs on; nothing in this repository sets it.

### FR-07 — Administrator can add, update, and deactivate routes and stops through a web-based Admin Dashboard

**IMPLEMENTED.**

Web entry point: `lib/main.dart:36-37` — `home: kIsWeb ? const AdminLoginScreen() : SplashScreen(...)`, with `kIsWeb` imported at line 2. A `web/` directory exists (`ls -d web` → `web/`; `android/`, `ios/`, `linux/`, `macos/`, `windows/` also exist).

| Capability | Routes | Stops |
| --- | --- | --- |
| Add | `add_route_screen.dart` `RouteFormPanel` (line 30), `_save()` (line 255) → `createRoute` at line 316; repo `createRoute` at `route_repository.dart:100` | `add_stop_screen.dart` `StopFormPanel` (line 26), `_save()` (line 86) → `createStop` at line 113; repo `createStop` at `route_repository.dart:92` |
| Update | same panel in edit mode → `updateRoute` at `add_route_screen.dart:318`; repo `updateRoute` at `route_repository.dart:128` | `add_stop_screen.dart:111` → `updateStop`; repo `updateStop` at `route_repository.dart:150` |
| Deactivate | `admin_manage_screen.dart:723` — `await _repository.setRouteActive(route.id, !route.isActive);`; repo `setRouteActive` at `route_repository.dart:184` | `admin_manage_screen.dart:553` — `await _repository.setStopActive(stop.id, !stop.isActive);`; repo `setStopActive` at `route_repository.dart:175` |

Shell and navigation: `lib/features/admin/presentation/admin_home_screen.dart` — `AdminHomeScreen` (line 25), `_AdminSection` enum (line 33), `_AdminView` enum (line 36), `_openStopForm` (line 62), `_openRouteForm` (line 69), `_closeForm` (line 77), `_buildContent` (line 147). Lists: `StopsManageList` (`admin_manage_screen.dart:501`) and `RoutesManageList` (`admin_manage_screen.dart:685`).

### FR-08 — distinguish SCHEDULED (operating hours) from WHEN_FULL ("Departs when full")

**PARTIALLY IMPLEMENTED.**

The two-value distinction exists in the model and on both card types:

- Model enum: `lib/core/models/route_model.dart:5-28` — `DepartureType { scheduled, whenFull }`, mapping the exact strings `'SCHEDULED'` (line 11) and `'WHEN_FULL'` (line 13).
- Search-result card: `RouteStatusBadge._resolveStatus` at `route_status_badge.dart:144-168` branches at line 147 (`if (route.departureType != DepartureType.scheduled) return _BadgeStyle.whenFull;`), producing the amber `'Departs when full'` pill (`_BadgeStyle.whenFull`, lines 209-214). Scheduled routes get `'First bus at $time'` (line 202) / `'Next bus in about $minutes min'` (line 195) / `'Service ended today'` (line 216).
- Browse-all-routes card: `lib/features/search/presentation/all_routes_screen.dart:150-152`:
  ```dart
  route.departureType == DepartureType.scheduled
      ? '${route.firstDeparture} - ${route.lastDeparture}'
      : 'Departs when full',
  ```
- Trip Details: `lib/features/trip/presentation/trip_details_screen.dart:309-320` — `'First departure'` / `'Last departure'` rows for scheduled, else `_DetailRow('Departs', 'When full', isLast: true)`.

Missing part, specific to the search-result card only: the SCHEDULED branch there does **not** show operating hours. It shows a next-departure/first-bus status instead (evidence above), and when `frequencyMinutes` is null while the route is inside its operating window, `_resolveStatus` returns `null` (`route_status_badge.dart:167`) so no badge is rendered at all (`route_status_badge.dart:119`), leaving that card with no departure-type indication. The operating-hours range appears only on the *Browse all routes* card and on Trip Details, not on the FR-03 search-result card.

### FR-09 — filter inactive routes and stops from student search while retaining them in the database

**IMPLEMENTED.**

Student-facing reads all filter on `isActive`:

- Stops: `route_repository.dart:42-52` `getAllStops()` — `.where('isActive', isEqualTo: true)` at line 45.
- Route search: `route_repository.dart:66-85` `searchRoutesByOrigin(...)` — `.where('isActive', isEqualTo: true)` at line 73.
- Browse all: `route_repository.dart:195-205` `getAllActiveRoutes()` — `.where('isActive', isEqualTo: true)` at line 198.

Retention in the database, with separate unfiltered admin reads:

- `route_repository.dart:160-163` `getAllStopsForAdmin()` — `_firestore.collection('stops').get()`, no filter, with the doc comment at lines 157-159 stating it returns every stop regardless of `isActive`.
- `route_repository.dart:167-170` `getAllRoutesForAdmin()` — same, no filter.
- Deactivation flips the flag rather than deleting: `setStopActive` (line 175) and `setRouteActive` (line 184) both `.update({'isActive': isActive})`.

Factual note: the Trip Details stop timeline renders the names held in the route document's own embedded `stops` array (`trip_details_screen.dart:111-116`) and performs no `isActive` check on them. Those entries are stored names (`RouteStop.stopName`, `lib/core/models/route_model.dart:63`), not looked-up `stops` documents — the admin form describes waypoints as free-form names (`lib/features/admin/presentation/add_route_screen.dart:20-23`).

---

## 2. Student authentication — does it exist at all?

**A student-facing auth screen EXISTS.** Two of them.

**Exact file paths:**

- `lib/features/auth/presentation/student_login_screen.dart` — `StudentLoginScreen` (line 11), `_StudentLoginScreenState` (line 18), handler `_signIn()` (line 34) calling `await _authRepository.signIn(email: email, password: password);` (line 51). Sign-in button at line 136.
- `lib/features/auth/presentation/student_signup_screen.dart` — `StudentSignUpScreen` (line 8), `_StudentSignUpScreenState` (line 15), handler `_signUp()` (line 33) calling `await _authRepository.signUp(email: email, password: password);` (line 58). Create-account button at line 139. Reached from the login screen at `student_login_screen.dart:147-157` ("Create an account").

Command run to find every non-admin reference:

```
grep -rn -E "AuthRepository|signIn|signUp|signOut" lib --include='*.dart' | grep -v '/admin/'
```

Non-admin hits outside the repository file itself:

```
lib/features/auth/presentation/student_login_screen.dart:19:  final _authRepository = AuthRepository();
lib/features/auth/presentation/student_login_screen.dart:34:  Future<void> _signIn() async {
lib/features/auth/presentation/student_login_screen.dart:51:      await _authRepository.signIn(email: email, password: password);
lib/features/auth/presentation/student_login_screen.dart:136:                    onPressed: _isLoading ? null : _signIn,
lib/features/auth/presentation/student_signup_screen.dart:16:  final _authRepository = AuthRepository();
lib/features/auth/presentation/student_signup_screen.dart:33:  Future<void> _signUp() async {
lib/features/auth/presentation/student_signup_screen.dart:58:      await _authRepository.signUp(email: email, password: password);
lib/features/auth/presentation/student_signup_screen.dart:139:                    onPressed: _isLoading ? null : _signUp,
lib/features/search/presentation/home_page.dart:35:  final AuthRepository _authRepository = AuthRepository();
lib/features/search/presentation/home_page.dart:172:  Future<void> _signOut() async {
lib/features/search/presentation/home_page.dart:196:    await _authRepository.signOut();
lib/features/search/presentation/home_page.dart:220:              onPressed: _signOut,
lib/main.dart:30:    final bool isSignedIn = AuthRepository().currentUser != null;
```

**Can a student use the app without signing in? YES.** Traced navigation:

1. `lib/main.dart:12-18` — `main()` initialises Firebase and runs `MyApp`.
2. `lib/main.dart:30` — `final bool isSignedIn = AuthRepository().currentUser != null;`
3. `lib/main.dart:36-42` — the initial route:
   ```dart
   home: kIsWeb
       ? const AdminLoginScreen()
       : SplashScreen(
     nextPage: isSignedIn
         ? const HomePage()
         : const StudentLoginScreen(),
   ),
   ```
4. `lib/core/presentation/splash_screen.dart:29` schedules `_goToNextPage` after 2 seconds; lines 38-40 do `pushReplacement` to `widget.nextPage`.
5. On `StudentLoginScreen`, `lib/features/auth/presentation/student_login_screen.dart:159-162`:
   ```dart
   OutlinedButton(
     onPressed: _isLoading ? null : _goToHome,
     child: const Text('Continue without signing in'),
   ),
   ```
   `_goToHome()` (lines 63-67) does `pushReplacement` straight to `const HomePage()`.
6. `HomePage` (`lib/features/search/presentation/home_page.dart:14`) performs no auth check before rendering. Its only auth-dependent element is the sign-out icon, shown conditionally at line 216: `if (_authRepository.currentUser != null)`. Search (`_search()`, line 112), Browse all routes (`_openAllRoutes()`, line 126), the stop picker (`_openStopPicker`, line 98) and Trip Details (pushed from `search_results_placeholder.dart:178-185` and `all_routes_screen.dart:116-120`) contain no sign-in gate.

The screen doc comment states the same intent at `student_login_screen.dart:7-10`: "Signing in is OPTIONAL — the 'Continue without signing in' button below goes straight to search". Sign-out returns the student to `StudentLoginScreen` (`home_page.dart:198-201`), and the dialog body at `home_page.dart:177-180` reads "You can still search buses as a guest."

The `AuthRepository` methods that back this are shared with admin: `signUp` (`lib/features/auth/data/auth_repository.dart:29`), `signIn` (line 49), `signOut` (line 69), `currentUser` (line 26). The doc comment at `auth_repository.dart:14` says "All authentication — student AND admin — goes through this class."

---

## 3. TODO / FIXME / placeholder scan

Command run:

```
grep -rn -i -E "TODO|FIXME|HACK|not implemented|coming soon|placeholder" lib --include='*.dart'
```

| File path | Line number | Exact line text |
| --- | --- | --- |
| `lib/core/models/route_model.dart` | 156 | `      priceJD: (data['priceJD'] as num).toDouble(),` |
| `lib/core/models/stop_model.dart` | 35 | `      latitude: (data['latitude'] as num).toDouble(),` |
| `lib/core/models/stop_model.dart` | 36 | `      longitude: (data['longitude'] as num).toDouble(),` |
| `lib/features/search/presentation/home_page.dart` | 10 | `import 'search_results_placeholder.dart';` |
| `lib/features/search/presentation/home_page.dart` | 117 | `        builder: (context) => SearchResultsPlaceholder(` |
| `lib/features/search/presentation/home_page.dart` | 163 | `        builder: (context) => SearchResultsPlaceholder(` |
| `lib/features/search/presentation/home_page.dart` | 364 | `/// stop's name once selected, or a placeholder before that.` |
| `lib/features/search/presentation/search_results_placeholder.dart` | 11 | `class SearchResultsPlaceholder extends StatefulWidget {` |
| `lib/features/search/presentation/search_results_placeholder.dart` | 12 | `  const SearchResultsPlaceholder({` |
| `lib/features/search/presentation/search_results_placeholder.dart` | 24 | `  State<SearchResultsPlaceholder> createState() =>` |
| `lib/features/search/presentation/search_results_placeholder.dart` | 25 | `      _SearchResultsPlaceholderState();` |
| `lib/features/search/presentation/search_results_placeholder.dart` | 30 | `class _SearchResultsPlaceholderState extends State<SearchResultsPlaceholder> {` |

What these hits actually are, stated so the table is not misread:

- The three `toDouble()` lines match only because a case-insensitive search for `TODO` matches the substring `toDo` inside `toDouble`. They are not markers.
- The nine `Placeholder` hits are all occurrences of the class name `SearchResultsPlaceholder` (the search-results screen, which is fully implemented — see FR-03/FR-05 above) plus one doc comment at `home_page.dart:364` describing hint text in a field.

Two narrower commands, run to separate real markers from substring coincidences:

```
grep -rn -E "TODO|FIXME|HACK" lib --include='*.dart'
```
→ no matches (case-sensitive).

```
grep -rn -i -E "not implemented|coming soon" lib --include='*.dart'
```
→ no matches.

So: there are no case-sensitive `TODO`, `FIXME`, or `HACK` markers, and no "not implemented" or "coming soon" strings anywhere under `lib/`.

---

## 4. Chapter 4.3 figure captions vs. actual screens

Note on the count: the request's heading says eleven screens, and the list that follows contains nine captions. All nine listed captions are checked below.

| # | Caption | Verdict | File path and evidence |
| --- | --- | --- | --- |
| 1 | Home screen with origin/destination selection and recent searches | Present | `lib/features/search/presentation/home_page.dart` — `HomePage` (line 14) / `_HomeView` (line 23). From/To fields: `_StopField` at lines 258-263 (`label: 'From'`) and 265-271 (`label: 'To (optional)'`). Recent searches: `_loadRecentSearches()` (line 47), `_saveRecentSearch(...)` (line 61), `_useRecentSearch(...)` (line 138), and the `'RECENT'` section rendered at lines 322-354. |
| 2 | Stop picker listing only active stops with type-to-filter search | Present | `lib/features/search/presentation/widgets/stop_picker_sheet.dart` — `StopPickerSheet` (line 8). Active-only via `getAllStops()` (`route_repository.dart:45`). Type-to-filter: `TextField` line 82, `onChanged` line 83, filter lines 59-61. |
| 3 | Search results ordered soonest-departure-first with direction and status badges | Present | `lib/features/search/presentation/search_results_placeholder.dart` — sort at lines 56-60; subtitle `'soonest departure first'` line 106; direction badge `_DirectionChip` used at line 219, class at line 247; status badge `RouteStatusBadge(route: route)` at line 238, class in `lib/features/search/presentation/widgets/route_status_badge.dart:111`. |
| 4 | Trip details with ordered stop timeline, fare, duration, operating days and departure pattern | Present | `lib/features/trip/presentation/trip_details_screen.dart` — `TripDetailsScreen` (line 81). Ordered timeline: `_allStopNames` getter sorting by `order` (lines 111-116), rendered by `_buildStopsCard()` (line 225) and `_StopRow` (line 331). Fare: `_DetailRow('Price', ...)` line 303. Duration: line 304. Operating days: lines 305-308 with `formatOperatingDays` (line 44). Departure pattern: lines 309-320. |
| 5 | Browse all routes | Present | `lib/features/search/presentation/all_routes_screen.dart` — `AllRoutesScreen` (line 11); AppBar title `'All routes'` (line 63); entry point `_openAllRoutes()` at `home_page.dart:126` with the button labelled `'Browse all routes'` at `home_page.dart:312`. |
| 6 | Empty state naming the stop that returned no routes | Present | `lib/features/search/presentation/search_results_placeholder.dart:145-166`, specifically line 155: `'No buses found from ${widget.fromStop.name} yet.'` |
| 7 | Offline banner shown when results are served from cache | Present | `lib/core/widgets/offline_banner.dart` — `OfflineBanner` (line 5), text line 20. Rendered when `_isOffline` is true at `search_results_placeholder.dart:170` (`_isOffline` set from `result.isFromCache` at line 65) and at `all_routes_screen.dart:105` (set at line 40). |
| 8 | Administrator dashboard routes data table with status pills and row menu | Present | `lib/features/admin/presentation/admin_manage_screen.dart` — `RoutesManageList` (line 685). Table via `_TableCard` at line 810 (class line 357); header cells lines 812-818 (`'Route'`, `'Operator'`, `'Origin'`, `'Destination'`, `'Price'`, `'Status'`); status pill `_StatusPill(isActive: route.isActive, flex: 2)` at line 833 (class line 166); row menu `_RowMenu(...)` at line 834 (class line 202, `PopupMenuButton<String>` at line 221). |
| 9 | Administrator route edit form with waypoint reordering | Present | `lib/features/admin/presentation/add_route_screen.dart` — `RouteFormPanel` (line 30), edit mode via `existingRoute` (doc comment lines 15-18; pre-fill at line 104). Waypoint reordering: `_moveWaypoint(int index, int delta)` (line 231), wired to per-row callbacks at lines 648-651, with the up/down icon buttons at lines 752-760 (`Icons.arrow_upward` / `Icons.arrow_downward`, tooltips `'Move up'` / `'Move down'`) and the instruction text at line 624 ("Waypoints are saved in the order shown. Use the arrows to …"). |

**No caption in the list is MISSING** — all nine have a matching widget/screen file under `lib/features/` (caption 7's banner itself lives in `lib/core/widgets/`, and is consumed by two screens under `lib/features/search/`).

---

## 5. Uncommitted or divergent work

### `git status --porcelain`

```
 M .gitignore
 M lib/features/admin/presentation/admin_home_screen.dart
?? docs/design-audit-2026-08-22.md
?? docs/fr10-code-review-input.md
?? docs/fr10-fix-verification.md
?? lib/features/admin/presentation/admin_home_screen.dart.bak
```

### `git log --oneline -10`

```
2fa3c4c firestore.rules: admins/{adminId} allows self-read only (request.auth.uid == adminId), write stays fully denied
ac19661 docs: add Round 2 verification (SR-13 to SR-16) for admins self-read rule
147622e feat(admin-auth): gate Admin Dashboard on admins collection membership
27f7dba fix: resolve data access error in _loadStops within add_route_screen
6555027 chore: remove the temporary report file
7f47ea6 chore: hide the debug banner for screenshots
0cb23c8 fix(trip): stop rendering origin and destination twice in the stops timeline
d0c5bdc feat(admin): add route edit form, waypoint reordering, and every-day operating days
d8e785d feat(admin): add an Edit entry to route rows
b84b90a feat(admin): give the route form an edit mode, waypoint reordering, and admin stop list
```

### `git branch -a`

```
+ claude/remote-control-ad61b3
* dev
  main
  remotes/origin/HEAD -> origin/main
  remotes/origin/dev
  remotes/origin/main
```

(These three blocks are the raw command output, unmodified. This audit file itself was created after those commands ran, so it does not appear in the `git status` listing above.)

---

## 6. Chapter 7 Future Work cross-check

Command run against `lib/`:

```
grep -rn -i -E "Chapter 7|Future Work|Ch\.7|Ch 7" lib --include='*.dart'
```

Four hits, all in one file, forming three distinct documented simplifications.

### Hit 1 — `lib/features/search/data/route_repository.dart:126`

Line 126 reads: `  /// in the stop edit form, and an automatic cascade is a Chapter 7`

Full comment block it belongs to (`route_repository.dart:106-127`, the doc comment on `updateRoute`):

```dart
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
```

### Hit 2 — `lib/features/search/data/route_repository.dart:148`

Line 148 reads: `  /// simplification, logged for Ch.7 Future Work alongside the`

Full comment block (`route_repository.dart:135-149`, the doc comment on `updateStop`):

```dart
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
```

### Hits 3 and 4 — `lib/features/search/data/route_repository.dart:215` and `:216`

Line 215 reads: `  /// is a deliberate simplification for the MVP. Logged for Ch.7`
Line 216 reads: `  /// Future Work as "referential integrity checks before deletion".`

Full comment block (`route_repository.dart:207-216`, the doc comment on `deleteStop`):

```dart
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
```

### Related hits outside `lib/`

Command run repo-wide (excluding `.claude/worktrees/`):

```
grep -rn -i -E "Chapter 7|Future Work|Ch\.7" . --include='*.dart' --include='*.md' --include='*.rules' --include='*.yaml' | grep -v '\.claude/worktrees'
```

Two additional hits, neither of them a code comment:

- `CLAUDE.md:100` — `documented as Future Work, not implemented.` (closing line of the "Scope boundaries" section, which lists: no live GPS tracking, no in-app payments, no driver ratings, no push notifications, no multi-leg/transfer journey planning).
- `docs/data-model.md:100` — a paragraph ending: "A composite index would only become necessary if a future query added a range filter (for example, filtering by `priceJD`) or an `orderBy` on a field different from the equality filters — tracked as a Future Work item, not a current requirement."

### What is documented in code vs. what is not

Documented as Future Work in a code comment (all in `lib/features/search/data/route_repository.dart`):

1. Stop rename does not cascade to the denormalised `originStopName` / `destinationStopName` copies held by routes (lines 118-127 and 143-149).
2. No referential-integrity check before `deleteStop` (lines 207-216).

Documented outside code: composite-index limits (`docs/data-model.md:100`); the five out-of-scope features (`CLAUDE.md:100`).

Findings from Sections 1-4 above that carry **no** "Chapter 7"/"Future Work" comment anywhere in `lib/` — per the grep result above, the only four such comments in `lib/` are the ones quoted, all in `route_repository.dart`:

- FR-01: no proximity / "near AAU" filter of any kind (`stop_picker_sheet.dart`, `route_repository.dart:42-52`).
- FR-02: search matches `originStopId` only, not stops held in the route's embedded `stops` array (`route_repository.dart:66-85`).
- FR-03: destination stop name is absent from the search-result card (`search_results_placeholder.dart:194-242`).
- FR-03 / FR-08: a SCHEDULED route inside its operating window with `frequencyMinutes == null` renders no badge and no operating-hours line on the search-result card (`route_status_badge.dart:161-167` and `:119`; the comment at lines 164-166 refers to an "operating hours line" that `_buildRouteCard` does not render).
- FR-04: the Maps link is a `/maps/dir/` directions URL rather than the `/maps/search/?api=1&query=LAT,LON` form; and the coordinate path is skipped entirely when `originStop` is null, which is the path taken from Browse all routes (`trip_details_screen.dart:118-132`, `all_routes_screen.dart:118`).
- FR-05: Browse all routes applies no sort (`all_routes_screen.dart:33-54`).
- FR-06: no explicit Firestore persistence configuration anywhere in `lib/` (grep for `persistenceEnabled|Settings(|enablePersistence|cacheSizeBytes` returned no matches).
- FR-09: the Trip Details stop timeline renders stored waypoint names with no `isActive` check (`trip_details_screen.dart:111-116`).
- Section 2: student sign-in/sign-up screens exist and are fully wired, while `CLAUDE.md` (the "### Auth" section) states auth is admin-only with no student sign-up or sign-in. That divergence is not noted in any code comment; `auth_repository.dart:14` and `student_login_screen.dart:7-10` document the student path as intended behaviour.
