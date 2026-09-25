import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/una_icons.dart';

/// Rotura de la nota y enhorabuena (spec 003, CA-003-03b/04, prototipo
/// `design/prototype/Main.dc.html`: `.tear`, `.half`, `.success`, `.cf*`).
///
/// La nota se parte en dos mitades con borde irregular que caen **por encima**
/// de la enhorabuena (fondo `ink`). A los `successHold` (o 4 s con lector de
/// pantalla, CA-003-13) empieza el fundido de `successFade`.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.face,
    required this.colorKey,
    required this.hasNext,
    required this.onFadeStart,
    required this.onFinished,
  });

  /// La nota tal como se veía (sin logotipo, menú ni botón): se recorta en dos.
  final Widget face;
  final int colorKey;
  final bool hasNext;
  final VoidCallback onFadeStart;
  final VoidCallback onFinished;

  /// Con lector de pantalla la enhorabuena dura al menos esto (CA-003-13).
  static const screenReaderHold = Duration(seconds: 4);

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;
  late Duration _hold;
  late bool _reduced;
  bool _fadeStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t != null) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _hold = MediaQuery.accessibleNavigationOf(context)
        ? CelebrationOverlay.screenReaderHold
        : UnaMotion.successHold;
    _t =
        AnimationController(
            vsync: this,
            duration: _hold + UnaMotion.successFade,
          )
          ..addListener(_onTick)
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) widget.onFinished();
          })
          ..forward();
  }

  void _onTick() {
    if (!_fadeStarted && _elapsed >= _hold) {
      _fadeStarted = true;
      widget.onFadeStart();
    }
  }

  Duration get _elapsed => (_t!.duration!) * _t!.value;

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  /// Progreso (0–1) de un tramo [delay, delay + length) con su curva.
  double _segment(Duration delay, Duration length, Curve curve) {
    final ms = _elapsed.inMicroseconds - delay.inMicroseconds;
    if (ms <= 0) return 0;
    final v = (ms / length.inMicroseconds).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    const palette = UnaPalettes.classic;
    final color = palette[widget.colorKey % palette.length];
    return AnimatedBuilder(
      animation: _t!,
      builder: (context, _) {
        final fade = _segment(
          _hold,
          UnaMotion.successFade,
          UnaMotion.easeCurve,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 1 - fade,
              child: _Success(
                color: color,
                hasNext: widget.hasNext,
                reduced: _reduced,
                segment: _segment,
              ),
            ),
            if (_reduced)
              Opacity(
                opacity:
                    1 -
                    _segment(
                      Duration.zero,
                      UnaMotion.reducedMotionFade,
                      UnaMotion.easeCurve,
                    ),
                child: IgnorePointer(child: widget.face),
              )
            else ...[
              _TornHalf(
                left: true,
                progress: _segment(
                  Duration.zero,
                  UnaMotion.tear,
                  Curves.linear,
                ),
                child: widget.face,
              ),
              _TornHalf(
                left: false,
                progress: _segment(
                  Duration.zero,
                  UnaMotion.tear,
                  Curves.linear,
                ),
                child: widget.face,
              ),
            ],
          ],
        );
      },
    );
  }
}

typedef _Segment = double Function(Duration delay, Duration length, Curve c);

// ─── Enhorabuena ─────────────────────────────────────────────────────────────

class _Success extends StatelessWidget {
  const _Success({
    required this.color,
    required this.hasNext,
    required this.reduced,
    required this.segment,
  });

