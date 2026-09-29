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

/// Fila de las hojas (menú, "Mover"; `.mrow` del prototipo): 58 px, icono de 22, texto de 19 en negrita.
/// Con [subtitle], dos líneas y 64 px como mínimo ("Añadir a la tarea", spec 007).
class SheetRow extends StatelessWidget {
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
    this.trailing,
    this.trailingSemantics,
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

  /// Prototipo: `.mrow:disabled { opacity: .35 }`.
  static const _disabledOpacity = 0.35;

  String get _semanticLabel {
    final sub = subtitle;
    final main = sub == null ? label : '$label. ${sub.replaceAll(' · ', ', ')}';
    return trailingSemantics == null ? main : '$main, $trailingSemantics';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.bodyL,
      fontWeight: UnaFontWeights.bold,
      color: color,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: _semanticLabel,
      hint: enabled ? null : disabledHint,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            highlightColor: UnaColors.pressed,
            splashFactory: NoSplash.splashFactory,
            child: Container(
              height: subtitle == null ? UnaSizes.menuRow : null,
              // Con texto grande, la fila de dos líneas crece.
              constraints: subtitle == null
                  ? null
                  : const BoxConstraints(minHeight: UnaSizes.sheetRowTall),
              // A la derecha, sin margen: el total queda alineado con el borde
              // del botón "Nueva tarea".
              padding: const EdgeInsets.only(left: UnaSpace.xs),
              decoration: divider
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
                  UnaIcon(icon, color: color),
                  const SizedBox(width: UnaSpace.m),
                  Expanded(
                    child: subtitle == null
                        ? Text(label, style: labelStyle)
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: UnaSpace.s,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label, style: labelStyle),
                                const SizedBox(height: UnaSpace.xxs),
                                Text(
                                  subtitle!,
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
                  if (trailing != null)
                    Text(
                      trailing!,
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
    );
  }
}
