# Coasterna — Device-Local Favorite Routes Feature (2026-09-01)

Branch `dev`, HEAD at session start: `a86c904` (the previous batch-fix session — Tariq had already committed it between sessions, using the suggested message from that session's report). Building with blanket permission already granted by Abdallah and Gaith to touch `route_repository.dart`, `main.dart`, and Gaith's screens. No `git add`/`commit`/`push` run. Firestore, `firestore.rules`, and every Firestore collection/schema were left untouched — this feature is 100% local (`SharedPreferences`), no new Firestore collection, no Security Rules change. Every file below was read in full before editing.

---

## Step 1 — read first

Read in full, before any edit:

- `lib/features/search/presentation/home_page.dart` — studied `_loadRecentSearches()` (try/catch around `SharedPreferences.getInstance()` + `jsonDecode`, `debugPrint` on failure, never rethrows, `_isLoadingRecentSearches` flag) and `_saveRecentSearch()` (`jsonEncode` back to `SharedPreferences`). This is the exact pattern `FavoritesRepository` mirrors.
- `lib/features/search/data/route_repository.dart` — confirmed `getAllActiveRoutes()` (line 248 as of this session's start) returns `RepoResult<List<RouteModel>>` filtered to `isActive: true`, and `getAllStops()` returns `RepoResult<List<StopModel>>`.
- `lib/features/search/presentation/search_results_placeholder.dart` — `_buildRouteCard(RouteModel route)`, confirmed the "To: ..." destination line and `RouteStatusBadge` were both already present (from the previous recheck session's fixes) and needed to be kept intact.
- `lib/features/search/presentation/all_routes_screen.dart` — `_buildRouteCard(RouteModel route)`, confirmed a placeholder `const SizedBox.shrink()` already sat in the subtitle row as a natural insertion point, and `_stopsById` (built from `getAllStops()`) was already there for the Maps-coordinates hand-off to `TripDetailsScreen`.
- `lib/features/trip/presentation/trip_details_screen.dart` — confirmed the `AppBar` had no `actions` yet, and `widget.route.id` was available.
- `lib/features/auth/data/auth_repository.dart` — confirmed `currentUser` getter (`User? get currentUser => _auth.currentUser;`, line 26) is what every gate in this session checks (`_authRepository.currentUser != null`).
- `lib/core/models/route_model.dart` — confirmed `RouteModel.id` (line 92) is the field used as the favorite key everywhere.

No line numbers from any prior report were trusted — everything above was re-confirmed against the files as they stood at the start of this session.

---

## Step 2 — `FavoritesRepository`

**New file:** `lib/features/favorites/data/favorites_repository.dart`

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local favorite routes for signed-in students.
///
/// DELIBERATE MVP DECISION (D49), NOT A MISSED REQUIREMENT — favorites
/// are stored in `SharedPreferences` on this device only, never in
/// Firestore. They do not sync across a student's devices and are
/// lost if the app is uninstalled. A Firestore-backed version (a
/// `students/{uid}/favorites` collection) was considered and
/// explicitly deferred — that would reopen the closed three-collection
/// Firestore decision, which is out of scope here. See CLAUDE.md's
/// pending student-favorites scope item.
class FavoritesRepository {
  static const _key = 'favorite_route_ids';

  /// Reads the stored set of favorite route ids. Malformed or
  /// unreadable stored data must never crash a screen — on any error
  /// this returns an empty set, mirroring the pattern
  /// `_loadRecentSearches` uses in home_page.dart.
  Future<Set<String>> getFavoriteRouteIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<String>().toSet();
    } catch (e) {
      debugPrint('Could not load favorite routes: $e');
      return {};
    }
  }

  /// Convenience wrapper over [getFavoriteRouteIds] for a single route.
  Future<bool> isFavorite(String routeId) async {
    final ids = await getFavoriteRouteIds();
    return ids.contains(routeId);
  }

  /// Adds [routeId] to the favorites set if it is absent, removes it
  /// if it is already present, then writes the whole set back as a
  /// JSON list.
  Future<void> toggleFavorite(String routeId) async {
    final ids = await getFavoriteRouteIds();
    if (ids.contains(routeId)) {
      ids.remove(routeId);
    } else {
      ids.add(routeId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ids.toList()));
  }
}
```

Matches home_page.dart's pattern exactly: same `try`/`catch` shape around `SharedPreferences.getInstance()` + `jsonDecode`, same `debugPrint` (no import needed beyond `package:flutter/foundation.dart`, same as `home_page.dart` gets it transitively via `material.dart`), same "never rethrow, treat as empty" rule, same `jsonEncode`-back-to-`SharedPreferences` write path. The class-level doc comment documents D49 as instructed — local-only, no sync, lost on uninstall, deferred Firestore version.

---

## Step 3 — `FavoriteButton`

**New file:** `lib/features/favorites/presentation/favorite_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/favorites_repository.dart';

/// Star toggle for one route's favorite status.
///
/// ASSUMES the caller has already checked that a student is signed
/// in — this widget does not check `AuthRepository().currentUser`
/// itself. Favoriting is device-local and has no concept of "whose"
/// favorite it is, so nothing here would actually break for a guest;
/// the auth gate exists purely so guests are not shown a feature that
/// implies an account. Every call site is expected to wrap this
/// widget in `if (_authRepository.currentUser != null) ...` the same
/// way the sign-out icon in home_page.dart is gated.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.routeId, this.onChanged});

  final String routeId;

  /// Called after a successful toggle with the new favorited state.
  /// Optional — most call sites don't need it. FavoritesScreen uses it
  /// to remove a card from its own list the moment it is unfavorited,
  /// without waiting for a full reload.
  final ValueChanged<bool>? onChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _repository = FavoritesRepository();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final isFavorite = await _repository.isFavorite(widget.routeId);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorite);
  }

  Future<void> _toggle() async {
    await _repository.toggleFavorite(widget.routeId);
    if (!mounted) return;
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    // The icon change itself is the feedback — no snackbar needed.
    return IconButton(
      icon: Icon(
        _isFavorite ? Icons.star : Icons.star_border,
        color: _isFavorite ? AppColors.accent : AppColors.textTertiary,
      ),
      tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: _toggle,
    );
  }
}
```

Sizing/pattern match: built as a plain `IconButton` — the exact same widget home_page.dart uses for the info/sign-in/sign-out icons (`IconButton(icon: const Icon(...), tooltip: ..., onPressed: ...)`), so it inherits Material's default `IconButton` touch target and padding automatically instead of a bespoke size. Colors are `AppColors.accent` (gold — the same token the "RECENT" icon and stop-picker accents already use) for the filled star and `AppColors.textTertiary` for the outline, both existing tokens, no new colors introduced.

The one addition beyond the prompt's exact skeleton is the optional `onChanged` callback — needed for Step 5's optimistic-removal choice (documented there) — every other call site (Steps 4a–4c) ignores it and behaves exactly as specified: toggle, flip local state, no snackbar.

---

## Step 4 — wiring into the three route cards

### 4a. `search_results_placeholder.dart`

Added imports:
```dart
import '../../auth/data/auth_repository.dart';
import '../../favorites/presentation/favorite_button.dart';
```
Added field to `_SearchResultsPlaceholderState`:
```dart
final AuthRepository _authRepository = AuthRepository();
```

**Before** (`_buildRouteCard`, price/badge area):
```dart
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${route.priceJD.toStringAsFixed(2)} JD'
                ' · about ${route.durationMinutes} min',
            style: AppTextStyles.monoData(fontSize: 13.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          RouteStatusBadge(route: route),
```

**After:**
```dart
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${route.priceJD.toStringAsFixed(2)} JD'
                    ' · about ${route.durationMinutes} min',
                style: AppTextStyles.monoData(fontSize: 13.5),
              ),
              if (_authRepository.currentUser != null)
                FavoriteButton(routeId: route.id),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RouteStatusBadge(route: route),
