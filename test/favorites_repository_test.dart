import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coasterna_project/features/favorites/data/favorites_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // idsNotifier/_loadedForKey are static (shared across every
    // FavoritesRepository instance in the running app), so they must
    // be reset between tests too or a later test would see the
    // previous test's in-memory favorites instead of reloading from
    // the freshly-mocked SharedPreferences.
    FavoritesRepository.resetForSignOut();
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

    test('toggleFavorite returns the resulting favorited state', () async {
      final repository = FavoritesRepository();
      expect(await repository.toggleFavorite('route-1'), isTrue);
      expect(await repository.toggleFavorite('route-1'), isFalse);
    });

    test(
        'concurrent toggles on different route ids do not clobber each '
        "other's write",
        () async {
      final repository = FavoritesRepository();

      // Both calls start before either has finished writing, so a
      // naive read-modify-write would have the second setString()
      // overwrite the first's addition. toggleFavorite serializes
      // these on an internal write queue instead.
      await Future.wait([
        repository.toggleFavorite('route-1'),
        repository.toggleFavorite('route-2'),
      ]);

      expect(await repository.getFavoriteRouteIds(), {'route-1', 'route-2'});
    });
  });
}
