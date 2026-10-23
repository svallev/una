import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-apk-locales.sh` (spec 024, CA-024-04, H-022-10): el APK de release tiene que traer
/// recursos propios en `ca`, `es` y el inglés por defecto. Se prueba con un `aapt2` de mentira que
/// imprime el contenido del «APK» (un archivo de texto con el volcado de `dump configurations`),
/// sin SDK ni compilar. El APK real lo vigila la CI tras `flutter build apk --release`.
const _script = '../tools/check-apk-locales.sh';

/// El volcado de la release de hoy (con `values-ca`): la línea vacía es `values/`.
const _good =
    '\nv27\nv28\nmdpi\nhdpi\nxhdpi\nxxhdpi\nxxxhdpi\nanydpi\nnodpi\nca\nes\n';

late Directory _tmp;
late String _fakeAapt2;

String _apk(String name, String dump) {
  final f = File('${_tmp.path}/$name.apk')..writeAsStringSync(dump);
  return f.path;
}

ProcessResult _run(List<String> args) =>
    Process.runSync('bash', [_script, '--aapt2', _fakeAapt2, ...args]);

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('check_apk_locales_');
    addTearDown(() => _tmp.deleteSync(recursive: true));
    _fakeAapt2 = '${_tmp.path}/aapt2';
    // `aapt2 dump configurations <apk>`: imprime el «APK».
    File(_fakeAapt2).writeAsStringSync('#!/bin/sh\ncat "\$3"\n');
    Process.runSync('chmod', ['+x', _fakeAapt2]);
  });

  test('CA-024-04: un APK con ca, es y el inglés por defecto pasa', () {
    final r = _run([_apk('ok', _good)]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect('${r.stdout}', contains('OK'));
  });

  test('CA-024-04: la línea vacía (inglés) puede ir al final del volcado', () {
    final r = _run([_apk('ok', 'ca\nes\nv27\n\n')]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
  });

  test('CA-024-04: sin ca falla y nombra el idioma (H-022-10)', () {
    final r = _run([_apk('sinca', _good.replaceAll('ca\n', ''))]);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains("'ca'"));
    expect('${r.stderr}', isNot(contains("'es'")));
  });

  test('CA-024-04: sin es falla y nombra el idioma', () {
    final r = _run([_apk('sines', _good.replaceAll('es\n', ''))]);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains("'es'"));
  });

  test('CA-024-04: sin la configuración por defecto (inglés) falla', () {
    final r = _run([_apk('sinen', 'v27\nca\nes\n')]);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('por defecto'));
  });

  test('CA-024-04: ca-rES y es-rES cuentan; v27 o un "cat" no', () {
    expect(_run([_apk('region', '\nca-rES\nes-rES\n')]).exitCode, 0);
    expect(_run([_apk('falso', '\ncat\nesp\nv27\n')]).exitCode, 1);
    // Una región sin idioma propio no es el idioma.
    expect(_run([_apk('solo', '\nv27-ca\nv27-es\n')]).exitCode, 1);
  });

  test(
    'CA-024-04: falla cerrada: sin APK, APK inexistente o volcado vacío',
    () {
      expect(_run(['${_tmp.path}/no-existe.apk']).exitCode, 1);
      expect(_run([_apk('vacio', '')]).exitCode, 1);
      // Sin ningún APK en los argumentos ni en app/build (o con ellos): no es un verde.
      final bad = Process.runSync('bash', [
        _script,
        '--aapt2',
        '${_tmp.path}/no-aapt2',
      ]);
      expect(bad.exitCode, 1);
      expect('${bad.stderr}', contains('aapt2'));
    },
  );

  test('CA-024-04: con varios APK, uno malo hace fallar al conjunto', () {
    final r = _run([_apk('a', _good), _apk('b', 'v27\nes\n')]);
    expect(r.exitCode, 1);
    expect('${r.stdout}', contains('a.apk'));
    expect('${r.stderr}', contains('b.apk'));
  });

  test('CA-024-04: un argumento desconocido es un error de uso (2)', () {
    expect(Process.runSync('bash', [_script, '--nope']).exitCode, 2);
  });
}
