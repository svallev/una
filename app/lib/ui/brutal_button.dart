import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Botón "brutalista" del prototipo (`.bb`): borde de 3 px, sombra dura de 5 px
/// y hundimiento al pulsar.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.iconSize = UnaSizes.iconL,
    this.iconStroke = UnaSizes.iconStrokeBold,
    this.height = UnaSizes.button,
    this.fontSize = UnaFontSizes.bodyL,
    this.background = UnaColors.surface,
    this.expand = true,
    this.singleLine = false,
  }) : iconOnly = false;

  /// Botón cuadrado solo con icono (p. ej. "+"). [label] es su nombre accesible.
  const BrutalButton.icon({
    super.key,
    required this.label,
    required UnaIconData this.icon,
    required this.onPressed,
    this.iconSize = UnaSizes.iconL,
    this.iconStroke = UnaSizes.iconStrokeBold,
    this.height = UnaSizes.button,
    this.background = UnaColors.surface,
  }) : trailingIcon = null,
       fontSize = UnaFontSizes.bodyL,
       expand = false,
       singleLine = true,
       iconOnly = true;

  final String label;
  final VoidCallback? onPressed;

  /// Icono delante del texto (completar: ✓).
  final UnaIconData? icon;

  /// Icono detrás del texto (Guardar: →).
  final UnaIconData? trailingIcon;
  final double iconSize;

  /// Grosor del trazo del icono (los botones grandes usan el grueso).
  final double iconStroke;

  /// Alto mínimo; con texto grande del sistema, el botón crece.
  final double height;
  final double fontSize;
  final Color background;

  /// Ocupa todo el ancho disponible.
  final bool expand;

  /// El texto nunca pasa a una segunda línea: si no cabe (texto grande del
  /// sistema, pantallas estrechas) se reduce lo justo, sin cortarse.
  final bool singleLine;
  final bool iconOnly;

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

  Widget _icon(UnaIconData data) =>
      UnaIcon(data, size: widget.iconSize, strokeWidth: widget.iconStroke);

  Widget _label() {
    final style = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: widget.fontSize,
      fontWeight: UnaFontWeights.extrabold,
      letterSpacing: UnaLetterSpacing.snug * widget.fontSize,
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

  Widget _content() {
    if (widget.iconOnly) return Center(child: _icon(widget.icon!));
    return Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          _icon(widget.icon!),
          const SizedBox(width: UnaSpace.sm),
        ],
        Flexible(child: _label()),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: UnaSpace.sm),
          _icon(widget.trailingIcon!),
        ],
      ],
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
            width: widget.iconOnly ? widget.height : null,
            constraints: BoxConstraints(minHeight: widget.height),
            padding: widget.iconOnly
                ? EdgeInsets.zero
                // Prototipo: 28 delante y 22 detrás si hay flecha.
                : EdgeInsets.fromLTRB(
                    UnaSpace.xl,
                    UnaSpace.sm,
                    widget.trailingIcon != null ? UnaSpace.ml : UnaSpace.xl,
                    UnaSpace.sm,
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
            child: _content(),
          ),
        ),
      ),
    );
  }
}
