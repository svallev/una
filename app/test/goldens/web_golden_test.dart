// Goldens de la spec 009 (T-009-20). Se generan y comparan solo en Linux (CI):
// ver docs/testing.md, "Goldens". La WebView va sustituida por la falsa
// (`FakeWebPages`: una zona en blanco, sin red); los eventos de carga se dan a
// mano. La hoja "Añadir" de una tarea nueva no cambia (la fila "Cargar URL" ya
// estaba): sus goldens siguen en `image_golden_test.dart`.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_web_page_driver.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _address = 'https://www.congreso.ejemplo.com/programa';

/// Tarea web guardada con la dirección [url].
Task _webTask(
  String id, {
  String url = _address,
  String rank = 'MA',
  int color = 3,
}) {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: id,
    text: null,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: color,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-$id', url: url), at),
  );
}

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;
  late MemoryAttachmentStore store;
  late InMemoryTaskRepository repo;

  setUp(() {
    web = FakeWebPages();
    store = MemoryAttachmentStore();
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    ...web.overrides,
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
  ];

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  /// La app entera con [tasks] en el repositorio (la primera, la actual).
  Future<void> pumpApp(WidgetTester tester, List<Task> tasks) async {
    for (final task in tasks) {
      await repo.insert(task);
    }
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    await tester.pumpAndSettle();
  }

  testWidgets('CA-009-02: hoja "Cargar URL" con una dirección no válida', (
    tester,
  ) async {
    await pumpWithApp(
      tester,
      const TaskEditorScreen(mode: EditorMode.first),
      repo: repo,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Añadir foto, imagen o archivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar URL'));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(UrlSheet),
        matching: find.byType(TextField),
      ),
      'intranet',
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Esa dirección no parece válida.'), findsOneWidget);
    await golden(tester, 'url_sheet_error_es');
  }, skip: _skip);

  testWidgets('CA-009-06, CA-009-07: tarea web cargando (barra con candado, '
      'dominio y "WEB"; línea de carga)', (tester) async {
    await pumpApp(tester, [_webTask('w')]);
    web.last
      ..started(_address)
      ..progress(40);
    await tester.pumpAndSettle();
    expect(find.byType(WebBar), findsOneWidget);
    expect(find.byKey(const ValueKey('web-loading')), findsOneWidget);
    await golden(tester, 'current_task_web_loading_es');
  }, skip: _skip);

  testWidgets('CA-009-08: tarea web sin conexión', (tester) async {
    await pumpApp(tester, [_webTask('w')]);
    web.last
      ..started(_address)
      ..error(WebLoadError.hostLookup);
    await tester.pumpAndSettle();
    expect(
      find.text('Necesitas conexión para ver esta página.'),
      findsOneWidget,
    );
    await golden(tester, 'current_task_web_offline_es');
  }, skip: _skip);

  testWidgets('CA-009-09: tarea web sin https (sin candado)', (tester) async {
    await pumpApp(tester, [
      _webTask('w', url: 'http://viejo.ejemplo.com/carta'),
    ]);
    web.last.error(WebLoadError.connect);
    await tester.pumpAndSettle();
    expect(
      find.text('Esta página no usa conexión segura. Ábrela en el navegador.'),
      findsOneWidget,
    );
    await golden(tester, 'current_task_web_insecure_es');
  }, skip: _skip);

  testWidgets('CA-009-17: listado con la insignia "WEB" y el dominio', (
    tester,
  ) async {
    await pumpApp(tester, [
      sampleTask(id: 't1', text: 'Comprar pan', rank: 'A'),
      _webTask('w1', rank: 'B'),
      _webTask(
        'w2',
        url: 'http://viejo.ejemplo.com/carta',
        rank: 'C',
        color: 4,
      ),
    ]);
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.text('WEB'), findsNWidgets(2));
    await golden(tester, 'task_list_web_es');
  }, skip: _skip);
}
