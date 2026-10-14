import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-android-permissions.sh` (CA-019-25, T-8, T-13): permisos exactos y lista blanca
/// de componentes del manifiesto combinado. Se prueba con manifiestos de juguete en un
/// directorio temporal con la misma estructura que deja Gradle.
const _script = '../tools/check-android-permissions.sh';

const _alarmAction = 'invalid.pending.app.action.NOTIFICATION_ALARM';

const _systemActions = [
  'android.intent.action.LOCKED_BOOT_COMPLETED',
  'android.intent.action.BOOT_COMPLETED',
  'android.intent.action.TIME_SET',
  'android.intent.action.TIMEZONE_CHANGED',
  'android.intent.action.LOCALE_CHANGED',
  'android.intent.action.MY_PACKAGE_REPLACED',
];

/// Un manifiesto combinado como el de la app. Cada parámetro permite estropear una pieza.
String _manifest({
  List<String> permissions = const [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
  ],
  String? wakeReceiver,
  String profileReceiver = _profileReceiver,
  String extra = '',
  String mainActivity = _mainActivity,
}) =>
    '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="invalid.pending.app">
    <uses-sdk android:minSdkVersion="26" />
    ${[for (final p in permissions) '<uses-permission android:name="$p" />'].join('\n    ')}
    <permission android:name="invalid.pending.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
        android:protectionLevel="signature" />
    <uses-permission android:name="invalid.pending.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" />
    <application android:name="android.app.Application">
        $mainActivity
        <provider android:name="androidx.core.content.FileProvider"
            android:authorities="invalid.pending.app.imports" android:exported="false"
            android:grantUriPermissions="true" />
        <activity android:name="io.flutter.plugins.urllauncher.WebViewActivity"
            android:exported="false" android:theme="@android:style/Theme.NoTitleBar.Fullscreen" />
        <provider android:name="androidx.startup.InitializationProvider"
            android:authorities="invalid.pending.app.androidx-startup" android:exported="false" />
        ${wakeReceiver ?? _wake()}
        $profileReceiver
        $extra
    </application>
</manifest>
''';

const _mainActivity = '''
<activity android:name="invalid.pending.app.MainActivity" android:exported="true"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>''';

String _filter(List<String> actions) =>
    '<intent-filter>${[for (final a in actions) '<action android:name="$a" />'].join()}</intent-filter>';

String _wake({
  String exported = 'android:exported="false"',
  String direct = 'android:directBootAware="true"',
  String name = 'invalid.pending.app.notifications.WakeReceiver',
  List<String> actions = _systemActions,
  String attrs = '',
}) =>
    '<receiver android:name="$name" $direct $exported $attrs>'
    '${_filter(actions)}</receiver>';

const _profileReceiver = '''
<receiver android:name="androidx.profileinstaller.ProfileInstallReceiver"
            android:directBootAware="false" android:enabled="true" android:exported="true"
            android:permission="android.permission.DUMP">
            <intent-filter><action android:name="androidx.profileinstaller.action.INSTALL_PROFILE" /></intent-filter>
            <intent-filter><action android:name="androidx.profileinstaller.action.SKIP_FILE" /></intent-filter>
        </receiver>''';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('perm_check_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run(String mode, String manifest) {
    final dir = Directory(
      '${tmp.path}/build/app/intermediates/merged_manifest/$mode/out',
    )..createSync(recursive: true);
    File('${dir.path}/AndroidManifest.xml').writeAsStringSync(manifest);
    return Process.runSync('bash', [
      File(_script).absolute.path,
      mode,
    ], workingDirectory: tmp.path);
  }

  void expectOk(String mode, String manifest) {
    final r = run(mode, manifest);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }

  void expectFails(String mode, String manifest, Pattern message) {
    final r = run(mode, manifest);
    expect(r.exitCode, isNot(0), reason: '${r.stdout}${r.stderr}');
    expect('${r.stdout}${r.stderr}', contains(message));
  }

  // CA-020-13: el script lee un manifiesto dado con `--manifest` (sin carpeta de Gradle) y
  // cuenta todas las formas de pedir un permiso y el filtro de la MainActivity.
  ProcessResult runArgs(List<String> args) => Process.runSync('bash', [
    File(_script).absolute.path,
    ...args,
  ], workingDirectory: tmp.path);

  ProcessResult runFile(String manifest, {String mode = 'release'}) {
    final file = File('${tmp.path}/AndroidManifest.test.xml')
      ..writeAsStringSync(manifest);
    return runArgs([mode, '--manifest', file.path]);
  }

  void expectFileOk(String manifest, {String mode = 'release'}) {
    final r = runFile(manifest, mode: mode);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }

  void expectFileFails(String manifest, Object message) {
    final r = runFile(manifest);
    expect(r.exitCode, isNot(0), reason: '${r.stdout}${r.stderr}');
    expect(
      '${r.stdout}${r.stderr}',
      message is Pattern ? contains(message) : message,
    );
  }

  /// La MainActivity de siempre con otro contenido en sus `<intent-filter>`.
  String activityWith(String filters) =>
      '<activity android:name="invalid.pending.app.MainActivity" android:exported="true">'
      '<meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />'
      '$filters</activity>';

  const mainAction = '<action android:name="android.intent.action.MAIN" />';
  const launcher =
      '<category android:name="android.intent.category.LAUNCHER" />';

  group('CA-020-13: --manifest', () {
    test('CA-020-13: un manifiesto dado se revisa sin carpeta de Gradle', () {
      expectFileOk(_manifest());
      expectFileOk(_manifest(), mode: 'debug');
      // Sin la opción, y sin build/, sigue pidiendo compilar.
      final r = runArgs(['release']);
      expect(r.exitCode, isNot(0));
      expect('${r.stdout}${r.stderr}', contains('flutter build apk'));
    });

    test('CA-020-13: sin el archivo, vacío o sin <manifest> falla cerrado', () {
      final missing = runArgs([
        'release',
        '--manifest',
        '${tmp.path}/no-existe.xml',
      ]);
      expect(missing.exitCode, isNot(0));
      expect(
        '${missing.stdout}${missing.stderr}',
        allOf(contains('No se puede leer'), contains('no-existe.xml')),
      );
      for (final body in ['', '   \n', '<application/>']) {
        expectFileFails(body, contains('AndroidManifest.test.xml'));
      }
    });

    test('CA-020-13: argumentos desconocidos o --manifest sin valor → uso', () {
      for (final args in [
        ['release', '--manifest'],
        ['release', '--otra'],
        ['profile'],
      ]) {
        final r = runArgs(args);
        expect(r.exitCode, 2, reason: '$args ${r.stdout}${r.stderr}');
      }
    });
  });

  group('CA-020-13: todas las formas de pedir un permiso', () {
    test(
      'CA-020-13: <uses-permission-sdk-23> y -sdk-m de más fallan nombrándolos',
      () {
        for (final tag in [
          'uses-permission',
          'uses-permission-sdk-23',
          'uses-permission-sdk-m',
        ]) {
          expectFileFails(
            _manifest(
              extra: '<$tag android:name="android.permission.READ_CONTACTS" />',
            ),
            allOf(contains('Permiso no permitido'), contains('READ_CONTACTS')),
          );
        }
      },
    );

    test('CA-020-13: la etiqueta repartida en líneas o con comillas simples también cuenta', () {
      expectFileFails(
        _manifest(
          extra: '<uses-permission-sdk-m\n   android:maxSdkVersion="30"\n   android:name="android.permission.CAMERA" />',
        ),
        contains('android.permission.CAMERA'),
      );
      expectFileFails(
        _manifest(
          extra: "<uses-permission android:name='android.permission.CAMERA'/>",
        ),
        contains('android.permission.CAMERA'),
      );
    });

    test('CA-020-13: una etiqueta sin android:name legible falla', () {
      expectFileFails(
        _manifest(extra: '<uses-permission-sdk-m />'),
        allOf(contains('uses-permission-sdk-m'), contains('sin android:name')),
      );
    });

    test('CA-020-13: un permiso solo dentro de un comentario no cuenta', () {
      expectFileOk(
        _manifest(
          extra: '<!-- <uses-permission android:name="android.permission.CAMERA" /> -->',
        ),
      );
    });

    test(
      'CA-020-13: los permisos permitidos valen en cualquiera de las formas',
      () {
        expectFileOk(
          _manifest(
            extra: '<uses-permission-sdk-23 android:name="android.permission.INTERNET" />',
          ),
        );
      },
    );
  });

  group('CA-020-13: el filtro de la MainActivity', () {
    test(
      'CA-020-13: un solo filtro MAIN + LAUNCHER pasa (también multilínea)',
      () {
        expectFileOk(
          _manifest(
            mainActivity: activityWith(
              '<intent-filter>\n  $mainAction\n\n  $launcher\n</intent-filter>',
            ),
          ),
        );
      },
    );

    test('CA-020-13: un segundo <intent-filter> falla', () {
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction$launcher</intent-filter>'
            '<intent-filter>$mainAction$launcher</intent-filter>',
          ),
        ),
        contains('MainActivity'),
      );
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction$launcher</intent-filter>'
            '<intent-filter><action android:name="android.intent.action.VIEW" /></intent-filter>',
          ),
        ),
        allOf(contains('MainActivity'), contains('2 <intent-filter>')),
      );
    });

    test('CA-020-13: sin filtro, o un filtro vacío o autocerrado, falla', () {
      expectFileFails(
        _manifest(mainActivity: activityWith('')),
        contains('MainActivity'),
      );
      expectFileFails(
        _manifest(mainActivity: activityWith('<intent-filter />')),
        contains('MainActivity'),
      );
      expectFileFails(
        _manifest(
          mainActivity: activityWith('<intent-filter></intent-filter>'),
        ),
        contains('MAIN'),
      );
    });

    test('CA-020-13: un <data> falla nombrándolo (deep link)', () {
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction$launcher<data android:scheme="https" android:host="x.es" /></intent-filter>',
          ),
        ),
        contains('<data>'),
      );
    });

    test('CA-020-13: BROWSABLE, DEFAULT u otra categoría fallan nombrándola', () {
      for (final category in [
        'android.intent.category.BROWSABLE',
        'android.intent.category.DEFAULT',
        'android.intent.category.INFO',
      ]) {
        expectFileFails(
          _manifest(
            mainActivity: activityWith(
              '<intent-filter>$mainAction$launcher<category android:name="$category" /></intent-filter>',
            ),
          ),
          contains(category),
        );
      }
    });

    test('CA-020-13: una acción de más falla nombrándola', () {
      for (final action in [
        'android.intent.action.VIEW',
        'android.intent.action.SEND',
        'android.intent.action.MAIN2',
      ]) {
        expectFileFails(
          _manifest(
            mainActivity: activityWith(
              '<intent-filter>$mainAction<action android:name="$action" />$launcher</intent-filter>',
            ),
          ),
          contains(action),
        );
      }
    });

    test('CA-020-13: la MainActivity sin android:exported="true" falla', () {
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction$launcher</intent-filter>',
          ).replaceAll('android:exported="true"', 'android:exported="false"'),
        ),
        contains('android:exported="true"'),
      );
    });

    test('CA-020-13: sin MAIN o sin LAUNCHER falla', () {
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter><action android:name="android.intent.action.VIEW" />$launcher</intent-filter>',
          ),
        ),
        contains('acción android.intent.action.MAIN'),
      );
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction<category android:name="android.intent.category.DEFAULT" /></intent-filter>',
          ),
        ),
        contains('categoría android.intent.category.LAUNCHER'),
      );
    });

    test('CA-020-13: autoVerify u otro elemento hijo en el filtro falla', () {
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter android:autoVerify="true">$mainAction$launcher</intent-filter>',
          ),
        ),
        contains('autoVerify'),
      );
      expectFileFails(
        _manifest(
          mainActivity: activityWith(
            '<intent-filter>$mainAction$launcher<uri-relative-filter-group /></intent-filter>',
          ),
        ),
        contains('uri-relative-filter-group'),
      );
    });

    test('CA-020-13: un filtro dentro de un comentario no cuenta', () {
      expectFileOk(
        _manifest(
          mainActivity: activityWith(
            '<!-- <intent-filter><data android:scheme="x" /></intent-filter> -->'
            '<intent-filter>$mainAction$launcher</intent-filter>',
          ),
        ),
      );
    });

    test('CA-020-13: los filtros de otros componentes no se cuentan en la MainActivity', () {
      // El WakeReceiver y el ProfileInstallReceiver llevan varios filtros y el manifiesto base pasa.
      expectFileOk(_manifest());
    });
  });

  group('CA-020-13: manifiestos negativos de tools/fixtures/manifests/', () {
    const dir = '../tools/fixtures/manifests';

    test('CA-020-13: el manifiesto bueno pasa en release y en debug', () {
      final ok = File('$dir/ok.xml').readAsStringSync();
      expectFileOk(ok);
      expectFileOk(ok, mode: 'debug');
    });

    test('CA-020-13: cada manifiesto negativo falla nombrando lo suyo', () {
      final lines = File('$dir/expected.tsv')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(lines.length, greaterThanOrEqualTo(9));
      for (final line in lines) {
        final parts = line.split('\t');
        expect(parts, hasLength(2), reason: line);
        final r = runFile(File('$dir/${parts[0]}').readAsStringSync());
        expect(r.exitCode, isNot(0), reason: '${parts[0]}: ${r.stdout}');
        expect('${r.stdout}${r.stderr}', contains(parts[1]), reason: parts[0]);
      }
      // Ningún .xml se queda sin su línea (no hay un negativo que nadie ejecuta).
      final listed = {for (final l in lines) l.split('\t').first};
      final xml = Directory(dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.endsWith('.xml') && n != 'ok.xml');
      expect(listed, containsAll(xml));
    });

    // --negative es la comprobación de la CI: se prueba que ella misma falla cuando el conjunto
    // de manifiestos está mal (copia del script con sus manifiestos en una carpeta temporal).
    ProcessResult negativeIn(void Function(Directory manifests) tamper) {
      final root = Directory('${tmp.path}/copy/tools')
        ..createSync(recursive: true);
      File(_script).copySync('${root.path}/check-android-permissions.sh');
      final manifests = Directory('${root.path}/fixtures/manifests')
        ..createSync(recursive: true);
      for (final f in Directory(dir).listSync().whereType<File>()) {
        f.copySync('${manifests.path}/${f.uri.pathSegments.last}');
      }
      tamper(manifests);
      return Process.runSync('bash', [
        '${root.path}/check-android-permissions.sh',
        '--negative',
      ], workingDirectory: tmp.path);
    }

    test('CA-020-13: --negative falla si un negativo pasa, no nombra lo suyo o no está listado', () {
      // Sin tocar nada, la copia pasa (la prueba de la propia copia).
      expect(negativeIn((_) {}).exitCode, 0);

      final passes = negativeIn((m) {
        File('${m.path}/permission-extra.xml')
            .writeAsStringSync(File('${m.path}/ok.xml').readAsStringSync());
      });
      expect(passes.exitCode, isNot(0));
      expect('${passes.stdout}', contains('permission-extra.xml'));

      final wrongText = negativeIn((m) {
        final tsv = File('${m.path}/expected.tsv');
        tsv.writeAsStringSync(
          tsv.readAsStringSync().replaceFirst(
            'android.permission.READ_EXTERNAL_STORAGE',
            'otra.cosa',
          ),
        );
      });
      expect(wrongText.exitCode, isNot(0));
      expect('${wrongText.stdout}', contains('otra.cosa'));

      final unlisted = negativeIn((m) {
        File('${m.path}/nuevo.xml').writeAsStringSync(
          File('${m.path}/permission-extra.xml').readAsStringSync(),
        );
      });
      expect(unlisted.exitCode, isNot(0));
      expect('${unlisted.stdout}', contains('nuevo.xml'));

      final badOk = negativeIn((m) {
        File(
          '${m.path}/ok.xml',
        ).writeAsStringSync(File('${m.path}/main-data.xml').readAsStringSync());
      });
      expect(badOk.exitCode, isNot(0));
      expect('${badOk.stdout}', contains('ok.xml'));
    });

    test('CA-020-13: --negative recorre los mismos y termina bien', () {
      final r = runArgs(['--negative']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}', contains('manifiestos negativos'));
    });
  });

  group('CA-019-25: permisos', () {
    test(
      'release y debug con los tres permisos y los componentes esperados',
      () {
        expectOk('release', _manifest());
        expectOk('debug', _manifest());
      },
    );

    test('un permiso de alarma exacta falla (y cualquier otro no listado)', () {
      for (final extra in [
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WAKE_LOCK',
      ]) {
        expectFails(
          'release',
          _manifest(
            permissions: [
              'android.permission.INTERNET',
              'android.permission.POST_NOTIFICATIONS',
              'android.permission.RECEIVE_BOOT_COMPLETED',
              extra,
            ],
          ),
          'Permiso no permitido',
        );
      }
    });

    test('faltar un permiso permitido no falla (solo sobrar uno)', () {
      expectOk(
        'release',
        _manifest(permissions: ['android.permission.INTERNET']),
      );
    });
  });

  group('CA-019-25: lista blanca de componentes', () {
    test('un receptor exportado falla', () {
      expectFails(
        'release',
        _manifest(wakeReceiver: _wake(exported: 'android:exported="true"')),
        'WakeReceiver',
      );
    });

    test('un receptor sin android:exported falla', () {
      expectFails(
        'release',
        _manifest(wakeReceiver: _wake(exported: '')),
        'WakeReceiver',
      );
    });

    test('un receptor sin directBootAware="true" falla', () {
      for (final direct in ['', 'android:directBootAware="false"']) {
        expectFails(
          'release',
          _manifest(wakeReceiver: _wake(direct: direct)),
          'directBootAware',
        );
      }
    });

    test('si falta el WakeReceiver falla', () {
      expectFails('release', _manifest(wakeReceiver: ''), 'WakeReceiver');
    });

    test('la acción de la alarma en un <intent-filter> falla', () {
      expectFails(
        'release',
        _manifest(
          wakeReceiver: _wake(actions: [..._systemActions, _alarmAction]),
        ),
        'acción',
      );
      expectFails(
        'release',
        _manifest(
          extra:
              '<activity android:name="x.Other" android:exported="false">${_filter([_alarmAction])}</activity>',
        ),
        _alarmAction,
      );
    });

    test('una acción del sistema fuera de la lista falla', () {
      expectFails(
        'release',
        _manifest(
          wakeReceiver: _wake(
            actions: [
              ..._systemActions,
              'android.intent.action.QUICKBOOT_POWERON',
            ],
          ),
        ),
        'acción',
      );
    });

    test('un receptor, servicio o actividad desconocidos fallan', () {
      expectFails(
        'release',
        _manifest(
          extra: '<receiver android:name="com.evil.Receiver" android:exported="false" />',
        ),
        'com.evil.Receiver',
      );
      expectFails(
        'release',
        _manifest(
          extra: '<service android:name="com.evil.Service" android:exported="false" />',
        ),
        'com.evil.Service',
      );
      expectFails(
        'release',
        _manifest(
          extra: '<activity android:name="com.evil.Activity" android:exported="false" />',
        ),
        'com.evil.Activity',
      );
    });

    test('ProfileInstallReceiver sin el permiso DUMP falla', () {
      expectFails(
        'release',
        _manifest(
          profileReceiver: _profileReceiver.replaceAll(
            'android:permission="android.permission.DUMP"',
            '',
          ),
        ),
        'ProfileInstallReceiver',
      );
    });

    test('MainActivity debe ser la única actividad exportada', () {
      expectFails(
        'release',
        _manifest(
          extra: '<activity android:name="io.flutter.plugins.urllauncher.WebViewActivity" android:exported="true" />',
        ),
        'WebViewActivity',
      );
    });

    test('el <provider> exportado sigue fallando', () {
      expectFails(
        'release',
        _manifest(
          extra: '<provider android:name="x.P" android:authorities="a" android:exported="true" />',
        ),
        'provider',
      );
    });
  });
}
