import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// Icono adaptable de Android (spec 018, T-018-03): geometría, colores, capa
/// con tema y nitidez de los recursos. Mide con `dart:ui` (no con `tool/`).
const _res = 'android/app/src/main/res';
const _adaptiveXml = '$_res/mipmap-anydpi/ic_launcher.xml';
const _foregroundPng = '$_res/drawable-nodpi/ic_launcher_foreground.png';
const _backgroundXml = '$_res/values/ic_launcher_background.xml';

/// El lienzo adaptable es de 108 dp; el círculo visible, de 72; la zona
/// segura, de 66 (CA-018-01 y 02).
const _canvasDp = 108.0;
const _visibleDp = 72.0;
const _safeRadiusDp = 33.0;

String _read(String path) => File(path).readAsStringSync();

/// El valor de un atributo `android:<name>` de una etiqueta del XML.
String? _attr(String xml, String tag, String name) {
  final element = RegExp('<$tag\\b[^>]*>', dotAll: true).firstMatch(xml);
  if (element == null) return null;
  return RegExp('android:$name\\s*=\\s*"([^"]*)"')
      .firstMatch(element.group(0)!)
      ?.group(1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tokens = readIconTokens();

  group('CA-018-01: el icono en el lanzador', () {
    test(
      'CA-018-01: existe el icono adaptable y declara fondo y primer plano',
      () {
        final xml = _read(_adaptiveXml);
        expect(xml, contains('<adaptive-icon'));
        expect(
          _attr(xml, 'background', 'drawable'),
          '@color/ic_launcher_background',
        );
        expect(
          _attr(xml, 'foreground', 'drawable'),
          '@drawable/ic_launcher_foreground',
        );
      },
    );

    test('CA-018-01: la «u.» ocupa el 56 % del círculo de 72 dp (± 1 pp) y está centrada (± 1 dp)', () async {
      final image = await loadRgba(_foregroundPng);
      final m = measureFigure(image);
      final dpPerPx = _canvasDp / image.width;
      final widthRatio = m.boxWidth * dpPerPx / _visibleDp;
      expect(widthRatio, closeTo(0.56, 0.01));
      expect(m.offsetX * dpPerPx, closeTo(0, 1));
      expect(m.offsetY * dpPerPx, closeTo(0, 1));
    });
  });

  group('CA-018-02: entero con cualquier máscara', () {
    test(
      'CA-018-02: todo píxel opaco del primer plano está a ≤ 33 dp del centro',
      () async {
        final image = await loadRgba(_foregroundPng);
        final m = measureFigure(image);
        expect(
          m.maxDistance * _canvasDp / image.width,
          lessThanOrEqualTo(_safeRadiusDp),
        );
      },
    );

    test(
      'CA-018-02: el fondo es un color liso que llena los 108 dp (sin imagen)',
      () {
        final xml = _read(_adaptiveXml);
        expect(_attr(xml, 'background', 'drawable'), startsWith('@color/'));
        expect(File(_backgroundXml).existsSync(), isTrue);
        expect(
          _read(_backgroundXml),
          matches(
            RegExp(
              r'<color name="ic_launcher_background">#[0-9A-F]{6}</color>',
            ),
          ),
        );
      },
    );
  });

  group('CA-018-03: los colores salen de los tokens', () {
    test('CA-018-03: el fondo es exactamente palette.classic.0', () {
      final xml = _read(_backgroundXml);
      expect(
        xml,
        contains(
          '<color name="ic_launcher_background">${tokens.yellowHex}</color>',
        ),
      );
      expect(xml, contains('GENERADO'));
    });

    test('CA-018-03: el primer plano solo tiene tinta, transparencia y suavizado de tinta (± 10)', () async {
      final image = await loadRgba(_foregroundPng);
      // `dart:ui` premultiplica: con alfa bajo el color no sirve para comparar.
      final colors = colorCounts(image, minAlpha: 128);
      expect(colors, isNotEmpty);
      expect(colors.containsKey(tokens.ink), isTrue);
      for (final color in colors.keys) {
        expect(
          deviationFromBlend(color, tokens.ink, tokens.ink),
          lessThanOrEqualTo(10),
          reason: 'el color ${hexOf(color)} se aparta de la tinta',
        );
      }
      // Fuera de la figura todo es transparente: nada de fondo ni de sombra.
      final opaque = colorCounts(image, minAlpha: 255);
      expect(opaque.keys, contains(tokens.ink));
      expect(opaque.length, 1, reason: 'el relleno macizo es solo tinta');
    });
  });

  group('CA-018-04: icono con tema', () {
    test('CA-018-04: declara <monochrome> con el mismo drawable que el primer plano', () {
      final xml = _read(_adaptiveXml);
      expect(
        _attr(xml, 'monochrome', 'drawable'),
        '@drawable/ic_launcher_foreground',
      );
      expect(
        _attr(xml, 'monochrome', 'drawable'),
        _attr(xml, 'foreground', 'drawable'),
      );
    });

    test('CA-018-04: la silueta es maciza: alfa 255 en el cuerpo de la «u.» y en el punto', () async {
      final image = await loadRgba(_foregroundPng);
      // El punto está hacia x 256–296, y 227–265 (de 432): su centro, macizo.
      for (var y = 241; y <= 251; y++) {
        for (var x = 271; x <= 281; x++) {
          expect(image.alpha(x, y), 255, reason: 'punto en ($x, $y)');
        }
      }
      // Fuera de la figura, alfa 0 (esquinas y borde del lienzo).
      for (final (x, y) in [
        (0, 0),
        (431, 0),
        (0, 431),
        (431, 431),
        (216, 20),
      ]) {
        expect(image.alpha(x, y), 0, reason: 'fuera de la figura en ($x, $y)');
      }
    });

    test(
      'CA-018-04: solo el borde es semitransparente (el cuerpo es macizo)',
      () async {
        final image = await loadRgba(_foregroundPng);
        // Todo píxel con alfa parcial está a ≤ 3 px de uno con alfa 0: es el
        // suavizado del contorno; dentro de la figura no hay manchas.
        const radius = 3;
        var partial = 0;
        var opaque = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final a = image.alpha(x, y);
            if (a == 255) opaque++;
            if (a == 0 || a == 255) continue;
            partial++;
            var nearEmpty = false;
            for (var dy = -radius; dy <= radius && !nearEmpty; dy++) {
              for (var dx = -radius; dx <= radius; dx++) {
                final nx = x + dx;
                final ny = y + dy;
                if (nx < 0 ||
                    ny < 0 ||
                    nx >= image.width ||
                    ny >= image.height) {
                  continue;
                }
                if (image.alpha(nx, ny) == 0) {
                  nearEmpty = true;
                  break;
                }
              }
            }
            expect(
              nearEmpty,
              isTrue,
              reason: 'alfa parcial interior en ($x, $y)',
            );
          }
        }
        expect(
          opaque,
          greaterThan(partial),
          reason: 'la figura es mayormente maciza',
        );
      },
    );
  });

  group('CA-018-05: sin tema, o antes de Android 13', () {
    test('CA-018-05: la capa monocroma no es un recurso propio (el primer plano no depende de ella)', () {
      expect(File(_adaptiveXml).existsSync(), isTrue);
      final drawables = Directory(_res)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.contains('ic_launcher'))
          .toList();
      expect(drawables.where((p) => p.contains('monochrome')), isEmpty);
    });
  });

  group('CA-018-07: nítido a cualquier densidad', () {
    test('CA-018-07: el primer plano es cuadrado y de al menos 432 px (4 × 108 dp)', () {
      final header = readPngHeader(File(_foregroundPng).readAsBytesSync());
      expect(header.width, header.height);
      expect(header.width, greaterThanOrEqualTo(432));
      expect(header.hasAlphaChannel, isTrue);
    });
  });
}
