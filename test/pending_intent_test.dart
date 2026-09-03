import 'package:flutter_test/flutter_test.dart';
import 'package:coasterna_project/core/pending_intent.dart';

void main() {
  group('PendingIntentHolder', () {
    test('consume() returns null when nothing is pending', () {
      expect(PendingIntentHolder.consume(), isNull);
    });

    test('set() then consume() returns the stored intent and clears it', () {
      PendingIntentHolder.set(
        const PendingFavorite('route1', 'Sweileh to AAU Main Gate'),
      );

      final consumed = PendingIntentHolder.consume();
      expect(consumed, isA<PendingFavorite>());
      expect(consumed!.routeId, 'route1');
      expect(consumed.routeName, 'Sweileh to AAU Main Gate');

      // Consuming a second time returns null — it was cleared by the
      // first consume(), so it can never fire twice.
      expect(PendingIntentHolder.consume(), isNull);
    });

    test('set() overwrites an unconsumed intent — only one at a time', () {
      PendingIntentHolder.set(const PendingFavorite('route1', 'First route'));
      PendingIntentHolder.set(const PendingReport('route2', 'Second route'));

      final consumed = PendingIntentHolder.consume();
      expect(consumed, isA<PendingReport>());
      expect(consumed!.routeId, 'route2');
      expect(consumed.routeName, 'Second route');

      // The first set() was overwritten before it was ever consumed —
      // nothing is left pending.
      expect(PendingIntentHolder.consume(), isNull);
    });

    test('PendingFavorite and PendingReport both carry routeId/routeName',
        () {
      const favorite = PendingFavorite('r1', 'Route One');
      const report = PendingReport('r2', 'Route Two');

      expect(favorite.routeId, 'r1');
      expect(favorite.routeName, 'Route One');
      expect(report.routeId, 'r2');
      expect(report.routeName, 'Route Two');
    });
  });
}
