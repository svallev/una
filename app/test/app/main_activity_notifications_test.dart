import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CA-019-19a, 20, P-019-14: el cableado de `MainActivity.kt` con las
/// notificaciones. La lógica pura tiene sus JUnit (`ForegroundTrackerTest`,
/// `PermissionRequestsTest`, `ActivationNonceTest`); aquí se vigila que la
/// actividad llame a cada pieza en el gancho correcto, que no se puede probar
/// en la JVM sin Android. El comportamiento real se mira en T-019-14.
void main() {
  final source = File(
    'android/app/src/main/kotlin/invalid/pending/app/MainActivity.kt',
  ).readAsStringSync();

  /// El cuerpo de `override fun <name>(…) { … }` (llaves equilibradas).
  String body(String name) {
    final start = source.indexOf(RegExp('override fun $name\\('));
    expect(start, isNonNegative, reason: 'falta override $name');
    final open = source.indexOf('{', source.indexOf(')', start));
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}' && --depth == 0) return source.substring(open, i);
    }
    fail('llaves sin cerrar en $name');
  }

  test('CA-019-19a: onStop limpia el indicador y onPause no lo toca', () {
    expect(body('onStop'), contains('notifications?.onStop()'));
    expect(body('onPause'), isNot(contains('notifications')));
  });

  test('CA-019-19a: onResume lo restaura por el canal', () {
    expect(body('onResume'), contains('notifications?.onResume()'));
  });

  test('CA-019-20: onNewIntent lo pasa al canal, que comprueba el nonce', () {
    expect(body('onNewIntent'), contains('notifications?.onNewIntent(intent)'));
    final channel = File(
      'android/app/src/main/kotlin/invalid/pending/app/notifications/NotificationsChannel.kt',
    ).readAsStringSync();
    expect(channel, contains('ActivationNonce.accept(intent.action'));
    expect(channel, contains('invokeMethod("openCurrentTask"'));
  });

  test('P-019-14: el foco y el resultado del permiso llegan al canal', () {
    expect(
      body('onWindowFocusChanged'),
      contains('notifications?.onWindowFocusChanged(hasFocus)'),
    );
    expect(
      body('onRequestPermissionsResult'),
      contains('notifications?.onPermissionResult(requestCode, grantResults)'),
    );
  });

  test(
    'plan §3.5: al limpiar el motor, una petición pendiente se abandona',
    () {
      expect(
        body('cleanUpFlutterEngine'),
        contains('notifications?.dispose()'),
      );
    },
  );

  test('CA-019-23: el canal no contesta con el texto de ningún error', () {
    // Sin comentarios: el KDoc menciona `result.error(code, null, null)`.
    final channel =
        File(
              'android/app/src/main/kotlin/invalid/pending/app/notifications/NotificationsChannel.kt',
            )
            .readAsLinesSync()
            .where((l) => !RegExp(r'^\s*(\*|/\*|//)').hasMatch(l))
            .join('\n');
    // Todos los `result.error` van con mensaje y detalles nulos.
    final errors = RegExp(r'result\.error\(([^)]*)\)').allMatches(channel);
    expect(errors, isNotEmpty);
    for (final m in errors) {
      expect(m.group(1), endsWith(', null, null'), reason: m.group(0));
    }
  });
}
