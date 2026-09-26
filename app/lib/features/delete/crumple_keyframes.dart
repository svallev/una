import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/animation.dart';

import '../../app/theme/tokens.g.dart';

/// Fotogramas clave del arrugado (spec 004, CA-004-04), copiados del prototipo
/// (`design/prototype/Main.dc.html`: `@keyframes crumple`, `lift`,
/// `facetsIn`, `shadeIn`, `trashIn`, `lid`, `thud`). Son datos de la
/// animación, como el CSS: los tiempos van en fracciones de
/// `motion.duration.crumple` (2,2 s) y las distancias en px del marco de
/// 390 × 844 (`size.frameWidth/Height`).
///
/// Sin la textura de ruido del filtro SVG del prototipo (`feTurbulence`):
/// decisión del propietario, primero sin ella (DEV-25).

/// Curva `ease` de CSS.
const _ease = Cubic(0.25, 0.1, 0.25, 1);

/// Un fotograma: momento (0–1) y curva del tramo que empieza en él (la de la
/// animación si no se indica, como en CSS).
class _Key<T> {
  const _Key(this.at, this.value, [this.curve]);
  final double at;
  final T value;
  final Curve? curve;
}

/// Interpola [keys] en [t] (0–1) con [lerp]; cada tramo usa su curva o
/// [base]. Antes del primero y después del último, se mantiene el valor.
T _sample<T>(
  List<_Key<T>> keys,
  double t,
  T Function(T a, T b, double f) lerp, {
  Curve base = Curves.linear,
}) {
  if (t <= keys.first.at) return keys.first.value;
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (t <= b.at) {
      final span = b.at - a.at;
      final f = span == 0 ? 1.0 : (t - a.at) / span;
      return lerp(a.value, b.value, (a.curve ?? base).transform(f));
    }
  }
  return keys.last.value;
}

double _lerpD(double a, double b, double f) => a + (b - a) * f;

/// Transformación de la nota: `translateY(y) rotate(deg) scale(sx, sy)`
/// alrededor del centro, y su opacidad.
class CrumpleTransform {
  const CrumpleTransform({
    this.translateY = 0,
    this.rotateDeg = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
  });

  /// En px del marco de 390 × 844.
  final double translateY;
  final double rotateDeg;
  final double scaleX;
  final double scaleY;
  final double opacity;

  static CrumpleTransform lerp(
    CrumpleTransform a,
    CrumpleTransform b,
    double f,
  ) => CrumpleTransform(
    translateY: _lerpD(a.translateY, b.translateY, f),
    rotateDeg: _lerpD(a.rotateDeg, b.rotateDeg, f),
    scaleX: _lerpD(a.scaleX, b.scaleX, f),
    scaleY: _lerpD(a.scaleY, b.scaleY, f),
    opacity: _lerpD(a.opacity, b.opacity, f),
  );

