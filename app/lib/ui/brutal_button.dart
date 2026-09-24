import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';

/// Botón "brutalista" del prototipo: borde de 3 px, sombra dura y hundimiento al pulsar.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.background = UnaColors.surface,
    this.expand = true,
    this.singleLine = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final bool expand;

  /// El texto nunca pasa a una segunda línea: si no cabe (texto grande del
  /// sistema, pantallas estrechas) se reduce lo justo, sin cortarse.
  final bool singleLine;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _down = false;
  bool _focused = false;

  void _activate() => widget.onPressed?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    // Teclado e interruptores: Tab llega al botón e Intro/Espacio lo activan.
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: FocusRing(visible: _focused && enabled, child: _button(enabled)),
    );
  }

  Widget _label() {
    const style = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.bodyL,
      fontWeight: UnaFontWeights.extrabold,
      color: UnaColors.ink,
    );
    if (!widget.singleLine) {
      return Text(widget.label, textAlign: TextAlign.center, style: style);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(widget.label, maxLines: 1, softWrap: false, style: style),
    );
  }

  Widget _button(bool enabled) {
    final pressed = _down || !enabled;
    final offset = pressed ? const Offset(4, 4) : Offset.zero;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: UnaMotion.press,
            transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
            constraints: const BoxConstraints(
              minHeight: UnaSizes.minTouchTarget + UnaSpace.m,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: UnaSpace.ml,
              vertical: UnaSpace.sm,
            ),
            decoration: BoxDecoration(
              color: widget.background,
              border: Border.all(
                color: UnaColors.ink,
                width: UnaBorders.strongWidth,
              ),
              boxShadow: [
                if (!pressed)
                  UnaShadows.button
                else if (enabled)
                  UnaShadows.buttonPressed,
              ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: UnaSizes.icon, color: UnaColors.ink),
                  const SizedBox(width: UnaSpace.s),
                ],
                Flexible(child: _label()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
