import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// Qué lleva la app de Android como icono (spec 018, T-018-03): el manifiesto,
/// los recursos de `res/` y las compilaciones `debug` y `profile`.
const _main = 'android/app/src/main';
const _res = '$_main/res';
const _fixtures = 'test/fixtures/flutter_template_icons';
const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

String _read(String path) => File(path).readAsStringSync();

List<File> _filesUnder(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().toList();

/// Luminancia relativa de WCAG de un `0xRRGGBB`.
double _luminance(int rgb) {
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((rgb >> 16) & 0xFF) +
      0.7152 * channel((rgb >> 8) & 0xFF) +
      0.0722 * channel(rgb & 0xFF);
}

double _contrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final manifest = _read('$_main/AndroidManifest.xml');

  group('CA-018-06: nada del icono de Flutter', () {
    test('CA-018-06: el manifiesto declara @mipmap/ic_launcher, que resuelve a un <adaptive-icon>', () {
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(manifest, isNot(contains('roundIcon')));
      final xml = File('$_res/mipmap-anydpi/ic_launcher.xml');
      expect(xml.existsSync(), isTrue);
      expect(xml.readAsStringSync(), contains('<adaptive-icon'));
    });

    test('CA-018-06: no queda ningún ic_launcher.png en res/ (ni con los bytes de la plantilla)', () {
      final pngs = _filesUnder(_res)
          .where((f) => RegExp(r'ic_launcher.*\.png$').hasMatch(f.path));
      for (final f in pngs) {
        expect(f.path, contains('drawable-nodpi/ic_launcher_foreground.png'));
      }
      final template = [
        for (final d in _densities)
          File('$_fixtures/android-$d.png').readAsBytesSync(),
      ];
      for (final f in _filesUnder(_res).where((f) => f.path.endsWith('.png'))) {
        final bytes = f.readAsBytesSync();
        for (final t in template) {
          expect(
            bytes.length == t.length && _same(bytes, t),
            isFalse,
            reason: '${f.path} es un icono de la plantilla',
          );
        }
      }
      for (final d in _densities) {
        expect(File('$_res/mipmap-$d/ic_launcher.png').existsSync(), isFalse);
      }
    });

    test('CA-018-06: no hay recursos de icono huérfanos y todo lo que referencia existe', () {
      final xml = _read('$_res/mipmap-anydpi/ic_launcher.xml');
      final refs = RegExp(r'@(color|drawable)/(\w+)')
          .allMatches(xml)
          .map((m) => m.group(0)!)
          .toSet();
      expect(refs, {
        '@color/ic_launcher_background',
        '@drawable/ic_launcher_foreground',
      });
      expect(
        File('$_res/drawable-nodpi/ic_launcher_foreground.png').existsSync(),
        isTrue,
      );
      expect(
        _read('$_res/values/ic_launcher_background.xml'),
        contains('name="ic_launcher_background"'),
      );
      // Todo archivo de res/ con «ic_launcher» en el nombre es uno de los tres.
      final icons =
          _filesUnder(_res)
              .map((f) => f.path.substring(_res.length + 1))
              .where((p) => p.contains('ic_launcher'))
              .toList()
            ..sort();
      expect(icons, [
        'drawable-nodpi/ic_launcher_foreground.png',
        'mipmap-anydpi/ic_launcher.xml',
        'values/ic_launcher_background.xml',
      ]);
    });
  });

  group('CA-018-11: nombre y accesibilidad sin cambios', () {
    test('CA-018-11: el nombre sale de @string/app_name, generado de identity.yaml', () {
      expect(manifest, contains('android:label="@string/app_name"'));
      final strings = _read('$_res/values/strings.xml');
      expect(strings, contains('GENERADO por tool/gen_identity.dart'));
      final name = RegExp(r'displayName:\s*"([^"]*)"')
          .firstMatch(_read('identity.yaml'))!
          .group(1)!;
      expect(
        strings,
        contains('<string name="app_name" translatable="false">$name</string>'),
      );
    });

    test('CA-018-11: el contraste de la tinta sobre el amarillo es ≈ 14,9 : 1 (≥ 3 : 1)', () {
      final tokens = readIconTokens();
      final ratio = _contrast(tokens.ink, tokens.yellow);
      expect(ratio, greaterThanOrEqualTo(3));
      expect(ratio, closeTo(14.9, 0.1));
    });
  });

  group('CA-018-14: todas las compilaciones llevan el mismo icono', () {
    for (final variant in ['debug', 'profile']) {
      test(
        'CA-018-14: src/$variant no trae recursos ni referencias de icono',
        () {
          final dir = 'android/app/src/$variant';
          expect(Directory('$dir/res').existsSync(), isFalse);
          for (final f in _filesUnder(dir)) {
            final text = f.readAsStringSync();
            expect(text, isNot(contains('android:icon')), reason: f.path);
            expect(text, isNot(contains('ic_launcher')), reason: f.path);
          }
        },
      );
    }
  });
}

bool _same(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