  final Color color;
  final bool hasNext;
  final bool reduced;
  final _Segment segment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stamp = reduced
        ? 1.0
        : segment(UnaMotion.stampDelay, UnaMotion.stamp, UnaMotion.stampCurve);
    final rise1 = reduced
        ? 1.0
        : segment(UnaMotion.riseDelay, UnaMotion.rise, UnaMotion.standardCurve);
    final rise2 = reduced
        ? 1.0
        : segment(
            UnaMotion.riseDelaySecond,
            UnaMotion.rise,
            UnaMotion.standardCurve,
          );
    final confetti = reduced
        ? 0.0
        : segment(
            UnaMotion.confettiDelay,
            UnaMotion.confetti,
            UnaMotion.confettiCurve,
          );
    const titleStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.success,
      fontWeight: UnaFontWeights.black,
      height: 1.02,
      letterSpacing: UnaLetterSpacing.intro * UnaFontSizes.success,
      color: UnaColors.onInk,
    );
    return ColoredBox(
      color: UnaColors.ink,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            if (confetti > 0 && confetti < 1)
              _Confetti(
                progress: confetti,
                origin: Offset(_confettiX, constraints.maxHeight / 2),
              ),
            SafeArea(
              child: Padding(
                // Prototipo: padding 0 24 60 (el bloque queda algo por encima del centro).
                padding: const EdgeInsets.fromLTRB(
                  UnaSpace.l,
                  0,
                  UnaSpace.l,
                  UnaSpace.xxl + UnaSpace.ml,
                ),
                child: Semantics(
                  container: true,
                  label: '${l10n.successTitle1} ${l10n.successTitle2}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stamp(progress: stamp, color: color),
                      const SizedBox(height: _gap),
                      _Rise(
                        progress: rise1,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${l10n.successTitle1}\n'),
                              TextSpan(
                                text: l10n.successTitle2,
                                style: TextStyle(color: color),
                              ),
                            ],
                          ),
                          style: titleStyle,
                        ),
                      ),
                      if (hasNext) ...[
                        const SizedBox(height: _gap),
                        _Rise(
                          progress: rise2,
                          child: Text(
                            l10n.successNext,
                            style: const TextStyle(
                              fontFamily: UnaFonts.mono,
                              fontSize: UnaFontSizes.bodyS,
                              height: 1.4,
                              color: UnaColors.onInk,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Separación entre sello, títulos y "siguiente" (prototipo: gap 22).
  static const _gap = UnaSpace.ml + UnaSpace.xxs;

  /// El confeti sale de la izquierda del sello (prototipo: left 72px).
  static const _confettiX = UnaSpace.l + UnaSpace.xxl + UnaSpace.s;
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Prototipo: scale(0) rotate(-30deg) opacity 0 → scale(1) rotate(-6deg).
    const from = -30 * math.pi / 180, to = -6 * math.pi / 180;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: from + (to - from) * progress,
        child: Transform.scale(
          scale: math.max(progress, 0),
          child: Container(
            width: UnaSizes.stamp,
            height: UnaSizes.stamp,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: UnaColors.onInk,
                width: UnaBorders.strongWidth,
              ),
              boxShadow: const [UnaShadows.stamp],
            ),
            child: const Center(
              child: UnaIcon(
                UnaIcons.check,
                size: UnaSizes.stampIcon,
                strokeWidth: UnaSizes.stampIconStroke,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.progress, required this.child});
  final double progress;
  final Widget child;

  /// Prototipo: `rise` desde 18 px más abajo.
  static const _distance = UnaSpace.m + UnaSpace.xxs;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress,
    child: Transform.translate(
      offset: Offset(0, _distance * (1 - progress)),
      child: child,
    ),
  );
}

// ─── Confeti ─────────────────────────────────────────────────────────────────

/// Piezas del prototipo (`.cf1`–`.cf18`): tamaño, color (índice de la paleta o
/// -1 = blanco), destino (dx, dy) y giro final en grados.
const _pieces = <(double, int, double, double, double)>[
  (10, 1, 162, -9, -194),
  (14, 2, -18, -103, 196),
  (10, 3, -45, -163, 95),
  (16, 4, 148, -8, -141),
  (12, -1, 191, 124, -128),
  (10, 0, -177, 182, 248),
  (12, 1, 82, 192, 24),
  (16, 2, 91, -145, 25),
  (12, 3, 194, 33, 129),
  (12, 4, 81, 163, -23),
  (14, -1, 211, 66, -74),
  (14, 0, -27, 183, 118),
  (16, 1, 188, -7, -205),
  (16, 2, 166, -71, 141),
  (10, 3, -106, 128, 150),
  (12, 4, 83, 263, 191),
  (10, -1, 143, 169, -156),
  (10, 0, -163, -23, 112),
];

class _Confetti extends StatelessWidget {
  const _Confetti({required this.progress, required this.origin});
  final double progress;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    // Opacidad 1 hasta el 70 % y después se apaga (prototipo).
    final opacity = progress < 0.7 ? 1.0 : 1 - (progress - 0.7) / 0.3;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final (size, colorIndex, dx, dy, turn) in _pieces)
            Positioned(
              left: origin.dx + dx * progress - size / 2,
              top: origin.dy + dy * progress - size / 2,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: turn * math.pi / 180 * progress,
                  child: Transform.scale(
                    scale: progress,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: colorIndex < 0
                            ? UnaColors.surface
                            : UnaPalettes.classic[colorIndex],
                        border: Border.all(
                          color: UnaColors.ink,
                          width: UnaSizes.confettiBorder,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Rotura ──────────────────────────────────────────────────────────────────

/// Borde irregular del prototipo (`.half .face`), en % de ancho y alto.
const _edge = <(double, double)>[
  (49.08, 0.00),
  (50.78, 2.50),
  (50.19, 4.85),
  (47.70, 7.78),
  (47.59, 10.99),
  (47.76, 14.06),
  (49.61, 16.44),
  (48.04, 20.30),
  (50.66, 22.94),
  (50.40, 27.04),
  (52.48, 30.03),
  (51.86, 32.32),
  (48.15, 35.10),
  (49.00, 37.54),
  (48.34, 41.37),
  (50.72, 44.73),
  (50.25, 47.68),
  (47.71, 50.00),
  (50.94, 52.62),
  (49.03, 55.67),
  (49.76, 59.04),
  (51.53, 61.84),
  (48.67, 65.44),
  (50.13, 68.79),
  (51.19, 72.74),
  (52.50, 75.52),
  (49.57, 77.95),
  (48.19, 81.67),
  (47.60, 84.84),
  (51.38, 88.38),
  (51.95, 91.73),
  (51.02, 94.55),
  (50.42, 97.94),
  (51.36, 100.00),
];

/// El papel asoma 1,3 % por el borde roto (`.half .fiber`).
const _fiberOffset = 1.30;

Path _halfPath(Size s, {required bool left, double offset = 0}) {
  final side = left ? 0.0 : s.width;
  final p = Path()..moveTo(side, 0);
  for (final (x, y) in _edge) {
    p.lineTo((x + offset) / 100 * s.width, y / 100 * s.height);
  }
  return p
    ..lineTo(side, s.height)
    ..close();
}

/// Fotogramas clave del prototipo (`tearL`; la derecha es simétrica): tiempo,
/// desplazamiento x, y y giro en grados.
const _keys = <(double, double, double, double)>[
  (0, 0, 0, 0),
  (0.08, -2, 0, -0.6),
  (0.14, 1, 0, 0.3),
  (0.38, -16, 4, -7),
  (1, -150, 980, -34),
];

(double, double, double) _tearAt(double t) {
  for (var i = 1; i < _keys.length; i++) {
    final (t1, x1, y1, r1) = _keys[i];
    if (t <= t1 || i == _keys.length - 1) {
      final (t0, x0, y0, r0) = _keys[i - 1];
      // Hasta el 38 %, la curva `tear`; después cae con `fall`.
      final curve = i < 4 ? UnaMotion.tearCurve : UnaMotion.fallCurve;
      final k = curve.transform(((t - t0) / (t1 - t0)).clamp(0.0, 1.0));
      double lerp(double a, double b) => a + (b - a) * k;
      return (lerp(x0, x1), lerp(y0, y1), lerp(r0, r1));
    }
  }
  return (0, 0, 0);
}

class _TornHalf extends StatelessWidget {
  const _TornHalf({
    required this.left,
    required this.progress,
    required this.child,
  });

  final bool left;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (x, y, turn) = _tearAt(progress);
    final sign = left ? 1.0 : -1.0;
    return IgnorePointer(
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.translationValues(x * sign, y, 0)
          ..rotateZ(turn * sign * math.pi / 180),
        child: CustomPaint(
          painter: _FiberPainter(left: left),
          child: ClipPath(
            clipper: _HalfClipper(left: left),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Sombra dura (`drop-shadow(4px 6px 0 ink/.85)`) y el filo de papel.
class _FiberPainter extends CustomPainter {
  _FiberPainter({required this.left});
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final fiber = _halfPath(
      size,
      left: left,
      offset: left ? _fiberOffset : -_fiberOffset,
    );
    canvas
      ..drawPath(
        fiber.shift(const Offset(4, 6)),
        Paint()..color = UnaColors.tearShadow,
      )
      ..drawPath(fiber, Paint()..color = UnaColors.paperFiber);
  }

  @override
  bool shouldRepaint(_FiberPainter old) => old.left != left;
}

class _HalfClipper extends CustomClipper<Path> {
  _HalfClipper({required this.left});
  final bool left;

  @override
  Path getClip(Size size) => _halfPath(size, left: left);

  @override
  bool shouldReclip(_HalfClipper old) => old.left != left;
}
