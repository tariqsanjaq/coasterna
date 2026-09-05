import 'package:flutter_test/flutter_test.dart';
import 'package:coasterna_project/features/profile/presentation/profile_screen.dart';

void main() {
  group('splitDisplayName (decision D53 part 2)', () {
    test('splits "First Last" on the first space', () {
      expect(splitDisplayName('tariq test'), ('tariq', 'test'));
    });

    test('splits only on the FIRST space — extra words stay in the '
        'last-name half', () {
      expect(splitDisplayName('Ahmad Al Rawi'), ('Ahmad', 'Al Rawi'));
    });

    test('a single word with no space becomes (word, "")', () {
      expect(splitDisplayName('Tariq'), ('Tariq', ''));
    });

    test('null input returns ("", "") — never crashes', () {
      expect(splitDisplayName(null), ('', ''));
    });

    test('empty or whitespace-only input returns ("", "")', () {
      expect(splitDisplayName(''), ('', ''));
      expect(splitDisplayName('   '), ('', ''));
    });

    test('extra internal whitespace between names does not leak into '
        'the last-name field', () {
      expect(splitDisplayName('Tariq   Test'), ('Tariq', 'Test'));
    });

    test('leading/trailing whitespace around the whole name is trimmed',
        () {
      expect(splitDisplayName('  Tariq Test  '), ('Tariq', 'Test'));
    });
  });
}
