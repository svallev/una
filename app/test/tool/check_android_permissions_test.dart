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
