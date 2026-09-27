import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Cuadrado blanco con borde negro y un icono ("Quitar adjunto" del editor y
/// "Cerrar" del visor, spec 007). Con teclado o interruptores recibe el foco y
/// muestra el anillo (WCAG 2.4.7), y Intro o Espacio lo activan.
class BoxedIconButton extends StatefulWidget {
  const BoxedIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.dimension,
    required this.iconSize,
    required this.iconStroke,
    required this.onPressed,
  });

  final String label;
  final UnaIconData icon;
  final double dimension;
  final double iconSize;
  final double iconStroke;
  final VoidCallback onPressed;

  @override
  State<BoxedIconButton> createState() => _BoxedIconButtonState();
}

class _BoxedIconButtonState extends State<BoxedIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: FocusRing(
          visible: _focused,
          child: Material(
            color: UnaColors.surface,
            shape: const Border.fromBorderSide(
              BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
            ),
            child: InkWell(
              onTap: widget.onPressed,
              // El foco lo lleva FocusableActionDetector (con su anillo).
              canRequestFocus: false,
              highlightColor: UnaColors.pressed,
              splashFactory: NoSplash.splashFactory,
              child: SizedBox.square(
                dimension: widget.dimension,
                child: Center(
                  child: UnaIcon(
                    widget.icon,
                    size: widget.iconSize,
                    strokeWidth: widget.iconStroke,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
