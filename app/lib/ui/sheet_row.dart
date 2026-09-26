import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
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
          child: Semantics(
            header: true,
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
          child: Semantics(
            button: true,
            label: closeLabel,
            excludeSemantics: true,
            onTap: () => Navigator.of(context).pop(),
            child: InkResponse(
              onTap: () => Navigator.of(context).pop(),
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
        ),
      ],
    );
  }
}

/// Fila de las hojas (menú, "Mover"; `.mrow` del prototipo): 58 px, icono de 22, texto de 19 en negrita.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
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
  final VoidCallback onTap;
  final Color color;
  final bool divider;
  final bool enabled;
  final String? disabledHint;

  /// Prototipo: `.mrow:disabled { opacity: .35 }`.
  static const _disabledOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: trailingSemantics == null ? label : '$label, $trailingSemantics',
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
              height: UnaSizes.menuRow,
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
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.bodyL,
                        fontWeight: UnaFontWeights.bold,
                        color: color,
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
