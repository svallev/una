// SPIKE S2 — animaciones del prototipo: mantener pulsado 1,2 s, romper en dos,
// arrugar con shader y papelera; variante "reducir movimiento". Código desechable.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'perf.dart';

const ink = Color(0xFF111111);
const paper = Color(0xFFF4F1EA);
const palette = [Color(0xFFFFE55C), Color(0xFFFF9EC4), Color(0xFF8FD3F4), Color(0xFFA6E88F), Color(0xFFFFB870)];

late ui.FragmentProgram crumpleProgram;

Future<void> loadShaders() async {
  crumpleProgram = await ui.FragmentProgram.fromAsset('shaders/crumple.frag');
}

class StickyNote extends StatelessWidget {
  const StickyNote({super.key, required this.text, required this.color, this.child});
  final String text;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final l = text.length;
    final size = l < 40 ? 50.0 : (l < 90 ? 40.0 : (l < 160 ? 31.0 : 26.0));
    return Container(
      decoration: BoxDecoration(color: color, border: Border.all(color: ink, width: 3)),
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 140),
      alignment: Alignment.centerLeft,
      child: child ??
          Text(text,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -0.03 * size, color: ink)),
    );
  }
}

enum Phase { idle, holding, tearing, success, successOut, crumpling }

class AnimLab extends StatefulWidget {
  const AnimLab({super.key});
  @override
  State<AnimLab> createState() => _AnimLabState();
}

class _AnimLabState extends State<AnimLab> with TickerProviderStateMixin {
  final _noteKey = GlobalKey();
  final _rec = FrameRecorder();
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _tear = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  late final AnimationController _crumple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  Phase _phase = Phase.idle;
  ui.Image? _snapshot;
  bool _reduceMotion = false;
  int _colorIdx = 0;
  String _stats = 'Sin mediciones todavía';

  final _texts = const ['Llamar a Marta para cerrar la fecha de la mudanza', 'Comprar bombillas', 'Leer el capítulo 3 antes del jueves'];

  bool get _reduced => _reduceMotion || MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _complete();
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    _tear.dispose();
    _crumple.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<ui.Image> _capture() async {
    final boundary = _noteKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
  }

  void _holdStart() {
    if (_phase != Phase.idle) return;
    setState(() => _phase = Phase.holding);
    _hold.forward(from: 0);
  }

  void _holdCancel() {
    if (_phase != Phase.holding || _hold.isCompleted) return;
    _hold.animateBack(0, duration: const Duration(milliseconds: 280));
    setState(() => _phase = Phase.idle);
  }

  Future<void> _complete() async {
    _rec.start();
    final img = await _capture();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    setState(() {
      _snapshot = img;
      _phase = Phase.tearing;
    });
    if (_reduced) {
      await _fade.forward(from: 0);
    } else {
      await _tear.forward(from: 0);
    }
    setState(() => _phase = Phase.success);
    await Future<void>.delayed(Duration(milliseconds: _reduced ? 1200 : 850));
    setState(() => _phase = Phase.successOut);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final s = await _rec.stopAfterFlush(_reduced ? 'Completar (reducir movimiento)' : 'Completar (romper en dos)');
    _next(s);
  }

  Future<void> _delete() async {
    if (_phase != Phase.idle) return;
    _rec.start();
    final img = await _capture();
    setState(() {
      _snapshot = img;
      _phase = Phase.crumpling;
    });
    if (_reduced) {
      await _fade.forward(from: 0);
    } else {
      await _crumple.forward(from: 0);
    }
    final s = await _rec.stopAfterFlush(_reduced ? 'Eliminar (reducir movimiento)' : 'Eliminar (arrugar + papelera)');
    _next(s);
  }

