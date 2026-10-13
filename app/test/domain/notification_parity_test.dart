import 'dart:io';

import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/services/host_display.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 019, T-019-05: lo que se repite entre Dart y el Kotlin que corre con la
/// app cerrada (plan §5). Las rutas son relativas a `app/` (el directorio de
/// `flutter test`). Los archivos de casos son de texto plano y los lee también
/// JUnit (`HostDisplayTest.kt`, `TaskLabelTest.kt`).
const _fixtures = 'test/fixtures/notifications';
const _kotlin = 'android/app/src/main/kotlin/invalid/pending/app/notifications';

/// Desescapa `\uXXXX`, `\\`, `\t`, `\n` y `\r` (el mismo formato que Kotlin).
String _unescape(String s) =>
    s.replaceAllMapped(RegExp(r'\\(u[0-9a-fA-F]{4}|\\|t|n|r)'), (m) {
      final e = m[1]!;
      return switch (e[0]) {
        'u' => String.fromCharCode(int.parse(e.substring(1), radix: 16)),
        't' => '\t',
        'n' => '\n',
        'r' => '\r',
        _ => '\\',
      };
    });

String? _nullable(String raw) => raw == '<null>' ? null : _unescape(raw);

/// Las líneas con datos de un archivo de casos, con su número de línea.
List<(int, List<String>)> _cases(String name, int columns) {
  final lines = File('$_fixtures/$name').readAsLinesSync();
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].isNotEmpty && !lines[i].startsWith('#'))
        (i + 1, lines[i].split('\t')),
  ].map((c) {
    if (c.$2.length != columns) {
      throw StateError('$name:${c.$1} no tiene $columns columnas');
    }
    return c;
  }).toList();
}

void main() {
  group(
    'CA-019-16: HostDisplay (Kotlin) = displayHost / webAddressHost (Dart)',
    () {
      final cases = _cases('hosts.txt', 3);

      test('el archivo de casos tiene de los tres tipos', () {
        final kinds = cases.map((c) => c.$2[0]).toSet();
        expect(kinds, {'host', 'hostWww', 'url'});
        expect(cases.length, greaterThan(30));
      });

      for (final (line, c) in cases) {
        test('hosts.txt:$line ${c[0]} ${c[1]}', () {
          final input = _nullable(c[1]);
          final expected = _nullable(c[2]);
          final actual = switch (c[0]) {
            'host' => displayHost(input!),
            'hostWww' => displayHost(input!, dropWww: true),
            'url' => webAddressHost(input),
            _ => fail('tipo desconocido ${c[0]}'),
          };
          expect(actual, expected);
        });
      }
    },
  );

  group('CA-019-16: el dominio esperado de labels.txt es el de la barra', () {
    for (final (line, c) in _cases('labels.txt', 4)) {
      final expected = c[3];
      if (!expected.startsWith('domain:')) continue;
      test('labels.txt:$line ${c[0]}', () {
        // La columna de adjuntos es «tipo,origen,dirección».
        final url = _nullable(c[2].split(',').skip(2).join(','));
        expect(webAddressHost(url), _unescape(expected.substring(7)));
      });
    }
  });

  group('CA-019-10: las tres horas de Kotlin = las de la ayuda de Ajustes', () {
    test('NotificationTimes.kt tiene 08:55, 13:55 y 18:55 como Dart', () {
      final source = File('$_kotlin/NotificationTimes.kt').readAsStringSync();
      final kotlin = [
        for (final m in RegExp(
          r'LocalTime\.of\((\d+),\s*(\d+)\)',
        ).allMatches(source))
          NotificationTime(int.parse(m[1]!), int.parse(m[2]!)),
      ];
      expect(kotlin, NotificationSchedule.times);
      expect(kotlin.map((t) => t.label), ['08:55', '13:55', '18:55']);
    });
  });
}
