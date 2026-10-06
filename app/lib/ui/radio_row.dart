import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Grupo de selección única de la página de Idioma (CA-015-07): rol de grupo de
/// botones de radio **sin etiqueta propia**. El título de la página ya lo
/// nombra; un nodo con etiqueta sería una parada de foco más (y repetiría
/// "Idioma" tras el título), justo lo que prohíbe la spec.
class UnaRadioGroup extends StatelessWidget {
  const UnaRadioGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.radioGroup,
    child: child,
  );
}

/// Opción de un grupo de selección única (prototipo: fila de Ajustes de 60;
/// spec 015, CA-015-07): nombre, línea opcional debajo ("Como el sistema" dice
/// el idioma que resulta) y, a la derecha, la marca de selección.
///
/// - Para el lector es un **botón de radio** (`checked`, dentro de un grupo de
///   selección única, no `selected`); la marca visible (una palanca de tinta
///   ≥ 3:1 frente al papel) es decorativa. El nombre lleva la línea de debajo
///   ("Como el sistema, Español"); [attributedLabel] lo sustituye cuando hay
///   que marcar un tramo con su idioma (CA-015-11).
/// - Toda la fila es la zona táctil; Intro y Espacio activan, y con el foco del
///   teclado o de un interruptor, anillo.
class UnaRadioRow extends StatefulWidget {
  const UnaRadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.attributedLabel,
    this.divider = false,
    this.focusNode,
    this.semanticsKey,
  });

  /// La marca de selección (para los tests).
  static const markKey = ValueKey<String>('una-radio-mark');

  final String label;

  /// Línea debajo del nombre, en monoespaciada (el idioma que resulta).
  final String? subtitle;

  /// Etiqueta del lector con marcas de idioma por tramo; sustituye a la que se
  /// forma con [label] y [subtitle].
  final AttributedString? attributedLabel;

  final bool selected;
  final VoidCallback onTap;

  /// Línea de 1 px sobre la fila (entre opciones).
  final bool divider;
  final FocusNode? focusNode;
  final GlobalKey? semanticsKey;

  @override
  State<UnaRadioRow> createState() => _UnaRadioRowState();
}

class _UnaRadioRowState extends State<UnaRadioRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;
    final attributed = widget.attributedLabel;
    return Semantics(
      key: widget.semanticsKey,
      checked: widget.selected,
      inMutuallyExclusiveGroup: true,
      focusable: true,
      focused: _focused,
      label: attributed == null
          ? (subtitle == null ? widget.label : '${widget.label}, $subtitle')
          : null,
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
              constraints: const BoxConstraints(
                minHeight: UnaSizes.settingsRow,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: UnaSpace.xs,
                vertical: UnaSpace.s,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontFamily: UnaFonts.display,
                            fontSize: UnaFontSizes.bodyL,
                            fontWeight: UnaFontWeights.bold,
                            height: 1.15,
                            color: UnaColors.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: UnaSpace.xs),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: UnaFonts.mono,
                              fontSize: UnaFontSizes.caption,
                              fontWeight: UnaFontWeights.regular,
                              height: 1.3,
                              color: UnaColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: UnaSpace.m),
                  // La marca ocupa siempre su sitio: las opciones no se
                  // mueven al elegir.
                  SizedBox.square(
                    dimension: UnaSizes.icon,
                    child: widget.selected
                        ? const UnaIcon(
                            UnaIcons.check,
                            key: UnaRadioRow.markKey,
                            strokeWidth: UnaSizes.iconStrokeBold,
                          )
                        : null,
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
