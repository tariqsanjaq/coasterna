# Coasterna — Project Gap Re-Check (2026-09-01)

Read-only re-verification of `docs/audit-trail/project-gap-audit.md` against the current state of branch `dev`. Every file below was re-read fresh in this session; none of the old audit's line numbers were trusted or reused without re-confirming against current file content. No file was modified except this report.

Note on the old audit's reliability: `docs/audit-trail/project-gap-audit.md` cites file paths that do not exist on the current tree (e.g. `lib/core/presentation/splash_screen.dart`, which is currently `lib/features/splash/presentation/splash_screen.dart`) and describes a `main.dart`/splash flow (`isSignedIn` check, `SplashScreen(nextPage: ...)`) that does not match the current `main.dart`/`SplashScreen` content. That audit was evidently run against a different code state than what's on `dev` now. `git log` (section 8 below) shows five commits between then and now that plausibly explain the fixes found: `a160436`, `91c4165`, `106cf9f`, `36e274a`, and the two after them.

---

## 1. FR-01 — proximity / "near AAU" filter

**STILL OPEN.**

Command re-run fresh:

```
grep -rn -i -E "distance|radius|nearby|proximity|geopoint|haversine" lib --include='*.dart'
```

Every one of the 47 hits returned is `AppRadius`/`BorderRadius`/`kAdminFieldRadius` UI corner-radius styling (e.g. `lib/core/theme/app_theme.dart:40,90,98,106`, `lib/features/admin/presentation/admin_form_widgets.dart:20-22,76,118,137,141,145,256,294`, `lib/features/search/presentation/all_routes_screen.dart:176,206,232,326`, `lib/features/search/presentation/home_page.dart:105-106,257,305-306,339,406,415`, `lib/features/trip/presentation/trip_details_screen.dart:195,227,280`, and similar in every other screen file). None of `distance`, `nearby`, `proximity`, `geopoint`, or `haversine` appears anywhere in `lib/`.

`StopModel` still stores `latitude`/`longitude` (`lib/core/models/stop_model.dart:9-10`) but nothing in `lib/` reads them for filtering or sorting a stop list — `getAllStops()` (`lib/features/search/data/route_repository.dart:42-52`) filters only on `isActive`, and `StopPickerSheet`'s only filter is the name substring match (`lib/features/search/presentation/widgets/stop_picker_sheet.dart:59-61`). No proximity/"near AAU" element of any kind exists.

## 2. FR-03 — destination name on the search-result card / `_DirectionChip`

**Destination name: ALREADY FIXED.** **`_DirectionChip`: unchanged (still three fixed labels).**

Fresh read of `lib/features/search/presentation/search_results_placeholder.dart`, `_buildRouteCard` (lines 194-251):

```dart
222          const SizedBox(height: AppSpacing.xs),
223          Text(
224            'Board at: ${widget.fromStop.name}',
...
230          const SizedBox(height: AppSpacing.xs),
231          Text(
232            'To: ${route.destinationStopName}',
233            style: const TextStyle(
```

Line 232-233 now prints `'To: ${route.destinationStopName}'` as its own line on the card, directly below the "Board at" origin line. This directly contradicts the old audit's "destination is not printed on the search-result card" finding — it is now printed, unconditionally, for every card.

`_DirectionChip` (lines 254-270) is unchanged from the old audit's description — it still emits exactly one of three fixed strings, never the destination name itself:

```dart
262    final String label;
263    if (route.destinationStopName.toLowerCase().contains('aau')) {
264      label = 'To AAU';
265    } else if (route.direction == RouteDirection.outbound) {
266      label = 'Towards AAU';
267    } else {
268      label = 'From AAU';
269    }
```

(It does read `route.destinationStopName` at line 263, but only to test for the substring "aau", not to display it.)

## 3. FR-03/FR-08 — `_resolveStatus` for SCHEDULED + inside window + `frequencyMinutes == null`

**ALREADY FIXED.**

Fresh read of `lib/features/search/presentation/widgets/route_status_badge.dart`, `_resolveStatus` (lines 155-184):

