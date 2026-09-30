import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_ring.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/una_icons.dart';

/// Orden de lectura de los niveles de la Configuración (spec 012, plan §8):
/// título, aviso o estado, opciones o filas, y por último Cerrar o Volver.
/// El orden del teclado es otro (CA-012-12): Cerrar/Volver, título, opciones.
abstract final class SettingsOrder {
  static const title = 0.0;
  static const status = 1.0;
  static const content = 2.0;
  static const leading = 3.0;
}

/// Marco de un nivel de la Configuración (spec 012): cabecera con el botón
/// (Cerrar en el nivel 1, Volver en los otros) y el título como encabezado, y
/// debajo el contenido. Lleva el foco al título al llegar (CA-012-02) y sube un
/// nivel con el botón, el atrás del sistema o Escape.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.root,
    required this.child,
    this.titleFocus,
    this.titleKey,
  });

  final String title;

  /// El nivel 1 (icono Cerrar); los demás llevan Volver.
  final bool root;
  final Widget child;

  /// Foco del título, si la pantalla necesita dárselo después (p. ej. tras
  /// "Reintentar").
  final FocusNode? titleFocus;

  /// Clave del nodo accesible del título.
  final GlobalKey? titleKey;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ownFocus = FocusNode(debugLabel: 'settings title');
  final _ownKey = GlobalKey();
  bool _titleFocused = false;
  bool _leaving = false;

  FocusNode get _focus => widget.titleFocus ?? _ownFocus;
  GlobalKey get _key => widget.titleKey ?? _ownKey;

  @override
  void initState() {
    super.initState();
    // Al llegar, el foco va al título (tabla de niveles de la spec).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _key.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  void dispose() {
    _ownFocus.dispose();
    super.dispose();
  }

  /// Sube un nivel (el botón y Escape). Una sola vez, y nunca con otra ruta
  /// (la confirmación del enlace) por encima.
  void _leave() {
    if (_leaving || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _leave},
      child: Scaffold(
        backgroundColor: UnaColors.paper,
        body: SafeArea(
          bottom: false,
          // Sin `label`: el título ya se lee como encabezado (no se dice dos
          // veces al entrar).
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prototipo del listado: alto 68, `padding: 12px 20px 0`.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    UnaSpace.ml - 1,
                    UnaSpace.sm,
                    UnaSpace.ml,
                    0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: UnaSizes.listHeader - UnaSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          sortKey: const OrdinalSortKey(SettingsOrder.leading),
                          child: SquareIconButton(
                            icon: widget.root
                                ? UnaIcons.close
                                : UnaIcons.arrowLeft,
                            label: widget.root
                                ? l10n.settingsClose
                                : l10n.licensesBack,
                            fill: UnaColors.paper,
                            onPressed: _leave,
                          ),
                        ),
                        const SizedBox(width: UnaSpace.sm - 1),
                        Expanded(
                          child: Semantics(
                            key: _key,
                            container: true,
                            header: true,
                            sortKey: const OrdinalSortKey(SettingsOrder.title),
                            child: Focus(
                              focusNode: _focus,
                              onFocusChange: (v) =>
                                  setState(() => _titleFocused = v),
                              child: FocusRing(
                                visible: _titleFocused && showsFocusHighlight,
                                child: _FitTitle(widget.title),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  // Sin clave, el contenido se leería antes que Cerrar o
                  // después del título según su posición.
                  child: Semantics(
                    sortKey: const OrdinalSortKey(SettingsOrder.content),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El título: 26 con la escala de texto del sistema, pero si la palabra más
/// larga no cabe en el ancho (al 200 %, "Configuración" a 360 dp) se reduce lo
/// justo para que no se parta ninguna palabra, como el texto de la tarea
/// (CA-001-07, CA-012-13), y nunca por debajo de 26.
class _FitTitle extends StatelessWidget {
  const _FitTitle(this.text);

  final String text;

  static const _base = TextStyle(
    fontFamily: UnaFonts.display,
    fontSize: UnaFontSizes.title,
    fontWeight: UnaFontWeights.extrabold,
    letterSpacing: UnaLetterSpacing.tighter * UnaFontSizes.title,
    color: UnaColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaled = scaler.scale(UnaFontSizes.title);
        var longest = 0.0;
        for (final word in text.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(
              text: word,
              style: _base.copyWith(fontSize: scaled),
            ),
            textDirection: direction,
          )..layout();
          if (painter.width > longest) longest = painter.width;
          painter.dispose();
        }
        // Sin encoger por debajo del tamaño sin escalar: un nombre largo sin
        // espacios (`flutter_local_notifications_platform_interface`) se parte
        // por caracteres en lugar de quedar diminuto.
        final floor = scaled > UnaFontSizes.title
            ? UnaFontSizes.title / scaled
            : 1.0;
        final fit = longest > constraints.maxWidth
            ? math.max(constraints.maxWidth / longest, floor)
            : 1.0;
        return Text(
          text,
          textScaler: TextScaler.noScaling,
          style: _base.copyWith(fontSize: scaled * fit),
        );
      },
    );
  }
}