```

The "To: ..." destination line (unaffected, sits above this block) and the `RouteStatusBadge` line are both untouched, per instructions. `git diff --numstat`: `15  4  lib/features/search/presentation/search_results_placeholder.dart`.

### 4b. `all_routes_screen.dart`

Added imports:
```dart
import '../../auth/data/auth_repository.dart';
import '../../favorites/presentation/favorite_button.dart';
```
Added field to `_AllRoutesScreenState`:
```dart
final AuthRepository _authRepository = AuthRepository();
```

**Before** (`_buildRouteCard`, subtitle row — the trailing `SizedBox.shrink()` was an unused placeholder already sitting exactly where a trailing element belongs):
```dart
              Expanded(
                child: Text(
                  _subtitleFor(route),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const SizedBox.shrink(),
            ],
          ),
```

**After:**
```dart
              Expanded(
                child: Text(
                  _subtitleFor(route),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (_authRepository.currentUser != null)
                FavoriteButton(routeId: route.id)
              else
                const SizedBox.shrink(),
            ],
          ),
```

`git diff --numstat`: `8  1  lib/features/search/presentation/all_routes_screen.dart`.

### 4c. `trip_details_screen.dart`

Added imports:
```dart
import '../../auth/data/auth_repository.dart';
import '../../favorites/presentation/favorite_button.dart';
```
Added field to `_TripDetailsScreenState`:
```dart
final AuthRepository _authRepository = AuthRepository();
```

**Before** (`AppBar`, right after the title `Column`, no `actions` existed):
```dart
            Text(
              route.operatorName,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
```

**After** (button placed in the AppBar's `actions`, next to the title, not buried in a detail row — same pattern home_page.dart already uses for its icons):
```dart
            Text(
              route.operatorName,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (_authRepository.currentUser != null)
            FavoriteButton(routeId: route.id),
        ],
      ),
      body: SafeArea(
```

`git diff --numstat`: `8  0  lib/features/trip/presentation/trip_details_screen.dart`.

---

## Step 5 — `FavoritesScreen`

**New file:** `lib/features/favorites/presentation/favorites_screen.dart`

Constructor follows `all_routes_screen.dart`'s exact pattern — takes the existing `RouteRepository` instance rather than constructing its own:
```dart
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.repository});

  final RouteRepository repository;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}
