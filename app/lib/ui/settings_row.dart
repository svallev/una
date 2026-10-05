import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Lo que va a la derecha de una [SettingsRow].
enum SettingsRowTrailing {
  /// Nada.
  none,

  /// Chevron: la fila abre otro nivel de Ajustes ("Idioma").
  chevron,
}

/// Fila de Ajustes (prototipo, tablero 16; spec 015, CA-015-01b y 06): icono a
/// la izquierda, nombre, valor a la derecha (opcional) y, al final, el
/// chevron (abre otro nivel) o el icono de "abre una web".
///
/// - **Medidas del prototipo** (tokens): 60 de alto mínimo; con [indent] (las
///   filas de web bajo "Información"), 52 y 38 de sangría, texto de 17 e icono
///   de 20.
/// - **El valor pasa a una segunda línea** con el texto grande (CA-015-06): en
///   un `Wrap`, nombre y valor van en la misma línea (el valor, a la derecha) y,
///   si no caben, el valor baja bajo el nombre, sin recortarse.
/// - **Un solo nodo** para el lector: botón con nombre, valor y, en las filas de
///   web, [opensWebHint] **dentro de la etiqueta** ("Ayuda, Abre una página
///   web en el navegador"; TalkBack puede omitir una pista). Los iconos son
///   decorativos. [attributedLabel] sustituye a esa etiqueta cuando hay que
///   marcar un tramo con su idioma (CA-015-11, "Idioma, Español").
/// - Toda la fila es la zona táctil; Intro y Espacio activan, y con el foco del
///   teclado o de un interruptor, anillo.
class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.trailing = SettingsRowTrailing.none,
    this.opensWebHint,
    this.attributedLabel,
    this.indent = false,
    this.divider = false,
    this.focusNode,
    this.semanticsKey,
  }) : assert(
         opensWebHint == null || trailing == SettingsRowTrailing.none,
         'una fila de web lleva el icono de "abre una web", no el chevron',
       );

  final UnaIconData icon;
  final String label;
  final VoidCallback onTap;

  /// Valor actual, a la derecha del nombre ("Español").
  final String? value;
  final SettingsRowTrailing trailing;

  /// "Abre una página web en el navegador": con él la fila es de web (lleva el
  /// icono de "abre una web") y el texto va unido al nombre del lector.
  final String? opensWebHint;

  /// Etiqueta del lector con marcas de idioma por tramo; sustituye a la que se
  /// forma con [label], [value] y [opensWebHint].
  final AttributedString? attributedLabel;

  /// Fila de web bajo "Información": más baja, con sangría y texto de 17.
  final bool indent;

  /// Línea de 1 px sobre la fila (entre filas de un mismo bloque).
  final bool divider;

  /// Foco de teclado de la fila, para dárselo desde fuera (al volver del nivel
  /// 2, al cancelar la confirmación de un enlace).
  final FocusNode? focusNode;

  /// Clave del nodo accesible de la fila, para enviar desde él el aviso de
  /// foco del lector.
  final GlobalKey? semanticsKey;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _focused = false;

  String get _semanticLabel =>
      [widget.label, ?widget.value, ?widget.opensWebHint].join(', ');

  @override
  Widget build(BuildContext context) {
    final indent = widget.indent;
    final value = widget.value;
    final attributed = widget.attributedLabel;
    final iconSize = indent ? UnaSizes.listIcon : UnaSizes.icon;
    return Semantics(
      key: widget.semanticsKey,
      button: true,
      label: attributed == null ? _semanticLabel : null,
      attributedLabel: attributed,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          highlightColor: UnaColors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: FocusRing(
            visible: _focused && showsFocusHighlight,
            child: Container(
              // Con texto grande, la fila crece (una o dos líneas).
              constraints: BoxConstraints(
                minHeight: indent
                    ? UnaSizes.settingsRowSub
                    : UnaSizes.settingsRow,
              ),
              padding: EdgeInsets.only(
                left: indent ? UnaSizes.settingsRowSubIndent : UnaSpace.xs,
                right: UnaSpace.xs,
                top: UnaSpace.s,
                bottom: UnaSpace.s,
              ),
              decoration: widget.divider
                  ? const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: UnaColors.disabled,
                          width: UnaSizes.separatorRow,
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  UnaIcon(widget.icon, size: iconSize),
                  SizedBox(width: indent ? UnaSpace.sm + 2 : UnaSpace.m),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: UnaSpace.s,
                      runSpacing: UnaSpace.xs,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: UnaFonts.display,
                            fontSize: indent
                                ? UnaFontSizes.body
                                : UnaFontSizes.bodyL,
                            fontWeight: UnaFontWeights.bold,
                            height: 1.15,
                            color: UnaColors.ink,
                          ),
                        ),
                        if (value != null)
                          Text(
                            value,
                            style: const TextStyle(
                              fontFamily: UnaFonts.mono,
                              fontSize: UnaFontSizes.caption,
                              fontWeight: UnaFontWeights.regular,
                              color: UnaColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.trailing == SettingsRowTrailing.chevron) ...[
                    const SizedBox(width: UnaSpace.s),
                    const UnaIcon(
                      UnaIcons.chevronRight,
                      size: UnaSizes.iconS + 2,
                      strokeWidth: UnaSizes.iconStrokeBold,
                    ),
                  ],
                  if (widget.opensWebHint != null) ...[
                    const SizedBox(width: UnaSpace.s),
                    const UnaIcon(
                      UnaIcons.openWeb,
                      size: UnaSizes.iconS + 2,
                      strokeWidth: UnaSizes.iconStrokeBold,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
