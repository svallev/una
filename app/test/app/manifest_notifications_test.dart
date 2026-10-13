import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El manifiesto de la app y sus avisos (spec 019, CA-019-11, 13, 25): permisos exactos,
/// un único receptor no exportado y sin alarmas exactas. El manifiesto **combinado** (con lo
/// que añaden las dependencias) lo vigila `tools/check-android-permissions.sh`.
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _kotlin = 'android/app/src/main/kotlin/invalid/pending/app/notifications';

String _manifest() =>
    File(_manifestPath)
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _attr(String tag, String name) =>
    RegExp('android:$name="([^"]*)"').firstMatch(tag)?.group(1) ?? '';

/// La etiqueta de apertura y el cuerpo del primer `<receiver>` de nombre [name].
({String open, String body}) _receiver(String xml, String name) {
  final m = RegExp(
    '(<receiver\\b[^>]*android:name="$name"[^>]*>)(.*?)</receiver>',
    dotAll: true,
  ).firstMatch(xml);
  expect(m, isNotNull, reason: 'Falta el <receiver> $name');
  return (open: m!.group(1)!, body: m.group(2)!);
}

const _systemBroadcasts = {
  'android.intent.action.LOCKED_BOOT_COMPLETED',
  'android.intent.action.BOOT_COMPLETED',
  'android.intent.action.TIME_SET',
  'android.intent.action.TIMEZONE_CHANGED',
  'android.intent.action.LOCALE_CHANGED',
  'android.intent.action.MY_PACKAGE_REPLACED',
};

void main() {
  group('CA-019-25: permisos del manifiesto', () {
    test(
      'son exactamente INTERNET, POST_NOTIFICATIONS y RECEIVE_BOOT_COMPLETED',
      () {
        final perms = RegExp(r'<uses-permission\b[^>]*android:name="([^"]+)"')
            .allMatches(_manifest())
            .map((m) => m.group(1))
            .toSet();
        expect(perms, {
          'android.permission.INTERNET',
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.RECEIVE_BOOT_COMPLETED',
        });
      },
    );

    test('ninguno para alarmas exactas ni para despertar el móvil', () {
      final xml = _manifest();
      for (final banned in [
        'SCHEDULE_EXACT_ALARM',
        'USE_EXACT_ALARM',
        'WAKE_LOCK',
        'USE_FULL_SCREEN_INTENT',
        'FOREGROUND_SERVICE',
      ]) {
        expect(xml, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('CA-019-13 y 25: el receptor de los despertares', () {
    test(
      'un solo receptor, no exportado y consciente del arranque directo',
      () {
        final xml = _manifest();
        expect(RegExp(r'<receiver\b').allMatches(xml), hasLength(1));
        final r = _receiver(xml, '.notifications.WakeReceiver');
        expect(_attr(r.open, 'exported'), 'false');
        expect(_attr(r.open, 'directBootAware'), 'true');
        expect(_attr(r.open, 'permission'), isEmpty);
      },
    );

    test('solo escucha las seis difusiones protegidas del sistema', () {
      final r = _receiver(_manifest(), '.notifications.WakeReceiver');
      final actions = RegExp(r'<action\b[^>]*android:name="([^"]+)"')
          .allMatches(r.body)
          .map((m) => m.group(1))
          .toSet();
      expect(actions, _systemBroadcasts);
    });

    test('las seis son las que el Kotlin acepta (lista blanca)', () {
      final kotlin = File('$_kotlin/WakeActions.kt').readAsStringSync();
      for (final action in _systemBroadcasts) {
        expect(kotlin, contains('"$action"'), reason: action);
      }
    });

    test('la acción de la alarma propia no está en ningún <intent-filter>', () {
      final kotlin = File('$_kotlin/WakeActions.kt').readAsStringSync();
      final alarm = RegExp(r'const val ALARM\s*=\s*"([^"]+)"')
          .firstMatch(kotlin)
          ?.group(1);
      expect(alarm, isNotNull);
      expect(_manifest(), isNot(contains(alarm)));
      // La alarma llega por un PendingIntent explícito, no por un filtro.
      final manifest = _manifest();
      final filters = RegExp(
        r'<intent-filter\b.*?</intent-filter>',
        dotAll: true,
      ).allMatches(manifest).map((m) => m.group(0)!).join();
      expect(filters, isNot(contains('NOTIFICATION_ALARM')));
    });

    test('sin servicios y con una sola actividad propia', () {
      final xml = _manifest();
      expect(RegExp(r'<service\b').hasMatch(xml), isFalse);
      expect(RegExp(r'<activity\b').allMatches(xml), hasLength(1));
    });
  });

  group('CA-019-11: sin alarmas exactas en el código', () {
    late String arm;
    setUpAll(() => arm = File('$_kotlin/AlarmArm.kt').readAsStringSync());

    String code() => arm
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');

    test('pide setAndAllowWhileIdle y nunca una exacta', () {
      expect(code(), contains('setAndAllowWhileIdle'));
      for (final banned in [
        'setExact',
        'setExactAndAllowWhileIdle',
        'setAlarmClock',
        'setRepeating',
        'setInexactRepeating',
      ]) {
        expect(code(), isNot(contains(banned)), reason: banned);
      }
    });

    test('el PendingIntent es explícito e inmutable', () {
      expect(code(), contains('FLAG_IMMUTABLE'));
      expect(code(), contains('WakeReceiver::class.java'));
      expect(code(), contains('getBroadcast'));
    });
  });

  test('CA-019-23: la copia derivada vive en el almacenamiento protegido '
      'del dispositivo (accesible antes del primer desbloqueo)', () {
    final store = File('$_kotlin/DerivedStore.kt').readAsStringSync();
    expect(store, contains('createDeviceProtectedStorageContext'));
    expect(store, contains('una_notifications'));
  });
}
