import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  late ImportRegistry registry;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
    registry = ImportRegistry();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
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

    testWidgets('sin texto: "Eliminar tarea" con la confirmación de '
        'CA-004-01', (tester) async {
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
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
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

  group('CA-007-16/17: barrido tras el primer fotograma', () {
    testWidgets('borra adjuntos sin tarea y temporales; respeta las '
        'completadas y las importaciones en curso', (tester) async {
      final done = await imageTask(id: 'done', rank: 'A');
      await repo.insert(done);
      await repo.complete(done.id, DateTime.utc(2026, 9, 21));
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

      expect(await store.storedIds(), {'done', 'live'});
      expect(await store.stagingIds(), {'importing'});
    });
  });
}
