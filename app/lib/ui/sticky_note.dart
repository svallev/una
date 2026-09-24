import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';

/// Nota adhesiva a pantalla completa (prototipo, pantalla 1).
class StickyNote extends StatelessWidget {
  const StickyNote({
    super.key,
    required this.colorKey,
    required this.child,
    this.palette = UnaPalettes.classic,
  });

  final int colorKey;
  final Widget child;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette[colorKey % palette.length],
        border: Border.all(color: UnaColors.ink, width: UnaBorders.strongWidth),
      ),
      child: child,
    );
  }
}
