import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-gradle-wrapper.sh` (CA-020-14, 012-S6): la distribución de Gradle lleva su suma
/// SHA-256 en `gradle-wrapper.properties` (la que fija `tools/gradle-wrapper.lock`) y el
/// `gradle-wrapper.jar` que se ejecuta es uno de los que publica Gradle. Se prueba con
/// propiedades, locks y jars de juguete en un directorio temporal.
const _script = '../tools/check-gradle-wrapper.sh';
const _realLock = '../tools/gradle-wrapper.lock';
const _realProperties = 'android/gradle/wrapper/gradle-wrapper.properties';
const _realJar = 'android/gradle/wrapper/gradle-wrapper.jar';

// Lo que publica Gradle (https://gradle.org/release-checksums/, comprobado el 2026-10-14).
const _distSum9 =
    '46ac66d47f30f3dacfdf306e0b714a91a34fb94a22ba0a744b280933f47bc0cf';
const _jarSum210 =
    '16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da';
const _jarSum9 =
    '238e777fcddd7e34f9708186085def2abd6e08e658505b38718d79d74c21abd5';

const _goodJar = 'contenido de un jar de prueba';
const _distFile = 'gradle-9.8.0-all.zip';

/// SHA-256 de un texto con las herramientas del sistema (`package:crypto` no es dependencia).
String _sha(String text) {
  final file = File('${Directory.systemTemp.createTempSync('sha_').path}/x')
    ..writeAsBytesSync(utf8.encode(text));
  try {
    final r = Platform.isLinux
        ? Process.runSync('sha256sum', [file.path])
        : Process.runSync('shasum', ['-a', '256', file.path]);
    return (r.stdout as String).split(' ').first;
  } finally {
    file.parent.deleteSync(recursive: true);
  }
}

final _jarSum = _sha(_goodJar);

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

String _lock({
  String? dist,
  String jar = '',
  String extra = '',
  String distLine = '',
}) =>
    '''
# lock de prueba
${distLine.isEmpty ? 'distribution $_distFile ${dist ?? _distSum}' : distLine}
wrapper-jar 9.8.0 ${jar.isEmpty ? _jarSum : jar}
$extra''';

const _distSum =
    '000000000000000000000000000000000000000000000000000000000000d157';

String _props({
  String? sumLine,
  String url = 'https\\://services.gradle.org/distributions/$_distFile',
}) =>
    '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
${sumLine ?? 'distributionSha256Sum=$_distSum'}
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=$url
''';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('gradle_wrapper_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run({
    String? props,
    String? lock,
    Object? jar = _goodJar,
    List<String> extraArgs = const [],
  }) {
    final p = File('${tmp.path}/gradle-wrapper.properties');
    final l = File('${tmp.path}/gradle-wrapper.lock');
    final j = File('${tmp.path}/gradle-wrapper.jar');
    if (props != null) p.writeAsStringSync(props);
    if (lock != null) l.writeAsStringSync(lock);
    if (jar is String) j.writeAsStringSync(jar);
    if (jar is List<int>) j.writeAsBytesSync(jar);
    return Process.runSync('bash', [
      File(_script).absolute.path,
      '--properties',
      p.path,
      '--lock',
      l.path,
      '--jar',
      j.path,
      ...extraArgs,
    ], workingDirectory: tmp.path);
  }

  String out(ProcessResult r) => '${r.stdout}${r.stderr}';

  void expectOk({String? props, String? lock, Object? jar = _goodJar}) {
    final r = run(props: props ?? _props(), lock: lock ?? _lock(), jar: jar);
    expect(r.exitCode, 0, reason: out(r));
  }

  void expectFails(
    Object message, {
    String? props,
    String? lock,
    Object? jar = _goodJar,
  }) {
    final r = run(props: props ?? _props(), lock: lock ?? _lock(), jar: jar);
    expect(r.exitCode, isNot(0), reason: out(r));
    expect(out(r), contains(message));
  }

  group('CA-020-14: la suma de la distribución en gradle-wrapper.properties', () {
    test('CA-020-14: con la suma del lock y el jar admitido pasa', () {
      expectOk();
    });

    test('CA-020-14: con fin de línea CRLF también pasa', () {
      expectOk(props: _props().replaceAll('\n', '\r\n'));
    });

    test('CA-020-14: sin la línea distributionSha256Sum falla y lo dice (CL-020-18)', () {
      final props = _props().replaceAll(
        RegExp(r'distributionSha256Sum=.*\n'),
        '',
      );
      expectFails('Falta distributionSha256Sum', props: props);
    });

    test('CA-020-14: la suma comentada no cuenta', () {
      expectFails(
        'Falta distributionSha256Sum',
        props: _props(sumLine: '#distributionSha256Sum=$_distSum'),
      );
    });

    test('CA-020-14: una suma distinta de la del lock falla', () {
      expectFails(
        'no coincide',
        props: _props(sumLine: 'distributionSha256Sum=${_hex(0xbad)}'),
      );
    });

    test('CA-020-14: una suma en mayúsculas o de otra longitud falla', () {
      expectFails(
        'mal formada',
        props: _props(
          sumLine: 'distributionSha256Sum=${_distSum.toUpperCase()}',
        ),
      );
      expectFails(
        'mal formada',
        props: _props(
          sumLine: 'distributionSha256Sum=${_distSum.substring(1)}',
        ),
      );
      expectFails(
        'mal formada',
        props: _props(sumLine: 'distributionSha256Sum='),
      );
    });

    test('CA-020-14: dos líneas de suma (la última gana en Gradle) fallan', () {
      expectFails(
        'aparece 2 veces',
        props: _props(
          sumLine:
              'distributionSha256Sum=$_distSum\ndistributionSha256Sum=${_hex(0xbad)}',
        ),
      );
    });

    test(
      'CA-020-14: una forma de escribir la clave que Gradle acepta pero esta '
      'comprobación no lee falla (falla cerrada)',
      () {
        expectFails(
          'mal formada',
          props: _props(sumLine: 'distributionSha256Sum = $_distSum'),
        );
        expectFails(
          'mal formada',
          props: _props(sumLine: ' distributionSha256Sum=$_distSum'),
        );
        expectFails(
          'mal formada',
          props: _props(sumLine: 'distributionSha256Sum:$_distSum'),
        );
      },
    );

    test('CA-020-14: una versión de Gradle que el lock no conoce falla (CL-020-18)', () {
      expectFails(
        'gradle-9.9.0-all.zip no está en tools/gradle-wrapper.lock',
        props: _props(
          url: 'https\\://services.gradle.org/distributions/gradle-9.9.0-all.zip',
        ),
      );
    });

    test('CA-020-14: la distribución -bin (que el lock no lista) falla', () {
      expectFails(
        'gradle-9.8.0-bin.zip no está en tools/gradle-wrapper.lock',
        props: _props(
          url: 'https\\://services.gradle.org/distributions/gradle-9.8.0-bin.zip',
        ),
      );
    });

    test(
      'CA-020-14: un distributionUrl de otro servidor o sin https falla',
      () {
        for (final url in [
          'https\\://example.com/distributions/$_distFile',
          'http\\://services.gradle.org/distributions/$_distFile',
          'https\\://services.gradle.org.evil.test/distributions/$_distFile',
          'https\\://services.gradle.org/other/$_distFile',
          'file\\:///tmp/$_distFile',
          'https\\://servicesXgradleXorg/distributions/$_distFile',
          'https\\://services.gradle.org/distributions/$_distFile?x=1',
          'https\\://services.gradle.org/distributions/$_distFile/../x',
        ]) {
          expectFails('distributionUrl', props: _props(url: url));
        }
      },
    );

    test('CA-020-14: sin distributionUrl o con dos falla', () {
      expectFails(
        'distributionUrl',
        props: _props().replaceAll(RegExp(r'distributionUrl=.*\n'), ''),
      );
      expectFails(
        'distributionUrl',
        props:
            '${_props()}distributionUrl=https\\://services.gradle.org/distributions/$_distFile\n',
      );
    });
  });

  group('CA-020-14: el gradle-wrapper.jar que se ejecuta', () {
    test('CA-020-14: un jar que no está entre las sumas del lock falla y da la suma', () {
      final r = run(props: _props(), lock: _lock(), jar: 'otro jar');
      expect(r.exitCode, isNot(0), reason: out(r));
      expect(out(r), contains('gradle-wrapper.jar'));
      expect(out(r), contains(_sha('otro jar')));
    });

    test('CA-020-14: un jar con un solo byte cambiado falla', () {
      final bytes = utf8.encode(_goodJar)..[3] ^= 1;
      expectFails('gradle-wrapper.jar', jar: bytes);
    });

    test('CA-020-14: un jar ausente falla y dice cómo generarlo', () {
      final r = run(props: _props(), lock: _lock(), jar: null);
      expect(r.exitCode, isNot(0), reason: out(r));
      expect(out(r), contains('gradle-wrapper.jar'));
      expect(out(r), contains('flutter build'));
    });

    test('CA-020-14: un jar vacío falla', () {
      expectFails('gradle-wrapper.jar', jar: '');
    });

    test('CA-020-14: cualquiera de las sumas admitidas del lock vale', () {
      final other = 'otro jar admitido';
      expectOk(
        lock: _lock(extra: 'wrapper-jar 2.10 ${_sha(other)}'),
        jar: other,
      );
    });
  });

  group('CA-020-14: el lock', () {
    test('CA-020-14: sin lock falla nombrándolo', () {
      final r = run(props: _props(), lock: null, jar: _goodJar);
      expect(r.exitCode, isNot(0), reason: out(r));
      expect(out(r), contains('No se puede leer tools/gradle-wrapper.lock'));
    });

    test('CA-020-14: un lock vacío o sin sumas de jar falla', () {
      expectFails('gradle-wrapper.lock', lock: '# solo un comentario\n');
      expectFails(
        'wrapper-jar',
        lock: '# sin jar\ndistribution $_distFile $_distSum\n',
      );
      expectFails(
        'distribution',
        lock: '# sin distribución\nwrapper-jar 9.8.0 $_jarSum\n',
      );
    });

    test('CA-020-14: una línea mal formada del lock falla (no se salta)', () {
      for (final bad in [
        'distribution $_distFile corta',
        'wrapper-jar 9.8.0 ${_hex(0xabc).toUpperCase()}',
        'distribucion $_distFile $_distSum',
        'wrapper-jar $_jarSum',
        'wrapper-jar 9.8.0 $_jarSum de-mas',
      ]) {
        expectFails('gradle-wrapper.lock', lock: _lock(extra: bad));
      }
    });

    test(
      'CA-020-14: dos sumas distintas para la misma distribución fallan',
      () {
        expectFails(
          'dos sumas distintas para $_distFile',
          lock: _lock(extra: 'distribution $_distFile ${_hex(0xbad)}'),
        );
      },
    );
  });

  group('CA-020-14: los archivos reales del repositorio', () {
    test('CA-020-14: el lock lleva las sumas que publica Gradle', () {
      final lock = File(_realLock).readAsStringSync();
      expect(lock, contains('distribution gradle-9.8.0-all.zip $_distSum9'));
      expect(lock, contains('wrapper-jar 2.10 $_jarSum210'));
      expect(lock, contains('wrapper-jar 9.8.0 $_jarSum9'));
    });

    test('CA-020-14: gradle-wrapper.properties lleva la suma de gradle-9.8.0-all.zip', () {
      final props = File(_realProperties).readAsStringSync();
      expect(
        props,
        contains(
          RegExp('^distributionSha256Sum=$_distSum9\$', multiLine: true),
        ),
      );
      expect(props, contains('gradle-9.8.0-all.zip'));
    });

    test('CA-020-14: las propiedades reales pasan con un jar de prueba que el '
        'lock admite', () {
      final lock =
          '${File(_realLock).readAsStringSync()}'
          'wrapper-jar prueba $_jarSum\n';
      final r = run(
        props: File(_realProperties).readAsStringSync(),
        lock: lock,
      );
      expect(r.exitCode, 0, reason: out(r));
    });

    test('CA-020-14: el gradle-wrapper.jar que ha generado Flutter pasa', () {
      final jar = File(_realJar);
      final r = Process.runSync('bash', [File(_script).absolute.path]);
      if (!jar.existsSync()) {
        // El jar lo genera `flutter build` y no está en el repositorio: sin compilar, falla.
        expect(r.exitCode, isNot(0), reason: out(r));
        return;
      }
      expect(r.exitCode, 0, reason: out(r));
    });
  });

  test(
    'CA-020-14: un argumento desconocido sale con código 2 sin comprobar nada',
    () {
      final r = run(props: _props(), lock: _lock(), extraArgs: ['--nada']);
      expect(r.exitCode, 2, reason: out(r));
    },
  );
}
