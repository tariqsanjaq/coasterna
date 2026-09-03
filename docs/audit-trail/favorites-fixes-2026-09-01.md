# Favorites feature — ultrareview fix session (2026-09-01)

Fixes all 5 findings from the `/ultrareview` cloud run against `a86c904` (the
favorites-feature commit). Two `normal`-severity, three `nit`-severity. No
`git add`/`commit`/`push` performed — Tariq commits himself. No Firestore or
`firestore.rules` changes.

Files touched:
- `lib/features/favorites/data/favorites_repository.dart`
- `lib/features/favorites/presentation/favorite_button.dart`
- `lib/features/favorites/presentation/favorites_screen.dart`
- `lib/features/auth/data/auth_repository.dart`
- `test/favorites_repository_test.dart` (regression coverage + a static-state
  reset needed once the repository gained shared static state — see Fix 3/5)

Verification: `flutter analyze` → `No issues found!`
(`favorites-fixes-2026-09-01-analyze.txt`). `flutter test` → all 46 tests pass
(`favorites-fixes-2026-09-01-test.txt`), up from 4 in the favorites suite.
Diffstat in `favorites-fixes-2026-09-01-diffstat.txt`.

---

## Fix 1 — `FavoriteButton` stale local state (bug_001, normal)

**Problem.** `_FavoriteButtonState` read `_isFavorite` once in `initState()`
and cached it locally. Two instances for the same route (a search card + the
Trip Details AppBar star) drifted apart the moment one was toggled, and
`_toggle()` inverted the *stale local* boolean rather than the real stored
value — so a tap on the stale instance could silently reverse the user's
intent (asking to favorite something actually unfavorited it, or vice versa).

**Fix.** Replaced the per-instance cache with a shared, observable source of
truth: `FavoritesRepository.idsNotifier`, a `static ValueNotifier<Set<String>>`
shared by every `FavoritesRepository()` instance. `FavoriteButton` now reads
`favoriteIds.contains(widget.routeId)` fresh on every build via
`ValueListenableBuilder`, and `toggleFavorite()` returns the actual resulting
state instead of the caller guessing it by inversion. No call site
(`search_results_placeholder.dart`, `all_routes_screen.dart`,
`trip_details_screen.dart`, `favorites_screen.dart`) needed any change — they
all just construct `FavoriteButton(routeId: ...)`.

Before (`favorite_button.dart`):
```dart
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
    return IconButton(
      icon: Icon(_isFavorite ? Icons.star : Icons.star_border, ...),
      ...
      onPressed: _toggle,
    );
  }
}
```

After:
```dart
class _FavoriteButtonState extends State<FavoriteButton> {
  final _repository = FavoritesRepository();

  @override
  void initState() {
    super.initState();
    unawaited(_repository.getFavoriteRouteIds()); // kicks off the load
  }

  Future<void> _toggle() async {
    final nowFavorite = await _repository.toggleFavorite(widget.routeId);
    if (!mounted) return;
    widget.onChanged?.call(nowFavorite);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesRepository.idsNotifier,
      builder: (context, favoriteIds, _) {
        final isFavorite = favoriteIds.contains(widget.routeId);
        return IconButton(
          icon: Icon(isFavorite ? Icons.star : Icons.star_border, ...),
          ...
          onPressed: _toggle,
        );
      },
    );
  }
}
```

This same change also **eliminates bug_004** (the `FavoritesScreen` row-reuse
bug) at the root: there is no longer a local boolean for Flutter to carry over
when it reuses a `State` object across list positions — every build re-derives
the star from `widget.routeId`, which Flutter always keeps current even when
reusing the underlying `State`. The explicit `ValueKey` from Fix 2 is added
anyway, per the task's own requirement, as defense in depth.

---

## Fix 2 — Missing list-item keys in `FavoritesScreen` (bug_004, normal)

**Problem.** The `InkWell` returned by `ListView.separated`'s `itemBuilder`
had no `Key`. After `_removeFromList` shrank `_routes`, Flutter reconciled
children by position and could reuse a `State` object that was really meant
for a different route.

**Fix.** Added `key: ValueKey(route.id)` to the `InkWell` wrapping each row,
so Flutter matches elements by route identity instead of list position.

Before (`favorites_screen.dart`):
```dart
itemBuilder: (context, index) {
  final route = _routes[index];
  return InkWell(
    borderRadius: BorderRadius.circular(AppRadius.card),
    onTap: () { ... },
    child: _buildRouteCard(route),
  );
},
```

