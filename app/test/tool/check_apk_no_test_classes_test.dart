import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/aab_support.dart' show realAabPath;

/// El script de CI que vigila que JUnit/Hamcrest (solo `testImplementation`,
/// spec 019, plan §0 C-2) no entre en un APK distribuido. Crea APK de juguete
/// con `zip` (un APK es un zip con `classes*.dex`).
const _script = '../tools/check-apk-no-test-classes.sh';

bool _hasTool(String name) => Process.runSync('which', [name]).exitCode == 0;

/// Un zip con [entries] (ruta -> contenido) dentro de [dir]; devuelve su ruta.
String _apk(Directory dir, String name, Map<String, List<int>> entries) {
  final staging = Directory('${dir.path}/staging_$name')..createSync();
  entries.forEach((path, bytes) {
    final file = File('${staging.path}/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    expect(file.existsSync(), isTrue);
  });
  final out = '${dir.path}/$name.apk';
  final r = Process.runSync('zip', [
    '-q',
    '-r',
    out,
    '.',
  ], workingDirectory: staging.path);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return out;
}

/// Como [_run], pero con SIGPIPE en su comportamiento por defecto: la VM de Dart lo ignora y los hijos
/// lo heredan, y entonces el cierre temprano de `grep -q` no corta la tubería como en la CI real.
ProcessResult _runWithSigpipe(List<String> apks) => Process.runSync('perl', [
  '-e',
  r'$SIG{PIPE} = "DEFAULT"; exec @ARGV',
  'bash',
  _script,
  ...apks,
]);

ProcessResult _run(List<String> apks) => Process.runSync(
  'bash',
  [_script, ...apks],
  environment: {...Platform.environment},
);

List<int> _dex(String body) => [
  ...latin1.encode('dex\n035\u0000'),
  ...latin1.encode(body),
];

void main() {
  final skip = !_hasTool('zip') || !_hasTool('unzip')
      ? 'zip/unzip no disponibles'
      : null;
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('apk_check_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  // Un APK real tiene miles de entradas y dex de megas: con `set -o pipefail`, un `| grep -q` que
  // encuentra pronto corta la tubería (SIGPIPE) y la comprobación daba por buena una clase de pruebas
  // (falso negativo, comprobado en T-020-07). Aquí lo que hay que encontrar está al principio.
  group('CA-020-02: paquetes grandes (sin SIGPIPE bajo pipefail)', () {
    test('un org/junit al principio de un zip de 6000 entradas se detecta', () {
      final dir = Directory('${tmp.path}/big')..createSync();
      File('${dir.path}/org/junit/Test.class')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0xca, 0xfe]);
      final names = <String>[];
      for (var i = 0; i < 6000; i++) {
        File('${dir.path}/f$i.txt').writeAsStringSync('$i');
        names.add('f$i.txt');
      }
      final out = '${tmp.path}/big.apk';
      final z = Process.runSync('zip', [
        '-q',
        '-X',
        out,
        'org/junit/Test.class',
        ...names,
      ], workingDirectory: dir.path);
      expect(z.exitCode, 0, reason: '${z.stderr}');
      for (var i = 0; i < 5; i++) {
        final r = _runWithSigpipe([out]);
        expect(r.exitCode, 1, reason: 'pasada $i: ${r.stdout}${r.stderr}');
        expect(r.stdout, contains('entradas de JUnit'));
      }
    }, skip: skip);

    test('ningún script de tools/ canaliza unzip a un grep -q (con pipefail daba falsos negativos)', () {
      final scripts = [
        ...Directory('../tools').listSync().whereType<File>(),
        ...Directory('../tools/release').listSync().whereType<File>(),
      ].where((f) => f.path.endsWith('.sh'));
      expect(scripts, isNotEmpty);
      final bad = RegExp(r'unzip[^\n|]*\|\s*(LC_ALL=C\s+)?grep\s+-[a-zA-Z]*q');
      for (final f in scripts) {
        expect(bad.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('una clase de JUnit al principio de un dex de 3 MB se detecta', () {
      final apk = _apk(tmp, 'bigdex', {
        'classes.dex': _dex('Lorg/junit/Test; ${'x' * (3 * 1024 * 1024)}'),
      });
      for (var i = 0; i < 5; i++) {
        final r = _runWithSigpipe([apk]);
        expect(r.exitCode, 1, reason: 'pasada $i: ${r.stdout}${r.stderr}');
        expect(r.stdout, contains('classes.dex lleva clases de JUnit'));
      }
    }, skip: skip);
  });

  test('CA-019-25: un APK sin clases de pruebas pasa', () {
    final apk = _apk(tmp, 'clean', {
      'classes.dex': _dex('Landroidx/core/app/NotificationCompat;'),
      'AndroidManifest.xml': utf8.encode('<manifest/>'),
    });
    final r = _run([apk]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('OK'));
  }, skip: skip);

  for (final descriptor in [
    'Lorg/junit/Test;',
    'Lorg/hamcrest/Matcher;',
    'Ljunit/framework/TestCase;',
  ]) {
    test('CA-019-25: un dex con $descriptor falla y nombra el dex', () {
      final apk = _apk(tmp, 'bad', {
        'classes.dex': _dex('Lfoo/Bar;'),
        'classes2.dex': _dex('xx $descriptor yy'),
      });
      final r = _run([apk]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}${r.stderr}', contains('classes2.dex'));
    }, skip: skip);
  }

  test('CA-019-25: una entrada org/junit/... en el APK falla', () {
    final apk = _apk(tmp, 'entry', {
      'classes.dex': _dex('Lfoo/Bar;'),
      'org/junit/Test.class': [0xca, 0xfe],
    });
    final r = _run([apk]);
    expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
  }, skip: skip);

  test('CA-019-25: con varios APK, uno malo hace fallar a todos', () {
    final good = _apk(tmp, 'good', {'classes.dex': _dex('Lfoo/Bar;')});
    final bad = _apk(tmp, 'bad2', {'classes.dex': _dex('Lorg/junit/Test;')});
    final r = _run([good, bad]);
    expect(r.exitCode, 1);
    expect(r.stdout, contains('OK'));
  }, skip: skip);

  // R8 quita lo que nadie usa, así que el APK de release saldría limpio aunque JUnit fuera una
  // `implementation` (comprobado en T-019-04): la vigilancia del archivo de Gradle es la que lo
  // impide, y la del APK atrapa lo que R8 sí conservara.
  test(
    'CA-019-25: JUnit y Hamcrest solo se declaran como testImplementation',
    () {
      final lines = File('android/app/build.gradle.kts')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => !l.startsWith('//'))
          .where((l) => l.contains('junit') || l.contains('hamcrest'))
          .toList();
      expect(
        lines,
        isNotEmpty,
        reason: 'JUnit debe seguir declarado (P-019-1)',
      );
      for (final line in lines) {
        expect(line, startsWith('testImplementation('), reason: line);
      }
    },
  );

  test('CA-019-25: un APK que no existe falla; sin argumentos, uso (2)', () {
    expect(_run(['${tmp.path}/no-existe.apk']).exitCode, 1);
    expect(_run([]).exitCode, 2);
  }, skip: skip);

  // CA-020-02 (4) (T-020-06): el mismo script acepta un AAB (`base/dex/classes*.dex`).
  group('CA-020-02: el AAB', () {
    String aab(String name, Map<String, List<int>> entries) {
      final staging = Directory('${tmp.path}/staging_$name')..createSync();
      entries.forEach((path, bytes) {
        File('${staging.path}/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
      });
      final out = '${tmp.path}/$name.aab';
      final r = Process.runSync('zip', [
        '-q',
        '-r',
        out,
        '.',
      ], workingDirectory: staging.path);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return out;
    }

    test('CA-020-02: un AAB sin clases de pruebas pasa', () {
      final f = aab('clean', {
        'BundleConfig.pb': [1],
        'base/manifest/AndroidManifest.xml': [1],
        'base/dex/classes.dex': _dex('Landroidx/core/app/NotificationCompat;'),
      });
      final r = _run([f]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('OK'));
    }, skip: skip);

    for (final descriptor in [
      'Lorg/junit/Test;',
      'Lorg/hamcrest/Matcher;',
      'Ljunit/framework/TestCase;',
    ]) {
      test('CA-020-02: un base/dex/classes2.dex con $descriptor falla y '
          'nombra el dex', () {
        final f = aab('bad', {
          'base/dex/classes.dex': _dex('Lfoo/Bar;'),
          'base/dex/classes2.dex': _dex('xx $descriptor yy'),
        });
        final r = _run([f]);
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
        expect('${r.stdout}${r.stderr}', contains('base/dex/classes2.dex'));
      }, skip: skip);
    }

    test(
      'CA-020-02: una entrada org/junit/... bajo base/root/ del AAB falla',
      () {
        final f = aab('entry', {
          'base/dex/classes.dex': _dex('Lfoo/Bar;'),
          'base/root/org/junit/Test.class': [0xca, 0xfe],
        });
        final r = _run([f]);
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      },
      skip: skip,
    );

    test('CA-020-02: APK y AAB juntos: uno malo hace fallar a todos', () {
      final good = _apk(tmp, 'good', {'classes.dex': _dex('Lfoo/Bar;')});
      final bad = aab('bad3', {
        'base/dex/classes.dex': _dex('Lorg/junit/Test;'),
      });
      final r = _run([good, bad]);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('OK'));
    }, skip: skip);

    test('CA-020-02: el AAB real de release (si está compilado) pasa', () {
      if (!File(realAabPath).existsSync() || skip != null) {
        markTestSkipped('sin AAB de release compilado');
        return;
      }
      final r = _run([realAabPath]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });
  });
}
