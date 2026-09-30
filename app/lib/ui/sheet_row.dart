import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Cabecera de una hoja: etiqueta en monoespaciada (encabezado) y la X para
/// cerrar (prototipo: botón de 44 con margen derecho de -14).
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.label, required this.closeLabel});

  final String label;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // El lector lee la etiqueta tal cual (en mayúsculas se deletrearía).
          child: Semantics(
            header: true,
            label: label,
            excludeSemantics: true,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: UnaFonts.mono,
                fontSize: UnaFontSizes.tag,
                fontWeight: UnaFontWeights.bold,
                letterSpacing: UnaLetterSpacing.tagWide * UnaFontSizes.tag,
                color: UnaColors.ink,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(UnaSpace.m - 2, 0),
          child: _CloseButton(label: closeLabel),
        ),
      ],
    );
  }
}

/// La X de la cabecera: cierra la hoja. Con el foco del teclado o de un
/// interruptor, anillo de foco (WCAG 2.4.7).
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(),
      child: InkResponse(
        onTap: () => Navigator.of(context).pop(),
        onFocusChange: (v) => setState(() => _focused = v),
        child: FocusRing(
          visible: _focused && showsFocusHighlight,
          child: const SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Center(
              child: UnaIcon(
                UnaIcons.close,
                size: UnaSizes.iconS,
                strokeWidth: UnaSizes.iconStrokeBold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de las hojas (menú, "Mover"; `.mrow` del prototipo): 58 px como mínimo,
/// icono de 22, texto de 19 en negrita. Con [subtitle], dos líneas y 64 px como
/// mínimo ("Añadir a la tarea", spec 007). Con texto grande crece en lugar de
/// cortar el texto (CA-012-13) y, con el foco del teclado o de un interruptor,
/// muestra el anillo de foco (WCAG 2.4.7).
class SheetRow extends StatefulWidget {
  const SheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color = UnaColors.ink,
    this.divider = false,
    this.enabled = true,
    this.disabledHint,
    this.hint,
    this.trailing,
    this.trailingSemantics,
    this.focusNode,
    this.semanticsKey,
  });

  /// Texto pequeño alineado a la derecha (el total de tareas, CA-005-12).
  final String? trailing;

  /// Cómo lo lee el lector de pantalla ("3 tareas").
  final String? trailingSemantics;

  final UnaIconData icon;
  final String label;

  /// Segunda línea, en monoespaciada. El lector la lee tras el nombre, con
  /// una pausa en lugar del "·" ("Hacer foto. Con la cámara, va arriba del
  /// todo").
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final bool divider;
  final bool enabled;
  final String? disabledHint;

  /// Pista del lector con la fila activada ("Abre una página web en el
  /// navegador", CA-012-11). Desactivada, manda [disabledHint].
  final String? hint;

  /// Foco de teclado de la fila, para dárselo desde fuera (al volver de una
  /// pantalla, CA-012-02).
  final FocusNode? focusNode;

  /// Clave del nodo accesible de la fila, para enviar desde él el aviso de
  /// foco del lector.
  final GlobalKey? semanticsKey;

  /// Prototipo: `.mrow:disabled { opacity: .35 }`.
  static const _disabledOpacity = 0.35;

  @override
  State<SheetRow> createState() => _SheetRowState();
}

class _SheetRowState extends State<SheetRow> {
  bool _focused = false;

  String get _semanticLabel {
    final sub = widget.subtitle;
    final main = sub == null
        ? widget.label
        : '${widget.label}. ${sub.replaceAll(' · ', ', ')}';
    return widget.trailingSemantics == null
        ? main
        : '$main, ${widget.trailingSemantics}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final subtitle = widget.subtitle;
    final labelStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.bodyL,
      fontWeight: UnaFontWeights.bold,
      color: color,
    );
    return Semantics(
      key: widget.semanticsKey,
      button: true,
      enabled: widget.enabled,
      label: _semanticLabel,
      hint: widget.enabled ? widget.hint : widget.disabledHint,
      excludeSemantics: true,
      onTap: widget.enabled ? widget.onTap : null,
      child: Opacity(
        opacity: widget.enabled ? 1 : SheetRow._disabledOpacity,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            focusNode: widget.focusNode,
            onFocusChange: (v) => setState(() => _focused = v),
            highlightColor: UnaColors.pressed,
            splashFactory: NoSplash.splashFactory,
            child: FocusRing(
              visible: _focused && showsFocusHighlight,
              child: Container(
                // Con texto grande, la fila crece (una o dos líneas).
                constraints: BoxConstraints(
                  minHeight: subtitle == null
                      ? UnaSizes.menuRow
                      : UnaSizes.sheetRowTall,
                ),
                // A la derecha, sin margen: el total queda alineado con el
                // borde del botón "Nueva tarea".
                padding: const EdgeInsets.only(left: UnaSpace.xs),
                decoration: widget.divider
                    ? const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: UnaColors.disabled,
                            width: UnaBorders.hairlineWidth,
                          ),
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    UnaIcon(widget.icon, color: color),
                    const SizedBox(width: UnaSpace.m),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: UnaSpace.s,
                        ),
                        child: subtitle == null
                            ? Text(widget.label, style: labelStyle)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.label, style: labelStyle),
                                  const SizedBox(height: UnaSpace.xxs),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontFamily: UnaFonts.mono,
                                      fontSize: UnaFontSizes.micro,
                                      fontWeight: UnaFontWeights.regular,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (widget.trailing != null)
                      Text(
                        widget.trailing!,
                        style: TextStyle(
                          fontFamily: UnaFonts.mono,
                          fontSize: UnaFontSizes.link,
                          fontWeight: UnaFontWeights.bold,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