```

Loading pipeline (`_loadFavorites()`), matching the requested steps 1-3 (favorite ids → `getAllActiveRoutes()` → filter to the favorite set), plus the same soonest-departure sort and the same tolerant secondary `getAllStops()` read `all_routes_screen.dart` uses for `_stopsById`:

```dart
  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    List<RouteModel> favoriteRoutes = [];
    Map<String, StopModel> stopsById = {};
    try {
      final favoriteIds = await _favoritesRepository.getFavoriteRouteIds();
      final result = await widget.repository.getAllActiveRoutes();

      try {
        final stopsResult = await widget.repository.getAllStops();
        stopsById = {
          for (final stop in stopsResult.data) stop.id: stop,
        };
      } catch (_) {
        stopsById = {};
      }

      favoriteRoutes = result.data
          .where((route) => favoriteIds.contains(route.id))
          .toList();

      final now = DateTime.now();
      favoriteRoutes.sort(
        (a, b) =>
            routeDepartureRank(a, now).compareTo(routeDepartureRank(b, now)),
      );
    } catch (e) {
      debugPrint('Could not load favorite routes: $e');
      favoriteRoutes = [];
    }

    if (!mounted) return;
    setState(() {
      _routes = favoriteRoutes;
      _stopsById = stopsById;
      _isLoading = false;
    });
  }
```

**Three states, exactly as specified** (no fourth "error" state — a failed read degrades to the empty list instead, per the task's explicit three-state spec):

```dart
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_routes.isEmpty) {
      return const Center(
        child: Text(
          'No favorite routes yet.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    return ListView.separated( /* ... route cards ... */ );
  }
```

The empty-state `TextStyle(color: AppColors.textTertiary, fontSize: 13)` and the "No ... yet." wording exactly mirror home_page.dart's "No recent searches yet." empty state (`_buildRecentSearches()`), just wrapped in `Center` since this is a full screen rather than a section inside Home.

**Route card:** duplicated from `all_routes_screen.dart`'s `_buildRouteCard` (plus a `FavoriteButton`), rather than extracted into a shared widget. `_buildRouteCard` is a private method on `_AllRoutesScreenState`, so extracting it would mean touching `all_routes_screen.dart` beyond the Step 4b change already made there; duplicating a few dozen lines into the new file only, with a comment explaining why, was the less invasive of the two options the task offered. Duplicated alongside it: `_subtitleFor`, `_buildFrequencyLabel`, and the two frequency-pill color consts (`_frequencyGreenBackground`/`_frequencyAmberBackground`), all copied verbatim from `all_routes_screen.dart`.

Tapping a card navigates to `TripDetailsScreen` exactly the way `all_routes_screen.dart` does — same `originStop: _stopsById[route.originStopId]` lookup:
```dart
onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => TripDetailsScreen(
        route: route,
        originStop: _stopsById[route.originStopId],
      ),
    ),
  );
},
```

**Unfavoriting from this screen — optimistic removal, not a full reload:**
```dart
  void _removeFromList(String routeId) {
    setState(() => _routes.removeWhere((route) => route.id == routeId));
  }
