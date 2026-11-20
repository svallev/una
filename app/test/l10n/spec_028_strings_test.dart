import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Las **3** claves nuevas de la tabla «Textos (ES / EN)» de la spec 028 (§7), copiadas tal cual:
/// (ES, EN). El texto del permiso de cámara de iOS no es un ARB (va en `InfoPlist.strings`).
const _spec028 = <String, (String, String)>{
  'errCameraDenied': (
    'La cámara no tiene permiso. Puedes darlo en los Ajustes del iPhone.',
    'The camera has no permission. You can allow it in iPhone Settings.',
  ),
  'errCameraDeniedOpenSettings': ('Abrir Ajustes', 'Open Settings'),
  'settingsNotificationsPrivacyIos': (
    'La notificación muestra tu tarea actual. Con el iPhone bloqueado, iOS '
        'solo la enseña si permites las previsualizaciones siempre.',
    'The notification shows your current task. When your iPhone is locked, '
        'iOS only shows it if you always allow previews.',
  ),
};

void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-028-10, CA-028-16: las tres claves nuevas están tal cual en las '
      'ARB ES y EN y la plantilla las describe citando su CA', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _spec028.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
      final meta = es['@$k'] as Map<String, dynamic>?;
      expect(meta, isNotNull, reason: '@$k');
      expect(meta!['description'], contains('CA-028-'), reason: '@$k');
      expect(meta.containsKey('placeholders'), isFalse, reason: '@$k');
    }
  });

  test('CA-028-10, CA-028-16: solo esas tres claves citan CA-028 en su '
      'descripción (las del resto de specs no se tocan)', () {
    final withCa028 = [
      for (final e in es.entries)
        if (e.key.startsWith('@') &&
            e.value is Map &&
            (e.value as Map)['description'].toString().contains('CA-028-'))
          e.key.substring(1),
    ]..sort();
    expect(withCa028, _spec028.keys.toList()..sort());
  });

  test('CA-028-10, CA-028-16: las clases generadas dan el texto de cada '
      'idioma', () {
    final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();
    expect(l10nEs.errCameraDenied, _spec028['errCameraDenied']!.$1);
    expect(l10nEn.errCameraDenied, _spec028['errCameraDenied']!.$2);
    expect(l10nEs.errCameraDeniedOpenSettings, 'Abrir Ajustes');
    expect(l10nEn.errCameraDeniedOpenSettings, 'Open Settings');
    expect(
      l10nEs.settingsNotificationsPrivacyIos,
      _spec028['settingsNotificationsPrivacyIos']!.$1,
    );
    expect(
      l10nEn.settingsNotificationsPrivacyIos,
      _spec028['settingsNotificationsPrivacyIos']!.$2,
    );
  });

  test('CA-028-16: la línea de iOS no sustituye a la de Android '
      '(siguen las dos)', () {
    expect(es['settingsNotificationsPrivacy'], isNot(contains('iPhone')));
    expect(en['settingsNotificationsPrivacy'], isNot(contains('iPhone')));
  });
}
