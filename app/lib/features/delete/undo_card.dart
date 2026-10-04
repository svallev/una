import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsSortKey;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/semantics.dart' show FocusSemanticEvent;
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_ring.dart';
import '../../ui/una_icons.dart';
import '../attachments/task_labels.dart';
import 'undo_controller.dart' show UndoFocus;

/// La card número `serial` ya se ha dibujado (`UndoController.cardShown`).
typedef UndoShownCallback = void Function(
  int serial, {
  required bool screenReader,
});

/// El foco del lector o del teclado entra en la card número `serial` o sale
/// de ella (`UndoController.focusChanged`).
typedef UndoFocusCallback = void Function(
  int serial,
  UndoFocus source, {
  required bool focused,
});

/// El lector se ha encendido o apagado con la card a la vista
/// (`UndoController.screenReaderChanged`).
typedef UndoScreenReaderCallback = void Function({required bool enabled});

/// Card de deshacer (spec 014, tableros 12 y 13; prototipo `.undo`): franja
/// negra abajo, a todo el ancho, con la papelera, "Tarea eliminada", la
/// etiqueta de la tarea, el botón "Deshacer" y la barra de tiempo del color de
/// la nota (CA-014-03, CA-014-04).
///
/// Para el lector es **un solo nodo** con papel de botón que se lee una vez,
/// «Deshacer. Tarea eliminada: {etiqueta}», sin región en vivo (CA-014-16).
/// Solo dibuja: el tiempo, deshacer y el foco los deciden el controlador y
/// quien la monta (`UndoCardHost` o el listado), a los que avisa por los
/// callbacks con el número de serie de la eliminación.
class UndoCard extends StatefulWidget {
  const UndoCard({
    super.key,
    required this.task,
    required this.serial,
    required this.fraction,
    required this.onUndo,
    required this.onShown,
    required this.onFocusChanged,
    this.onScreenReaderChanged,
    this.focusNode,
    this.sortKey,
    this.requestsFocus = false,
  });

  /// La tarea eliminada: su etiqueta y el color de la barra.
  final Task task;

  /// Número de la eliminación. Si cambia (otra eliminación desde el listado,
  /// CA-014-08), la card se queda, sin volver a entrar, con otra etiqueta y
  /// otro nodo para el lector.
  final int serial;

  /// Lo que queda, de 1 a 0: se lee en cada fotograma (barra de tiempo).
  final double Function() fraction;

  /// "Deshacer": con el dedo, el lector, Intro, Espacio o el switch. Las
  /// guardas (350 ms, una sola vez) son del controlador.
  final VoidCallback onUndo;
  final UndoShownCallback onShown;
  final UndoFocusCallback onFocusChanged;
  final UndoScreenReaderCallback? onScreenReaderChanged;

  /// Foco de teclado de "Deshacer": lo guarda quien la monta, para pedírselo
  /// y para que no se pierda al cambiar de serie.
  final FocusNode? focusNode;

  /// Orden de lectura frente a sus hermanos (va la primera, CA-014-16).
  final SemanticsSortKey? sortKey;

  /// Si lleva el foco a sí misma al aparecer y con cada eliminación nueva
  /// (CA-014-16, CA-014-20): el aviso de foco al lector, siempre, y el foco de
  /// entrada de "Deshacer" con un lector o un teclado físico en uso (P-014-3).
  /// No se pide a sí misma el foco si no se lo piden: el cambio de ventana no
  /// basta para llevar a TalkBack a la card (plan 014 §1).
  final bool requestsFocus;

  /// Claves para los tests y las medidas.
  static const contentKey = ValueKey('undo-card-content');
  static const buttonKey = ValueKey('undo-card-button');
  static const barKey = ValueKey('undo-card-bar');

  @override
  State<UndoCard> createState() => _UndoCardState();
}

class _UndoCardState extends State<UndoCard> with TickerProviderStateMixin {
  static const _titleStyle = TextStyle(
    fontFamily: UnaFonts.display,
    fontSize: UnaFontSizes.body,
    fontWeight: UnaFontWeights.extrabold,
    letterSpacing: UnaLetterSpacing.snug * UnaFontSizes.body,
    color: UnaColors.onInk,
  );
  static const _labelStyle = TextStyle(
    fontFamily: UnaFonts.mono,
    fontSize: UnaFontSizes.micro,
    fontWeight: UnaFontWeights.regular,
    color: UnaColors.onInkMuted,
  );
  static const _buttonStyle = TextStyle(
    fontFamily: UnaFonts.display,
    fontSize: UnaFontSizes.bodyS,
    fontWeight: UnaFontWeights.extrabold,
    color: UnaColors.onInk,
  );