  /// Matriz para una nota de tamaño [size] (el desplazamiento se escala con
  /// la altura real frente a los 844 px del prototipo).
  Float64List matrix(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ty = translateY * size.height / UnaSizes.frameHeight;
    final r = rotateDeg * math.pi / 180;
    final c = math.cos(r);
    final s = math.sin(r);
    // p' = centro + (0, ty) + R·S·(p − centro), como `transform-origin:
    // 50% 50%` en CSS. Matriz 4×4 por columnas.
    final a = c * scaleX;
    final b = s * scaleX;
    final e = -s * scaleY;
    final d = c * scaleY;
    return Float64List.fromList([
      a, b, 0, 0, //
      e, d, 0, 0, //
      0, 0, 1, 0, //
      cx - a * cx - e * cy, cy + ty - b * cx - d * cy, 0, 1, //
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is CrumpleTransform &&
      other.translateY == translateY &&
      other.rotateDeg == rotateDeg &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(translateY, rotateDeg, scaleX, scaleY, opacity);

  @override
  String toString() =>
      'CrumpleTransform(y: $translateY, rot: $rotateDeg, '
      'scale: $scaleX×$scaleY, opacity: $opacity)';
}

/// Polígono de recorte de 12 puntos en fracciones (0–1) del ancho y el alto.
typedef _Poly = List<Offset>;

_Poly _p(List<double> xy) => [
  for (var i = 0; i < xy.length; i += 2) Offset(xy[i] / 100, xy[i + 1] / 100),
];

_Poly _lerpPoly(_Poly a, _Poly b, double f) => [
  for (var i = 0; i < a.length; i++) Offset.lerp(a[i], b[i], f)!,
];

const _inOut = Cubic(0.4, 0, 0.6, 1);
const _settle = Cubic(0.2, 0.6, 0.4, 1);
const _fall = Cubic(0.55, 0, 1, 0.45);

final _ball = _p([
  31, 31, 46, 29, 60, 30, 71, 36, 72, 47, 70, 60, //
  66, 69, 54, 71, 42, 70, 32, 66, 28, 55, 29, 42,
]);

final List<_Key<_Poly>> _clipKeys = [
  _Key(
    0,
    _p([
      0,
      0,
      33,
      0,
      67,
      0,
      100,
      0,
      100,
      33,
      100,
      67,
      100,
      100,
      67,
      100,
      33,
      100,
      0,
      100,
      0,
      67,
      0,
      33,
    ]),
    _inOut,
  ),
  _Key(
    0.06,
    _p([
      1,
      1,
      34,
      2,
      66,
      0,
      99,
      2,
      98,
      33,
      100,
      67,
      98,
      99,
      67,
      98,
      34,
      100,
      2,
      98,
      0,
      66,
      2,
      34,
    ]),
  ),
  _Key(
    0.13,
    _p([
      4,
      3,
      35,
      7,
      64,
      2,
      96,
      6,
      93,
      34,
      98,
      66,
      94,
      96,
      65,
      92,
      37,
      98,
      6,
      94,
      2,
      64,
      8,
      35,
    ]),
  ),
  _Key(
    0.22,
    _p([
      11,
      10,
      37,
      17,
      61,
      7,
      88,
      13,
      82,
      37,
      91,
      62,
      84,
      88,
      62,
      80,
      39,
      92,
      15,
      86,
      19,
      61,
      9,
      37,
    ]),
  ),
  _Key(
    0.32,
    _p([
      20,
      21,
      41,
      26,
      59,
      17,
      78,
      24,
      73,
      40,
      81,
      58,
      74,
      77,
      58,
      71,
      42,
      80,
      23,
      75,
      28,
      57,
      18,
      41,
    ]),
  ),
  _Key(
    0.43,
    _p([
      28,
      29,
      44,
      32,
      58,
      26,
      72,
      31,
      69,
      44,
      74,
      58,
      69,
      70,
      56,
      67,
      43,
      73,
      30,
      69,
      34,
      56,
      26,
      43,
    ]),
  ),
  _Key(0.55, _ball, _settle),
  _Key(0.64, _ball, _fall),
  _Key(0.88, _ball),
  _Key(1, _ball),
];

const List<_Key<CrumpleTransform>> _transformKeys = [
  _Key(0, CrumpleTransform(), _inOut),
  _Key(0.06, CrumpleTransform(rotateDeg: -0.4, scaleX: 0.995, scaleY: 0.99)),
  _Key(0.13, CrumpleTransform(rotateDeg: -1.5, scaleX: 0.97, scaleY: 0.93)),
  _Key(0.22, CrumpleTransform(rotateDeg: -3, scaleX: 0.86, scaleY: 0.56)),
  _Key(0.32, CrumpleTransform(rotateDeg: -6, scaleX: 0.66, scaleY: 0.36)),
  _Key(0.43, CrumpleTransform(rotateDeg: -11, scaleX: 0.52, scaleY: 0.25)),
  _Key(
    0.55,
    CrumpleTransform(rotateDeg: -18, scaleX: 0.47, scaleY: 0.22),
    _settle,
  ),
  _Key(
    0.64,
    CrumpleTransform(
      translateY: -70,
      rotateDeg: -70,
      scaleX: 0.43,
      scaleY: 0.21,
    ),
    _fall,
  ),
  _Key(
    0.88,
    CrumpleTransform(
      translateY: 334,
      rotateDeg: -240,
      scaleX: 0.24,
      scaleY: 0.115,
    ),
  ),
  _Key(
    0.91,
    CrumpleTransform(
      translateY: 354,
      rotateDeg: -250,
      scaleX: 0.2,
      scaleY: 0.097,
      opacity: 0,
    ),
  ),
  _Key(
    1,
    CrumpleTransform(
      translateY: 354,
      rotateDeg: -250,
      scaleX: 0.2,
      scaleY: 0.097,
      opacity: 0,
    ),
  ),
];

/// Sombra dura de la nota (`lift`): desplazamiento y opacidad de `ink`.
typedef CrumpleShadow = ({Offset offset, double alpha});

const List<_Key<CrumpleShadow>> _liftKeys = [
  _Key(0, (offset: Offset.zero, alpha: 0)),
  _Key(0.14, (offset: Offset(6, 8), alpha: 0.9)),
  _Key(0.55, (offset: Offset(4, 5), alpha: 0.9)),
  _Key(1, (offset: Offset(4, 5), alpha: 0.9)),
];

CrumpleShadow _lerpShadow(CrumpleShadow a, CrumpleShadow b, double f) => (
  offset: Offset.lerp(a.offset, b.offset, f)!,
  alpha: _lerpD(a.alpha, b.alpha, f),
);

/// `facetsIn` dura 1,2 s dentro de los 2,2 s.
const double _facetsSpan = 1200 / 2200;
const _facetsCurve = Cubic(0.3, 0, 0.3, 1);
const List<_Key<double>> _facetsKeys = [
  _Key(0, 0),
  _Key(0.25, 0.55),
  _Key(1, 1),
];

const List<_Key<double>> _shadeKeys = [
  _Key(0, 0),
  _Key(0.24, 0),
  _Key(0.55, 1),
  _Key(1, 1),
];

/// Papelera: `trashIn` (opacidad y subida), `lid` y `thud`.
typedef TrashPose = ({
  double opacity,
  double dy,
  double lidDeg,
  Offset lidShift,
  double canScaleX,
  double canScaleY,
});

const List<_Key<(double, double)>> _trashInKeys = [
  _Key(0, (0, 24)),
  _Key(0.18, (0, 24)),
  _Key(0.30, (1, 0)),
  _Key(0.94, (1, 0)),
  _Key(1, (0, 10)),
];

const List<_Key<(double, Offset)>> _lidKeys = [
  _Key(0, (0, Offset.zero)),
  _Key(0.52, (0, Offset.zero)),
  _Key(0.62, (38, Offset(4, -2))),
  _Key(0.86, (38, Offset(4, -2))),
  _Key(0.91, (-6, Offset.zero)),
  _Key(0.95, (0, Offset.zero)),
  _Key(1, (0, Offset.zero)),
];

const List<_Key<(double, double)>> _thudKeys = [
  _Key(0, (1, 1)),
  _Key(0.88, (1, 1)),
  _Key(0.91, (1.06, 0.92)),
  _Key(0.95, (0.97, 1.03)),
  _Key(0.98, (1, 1)),
  _Key(1, (1, 1)),
];

(double, double) _lerpPair((double, double) a, (double, double) b, double f) =>
    (_lerpD(a.$1, b.$1, f), _lerpD(a.$2, b.$2, f));

/// Estado de todo el arrugado en el instante [t] (0–1 de 2,2 s).
class CrumpleFrame {
  CrumpleFrame(double t)
    : t = t.clamp(0.0, 1.0),
      clip = _sample(_clipKeys, t, _lerpPoly),
      transform = _sample(_transformKeys, t, CrumpleTransform.lerp),
      shadow = _sample(_liftKeys, t, _lerpShadow),
      facetsOpacity = _sample(
        _facetsKeys,
        (t / _facetsSpan).clamp(0.0, 1.0),
        _lerpD,
        base: _facetsCurve,
      ),
      shadeOpacity = _sample(_shadeKeys, t, _lerpD),
      trash = _trashPose(t);

  final double t;

  /// Polígono de recorte (fracciones del ancho y el alto).
  final List<Offset> clip;
  final CrumpleTransform transform;
  final CrumpleShadow shadow;
  final double facetsOpacity;
  final double shadeOpacity;
  final TrashPose trash;

  /// El recorte en px para una nota de tamaño [size].
  Path clipPath(Size size) => Path()
    ..addPolygon([
      for (final p in clip) Offset(p.dx * size.width, p.dy * size.height),
    ], true);

  static TrashPose _trashPose(double t) {
    final (opacity, dy) = _sample(_trashInKeys, t, _lerpPair, base: _ease);
    final (lidDeg, lidShift) = _sample(
      _lidKeys,
      t,
      (a, b, f) => (_lerpD(a.$1, b.$1, f), Offset.lerp(a.$2, b.$2, f)!),
      base: _ease,
    );
    final (sx, sy) = _sample(_thudKeys, t, _lerpPair, base: _ease);
    return (
      opacity: opacity,
      dy: dy,
      lidDeg: lidDeg,
      lidShift: lidShift,
      canScaleX: sx,
      canScaleY: sy,
    );
  }
}

/// Malla de facetas del prototipo (`facetMesh`): 6 × 11 celdas sobre
/// 390 × 844, con la misma semilla, para que los pliegues sean los mismos.
class CrumpleFacet {
  const CrumpleFacet(this.points, this.fill, this.stroke);

  /// Vértices en fracciones (0–1) del ancho y el alto.
  final List<Offset> points;
  final Color fill;
  final Color stroke;
}

final List<CrumpleFacet> crumpleFacets = _facetMesh();

List<CrumpleFacet> _facetMesh() {
  var seed = 20250922;
  double rnd() {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  }

  const cols = 6;
  const rows = 11;
  const w = UnaSizes.frameWidth;
  const h = UnaSizes.frameHeight;
  final pts = <List<Offset>>[];
  for (var r = 0; r <= rows; r++) {
    final row = <Offset>[];
    for (var c = 0; c <= cols; c++) {
      final edge = r == 0 || r == rows || c == 0 || c == cols;
      final x =
          c * w / cols +
          (edge && (c == 0 || c == cols) ? 0 : (rnd() - 0.5) * w / cols * 0.8);
      final y =
          r * h / rows +
          (edge && (r == 0 || r == rows) ? 0 : (rnd() - 0.5) * h / rows * 0.8);
      // El prototipo redondea a una décima (toFixed(1)).
      row.add(
        Offset(
          double.parse(x.toStringAsFixed(1)) / w,
          double.parse(y.toStringAsFixed(1)) / h,
        ),
      );
    }
    pts.add(row);
  }
  final out = <CrumpleFacet>[];
  void tri(Offset a, Offset b, Offset c) {
    final v = rnd();
    final fill = v < 0.5
        ? UnaColors.ink.withValues(
            alpha: double.parse((0.03 + v * 0.2).toStringAsFixed(3)),
          )
        : UnaColors.surface.withValues(
            alpha: double.parse(((v - 0.5) * 0.7).toStringAsFixed(3)),
          );
    final stroke = UnaColors.ink.withValues(
      alpha: double.parse((0.08 + rnd() * 0.14).toStringAsFixed(3)),
    );
    out.add(CrumpleFacet([a, b, c], fill, stroke));
  }

  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final p00 = pts[r][c];
      final p10 = pts[r][c + 1];
      final p01 = pts[r + 1][c];
      final p11 = pts[r + 1][c + 1];
      if (rnd() < 0.5) {
        tri(p00, p10, p11);
        tri(p00, p11, p01);
      } else {
        tri(p00, p10, p01);
        tri(p10, p11, p01);
      }
    }
  }
  return out;
}
