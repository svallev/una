import 'dart:io';

import 'package:app/app/app_identity.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/app_harness.dart';

/// Archivo generado desde `identity.yaml`: el único de `lib/` que puede
/// llevar el nombre escrito.
const _generated = 'lib/app/app_identity.g.dart';

/// El nombre escrito tal cual como palabra suelta (distingue mayúsculas).
/// No cuenta dentro de otra palabra ("ninguna." contiene "una.") ni como
/// parte de un identificador técnico ("una.sqlite", el archivo de la BD, que
/// no debe cambiar con el nombre para no perder los datos).
RegExp _literal(String name) => RegExp(
  '(?<![\\p{L}\\p{N}_])${RegExp.escape(name)}(?![\\p{L}\\p{N}_])',
  unicode: true,
);

/// Archivos de `lib/`: todos, también los ARB (`lib/l10n/`) y los generados
/// de l10n.
List<File> _scannedFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        // Solo texto: fuera los archivos del sistema (`.DS_Store`).
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'))
        .where((f) => f.path.replaceAll(r'\', '/') != _generated)
        .toList();

/// Devuelve `archivo:línea` de cada aparición literal de [names].
List<String> _findLiterals(Iterable<File> files, List<String> names) {
  final patterns = names.map(_literal).toList();
  final hits = <String>{};
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (final (i, line) in lines.indexed) {
      if (patterns.any((p) => p.hasMatch(line))) {
        hits.add('${file.path}:${i + 1}');
      }
    }
  }
  return hits.toList()..sort();
}

void main() {
  final identity =
      loadYaml(File('identity.yaml').readAsStringSync()) as YamlMap;
  final names = [
    identity['displayName'] as String,
    identity['wordmark'] as String,
  ];

  test('CA-010-05: AppIdentity coincide con identity.yaml (fuente única)', () {
    expect(AppIdentity.displayName, identity['displayName']);
    expect(AppIdentity.wordmark, identity['wordmark']);
  });

  test('CA-012-05: privacyPolicyUrl sale de identity.yaml, es https y es una '
      'sola dirección para los dos idiomas', () {
    expect(identity['privacyPolicyUrl'], isA<String>());
    expect(AppIdentity.privacyPolicyUrl, identity['privacyPolicyUrl']);
    final uri = Uri.parse(AppIdentity.privacyPolicyUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(uri.userInfo, isEmpty);
  });

  test('CA-012-05: la dirección de la política no está escrita en lib/ '
      'fuera de lo generado', () {
    final url = identity['privacyPolicyUrl'] as String;
    final hits = [
      for (final f in _scannedFiles())
        if (f.readAsStringSync().contains(url)) f.path,
    ];
    expect(hits, isEmpty);
  });

  test('CA-012-05: CI ya comprueba lo generado y la marca del marcador '
      'está documentada en identity.yaml', () {
    final yaml = File('identity.yaml').readAsStringSync();
    expect(yaml, contains('privacyPolicyUrl'));
    expect(yaml, contains('PD-2'));
  });

  test(
    'CA-010-05: el nombre no está escrito tal cual en lib/ ni en los ARB',
    () {
      final files = _scannedFiles();
      expect(files.where((f) => f.path.endsWith('.arb')), hasLength(2));
      expect(_findLiterals(files, names), isEmpty);
    },
  );

  test('CA-010-05: la búsqueda detecta el nombre suelto y no palabras que '
      'lo contienen', () {
    final tmp = Directory.systemTemp.createTempSync('identity_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final hit = File('${tmp.path}/hit.dart')
      ..writeAsStringSync("const title = '${names.first}';\n");
    final miss = File('${tmp.path}/miss.dart')
      ..writeAsStringSync(
        "// La primera no tiene ninguna.\nconst db = 'una.sqlite';\n",
      );
    expect(_findLiterals([hit], names), ['${hit.path}:1']);
    expect(_findLiterals([miss], names), isEmpty);
  });

  test('CA-010-05: strings.xml lleva el displayName generado', () {
    final xml = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();
    expect(xml, contains('GENERADO por tool/gen_identity.dart'));
    expect(
      xml,
      contains(
        '<string name="app_name" translatable="false">'
        '${AppIdentity.displayName}</string>',
      ),
    );
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:label="@string/app_name"'));
  });

  test('CA-010-05: CI comprueba que la identidad generada está al día', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('dart run tool/gen_identity.dart --check'));
  });

  testWidgets(
    'CA-010-05: el título de la app (Recientes) es displayName en ES y EN',
    (tester) async {
      await pumpUnaApp(tester, repo: InMemoryTaskRepository(), tasks: ['A']);
      expect(find.byType(UnaApp), findsOneWidget);
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        AppIdentity.displayName,
      );

      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        AppIdentity.displayName,
      );
    },
  );

  testWidgets('CA-010-05: la pantalla de error de almacenamiento también '
      'lleva displayName de título', (tester) async {
    await tester.pumpWidget(StorageErrorApp(noSpace: false, onRetry: () {}));
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      AppIdentity.displayName,
    );
  });
}