  /// Teclas que activan "Deshacer" (como los atajos por defecto de la app).
  static final _activators = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  };

  late final AnimationController _enter;
  late final Animation<double> _entered;
  late final ValueNotifier<double> _fraction;
  late final Ticker _ticker;

  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;
  bool _down = false;
  bool? _screenReader;

  /// Nodo del lector de esta serie: uno nuevo con cada eliminación, para que
  /// se lea con la etiqueta nueva (CA-014-08).
  GlobalKey _semanticsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // La entrada no se acorta con "Quitar animaciones": solo pierde el
    // desplazamiento con reducir movimiento (CA-014-21).
    _enter = AnimationController(
      vsync: this,
      duration: UnaMotion.undoEnter,
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
    _entered = CurvedAnimation(parent: _enter, curve: UnaMotion.sheetCurve);
    // La barra se repinta en cada fotograma con lo que diga el controlador;
    // sigue con reducir movimiento (CA-014-21).
    _fraction = ValueNotifier(widget.fraction());
    _ticker = createTicker((_) => _fraction.value = widget.fraction())..start();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    _notifyShown();
    _requestEntryFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reader = MediaQuery.accessibleNavigationOf(context);
    final before = _screenReader;
    _screenReader = reader;
    if (before != null && before != reader) {
      widget.onScreenReaderChanged?.call(enabled: reader);
    }
  }

  @override
  void didUpdateWidget(UndoCard old) {
    super.didUpdateWidget(old);
    if (widget.focusNode != old.focusNode) {
      _focused = _node.hasFocus;
    }
    if (widget.serial != old.serial) {
      _semanticsKey = GlobalKey();
      _fraction.value = widget.fraction();
      _notifyShown();
      _requestEntryFocus();
    }
  }

  /// Tras el primer fotograma de cada serie (plan §4: así la cuenta no
  /// empieza antes de que se vea).
  void _notifyShown() {
    final serial = widget.serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.serial != serial) return;
      widget.onShown(
        serial,
        screenReader: MediaQuery.accessibleNavigationOf(context),
      );
    });
  }

  /// Foco explícito tras el primer fotograma de cada serie (plan §3): el nodo
  /// de la serie ya existe y el aviso al lector llega a él. Con un lector
  /// ([MediaQuery.accessibleNavigation]) o un teclado físico (modo
  /// tradicional) también el foco de entrada de "Deshacer"; con el tacto sin
  /// lector, no (CA-014-20).
  void _requestEntryFocus() {
    if (!widget.requestsFocus) return;
    final serial = widget.serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.serial != serial) return;
      final reader = MediaQuery.accessibleNavigationOf(context);
      final keyboard =
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
      if (reader || keyboard) {
        if (_node.hasFocus) {
          // Ya lo tenía (otra eliminación seguida): el controlador empieza de
          // cero con cada serie y no se entera si no se le avisa.
          widget.onFocusChanged(serial, UndoFocus.keyboard, focused: true);
        } else {
          _node.requestFocus();
        }
      }
      _semanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  void _onHighlightMode(FocusHighlightMode _) {
    if (mounted && _focused) setState(() {});
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChanged(widget.serial, UndoFocus.keyboard, focused: focused);
  }

  /// Intro o Espacio mantenidos (o con rebote) no repiten (CL-014-3); Escape
  /// se consume sin hacer nada: en Android volvería al sistema como ATRÁS
  /// (CA-014-20).
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) return KeyEventResult.handled;
    if (!_activators.contains(key)) return KeyEventResult.ignored;
    if (event is KeyDownEvent) widget.onUndo();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _ticker.dispose();
    _fraction.dispose();
    _enter.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = taskLabel(
      l10n,
      widget.task,
    ).replaceAll(RegExp(r'[\r\n]+'), ' ');
    final reduced = MediaQuery.disableAnimationsOf(context);
    final palette = UnaPalettes.classic;
    final color = palette[widget.task.colorKey % palette.length];
    return Semantics(
      key: _semanticsKey,
      container: true,
      button: true,
      label: l10n.undoA11yLabel(label),
      focusable: true,
      focused: _focused,
      sortKey: widget.sortKey,
      onTap: widget.onUndo,
      onFocus: defaultTargetPlatform == TargetPlatform.iOS
          ? null
          : _node.requestFocus,
      onDidGainAccessibilityFocus: () =>
          widget.onFocusChanged(widget.serial, UndoFocus.reader, focused: true),
      onDidLoseAccessibilityFocus: () => widget.onFocusChanged(
        widget.serial,
        UndoFocus.reader,
        focused: false,
      ),
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _entered,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            reduced ? 0 : UnaSizes.undoEnterOffset * (1 - _entered.value),
          ),
          child: child,
        ),
        // En el árbol del lector desde el primer fotograma (CA-014-16).
        child: FadeTransition(
          opacity: _entered,
          alwaysIncludeSemantics: true,
          child: ColoredBox(
            color: UnaColors.ink,
            // Abajo, la barra queda encima del margen del sistema y el negro
            // llega al borde (P-014-2); a los lados, el contenido y la barra
            // quedan dentro (barra de navegación, recorte de la cámara).
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _content(context, l10n, label),
                  RepaintBoundary(
                    child: SizedBox(
                      height: UnaSizes.undoBar,
                      child: CustomPaint(
                        key: UndoCard.barKey,
                        painter: _BarPainter(_fraction, color),
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

  Widget _content(BuildContext context, AppLocalizations l10n, String label) {
    final scaler = MediaQuery.textScalerOf(context);
    // Con el texto grande, la etiqueta puede ocupar dos líneas (CL-014-6).
    final twoLines =
        scaler.scale(UnaFontSizes.micro) / UnaFontSizes.micro >=
        UnaMotion.undoLabelTwoLinesTextScale;
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.undoDeletedTitle, style: _titleStyle),
        const SizedBox(height: UnaSizes.undoTextGap),
        Text(
          label,
          maxLines: twoLines ? 2 : 1,
          softWrap: twoLines,
          overflow: TextOverflow.ellipsis,
          style: _labelStyle,
        ),
      ],
    );
    const trash = UnaIcon(UnaIcons.trash, color: UnaColors.onInk);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = _fitsSideBySide(
          context,
          l10n,
          constraints.maxWidth - UnaSpace.l - UnaSpace.ml,
        );
        final button = _button(l10n);
        return Container(
          key: UndoCard.contentKey,
          constraints: const BoxConstraints(minHeight: UnaSizes.undoCard),
          padding: const EdgeInsets.fromLTRB(
            UnaSpace.l,
            UnaSpace.m,
            UnaSpace.ml,
            UnaSpace.m,
          ),
          alignment: AlignmentDirectional.centerStart,
          child: sideBySide
              ? Row(
                  children: [
                    trash,
                    const SizedBox(width: UnaSizes.undoGap),
                    Expanded(child: texts),
                    const SizedBox(width: UnaSizes.undoGap),
                    button,
                  ],
                )
              // "Deshacer" no cabe al lado: pasa debajo, a la derecha
              // (CL-014-6, DEV-51).
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        trash,
                        const SizedBox(width: UnaSizes.undoGap),
                        Expanded(child: texts),
                      ],
                    ),
                    const SizedBox(height: UnaSizes.undoGap),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: button,
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// "Deshacer" va al lado del texto si, con su ancho, "Tarea eliminada" cabe
  /// en una línea en lo que queda; en horizontal, siempre (CL-014-7).
  bool _fitsSideBySide(
    BuildContext context,
    AppLocalizations l10n,
    double width,
  ) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return true;
    }
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final button =
        2 * (UnaBorders.undoButtonWidth + UnaSizes.undoButtonPadX) +
        UnaSizes.undoIcon +
        UnaSpace.s +
        measure(l10n.undoButton, _buttonStyle);
    final text = width - UnaSizes.icon - 2 * UnaSizes.undoGap - button;
    return measure(l10n.undoDeletedTitle, _titleStyle) <= text;
  }

  /// "Deshacer": se ve de 44 con borde blanco y su zona táctil mide 48 dp
  /// (CA-014-03). El anillo de foco tiene sitio libre alrededor (9 px) y no
  /// se recorta (CA-014-20).
  Widget _button(AppLocalizations l10n) {
    const press = UnaSizes.undoButtonPress;
    final visible = DecoratedBox(
      key: UndoCard.buttonKey,
      decoration: BoxDecoration(
        border: Border.all(
          color: UnaColors.onInk,
          width: UnaBorders.undoButtonWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UnaSizes.undoButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnaBorders.undoButtonWidth + UnaSizes.undoButtonPadX,
            vertical: UnaBorders.undoButtonWidth,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UnaIcon(
                UnaIcons.arrowUTurnLeft,
                size: UnaSizes.undoIcon,
                strokeWidth: UnaSizes.undoIconStroke,
                color: UnaColors.onInk,
              ),
              const SizedBox(width: UnaSpace.s),
              Text(
                l10n.undoButton,
                maxLines: 1,
                softWrap: false,
                style: _buttonStyle,
              ),
            ],
          ),
        ),
      ),
    );
    return Focus(
      focusNode: _node,
      // El nodo del lector es el de toda la card.
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onUndo,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            widthFactor: 1,
            child: FocusRing(
              visible: _focused && showsFocusHighlight,
              child: Transform.translate(
                offset: _down ? const Offset(press, press) : Offset.zero,
                child: visible,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de tiempo: la pista gris y, encima, la parte que queda, del color
/// de la nota, pegada a la izquierda: se vacía de derecha a izquierda.
class _BarPainter extends CustomPainter {
  _BarPainter(this.fraction, this.color) : super(repaint: fraction);

  final ValueListenable<double> fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = UnaColors.undoTrack);
    final left = fraction.value.clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * left, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.color != color || old.fraction != fraction;
}