After:
```dart
itemBuilder: (context, index) {
  final route = _routes[index];
  return InkWell(
    key: ValueKey(route.id),
    borderRadius: BorderRadius.circular(AppRadius.card),
    onTap: () { ... },
    child: _buildRouteCard(route),
  );
},
```

---

## Fix 3 — `toggleFavorite` read-modify-write race (bug_003, nit)

**Problem.** `toggleFavorite` read the stored set, mutated it in memory, then
wrote it back with no lock. Two overlapping toggles (rapid taps on two
different stars) could both read the same starting set, and the second
`setString` clobbered the first.

**Fix.** Serialized all toggles on a single-flight `static Future` write
queue on `FavoritesRepository`, so a second call always starts its
read-modify-write only after the first has fully applied and published to
`idsNotifier`.

Before (`favorites_repository.dart`):
```dart
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
```

After:
```dart
static Future<void> _writeQueue = Future<void>.value();

Future<bool> toggleFavorite(String routeId) {
  final result = _writeQueue.then((_) => _toggleFavoriteLocked(routeId));
  _writeQueue = result.then((_) {}, onError: (_) {});
  return result;
}

Future<bool> _toggleFavoriteLocked(String routeId) async {
  await _ensureLoaded();
  final key = _storageKey;
  final ids = Set<String>.from(idsNotifier.value);

  final bool nowFavorite;
  if (ids.contains(routeId)) {
    ids.remove(routeId);
    nowFavorite = false;
  } else {
    ids.add(routeId);
    nowFavorite = true;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, jsonEncode(ids.toList()));
  idsNotifier.value = ids;
  return nowFavorite;
}
```

Added a regression test (`test/favorites_repository_test.dart`):
`concurrent toggles on different route ids do not clobber each other's write`
— fires two `toggleFavorite` calls via `Future.wait` and asserts both ids end
up stored.

---

## Fix 4 — `FavoritesScreen` collapses a failed load into "empty" (bug_002, nit)

**Problem.** Any exception from `getFavoriteRouteIds()`/`getAllActiveRoutes()`
fell into a catch that set `favoriteRoutes = []`, so an offline/permission
failure rendered the exact same "No favorite routes yet." text as a genuinely
empty list, with no retry — unlike the sibling `AllRoutesScreen` (added in the
same PR), which has a real `loading/loaded/empty/error` state machine with a
Retry button.

**Fix.** Reused `AllRoutesScreen`'s exact four-state pattern (same enum shape,
same error icon/copy/`TextButton` structure, same `isFromCache`-while-empty
heuristic for distinguishing "genuinely nothing" from "the cache came back
empty because the read likely failed").

Before (`favorites_screen.dart`):
```dart
bool _isLoading = true;
List<RouteModel> _routes = [];

Future<void> _loadFavorites() async {
  setState(() => _isLoading = true);
  List<RouteModel> favoriteRoutes = [];
  try {
    ...
  } catch (e) {
    // A failed read here degrades to "no favorites shown" rather
    // than a fourth error state.
    favoriteRoutes = [];
  }
  setState(() {
    _routes = favoriteRoutes;
    _isLoading = false;
  });
}

Widget _buildBody() {
  if (_isLoading) return const Center(child: CircularProgressIndicator(...));
  if (_routes.isEmpty) return const Center(child: Text('No favorite routes yet.'));
  return ListView.separated(...);
}
```

After:
```dart
enum _LoadState { loading, loaded, empty, error }
_LoadState _state = _LoadState.loading;
List<RouteModel> _routes = [];

Future<void> _loadFavorites() async {
  setState(() => _state = _LoadState.loading);
  try {
    ...
    setState(() {
      _routes = favoriteRoutes;
      _stopsById = stopsById;
      if (result.data.isEmpty && result.isFromCache) {
        _state = _LoadState.error;
      } else if (favoriteRoutes.isEmpty) {
        _state = _LoadState.empty;
      } else {
        _state = _LoadState.loaded;
      }
    });
  } catch (e) {
    debugPrint('Could not load favorite routes: $e');
    setState(() => _state = _LoadState.error);
  }
}

Widget _buildBody() {
  if (_state == _LoadState.loading) return const Center(child: CircularProgressIndicator(...));
  if (_state == _LoadState.error) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
        const Text('Could not load favorites. Check your connection.'),
        TextButton(onPressed: _loadFavorites, child: const Text('Retry')),
      ]),
    );
  }
  if (_state == _LoadState.empty) return const Center(child: Text('No favorite routes yet.'));
  return ListView.separated(...);
}
```

