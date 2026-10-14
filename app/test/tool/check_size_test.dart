import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-size.sh` (CA-020-02 punto 7): el APK por ABI, comprimido, pesa menos de 25 MB. Es el
/// bucle que estaba en `ci.yml`, movido a un script para no repetirlo en el trabajo de publicación.
const _script = '../tools/check-size.sh';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('check_size_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  // Bytes que no se comprimen (el APK real ya va comprimido por dentro).
  File blob(String name, int bytes) {
    final rnd = Random(7);
    final data = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      data[i] = rnd.nextInt(256);
    }
    return File('${tmp.path}/$name')..writeAsBytesSync(data);
  }

  ProcessResult run(List<String> args) =>
      Process.runSync('bash', [_script, ...args]);

  test('CA-020-02: un APK pequeño pasa y dice cuánto pesa', () {
    final apk = blob('app-x86_64-release.apk', 1024);
    final r = run([apk.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('app-x86_64-release.apk'));
    expect(r.stdout, contains('comprimido'));
  });

  test('CA-020-02: más de 25 MB comprimido falla y nombra el APK', () {
    final apk = blob('app-arm64-v8a-release.apk', 26 * 1024 * 1024);
    final r = run([apk.path]);
    expect(r.exitCode, 1);
    expect('${r.stdout}${r.stderr}', contains('app-arm64-v8a-release.apk'));
    expect('${r.stdout}${r.stderr}', contains('25 MB'));
  });

  test('CA-020-02: --limit-mb cambia el umbral (para las pruebas)', () {
    final apk = blob('a.apk', 2 * 1024 * 1024);
    expect(run(['--limit-mb', '1', apk.path]).exitCode, 1);
    expect(run(['--limit-mb', '3', apk.path]).exitCode, 0);
  });

  test('CA-020-02: basta un APK grande entre varios para fallar', () {
    final small = blob('small.apk', 1024);
    final big = blob('big.apk', 2 * 1024 * 1024);
    final r = run(['--limit-mb', '1', small.path, big.path]);
    expect(r.exitCode, 1);
    expect('${r.stdout}${r.stderr}', contains('big.apk'));
  });

  test('CA-020-02: sin ningún APK (0 entradas) es un fallo, no un verde', () {
    final r = run(['--dir', tmp.path]);
    expect(r.exitCode, 1);
    expect('${r.stdout}${r.stderr}', contains('ningún APK'));
  });

  test('CA-020-02: --dir recorre los app-*-release.apk de la carpeta', () {
    blob('app-x86_64-release.apk', 1024);
    blob('app-debug.apk', 26 * 1024 * 1024); // no es de release: no cuenta
    final r = run(['--dir', tmp.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('app-x86_64-release.apk'));
    expect(r.stdout, isNot(contains('app-debug.apk')));
  });

  test('CA-020-02: un paquete que no existe es un fallo que lo nombra', () {
    final r = run(['${tmp.path}/no-existe.apk']);
    expect(r.exitCode, 1);
    expect('${r.stdout}${r.stderr}', contains('no-existe.apk'));
  });

  test('CA-020-02: una opción desconocida o un valor no numérico es un error de uso', () {
    expect(run(['--nada']).exitCode, 2);
    expect(run(['--limit-mb']).exitCode, 2);
    expect(run(['--limit-mb', 'x', 'a.apk']).exitCode, 2);
    expect(run(['--limit-mb', '0', 'a.apk']).exitCode, 2);
  });

  test('CA-020-02: ci.yml llama al script en lugar de repetir el bucle', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('tools/check-size.sh'));
    expect(ci, isNot(contains('gzip -9')));
  });
}
