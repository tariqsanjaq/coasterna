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
