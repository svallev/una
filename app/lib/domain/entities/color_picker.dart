import 'dart:math';

import 'task.dart';

/// Elige el color de una tarea nueva: nunca el de la tarea actual (CA-001-08).
class ColorPicker {
  ColorPicker([Random? random]) : _random = random ?? Random();
  final Random _random;

  int pick({int? currentColorKey}) {
    final options = [
      for (var i = 0; i < Task.paletteSize; i++)
        if (i != currentColorKey) i,
    ];
    return options[_random.nextInt(options.length)];
  }
}
