import 'dart:convert';
import 'dart:io';

import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_leaks.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Las **17** claves nuevas de la tabla "Textos (ES / EN)" de la spec 019 (§7), copiadas tal
/// cual: (ES, EN, placeholders del ARB de plantilla).
const _spec019 = <String, (String, String, Map<String, String>)>{
  'settingsNotifications': ('Notificaciones', 'Notifications', {}),
  'settingsNotificationsPerDay': (
    'Notificaciones al día',
    'Notifications per day',
    {},
  ),
  'settingsNotificationsOption': (
    '{count, plural, one{{count} notificación al día} '
        'other{{count} notificaciones al día}}',
    '{count, plural, one{{count} notification per day} '
        'other{{count} notifications per day}}',
    {'count': 'int'},
  ),
  'settingsNotificationsHelp1': (
    'La notificación será a las {time1}.',
    'The notification will be at {time1}.',
    {'time1': 'String'},
  ),
  'settingsNotificationsHelp2': (
    'Las notificaciones serán a las {time1} y a las {time2}.',
    'The notifications will be at {time1} and {time2}.',
    {'time1': 'String', 'time2': 'String'},
  ),
  'settingsNotificationsHelp3': (
    'Las notificaciones serán a las {time1}, a las {time2} y a las {time3}.',
    'The notifications will be at {time1}, {time2} and {time3}.',
    {'time1': 'String', 'time2': 'String', 'time3': 'String'},
  ),
  'settingsNotificationsBlocked': (
    'Las notificaciones están bloqueadas en los Ajustes del sistema.',
    'Notifications are blocked in your system settings.',
    {},
  ),
  'settingsNotificationsOpenSystem': (
    'Abrir los ajustes de notificaciones',
    'Open notification settings',
    {},
  ),
  'settingsNotificationsPrivacy': (
    'La notificación muestra tu tarea actual. Con el móvil bloqueado también '
        'se ve, salvo que ocultes el contenido sensible en los ajustes de tu '
        'móvil.',
    'The notification shows your current task. It also shows when your phone '
        "is locked, unless you hide sensitive content in your phone's "
        'settings.',
    {},
  ),
  'settingsNotificationsOpenError': (
    'No se pudieron abrir los Ajustes del sistema.',
    "Couldn't open system settings.",
    {},
  ),
  'settingsNotificationsEnabledAnnounce': (
    'Notificaciones activadas.',
    'Notifications on.',
    {},
  ),
  'settingsNotificationsAllowedAnnounce': (
    'Notificaciones permitidas.',
    'Notifications allowed.',
    {},
  ),
  'settingsNotificationsAllowedOnAnnounce': (
    'Notificaciones permitidas y activadas.',
    'Notifications allowed and turned on.',
    {},
  ),
  'notificationChannelName': ('Tarea actual', 'Current task', {}),
  'notificationChannelDescription': (
    'Te recuerda tu tarea actual 1, 2 o 3 veces al día, según elijas en '
        'Ajustes.',
    'Reminds you of your current task 1, 2 or 3 times a day, as set in '
        'Settings.',
    {},
  ),
  'notificationTitle': ('Tarea actual', 'Current task', {}),
  'notificationPublic': (
    'Tienes una tarea pendiente.',
    'You have a task waiting.',
    {},
  ),
};

/// Claves que la 019 reutiliza sin tocarlas (spec §7).
const _reused = <String, (String, String)>{
  'settingsSaveError': (
    'No se pudo guardar el ajuste.',
    "Couldn't save the setting.",
  ),
  'attachmentPhoto': ('Foto', 'Photo'),
  'attachmentImage': ('Imagen', 'Image'),
  'attachmentPdf': ('PDF', 'PDF'),
};

