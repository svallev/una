import 'dart:convert';

import 'package:app/app/bundled_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un `AssetBundle` que apunta qué se pide y lo lee del real.
class _CountingBundle extends CachingAssetBundle {
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    return rootBundle.load(key);
  }
}

/// Todas las entradas del registro: `paquetes → textos`.
Future<Map<String, List<String>>> _collect() async {
  final byPackage = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    for (final package in entry.packages) {
      byPackage.putIfAbsent(package, () => []).add(text);
    }
  }
  return byPackage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test(
    'CA-012-03: las cinco entradas propias existen (fuentes, PDFium, SQLite y '
    'bibliotecas de Android) con su texto',
    () async {
      registerBundledLicenses();
      final byPackage = await _collect();

      expect(
        byPackage.keys,
        containsAll([
          'Archivo',
          'Space Mono',
          'PDFium',
          'SQLite',
          androidLibrariesLicenseName,
        ]),
      );
      expect(byPackage['Archivo']!.single, contains('SIL OPEN FONT LICENSE'));
      expect(
        byPackage['Space Mono']!.single,
        contains('SIL OPEN FONT LICENSE'),
      );

      // PDFium: la licencia propia y los avisos de sus terceros (varios
      // textos, cada uno con su título), y la línea de origen al principio.
      final pdfium = byPackage['PDFium']!;
      expect(pdfium.length, greaterThan(10));
      expect(pdfium.first, startsWith('Origin: github.com/bblanchon/'));
      expect(pdfium.first, contains('chromium/7811'));
      expect(pdfium.join('\n'), contains('The PDFium Authors'));
      expect(pdfium.join('\n'), contains('FreeType'));

      expect(byPackage['SQLite']!.single, contains('May you do good'));

      final android = byPackage[androidLibrariesLicenseName]!;
      expect(android.first, contains('androidx.core:core'));
      expect(android.first, contains('org.jetbrains.kotlin:kotlin-stdlib'));
      expect(android.last, contains('Apache License'));
      expect(android.last, contains('Version 2.0'));
    },
  );

  test(
    'CA-012-03: ningún texto queda vacío ni con separadores sueltos',
    () async {
      registerBundledLicenses();
      for (final entry in (await _collect()).entries) {
        for (final text in entry.value) {
          expect(text.trim(), isNotEmpty, reason: entry.key);
          expect(text, isNot(contains('=' * 80)), reason: entry.key);
        }
      }
    },
  );

  test('CA-012-16: no se lee ningún archivo hasta pedir las licencias '
      '(P2: nada antes del primer fotograma)', () async {
    final bundle = _CountingBundle();
    registerBundledLicenses(bundle: bundle);
    expect(bundle.loads, isEmpty);

    await LicenseRegistry.licenses.toList();
    expect(
      bundle.loads,
      containsAll([
        'assets/fonts/archivo/OFL.txt',
        'assets/fonts/space_mono/OFL.txt',
        'assets/licenses/pdfium.txt',
        'assets/licenses/sqlite.txt',
        'assets/licenses/android.txt',
      ]),
    );
  });

  test('CA-012-03: los assets son UTF-8 y no llevan caracteres de dirección '
      '(no se pueden usar para ocultar texto)', () async {
    for (final path in [
      'assets/licenses/pdfium.txt',
      'assets/licenses/sqlite.txt',
      'assets/licenses/android.txt',
    ]) {
      final bytes = (await rootBundle.load(path)).buffer.asUint8List();
      final text = utf8.decode(bytes); // lanza si no es UTF-8
      final bidi = text.runes.where(
        (r) =>
            r == 0x200e ||
            r == 0x200f ||
            (r >= 0x202a && r <= 0x202e) ||
            (r >= 0x2066 && r <= 0x2069),
      );
      expect(bidi, isEmpty, reason: path);
    }
  });
}
