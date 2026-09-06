import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_repository.dart';

/// Device-local recent searches for the Home screen.
///
/// The stored key is namespaced per signed-in user (falling back to a
/// `_guest` suffix) — the same convention `FavoritesRepository` uses —
/// so recent searches never leak between two students who sign in one
/// after another on the same shared device. [resetForSignOut] must be
/// called on sign-out to drop the outgoing user's in-memory state; the
/// next repository call then reloads whatever key matches the newly
/// signed-in user (or nobody).
class RecentSearchesRepository {
  static const _keyPrefix = 'recent_searches';

  static List<Map<String, dynamic>>? _cached;
  static String? _loadedForKey;
  static Future<void>? _loadFuture;

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

  /// Ensures the cached list holds the current user's recent searches
  /// before a read or write proceeds. A no-op once the key for the
  /// current user has already been loaded; concurrent calls share one
  /// in-flight load rather than each hitting `SharedPreferences`
  /// separately.
  Future<void> _ensureLoaded() {
    final key = _storageKey;
    if (_loadedForKey == key) return Future<void>.value();
    return _loadFuture ??= _loadFromStorage(key).whenComplete(() {
      _loadFuture = null;
    });
  }

  Future<void> _loadFromStorage(String key) async {
    List<Map<String, dynamic>> loaded = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        loaded = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Could not load recent searches: $e');
      loaded = [];
    }
    _cached = loaded;
    _loadedForKey = key;
  }

  /// Reads the stored list of recent searches. Malformed or
  /// unreadable stored data must never crash Home — on any error this
  /// returns an empty list.
  Future<List<Map<String, dynamic>>> getRecentSearches() async {
    await _ensureLoaded();
    return _cached ?? [];
  }

  /// Writes the given list back as JSON under the current user's key,
  /// then updates the cache. Callers are responsible for dedup/capping
  /// before calling this (see `_saveRecentSearch` in home_page.dart).
  Future<void> saveRecentSearches(List<Map<String, dynamic>> entries) async {
    await _ensureLoaded();
    final key = _storageKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(entries));
    _cached = entries;
  }

  /// Drops the in-memory recent-searches state. Must be called on
  /// sign-out (see `AuthRepository.signOut()`) so a second student who
  /// signs in on the same shared device never sees the first
  /// student's recent searches while the new key loads.
  static void resetForSignOut() {
    _cached = null;
    _loadedForKey = null;
    _loadFuture = null;
  }
}
