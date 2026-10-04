import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fonts.dart';
import '../../support/pdfrx.dart';
import '../../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late FakePdfImporter pdfImporter;
  late InMemoryTaskRepository repo;
  late ImportRegistry registry;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    pdfImporter = FakePdfImporter(store);
    taskPdfCalls.clear();
    repo = InMemoryTaskRepository();
    registry = ImportRegistry();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
    pdfImporterProvider.overrideWithValue(pdfImporter),
    ...fakePdfViews,
    importRegistryProvider.overrideWithValue(registry),
  ];

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

  Future<Task> imageTask({
    String? text = 'Horario',
    String id = 'a1',
    String rank = 'M',
  }) async {
    final attachment = await store.commit(
      stageImage(store, id),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(id: 't-$id', text: text ?? 'x', rank: rank);
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<Task> pdfTask({String? text = 'Programa', String id = 'p1'}) async {
    store
      ..putStaging(id, 'document.pdf', Uint8List.fromList('%PDF-1.7'.codeUnits))
      ..putStaging(id, 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: id,
        byteSize: 2400000,
        pageCount: 12,
        width: 595,
        height: 842,
        originalName: 'Programa.pdf',
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(id: 't-$id', text: text ?? 'x');
    return base.withContent(text, attachment, base.updatedAt);
  }

  /// El icono del aviso de la tarjeta.
  UnaIconData cardIcon(WidgetTester tester) => tester
      .widget<UnaIcon>(
        find.descendant(
          of: find.byType(MissingAttachmentCard),
          matching: find.byType(UnaIcon),
        ),
      )
      .icon;

  Future<void> pump(
    WidgetTester tester, {
    List<String> tasks = const [],
  }) async {
    listen(tester);
    await pumpUnaApp(tester, repo: repo, tasks: tasks, overrides: overrides());
    await tester.pumpAndSettle();
  }

  group('CA-007-19: falta la versión completa', () {
    testWidgets('se ve "Adjunto no disponible" con una sola acción, "Quitar '
        'adjunto", y la app no se cierra', (tester) async {
      await repo.insert(await imageTask());
      store.removeFile('a1', 'full-0-0.jpg');
      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(find.byType(TaskImage), findsNothing);
      expect(find.text('Horario'), findsOneWidget);
      expect(find.text('Adjunto no disponible'), findsOneWidget);
      expect(find.text('Sustituir'), findsNothing);
      expect(find.text('Quitar adjunto'), findsOneWidget);
      expect(find.text('Eliminar tarea'), findsNothing);
      expect(cardIcon(tester), UnaIcons.image);
    });

    testWidgets('también si la completa está vacía', (tester) async {
      await repo.insert(await imageTask());
      store.putStored('a1', 'full-0-0.jpg', Uint8List(0));
      await pump(tester);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
    });

    testWidgets('el lector lo lee con la tarea y conserva completar y '
        'eliminar', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask());
      store.removeFile('a1', 'full-0-0.jpg');
      await pump(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Tarea actual: Horario. Adjunto no disponible'),
        ),
        isSemantics(
          label: 'Tarea actual: Horario. Adjunto no disponible',
          customActions: [
            const CustomSemanticsAction(label: 'Completar tarea'),
            const CustomSemanticsAction(label: 'Eliminar tarea'),
          ],
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('CA-014-01, CA-007-19: sin texto, "Eliminar tarea" elimina sin '
        'confirmación y la card dice "Foto"', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask(text: null));
      store.removeFile('a1', 'full-0-0.jpg');
      await pump(tester);
      expect(find.text('Quitar adjunto'), findsNothing);
      expect(
        find.bySemanticsLabel('Tarea actual: Foto. Adjunto no disponible'),
        findsOneWidget,
      );
      await tester.tap(find.text('Eliminar tarea'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(DeleteConfirmSheet), findsNothing);
      expect(await repo.currentTask(), isNull);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        find.descendant(of: find.byType(UndoCard), matching: find.text('Foto')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CA-007-16: "Quitar adjunto" deja la tarea con su texto y '
        'borra los archivos', (tester) async {
      final task = await imageTask();
      await repo.insert(task);
      store.removeFile('a1', 'full-0-0.jpg');
      await pump(tester);
      await tester.tap(find.text('Quitar adjunto'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachment, isNull);
      expect(saved.text, 'Horario');
      expect(saved.rank, task.rank);
      expect(await store.storedIds(), isEmpty);
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(announcements, ['Adjunto quitado']);
    });
  });

  group('CA-007-19: faltan solo las derivadas', () {
    for (final name in ['screen.jpg', 'thumb.jpg']) {
      testWidgets('falta $name: se regenera sin avisar', (tester) async {
        await repo.insert(await imageTask());
        store.removeFile('a1', name);
        await pump(tester);
        expect(importer.regenerated, ['a1']);
        expect(find.byType(MissingAttachmentCard), findsNothing);
        expect(find.byType(TaskImage), findsOneWidget);
        expect(store.bytes('attachments/a1/$name'), isNotNull);
      });
    }

    testWidgets('si no se puede regenerar, "Adjunto no disponible"', (
      tester,
    ) async {
      await repo.insert(await imageTask());
      store.removeFile('a1', 'screen.jpg');
      importer.regenerateError = const FormatException('corrupta');
      await pump(tester);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
    });
  });

  group('CA-008-18: PDF no disponible', () {
    for (final (what, spoil) in <(String, void Function())>[
      ('falta', () => store.removeFile('p1', 'document.pdf')),
      ('está vacío', () => store.putStored('p1', 'document.pdf', Uint8List(0))),
    ]) {
      testWidgets('si el PDF $what: la tarjeta con el icono de documento y una '
          'sola acción, "Quitar adjunto"; la app no se cierra', (tester) async {
        await repo.insert(await pdfTask());
        spoil();
        await pump(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(MissingAttachmentCard), findsOneWidget);
        expect(cardIcon(tester), UnaIcons.document);
        expect(find.byKey(const Key('fake-task-pdf')), findsNothing);
        expect(find.byType(PdfStrip), findsNothing);
        expect(find.text('Programa'), findsOneWidget);
        expect(find.text('Adjunto no disponible'), findsOneWidget);
        expect(find.text('Quitar adjunto'), findsOneWidget);
        expect(find.text('Eliminar tarea'), findsNothing);
        expect(pdfImporter.rendered, isEmpty);
      });
    }

    testWidgets('si el PDF no se puede abrir (el visor falla): la tarjeta', (
      tester,
    ) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      expect(find.byKey(const Key('fake-task-pdf')), findsOneWidget);
      expect(find.byType(MissingAttachmentCard), findsNothing);

      taskPdfCalls.last.onUnreadable!();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(cardIcon(tester), UnaIcons.document);
      expect(find.byKey(const Key('fake-task-pdf')), findsNothing);
    });

    testWidgets('el lector la lee con el texto y conserva completar y '
        'eliminar', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await pdfTask());
      store.removeFile('p1', 'document.pdf');
      await pump(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Tarea actual: Programa. Adjunto no disponible',
          ),
        ),
        isSemantics(
          label: 'Tarea actual: Programa. Adjunto no disponible',
          customActions: [
            const CustomSemanticsAction(label: 'Completar tarea'),
            const CustomSemanticsAction(label: 'Eliminar tarea'),
          ],
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('CA-014-01, CA-008-18: sin texto, se lee con el nombre y '
        '"Eliminar tarea" elimina sin confirmación', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await pdfTask(text: null));
      store.removeFile('p1', 'document.pdf');
      await pump(tester);
      expect(
        find.bySemanticsLabel(
          'Tarea actual: Programa.pdf. Adjunto no disponible',
        ),
        findsOneWidget,
      );
      expect(find.text('Quitar adjunto'), findsNothing);
      await tester.tap(find.text('Eliminar tarea'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(DeleteConfirmSheet), findsNothing);
      expect(await repo.currentTask(), isNull);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        find.descendant(
          of: find.byType(UndoCard),
          matching: find.text('Programa.pdf'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CA-008-16: "Quitar adjunto" deja la tarea con su texto y '
        'borra el PDF', (tester) async {
      await repo.insert(await pdfTask());
      store.removeFile('p1', 'document.pdf');
      await pump(tester);
      await tester.tap(find.text('Quitar adjunto'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachment, isNull);
      expect(saved.text, 'Programa');
      expect(await store.storedIds(), isEmpty);
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(announcements, ['Adjunto quitado']);
    });

    testWidgets('si solo falta la versión de pantalla, se regenera sin avisar '
        'con la página de la última posición', (tester) async {
      await repo.insert(await pdfTask());
      store.removeFile('p1', 'screen.jpg');
      const saved = PdfPosition(page: 4, offset: 0.25);
      await store.writePosition('p1', saved);
      await pump(tester);

      expect(pdfImporter.rendered, [('p1', saved)]);
      expect(store.bytes('attachments/p1/screen.jpg'), isNotNull);
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(find.byKey(const Key('fake-task-pdf')), findsOneWidget);
      expect(importer.regenerated, isEmpty);
    });

    testWidgets('sin posición guardada, con la primera página', (tester) async {
      await repo.insert(await pdfTask());
      store.removeFile('p1', 'screen.jpg');
      await pump(tester);
      expect(pdfImporter.rendered, [('p1', PdfPosition.start)]);
      expect(find.byType(MissingAttachmentCard), findsNothing);
    });

    testWidgets('si no se puede regenerar (el PDF no se abre), la tarjeta', (
      tester,
    ) async {
      await repo.insert(await pdfTask());
      store.removeFile('p1', 'screen.jpg');
      pdfImporter.renderError = StateError('ilegible');
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(cardIcon(tester), UnaIcons.document);
    });
  });

  testWidgets('CA-007-23: con el texto al 200 % en 360 dp la tarjeta se ve '
      'entera', (tester) async {
    final task = await imageTask(text: 'Horario del festival de verano');
    store.removeFile('a1', 'full-0-0.jpg');
    await repo.insert(task);
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    tester.view.physicalSize = const Size(360, 780);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MissingAttachmentCard), findsOneWidget);
    expect(tester.getSize(find.text('Quitar adjunto')).height, greaterThan(0));
  });

  group('CA-007-16: barrido tras el primer fotograma', () {
    testWidgets('borra adjuntos sin tarea (también los de una completada, '
        'ADR-0012) y temporales; respeta las importaciones en curso', (
      tester,
    ) async {
      final done = await imageTask(id: 'done', rank: 'A');
      await repo.insert(done);
      // Completada sin llegar a borrar sus archivos (la app murió).
      await repo.remove(done.id);
      await repo.insert(await imageTask(id: 'live', rank: 'B'));
      await store.commit(stageImage(store, 'orphan'), DateTime.utc(2026));
      stageImage(store, 'leftover');
      stageImage(store, 'importing');
      registry.add('importing');

      await pump(tester);
      // Nada antes del primer fotograma + el retraso.
      expect(await store.storedIds(), {'done', 'live', 'orphan'});
      await tester.pump(UnaApp.sweepDelay);
      await tester.pumpAndSettle();

      expect(await store.storedIds(), {'live'});
      expect(await store.stagingIds(), {'importing'});
    });
  });

  group('CA-008-18: con el motor de PDF de verdad', () {
    setUpAll(initPdfrxForTests);

    Future<int> pumpViewer(WidgetTester tester, String name) async {
      var unreadable = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TaskPdfView(
            args: TaskPdfArgs(
              source: (
                path: null,
                bytes: base64Decode(pdfFixtures[name]!),
                key: name,
              ),
              screen: MemoryImage(tinyImage),
              captionColor: const Color(0xFFFFE55C),
              initialPosition: PdfPosition.start,
              onPosition: (_) {},
              onUnreadable: () => unreadable++,
            ),
          ),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      // pdfrx deja temporizadores propios: se desmonta y se dejan correr.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      return unreadable;
    }

    testWidgets('un PDF que no se puede abrir avisa una vez', (tester) async {
      expect(await pumpViewer(tester, 'html_as.pdf'), 1);
    });

    testWidgets('uno correcto, no', (tester) async {
      expect(await pumpViewer(tester, 'one_page.pdf'), 0);
    });
  });
}
