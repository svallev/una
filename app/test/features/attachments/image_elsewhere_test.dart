import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/pump_app.dart';
import '../task_list/list_harness.dart';

const _frame = Duration(milliseconds: 16);

void main() {
  late MemoryAttachmentStore store;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
  ];

  Future<Task> imageTask(
    String id, {
    String? text,
    required String rank,
    AttachmentOrigin origin = AttachmentOrigin.camera,
    int color = 1,
  }) async {
    final attachment = await store.commit(
      stageImage(store, 'a-$id', origin: origin),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(
      id: id,
      text: text ?? 'x',
      rank: rank,
      colorKey: color,
    );
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<void> openListWith(WidgetTester tester, List<Task> tasks) async {
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
  }

  TaskListRow rowFor(WidgetTester tester, String id) => tester
      .widgetList<TaskListRow>(find.byType(TaskListRow))
      .firstWhere((r) => r.task.id == id);

  Finder thumbOf(WidgetTester tester, String id) => find.descendant(
    of: find.byWidget(rowFor(tester, id)),
    matching: find.byType(TaskThumbnail),
  );

  group('CA-007-20: listado', () {
    testWidgets('miniatura de 44 px con borde, entre el asa y el texto; '
        'en la primera, a 8 px', (tester) async {
      await openListWith(tester, [
        await imageTask('t1', text: 'Horario', rank: 'A'),
        await imageTask('t2', text: 'Mapa', rank: 'B'),
        sampleTask(id: 't3', text: 'Llamar', rank: 'C'),
      ]);

      for (final id in ['t1', 't2']) {
        expect(tester.getSize(thumbOf(tester, id)), const Size(44, 44));
      }
      expect(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't3')),
          matching: find.byType(TaskThumbnail),
        ),
        findsNothing,
      );
      // Entre el asa y el texto.
      final thumb = tester.getRect(thumbOf(tester, 't2'));
      final text = tester.getRect(find.text('Mapa'));
      expect(thumb.right, lessThan(text.left));
      final row = tester.getRect(find.byWidget(rowFor(tester, 't2')));
      expect(thumb.left - row.left, greaterThan(34));
      // En la primera (sin asa), 8 px más dentro.
      final firstRow = tester.getRect(find.byWidget(rowFor(tester, 't1')));
      final firstThumb = tester.getRect(thumbOf(tester, 't1'));
      expect(
        firstThumb.left - firstRow.left,
        UnaBorders.strongWidth + UnaSpace.xs + UnaSpace.s,
      );
    });

    testWidgets('sin texto, la fila dice "Foto" o "Imagen"', (tester) async {
      await openListWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        await imageTask('t1', rank: 'B'),
        await imageTask('t2', rank: 'C', origin: AttachmentOrigin.gallery),
      ]);
      expect(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't1')),
          matching: find.text('Foto'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't2')),
          matching: find.text('Imagen'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CA-007-21: el lector lee "{n} de {total}: {texto}. Con '
        'foto" o "{n} de {total}: Foto"; la miniatura es decorativa', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openListWith(tester, [
        await imageTask('t1', text: 'Horario', rank: 'A'),
        await imageTask('t2', rank: 'B'),
        await imageTask(
          't3',
          text: 'Mapa',
          rank: 'C',
          origin: AttachmentOrigin.gallery,
        ),
      ]);
      expect(
        find.bySemanticsLabel('1 de 3. Tarea actual: Horario. Con foto'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 de 3: Foto'), findsOneWidget);
      expect(find.bySemanticsLabel('3 de 3: Mapa. Con imagen'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CA-007-19: sin la miniatura, la insignia "FOTO"/"IMAGEN"', (
      tester,
    ) async {
      final t1 = await imageTask('t1', text: 'Horario', rank: 'A');
      final t2 = await imageTask(
        't2',
        text: 'Mapa',
        rank: 'B',
        origin: AttachmentOrigin.gallery,
      );
      store
        ..removeFile('a-t1', 'full-0-0.jpg')
        ..removeFile('a-t2', 'full-0-0.jpg');
      await openListWith(tester, [t1, t2]);
      expect(
        find.descendant(of: thumbOf(tester, 't1'), matching: find.text('FOTO')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: thumbOf(tester, 't2'),
          matching: find.text('IMAGEN'),
        ),
        findsOneWidget,
      );
      final badge = tester.widget<Text>(find.text('IMAGEN'));
      expect(badge.style!.fontSize, UnaFontSizes.badge);
    });

    testWidgets('CL-007-9: 500 tareas, todas con imagen, sin errores', (
      tester,
    ) async {
      final tasks = <Task>[];
      for (var i = 0; i < 500; i++) {
        tasks.add(
          await imageTask(
            't$i',
            text: 'Tarea $i',
            rank: 'M${i.toString().padLeft(3, '0')}1',
          ),
        );
      }
      await openListWith(tester, tasks);
      expect(tester.takeException(), isNull);
      expect(find.byType(TaskThumbnail), findsWidgets);
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, -5000),
        5000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA-004-01: eliminar una fila sin texto dice "Foto"', (
      tester,
    ) async {
      await openListWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        await imageTask('t1', rank: 'B'),
      ]);
      await tester.tap(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't1')),
          matching: find.byWidgetPredicate(
            (w) => w is UnaIcon && w.icon == UnaIcons.trash,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DeleteConfirmSheet),
          matching: find.textContaining('Foto'),
        ),
        findsOneWidget,
      );
    });
  });

  group('CA-007-20: completar y eliminar', () {
    List<String> listen(WidgetTester tester) => listenAnnouncements(tester);

    testWidgets('CL-003-4/8: la rotura muestra la imagen y el anuncio dice '
        '"Siguiente: Foto"', (tester) async {
      final announcements = listen(tester);
      await repo.insert(await imageTask('t1', text: 'Horario', rank: 'A'));
      await repo.insert(await imageTask('t2', rank: 'B'));
      await pumpUnaApp(
        tester,
        repo: repo,
        screenReader: true,
        overrides: overrides(),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(_frame);
      await gesture.up();
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CelebrationOverlay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(TaskImage),
        ),
        findsWidgets,
      );
      expect(find.byType(MissingAttachmentCard), findsNothing);
      await tester.pumpAndSettle();
      expect(announcements, contains('Tarea completada. Siguiente: Foto'));
      // CA-007-17 (ADR-0012): completar borra los archivos de la completada,
      // aunque la rotura siga mostrando su imagen.
      expect(await store.storedIds(), {'a-t2'});
    });

    testWidgets('el arrugado muestra la imagen (no "Adjunto no disponible"), '
        'la card dice "Foto" y los archivos se borran al acabar el '
        'tiempo', (tester) async {
      final announcements = listen(tester);
      await repo.insert(await imageTask('t1', rank: 'A'));
      await repo.insert(
        await imageTask('t2', rank: 'B', origin: AttachmentOrigin.gallery),
      );
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      // Sin confirmación (CA-014-01).
      await tester.pump(_frame);
      await tester.pump(_frame);
      await tester.pump(UnaMotion.crumple * 0.5);

      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CrumpleOverlay),
          matching: find.byType(TaskImage),
        ),
        findsOneWidget,
      );
      expect(find.byType(MissingAttachmentCard), findsNothing);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(_frame);
      await tester.pump(_frame);
      // CA-007-20, CA-014-04: la etiqueta sin texto, en la card; sin anuncios
      // (CA-014-16).
      expect(
        find.descendant(
          of: find.byType(UndoCard),
          matching: find.textContaining('Foto'),
        ),
        findsOneWidget,
      );
      expect(announcements, isEmpty);
      // CA-014-15: los archivos siguen mientras se puede deshacer y se
      // borran al acabar el tiempo.
      expect(await store.storedIds(), {'a-t1', 'a-t2'});
      await tester.pump(UnaMotion.undoWindow);
      await tester.pumpAndSettle();
      // CA-007-16: los archivos de la eliminada ya no están.
      expect(await store.storedIds(), {'a-t2'});
    });
  });

  testWidgets('CA-014-09: deshacer devuelve la tarea con su imagen y sus '
      'versiones; los archivos siguen pasado el tiempo', (tester) async {
    await repo.insert(await imageTask('t1', text: 'Horario', rank: 'A'));
    await repo.insert(await imageTask('t2', rank: 'B'));
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pump(_frame);
    await tester.pump(UnaMotion.crumple);
    await tester.pump(_frame);
    await tester.pump(const Duration(milliseconds: 400));
    expect(await repo.findById('t1'), isNull);
    expect(await store.storedIds(), {'a-t1', 'a-t2'});

    await tester.tap(
      find.descendant(
        of: find.byType(UndoCard),
        matching: find.byKey(UndoCard.buttonKey),
      ),
    );
    await tester.pump(_frame);
    await tester.pump(UnaMotion.sheetOut * 2);
    await tester.pumpAndSettle();

    expect((await repo.currentTask())!.id, 't1');
    expect(find.byType(UndoCard), findsNothing);
    expect(find.byType(TaskImage), findsWidgets);
    expect(find.byType(MissingAttachmentCard), findsNothing);
    // Pasado el tiempo que tenía la card, nada se borra.
    await tester.pump(UnaMotion.undoWindow * 2);
    await tester.pumpAndSettle();
    expect(await store.storedIds(), {'a-t1', 'a-t2'});
  });
}
