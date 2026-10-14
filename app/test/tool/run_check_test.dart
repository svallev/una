import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/release/run-check.sh` (CA-020-02, plan §3.2): ejecuta una comprobación del trabajo de
/// publicación, guarda su salida y añade una línea `id<TAB>código<TAB>json` a `results.tsv`, sin
/// tragarse el código de salida (el paso del workflow lleva `continue-on-error`, así que su
/// `outcome` es el verdadero y el resumen puede cruzarlo con esa línea).
const _script = '../tools/release/run-check.sh';

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('run_check_');
    dir = '${tmp.path}/release';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run(List<String> args) {
    return Process.runSync(
      'bash',
      [_script, ...args],
      environment: {'RELEASE_DIR': dir},
    );
  }

  List<List<String>> rows() {
    final f = File('$dir/results.tsv');
    if (!f.existsSync()) return [];
    return f
        .readAsLinesSync()
        .map((l) => l.split('\t'))
        .toList(growable: false);
  }

  test('CA-020-02: un código 0 deja su línea y sale con 0', () {
    final r = run(['permissions', '--', 'bash', '-c', 'echo hola']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('hola'));
    expect(rows(), [
      ['permissions', '0', ''],
    ]);
  });

  test('CA-020-02: un código distinto de 0 se anota y se conserva', () {
    final r = run(['pdfium', '--', 'bash', '-c', 'echo roto; exit 3']);
    expect(r.exitCode, 3);
    expect(r.stdout, contains('roto'));
    expect(rows(), [
      ['pdfium', '3', ''],
    ]);
  });

  test('CA-020-02: un comando que no existe deja su línea con 127', () {
    final r = run(['licenses', '--', 'no-existe-este-comando-020']);
    expect(r.exitCode, 127);
    expect(rows(), [
      ['licenses', '127', ''],
    ]);
  });

  test('CA-020-02: guarda la salida de la comprobación en <id>.log', () {
    run(['size', '--', 'bash', '-c', 'echo uno; echo dos >&2']);
    final log = File('$dir/size.log').readAsStringSync();
    expect(log, contains('uno'));
    expect(log, contains('dos'));
  });

  test('CA-020-02: {json} se sustituye por la ruta y queda anotada', () {
    final r = run([
      'identity',
      '--',
      'bash',
      '-c',
      r'echo "{}" > "$1"',
      'x',
      '{json}',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(rows(), [
      ['identity', '0', '$dir/identity.json'],
    ]);
    expect(File('$dir/identity.json').readAsStringSync(), contains('{}'));
  });

  test(
    'CA-020-02: un JSON de una ejecución anterior se borra antes de empezar',
    () {
      Directory(dir).createSync(recursive: true);
      File('$dir/signature.json').writeAsStringSync('viejo');
      // La comprobación no escribe nada: no puede quedar el JSON de antes.
      run(['signature', '--', 'bash', '-c', 'exit 1', 'x', '{json}']);
      expect(File('$dir/signature.json').existsSync(), isFalse);
      expect(rows(), [
        ['signature', '1', '$dir/signature.json'],
      ]);
    },
  );

  test('CA-020-02: sin {json} no anota ninguna ruta', () {
    run(['tag', '--', 'bash', '-c', 'exit 0']);
    expect(rows().single[2], '');
  });

  test('CA-020-02: varias comprobaciones se añaden una tras otra', () {
    run(['permissions', '--', 'bash', '-c', 'exit 0']);
    run(['pdfium', '--', 'bash', '-c', 'exit 1']);
    run(['permissions', '--', 'bash', '-c', 'exit 0']);
    expect(rows().map((r) => '${r[0]}:${r[1]}'), [
      'permissions:0',
      'pdfium:1',
      'permissions:0', // un id repetido lo detecta el resumen, no el envoltorio
    ]);
  });

  test('CA-020-02: los argumentos con espacios llegan enteros', () {
    final r = run(['size', '--', 'bash', '-c', r'echo "[$1]"', 'x', 'a b  c']);
    expect(r.stdout, contains('[a b  c]'));
  });

  test(
    'CA-020-02: un id que no es minúsculas y guiones es un error de uso',
    () {
      for (final id in [
        'Permissions',
        '../x',
        'a b',
        '',
        'a;b',
        '1abc',
        '-x',
        'ok\nBAD', // the whole id, not line by line
      ]) {
        final r = run([id, '--', 'bash', '-c', 'exit 0']);
        expect(r.exitCode, 2, reason: 'id «$id»');
        expect(rows(), isEmpty, reason: 'id «$id»');
      }
    },
  );

  test('CA-020-02: sin «--» o sin comando es un error de uso', () {
    expect(run(['pdfium']).exitCode, 2);
    expect(run(['pdfium', '--']).exitCode, 2);
    expect(run(['pdfium', 'bash', '-c', 'exit 0']).exitCode, 2);
    expect(rows(), isEmpty);
  });

  test('CA-020-02: sin carpeta de resultados (ni RELEASE_DIR ni RUNNER_TEMP) falla', () {
    final r = Process.runSync(
      'bash',
      [_script, 'pdfium', '--', 'bash', '-c', 'exit 0'],
      environment: {'RELEASE_DIR': '', 'RUNNER_TEMP': ''},
    );
    expect(r.exitCode, 2);
    expect('${r.stdout}${r.stderr}', contains('RELEASE_DIR'));
  });

  test('CA-020-02: sin RELEASE_DIR usa RUNNER_TEMP/release', () {
    final r = Process.runSync(
      'bash',
      [_script, 'pdfium', '--', 'bash', '-c', 'exit 0'],
      environment: {'RELEASE_DIR': '', 'RUNNER_TEMP': tmp.path},
    );
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(File('${tmp.path}/release/results.tsv').existsSync(), isTrue);
  });
}
