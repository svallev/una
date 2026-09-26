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

    test('CL-006-8: evenlySpaced da claves ordenadas, válidas y de igual longitud', () {
      for (final n in [0, 1, 2, 61, 62, 500, 5000]) {
        final keys = Rank.evenlySpaced(n);
        expect(keys, hasLength(n));
        expect([...keys]..sort(), keys);
        expect(keys.toSet(), hasLength(n));
        expect(keys.map((k) => k.length).toSet().length, lessThanOrEqualTo(1));
        for (final k in keys) {
          expect(k.endsWith('0'), isFalse, reason: k);
          expect(k.length, lessThan(Rank.maxLength));
        }
        // Queda hueco para insertar delante, entre y detrás sin alargar mucho.
        if (n >= 2) {
          expect(
            Rank.between(keys[0], keys[1]).length,
            lessThanOrEqualTo(keys[0].length),
          );
          expect(
            Rank.before(keys.first).length,
            lessThanOrEqualTo(keys.first.length),
          );
        }
      }
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
