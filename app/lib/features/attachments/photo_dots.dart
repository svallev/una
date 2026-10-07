import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';

/// Los puntos del carrusel (spec 016, CA-016-09 y 22, DEV-53): uno por foto,
/// cuadrado, con borde de tinta de 2; **lleno de tinta el de la foto que se
/// ve** y blanco los demás, de modo que el estado lo da el relleno y no solo el
/// color (WCAG 1.4.1). Cada punto lleva un **halo blanco de 1,5 por fuera**:
/// sobre cualquier foto, la tinta o el halo llegan a ≥ 3:1 (WCAG 1.4.11).
///
/// Son solo informativos: **transparentes a los toques** (un swipe o un
/// pellizco que empieza sobre ellos llega al carrusel) y **fuera de la lectura**
/// (la posición la dice la etiqueta de la tarea). Con una sola foto no se
/// dibujan.
class PhotoDots extends StatelessWidget {
  const PhotoDots({super.key, required this.count, required this.index})
    : assert(count >= 0);

  /// Una foto = un punto.
  final int count;

  /// La foto que se ve (0 es la primera).
  final int index;

  /// El punto de la foto [i], para los tests.
  static Key dotKey(int i) => ValueKey('photo-dot-$i');

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              // La separación es la del prototipo entre los bordes de tinta:
              // los halos de dos puntos vecinos no la cuentan.
              if (i > 0)
                const SizedBox(
                  width:
                      UnaSizes.photoDotGap - 2 * UnaBorders.photoDotHaloWidth,
                ),
              _Dot(key: dotKey(i), filled: i == index),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // El halo blanco, por fuera del borde de tinta.
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(
            color: UnaColors.photoDotHalo,
            width: UnaBorders.photoDotHaloWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnaBorders.photoDotHaloWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: filled ? UnaColors.photoDotInk : UnaColors.photoDotLight,
            border: const Border.fromBorderSide(
              BorderSide(
                color: UnaColors.photoDotInk,
                width: UnaBorders.photoDotWidth,
              ),
            ),
          ),
          child: const SizedBox.square(dimension: UnaSizes.photoDot),
        ),
      ),
    );
  }
}
