import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Claves **nuevas** de la tabla "Textos (ES / EN)" de la spec 017 (§7),
/// copiadas tal cual. `settingsSaveError` ya existe y no cambia.
const _spec017 = <String, (String, String)>{
  'settingsLockZoom': ('Bloquear zoom', 'Lock zoom'),
  'settingsLockZoomHint': (
    'Solo imágenes: sin zoom ni scroll',
    'Images only: no zoom or scroll',
  ),
};

void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-017-17: las claves nuevas de la spec 017 están tal cual en las ARB '
      'ES y EN, con descripción que cita su CA', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _spec017.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
      expect(es[k], isNot(en[k]), reason: 'ES y EN distintos: $k');
      for (final arb in [es, en]) {
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta, isNotNull, reason: '@$k');
        expect(meta!['description'], isA<String>(), reason: '@$k');
        expect(meta['description'] as String, isNotEmpty, reason: '@$k');
        expect(meta['description'], contains('CA-017-'), reason: '@$k');
      }
    }
  });

  test('CA-017-17: las claves generadas dan el texto de cada idioma', () {
    final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();
    expect(l10nEs.settingsLockZoom, 'Bloquear zoom');
    expect(l10nEn.settingsLockZoom, 'Lock zoom');
    expect(l10nEs.settingsLockZoomHint, 'Solo imágenes: sin zoom ni scroll');
    expect(l10nEn.settingsLockZoomHint, 'Images only: no zoom or scroll');
  });

  test('CA-017-04, CA-017-17: settingsSaveError no ha cambiado (la 017 '
      'reutiliza el aviso de la 015)', () {
    expect(es['settingsSaveError'], 'No se pudo guardar el ajuste.');
    expect(en['settingsSaveError'], "Couldn't save the setting.");
    expect(
      (es['@settingsSaveError'] as Map)['description'],
      contains('CA-015-25'),
    );
    expect(
      (en['@settingsSaveError'] as Map)['description'],
      contains('CA-015-25'),
    );
  });

  test('CA-017-17, CA-017-14: la 017 no añade más claves que las dos de la '
      'spec §7 (la tarea no gana textos)', () {
    // Los textos de la 017 son solo estas claves: ninguna otra menciona CA-017.
    for (final arb in [es, en]) {
      final withCa017 = [
        for (final e in arb.entries)
          if (e.key.startsWith('@') &&
              e.value is Map &&
              (e.value as Map)['description'].toString().contains('CA-017-'))
            e.key.substring(1),
      ]..sort();
      expect(withCa017, _spec017.keys.toList()..sort());
    }
  });

  test('CA-017-17: el glosario cita las dos claves de «Bloquear zoom»', () {
    final glossary = File('../docs/glossary.md').readAsStringSync();
    final row = glossary
        .split('\n')
        .firstWhere((l) => l.startsWith('| Bloquear zoom |'));
    for (final k in _spec017.keys) {
      expect(row, contains('`$k`'), reason: k);
    }
  });
}
