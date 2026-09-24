import 'dart:math';

import 'package:app/domain/entities/rank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rank (orden fraccional, ADR-0002)', () {
    test('la clave inicial es válida y no vacía', () {
      final k = Rank.initial();
      expect(k, isNotEmpty);
      expect(k.endsWith('0'), isFalse);
    });

    test('before() queda antes y after() queda después', () {
      const k = 'V';
      expect(Rank.before(k).compareTo(k), lessThan(0));
      expect(Rank.after(k).compareTo(k), greaterThan(0));
    });

    test('between() queda estrictamente entre las dos claves', () {
      final m = Rank.between('A', 'B');
      expect('A'.compareTo(m), lessThan(0));
      expect(m.compareTo('B'), lessThan(0));
    });

    test('rechaza un orden invertido o claves con cero final', () {
      expect(() => Rank.between('B', 'A'), throwsArgumentError);
      expect(() => Rank.between('A0', null), throwsArgumentError);
    });

    test('1000 inserciones "arriba del todo" seguidas mantienen el orden (CL-002-1)', () {
      final keys = <String>[Rank.initial()];
      for (var i = 0; i < 1000; i++) {
        keys.insert(0, Rank.before(keys.first));
      }
      final sorted = [...keys]..sort();
      expect(keys, sorted);
      expect(keys.toSet().length, keys.length);
    });

    test(
      'propiedad: 2000 inserciones aleatorias mantienen un orden total y único',
      () {
        final rnd = Random(20260924);
        final keys = <String>[Rank.initial()];
        for (var i = 0; i < 2000; i++) {
          final pos = rnd.nextInt(keys.length + 1);
          final before = pos == 0 ? null : keys[pos - 1];
          final after = pos == keys.length ? null : keys[pos];
          final k = Rank.between(before, after);
          expect(k.endsWith('0'), isFalse, reason: 'clave "$k"');
          keys.insert(pos, k);
        }
        final sorted = [...keys]..sort();
        expect(keys, sorted);
        expect(keys.toSet().length, keys.length);
      },
    );
  });
}
