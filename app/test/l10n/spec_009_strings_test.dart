import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Tabla "Textos (ES / EN)" de la spec 009 (§7), copiada tal cual.
const _spec009 = <String, (String, String)>{
  'urlSheetTitle': ('Cargar URL', 'Load URL'),
  'urlPlaceholder': ('https://', 'https://'),
  'urlHelp': (
    'Se abre como tarea, arriba del todo.',
    'It opens as a task, on top.',
  ),
  'urlOpen': ('Abrir', 'Open'),
  'urlErrEmpty': ('Escribe una dirección web.', 'Enter a web address.'),
  'urlErrScheme': (
    'Solo se admiten direcciones web (http o https).',
    'Only web addresses (http or https) are supported.',
  ),
  'urlErrInvalid': (
    'Esa dirección no parece válida.',
    "That address doesn't look valid.",
  ),
  'urlNeedsConnection': (
    'Necesitas conexión para ver esta página.',
    'You need a connection to view this page.',
  ),
  'urlInsecure': (
    'Esta página no usa conexión segura. Ábrela en el navegador.',
    "This page doesn't use a secure connection. Open it in the browser.",
  ),
  'urlLoadFailed': (
    'No se ha podido cargar la página ({reason}).',
    "Couldn't load the page ({reason}).",
  ),
  'urlReasonCertificate': ('certificado no válido', 'invalid certificate'),
  'urlNotAPage': (
    'Esta dirección no es una página web. Ábrela en el navegador.',
    "This address isn't a web page. Open it in the browser.",
  ),
  'urlRedirected': (
    'Esta dirección te ha llevado a {host}.',
    'This address took you to {host}.',
  ),
  'urlOpenInBrowser': ('Abrir en el navegador', 'Open in browser'),
  'urlLoadingA11y': ('Cargando página', 'Loading page'),
  'urlA11yBar': ('Página web de {host}', 'Web page from {host}'),
  'attachmentWeb': ('WEB', 'WEB'),
  'a11yRowWeb': ('{host}. Página web', '{host}. Web page'),
  'urlOpenPageWeb': ('Abrir página ↗', 'Open page ↗'),
};

/// Claves quitadas de la spec al pasar a "sin copia local" (ADR-0016).
const _removed = [
  'urlSaving',
  'urlSnapshotOf',
  'urlSnapshotPartial',
  'urlRefresh',
  'urlSnapshotPending',
  'urlReasonHttp',
];

void main() {
  final es = _arb('es'), en = _arb('en');

  test(
    'CA-009-06, spec 009 §7: los textos ES y EN están tal cual en las ARB',
    () {
      for (final MapEntry(key: k, value: (esText, enText))
          in _spec009.entries) {
        expect(es[k], esText, reason: 'ES $k');
        expect(en[k], enText, reason: 'EN $k');
      }
    },
  );

  test(
    'spec 009 §7: los textos con {host} o {reason} declaran el placeholder',
    () {
      for (final (k, p) in [
        ('urlLoadFailed', 'reason'),
        ('urlRedirected', 'host'),
        ('urlA11yBar', 'host'),
        ('a11yRowWeb', 'host'),
      ]) {
        final meta = es['@$k'] as Map<String, dynamic>;
        expect((meta['placeholders'] as Map<String, dynamic>).keys, [
          p,
        ], reason: k);
      }
    },
  );

  test('ADR-0016: no quedan las claves de la copia local', () {
    for (final k in _removed) {
      expect(es.containsKey(k), isFalse, reason: k);
      expect(en.containsKey(k), isFalse, reason: k);
    }
  });
}
