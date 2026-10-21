import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_package.dart';
import '../support/aab_support.dart';

/// El AAB (spec 020, T-020-06, P-020-1): `tool/check_package.dart` lo lee reempaquetando su módulo
/// `base/` como un APK *proto* y convirtiéndolo con `aapt2 convert` al formato binario, de modo que
/// las mismas reglas (a) a (g) valen para el APK y el AAB. Aquí: un AAB de prueba (un zip pequeño
/// con las entradas de `base/` que la herramienta usa) y un `aapt2` de mentira que sirve los volcados
/// de `test/tool/fixtures/aapt2/good/` (los del APK de release real); y el AAB real si está
/// compilado (`flutter build appbundle --release`).
void main() {
  final skip = zipToolsSkip;

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('check_package_aab_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String fakeAapt2({
    String? manifest,
    String? resources,
    int convertExit = 0,
  }) => writeFakeAapt2(
    tmp,
    manifest: manifest,
    resources: resources,
    convertExit: convertExit,
  );

  ({int code, String out, String err}) run(List<String> args) {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = runCheckPackage(args, out: out, err: err);
    return (code: code, out: '$out', err: '$err');
  }

  group('CA-020-02 (8): la estática MASTG sobre el AAB', () {
    test('CA-020-02: un AAB con los volcados buenos pasa (código 0)', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final r = run(['--aapt2', fakeAapt2(), aab]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      expect(r.out, contains('OK'));
      expect(r.out, contains(aab));
    }, skip: skip);

    test('CA-020-02: lee el módulo base como APK proto y lo convierte con '
        '`aapt2 convert` al formato binario', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      run(['--aapt2', fakeAapt2(), aab]);
      final calls = File('${tmp.path}/calls.log').readAsLinesSync();
      final convert = calls.where((l) => l.startsWith('convert ')).toList();
      expect(convert, hasLength(1));
      expect(convert.single, contains('--output-format binary'));
      // Los volcados se piden sobre el APK convertido, no sobre el AAB.
      final dumps = calls.where((l) => l.startsWith('dump '));
      expect(dumps, isNotEmpty);
      for (final d in dumps) {
        expect(d, isNot(contains(aab)));
      }
    }, skip: skip);

    test('CA-020-02: una regla rota en el AAB: código 1, nombra regla y '
        'archivo, y el paquete', () {
      final good = goodManifestDump();
      final broken = good.replaceAll(
        'usesCleartextTraffic(0x010104ec)=false',
        'usesCleartextTraffic(0x010104ec)=true',
      );
      expect(broken, isNot(good), reason: 'el volcado no cambió');
      final aab = zipEntries(tmp, 'bad', aabEntries());
      final r = run(['--aapt2', fakeAapt2(manifest: broken), aab]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final text = '${r.out}${r.err}';
      expect(text, contains('(b)'));
      expect(text, contains('AndroidManifest.xml'));
      expect(text, contains(aab));
    }, skip: skip);

    test('CA-020-02: un AAB con un módulo distinto de base/ falla', () {
      final aab = zipEntries(
        tmp,
        'dyn',
        aabEntries(
          extra: {
            'feature_x/manifest/AndroidManifest.xml': utf8.encode('x'),
            'feature_x/dex/classes.dex': utf8.encode('x'),
          },
        ),
      );
      final r = run(['--aapt2', fakeAapt2(), aab]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final text = '${r.out}${r.err}';
      expect(text, contains('feature_x'));
      expect(text, contains('módulo'));
      // No se mira un manifiesto a medias: ni siquiera se convierte.
      final calls = File('${tmp.path}/calls.log');
      expect(
        !calls.existsSync() || !calls.readAsStringSync().contains('convert'),
        isTrue,
      );
    }, skip: skip);

    test('CA-020-02: una entrada suelta en la raíz del AAB falla', () {
      final aab = zipEntries(
        tmp,
        'root',
        aabEntries(extra: {'otra.bin': utf8.encode('x')}),
      );
      final r = run(['--aapt2', fakeAapt2(), aab]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect('${r.out}${r.err}', contains('otra.bin'));
    }, skip: skip);

    for (final missing in [
      'base/manifest/AndroidManifest.xml',
      'base/resources.pb',
    ]) {
      test('CA-020-02: un AAB sin $missing falla (falla cerrada)', () {
        final aab = zipEntries(tmp, 'sin', aabEntries(without: [missing]));
        final r = run(['--aapt2', fakeAapt2(), aab]);
        expect(r.code, 1, reason: '${r.out}${r.err}');
        expect('${r.out}${r.err}', contains(missing));
      }, skip: skip);
    }

    test('CA-020-02: un `aapt2 convert` que falla es un fallo de la '
        'comprobación, no un verde', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final r = run(['--aapt2', fakeAapt2(convertExit: 3), aab]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect('${r.out}${r.err}', contains('fallo de la comprobación'));
    }, skip: skip);

    test('CA-020-02: un AAB que no es un zip falla', () {
      final aab = File('${tmp.path}/roto.aab')..writeAsStringSync('no soy zip');
      final r = run(['--aapt2', fakeAapt2(), aab.path]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      expect('${r.out}${r.err}', contains('roto.aab'));
    }, skip: skip);

    test('CA-020-02: no deja carpetas temporales tras comprobar un AAB', () {
      Directory.systemTemp.listSync().whereType<Directory>().toList();
      int count() => Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('una_aab_'))
          .length;
      final before = count();
      final aab = zipEntries(tmp, 'ok', aabEntries());
      run(['--aapt2', fakeAapt2(), aab]);
      run(['--aapt2', fakeAapt2(convertExit: 3), aab]);
      expect(count(), before);
    }, skip: skip);

    test('CA-020-02 (f): un secreto en BUNDLE-METADATA/ del AAB se encuentra '
        '(en el AAB se mira el archivo entero)', () {
      final key = 'AIza${'SyA-bcdefghijklmnopqrstuvwxyz012345'}';
      final aab = zipEntries(
        tmp,
        'sec',
        aabEntries(
          extra: {
            'BUNDLE-METADATA/com.android.tools.build.libraries/x.pb': utf8
                .encode(key),
          },
        ),
      );
      final r = run(['--aapt2', fakeAapt2(), aab]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final text = '${r.out}${r.err}';
      expect(text, contains('(f)'));
      expect(
        text,
        contains('BUNDLE-METADATA/com.android.tools.build.libraries/x.pb'),
      );
      expect(text, isNot(contains(key.substring(0, 8))));
    }, skip: skip);

    test('CA-023-19: una ruta de compilación en el AAB (también en '
        'BUNDLE-METADATA/) falla; la del runner de GitHub, no', () {
      final aab = zipEntries(
        tmp,
        'bp',
        aabEntries(
          extra: {
            'BUNDLE-METADATA/com.android.tools.build.debugsymbols/x.sym': utf8
                .encode('x /Users/ana/p/lib/main.dart x'),
            'base/lib/arm64-v8a/libapp.so': utf8.encode(
              'x /home/runner/work/Una/Una/app/lib/main.dart x',
            ),
          },
        ),
      );
      final r = run(['--aapt2', fakeAapt2(), aab]);
      final text = '${r.out}${r.err}';
      expect(r.code, 1, reason: text);
      expect(text, contains('(build-paths)'));
      expect(
        text,
        contains('BUNDLE-METADATA/com.android.tools.build.debugsymbols/x.sym'),
      );
      expect(text, contains('/Users/ana/p/lib/main.dart'));
      expect(text, isNot(contains('libapp.so')));
    }, skip: skip);

    test(
      'CA-020-02 (f): un archivo de firma dentro de base/ del AAB falla',
      () {
        final aab = zipEntries(
          tmp,
          'jks',
          aabEntries(extra: {'base/assets/release.jks': utf8.encode('x')}),
        );
        final r = run(['--aapt2', fakeAapt2(), aab]);
        expect(r.code, 1, reason: '${r.out}${r.err}');
        expect('${r.out}${r.err}', contains('base/assets/release.jks'));
      },
      skip: skip,
    );

    test('CA-020-02: el AAB real de release (si está compilado) pasa', () {
      final aab = File(realAabPath);
      final aapt2 = findAapt2();
      if (aapt2 == null || !aab.existsSync() || !hasTool('zip')) {
        markTestSkipped('sin aapt2, sin zip o sin AAB de release compilado');
        return;
      }
      final r = run([
        '--aapt2',
        aapt2,
        '--allowlist',
        '../tools/release/secret-allowlist.txt',
        aab.path,
      ]);
      expectPassesOrLocalBuildPaths(r.code, '${r.out}${r.err}');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  group('CA-020-02 (3): el manifiesto como XML (para la lista blanca de '
      'permisos y componentes)', () {
    test('CA-020-02: los atributos de android llevan su prefijo y el resto, '
        'no', () {
      const dump = '''
N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    A: package="a.b.c" (Raw: "a.b.c")
    A: http://schemas.android.com/apk/res/android:versionCode(0x0101021b)=7
    E: uses-permission (line=5)
      A: http://schemas.android.com/apk/res/android:name(0x01010003)="android.permission.INTERNET" (Raw: "android.permission.INTERNET")
    E: application (line=6)
      A: http://schemas.android.com/apk/res/android:debuggable(0x0101000f)=false
      E: activity (line=8)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="a.b.c.MainActivity" (Raw: "a.b.c.MainActivity")
        A: http://schemas.android.com/apk/res/android:exported(0x01010010)=true
''';
      final xml = manifestDumpToXml(dump);
      expect(xml, contains('<manifest '));
      expect(
        xml,
        contains('xmlns:android="http://schemas.android.com/apk/res/android"'),
      );
      expect(xml, contains(' package="a.b.c"'));
      expect(xml, isNot(contains('android:package')));
      expect(xml, contains('android:versionCode="7"'));
      expect(
        xml,
        contains(
          '<uses-permission android:name="android.permission.INTERNET">',
        ),
      );
      expect(xml, contains('android:exported="true"'));
      expect(xml, contains('</uses-permission>'));
      expect(xml, contains('</manifest>'));
      // Cada elemento se cierra donde toca: la actividad está dentro de application.
      expect(
        xml.indexOf('<activity '),
        inInclusiveRange(
          xml.indexOf('<application '),
          xml.indexOf('</application>'),
        ),
      );
    });

    test(
      'CA-020-02: los valores se escapan (un `"` o `<` no rompe el XML)',
      () {
        const dump = '''
N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    A: package="a.b" (Raw: "a.b")
    E: meta-data (line=3)
      A: http://schemas.android.com/apk/res/android:value(0x01010024)="x<&>y" (Raw: "x<&>y")
''';
        final xml = manifestDumpToXml(dump);
        expect(xml, contains('android:value="x&lt;&amp;&gt;y"'));
        expect(xml, isNot(contains('x<&>y')));
      },
    );

    test('CA-020-02: un volcado que no se entiende lanza FormatException', () {
      expect(() => manifestDumpToXml(''), throwsFormatException);
      expect(() => manifestDumpToXml('E: nada raro'), throwsFormatException);
    });

    test('CA-020-02: --manifest-xml escribe el XML del AAB en el archivo', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final out = '${tmp.path}/m.xml';
      final r = run(['--aapt2', fakeAapt2(), '--manifest-xml', out, aab]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      final xml = File(out).readAsStringSync();
      expect(xml, contains('<manifest '));
      expect(xml, contains('package="invalid.pending.app"'));
      expect(xml, contains('android.permission.'));
      expect(xml, contains('invalid.pending.app.notifications.WakeReceiver'));
    }, skip: skip);

    test('CA-020-02: --manifest-xml con un paquete que no se lee: código 1, '
        'sin dejar el archivo', () {
      final out = '${tmp.path}/m.xml';
      final r = run([
        '--aapt2',
        fakeAapt2(),
        '--manifest-xml',
        out,
        '${tmp.path}/no-existe.aab',
      ]);
      expect(r.code, 1);
      expect('${r.out}${r.err}', contains('no-existe.aab'));
      expect(File(out).existsSync(), isFalse);
    }, skip: skip);

    test('CA-020-02: --manifest-xml pide exactamente un paquete', () {
      final out = '${tmp.path}/m.xml';
      expect(run(['--manifest-xml', out]).code, 2);
      expect(run(['--manifest-xml', out, 'a.aab', 'b.aab']).code, 2);
      expect(run(['--manifest-xml']).code, 2);
    });
  });

  group('CA-020-03 (f): el package name', () {
    String ids(List<ClassedIssue> issues) =>
        issues.map((i) => '${i.kind}: ${i.message}').join('\n');

    test('CA-020-03: invalid.pending.* es provisional (aviso b)', () {
      for (final id in ['invalid.pending.app', 'invalid.pending.una.x']) {
        final issues = checkApplicationId(id);
        expect(issues, hasLength(1), reason: id);
        expect(issues.single.kind, 'provisional', reason: id);
        expect(issues.single.message, contains(id));
        expect(issues.single.message, contains('provisional'), reason: id);
      }
    });

    test('CA-020-03: un dominio reservado (al revés) es provisional', () {
      for (final id in [
        'com.example.una', // example.com
        'org.example.una',
        'net.example',
        'com.yourdomain.una',
        'test.una', // el sufijo .test
        'invalid.una', // el sufijo .invalid
        'local.una',
        'home.una',
      ]) {
        final issues = checkApplicationId(id);
        expect(issues, isNotEmpty, reason: id);
        expect(issues.map((i) => i.kind).toSet(), {
          'provisional',
        }, reason: '$id: ${ids(issues)}');
      }
    });

    test('CA-020-03: «corp» como último segmento no es un sufijo reservado '
        'al revés (el dominio es corp.mycorp.com)', () {
      expect(checkApplicationId('com.mycorp.corp'), isEmpty);
    });

    test('CA-020-03: un package name propio no da nada', () {
      for (final id in [
        'es.valle.una',
        'com.miempresa.una_app',
        'app.una2.x',
      ]) {
        expect(checkApplicationId(id), isEmpty, reason: id);
      }
    });

    test(
      'CA-020-03: un package name mal formado es un fallo (no un aviso)',
      () {
        for (final id in [
          '',
          'una', // un solo segmento
          'com..una',
          'com.1una.x',
          'com.una-app.x',
          'Com.Una ',
          'com.una.',
          '.com.una',
          'com.una.class\n',
        ]) {
          final issues = checkApplicationId(id);
          expect(issues, isNotEmpty, reason: '«$id»');
          expect(issues.map((i) => i.kind).toSet(), {'fault'}, reason: '«$id»');
        }
      },
    );

    test('CA-020-03: el provisional y el mal formado no se mezclan: si hay '
        'un fallo, todo es fallo', () {
      // `invalid.pending.1x` es provisional y a la vez no es un package name válido.
      final issues = checkApplicationId('invalid.pending.1x');
      expect(issues.map((i) => i.kind).toSet(), {'fault'});
    });

    test('CA-020-03: --package-name escribe el JSON de clase (APK/AAB) y sale '
        'con 1', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final json = '${tmp.path}/pn.json';
      final r = run([
        '--aapt2',
        fakeAapt2(),
        '--package-name',
        '--json',
        json,
        aab,
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      expect(data['version'], 1);
      expect(data['complete'], isTrue);
      expect(data['checks'], ['package-name']);
      final issues = (data['issues'] as List).cast<Map<String, Object?>>();
      expect(issues, hasLength(1));
      expect(issues.single['kind'], 'provisional');
      expect(issues.single['subject'], 'ok.aab');
      expect(issues.single['message'], contains('invalid.pending.app'));
      expect(
        File('$json.tmp').existsSync(),
        isFalse,
        reason: 'escritura atómica',
      );
      expect('${r.out}${r.err}', contains('::error::'));
    }, skip: skip);

    test('CA-020-03: --package-name con un package name propio: código 0 y '
        'JSON sin errores', () {
      final own = goodManifestDump().replaceAll(
        'invalid.pending.app',
        'es.valle.una',
      );
      final aab = zipEntries(tmp, 'own', aabEntries());
      final json = '${tmp.path}/pn.json';
      final r = run([
        '--aapt2',
        fakeAapt2(manifest: own),
        '--package-name',
        '--json',
        json,
        aab,
      ]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      expect(data['complete'], isTrue);
      expect(data['issues'], isEmpty);
    }, skip: skip);

    test('CA-020-03: --package-name sobre un paquete ilegible: fallo en el '
        'JSON (completo) y código 1', () {
      final json = '${tmp.path}/pn.json';
      final r = run([
        '--aapt2',
        fakeAapt2(),
        '--package-name',
        '--json',
        json,
        '${tmp.path}/no-existe.apk',
      ]);
      expect(r.code, 1);
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      final issues = (data['issues'] as List).cast<Map<String, Object?>>();
      expect(issues.single['kind'], 'fault');
      expect(issues.single['subject'], 'no-existe.apk');
    }, skip: skip);

    test(
      'CA-020-03: --package-name con dos paquetes: un aviso por cada uno',
      () {
        final a = zipEntries(tmp, 'a', aabEntries());
        final b = zipEntries(tmp, 'b', aabEntries());
        final json = '${tmp.path}/pn.json';
        final r = run([
          '--aapt2',
          fakeAapt2(),
          '--package-name',
          '--json',
          json,
          a,
          b,
        ]);
        expect(r.code, 1);
        final data =
            jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
        final subjects = (data['issues'] as List)
            .cast<Map<String, Object?>>()
            .map((i) => i['subject'])
            .toList();
        expect(subjects, ['a.aab', 'b.aab']);
      },
      skip: skip,
    );

    test('CA-020-03: --json solo vale con --package-name; sin paquetes: 2', () {
      expect(run(['--json', '${tmp.path}/x.json', 'a.apk']).code, 2);
      expect(run(['--package-name']).code, 2);
      expect(run(['--package-name', '--json']).code, 2);
    });

    test('CA-020-03: el package name del AAB real de release (si está '
        'compilado) es el provisional', () {
      final aab = File(realAabPath);
      final aapt2 = findAapt2();
      if (aapt2 == null || !aab.existsSync() || !hasTool('zip')) {
        markTestSkipped('sin aapt2, sin zip o sin AAB de release compilado');
        return;
      }
      final json = '${tmp.path}/pn.json';
      final r = run([
        '--aapt2',
        aapt2,
        '--package-name',
        '--json',
        json,
        aab.path,
      ]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      final kinds = (data['issues'] as List).cast<Map<String, Object?>>().map(
        (i) => i['kind'],
      );
      expect(kinds.toSet(), {'provisional'});
    });
  });

  group('CA-020-02: tools/check-package.sh con un AAB', () {
    ProcessResult sh(List<String> args) =>
        Process.runSync('bash', ['../tools/check-package.sh', ...args]);

    test('CA-020-03: --package-name --json por la envoltura: código 1 y '
        'JSON de clase', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final json = '${tmp.path}/pn.json';
      final r = sh([
        '--aapt2',
        fakeAapt2(),
        '--package-name',
        '--json',
        json,
        aab,
      ]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      final data =
          jsonDecode(File(json).readAsStringSync()) as Map<String, Object?>;
      expect(data['complete'], isTrue);
      final kinds = (data['issues']! as List)
          .cast<Map<String, Object?>>()
          .map((i) => i['kind'])
          .toSet();
      expect(kinds, {'provisional'});
    }, skip: skip);

    test('CA-020-02: el AAB por la envoltura usa la lista de excepciones '
        'de los secretos', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final r = sh(['--aapt2', fakeAapt2(), aab]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    }, skip: skip);

    test('CA-020-02: --json sin --package-name es un uso incorrecto (2)', () {
      final r = sh(['--json', '${tmp.path}/x.json', '${tmp.path}/a.aab']);
      expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    });

    test('CA-020-02: --manifest-xml por la envoltura escribe el XML', () {
      final aab = zipEntries(tmp, 'ok', aabEntries());
      final out = '${tmp.path}/m.xml';
      final r = sh(['--aapt2', fakeAapt2(), '--manifest-xml', out, aab]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(File(out).readAsStringSync(), contains('<manifest '));
    }, skip: skip);
  });
}