```
wired through the card's `FavoriteButton`:
```dart
              FavoriteButton(
                routeId: route.id,
                onChanged: (isFavorite) {
                  if (!isFavorite) _removeFromList(route.id);
                },
              ),
```

**Why optimistic removal was chosen over a full reload:** the favorites list is short by nature (a hand-picked subset), and the toggle that triggers removal is a purely local `SharedPreferences` write with no Firestore round-trip involved. Re-running `getAllActiveRoutes()` + `getAllStops()` and showing the loading spinner again just to reflect one local unfavorite would be slower and more jarring than simply dropping the row the student just unstarred — the in-memory list and the stored favorite set can't drift apart from this action alone, since the button already wrote the change before calling back.

---

## Step 6 — entry point from Home

Added import to `home_page.dart`:
```dart
import '../../favorites/presentation/favorites_screen.dart';
```

**Before** (AppBar `actions`, the sign-in/sign-out conditional):
```dart
          if (_authRepository.currentUser == null)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Sign in',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _signOut,
            ),
```

**After** (Favorites icon added next to sign-out, both gated behind the same signed-in branch; guests still see only the sign-in icon):
```dart
          if (_authRepository.currentUser == null)
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Sign in',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                );
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.star_border),
              tooltip: 'Favorites',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FavoritesScreen(repository: _repository),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: _signOut,
            ),
          ],
```

Placement/visual call: next to the sign-out icon, as the prompt suggested — both live under the same "signed-in only" branch of the existing `if`/`else`, so a guest's AppBar is unchanged (still just About + Sign in) and a signed-in student now sees About, Favorites, Sign out. Icon chosen: `Icons.star_border` (outline, matching the unfavorited state of `FavoriteButton`, and matching the outline convention `Icons.lock_outline`/`Icons.info_outline` already use in this same AppBar) — this is a static navigation icon, not a toggle, so it does not need the filled/outline swap `FavoriteButton` does. `git diff --numstat`: `15  1  lib/features/search/presentation/home_page.dart`.

---

## Step 7 — verification

### 7a. Unit tests for `FavoritesRepository`

Added — confident in the `SharedPreferences.setMockInitialValues({})` pattern (a standard, documented test hook the `shared_preferences` package itself ships for exactly this purpose), so this was not skipped.

**New file:** `test/favorites_repository_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coasterna_project/features/favorites/data/favorites_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoritesRepository', () {
    test('getFavoriteRouteIds returns an empty set when nothing is stored',
        () async {
      final repository = FavoritesRepository();
      expect(await repository.getFavoriteRouteIds(), isEmpty);
    });

    test('toggleFavorite adds a route id that was not already favorited',
        () async {
      final repository = FavoritesRepository();
      await repository.toggleFavorite('route-1');

      expect(await repository.isFavorite('route-1'), isTrue);
      expect(await repository.getFavoriteRouteIds(), {'route-1'});
    });

    test('toggleFavorite removes a route id that was already favorited',
        () async {
      final repository = FavoritesRepository();
      await repository.toggleFavorite('route-1');
      await repository.toggleFavorite('route-1');

      expect(await repository.isFavorite('route-1'), isFalse);
      expect(await repository.getFavoriteRouteIds(), isEmpty);
    });

    test('toggling one route id does not affect another stored id',
        () async {
      final repository = FavoritesRepository();
      await repository.toggleFavorite('route-1');
      await repository.toggleFavorite('route-2');
      await repository.toggleFavorite('route-1');

      expect(await repository.getFavoriteRouteIds(), {'route-2'});
    });
  });
}
```
Style matches `test/route_status_test.dart`: `group`/`test` blocks, one behavior per test, descriptive full-sentence test names, `setUp` for shared fixture state. All 4 tests pass (see 7c).

### 7b. `flutter analyze`

Saved in full to `docs/audit-trail/favorites-feature-2026-09-01-analyze.txt`. **PASS.** Full content:

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
No issues found! (ran in 2.5s)
EXIT:0
```

