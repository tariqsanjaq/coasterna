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
