import 'package:flutter/widgets.dart';

import '../app/theme/tokens.g.dart';

/// Anillo de foco del prototipo (`outline: 3px solid ink; outline-offset: 3px`)
/// para quien navega con teclado o interruptores (WCAG 2.4.7).
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  /// El prototipo separa el anillo tanto como su grosor.
  static const _outset = UnaBorders.focusWidth * 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (visible)
          const Positioned(
            left: -_outset,
            top: -_outset,
            right: -_outset,
            bottom: -_outset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: UnaColors.ink,
                      width: UnaBorders.focusWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
