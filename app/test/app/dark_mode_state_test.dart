import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec 021, CA-021-07. T-021-02 solo fija la parte de fuente: la actividad no se recrea al
/// cambiar el modo del sistema porque `configChanges` incluye `uiMode`. Los tests de widgets
/// (estado conservado al cambiar el brillo) los añade T-021-05.
void main() {
  test('CA-021-07: configChanges del manifiesto contiene uiMode (no se recrea la actividad)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final value = RegExp(r'android:configChanges="([^"]*)"')
        .firstMatch(manifest)
        ?.group(1);
    expect(value, isNotNull);
    expect(value!.split('|'), contains('uiMode'));
  });
}
