import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// Las fuentes del tablero 17 (`design/prototype/assets/icon/`).
const _icon1024 = '../design/prototype/assets/icon/icon-1024.png';
const _foreground432 =
    '../design/prototype/assets/icon/adaptive-foreground-432.png';
const _monochrome432 =
    '../design/prototype/assets/icon/adaptive-monochrome-432.png';

/// Los PNG de la plantilla de Flutter que se retiran (T-018-01), guardados de
/// `HEAD` antes de borrar nada (CA-018-06).
const _fixtures = '/test/fixtures/flutter_template_icons';
const _fixtureSizes = {
  'android-mdpi': 48,
  'android-hdpi': 72,
  'android-xhdpi': 96,
  'android-xxhdpi': 144,
  'android-xxxhdpi': 192,
  'web-favicon': 16,
  'web-icon-192': 192,
  'web-icon-512': 512,
  'web-maskable-192': 192,
  'web-maskable-512': 512,
};

RgbaImage _image(int w, int h, void Function(int x, int y, List<int> px) f) {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final px = [0, 0, 0, 0];
      f(x, y, px);
      data.setRange((y * w + x) * 4, (y * w + x) * 4 + 4, px);
    }
  }
  return RgbaImage(w, h, data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tokens = readIconTokens();

  group('tokens', () {
    test('CA-018-03: lee palette.classic.0 y color.ink de tokens.json', () {
      expect(tokens.yellowHex, '#FFE55C');
      expect(tokens.inkHex, '#111111');
    });
  });

  group('readPngHeader', () {
    test('CA-018-01: lee ancho, alto y tipo de color de las fuentes', () {
      final fg = readPngHeader(File(_foreground432).readAsBytesSync());
      expect(
        (fg.width, fg.height, fg.bitDepth, fg.colorType),
        (432, 432, 8, 6),
      );
      expect(fg.hasAlphaChannel, isTrue);

      final original = readPngHeader(File(_icon1024).readAsBytesSync());
      expect((original.width, original.height), (1024, 1024));
      expect(original.colorType, 2, reason: 'el original es RGB, sin alfa');
      expect(original.hasAlphaChannel, isFalse);
    });

    test('CA-018-06: rechaza lo que no es un PNG', () {
      expect(
        () => readPngHeader(Uint8List.fromList(List.filled(40, 7))),
        throwsFormatException,
      );
      expect(() => readPngHeader(Uint8List(3)), throwsFormatException);
    });
  });

  group('measureFigure (sobre píxeles construidos a mano)', () {
    test('CA-018-01: caja, ancho relativo, centro y distancia máxima', () {
      // 10 × 10 con un rectángulo opaco de x 2–5 (4 de ancho) e y 3–4.
      final img = _image(10, 10, (x, y, px) {
        if (x >= 2 && x <= 5 && y >= 3 && y <= 4) px[3] = 255;
      });
      final m = measureFigure(img);
      expect((m.minX, m.minY, m.maxX, m.maxY), (2, 3, 5, 4));
      expect((m.boxWidth, m.boxHeight, m.pixels), (4, 2, 8));
      expect(m.widthRatio, closeTo(0.4, 1e-9));
      expect((m.centerX, m.centerY), (4.0, 4.0));
      expect((m.offsetX, m.offsetY), (-1.0, -1.0));
      // El píxel (2, 3) es el más lejano a (5, 5): su esquina exterior
      // (2, 3) queda a sqrt(3² + 2²).
      expect(m.maxDistance, closeTo(3.605551275, 1e-6));
    });

    test('CA-018-01: alfa 0 no cuenta y una imagen vacía lanza', () {
      final img = _image(4, 4, (x, y, px) => px[3] = 0);
      expect(() => measureFigure(img), throwsStateError);
    });

    test(
      'CA-018-01: la figura de un icono sin alfa se decide por el color',
      () {
        final bg = tokens.yellow;
        final img = _image(8, 8, (x, y, px) {
          final inside = x >= 1 && x <= 2 && y >= 1 && y <= 6;
          final c = inside ? tokens.ink : bg;
          px
            ..[0] = (c >> 16) & 0xFF
            ..[1] = (c >> 8) & 0xFF
            ..[2] = c & 0xFF
            ..[3] = 255;
        });
        final m = measureFigure(img, isFigure: differsFrom(bg));
        expect((m.boxWidth, m.boxHeight), (2, 6));
        // Con el alfa por defecto todo cuenta (todo es opaco).
        expect(measureFigure(img).boxWidth, 8);
      },
    );
  });

  group('deviationFromBlend', () {
    test('CA-018-03: 0 en los extremos y en una mezcla exacta', () {
      expect(deviationFromBlend(tokens.ink, tokens.yellow, tokens.ink), 0);
      expect(deviationFromBlend(tokens.yellow, tokens.yellow, tokens.ink), 0);
      // Mitad y mitad: (0xFF+0x11)/2 = 0x88; (0xE5+0x11)/2 = 0x7B; (0x5C+0x11)/2 = 0x36 (redondeos ±1).
      expect(
        deviationFromBlend(0x887B36, tokens.yellow, tokens.ink),
        lessThanOrEqualTo(1),
      );
    });

    test('CA-018-03: un color ajeno se aparta mucho', () {
      expect(
        deviationFromBlend(0x2040FF, tokens.yellow, tokens.ink),
        greaterThan(60),
      );
    });
  });

  group('sobre las fuentes del tablero 17', () {
    test('CA-018-01: primer plano de 432 px, x 135-296 e y 164-267', () async {
      final img = await loadRgba(_foreground432);
      expect((img.width, img.height), (432, 432));
      final m = measureFigure(img);
      expect((m.minX, m.maxX, m.minY, m.maxY), (135, 296, 164, 267));
      expect(m.boxWidth, 162);
      // 162 px = 40,5 dp = 56,25 % del círculo de 72 dp.
      expect(m.boxWidth / 4 / 72, closeTo(0.5625, 1e-9));
      expect(m.offsetX.abs(), lessThanOrEqualTo(1));
      expect(m.offsetY.abs(), lessThanOrEqualTo(1));
    });

    test('CA-018-02: primer plano, esquina más lejana a ≈ 24,1 dp', () async {
      final m = measureFigure(await loadRgba(_foreground432));
      expect(m.maxDistance / 4, closeTo(24.1, 0.3));
      expect(m.maxDistance / 4, lessThanOrEqualTo(33));
    });

    test(
      'CA-018-01: original de 1024, ancho 56,05 % y esquina a 33,3 %',
      () async {
        final img = await loadRgba(_icon1024);
        expect((img.width, img.height), (1024, 1024));
        final m = measureFigure(img, isFigure: differsFrom(tokens.yellow));
        expect(m.widthRatio * 100, closeTo(56.05, 0.1));
        expect(m.maxDistanceRatio * 100, closeTo(33.3, 0.1));
        expect(m.offsetX.abs(), lessThanOrEqualTo(1));
      },
    );

    test('CA-018-03: el primer plano solo lleva tinta (y alfa)', () async {
      final img = await loadRgba(_foreground432);
      final colors = colorCounts(img, minAlpha: 255);
      expect(colors.keys, [tokens.ink]);
      // También en el suavizado: el color queda a ±10 de la tinta.
      for (final c in colorCounts(img, minAlpha: 128).keys) {
        expect(
          deviationFromBlend(c, tokens.ink, tokens.ink),
          lessThanOrEqualTo(10),
        );
      }
    });

    test('CA-018-03: el original solo mezcla amarillo y tinta', () async {
      final img = await loadRgba(_icon1024);
      final colors = colorCounts(img);
      expect(colors.keys, containsAll([tokens.yellow, tokens.ink]));
      for (final c in colors.keys) {
        expect(
          deviationFromBlend(c, tokens.yellow, tokens.ink),
          lessThanOrEqualTo(10),
        );
      }
      // Sin alfa: todo opaco.
      expect(colorCounts(img, minAlpha: 255), colors);
    });

    test('CA-018-04: la capa monocroma del tablero existe y es 432 × 432', () {
      final h = readPngHeader(File(_monochrome432).readAsBytesSync());
      expect((h.width, h.height), (432, 432));
    });
  });

  group('fixtures de la plantilla de Flutter', () {
    test('CA-018-06: están los diez PNG, con el tamaño que tenían', () {
      for (final e in _fixtureSizes.entries) {
        final file = File('${Directory.current.path}$_fixtures/${e.key}.png');
        expect(file.existsSync(), isTrue, reason: e.key);
        final h = readPngHeader(file.readAsBytesSync());
        expect((h.width, h.height), (e.value, e.value), reason: e.key);
      }
      final present = Directory('${Directory.current.path}$_fixtures')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(present, {for (final k in _fixtureSizes.keys) '$k.png'});
    });
  });
}