```dart
155    _BadgeStyle? _resolveStatus(DateTime now) {
156      if (!routeRunsToday(route, now)) return _BadgeStyle.noService;
157
158      if (route.departureType != DepartureType.scheduled) {
159        return showWhenFullDetail
160            ? _BadgeStyle.whenFullDetailed
161            : _BadgeStyle.whenFull;
162      }
163
164      final first = parseTimeOnDay(route.firstDeparture, now);
165      final last = parseTimeOnDay(route.lastDeparture, now);
166
167      if (first != null && now.isBefore(first)) {
168        return _BadgeStyle.firstBusAt(
169          formatTimeLabel(route.firstDeparture, now),
170        );
171      }
172      if (last != null && now.isAfter(last)) return _BadgeStyle.serviceEnded;
173
174      final wait = minutesUntilNextDeparture(route, now);
175      if (wait != null) return _BadgeStyle.nextBus(wait);
176
177      // Scheduled, inside operating hours, but frequencyMinutes is
178      // missing. We can't invent a wait time, so fall back to showing
179      // the operating-hours range instead of an empty card.
180      return _BadgeStyle.operatingHours(
181        formatTimeLabel(route.firstDeparture, now),
182        formatTimeLabel(route.lastDeparture, now),
183      );
184    }
```

For the exact case in the question — SCHEDULED, inside the operating window (past `first`, before `last`), `frequencyMinutes == null` so `minutesUntilNextDeparture` returns `null` (its own null check is `route_status_badge.dart:71-72`) — execution now falls through to lines 180-183 and returns `_BadgeStyle.operatingHours(...)`, a new factory (lines 225-231 of the same file) that renders `'$first - $last'` in the green style. `_resolveStatus` has no remaining `return null;` path at all: every branch (`noService`, `whenFull`/`whenFullDetailed`, `firstBusAt`, `serviceEnded`, `nextBus`, `operatingHours`) returns a non-null `_BadgeStyle`. `build()`'s `if (status == null) return const SizedBox.shrink();` (line 129-130) is consequently unreachable code now, but the reported symptom — the card silently showing nothing for this case — no longer happens.

## 4. FR-04 — `_openInMaps()` URL, `originStop` optionality, `destinationParam`

**PARTIALLY FIXED.** URL scheme is fixed; the null-origin fallback is not.

Fresh read of `lib/features/trip/presentation/trip_details_screen.dart:107-135`:

```dart
107  Future<void> _openInMaps() async {
...
111    final String query = widget.originStop != null
112        ? '${widget.originStop!.latitude},${widget.originStop!.longitude}'
113        : widget.route.originStopName;
...
118    final uri = Uri.parse(
119      'https://www.google.com/maps/search/?api=1'
120          '&query=${Uri.encodeComponent(query)}',
121    );
```

- **URL scheme: ALREADY FIXED.** It is now `https://www.google.com/maps/search/?api=1&query=...` (a single-pin search link), not the old `/maps/dir/?api=1&origin=...&destination=...` directions link the prior audit quoted. This matches the format CLAUDE.md's Firestore section locks in (`LAT,LON` query string).
- **`originStop` optionality/null-fallback: STILL OPEN.** `originStop` is still declared `final StopModel? originStop;` (line 89), and the ternary at lines 111-113 still falls back to the plain name string `widget.route.originStopName` (no coordinates) whenever `originStop` is null.
- **`destinationParam`: no longer applicable.** The new single-query-pin URL has no destination parameter at all — there is nothing named `destinationParam` in the current file, and no destination value (name or coordinates) is sent to Maps any more. The old audit's third finding ("destination is always a name string, never coordinates") describes code that no longer exists; the whole directions-link approach was replaced.

## 5. FR-04 — `all_routes_screen.dart` constructing `TripDetailsScreen` without `originStop`

**ALREADY FIXED** (for the common case; a residual null path remains and is the same gap named in item 4).

Fresh read of `lib/features/search/presentation/all_routes_screen.dart`:

