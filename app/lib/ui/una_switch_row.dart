import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'una_icons.dart';

/// Fila de interruptor de Ajustes (prototipo, tablero 16; spec 015, CA-015-03):
/// icono, nombre, subtítulo opcional y, a la derecha, el interruptor de 54 × 32.
///
/// - **El estado lo da la posición del pomo, no el color** (WCAG 1.4.1): el
///   pomo cambia de lado y, como en el prototipo, pista y pomo intercambian
///   colores (apagado: pista del papel y pomo amarillo; encendido, al revés).
///   El amarillo contra el papel no contrasta y no se le exige: contrastan los
///   bordes de tinta (`validate-tokens`, CA-015-19).
/// - **Sin cambio optimista:** el estado mostrado es [value], el que da el
///   controlador. Tocar la fila solo avisa con [onToggle]; el pomo se mueve
///   cuando el guardado se ha confirmado y [value] cambia (CA-015-03: si
///   falla, TalkBack no dice "activado" y luego "desactivado").
/// - **Un solo nodo** para el lector (`toggled`, con el nombre y el subtítulo
///   juntos, sin pista aparte): el cambio de estado lo anuncia el sistema.
/// - Toda la fila es la zona táctil; Intro y Espacio activan (`InkWell` →
///   `ActivateIntent`) y, con el foco del teclado o de un interruptor, anillo.
/// - Con "reducir movimiento", pomo y pista cambian en el mismo fotograma
///   (CA-015-01d).
class UnaSwitchRow extends StatefulWidget {
  const UnaSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onToggle,
    this.subtitle,
    this.divider = false,
    this.focusNode,
    this.semanticsKey,
  });

  /// La pista y el pomo (para los tests: posición y colores).
  static const trackKey = ValueKey<String>('una-switch-track');
  static const knobKey = ValueKey<String>('una-switch-knob');

  final UnaIconData icon;
  final String label;

  /// Segunda línea en monoespaciada ("Imágenes, documentos y web").
  final String? subtitle;

  /// El valor que da el controlador: encendido o apagado.
  final bool value;

  /// Se llama al tocar o activar la fila; **no** cambia nada por sí sola.
  final VoidCallback onToggle;

  /// Línea de 1 px sobre la fila (entre filas de un mismo bloque).
  final bool divider;

  /// Foco de teclado de la fila, para dárselo desde fuera.
  final FocusNode? focusNode;

  /// Clave del nodo accesible de la fila, para enviar desde él el aviso de
  /// foco del lector.
  final GlobalKey? semanticsKey;

  @override
  State<UnaSwitchRow> createState() => _UnaSwitchRowState();
}

class _UnaSwitchRowState extends State<UnaSwitchRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: widget.semanticsKey,
      toggled: widget.value,
      // Nombre y subtítulo se leen juntos.
      label: subtitle == null ? widget.label : '${widget.label}, $subtitle',
      excludeSemantics: true,
      onTap: widget.onToggle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onToggle,
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          highlightColor: UnaColors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: FocusRing(
            visible: _focused && showsFocusHighlight,
            child: Container(
              constraints: BoxConstraints(
                minHeight: subtitle == null
                    ? UnaSizes.settingsRowSwitch
                    : UnaSizes.settingsRowSwitchHint,
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
                  UnaIcon(widget.icon),
                  const SizedBox(width: UnaSpace.m),
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
                              fontSize: UnaFontSizes.tag,
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
                  _Switch(value: widget.value, reduceMotion: reduce),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El interruptor dibujado (decorativo para el lector: la fila ya dice su
/// estado). Medidas del prototipo en tokens: pista de 54 × 32 con borde de
/// tinta de 3 y esquinas de 8; pomo de 22 con borde de 2 y esquinas de 4, a 2
/// de la esquina de dentro de la pista y 22 de recorrido.
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.reduceMotion});

  final bool value;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final trackFill = value ? UnaColors.switchOn : UnaColors.paper;
    final knobFill = value ? UnaColors.paper : UnaColors.switchOn;
    return AnimatedContainer(
      key: UnaSwitchRow.trackKey,
      duration: reduceMotion ? Duration.zero : UnaMotion.switchTrack,
      width: UnaSizes.switchWidth,
      height: UnaSizes.switchHeight,
      decoration: BoxDecoration(
        color: trackFill,
        border: const Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.switchTrackWidth),
        ),
        borderRadius: BorderRadius.circular(UnaBorders.switchTrackRadius),
      ),
      child: Stack(
        children: [
          AnimatedPositionedDirectional(
            duration: reduceMotion ? Duration.zero : UnaMotion.switchKnob,
            curve: UnaMotion.sheetCurve,
            start:
                UnaSizes.switchKnobInset +
                (value ? UnaSizes.switchKnobTravel : 0),
            top: UnaSizes.switchKnobInset,
            width: UnaSizes.switchKnob,
            height: UnaSizes.switchKnob,
            // El color del pomo cambia sin transición (prototipo: solo se
            // anima su posición).
            child: Container(
              key: UnaSwitchRow.knobKey,
              decoration: BoxDecoration(
                color: knobFill,
                border: const Border.fromBorderSide(
                  BorderSide(
                    color: UnaColors.ink,
                    width: UnaBorders.switchKnobWidth,
                  ),
                ),
                borderRadius: BorderRadius.circular(
                  UnaBorders.switchKnobRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
