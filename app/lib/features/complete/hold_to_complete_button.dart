import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../ui/focus_ring.dart';
import '../../ui/una_icons.dart';

/// Botón "Pulsa para completar" (spec 003): hay que **mantenerlo** pulsado
/// `holdToComplete` (1,2 s). Un relleno `ink` avanza de izquierda a derecha con
/// el mismo texto en blanco; al soltar antes, retrocede en `holdRelease`.
///
/// - Teclado: mantener Espacio o Intro (CA-003-08); las repeticiones no cuentan.
/// - Lector de pantalla: acción "Completar tarea" (CA-003-07); el doble toque
///   **no** completa, para evitar accidentes.
/// - Pasar a segundo plano o arrastrar fuera cancela (CA-003-02).
class HoldToCompleteButton extends StatefulWidget {
  const HoldToCompleteButton({
    super.key,
    required this.label,
    required this.a11yAction,
    required this.a11yHint,
    required this.onComplete,
  });

  final String label;
  final String a11yAction;
  final String a11yHint;

  /// Se llama al cumplirse el tiempo (o desde la acción accesible). Devuelve
  /// false si no se pudo completar: entonces el relleno retrocede (CA-003-12).
  final Future<bool> Function() onComplete;

  @override
  State<HoldToCompleteButton> createState() => HoldToCompleteButtonState();
}

@visibleForTesting
class HoldToCompleteButtonState extends State<HoldToCompleteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: UnaMotion.holdToComplete,
  )..addStatusListener(_onFillStatus);
  late final AppLifecycleListener _lifecycle;

  int? _pointer;
  bool _holding = false;
  bool _done = false;
  bool _focused = false;

  /// Progreso del relleno (0–1).
  @visibleForTesting
  double get progress => _fill.value;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _cancel);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _fill.dispose();
    super.dispose();
  }

  void _start() {
    if (_holding || _done) return;
    setState(() => _holding = true);
    _fill.forward();
  }

  void _cancel() {
    if (!_holding) return;
    setState(() => _holding = false);
    _fill.animateBack(
      0,
      duration: UnaMotion.holdRelease,
      curve: UnaMotion.easeOutCurve,
    );
  }

  void _onFillStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding) _finish();
  }

  Future<void> _finish() async {
    setState(() {
      _holding = false;
      _done = true;
    });
    final ok = await widget.onComplete();
    if (!ok && mounted) {
      setState(() => _done = false);
      await _fill.animateBack(
        0,
        duration: UnaMotion.holdRelease,
        curve: UnaMotion.easeOutCurve,
      );
    }
  }

  /// Acción accesible: completa sin mantener pulsado (CA-003-07).
  Future<void> _completeNow() async {
    if (_holding || _done) return;
    _fill.value = 1;
    await _finish();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final isActivate = {
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.select, // Botón central del mando (D-pad)
    }.contains(e.logicalKey);
    if (!isActivate) return KeyEventResult.ignored;
    if (e is KeyDownEvent) _start();
    if (e is KeyUpEvent && !_done) _cancel();
    // KeyRepeatEvent: se consume sin reiniciar el progreso.
    return KeyEventResult.handled;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) return; // Solo cuenta el primer dedo (CL-003-3).
    _pointer = e.pointer;
    _start();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && !(Offset.zero & box.size).contains(e.localPosition)) {
      _cancel(); // Arrastrar fuera del botón (CA-003-02).
    }
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (!_done) _cancel();
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _holding || _done;
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.a11yHint,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.a11yAction): _completeNow,
      },
      // "Doble toque y mantener" (TalkBack), mantener pulsado (Switch Access,
      // Voice Access): lo mismo que el gesto. El doble toque simple no completa.
      onLongPress: _completeNow,
      excludeSemantics: true,
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (v) {
          // Si el foco se va (p. ej., Tab) mientras se mantiene, se cancela.
          if (!v && !_done) _cancel();
          setState(
            () => _focused =
                v &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional,
          );
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: FocusRing(
            visible: _focused,
            child: AnimatedContainer(
              duration: UnaMotion.press,
              transform: pressed
                  ? Matrix4.translationValues(4, 4, 0)
                  : Matrix4.identity(),
              constraints: const BoxConstraints(minHeight: UnaSizes.holdButton),
              decoration: BoxDecoration(
                color: UnaColors.surface,
                border: Border.all(
                  color: UnaColors.ink,
                  width: UnaBorders.strongWidth,
                ),
                boxShadow: [
                  if (pressed) UnaShadows.buttonPressed else UnaShadows.button,
                ],
              ),
              child: Stack(
                children: [
                  _content(UnaColors.ink),
                  // Relleno: el mismo contenido en blanco sobre `ink`, recortado.
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _FillClipper(_fill),
                      child: ColoredBox(
                        color: UnaColors.ink,
                        child: _content(UnaColors.onInk),
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

  Widget _content(Color color) {
    final style = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.button,
      fontWeight: UnaFontWeights.extrabold,
      letterSpacing: UnaLetterSpacing.snug * UnaFontSizes.button,
      color: color,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: UnaSizes.holdButton - 2 * UnaBorders.strongWidth,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UnaSpace.l,
          vertical: UnaSpace.s,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnaIcon(
                UnaIcons.check,
                size: UnaSizes.iconL,
                strokeWidth: UnaSizes.iconStrokeBold,
                color: color,
              ),
              const SizedBox(width: UnaSpace.sm),
              // Siempre en una línea (decisión del propietario).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    style: style,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recorta el relleno al progreso actual (de izquierda a derecha).
class _FillClipper extends CustomClipper<Rect> {
  _FillClipper(this.progress) : super(reclip: progress);
  final Animation<double> progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.value, size.height);

  @override
  bool shouldReclip(_FillClipper old) => old.progress != progress;
}