  void _next(FrameStats s) {
    _hold.value = 0;
    _tear.value = 0;
    _crumple.value = 0;
    _fade.value = 0;
    setState(() {
      _phase = Phase.idle;
      _snapshot = null;
      _colorIdx = (_colorIdx + 1) % palette.length;
      _stats = s.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _texts[_colorIdx % _texts.length];
    final color = palette[_colorIdx];
    final showNote = _phase == Phase.idle || _phase == Phase.holding;
    return Scaffold(
      backgroundColor: paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // La siguiente tarea espera debajo (se revela al romper o arrugar).
          StickyNote(text: _texts[(_colorIdx + 1) % _texts.length], color: palette[(_colorIdx + 1) % palette.length]),
          if (_phase == Phase.success || _phase == Phase.successOut || (_phase == Phase.tearing))
            AnimatedOpacity(
              opacity: _phase == Phase.successOut ? 0 : 1,
              duration: const Duration(milliseconds: 700),
              child: const _Success(),
            ),
          Offstage(
            offstage: !showNote,
            child: RepaintBoundary(key: _noteKey, child: StickyNote(text: text, color: color)),
          ),
          if (_phase == Phase.tearing && _snapshot != null)
            _reduced
                ? FadeTransition(opacity: ReverseAnimation(_fade), child: RawImage(image: _snapshot, fit: BoxFit.fill))
                : AnimatedBuilder(
                    animation: _tear,
                    builder: (_, _) => CustomPaint(painter: TearPainter(_snapshot!, _tear.value)),
                  ),
          if (_phase == Phase.crumpling && _snapshot != null) ...[
            if (_reduced)
              FadeTransition(opacity: ReverseAnimation(_fade), child: RawImage(image: _snapshot, fit: BoxFit.fill))
            else ...[
              AnimatedBuilder(
                animation: _crumple,
                builder: (_, _) => CustomPaint(painter: CrumplePainter(_snapshot!, _crumple.value)),
              ),
              AnimatedBuilder(animation: _crumple, builder: (_, _) => _Trash(t: _crumple.value)),
            ],
          ],
          if (showNote) ...[
            const Positioned(left: 24, top: 48, child: Text('una.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink))),
            Positioned(left: 24, right: 24, bottom: 32, child: _holdButton()),
          ],
          Positioned(
            left: 12,
            right: 12,
            top: 90,
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: .85),
                padding: const EdgeInsets.all(8),
                child: Text(_stats, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ink)),
              ),
            ),
          ),
          if (showNote)
            Positioned(
              right: 16,
              top: 40,
              child: Row(children: [
                const Text('Reducir mov.', style: TextStyle(fontSize: 12)),
                Switch(value: _reduceMotion, onChanged: (v) => setState(() => _reduceMotion = v)),
                IconButton.filled(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar (arrugar)'),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _holdButton() {
    return Semantics(
      button: true,
      label: 'Mantén pulsado para completar',
      customSemanticsActions: {const CustomSemanticsAction(label: 'Completar tarea'): _complete},
      child: Listener(
        onPointerDown: (_) => _holdStart(),
        onPointerUp: (_) => _holdCancel(),
        onPointerCancel: (_) => _holdCancel(),
        child: Container(
          height: 64,
          decoration: const BoxDecoration(color: Colors.white, border: Border.fromBorderSide(BorderSide(color: ink, width: 3)), boxShadow: [BoxShadow(color: ink, offset: Offset(5, 5))]),
          child: AnimatedBuilder(
            animation: _hold,
            builder: (_, _) => Stack(fit: StackFit.expand, children: [
              FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _hold.value, child: const ColoredBox(color: ink)),
              Center(
                child: Text(
                  _hold.isCompleted ? '¡Hecho!' : (_phase == Phase.holding ? 'Sigue pulsando…' : 'Mantén pulsado para completar'),
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _hold.value > .5 ? Colors.white : ink),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ink,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¡Enhorabuena!', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
          Text('Tarea completada.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 22),
          Text('Ahora a por la siguiente →', style: TextStyle(fontSize: 17, color: Colors.white)),
        ]),
      ),
    );
  }
}

// ─── Interpolación por fotogramas clave (como los @keyframes del prototipo) ───
double _kf(List<(double, double)> kf, double t) {
  if (t <= kf.first.$1) return kf.first.$2;
  for (var i = 1; i < kf.length; i++) {
    if (t <= kf[i].$1) {
      final a = kf[i - 1], b = kf[i];
      return ui.lerpDouble(a.$2, b.$2, (t - a.$1) / (b.$1 - a.$1))!;
    }
  }
  return kf.last.$2;
}

// Polígonos de recorte del @keyframes crumple del prototipo (12 puntos, en %).
const _crumplePolys = <(double, List<double>)>[
  (0, [0, 0, 33, 0, 67, 0, 100, 0, 100, 33, 100, 67, 100, 100, 67, 100, 33, 100, 0, 100, 0, 67, 0, 33]),
  (.06, [1, 1, 34, 2, 66, 0, 99, 2, 98, 33, 100, 67, 98, 99, 67, 98, 34, 100, 2, 98, 0, 66, 2, 34]),
  (.13, [4, 3, 35, 7, 64, 2, 96, 6, 93, 34, 98, 66, 94, 96, 65, 92, 37, 98, 6, 94, 2, 64, 8, 35]),
  (.22, [11, 10, 37, 17, 61, 7, 88, 13, 82, 37, 91, 62, 84, 88, 62, 80, 39, 92, 15, 86, 19, 61, 9, 37]),
  (.32, [20, 21, 41, 26, 59, 17, 78, 24, 73, 40, 81, 58, 74, 77, 58, 71, 42, 80, 23, 75, 28, 57, 18, 41]),
  (.43, [28, 29, 44, 32, 58, 26, 72, 31, 69, 44, 74, 58, 69, 70, 56, 67, 43, 73, 30, 69, 34, 56, 26, 43]),
  (.55, [31, 31, 46, 29, 60, 30, 71, 36, 72, 47, 70, 60, 66, 69, 54, 71, 42, 70, 32, 66, 28, 55, 29, 42]),
  (1, [31, 31, 46, 29, 60, 30, 71, 36, 72, 47, 70, 60, 66, 69, 54, 71, 42, 70, 32, 66, 28, 55, 29, 42]),
];

class CrumplePainter extends CustomPainter {
  CrumplePainter(this.image, this.t);
  final ui.Image image;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const rot = [(0.0, 0.0), (.06, -.4), (.13, -1.5), (.22, -3.0), (.32, -6.0), (.43, -11.0), (.55, -18.0), (.64, -70.0), (.88, -240.0), (.91, -250.0), (1.0, -250.0)];
    const sx = [(0.0, 1.0), (.06, .995), (.13, .97), (.22, .86), (.32, .66), (.43, .52), (.55, .47), (.64, .43), (.88, .24), (.91, .2), (1.0, .2)];
    const sy = [(0.0, 1.0), (.06, .99), (.13, .93), (.22, .56), (.32, .36), (.43, .25), (.55, .22), (.64, .21), (.88, .115), (.91, .097), (1.0, .097)];
    const ty = [(0.0, 0.0), (.55, 0.0), (.64, -70.0), (.88, 334.0), (.91, 354.0), (1.0, 354.0)];
    const op = [(0.0, 1.0), (.88, 1.0), (.91, 0.0), (1.0, 0.0)];
    final opacity = _kf(op, t);
    if (opacity <= 0) return;

    // Polígono interpolado
    var i = 1;
    while (i < _crumplePolys.length - 1 && t > _crumplePolys[i].$1) {
      i++;
    }
    final a = _crumplePolys[i - 1], b = _crumplePolys[i];
    final f = ((t - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
    final path = Path();
    for (var k = 0; k < 24; k += 2) {
      final x = ui.lerpDouble(a.$2[k], b.$2[k], f)! / 100 * size.width;
      final y = ui.lerpDouble(a.$2[k + 1], b.$2[k + 1], f)! / 100 * size.height;
      k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy + _kf(ty, t));
    canvas.rotate(_kf(rot, t) * math.pi / 180);
    canvas.scale(_kf(sx, t), _kf(sy, t));
    canvas.translate(-c.dx, -c.dy);
    canvas.clipPath(path);

    // Shader: desplazamiento + pliegues; progreso = easeOutCubic(min(1, ms/1250))
    final p = math.min(1.0, t * 2200 / 1250);
    final e = 1 - math.pow(1 - p, 3).toDouble();
    final shader = crumpleProgram.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, e)
      ..setImageSampler(0, image);
    // Sombra dura bajo la bola (drop-shadow del prototipo)
    canvas.drawPath(path.shift(const Offset(4, 5)), Paint()..color = ink.withValues(alpha: .9 * opacity));
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CrumplePainter old) => old.t != t || old.image != image;
}

class _Trash extends StatelessWidget {
  const _Trash({required this.t});
  final double t;
  @override
  Widget build(BuildContext context) {
    final opacity = _kf(const [(0.0, 0.0), (.18, 0.0), (.30, 1.0), (.94, 1.0), (1.0, 0.0)], t);
    final dy = _kf(const [(0.0, 24.0), (.18, 24.0), (.30, 0.0), (.94, 0.0), (1.0, 10.0)], t);
    final lid = _kf(const [(0.0, 0.0), (.52, 0.0), (.62, 38.0), (.86, 38.0), (.91, -6.0), (.95, 0.0), (1.0, 0.0)], t);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 30,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Transform.rotate(
              angle: lid * math.pi / 180,
              alignment: Alignment.bottomRight,
              child: Container(width: 64, height: 10, color: ink),
            ),
            const SizedBox(height: 4),
            Container(width: 52, height: 60, decoration: BoxDecoration(border: Border.all(color: ink, width: 4))),
          ]),
        ),
      ),
    );
  }
}

/// La nota se parte en dos con un borde irregular y cada mitad cae (tearL / tearR).
class TearPainter extends CustomPainter {
  TearPainter(this.image, this.t);
  final ui.Image image;
  final double t;

  static final List<double> _edge = () {
    final r = math.Random(20250922);
    return List<double>.generate(41, (i) => 47.5 + r.nextDouble() * 5.5);
  }();

  Path _half(Size s, {required bool left, double offset = 0}) {
    final p = Path()..moveTo(left ? 0 : s.width, 0);
    for (var i = 0; i < _edge.length; i++) {
      p.lineTo((_edge[i] + offset) / 100 * s.width, i / (_edge.length - 1) * s.height);
    }
    p
      ..lineTo(left ? 0 : s.width, s.height)
      ..close();
    return p;
  }

  void _drawHalf(Canvas canvas, Size size, {required bool left}) {
    final sign = left ? -1.0 : 1.0;
    final tx = _kf([(0.0, 0.0), (.08, 2 * sign), (.14, -1 * sign), (.38, 16 * sign), (1.0, 150 * sign)], t);
    final ty = _kf(const [(0.0, 0.0), (.38, 4.0), (1.0, 980.0)], t);
    final rot = _kf([(0.0, 0.0), (.08, .6 * sign), (.14, -.3 * sign), (.38, 7 * sign), (1.0, 34 * sign)], t);
    // easeIn en la caída (cubic-bezier(.55,0,1,.45) a partir del 38 %)
    final origin = Offset(size.width / 2, size.height);
    canvas.save();
    canvas.translate(tx, ty);
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(rot * math.pi / 180);
    canvas.translate(-origin.dx, -origin.dy);
    final face = _half(size, left: left);
    final fiber = _half(size, left: left, offset: left ? 1.3 : -1.3);
    canvas.drawPath(face.shift(const Offset(4, 6)), Paint()..color = ink.withValues(alpha: .85));
    canvas.drawPath(fiber, Paint()..color = const Color(0xFFFFFDF3));
    canvas.clipPath(face);
    paintImage(canvas: canvas, rect: Offset.zero & size, image: image, fit: BoxFit.fill);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawHalf(canvas, size, left: true);
    _drawHalf(canvas, size, left: false);
  }

  @override
  bool shouldRepaint(TearPainter old) => old.t != t;
}
