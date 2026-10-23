import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec 024, CA-024-04, CL-024-12: la app **no** aparece en «Idiomas de la app» del sistema (no
/// declara `localeConfig` ni genera uno) y no recorta idiomas con `resConfigs`: el recurso
/// `values-ca` solo existe para que Android no reordene `ca-ES, en-US` (H-022-10).
const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _gradle = 'android/app/build.gradle.kts';
const _res = 'android/app/src/main/res';

String _stripXmlComments(String s) =>
    s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _stripGradleComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('CA-024-04: el manifiesto no declara android:localeConfig', () {
    expect(
      _stripXmlComments(File(_manifest).readAsStringSync()),
      isNot(contains('localeConfig')),
    );
  });

  test('CA-024-04: Gradle no genera localeConfig ni recorta idiomas', () {
    final gradle = _stripGradleComments(File(_gradle).readAsStringSync());
    expect(gradle, isNot(contains('generateLocaleConfig')));
    expect(gradle, isNot(contains('resConfigs')));
    expect(gradle, isNot(contains('resourceConfigurations')));
    expect(gradle, isNot(contains('localeFilters')));
  });

  test('CA-024-04: ningún recurso de la app es un locales_config', () {
    final files = Directory(_res)
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.contains('locale'));
    expect(files, isEmpty);
  });

  test('CA-024-04: existe values-ca con el mismo texto que values-es', () {
    final ca = File('$_res/values-ca/notification_strings.xml');
    final es = File('$_res/values-es/notification_strings.xml');
    expect(ca.existsSync(), isTrue, reason: 'Falta values-ca (H-022-10)');
    expect(ca.readAsStringSync(), es.readAsStringSync());
  });
}
