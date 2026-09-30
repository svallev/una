import 'package:app/data/licenses/flutter_license_source.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

LicenseEntry _entry(List<String> packages, String text) =>
    LicenseEntryWithLineBreaks(packages, text);

FlutterLicenseSource _source(List<LicenseEntry> entries) =>
    FlutterLicenseSource(entries: () => Stream.fromIterable(entries));

void main() {
  group('CA-012-03: FlutterLicenseSource agrupa por paquete', () {
    test(
      'un paquete con dos licencias distintas: dos textos, en orden',
      () async {
        final packages = await _source([
          _entry(['pdfrx'], 'MIT License\n\nPermission is granted'),
          _entry(['pdfrx'], 'BSD License\n\nRedistribution and use'),
        ]).load();

        expect(packages, hasLength(1));
        expect(packages.single.name, 'pdfrx');
        expect(packages.single.licenseCount, 2);
        expect(packages.single.texts.first.paragraphs.map((p) => p.text), [
          'MIT License',
          'Permission is granted',
        ]);
        expect(packages.single.texts.last.paragraphs.first.text, 'BSD License');
      },
    );

    test(
      'una licencia compartida por varios paquetes va en cada uno',
      () async {
        final packages = await _source([
          _entry(['a', 'b'], 'Same license'),
        ]).load();
        expect(packages.map((p) => p.name), ['a', 'b']);
        for (final p in packages) {
          expect(p.licenseCount, 1);
        }
      },
    );

    test('sin duplicados: el mismo texto dos veces cuenta una', () async {
      final packages = await _source([
        _entry(['a'], 'Same license'),
        _entry(['a'], 'Same license'),
        _entry(['a'], 'Other license'),
      ]).load();
      expect(packages.single.licenseCount, 2);
    });

    test('orden alfabético sin distinguir mayúsculas', () async {
      final packages = await _source([
        _entry(['zeta'], 'z'),
        _entry(['Beta'], 'b'),
        _entry(['alpha'], 'a'),
        _entry(['Archivo'], 'o'),
      ]).load();
      expect(packages.map((p) => p.name), ['alpha', 'Archivo', 'Beta', 'zeta']);
    });

    test('los nombres vacíos no crean una entrada', () async {
      final packages = await _source([
        _entry(['', '  ', 'real'], 'text'),
      ]).load();
      expect(packages.map((p) => p.name), ['real']);
    });

    test('conserva la sangría de los párrafos', () async {
      final packages = await _source([
        _entry(['a'], 'Title\n\n    indented paragraph\n\n${' ' * 12}Centered'),
      ]).load();
      final paragraphs = packages.single.texts.single.paragraphs;
      expect(paragraphs.first.indent, 0);
      // Flutter: 3 espacios = 1 nivel; más de 10 = centrado (-1).
      expect(paragraphs[1], (text: 'indented paragraph', indent: 1));
      expect(paragraphs[2], (text: 'Centered', indent: -1));
    });

    test(
      'sin ninguna licencia: lista vacía (lo trata el estado como error)',
      () async {
        expect(await _source(const []).load(), isEmpty);
      },
    );

    test('CA-012-15: si el registro falla, load() lanza el error', () async {
      final source = FlutterLicenseSource(
        entries: () async* {
          yield _entry(['a'], 'x');
          throw StateError('lectura fallida');
        },
      );
      await expectLater(source.load(), throwsStateError);
    });
  });

  test('CA-012-03: LicenseText compara por contenido', () {
    const a = LicenseText([(text: 'x', indent: 0)]);
    const b = LicenseText([(text: 'x', indent: 0)]);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const LicenseText([(text: 'x', indent: 1)])));
  });
}
