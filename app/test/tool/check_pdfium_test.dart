import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_package.dart' show sha256Hex;
import '../support/aab_support.dart';

/// `tools/check-pdfium.sh` (spec 008, threat-model §5; spec 020, T-020-06): el `libpdfium.so` de
/// cada paquete de release es exactamente el fijado en `tools/pdfium.lock`. Sin argumentos mira los
/// APK por ABI de `app/build`; con argumentos, los paquetes dados: un APK (el de un ABI por su nombre,
/// o todos los ABI) o un AAB (`base/lib/<abi>/libpdfium.so`, de todos los ABI).
///
/// Se prueba con una copia del script y una `pdfium.lock` de prueba en una carpeta temporal (el
/// script busca su lock junto a sí mismo) y paquetes de juguete.
const _script = '../tools/check-pdfium.sh';
const _abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

String _sha(List<int> bytes) => sha256Hex(bytes);

List<int> _lib(String abi) => utf8.encode('libpdfium de $abi');

void main() {
  final skip = zipToolsSkip;
  late Directory tmp;
  late String script;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfium_check_');
    final bin = Directory('${tmp.path}/tools')..createSync();
    script = '${bin.path}/check-pdfium.sh';
    File(_script).copySync(script);
    File('${bin.path}/pdfium.lock').writeAsStringSync(
      '# lock de prueba\n${[for (final a in _abis) '$a ${_sha(_lib(a))}'].join('\n')}\n',
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run(List<String> args, {String? cwd}) => Process.runSync(
    'bash',
    [script, ...args],
    workingDirectory: cwd ?? tmp.path,
  );

  String apk(String name, Map<String, List<int>> libs) =>
      zipEntries(tmp, name, {
        'classes.dex': [1],
        for (final MapEntry(:key, :value) in libs.entries)
          'lib/$key/libpdfium.so': value,
      }, ext: 'apk');

  String aab(
    String name,
    Map<String, List<int>> libs, {
    String module = 'base',
  }) => zipEntries(tmp, name, {
    'BundleConfig.pb': [1],
    for (final MapEntry(:key, :value) in libs.entries)
      '$module/lib/$key/libpdfium.so': value,
  });

  Map<String, List<int>> goodLibs() => {for (final a in _abis) a: _lib(a)};

  group('CA-020-02 (5): el AAB', () {
    test('CA-020-02: un AAB con los tres libpdfium.so fijados pasa', () {
      final f = aab('ok', goodLibs());
      final r = run([f]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      for (final a in _abis) {
        expect('${r.stdout}', contains('OK $a'));
      }
    }, skip: skip);

    test('CA-020-02: un libpdfium.so distinto en el AAB falla y nombra el '
        'ABI', () {
      final f = aab('bad', {...goodLibs(), 'x86_64': utf8.encode('otro')});
      final r = run([f]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      final text = '${r.stdout}${r.stderr}';
      expect(text, contains('x86_64'));
      expect(text, contains('bad.aab'));
      expect(text, contains('OK arm64-v8a'));
    }, skip: skip);

    test('CA-020-02: un AAB al que le falta un ABI falla (falla cerrada)', () {
      final f = aab('missing', {...goodLibs()}..remove('armeabi-v7a'));
      final r = run([f]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('armeabi-v7a'));
    }, skip: skip);

    test('CA-020-02: un libpdfium.so fuera de base/ no cuenta', () {
      final f = aab('othermodule', goodLibs(), module: 'feature_x');
      final r = run([f]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    }, skip: skip);

    test('CA-020-02: el AAB real de release (si está compilado) pasa', () {
      if (!File(realAabPath).existsSync() || skip != null) {
        markTestSkipped('sin AAB de release compilado');
        return;
      }
      final copy = File(_script).absolute.path;
      final r = Process.runSync('bash', [
        copy,
        File(realAabPath).absolute.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });

  group('CA-020-02 (5): los APK dados', () {
    test('CA-020-02: un APK por ABI (por su nombre) mira solo su ABI', () {
      final f = apk('app-x86_64-release', {'x86_64': _lib('x86_64')});
      final r = run([f]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}', contains('OK x86_64'));
      expect('${r.stdout}', isNot(contains('arm64')));
    }, skip: skip);

    test('CA-020-02: un APK por ABI con el .so cambiado falla', () {
      final f = apk('app-x86_64-release', {'x86_64': utf8.encode('otro')});
      final r = run([f]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    }, skip: skip);

    test(
      'CA-020-02: un APK universal (sin ABI en el nombre) mira los tres',
      () {
        final ok = apk('app-release', goodLibs());
        expect(run([ok]).exitCode, 0);
        final bad = apk('universal-bad', {...goodLibs()}..remove('x86_64'));
        final r = run([bad]);
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
        expect('${r.stdout}${r.stderr}', contains('x86_64'));
      },
      skip: skip,
    );

    test('CA-020-02: varios paquetes: uno malo hace fallar a todos', () {
      final good = aab('good', goodLibs());
      final bad = apk('app-arm64-v8a-release', {
        'arm64-v8a': utf8.encode('otro'),
      });
      final r = run([good, bad]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}', contains('OK arm64-v8a'));
    }, skip: skip);

    test('CA-020-02: un paquete que no existe falla', () {
      final r = run(['${tmp.path}/no-existe.aab']);
      expect(r.exitCode, 1);
      expect('${r.stdout}${r.stderr}', contains('no-existe.aab'));
    }, skip: skip);

    test('CA-020-02: un paquete que no es un zip falla', () {
      final f = File('${tmp.path}/roto.aab')..writeAsStringSync('nada');
      final r = run([f.path]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('no es un zip legible'));
    }, skip: skip);
  });

  group('CA-008-17: sin argumentos (los APK de app/build)', () {
    String apkDir() {
      final d = Directory('${tmp.path}/build/app/outputs/flutter-apk')
        ..createSync(recursive: true);
      return d.path;
    }

    test('CA-008-17: los tres APK por ABI buenos pasan', () {
      for (final a in _abis) {
        final f = apk('app-$a-release', {a: _lib(a)});
        File(f).copySync('${apkDir()}/app-$a-release.apk');
      }
      final r = run([]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    }, skip: skip);

    test('CA-008-17: sin ningún APK compilado falla (no se da por bueno)', () {
      final r = run([]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('flutter build apk'));
    }, skip: skip);

    test('CA-008-17: un APK de menos falla', () {
      for (final a in _abis.take(2)) {
        File(apk('app-$a-release', {a: _lib(a)}))
            .copySync('${apkDir()}/app-$a-release.apk');
      }
      final r = run([]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    }, skip: skip);

    test('CA-008-17: un lock sin ninguna huella falla', () {
      File('${tmp.path}/tools/pdfium.lock').writeAsStringSync('# vacío\n');
      final f = aab('ok', goodLibs());
      final r = run([f]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('pdfium.lock'));
    }, skip: skip);
  });

  test('CA-008-17: el lock real tiene las tres huellas y las de los APK '
      'reales (si están compilados) coinciden', () {
    final lock = File('../tools/pdfium.lock')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'));
    expect(lock.map((l) => l.split(' ').first).toList(), _abis);
    final dir = Directory('build/app/outputs/flutter-apk');
    final apks = [
      for (final a in _abis) File('${dir.path}/app-$a-release.apk'),
    ];
    if (skip != null || apks.any((f) => !f.existsSync())) {
      markTestSkipped('sin los tres APK de release compilados');
      return;
    }
    final r = Process.runSync('bash', [
      File(_script).absolute.path,
      ...apks.map((f) => f.absolute.path),
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
