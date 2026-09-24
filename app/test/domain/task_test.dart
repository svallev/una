import 'dart:math';

import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTaskText', () {
    test('CL-001-1: solo espacios o saltos de línea no es válido', () {
      expect(
        () => validateTaskText('   \n\t '),
        throwsA(isA<InvalidTaskText>()),
      );
    });

    test('recorta espacios al principio y al final', () {
      expect(validateTaskText('  Comprar pan \n'), 'Comprar pan');
    });

    test('CL-001-2: acepta 10 000 caracteres y rechaza 10 001', () {
      expect(validateTaskText('a' * 10000).length, 10000);
      expect(
        () => validateTaskText('a' * 10001),
        throwsA(isA<InvalidTaskText>()),
      );
    });

    test('CL-001-3: emojis, RTL y CJK se aceptan tal cual', () {
      const t =
          '📌 مرحبا 你好 https://ejemplo.com/una/url/muy/larga/sin/espacios';
      expect(validateTaskText(t), t);
    });
  });

  group('ColorPicker', () {
    test('CA-001-08: nunca repite el color de la tarea actual', () {
      final picker = ColorPicker(Random(1));
      for (var current = 0; current < Task.paletteSize; current++) {
        for (var i = 0; i < 200; i++) {
          final c = picker.pick(currentColorKey: current);
          expect(c, isNot(current));
          expect(c, inInclusiveRange(0, Task.paletteSize - 1));
        }
      }
    });

    test('sin tarea actual puede usar cualquiera de los 5 colores', () {
      final picker = ColorPicker(Random(2));
      final seen = {for (var i = 0; i < 500; i++) picker.pick()};
      expect(seen, {0, 1, 2, 3, 4});
    });
  });
}