`_removeFromList` was also updated to flip `_state` to `.empty` when the last
favorited row is removed, since it no longer has `_routes.isEmpty` as an
implicit fourth branch to fall back on.

---

## Fix 5 — Favorites leak across users on a shared device (bug_006, nit)

**Problem.** `FavoritesRepository` stored favorites under one global
`SharedPreferences` key (`favorite_route_ids`) with no per-user scoping, and
`AuthRepository.signOut()` never cleared it. On a shared device, Student B
signing in after Student A would see — and could delete by tapping — Student
A's favorites.

**Fix.** Read `auth_repository.dart` fresh to confirm `AuthRepository`
already exposes `User? get currentUser => _auth.currentUser;` and is the
single choke point both student and admin sign-out go through
(`Future<void> signOut() => _auth.signOut();`). Namespaced the storage key by
`AuthRepository().currentUser?.uid` (falling back to a `_guest` suffix), and
added `FavoritesRepository.resetForSignOut()` — a static method that clears
the in-memory notifier and forces the next read to reload from storage —
called from inside `AuthRepository.signOut()` itself, so every sign-out path
(the one in `home_page.dart`, plus the two admin ones) is covered without
touching any of those call sites.

One wrinkle this surfaced: reading `AuthRepository().currentUser` calls
`FirebaseAuth.instance`, which throws if Firebase hasn't been initialized —
true in this repository's own unit tests, which deliberately never touch
Firebase (matching CLAUDE.md's "unit-testable without Firebase" principle for
this layer). The uid lookup is wrapped in a try/catch that falls back to the
guest key on that specific failure, so the test suite keeps working
Firebase-free; in the running app Firebase is always initialized before this
code runs, so the catch branch never fires there.

Before (`favorites_repository.dart`):
```dart
class FavoritesRepository {
  static const _key = 'favorite_route_ids';

  Future<Set<String>> getFavoriteRouteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    ...
  }

  Future<void> toggleFavorite(String routeId) async {
    ...
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ids.toList()));
  }
}
```
```dart
// auth_repository.dart
Future<void> signOut() => _auth.signOut();
```

After:
```dart
class FavoritesRepository {
  static const _keyPrefix = 'favorite_route_ids';

  String get _storageKey {
    String? uid;
    try {
      uid = AuthRepository().currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    return uid != null ? '${_keyPrefix}_$uid' : '${_keyPrefix}_guest';
  }

  static void resetForSignOut() {
    idsNotifier.value = {};
    _loadedForKey = null;
    _loadFuture = null;
  }

  // getFavoriteRouteIds / toggleFavorite now read/write via _storageKey
  // instead of the old single global _key.
}
```
```dart
// auth_repository.dart
Future<void> signOut() async {
  await _auth.signOut();
  FavoritesRepository.resetForSignOut();
}
```

**Note on the resulting dependency.** This makes `favorites_repository.dart`
depend on `auth_repository.dart` (for `currentUser`) and `auth_repository.dart`
depend on `favorites_repository.dart` (for `resetForSignOut()`) — a circular
import between the two files. Dart supports this (both references are inside
method bodies, not top-level const initializers, so there's no load-order
cycle), and `flutter analyze` confirms it raises no issue. This was the
narrowest fix that guarantees no sign-out path is missed, since "all
authentication goes through `AuthRepository`" is this project's own
documented invariant — recreating the same guarantee by editing every
call-site of `signOut()` individually would be easy to leave out of sync as
new ones are added later.

---

## Test coverage added

`test/favorites_repository_test.dart` grew two new tests:
- `toggleFavorite returns the resulting favorited state` — locks in the
  Fix 1 API change from `Future<void>` to `Future<bool>`.
- `concurrent toggles on different route ids do not clobber each other's
  write` — regression test for Fix 3.

`setUp` also now calls `FavoritesRepository.resetForSignOut()` alongside
`SharedPreferences.setMockInitialValues({})`. This was necessary, not
optional: `idsNotifier` and `_loadedForKey` are `static`, shared by every
`FavoritesRepository()` instance in the running app (by design, for Fix 1) —
without the reset, a later test in the same run would see the previous test's
in-memory favorites instead of reloading from the freshly-mocked
`SharedPreferences`, since `_loadedForKey` would still match the guest key
from the prior test.
