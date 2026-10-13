import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
