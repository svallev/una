import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-size.sh` (CA-020-02 punto 7, enmendado por CA-023-20): el APK por ABI, comprimido, pesa
/// menos de 20 MB (antes 25). Es el bucle que estaba en `ci.yml`, movido a un script para no repetirlo
/// en el trabajo de publicación.
const _script = '../tools/check-size.sh';
const _mib = 1024 * 1024;

void main() {
  late Directory tmp;
  // Se genera una vez para todo el archivo (hasta 21 MB) y cada prueba toma un prefijo.
  var noise = Uint8List(0);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('check_size_');
  });
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

  // GITHUB_STEP_SUMMARY vacío: bajo la CI el script no debe escribir en el resumen real del trabajo.
  ProcessResult run(List<String> args, {String summary = ''}) =>
      Process.runSync(
        'bash',
        [_script, ...args],
        environment: {'GITHUB_STEP_SUMMARY': summary},
      );

  // Lo que mide el script: `gzip -9 -c <archivo>` (la cabecera lleva el nombre: se mide con el mismo).
  int gzSize(File f) {
    final r = Process.runSync('bash', [
      '-c',
      'gzip -9 -c "\$1" | wc -c',
      '_',
      f.path,
    ]);
    return int.parse((r.stdout as String).trim());
  }

  // Datos que no se comprimen, siempre los mismos (semilla fija): el prefijo de [n] bytes.
  Uint8List noiseOf(int n) {
    if (noise.length < n) {
      final rnd = Random(11);
      final b = Uint8List(n);
      final v = ByteData.sublistView(b);
      var i = 0;
      for (; i + 4 <= n; i += 4) {
        v.setUint32(i, rnd.nextInt(1 << 32));
      }
      for (; i < n; i++) {
        b[i] = rnd.nextInt(256);
      }
      noise = b;
    }
    return Uint8List.sublistView(noise, 0, n);
  }

  // Un APK cuyo tamaño comprimido es exactamente [target] bytes (la salida de `gzip -9`).
  File apkOfGzipSize(String name, int target) {
    final f = File('${tmp.path}/$name');
    var n = target;
    for (var i = 0; i < 12; i++) {
      f.writeAsBytesSync(noiseOf(n));
      final g = gzSize(f);
      if (g == target) return f;
      n += target - g;
    }
    fail('no se encontró un archivo de $target bytes comprimidos');
  }

  test('CA-020-02: un APK pequeño pasa y dice cuánto pesa', () {
    final apk = blob('app-x86_64-release.apk', 1024);
    final r = run([apk.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('app-x86_64-release.apk'));
    expect(r.stdout, contains('comprimido'));
  });

  test('CA-023-20: por defecto el límite es 20 MB: 21 MB falla y nombra el APK y el límite', () {
    final apk = blob('app-arm64-v8a-release.apk', 21 * _mib);
    final r = run([apk.path]);
    expect(r.exitCode, 1);
    expect('${r.stdout}${r.stderr}', contains('app-arm64-v8a-release.apk'));
    expect('${r.stderr}${r.stdout}', contains('20 MB'));
    expect('${r.stderr}${r.stdout}', isNot(contains('25 MB')));
  });

  test('CA-023-20: 19 MB pasan (con 25 MB de límite antes también pasaban 24: el umbral bajó)', () {
    final apk = blob('app-arm64-v8a-release.apk', 19 * _mib);
    final r = run([apk.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('CA-023-20: 20 MB menos 1 byte comprimido pasa; 20 MB exactos fallan; 20 MB más 1 byte, también', () {
    const limit = 20 * _mib;
    final below = apkOfGzipSize('app-x86_64-release.apk', limit - 1);
    expect(gzSize(below), limit - 1);
    final ok = run([below.path]);
    expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
    // Con un decimal truncado: 19,99… se enseña como 19,9, nunca como «20,0 MB» en un paquete que pasa.
    expect(ok.stdout, contains('19,9 MB comprimido'));

    final exact = apkOfGzipSize('app-x86_64-release.apk', limit);
    final at = run([exact.path]);
    expect(at.exitCode, 1);
    expect('${at.stdout}${at.stderr}', contains('20,0 MB'));

    final over = apkOfGzipSize('app-x86_64-release.apk', limit + 1);
    expect(run([over.path]).exitCode, 1);
  });

  test('CA-023-20: enseña el tamaño con un decimal (coma), truncado y no redondeado', () {
    // 13,96 MiB: truncado da 13,9; redondeado daría 14,0.
    final apk = blob('app-arm64-v8a-release.apk', (13.96 * _mib).round());
    final r = run([apk.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('13,9 MB comprimido'));
    final small = blob('app-x86_64-release.apk', (3.5 * _mib).round());
    expect(run([small.path]).stdout, contains('3,5 MB comprimido'));
    // Un decimal, sin punto: la comparación sigue siendo en bytes enteros.
    expect(run([small.path]).stdout, isNot(contains('3.5')));
  });

  test('CA-023-20: el tamaño de cada APK va también al resumen del trabajo (GITHUB_STEP_SUMMARY)', () {
    final a = blob('app-arm64-v8a-release.apk', (13.96 * _mib).round());
    final b = blob('app-x86_64-release.apk', 1024);
    final out = File('${tmp.path}/summary.md')..writeAsStringSync('antes\n');
    final r = run([a.path, b.path], summary: out.path);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    final text = out.readAsStringSync();
    expect(text, startsWith('antes\n'), reason: 'añade, no pisa');
    expect(text, contains('app-arm64-v8a-release.apk'));
    expect(text, contains('13,9 MB'));
    expect(text, contains('app-x86_64-release.apk'));
    expect(text, contains('0,0 MB'));
    expect(text, contains('20 MB'));
    // Solo el nombre del archivo, no la ruta de la máquina.
    expect(text, isNot(contains(tmp.path)));
  });

  test('CA-023-20: un APK que supera el límite también deja su tamaño en el resumen, marcado', () {
    final big = blob('app-arm64-v8a-release.apk', 21 * _mib);
    final out = File('${tmp.path}/summary.md');
    final r = run([big.path], summary: out.path);
    expect(r.exitCode, 1);
    final text = out.readAsStringSync();
    expect(text, contains('app-arm64-v8a-release.apk'));
    expect(text, contains('21,0 MB'));
    expect(text.toLowerCase(), contains('supera'));
  });

  test(
    'CA-023-20: sin GITHUB_STEP_SUMMARY (o vacío) no escribe ningún archivo',
    () {
      final apk = blob('app-x86_64-release.apk', 1024);
      run([apk.path]);
      expect(tmp.listSync().map((e) => e.path.split('/').last).toList(), [
        'app-x86_64-release.apk',
      ]);
    },
  );

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

  test('CA-023-20: el script no conserva el 25 de antes ni en su cabecera', () {
    final script = File(_script).readAsStringSync();
    expect(script, isNot(contains('25 MB')));
    expect(script, isNot(contains('limit_mb=25')));
    expect(script, contains('limit_mb=20'));
  });
}
