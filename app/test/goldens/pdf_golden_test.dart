// Goldens de la spec 008 (T-008-24). Se generan y comparan solo en Linux (CI):
// ver docs/testing.md, "Goldens". Con el motor de PDF de verdad (PDFium), para
// que se vean las páginas; los de la hoja "Añadir" (texto nuevo de la fila
// "Subir archivo") están en `image_golden_test.dart`.
@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/fake_pdf_importer.dart';
import '../support/fonts.dart';
import '../support/pdfrx.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initPdfrxForTests();
  });

  late MemoryAttachmentStore store;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
  ];

  /// Tarea con uno de los PDF de prueba (se abre con PDFium de verdad).
  Future<Task> pdfTask(
    String id, {
    String? text,
    String fixture = 'links.pdf',
    String name = 'Programa del congreso.pdf',
    int pages = 2,
    String rank = 'M',
    int color = 2,
  }) async {
    store
      ..putStaging('p-$id', 'document.pdf', base64Decode(pdfFixtures[fixture]!))
      ..putStaging('p-$id', 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: 'p-$id',
        byteSize: 2400000,
        pageCount: pages,
        width: 595,
        height: 842,
        originalName: name,
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(
      id: id,
      text: text ?? 'x',
      rank: rank,
      colorKey: color,
    );
    return base.withContent(text, attachment, base.updatedAt);
  }

  /// PDFium trabaja fuera del reloj falso de los tests: se le deja tiempo
  /// real para abrir el documento y dibujar las páginas.
  Future<void> settle(WidgetTester tester, [int rounds = 200]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// pdfrx deja temporizadores propios: se desmonta y se dejan correr.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  /// El giro lo pide la app al sistema: aquí basta con responder.
  void muteScreenChannel(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, (_) async => null)
      ..setMockMethodCallHandler(
        const MethodChannel('una/screen'),
        (_) async => null,
      );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
    });
  }

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1.0}) async {
    muteScreenChannel(tester);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpUnaApp(
      tester,
      repo: repo,
      overrides: [
        ...overrides(),
        attachmentRotatesProvider.overrideWithValue(true),
      ],
    );
    await settle(tester);
  }

  testWidgets('CA-008-04: editor con PDF y texto', (tester) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(
        mode: EditorMode.edit,
        task: await pdfTask('t1', text: 'Programa del congreso'),
      ),
      repo: repo,
      overrides: overrides(),
    );
    await settle(tester);
    expect(find.byType(PdfStrip), findsOneWidget);
    await golden(tester, 'editor_pdf_es');
    await unmount(tester);
  }, skip: _skip);

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-008-08: tarea actual con PDF y texto (texto ×$scale)', (
      tester,
    ) async {
      await repo.insert(await pdfTask('t1', text: 'Programa del congreso'));
      await pumpApp(tester, textScale: scale);
      expect(find.byType(PdfStrip), findsOneWidget);
      await golden(tester, 'current_task_pdf_es_x$scale');
      await unmount(tester);
    }, skip: _skip);
  }

  testWidgets('CA-008-08: tarea actual con PDF sin texto (sin banda)', (
    tester,
  ) async {
    await repo.insert(
      await pdfTask(
        't1',
        fixture: 'pages_20.pdf',
        name: 'pages_20.pdf',
        pages: 20,
      ),
    );
    await pumpApp(tester);
    await golden(tester, 'current_task_pdf_no_text_es');
    await unmount(tester);
  }, skip: _skip);

  testWidgets('CA-008-11: tarea con PDF en horizontal', (tester) async {
    await repo.insert(await pdfTask('t1', text: 'Programa del congreso'));
    await pumpApp(tester);
    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);
    expect(find.byType(PdfStrip), findsNothing);
    await golden(tester, 'current_task_pdf_landscape_es');
    await unmount(tester);
  }, skip: _skip);

  testWidgets('CA-008-19: listado con la insignia "PDF"', (tester) async {
    await repo.insert(
      await pdfTask('t1', text: 'Programa del congreso', rank: 'A'),
    );
    await repo.insert(sampleTask(id: 't2', text: 'Comprar pan', rank: 'B'));
    await repo.insert(
      await pdfTask(
        't3',
        fixture: 'pages_20.pdf',
        name: 'pages_20.pdf',
        pages: 20,
        rank: 'C',
        color: 3,
      ),
    );
    await repo.insert(
      await pdfTask('t4', text: 'Entradas', rank: 'D', color: 4),
    );
    store.removeFile('p-t4', 'document.pdf');
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await settle(tester, 40);
    await tester.tap(find.text('Todas mis tareas'));
    await settle(tester, 40);
    // El listado, con la insignia en las tres filas con PDF.
    expect(find.text('Comprar pan'), findsOneWidget);
    expect(find.text('PDF'), findsNWidgets(3));
    await golden(tester, 'task_list_pdf_es');
    await unmount(tester);
  }, skip: _skip);

  testWidgets('CA-008-12: confirmación de un enlace', (tester) async {
    await repo.insert(await pdfTask('t1', text: 'Programa del congreso'));
    await pumpApp(tester);
    // La misma hoja que abre la tarea actual al tocar un enlace web.
    showLinkConfirmSheet(
      tester.element(find.byType(CurrentTaskScreen)),
      WebLink(Uri.parse('https://example.com/programa'), 'example.com'),
    ).ignore();
    await settle(tester, 40);
    expect(find.text('¿Abrir example.com en el navegador?'), findsOneWidget);
    await golden(tester, 'link_confirm_es');
    await unmount(tester);
  }, skip: _skip);
}
