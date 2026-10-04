import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Tabla "Textos (ES / EN)" de la spec 014 (§7), copiada tal cual.
const _spec014 = <String, (String, String)>{
  'undoDeletedTitle': ('Tarea eliminada', 'Task deleted'),
  'undoButton': ('Deshacer', 'Undo'),
  'undoA11yLabel': (
    'Deshacer. Tarea eliminada: {label}',
    'Undo. Task deleted: {label}',
  ),
  'a11yUndone': ('Tarea recuperada', 'Task restored'),
  'undoError': (
    'No hemos podido recuperar la tarea',
    "We couldn't restore the task",
  ),
};

/// Claves que se reutilizan y cuyas descripciones dejan de mencionar la hoja
/// de confirmación (spec 014 §7).
const _reused = [
  'deleteA11yAction',
  'menuDelete',
  'deleteError',
  'editorCancel',
];

void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-014-03, CA-014-16, CA-014-18, CA-014-23, spec 014 §7: los textos '
      'ES y EN están tal cual en las ARB, con descripción', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _spec014.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
      final meta = es['@$k'] as Map<String, dynamic>;
      expect(meta['description'], contains('CA-014-'), reason: '@$k');
    }
  });

  test('CA-014-16: undoA11yLabel declara {label} (String) y lo sustituye '
      'completo', () {
    final meta = es['@undoA11yLabel'] as Map<String, dynamic>;
    final placeholders = meta['placeholders'] as Map<String, dynamic>;
    expect(placeholders.keys, ['label']);
    expect((placeholders['label'] as Map<String, dynamic>)['type'], 'String');

    final long = 'a' * 10000;
    expect(
      AppLocalizationsEs().undoA11yLabel('Comprar pan'),
      'Deshacer. Tarea eliminada: Comprar pan',
    );
    expect(
      AppLocalizationsEn().undoA11yLabel('Buy bread'),
      'Undo. Task deleted: Buy bread',
    );
    expect(AppLocalizationsEs().undoA11yLabel(long), endsWith(long));
  });

  test('CA-014-16, WCAG 2.5.3: la lectura de la card empieza por el texto '
      'visible del botón, en ES y en EN', () {
    for (final l10n in [AppLocalizationsEs(), AppLocalizationsEn()]) {
      expect(
        l10n.undoA11yLabel('x'),
        startsWith('${l10n.undoButton}. ${l10n.undoDeletedTitle}: '),
        reason: l10n.localeName,
      );
    }
  });

  test('CA-014-18, CA-014-23: anuncio y aviso de error salen de las ARB', () {
    expect(AppLocalizationsEs().a11yUndone, 'Tarea recuperada');
    expect(AppLocalizationsEn().a11yUndone, 'Task restored');
    expect(
      AppLocalizationsEs().undoError,
      'No hemos podido recuperar la tarea',
    );
    expect(AppLocalizationsEn().undoError, "We couldn't restore the task");
  });

  test('CA-014-01, CA-014-19, spec 014 §7: las descripciones de las claves '
      'reutilizadas ya no mencionan la hoja de confirmación', () {
    for (final k in _reused) {
      final meta = es['@$k'] as Map<String, dynamic>;
      final description = meta['description'] as String;
      expect(description, isNot(contains('confirmaci')), reason: '@$k');
      if (en['@$k'] case final Map<String, dynamic> enMeta) {
        expect(
          enMeta['description'] as String,
          isNot(contains('confirmaci')),
          reason: 'EN @$k',
        );
      }
    }
  });
}