```dart
37    /// Active stops keyed by document id, so tapping a route card can
38    /// hand TripDetailsScreen the origin StopModel — and with it the
39    /// real latitude/longitude the Google Maps link needs. Loaded once
40    /// alongside the routes, using the repository's existing
41    /// getAllStops(). The search flow already passes its own fromStop,
42    /// so this map only serves the browse flow.
43    Map<String, StopModel> _stopsById = {};
...
59      Map<String, StopModel> stopsById = {};
60      try {
61        final stopsResult = await widget.repository.getAllStops();
62        stopsById = {
63          for (final stop in stopsResult.data) stop.id: stop,
64        };
65      } catch (_) {
66        stopsById = {};
67      }
...
178                  Navigator.of(context).push(
179                    MaterialPageRoute(
180                      builder: (context) => TripDetailsScreen(
181                        route: route,
182                        originStop: _stopsById[route.originStopId],
183                      ),
184                    ),
185                  );
```

The call now explicitly passes `originStop: _stopsById[route.originStopId]` (line 182) — it is no longer the bare `TripDetailsScreen(route: route)` the old audit quoted. `_stopsById` is populated from a second `getAllStops()` read done alongside the routes read (lines 51-67).

Residual gap, not a new finding — this is the same still-open condition from item 4: `_stopsById[route.originStopId]` is a `Map` lookup and returns `null` if that stop id is not a key in the map (e.g. the origin stop was deactivated, since `getAllStops()` at `route_repository.dart:42-52` filters to `isActive: true` only, or if the stops read at lines 60-66 threw and fell back to `{}`). In that case `originStop` is still `null` and `_openInMaps()` still falls back to the name-only string. This is narrower than the old "always null from Browse all routes" finding, but not fully closed.

## 6. FR-05 — `all_routes_screen.dart` `_loadRoutes()` sort call

**STILL OPEN.**

```
grep -n "\.sort(" lib/features/search/presentation/all_routes_screen.dart
```

returns no matches (exit code 1, no output). Fresh read of `_loadRoutes()` (lines 51-87) confirms: it assigns `_routes = result.data;` (line 71) directly from the repository result with no `.sort(` call anywhere in the method, or anywhere else in the file. Browse all routes still renders routes in whatever order Firestore returns them; only `search_results_placeholder.dart` sorts by `routeDepartureRank` (unchanged, confirmed present at lines 56-60 of that file, calling `routeDepartureRank` from `route_status_badge.dart:93-106`).

## 7. Student auth vs. CLAUDE.md

Both screens still exist and are still reachable without any auth gate — confirmed by a fresh read of both files and their callers:

- `lib/features/auth/presentation/student_login_screen.dart` — `StudentLoginScreen`/`_StudentLoginScreenState` unchanged from the earlier read: `_signIn()` (line 34), "Continue without signing in" `OutlinedButton` at line 159-162 calling `_goToHome()` (lines 63-67), which pushes straight to `HomePage`.
- `lib/features/auth/presentation/student_signup_screen.dart` — `StudentSignUpScreen`, `_signUp()` (line 33), reached via "Create an account" from the login screen (`student_login_screen.dart:147-157`).

Current navigation path is **not** the one the old audit described (that audit's `main.dart`/`SplashScreen` code — `isSignedIn` check, `nextPage: isSignedIn ? HomePage : StudentLoginScreen` — does not exist on this branch). The current path, re-confirmed fresh:

- `lib/main.dart:27` — `home: kIsWeb ? const AdminLoginScreen() : const SplashScreen(),` — no `isSignedIn` branching.
- `lib/features/splash/presentation/splash_screen.dart:20-30` — after a fixed 1-second timer, `initState` pushes straight to `const HomePage()` unconditionally — it does not route through `StudentLoginScreen` at all.
- `lib/features/search/presentation/home_page.dart:227-237` — `HomePage` shows a "Sign in" icon (`Icons.lock_outline`) only `if (_authRepository.currentUser == null)`, which pushes `StudentLoginScreen` on tap. This is the only path to the student auth screens; nothing on `HomePage`, search, browse, or trip details requires it.

Net effect is the same substantive claim CLAUDE.md makes — no student-facing screen requires sign-in — but the mechanism changed: mobile now lands on `HomePage` directly with sign-in as an optional icon, rather than opening on `StudentLoginScreen` with a "Continue without signing in" button as the entry gate. CLAUDE.md's Auth section still describes the "Continue without signing in" button (accurate — it's still on `StudentLoginScreen`, still fully optional) but does not mention that mobile no longer opens on that screen by default.

