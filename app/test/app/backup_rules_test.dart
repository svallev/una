import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reglas de copia de Android (ADR-0004, CA-007-18). La BD está en
/// `app_flutter/` (`getApplicationDocumentsDirectory`, dominio `root`) y los
/// adjuntos en `files/attachments/` (`getApplicationSupportDirectory`, dominio
/// `file`); la preparación, en la caché, que nunca se copia.
const _res = 'android/app/src/main/res';

typedef _Rule = ({String tag, String domain, String path, String? flags});

/// Reglas `<include>`/`<exclude>` dentro de [section] (o de todo el archivo).
List<_Rule> _rules(String xml, [String? section]) {
  var body = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  if (section != null) {
    final m = RegExp(
      '<$section[^>]*>(.*?)</$section>',
      dotAll: true,
    ).firstMatch(body);
    expect(m, isNotNull, reason: 'Falta <$section>');
    body = m!.group(1)!;
  }
  String? attr(String tag, String name) =>
      RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);
  return [
    for (final m in RegExp(r'<(include|exclude)\b[^>]*/>').allMatches(body))
      (
        tag: m.group(1)!,
        domain: attr(m.group(0)!, 'domain')!,
        path: attr(m.group(0)!, 'path')!,
        flags: attr(m.group(0)!, 'requireFlags'),
      ),
  ];
}

/// ¿Entra `<domain>/<path>` con estas reglas? (inclusión explícita; las
/// exclusiones mandan).
bool _copies(List<_Rule> rules, String domain, String path) {
  bool covers(_Rule r) =>
      r.domain == domain &&
      (r.path == '.' || path == r.path || path.startsWith(r.path));
  if (rules.any((r) => r.tag == 'exclude' && covers(r))) return false;
  return rules.any((r) => r.tag == 'include' && covers(r));
}

String _read(String path) => File('$_res/$path').readAsStringSync();

void main() {
  group('CA-007-18: copia en la nube', () {
    test(
      'Android 12+: tareas y ajustes siempre; imágenes no; solo cifrada',
      () {
        final xml = _read('xml/data_extraction_rules.xml');
        expect(
          RegExp(r'<cloud-backup[^>]*disableIfNoEncryptionCapabilities="true"')
              .hasMatch(xml),
          isTrue,
        );
        final cloud = _rules(xml, 'cloud-backup');
        expect(_copies(cloud, 'root', 'app_flutter/una.sqlite'), isTrue);
        expect(_copies(cloud, 'sharedpref', 'x.xml'), isTrue);
        expect(_copies(cloud, 'file', 'attachments/a1/full-0-0.jpg'), isFalse);
        expect(_copies(cloud, 'root', 'cache/import/a1/source'), isFalse);
      },
    );

    test('Android 9–11: tareas y ajustes, solo cifrada; imágenes no', () {
      final rules = _rules(_read('xml-v28/backup_rules.xml'));
      expect(_copies(rules, 'root', 'app_flutter/una.sqlite'), isTrue);
      expect(_copies(rules, 'sharedpref', 'x.xml'), isTrue);
      expect(_copies(rules, 'file', 'attachments/a1/full-0-0.jpg'), isFalse);
      for (final r in rules.where((r) => r.tag == 'include')) {
        expect(r.flags, 'clientSideEncryption', reason: r.path);
      }
    });

    test('Android 8: no se copia nada (sin cifrado de extremo a extremo)', () {
      final rules = _rules(_read('xml/backup_rules.xml'));
      expect(rules.where((r) => r.tag == 'include'), isEmpty);
      for (final domain in ['root', 'file', 'database', 'sharedpref']) {
        expect(
          rules.any(
            (r) => r.tag == 'exclude' && r.domain == domain && r.path == '.',
          ),
          isTrue,
          reason: domain,
        );
      }
    });
  });

  test('CA-007-18: la transferencia entre dispositivos (Android 12+) lleva '
      'también las imágenes', () {
    final transfer = _rules(
      _read('xml/data_extraction_rules.xml'),
      'device-transfer',
    );
    expect(_copies(transfer, 'root', 'app_flutter/una.sqlite'), isTrue);
    expect(_copies(transfer, 'file', 'attachments/a1/full-0-0.jpg'), isTrue);
  });

  test('el manifiesto usa estas reglas', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });
}
