import 'dart:convert';
import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Claves **nuevas** de la tabla "Textos (ES / EN)" de la spec 015 (§7),
/// copiadas tal cual. `menuSettings` y `settingsClose` cambian de texto en
/// T-015-09 y `settingsPrivacy` ya existe; las retiradas, en T-015-11.
const _spec015 = <String, (String, String)>{
  'settingsTitle': ('Ajustes', 'Settings'),
  'settingsLanguage': ('Idioma', 'Language'),
  'settingsLanguageSystem': ('Como el sistema', 'Same as system'),
  'languageSpanish': ('Español', 'Español'),
  'languageEnglish': ('English', 'English'),
  'settingsKeepAwake': ('Pantalla siempre activa', 'Keep screen on'),
  'settingsKeepAwakeHint': (
    'Imágenes, documentos y web',
    'Images, documents and web',
  ),
  'settingsInfo': ('Información', 'Information'),
  'settingsThirdPartyLicenses': (
    'Licencias de terceros',
    'Third-party licenses',
  ),
  'settingsHelp': ('Ayuda', 'Help'),
  'settingsOpensWebHint': (
    'Abre una página web en el navegador',
    'Opens a web page in the browser',
  ),
  'settingsSaveError': (
    'No se pudo guardar el ajuste.',
    "Couldn't save the setting.",
  ),
  // «Volver» del nivel 2: la clave la decide el plan (§7 de la spec).
  'settingsBack': ('Volver', 'Back'),
};

void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-015-27: las claves nuevas de la spec 015 están tal cual en las ARB '
      'ES y EN, con descripción que cita su CA', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _spec015.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
      for (final arb in [es, en]) {
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta, isNotNull, reason: '@$k');
        expect(meta!['description'], contains('CA-015-'), reason: '@$k');
      }
    }
  });

  test('CA-015-27, CA-015-11: los nombres de los idiomas son iguales en las '
      'dos ARB (cada uno en su idioma) y salen de las clases generadas', () {
    for (final k in ['languageSpanish', 'languageEnglish']) {
      expect(es[k], en[k], reason: k);
    }
    expect(AppLocalizationsEs().languageSpanish, 'Español');
    expect(AppLocalizationsEs().languageEnglish, 'English');
    expect(AppLocalizationsEn().languageSpanish, 'Español');
    expect(AppLocalizationsEn().languageEnglish, 'English');
  });

  test('CA-015-27: las claves generadas dan el texto de cada idioma', () {
    final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();
    expect(l10nEs.settingsTitle, 'Ajustes');
    expect(l10nEn.settingsTitle, 'Settings');
    expect(l10nEs.settingsBack, 'Volver');
    expect(l10nEn.settingsBack, 'Back');
    expect(l10nEs.settingsOpensWebHint, 'Abre una página web en el navegador');
    expect(l10nEn.settingsSaveError, "Couldn't save the setting.");
  });

  test('CA-015-01a, CA-015-27: menuSettings y settingsClose cambian de texto '
      '(T-015-09); las claves de las licencias de la 012 se retiran en '
      'T-015-11, no antes', () {
    expect(es['menuSettings'], 'Ajustes');
    expect(en['menuSettings'], 'Settings');
    expect(es['settingsClose'], 'Cerrar ajustes');
    expect(en['settingsClose'], 'Close settings');
    for (final k in [
      'settingsLicenses',
      'settingsPrivacy',
      'settingsPrivacyHint',
      'licensesTitle',
      'licensesBack',
    ]) {
      expect(es.containsKey(k), isTrue, reason: k);
      expect(en.containsKey(k), isTrue, reason: k);
    }
  });

  test('CA-015-03, CA-015-19: los tokens nuevos del interruptor y de las filas '
      'salen de tokens.json (plan §2)', () {
    expect(UnaColors.switchOn, const Color(0xFFFFDC58));
    expect(UnaSizes.switchWidth, 54);
    expect(UnaSizes.switchHeight, 32);
    expect(UnaSizes.switchKnob, 22);
    expect(UnaSizes.switchKnobInset, 2);
    expect(UnaSizes.switchKnobTravel, 22);
    expect(UnaBorders.switchTrackWidth, 3);
    expect(UnaBorders.switchKnobWidth, 2);
    expect(UnaBorders.switchTrackRadius, 8);
    expect(UnaBorders.switchKnobRadius, 4);
    expect(UnaSizes.settingsRow, 60);
    expect(UnaSizes.settingsRowSwitch, 64);
    expect(UnaSizes.settingsRowSwitchHint, 76);
    expect(UnaSizes.settingsRowSub, 52);
    expect(UnaSizes.settingsRowSubIndent, 38);
    expect(UnaSizes.separatorBlock, 4);
    expect(UnaSizes.separatorRow, 1);
  });
}
