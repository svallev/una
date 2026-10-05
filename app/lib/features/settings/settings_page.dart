import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_ring.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/una_icons.dart';

/// Orden de lectura de los niveles de Ajustes (CA-013-05, CA-015-20g): título,
/// contenido y, por último, Cerrar o Volver. El contenido, **avisos incluidos**,
/// lleva una sola clave y se ordena por geometría: el aviso de guardado sale
/// bajo su fila y el de enlace tras Ayuda. El orden del teclado es otro
/// (CA-015-21a): Cerrar o Volver arriba y el título fuera de Tab.
abstract final class SettingsOrder {
  static const title = 0.0;
  static const content = 1.0;
  static const leading = 3.0;
}

/// Orden de Tab de los niveles de Ajustes (CA-015-21a, 21f y 21g): Cerrar o
/// Volver primero y después el contenido, **estén desplazados como estén**. Con
/// el orden de lectura por geometría, una fila que sale por arriba de la
/// pantalla (texto al 200 %) pasaría a ir antes que Cerrar.
abstract final class SettingsFocusOrder {
  static const leading = NumericFocusOrder(0);
  static const content = NumericFocusOrder(1);
}

/// Marco de un nivel de Ajustes (spec 015; antes, de la 012): cabecera con el
/// botón (Cerrar ajustes en el nivel 1, Volver en el 2) y el título como
/// encabezado, y debajo el contenido.
///
/// - **Lector:** al llegar, el foco va al título (foco de entrada y aviso de
///   foco al nodo del título). El título no se activa ni entra en el orden de
///   Tab (`skipTraversal`).
/// - **Teclado:** Cerrar o Volver recibe el foco **solo con el teclado físico**
///   (modo de resaltado `traditional`); con TalkBack y toque no se le pide, para
///   no desviar al lector del título (CA-015-21a, plan §3).
/// - Sube un nivel con el botón, el atrás del sistema o Escape.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.root,
    required this.child,
  });

  final String title;

  /// El nivel 1 (icono Cerrar ajustes); el otro lleva Volver.
  final bool root;
  final Widget child;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _titleKey = GlobalKey();

  /// El título puede tener el foco (así Escape llega al marco con el tacto o
  /// con TalkBack), pero Tab nunca se detiene en él (`skipTraversal`).
  final _titleFocus = FocusNode(
    debugLabel: 'settings title',
    skipTraversal: true,
  );
  bool _titleFocused = false;
  bool _leaving = false;

  /// Con el teclado físico, Cerrar o Volver toma el foco al montarse. Se decide
  /// una vez, al abrir la página (no cada vez que cambia el modo).
  late final bool _keyboardFocus = showsFocusHighlight;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_revealFocus);
    // Al llegar, el foco del lector va al título (tabla de niveles de la spec).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Con teclado físico, el foco lo tiene Cerrar o Volver (autofocus); si
      // no, el título, para que el lector y Escape partan de la página.
      if (!_keyboardFocus) _titleFocus.requestFocus();
      _titleKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_revealFocus);
    _titleFocus.dispose();
    super.dispose();
  }

  /// Lleva a la vista el control que recibe el foco (WCAG 2.4.11, CA-015-21f),
  /// **en los dos sentidos**: la política de Tab por defecto solo desplaza hacia
  /// delante y, al dar la vuelta (de la última fila a la primera, o con
  /// Mayús+Tab desde Cerrar), dejaría la fila fuera de la pantalla.
  void _revealFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return;
    // Solo lo que hay dentro de esta página (no la tarea de debajo).
    if (context.findAncestorStateOfType<_SettingsPageState>() != this) return;
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(context, alignmentPolicy: policy);
    }
  }

  /// Sube un nivel (el botón y Escape). Una sola vez, y nunca con otra ruta
  /// (p. ej. la página de Idioma subiendo) por encima.
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
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prototipo del listado: alto 68, `padding: 12px 20px 0`.
                  FocusTraversalOrder(
                    order: SettingsFocusOrder.leading,
                    child: Padding(
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
                              sortKey: const OrdinalSortKey(
                                SettingsOrder.leading,
                              ),
                              child: SquareIconButton(
                                icon: widget.root
                                    ? UnaIcons.close
                                    : UnaIcons.arrowLeft,
                                label: widget.root
                                    ? l10n.settingsClose
                                    : l10n.settingsBack,
                                fill: UnaColors.paper,
                                autofocus: _keyboardFocus,
                                onPressed: _leave,
                              ),
                            ),
                            const SizedBox(width: UnaSpace.sm - 1),
                            Expanded(
                              child: Semantics(
                                key: _titleKey,
                                container: true,
                                header: true,
                                sortKey: const OrdinalSortKey(
                                  SettingsOrder.title,
                                ),
                                // Solo es el foco inicial del lector: ni se activa
                                // ni entra en el orden del teclado (CA-015-21a).
                                child: Focus(
                                  focusNode: _titleFocus,
                                  onFocusChange: (v) =>
                                      setState(() => _titleFocused = v),
                                  child: FocusRing(
                                    visible:
                                        _titleFocused && showsFocusHighlight,
                                    child: _FitTitle(widget.title),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    // Sin clave, el contenido se leería antes que Cerrar o
                    // después del título según su posición.
                    child: FocusTraversalOrder(
                      order: SettingsFocusOrder.content,
                      child: Semantics(
                        sortKey: const OrdinalSortKey(SettingsOrder.content),
                        // La zona que se desplaza termina sobre la barra de
                        // navegación del sistema: así `ensureVisible` (avisos,
                        // foco del teclado) nunca deja un elemento bajo ella.
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom,
                          ),
                          child: widget.child,
                        ),
                      ),
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
