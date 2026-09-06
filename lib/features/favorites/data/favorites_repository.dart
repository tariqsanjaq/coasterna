import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_repository.dart';

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
///
/// The stored key is namespaced per signed-in user (falling back to a
/// `_guest` suffix) so favorites never leak between two students who
/// sign in one after another on the same shared device. [resetForSignOut]
/// must be called on sign-out to drop the outgoing user's in-memory
/// state; the next repository call then reloads whatever key matches
/// the newly signed-in user (or nobody).
///
/// [idsNotifier] is `static` — shared by every `FavoritesRepository()`
/// instance — so all `FavoriteButton`s showing the same route id stay
/// in sync the moment any one of them toggles it, instead of each
/// holding its own stale local copy.
class FavoritesRepository {
  static const _keyPrefix = 'favorite_route_ids';

  static final ValueNotifier<Set<String>> idsNotifier =
      ValueNotifier<Set<String>>({});

  static String? _loadedForKey;
  static Future<void>? _loadFuture;
  static Future<void> _writeQueue = Future<void>.value();

  /// Falls back to a guest key if reading the current user throws —
  /// concretely, if Firebase has not been initialized (as in this
  /// repository's own unit tests, which never touch Firebase). In the
  /// running app Firebase is always initialized before this is
  /// reached, so this only ever matters off of the real app.
  String get _storageKey {
    String? uid;
    try {
      uid = AuthRepository().currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    return uid != null ? '${_keyPrefix}_$uid' : '${_keyPrefix}_guest';
  }

  /// Ensures [idsNotifier] holds the current user's favorites before a
  /// read or write proceeds. A no-op once the key for the current user
  /// has already been loaded; concurrent calls share one in-flight
  /// load rather than each hitting `SharedPreferences` separately.
  Future<void> _ensureLoaded() {
    final key = _storageKey;
    if (_loadedForKey == key) return Future<void>.value();
    return _loadFuture ??= _loadFromStorage(key).whenComplete(() {
      _loadFuture = null;
    });
  }

  Future<void> _loadFromStorage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) {
        idsNotifier.value = {};
      } else {
        final decoded = jsonDecode(raw) as List<dynamic>;
        idsNotifier.value = decoded.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('Could not load favorite routes: $e');
      idsNotifier.value = {};
    }
    _loadedForKey = key;
  }

  /// Reads the stored set of favorite route ids. Malformed or
  /// unreadable stored data must never crash a screen — on any error
  /// this returns an empty set, mirroring the pattern
  /// `RecentSearchesRepository` uses for the same reason.
  Future<Set<String>> getFavoriteRouteIds() async {
    await _ensureLoaded();
    return idsNotifier.value;
  }

  /// Convenience wrapper over [getFavoriteRouteIds] for a single route.
  Future<bool> isFavorite(String routeId) async {
    final ids = await getFavoriteRouteIds();
    return ids.contains(routeId);
  }

  /// Adds [routeId] to the favorites set if it is absent, removes it
  /// if it is already present, writes the whole set back as a JSON
  /// list, then publishes the new set on [idsNotifier]. Returns the
  /// route's new favorited state.
  ///
  /// Calls are serialized on [_writeQueue] — a rapid tap on two
  /// different stars would otherwise each read the same starting set
  /// and the second write could silently clobber the first.
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

  /// Drops the in-memory favorites state. Must be called on sign-out
  /// (see `AuthRepository.signOut()`) so a second student who signs in
  /// on the same shared device never sees — or can toggle away — the
  /// first student's favorites while the new key loads.
  static void resetForSignOut() {
    idsNotifier.value = {};
    _loadedForKey = null;
    _loadFuture = null;
  }
}
