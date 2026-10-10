import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// Un solo dibujo (spec 018, T-018-05, CA-018-10): el icono de Android, el de
/// Android con tema, el de Play y los de la web salen del mismo original. En
/// todos, la «u.» con el punto mide el 56 % de la dimensión visible (el círculo
/// de 72 dp en Android; el lado entero en las demás), su caja está centrada,
/// los colores son los tokens y no hay nada añadido.
///
/// Mide con `dart:ui`, aparte del generador (plan §1.4). Los números de
/// `docs/design/app-icon.md` (CA-018-15) son los que comprueba este archivo.
const _canvasDp = 108.0;
const _visibleDp = 72.0;

const _res = 'android/app/src/main/res';
const _adaptiveXml = '$_res/mipmap-anydpi/ic_launcher.xml';
const _foreground = '$_res/drawable-nodpi/ic_launcher_foreground.png';
const _original = '../design/prototype/assets/icon/icon-1024.png';
const _play = '../store/google-play/icon-512.png';

/// Rejilla de comparación de siluetas: divide 288 (72 dp a 4 px/dp), 1024, 512,
/// 192 y 32 sin resto.
const _grid = 32;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = readIconTokens();
  final yellowR = (tokens.yellow >> 16) & 0xFF;
  final inkR = (tokens.ink >> 16) & 0xFF;

  /// Cobertura de tinta de un píxel de un icono **opaco** (Play, web, original):
  /// 0 en el amarillo, 1 en la tinta, por el canal rojo (los dos tokens se
  /// distinguen sin ambigüedad en él: 0xFF y 0x11).
  double opaqueCoverage(RgbaImage im, int x, int y) =>
      ((yellowR - im.red(x, y)) / (yellowR - inkR)).clamp(0.0, 1.0);

  Future<RgbaImage> load(String path) => loadRgba(path);

  /// Recorta el cuadrado del círculo visible (72 dp) de un lienzo de 108 dp.
  RgbaImage cropVisible(RgbaImage canvas) {
    final side = (canvas.width * _visibleDp / _canvasDp).round();
    final offset = (canvas.width - side) ~/ 2;
    final out = Uint8List(side * side * 4);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final from = ((y + offset) * canvas.width + x + offset) * 4;
        out.setRange(
          (y * side + x) * 4,
          (y * side + x) * 4 + 4,
          canvas.data,
          from,
        );
      }
    }
    return RgbaImage(side, side, out);
  }

  /// Silueta en una rejilla de [_grid] x [_grid]: cobertura media de tinta por
  /// celda.
  List<double> silhouette(
    RgbaImage im,
    double Function(RgbaImage, int, int) coverage,
  ) {
    final cell = im.width ~/ _grid;
    expect(cell * _grid, im.width, reason: 'la rejilla no divide ${im.width}');
    return [
      for (var gy = 0; gy < _grid; gy++)
        for (var gx = 0; gx < _grid; gx++)
          () {
            var sum = 0.0;
            for (var y = gy * cell; y < (gy + 1) * cell; y++) {
              for (var x = gx * cell; x < (gx + 1) * cell; x++) {
                sum += coverage(im, x, y);
              }
            }
            return sum / (cell * cell);
          }(),
    ];
  }

  /// Cuántos grupos de píxeles de figura conectados (4 vecinos) hay: la «u.» y
  /// su punto, nada más.
  int components(RgbaImage im, FigurePredicate isFigure) {
    final seen = List<bool>.filled(im.width * im.height, false);
    var count = 0;
    bool figure(int x, int y) =>
        isFigure(im.red(x, y), im.green(x, y), im.blue(x, y), im.alpha(x, y));
    for (var y0 = 0; y0 < im.height; y0++) {
      for (var x0 = 0; x0 < im.width; x0++) {
        if (seen[y0 * im.width + x0] || !figure(x0, y0)) continue;
        count++;
        final stack = [(x0, y0)];
        seen[y0 * im.width + x0] = true;
        while (stack.isNotEmpty) {
          final (x, y) = stack.removeLast();
          for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= im.width || ny >= im.height) continue;
            if (seen[ny * im.width + nx] || !figure(nx, ny)) continue;
            seen[ny * im.width + nx] = true;
            stack.add((nx, ny));
          }
        }
      }
    }
    return count;
  }

  // Las cuatro versiones (más el original, que es la referencia): nombre,
  // cómo se carga la parte visible y de qué tamaño de punto es un píxel
  // (tolerancia del ancho relativo).
  final versions =
      <({String name, String path, bool android, int side, double tol})>[
        (
          name: 'Android (primer plano)',
          path: _foreground,
          android: true,
          side: 288,
          tol: 0.01,
        ),
        (name: 'Play 512', path: _play, android: false, side: 512, tol: 0.01),
        (
          name: 'web Icon-512',
          path: 'web/icons/Icon-512.png',
          android: false,
          side: 512,
          tol: 0.01,
        ),
        (
          name: 'web Icon-192',
          path: 'web/icons/Icon-192.png',
          android: false,
          side: 192,
          tol: 0.01,
        ),
        (
          name: 'web Icon-maskable-512',
          path: 'web/icons/Icon-maskable-512.png',
          android: false,
          side: 512,
          tol: 0.01,
        ),
        (
          name: 'web Icon-maskable-192',
          path: 'web/icons/Icon-maskable-192.png',
          android: false,
          side: 192,
          tol: 0.01,
        ),
        // Un píxel del favicon es el 3 % del lado.
        (
          name: 'web favicon',
          path: 'web/favicon.png',
          android: false,
          side: 32,
          tol: 0.035,
        ),
      ];

  group('CA-018-10: el ancho y el centrado son los mismos en todas las versiones', () {
    test(
      'CA-018-10: el original (la referencia) mide el 56 % y está centrado',
      () async {
        final im = await load(_original);
        final m = measureFigure(
          im,
          isFigure: differsFrom(tokens.yellow, tolerance: 64),
        );
        expect(m.widthRatio, closeTo(0.56, 0.01));
        expect(m.offsetX.abs() / im.width, lessThan(0.005));
        expect(m.offsetY.abs() / im.width, lessThan(0.005));
      },
    );

    for (final v in versions) {
      test(
        'CA-018-10: ${v.name}: ancho 56 % ± ${(v.tol * 100).toStringAsFixed(1)} pp de la dimensión visible, caja centrada',
        () async {
          var im = await load(v.path);
          FigureMeasure m;
          if (v.android) {
            // La dimensión visible es el círculo de 72 dp del lienzo de 108.
            m = measureFigure(im);
            final dpPerPx = _canvasDp / im.width;
            expect(m.boxWidth * dpPerPx / _visibleDp, closeTo(0.56, v.tol));
            expect(m.offsetX * dpPerPx, closeTo(0, 1));
            expect(m.offsetY * dpPerPx, closeTo(0, 1));
            im = cropVisible(im);
            expect(im.width, v.side);
          } else {
            expect(im.width, v.side);
            m = measureFigure(
              im,
              isFigure: differsFrom(tokens.yellow, tolerance: 64),
            );
            expect(m.widthRatio, closeTo(0.56, v.tol));
            expect(
              m.offsetX.abs() / im.width,
              lessThanOrEqualTo(v.tol / 2 + 0.005),
            );
            expect(
              m.offsetY.abs() / im.width,
              lessThanOrEqualTo(v.tol / 2 + 0.005),
            );
          }
        },
      );
    }

    test(
      'CA-018-10: la altura relativa de la caja es la misma en todas (± 1 pp)',
      () async {
        final original = await load(_original);
        final ref =
            measureFigure(
              original,
              isFigure: differsFrom(tokens.yellow, tolerance: 64),
            ).boxHeight /
            original.width;
        for (final v in versions) {
          if (v.side == 32) continue;
          final im = await load(v.path);
          final double height;
          if (v.android) {
            final m = measureFigure(im);
            height = m.boxHeight * (_canvasDp / im.width) / _visibleDp;
          } else {
            final m = measureFigure(
              im,
              isFigure: differsFrom(tokens.yellow, tolerance: 64),
            );
            height = m.boxHeight / im.width;
          }
          expect(height, closeTo(ref, 0.01), reason: v.name);
        }
      },
    );
  });

  group('CA-018-10: mismos colores', () {
    test(
      'CA-018-10: Android: fondo = palette.classic.0 y primer plano solo tinta',
      () async {
        final xml = File('$_res/values/ic_launcher_background.xml')
            .readAsStringSync();
        expect(xml, contains('>${tokens.yellowHex}<'));
        final fg = await load(_foreground);
        final colors = colorCounts(fg, minAlpha: 128);
        for (final c in colors.keys) {
          expect(
            deviationFromBlend(c, tokens.ink, tokens.ink),
            lessThanOrEqualTo(10),
          );
        }
      },
    );

    for (final v in versions.where((v) => !v.android)) {
      test(
        'CA-018-10: ${v.name}: solo el amarillo, la tinta y su suavizado',
        () async {
          final im = await load(v.path);
          for (final c in colorCounts(im).keys) {
            expect(
              deviationFromBlend(c, tokens.yellow, tokens.ink),
              lessThanOrEqualTo(10),
              reason: '${v.name}: ${hexOf(c)}',
            );
          }
          final counts = colorCounts(im);
          expect(counts.keys, contains(tokens.yellow));
          expect(counts.keys, contains(tokens.ink));
        },
      );
    }

    test('CA-018-10: la manifest de la web y el icono comparten color (palette.classic.0)', () {
      final manifest = File('web/manifest.json')
          .readAsStringSync()
          .toUpperCase();
      expect(RegExp(tokens.yellowHex).allMatches(manifest).length, 2);
    });
  });

  group('CA-018-10: con tema', () {
    test('CA-018-10: la capa monocroma es el mismo recurso que el primer plano (mismo dibujo, tamaño y posición)', () {
      final xml = File(_adaptiveXml).readAsStringSync();
      String? drawable(String tag) =>
          RegExp('<$tag\\b[^>]*android:drawable\\s*=\\s*"([^"]*)"')
              .firstMatch(xml)
              ?.group(1);
      expect(drawable('monochrome'), isNotNull);
      expect(drawable('monochrome'), drawable('foreground'));
      expect(drawable('foreground'), '@drawable/ic_launcher_foreground');
    });
  });

  group('CA-018-10: sin elementos añadidos', () {
    test('CA-018-10: cada versión tiene exactamente dos piezas (la «u.» y el punto)', () async {
      for (final v in versions.where((v) => v.side >= 192)) {
        final im = await load(v.path);
        final n = v.android
            ? components(im, (r, g, b, a) => a >= 128)
            : components(im, differsFrom(tokens.yellow, tolerance: 128));
        expect(n, 2, reason: '${v.name}: $n piezas');
      }
      final original = await load(_original);
      expect(
        components(original, differsFrom(tokens.yellow, tolerance: 128)),
        2,
      );
    });

    test('CA-018-10: la silueta de cada versión coincide con la del original (rejilla de 32 x 32)', () async {
      final original = await load(_original);
      final ref = silhouette(original, opaqueCoverage);
      for (final v in versions) {
        var im = await load(v.path);
        final List<double> s;
        if (v.android) {
          im = cropVisible(im);
          s = silhouette(im, (i, x, y) => i.alpha(x, y) / 255);
        } else {
          s = silhouette(im, opaqueCoverage);
        }
        var sum = 0.0;
        var worst = 0.0;
        for (var i = 0; i < s.length; i++) {
          final d = (s[i] - ref[i]).abs();
          sum += d;
          if (d > worst) worst = d;
        }
        final mean = sum / s.length;
        // El favicon es el original reducido 32 veces: es un píxel por celda.
        expect(
          mean,
          lessThan(v.side == 32 ? 0.03 : 0.006),
          reason: '${v.name}: media $mean',
        );
        expect(
          worst,
          lessThan(v.side == 32 ? 0.35 : 0.12),
          reason: '${v.name}: máx $worst',
        );
      }
    });
  });
}
