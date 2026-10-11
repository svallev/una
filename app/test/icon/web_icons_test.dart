import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// La web de pruebas (spec 018, T-018-04, CA-018-09): favicon, iconos, color
/// del manifiesto y sin la descripción de plantilla. Las ayudas decodifican con
/// `dart:ui`, aparte del generador. Las plantillas de Flutter, de los fixtures.
const _web = 'web';
const _fixtures = 'test/fixtures/flutter_template_icons';

const _icons = {
  'favicon.png': (32, 'web-favicon.png'),
  'icons/Icon-192.png': (192, 'web-icon-192.png'),
  'icons/Icon-512.png': (512, 'web-icon-512.png'),
  'icons/Icon-maskable-192.png': (192, 'web-maskable-192.png'),
  'icons/Icon-maskable-512.png': (512, 'web-maskable-512.png'),
};

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, dynamic> _manifest() =>
    jsonDecode(File('$_web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = readIconTokens();

  group('CA-018-09: iconos', () {
    for (final entry in _icons.entries) {
      final path = '$_web/${entry.key}';
      final (size, fixture) = entry.value;

      test(
        'CA-018-09: $path mide $size x $size, es RGBA/RGB de 8 bits y no es el de la plantilla',
        () {
          final bytes = File(path).readAsBytesSync();
          final header = readPngHeader(bytes);
          expect(header.width, size);
          expect(header.height, size);
          expect(header.bitDepth, 8);
          final template = File('$_fixtures/$fixture').readAsBytesSync();
          expect(
            _sameBytes(bytes, template),
            isFalse,
            reason: '$path sigue siendo el icono de la plantilla',
          );
        },
      );

      test(
        'CA-018-09: $path tiene las esquinas amarillas, solo colores del icono y la figura al 56 %',
        () async {
          final image = await loadRgba(path);
          final last = size - 1;
          for (final (x, y) in [(0, 0), (last, 0), (0, last), (last, last)]) {
            expect(image.rgb(x, y), tokens.yellow, reason: 'esquina ($x, $y)');
            expect(image.alpha(x, y), 255);
          }
          for (final c in colorCounts(image).keys) {
            expect(
              deviationFromBlend(c, tokens.yellow, tokens.ink),
              lessThanOrEqualTo(10),
              reason: '${hexOf(c)} no es del icono',
            );
          }
          final m = measureFigure(
            image,
            isFigure: differsFrom(tokens.yellow, tolerance: 64),
          );
          // El favicon tiene un píxel = 3 puntos porcentuales.
          final tolerance = size == 32 ? 0.035 : 0.015;
          expect(m.widthRatio, closeTo(0.56, tolerance));
          expect(
            m.offsetX.abs() / size,
            lessThanOrEqualTo(tolerance / 2 + 0.005),
          );
          expect(
            m.offsetY.abs() / size,
            lessThanOrEqualTo(tolerance / 2 + 0.005),
          );
        },
      );
    }

    for (final name in ['Icon-maskable-192.png', 'Icon-maskable-512.png']) {
      test(
        'CA-018-09: en $name la esquina más lejana de la «u.» queda a <= 40 % del lado',
        () async {
          final image = await loadRgba('$_web/icons/$name');
          final m = measureFigure(
            image,
            isFigure: differsFrom(tokens.yellow, tolerance: 64),
          );
          expect(m.maxDistanceRatio, lessThanOrEqualTo(0.40));
          expect(m.maxDistanceRatio, closeTo(0.333, 0.02));
        },
      );
    }

    test('CA-018-09: el manifiesto declara los cuatro iconos y existen', () {
      final icons = (_manifest()['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons.map((i) => i['src']), [
        'icons/Icon-192.png',
        'icons/Icon-512.png',
        'icons/Icon-maskable-192.png',
        'icons/Icon-maskable-512.png',
      ]);
      for (final i in icons) {
        expect(File('$_web/${i['src']}').existsSync(), isTrue);
      }
    });
  });

  group('CA-018-09: color y textos del manifiesto', () {
    test('CA-018-09: theme_color y background_color son palette.classic.0', () {
      final manifest = _manifest();
      expect(
        (manifest['theme_color'] as String).toUpperCase(),
        tokens.yellowHex,
      );
      expect(
        (manifest['background_color'] as String).toUpperCase(),
        tokens.yellowHex,
      );
    });

    test('CA-018-09: sin descripción de plantilla en el manifiesto ni en la página', () {
      expect(_manifest().containsKey('description'), isFalse);
      final index = File('$_web/index.html').readAsStringSync();
      expect(index, isNot(contains('name="description"')));
    });

    test('CA-018-09: no queda 0175C2 ni «A new Flutter» en app/web', () {
      final files = Directory(_web).listSync(recursive: true).whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.png')) continue;
        final text = f.readAsStringSync();
        expect(text.toUpperCase(), isNot(contains('0175C2')), reason: f.path);
        expect(text, isNot(contains('A new Flutter')), reason: f.path);
      }
    });

    test('CA-018-09: nada más cambia: nombre de la identidad, start_url, display y orientación', () {
      final identity = File('identity.yaml').readAsStringSync();
      final name = RegExp(
        r'^displayName:\s*"([^"]+)"',
        multiLine: true,
      ).firstMatch(identity)!.group(1);
      final manifest = _manifest();
      expect(manifest['name'], name);
      expect(manifest['short_name'], name);
      expect(manifest['start_url'], '.');
      expect(manifest['display'], 'standalone');
      expect(manifest['orientation'], 'portrait-primary');
      expect(manifest['prefer_related_applications'], isFalse);
      final index = File('$_web/index.html').readAsStringSync();
      expect(
        index,
        contains('<meta name="apple-mobile-web-app-title" content="$name">'),
      );
      expect(
        index,
        contains('<link rel="icon" type="image/png" href="favicon.png"/>'),
      );
    });
  });
}
