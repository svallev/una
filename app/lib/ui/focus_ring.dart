import 'package:flutter/widgets.dart';

import '../app/theme/tokens.g.dart';

/// Si el foco se está mostrando (teclado o interruptores), no con el tacto:
/// para los controles que siguen el foco con `onFocusChange` (`InkWell`), como
/// hace `FocusableActionDetector.onShowFocusHighlight`.
bool get showsFocusHighlight =>
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// Anillo de foco del prototipo (`outline: 3px solid ink; outline-offset: 3px`)
/// para quien navega con teclado o interruptores (WCAG 2.4.7). Lleva además un
/// borde blanco por fuera, para verse también sobre una foto oscura (spec 007
/// §6, WCAG 1.4.11).
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.inside = false,
  });

  final bool visible;
  final Widget child;

  /// Dibuja el anillo por dentro del borde (lo que ocupa toda la pantalla,
  /// como la imagen de la tarea actual): el blanco en el borde y el negro
  /// justo dentro.
  final bool inside;

  /// El prototipo separa el anillo tanto como su grosor.
  static const _outset = UnaBorders.focusWidth * 2;
  static const _width = UnaBorders.focusWidth;

  static Widget _ring(double outset, Color color) => Positioned(
    left: -outset,
    top: -outset,
    right: -outset,
    bottom: -outset,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: color, width: _width),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (visible) ...[
          _ring(inside ? 0 : _outset + _width, UnaColors.surface),
          _ring(inside ? -_width : _outset, UnaColors.ink),
        ],
      ],
    );
  }
}
