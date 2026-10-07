import 'package:app/data/import/take_first.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-016-02: con 5000 elementos solo se leen 10 y el total se '
      'conserva', () {
    final read = <int>[];
    final r = takeFirst<int>(
      length: 5000,
      item: (i) {
        read.add(i);
        return i;
      },
      max: 10,
    );
    expect(read, [for (var i = 0; i < 10; i++) i]);
    expect(r.items, hasLength(10));
    expect(r.total, 5000);
  });

  test('CA-016-02: con menos del tope se leen todos, sin recorte', () {
    final read = <int>[];
    final r = takeFirst<int>(
      length: 3,
      item: (i) {
        read.add(i);
        return i;
      },
      max: 10,
    );
    expect(read, [0, 1, 2]);
    expect(r.items, [0, 1, 2]);
    expect(r.total, 3);
  });

  test(
    'CA-016-02: un elemento nulo se salta y una lista vacía no lee nada',
    () {
      final r = takeFirst<int>(
        length: 3,
        item: (i) => i == 1 ? null : i,
        max: 10,
      );
      expect(r.items, [0, 2]);
      var calls = 0;
      final empty = takeFirst<int>(
        length: 0,
        item: (i) {
          calls++;
          return i;
        },
        max: 10,
      );
      expect(calls, 0);
      expect(empty.items, isEmpty);
      expect(empty.total, 0);
    },
  );
}