Notably clean on the first pass, including the `else ...[A, B]` collection-if/spread combination used in `home_page.dart`'s AppBar `actions` (Step 6) and every new cross-feature import (`favorites/` importing from `auth/`, `search/`, `trip/`) — no `unused_import`, no lint on the new files.

### 7c. `flutter test`

Saved in full to `docs/audit-trail/favorites-feature-2026-09-01-test.txt`. **PASS — all 44 tests** (4 new `FavoritesRepository` tests + the 40 pre-existing tests, all still green). Full content:

```
Resolving dependencies...
Downloading packages...
  [package resolution output — identical to 7b, omitted here for brevity; see the saved .txt file for the untruncated listing]
Got dependencies!
33 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading C:/Users/Tariq/coasterna_project/test/favorites_repository_test.dart
00:00 +0: C:/Users/Tariq/coasterna_project/test/favorites_repository_test.dart: FavoritesRepository getFavoriteRouteIds returns an empty set when nothing is stored
00:00 +1: C:/Users/Tariq/coasterna_project/test/favorites_repository_test.dart: FavoritesRepository toggleFavorite adds a route id that was not already favorited
00:00 +2: C:/Users/Tariq/coasterna_project/test/favorites_repository_test.dart: FavoritesRepository toggleFavorite removes a route id that was already favorited
00:00 +3: C:/Users/Tariq/coasterna_project/test/favorites_repository_test.dart: FavoritesRepository toggling one route id does not affect another stored id
00:00 +4: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteStop fromJson and toJson round-trip preserves all fields
00:00 +5: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType fromFirestore maps SCHEDULED and WHEN_FULL correctly
00:00 +6: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType toFirestore is the exact inverse of fromFirestore
00:00 +7: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: DepartureType fromFirestore throws ArgumentError on an unknown value
00:00 +8: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection fromFirestore maps OUTBOUND and RETURN correctly
00:00 +9: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection toFirestore is the exact inverse of fromFirestore
00:00 +10: C:/Users/Tariq/coasterna_project/test/route_model_test.dart: RouteDirection fromFirestore throws ArgumentError on an unknown value
00:00 +11: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay parses a valid HH:mm string onto the reference date
00:00 +12: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay accepts a single-digit hour
00:00 +13: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the colon is missing
00:00 +14: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null on non-numeric text
00:00 +15: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the hour is out of range
00:00 +16: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: parseTimeOnDay returns null when the minute is out of range
00:00 +17: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday returns true when today is in operatingDays
00:00 +18: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday returns false when today is not in operatingDays
00:00 +19: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday is not confused by lowercase values in the data
00:00 +20: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeRunsToday an empty operatingDays list means the route runs every day
00:00 +21: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when frequencyMinutes is null
00:00 +22: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when frequencyMinutes is zero or negative
00:00 +23: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when firstDeparture cannot be parsed
00:00 +24: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null before the service has started for the day
00:00 +25: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture computes the wait from firstDeparture and frequency
00:00 +26: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns a full interval when standing exactly at a departure
00:00 +27: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: minutesUntilNextDeparture returns null when the next bus would fall after lastDeparture
00:00 +28: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a route that does not run today ranks below everything else
00:00 +29: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a WHEN_FULL route ranks below any scheduled route today
00:00 +30: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank a WHEN_FULL route still ranks above a route not running today
00:00 +31: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank before service starts, the rank is the wait until the first bus
00:00 +32: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: routeDepartureRank sorting a mixed list puts the soonest bus first
00:00 +33: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays collapses an unbroken run of days into a range
00:00 +34: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays lists days separately when there is a gap
00:00 +35: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays sorts into week order regardless of the order in Firestore
00:00 +36: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays an empty list reads as every day
00:00 +37: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays a single day is shown on its own
00:00 +38: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: formatOperatingDays unknown day codes do not crash the screen
00:00 +39: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore writes enums as their agreed Firestore strings
00:00 +40: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore writes collectedOn as a Firestore Timestamp, not a DateTime
00:00 +41: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore does not write the document id into the document body
00:00 +42: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore keeps a null frequencyMinutes as null
00:00 +43: C:/Users/Tariq/coasterna_project/test/route_status_test.dart: RouteModel.toFirestore serialises embedded waypoints in the order given
00:00 +44: All tests passed!
EXIT:0
```

