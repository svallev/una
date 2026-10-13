import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El validador de tokens (`tools/validate-tokens.mjs`) corre con Node en la CI
/// (`docs`) y aquí se prueba con copias modificadas de `design/tokens.json`
/// (opción `--tokens`), sin tocar el repositorio.
void main() {
  final root = Directory.current.parent.path;
  final script = '$root/tools/validate-tokens.mjs';
  final tokensFile = '$root/design/tokens.json';
  late Directory tmp;

  setUpAll(() => tmp = Directory.systemTemp.createTempSync('una_tokens_'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  ProcessResult run({Map<String, String> color = const {}, String? name}) {
    final json = jsonDecode(File(tokensFile).readAsStringSync()) as Map;
    for (final e in color.entries) {
      final token = (json['color'] as Map<String, dynamic>)[e.key] as Map;
      token['\$value'] = e.value;
    }
    final copy = File('${tmp.path}/${name ?? 'tokens'}.json')
      ..writeAsStringSync(jsonEncode(json));
    return Process.runSync('node', [script, '--tokens', copy.path]);
  }

  final hasNode = Process.runSync('node', ['--version']).exitCode == 0;
  final skip = hasNode ? null : 'node no está instalado';

  test('CA-019-26: los tokens del repositorio pasan el validador', () {
    final r = run();
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }, skip: skip);

  // Los textos nuevos de Ajustes (línea de privacidad, ayuda con las horas y
  // aviso de bloqueo) van en textMuted sobre el papel, como CA-017-15.
  test(
    'CA-019-26: textMuted claro falla en la privacidad, la ayuda y el aviso',
    () {
      final r = run(color: {'textMuted': '#9A9890'});
      expect(r.exitCode, isNot(0));
      final err = '${r.stderr}';
      expect(err, contains('notificaciones/línea de privacidad'));
      expect(err, contains('notificaciones/ayuda con las horas'));
      expect(err, contains('notificaciones/aviso de bloqueo'));
    },
    skip: skip,
  );

  test('CA-019-26: el botón de enlace (tinta sobre el papel) lo comprueba el '
      'validador', () {
    final r = run(color: {'ink': '#8A8780'});
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('notificaciones/botón de enlace'));
  }, skip: skip);

  // CA-019-03: la marca de selección (tinta) frente al relleno amarillo de la
  // opción marcada y frente al papel de las demás, ≥ 3:1.
  test(
    'CA-019-03: la marca de selección contra el amarillo y contra el papel',
    () {
      final dark = run(color: {'switchOn': '#222222'});
      expect(dark.exitCode, isNot(0));
      expect(
        '${dark.stderr}',
        contains(
          'opciones al día/marca de selección (ink) / relleno de la '
          'opción marcada (switchOn)',
        ),
      );
      final light = run(color: {'paper': '#222222'});
      expect(light.exitCode, isNot(0));
      expect(
        '${light.stderr}',
        contains(
          'opciones al día/marca de selección (ink) / papel de las '
          'demás opciones',
        ),
      );
    },
    skip: skip,
  );

  test('CA-019-03: el número de la opción marcada es texto, ≥ 4,5:1 sobre el '
      'amarillo', () {
    final r = run(color: {'ink': '#8A8780'});
    expect(r.exitCode, isNot(0));
    expect(
      '${r.stderr}',
      contains('notificaciones/número de la opción marcada'),
    );
  }, skip: skip);
}