void main() {
  final es = _arb('es'), en = _arb('en');

  test('CA-019-27: son exactamente 17 claves nuevas (13 settings… y '
      '4 notification…)', () {
    expect(_spec019, hasLength(17));
    expect(_spec019.keys.where((k) => k.startsWith('settings')), hasLength(13));
    expect(
      _spec019.keys.where((k) => k.startsWith('notification')),
      hasLength(4),
    );
  });

  test('CA-019-27: las claves nuevas de la spec 019 están tal cual en las ARB '
      'ES y EN, con descripción que cita su CA', () {
    for (final MapEntry(key: k, value: (esText, enText, _))
        in _spec019.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
      for (final arb in [es, en]) {
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta, isNotNull, reason: '@$k');
        expect(meta!['description'], isA<String>(), reason: '@$k');
        expect(meta['description'] as String, isNotEmpty, reason: '@$k');
        expect(meta['description'], contains('CA-019-'), reason: '@$k');
      }
    }
  });

  test('CA-019-27, CA-019-04: los placeholders del ARB de plantilla tienen el '
      'tipo de la spec (count entero; time1..3 texto ya formateado)', () {
    for (final MapEntry(key: k, value: (_, _, placeholders))
        in _spec019.entries) {
      final declared =
          ((es['@$k'] as Map<String, dynamic>)['placeholders']
              as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      expect(
        {
          for (final e in declared.entries)
            e.key: (e.value as Map<String, dynamic>)['type'],
        },
        placeholders,
        reason: k,
      );
    }
  });

  test('CA-019-27: las claves que la 019 reutiliza siguen igual y no se '
      'duplican con otro nombre', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _reused.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
    }
    // Ninguna clave nueva repite el texto de una reutilizada (el plan solo
    // las duplicaría con prefijo notification… si hiciera falta, y no hace).
    for (final k in ['notificationPhoto', 'notificationImage']) {
      expect(es.containsKey(k), isFalse, reason: k);
    }
  });

  test(
    'CA-019-27: solo las 17 claves nuevas citan CA-019 en su descripción',
    () {
      for (final arb in [es, en]) {
        final withCa019 = [
          for (final e in arb.entries)
            if (e.key.startsWith('@') &&
                e.value is Map &&
                (e.value as Map)['description'].toString().contains('CA-019-'))
              e.key.substring(1),
        ]..sort();
        expect(withCa019, _spec019.keys.toList()..sort());
      }
    },
  );

  test('CA-019-27: las clases generadas dan el texto de cada idioma, con el '
      'plural de la cantidad', () {
    final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();
    expect(l10nEs.settingsNotifications, 'Notificaciones');
    expect(l10nEn.settingsNotifications, 'Notifications');
    expect(l10nEs.settingsNotificationsPerDay, 'Notificaciones al día');
    expect(l10nEn.settingsNotificationsPerDay, 'Notifications per day');
    expect(l10nEs.settingsNotificationsOption(1), '1 notificación al día');
    expect(l10nEs.settingsNotificationsOption(2), '2 notificaciones al día');
    expect(l10nEs.settingsNotificationsOption(3), '3 notificaciones al día');
    expect(l10nEn.settingsNotificationsOption(1), '1 notification per day');
    expect(l10nEn.settingsNotificationsOption(3), '3 notifications per day');
    expect(l10nEs.notificationTitle, 'Tarea actual');
    expect(l10nEn.notificationTitle, 'Current task');
    expect(l10nEs.notificationPublic, 'Tienes una tarea pendiente.');
    expect(l10nEn.notificationPublic, 'You have a task waiting.');
  });

  test('CA-019-04, CA-019-27: la ayuda recibe las horas ya formateadas y las '
      'pone tal cual (siempre en 24 h, también en inglés)', () {
    final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();
    expect(
      l10nEs.settingsNotificationsHelp1('08:55'),
      'La notificación será a las 08:55.',
    );
    expect(
      l10nEs.settingsNotificationsHelp2('08:55', '13:55'),
      'Las notificaciones serán a las 08:55 y a las 13:55.',
    );
    expect(
      l10nEs.settingsNotificationsHelp3('08:55', '13:55', '18:55'),
      'Las notificaciones serán a las 08:55, a las 13:55 y a las 18:55.',
    );
    expect(
      l10nEn.settingsNotificationsHelp1('08:55'),
      'The notification will be at 08:55.',
    );
    expect(
      l10nEn.settingsNotificationsHelp2('08:55', '13:55'),
      'The notifications will be at 08:55 and 13:55.',
    );
    expect(
      l10nEn.settingsNotificationsHelp3('08:55', '13:55', '18:55'),
      'The notifications will be at 08:55, 13:55 and 18:55.',
    );
  });

  test('CA-019-27, CA-015-11: ningún texto nuevo lleva un fragmento del otro '
      'idioma (voz del lector)', () {
    final leaks = L10nLeaks.load();
    for (final lang in ['es', 'en']) {
      final arb = lang == 'es' ? es : en;
      final own = [
        for (final k in _spec019.keys) ...arbLiteralFragments(arb[k] as String),
      ];
      expect(leaks.leaksIn(own, languageCode: lang), isEmpty, reason: lang);
    }
  });

  test('CA-019-27: el glosario recoge Notificación, Hora de notificación, '
      'Bloqueadas y Versión genérica con sus claves', () {
    final lines = File('../docs/glossary.md').readAsStringSync().split('\n');
    String row(String start) => lines.firstWhere((l) => l.startsWith(start));
    expect(row('| Notificación |'), contains('Notification'));
    expect(row('| Hora de notificación |'), contains('Notification time'));
    final blocked = row('| Notificaciones bloqueadas |');
    expect(blocked, contains('`settingsNotificationsBlocked`'));
    final generic = row('| Versión genérica |');
    expect(generic, contains('`notificationPublic`'));
    final setting = row('| Notificaciones (ajuste) |');
    for (final k in ['settingsNotifications', 'settingsNotificationsPerDay']) {
      expect(setting, contains('`$k`'), reason: k);
    }
  });
}