### 7d. `git diff --numstat` and `git status --porcelain`

Saved to `docs/audit-trail/favorites-feature-2026-09-01-numstat.txt` and `docs/audit-trail/favorites-feature-2026-09-01-status.txt`.

`git status --porcelain`:
```
 M docs/project-status.md
 M lib/features/search/presentation/all_routes_screen.dart
 M lib/features/search/presentation/home_page.dart
 M lib/features/search/presentation/search_results_placeholder.dart
 M lib/features/trip/presentation/trip_details_screen.dart
?? devtools_options.yaml
?? docs/audit-trail/batch-fix-2026-09-01-analyze.txt
?? docs/audit-trail/batch-fix-2026-09-01-diffstat.txt
?? docs/audit-trail/batch-fix-2026-09-01-git-branch.txt
?? docs/audit-trail/batch-fix-2026-09-01-git-worktree.txt
?? docs/audit-trail/batch-fix-2026-09-01-status.txt
?? docs/audit-trail/batch-fix-2026-09-01-test.txt
?? docs/audit-trail/batch-fix-2026-09-01.md
?? docs/audit-trail/favorites-feature-2026-09-01-analyze.txt
?? docs/audit-trail/favorites-feature-2026-09-01-status.txt
?? docs/audit-trail/favorites-feature-2026-09-01-test.txt
?? docs/audit-trail/full-code-audit-2026-08-31.md
?? docs/audit-trail/project-gap-recheck-2026-09-01.md
?? lib/features/favorites/
?? test/favorites_repository_test.dart
```

`git diff --numstat`:
```
14	6	docs/project-status.md
8	1	lib/features/search/presentation/all_routes_screen.dart
15	1	lib/features/search/presentation/home_page.dart
15	4	lib/features/search/presentation/search_results_placeholder.dart
8	0	lib/features/trip/presentation/trip_details_screen.dart
```

Notes on what's in that listing:

- `docs/project-status.md` shows modified (14/6) but was **not touched by this session** — same as the previous session, something else keeps it refreshed between sessions; nothing here wrote to it.
- The four `M` files are exactly the four route-card/entry-point edits from Steps 4 and 6, matching the numstat line for line.
- `route_repository.dart`, `auth_repository.dart`, and the four `domain/.gitkeep` deletions from the *previous* batch-fix session no longer appear — `git log` confirms Tariq already committed that session's work as `a86c904` before this one started, using the exact suggested commit message from that session's report. This session did not touch either of those two files.
- `lib/features/favorites/` (the whole new feature directory: `data/favorites_repository.dart`, `presentation/favorite_button.dart`, `presentation/favorites_screen.dart`) and `test/favorites_repository_test.dart` are new, untracked, as expected.
- `devtools_options.yaml` appeared as an incidental untracked file — this is a Flutter DevTools config file auto-generated by running `flutter analyze`/`flutter test` in this environment, not something created intentionally for this feature. Flagging it here rather than silently leaving it for Tariq to wonder about; it is harmless and can be added to `.gitignore` or committed, at his discretion.
- No `.docx` file and no Firestore/`firestore.rules`/report-related `docs/` content appears in this diff — confirming the scope boundaries held.

---

**Suggested commit message for Tariq** (not run — for you to use verbatim or adapt):

> *feat(favorites): add device-local favorite routes for signed-in students, built with Gaith's pre-granted permission on his screens*
>
> New FavoritesRepository (SharedPreferences only, no Firestore — deliberate MVP decision D49, deferred sync) and a reusable FavoriteButton wired into the search-results, browse-all, and trip-details route cards behind the existing currentUser != null gate. New FavoritesScreen reachable from a star icon on Home, next to sign-out. Adds 4 unit tests for the repository's add/remove/toggle logic; flutter analyze and flutter test both pass.
