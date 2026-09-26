import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import 'crumple_keyframes.dart';
import 'trash_can.dart';

/// La nota eliminada se arruga hasta formar una bola que cae en la papelera
/// (spec 004, CA-004-04; prototipo `.sheet.crumpling`, `.wrap.crumpling`,
/// `.trash`, `.cta.hide`). Detrás ya está la siguiente tarea (o "Todo
/// hecho."); encima quedan el logotipo, el menú y el botón, que se oculta.
///
/// Con "reducir movimiento", la nota solo se desvanece en
/// `crumpleReducedFade`, sin papelera (CA-004-12).
class CrumpleOverlay extends StatefulWidget {
  const CrumpleOverlay({
    super.key,
    required this.face,
    required this.chrome,
    required this.onFinished,
  });

  /// La nota tal como se veía (color y texto, sin controles).
  final Widget face;

  /// Logotipo, menú y botón por encima; recibe la animación que oculta el
  /// botón (0 = visible, 1 = oculto).
  final Widget Function(Animation<double> ctaHide) chrome;
  final VoidCallback onFinished;

  @override
  State<CrumpleOverlay> createState() => _CrumpleOverlayState();
}

class _CrumpleOverlayState extends State<CrumpleOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;
  late final AppLifecycleListener _lifecycle;
  late bool _reduced;
  bool _finished = false;

  /// `.cta.hide`: 0,3 s con `ease` tras 0,15 s.
  static const _ctaDelay = Duration(milliseconds: 150);
  static const _ctaDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // Si la app pasa a segundo plano, al volver ya se ve la siguiente tarea,
    // sin repetir la animación (CA-004-03).
    _lifecycle = AppLifecycleListener(onHide: _finish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t != null) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _t =
        AnimationController(
          vsync: this,
          duration: _reduced ? UnaMotion.crumpleReducedFade : UnaMotion.crumple,
          // El fundido de 0,6 s también dura eso con "reducir movimiento"
          // (CA-004-12); por defecto se acortaría al 5 %.
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) _finish();
        });
    _t!.forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _t?.dispose();
    super.dispose();
  }

  Animation<double> get _ctaHide {
    final total = _t!.duration!.inMicroseconds;
    final start = _ctaDelay.inMicroseconds / total;
    final end = (_ctaDelay + _ctaDuration).inMicroseconds / total;
    return CurvedAnimation(
      parent: _t!,
      curve: Interval(start, math.min(end, 1), curve: Curves.ease),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t!;
    // Ni toques, ni lector, ni teclado: los controles de encima solo se ven
    // (CA-004-05).
    return IgnorePointer(
      child: ExcludeFocus(
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_reduced)
                FadeTransition(
                  // `fadeOut .6s ease`.
                  opacity: ReverseAnimation(
                    CurvedAnimation(parent: t, curve: Curves.ease),
                  ),
                  child: widget.face,
                )
              else
                AnimatedBuilder(
                  animation: t,
                  builder: (context, face) =>
                      _CrumplingNote(frame: CrumpleFrame(t.value), face: face!),
                  child: RepaintBoundary(child: widget.face),
                ),
              widget.chrome(_ctaHide),
              if (!_reduced)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      // Prototipo: `bottom: 30px`.
                      padding: const EdgeInsets.only(
                        bottom: UnaSpace.xl + UnaSpace.xxs,
                      ),
                      child: AnimatedBuilder(
                        animation: t,
                        builder: (_, _) =>
                            TrashCan(pose: CrumpleFrame(t.value).trash),
                      ),
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

/// La nota en un instante del arrugado: sombra dura, recorte, giro, escala,
/// facetas y sombreado de bola.
class _CrumplingNote extends StatelessWidget {
  const _CrumplingNote({required this.frame, required this.face});

  final CrumpleFrame frame;
  final Widget face;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final matrix = Matrix4.fromFloat64List(frame.transform.matrix(size));
        final opacity = frame.transform.opacity;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ShadowPainter(
                frame.clipPath(size).transform(matrix.storage),
                frame.shadow.offset * (size.width / UnaSizes.frameWidth),
                frame.shadow.alpha * opacity,
              ),
            ),
            Opacity(
              opacity: opacity,
              child: Transform(
                transform: matrix,
                child: ClipPath(
                  clipper: _PolygonClipper(frame),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      face,
                      Opacity(
                        opacity: frame.facetsOpacity,
                        child: const CustomPaint(painter: _FacetsPainter()),
                      ),
                      Opacity(
                        opacity: frame.shadeOpacity,
                        child: const CustomPaint(painter: _BallShadePainter()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolygonClipper extends CustomClipper<Path> {
  _PolygonClipper(this.frame);
  final CrumpleFrame frame;

  @override
  Path getClip(Size size) => frame.clipPath(size);

  @override
  bool shouldReclip(_PolygonClipper old) => old.frame.t != frame.t;
}

/// `lift`: `drop-shadow` duro (sin desenfoque) de la bola, en `ink`.
class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this.shape, this.offset, this.alpha);
  final Path shape;
  final Offset offset;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    canvas.drawPath(
      shape.shift(offset),
      Paint()..color = UnaColors.ink.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.offset != offset || old.alpha != alpha || old.shape != shape;
}

/// Pliegues: la malla de triángulos del prototipo (`.facets`), estirada a la
/// nota como el SVG con `preserveAspectRatio="none"`.
class _FacetsPainter extends CustomPainter {
  const _FacetsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * size.width / UnaSizes.frameWidth;
    final fill = Paint();
    for (final f in crumpleFacets) {
      final path = Path()
        ..addPolygon([
          for (final p in f.points)
            Offset(p.dx * size.width, p.dy * size.height),
        ], true);
      canvas.drawPath(path, fill..color = f.fill);
      canvas.drawPath(path, stroke..color = f.stroke);
    }
  }

  @override
  bool shouldRepaint(_FacetsPainter old) => false;
}

/// `.ballshade`: luz arriba a la izquierda y sombra abajo a la derecha, dos
/// degradados radiales elípticos (`farthest-corner`).
class _BallShadePainter extends CustomPainter {
  const _BallShadePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _ellipse(
      canvas,
      size,
      const Offset(0.36, 0.32),
      UnaColors.surface.withValues(alpha: 0.5),
      0.42,
    );
    _ellipse(
      canvas,
      size,
      const Offset(0.64, 0.70),
      UnaColors.ink.withValues(alpha: 0.32),
      0.58,
    );
  }

  /// Degradado de [color] a transparente en [stop], con la elipse de CSS:
  /// la proporción de `farthest-side` agrandada hasta la esquina más lejana
  /// (×√2).
  static void _ellipse(
    Canvas canvas,
    Size size,
    Offset at,
    Color color,
    double stop,
  ) {
    final rx = math.max(at.dx, 1 - at.dx) * size.width * math.sqrt2;
    final ry = math.max(at.dy, 1 - at.dy) * size.height * math.sqrt2;
    final center = Offset(at.dx * size.width, at.dy * size.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(center.dx, center.dy);
    canvas.scale(rx, ry);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: [0, stop],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BallShadePainter old) => false;
}
