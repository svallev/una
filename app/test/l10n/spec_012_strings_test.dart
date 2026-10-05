import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// De la tabla de textos de la spec 012 (§7) solo queda `settingsPrivacy`: la
/// 015 retiró las claves de las pantallas de licencias y `settingsPrivacyHint`
/// (T-015-11; ver `spec_015_strings_test.dart`).
void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-012-11: settingsPrivacy está tal cual en las ARB y con su CA', () {
    expect(es['settingsPrivacy'], 'Política de privacidad');
    expect(en['settingsPrivacy'], 'Privacy policy');
    final meta = es['@settingsPrivacy'] as Map<String, dynamic>;
    expect(meta['description'] as String, matches(RegExp(r'CA-012-\d\d')));
  });
}
