import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'press_motion.dart';
import 'una_icons.dart';

/// Botón cuadrado de barra del prototipo (`.sq`): 46 px, sombra de 3 px y
/// hundimiento al pulsar. Zona táctil de 48 dp (Android).
class SquareIconButton extends StatefulWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.fill,
    required this.onPressed,
    this.focusNode,
    this.semanticsKey,
    this.autofocus = false,
  });
  final UnaIconData icon;
  final String label;

  /// En Flutter la sombra también se pinta bajo la caja: sin relleno se vería
  /// un cuadrado negro (en el CSS del prototipo, la sombra solo va por fuera).
  final Color fill;
  final VoidCallback onPressed;

  /// Foco de teclado del botón, para dárselo desde fuera (al volver de otra
  /// pantalla).
  final FocusNode? focusNode;

  /// Clave del nodo accesible del botón, para enviar desde él el aviso de foco
  /// del lector.
  final GlobalKey? semanticsKey;

  /// Si pide el foco de teclado al montarse (p. ej. Cerrar o Volver de
  /// Ajustes con teclado físico, CA-015-21a).
  final bool autofocus;

  @override
  State<SquareIconButton> createState() => _SquareIconButtonState();
}

class _SquareIconButtonState extends State<SquareIconButton> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const sink = UnaShadows.iconButton;
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
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
        key: widget.semanticsKey,
        button: true,
        label: widget.label,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Center(
              child: FocusRing(
                visible: _focused,
                child: AnimatedContainer(
                  duration: pressDuration(context),
                  transform: _down
                      ? Matrix4.translationValues(
                          sink.offset.dx,
                          sink.offset.dy,
                          0,
                        )
                      : Matrix4.identity(),
                  width: UnaSizes.iconButton,
                  height: UnaSizes.iconButton,
                  decoration: BoxDecoration(
                    border: const Border.fromBorderSide(
                      BorderSide(
                        color: UnaColors.ink,
                        width: UnaBorders.strongWidth,
                      ),
                    ),
                    boxShadow: [if (!_down) sink],
                    color: widget.fill,
                  ),
                  child: Center(child: UnaIcon(widget.icon)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