Current, verbatim text of CLAUDE.md's `### Auth` section (re-read fresh; this section carries no diff marker in today's on-disk file, i.e. it reads the same as what changed in over yesterday's memory-noted diff):

> ### Auth
>
> All authentication — student AND admin — goes through `AuthRepository`
> (`lib/features/auth/data/auth_repository.dart`). Two independent flows:
>
> - **Student — optional.** `StudentLoginScreen` and `StudentSignUpScreen`
>   (`lib/features/auth/presentation/`) let a student sign in or create an account,
>   but "Continue without signing in" on the login screen goes straight to
>   `HomePage` as a guest. **No screen in the student-facing flow (search, browse,
>   trip details) requires a signed-in user.** This is a deliberate, confirmed
>   decision — do not add an auth gate to any student screen without asking.
> - **Admin — required.** `AdminLoginScreen` (reached as the home route when
>   `kIsWeb`, in `main.dart`) gates the Admin Dashboard on membership in the
>   `admins` Firestore collection — existence of `admins/{uid}` is the permission
>   check, not a role field. Firestore rule (published): `admins/{adminId}` allows
>   self-read only (`request.auth.uid == adminId`); write is fully denied
>   (console-managed only).
>
> **Pending scope item, not yet built:** the supervisor asked for student
> sign-in to unlock at least one real feature (currently it unlocks nothing beyond guest
> access). Candidate: saved/favorite routes, which needs a fourth Firestore collection
> and reopens the closed three-collection decision below. Do not build any
> version of this without an explicit go-ahead. Full context in
> `docs/project-status.md`.

This section still says auth is optional for students, admin-only-required — it does **not** say "admin-only" in the sense of forbidding student auth; the old audit's Section 2 framing ("CLAUDE.md states auth is admin-only with no student sign-up or sign-in") does not match the current (or, per the file's own history available to this session, the previously-quoted) text of this section — no divergence between code and this doc was found on re-read.

## 8. Fresh command output

### `git status --porcelain`

```
AM docs/project-status.md
?? docs/audit-trail/full-code-audit-2026-08-31.md
```

No tracked file under `lib/`, `test/`, `firestore.rules`, or `pubspec.yaml` is modified or untracked. The only pending changes are to `docs/project-status.md` (staged then further modified) and the untracked audit report this session produced yesterday (`docs/audit-trail/full-code-audit-2026-08-31.md`); this recheck's own new report file does not yet appear here because it was created after this command ran.

### `git log --oneline -10`

```
e554e6b fix(all-routes): match spec page 14 - header colour, badge width/wording, price chip border, row alignment; reorganize docs into docs/audit-trail/
f081ce2 fix(main): restore admin route and app theme
81434b9 feat: complete Task #14 (app icon, splash screen, about page, guest entry point)
91c4165 fix(search): pass origin stop coordinates from Browse all routes
a160436 Fix search result destination label, operating hours display, and Google Maps pin link
36e274a docs: add Task #10 waypoint search matching review (D38)
106cf9f feat(search): add waypoint-aware route search matching (D38, Task #10)
03decdc fix(admin): route sign-out through AuthRepository; add FR-10 review docs
2fa3c4c firestore.rules: admins/{adminId} allows self-read only (request.auth.uid == adminId), write stays fully denied
ac19661 docs: add Round 2 verification (SR-13 to SR-16) for admins self-read rule
```

Note: `HEAD` (`e554e6b`) matches the last commit reported at the start of this session. Commits `a160436` ("Fix search result destination label, operating hours display, and Google Maps pin link") and `91c4165` ("pass origin stop coordinates from Browse all routes") directly correspond to the fixes found in items 2-5 above; `81434b9`/`f081ce2`/`e554e6b` correspond to the splash/main.dart changes found in item 7.

### `git branch -a`

```
+ claude/remote-control-ad61b3
* dev
  main
  remotes/origin/HEAD -> origin/main
  remotes/origin/dev
  remotes/origin/main
```

Same branch set as the old audit recorded; currently on `dev`, matching the task's stated scope.
