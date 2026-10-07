import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../task_list/list_harness.dart';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

void main() {
  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late List<Override> overrides;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store)
      // "Subir imágenes" con una sola elegida es la 007 (CA-016-03).
      ..manyTotal = 1;
    overrides = [
      attachmentStoreProvider.overrideWithValue(store),
      imageImporterProvider.overrideWithValue(importer),
    ];
  });

  Future<void> addImage(WidgetTester tester) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir imágenes'));
    await tester.pumpAndSettle();
  }

  Future<void> openNewTask(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
  }

  testWidgets(
    'CA-007-05: desde la pantalla principal, con imagen va arriba sin '
    'preguntar y pasa a ser la actual',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
        overrides: overrides,
      );
      await openNewTask(tester);
      await addImage(tester);
      await tester.enterText(find.byType(TextField), 'Horario');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(PlacementSheet), findsNothing);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final current = (await repo.currentTask())!;
      expect(current.text, 'Horario');
      expect(current.attachment!.id, importer.copiedIds.single);
      expect(await order(repo), ['Horario', 'Primera', 'Segunda']);
      expect(await store.stagingIds(), isEmpty);
    },
  );

  testWidgets(
    'CA-007-05: desde el listado, vuelve con la fila en la posición 1, '
    'resaltada y con el foco',
    (tester) async {
      final announcements = listenAnnouncements(tester);
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda'],
        overrides: overrides,
      );
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      await addImage(tester);
      announcements.clear();
      await tester.enterText(find.byType(TextField), 'Horario');
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PlacementSheet), findsNothing);
      TaskListRow row() => tester
          .widgetList<TaskListRow>(find.byType(TaskListRow))
          .firstWhere((r) => r.task.text == 'Horario');
      expect(row().shadow, UnaShadows.listItemFlash);
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(shownOrder(tester).first, 'Horario');
      expect((await order(repo)).first, 'Horario');
      expect(announcements, ['Ahora es la tarea actual']);
    },
  );

  testWidgets('CA-007-06: editar la imagen desde el listado no la mueve', (
    tester,
  ) async {
    final repo = await openList(
      tester,
      tasks: ['Primera', 'Segunda', 'Tercera'],
      overrides: overrides,
    );
    await tester.tap(find.text('Tercera'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Tercera'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
    await addImage(tester);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
    final third = (await repo.pendingTasks()).last;
    expect(third.attachment!.id, importer.copiedIds.single);
  });

  testWidgets('CL-007-8: doble toque rápido en "Continuar" crea una sola '
      'tarea', (tester) async {
    final repo = await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Primera'],
      overrides: overrides,
    );
    await openNewTask(tester);
    await addImage(tester);
    await tester.tap(find.text('Continuar'));
    await tester.tap(find.text('Continuar'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final tasks = await repo.pendingTasks();
    expect(tasks, hasLength(2));
    expect(tasks.first.attachment, isNotNull);
    expect(tasks.first.text, isNull);
  });

  testWidgets(
    'CA-007-16: cancelar el editor con una imagen elegida no deja nada',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera'],
        overrides: overrides,
      );
      await openNewTask(tester);
      await addImage(tester);
      expect(await store.stagingIds(), hasLength(1));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(await repo.pendingTasks(), hasLength(1));
      expect(await store.stagingIds(), isEmpty);
      expect(await store.storedIds(), isEmpty);
    },
  );
}
