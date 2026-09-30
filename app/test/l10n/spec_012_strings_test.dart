import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Tabla "Textos (ES / EN)" de la spec 012 (§7), copiada tal cual.
/// `licensesCount` (plural ICU) se comprueba aparte.
const _spec012 = <String, (String, String)>{
  'settingsClose': ('Cerrar', 'Close'),
  'settingsLicenses': ('Licencias de código abierto', 'Open-source licenses'),
  'settingsPrivacy': ('Política de privacidad', 'Privacy policy'),
  'settingsPrivacyHint': (
    'Abre una página web en el navegador',
    'Opens a web page in the browser',
  ),
  'licensesTitle': ('Licencias de código abierto', 'Open-source licenses'),
  'licensesLoading': ('Cargando licencias…', 'Loading licenses…'),
  'licensesBack': ('Volver', 'Back'),
  'licensesError': (
    'No se pudieron cargar las licencias.',
    "Couldn't load the licenses.",
  ),
};

/// `licensesTextOf` (enmienda de la spec §7, propietario, 2026-09-30): lleva
/// placeholders, así que se comprueba aparte con su plantilla.
const _licensesTextOf = ('Licencia {n} de {total}', 'License {n} of {total}');

void main() {
  final es = _arb('es'), en = _arb('en');

  test(
    'CA-012-11, spec 012 §7: los textos ES y EN están tal cual en las ARB',
    () {
      for (final MapEntry(key: k, value: (esText, enText))
          in _spec012.entries) {
        expect(es[k], esText, reason: 'ES $k');
        expect(en[k], enText, reason: 'EN $k');
      }
      expect(es['licensesCount'], contains('plural'));
      expect(en['licensesCount'], contains('plural'));
    },
  );

  test('CA-012-11: cada clave nueva tiene descripción que cita su CA', () {
    for (final k in [..._spec012.keys, 'licensesCount', 'licensesTextOf']) {
      final meta = es['@$k'] as Map<String, dynamic>?;
      expect(meta, isNotNull, reason: '@$k');
      expect(
        meta!['description'] as String,
        matches(RegExp(r'CA-012-\d\d')),
        reason: 'descripción de $k',
      );
    }
    final count = es['@licensesCount'] as Map<String, dynamic>;
    expect(count['placeholders'], contains('count'));
  });

  test(
    'CA-012-11: licensesCount usa plural ICU (1 licencia / N licencias)',
    () {
      final esL = AppLocalizationsEs(), enL = AppLocalizationsEn();
      expect(esL.licensesCount(1), '1 licencia');
      expect(esL.licensesCount(2), '2 licencias');
      expect(esL.licensesCount(0), '0 licencias');
      expect(enL.licensesCount(1), '1 license');
      expect(enL.licensesCount(31), '31 licenses');
    },
  );

  test('CA-012-03: licensesTextOf ("Licencia {n} de {total}") está en las ARB y se rellena', () {
    expect(es['licensesTextOf'], _licensesTextOf.$1);
    expect(en['licensesTextOf'], _licensesTextOf.$2);
    final meta = es['@licensesTextOf'] as Map<String, dynamic>;
    expect(meta['placeholders'], allOf(contains('n'), contains('total')));
    expect(AppLocalizationsEs().licensesTextOf(2, 3), 'Licencia 2 de 3');
    expect(AppLocalizationsEn().licensesTextOf(2, 3), 'License 2 of 3');
  });

  test('CA-012-01: menuSettings sigue siendo el texto del menú', () {
    expect(es['menuSettings'], 'Configuración y perfil');
    expect(en['menuSettings'], 'Settings and profile');
  });
}
