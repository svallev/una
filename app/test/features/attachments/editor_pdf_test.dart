import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/pump_app.dart';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');
final _remove = find.bySemanticsLabel('Quitar adjunto');

void main() {
  late MemoryAttachmentStore store;
  late FakePdfImporter pdfs;
  late FakeImageImporter images;
  late InMemoryTaskRepository repo;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    pdfs = FakePdfImporter(store);
    images = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
  });

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    EditorMode mode = EditorMode.first,
    Task? task,
  }) async {
    listen(tester);
    await pumpWithApp(
      tester,
      TaskEditorScreen(mode: mode, task: task),
      repo: repo,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(images),
        pdfImporterProvider.overrideWithValue(pdfs),
        ...fakePdfViews,
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String row) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  group('CA-008-01/04: "Subir archivo" y el editor con PDF', () {
    for (final (mode, label) in [
      (EditorMode.first, 'Guardar'),
      (EditorMode.create, 'Continuar'),
    ]) {
      testWidgets(
        'franja, páginas, "Quitar adjunto", texto opcional y "$label" '
        '(${mode.name})',
        (tester) async {
          await pumpEditor(tester, mode: mode);
          await pick(tester, 'Subir archivo');

          expect(pdfs.picks, hasLength(1));
          expect(find.byType(AttachmentPreview), findsOneWidget);
          final strip = tester.widget<PdfStrip>(find.byType(PdfStrip));
          expect(
            (strip.type, strip.name, strip.size),
            ('PDF', 'Programa.pdf', '2,4 MB'),
          );
          expect(find.byKey(const Key('fake-pdf-pages')), findsOneWidget);
          expect(find.text('pdf:staged:${pdfs.picks.single}'), findsOneWidget);
          final removeSize = tester.getSize(_remove);
          expect(removeSize.width, greaterThanOrEqualTo(48));
          expect(removeSize.height, greaterThanOrEqualTo(48));
          expect(find.text('Añade un texto (opcional)'), findsOneWidget);
          expect(find.text(label), findsOneWidget);
          expect(announcements, contains('PDF añadido'));
          // El recuadro se lee como un único elemento.
          expect(
            find.bySemanticsLabel('Programa.pdf. PDF, 2,4 MB'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('sin nombre, la franja y la lectura dicen "PDF"', (
      tester,
    ) async {
      pdfs.pickedName = null;
      await pumpEditor(tester);
      await pick(tester, 'Subir archivo');
      expect(tester.widget<PdfStrip>(find.byType(PdfStrip)).name, 'PDF');
      expect(find.bySemanticsLabel('PDF. PDF, 2,4 MB'), findsOneWidget);
    });

    testWidgets('"Quitar adjunto" borra el PDF preparado y vuelve a (+)', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester, 'Subir archivo');
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(find.byType(PdfStrip), findsNothing);
      expect(await store.stagingIds(), isEmpty);
      expect(announcements.last, 'Adjunto quitado');
    });
  });

  testWidgets('CA-008-05: con PDF, "Continuar" lo pone arriba sin preguntar', (
    tester,
  ) async {
    await repo.insert(sampleTask(rank: 'M'));
    await pumpEditor(tester, mode: EditorMode.create);
    await pick(tester, 'Subir archivo');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementSheet), findsNothing);
    final current = (await repo.currentTask())!;
    expect(current.attachment!.isPdf, isTrue);
    expect(current.attachment!.originalName, 'Programa.pdf');
    expect(current.text, isNull);
    expect(await repo.countPending(), 2);
  });

  testWidgets(
    'CL-008-9: doble toque rápido en "Continuar" crea una sola tarea',
    (tester) async {
      await pumpEditor(tester, mode: EditorMode.create);
      await pick(tester, 'Subir archivo');
      await tester.tap(find.text('Continuar'));
      await tester.tap(find.text('Continuar'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await repo.countPending(), 1);
    },
  );

  testWidgets(
    'CA-008-06: sustituir la imagen por un PDF conserva posición y color',
    (tester) async {
      final attachment = await store.commit(
        stageImage(store, 'old', origin: AttachmentOrigin.gallery),
        DateTime.utc(2026, 9, 20),
      );
      final base = sampleTask(text: 'Horario', colorKey: 3, rank: 'M');
      final task = base.withContent('Horario', attachment, base.updatedAt);
      await repo.insert(task);
      await repo.insert(sampleTask(id: 't0', rank: 'C'));
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await pick(tester, 'Subir archivo');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final saved = (await repo.findById(task.id))!;
      expect(saved.attachment!.isPdf, isTrue);
      expect((saved.rank, saved.colorKey), ('M', 3));
      // La imagen sustituida ya no está (CA-008-16).
      expect(await store.storedIds(), {saved.attachment!.id});
    },
  );

  testWidgets('CA-008-06: al editar una tarea con PDF se ve su PDF', (
    tester,
  ) async {
    await pumpEditor(tester);
    await pick(tester, 'Subir archivo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final task = (await repo.currentTask())!;

    await pumpEditor(tester, mode: EditorMode.edit, task: task);
    expect(find.byType(PdfStrip), findsOneWidget);
    expect(find.text('pdf:${task.attachment!.documentPath}'), findsOneWidget);
  });

  testWidgets('CA-008-02: el error se muestra y el editor queda como estaba', (
    tester,
  ) async {
    pdfs.inspectError = const PdfImportFailure(PdfImportError.tooManyPages);
    await pumpEditor(tester);
    await pick(tester, 'Subir archivo');
    expect(
      find.text('El PDF tiene demasiadas páginas (máx. 20).'),
      findsOneWidget,
    );
    expect(find.byType(AttachmentPreview), findsNothing);
    expect(await store.stagingIds(), isEmpty);
  });

  testWidgets('CA-008-15: "Preparando PDF…" con "Cancelar" si tarda', (
    tester,
  ) async {
    pdfs.inspectDelay = const Duration(seconds: 5);
    await pumpEditor(tester);
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir archivo'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Preparando PDF…'), findsOneWidget);
    expect(announcements, contains('Preparando PDF…'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Preparando PDF…'), findsNothing);
    expect(find.byType(AttachmentPreview), findsNothing);
    expect(await store.stagingIds(), isEmpty);
  });
}
