import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('CA-013-01, spec 013 §7: licensesAndroidLibraries, tal cual en ES y EN '
      'y con su descripción', () {
    expect(
      _arb('es')['licensesAndroidLibraries'],
      'Bibliotecas de Android (AndroidX, Kotlin)',
    );
    expect(
      _arb('en')['licensesAndroidLibraries'],
      'Android libraries (AndroidX, Kotlin)',
    );
    final meta =
        _arb('es')['@licensesAndroidLibraries'] as Map<String, dynamic>;
    expect(meta['description'], isNotEmpty);
    expect(
      AppLocalizationsEs().licensesAndroidLibraries,
      'Bibliotecas de Android (AndroidX, Kotlin)',
    );
    expect(
      AppLocalizationsEn().licensesAndroidLibraries,
      'Android libraries (AndroidX, Kotlin)',
    );
  });
}
