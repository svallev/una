import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/task_labels.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import 'list_harness.dart';

final _at = DateTime.utc(2026, 10, 6);

Attachment _photo(String id, {AttachmentOrigin? origin}) => Attachment(
  id: id,
  kind: AttachmentKind.image,
  origin: origin ?? AttachmentOrigin.gallery,
  mime: 'image/jpeg',
  byteSize: 100,
  width: 400,
  height: 300,
  createdAt: _at,
);

Task _task(String? text, List<Attachment> attachments) => Task(
  id: 't1',
  text: text,
  status: TaskStatus.pending,
  rank: 'a',
  colorKey: 0,
  createdAt: _at,
  updatedAt: _at,
  attachments: attachments,
);

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('CA-016-19: etiquetas de la tarea con un grupo', () {
    final three = [_photo('a'), _photo('b'), _photo('c')];

    test('sin texto, "{n} fotos" (ES y EN); con una sola, "Foto"/"Imagen" '
        'de siempre', () {
      expect(taskLabel(es, _task(null, three)), '3 fotos');
      expect(taskLabel(en, _task(null, three)), '3 photos');
      expect(attachmentKindLabel(es, _task(null, three)), '3 fotos');
      expect(attachmentKindLabel(en, _task(null, three)), '3 photos');
      expect(taskLabel(es, _task(null, [_photo('a')])), 'Imagen');
      expect(
        taskLabel(
          es,
          _task(null, [_photo('a', origin: AttachmentOrigin.camera)]),
        ),
        'Foto',
      );
      expect(taskLabel(en, _task(null, [_photo('a')])), 'Image');
    });

    test('con texto, el texto (las fotos se dicen en la lectura)', () {
      expect(taskLabel(es, _task('Horario', three)), 'Horario');
      expect(taskLabel(en, _task('Schedule', three)), 'Schedule');
    });

    test('lectura: "{texto}. {n} fotos" o "{n} fotos"; sin los puntos del '
        'final; una foto, "Con imagen"', () {
      expect(taskReading(es, _task('Horario', three)), 'Horario. 3 fotos');
      expect(taskReading(es, _task('Horario...', three)), 'Horario. 3 fotos');
      expect(taskReading(es, _task(null, three)), '3 fotos');
      expect(taskReading(en, _task('Schedule', three)), 'Schedule. 3 photos');
      expect(taskReading(en, _task(null, three)), '3 photos');
      expect(
        taskReading(es, _task('Horario', [_photo('a')])),
        'Horario. Con imagen',
      );
      expect(taskReading(es, _task(null, [_photo('a')])), 'Imagen');
    });

    test('con dos fotos (el mínimo del grupo), "2 fotos"', () {
      expect(taskLabel(es, _task(null, [_photo('a'), _photo('b')])), '2 fotos');
    });

    test('un grupo no válido (mezcla o foto ilegible) se nombra como el '
        'primer adjunto, como hasta ahora', () {
      final unreadable = [_photo('a'), _photo('b')]
        ..[1] = Attachment(
          id: 'b',
          kind: AttachmentKind.image,
          origin: AttachmentOrigin.gallery,
          mime: 'image/jpeg',
          byteSize: 1,
          width: 1,
          height: 1,
          createdAt: _at,
          unreadable: true,
        );
      expect(taskLabel(es, _task(null, unreadable)), 'Imagen');
      expect(taskReading(es, _task('Horario', unreadable)), contains('imagen'));
    });
  });

  group('CA-016-19: listado', () {
    late MemoryAttachmentStore store;
    late InMemoryTaskRepository repo;

    setUp(() {
      store = MemoryAttachmentStore();
      repo = InMemoryTaskRepository();
    });

    List<Override> overrides() => [
      attachmentStoreProvider.overrideWithValue(store),
    ];

    Future<Task> groupTask(
      String id, {
      String? text,
      required String rank,
      int n = 3,
    }) async {
      final attachments = <Attachment>[];
      for (var i = 0; i < n; i++) {
        attachments.add(await store.commit(stageImage(store, '$id-$i'), _at));
      }
      return Task(
        id: id,
        text: text,
        status: TaskStatus.pending,
        rank: rank,
        colorKey: 1,
        createdAt: _at,
        updatedAt: _at,
        attachments: attachments,
      );
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

    testWidgets('miniatura de 44 px de la PRIMERA foto, sin contador ni '
        'número', (tester) async {
      await openListWith(tester, [
        await groupTask('t1', text: 'Horario', rank: 'A'),
        await groupTask('t2', text: 'Mapa', rank: 'B', n: 10),
      ]);

      for (final id in ['t1', 't2']) {
        final finder = thumbOf(tester, id);
        expect(tester.getSize(finder), const Size(44, 44));
        // La primera foto del grupo, no otra.
        final thumb = tester.widget<TaskThumbnail>(finder);
        expect(thumb.attachment.id, '$id-0');
        // Ni un solo texto dentro de la miniatura (ni "3", ni "10", ni
        // "FOTOS"): la miniatura sola, como en el prototipo.
        expect(
          find.descendant(of: finder, matching: find.byType(Text)),
          findsNothing,
        );
        expect(
          find.descendant(of: finder, matching: find.byType(Image)),
          findsOneWidget,
        );
      }
      // El borde y el tamaño son los de siempre (UnaSizes.listThumb).
      expect(tester.getSize(thumbOf(tester, 't1')).width, UnaSizes.listThumb);
    });

    testWidgets('sin texto, la fila dice "3 fotos"; con texto, el texto', (
      tester,
    ) async {
      await openListWith(tester, [
        await groupTask('t0', text: 'Primera', rank: 'A'),
        await groupTask('t1', rank: 'B'),
        await groupTask('t2', rank: 'C', n: 10),
      ]);
      Finder textIn(String id, String text) => find.descendant(
        of: find.byWidget(rowFor(tester, id)),
        matching: find.text(text),
      );
      expect(textIn('t0', 'Primera'), findsOneWidget);
      expect(textIn('t1', '3 fotos'), findsOneWidget);
      expect(textIn('t2', '10 fotos'), findsOneWidget);
    });

    testWidgets('si falta la primera foto, la insignia "FOTO" sin número', (
      tester,
    ) async {
      final t1 = await groupTask('t1', text: 'Horario', rank: 'A');
      final t2 = await groupTask('t2', text: 'Mapa', rank: 'B');
      store.removeFile('t2-0', 'full-0-0.jpg');
      await openListWith(tester, [t1, t2]);
      expect(
        find.descendant(of: thumbOf(tester, 't2'), matching: find.text('FOTO')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: thumbOf(tester, 't2'),
          matching: find.textContaining('3'),
        ),
        findsNothing,
      );
    });

    testWidgets('CA-016-20: el lector lee "{n} de {total}: {texto}. {n} '
        'fotos", también la primera fila ("1 de {total}. Tarea actual: …")', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openListWith(tester, [
        await groupTask('t1', text: 'Horario', rank: 'A'),
        await groupTask('t2', rank: 'B'),
        await groupTask('t3', text: 'Mapa', rank: 'C', n: 10),
      ]);
      expect(
        find.bySemanticsLabel('1 de 3. Tarea actual: Horario. 3 fotos'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 de 3: 3 fotos'), findsOneWidget);
      expect(find.bySemanticsLabel('3 de 3: Mapa. 10 fotos'), findsOneWidget);
      // Nunca "imagen" ni "foto" sueltas además del número.
      expect(
        find.bySemanticsLabel(RegExp('Con imagen|Con foto')),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('CA-016-20: la primera fila sin texto, "1 de {total}. Tarea '
        'actual: {n} fotos"', (tester) async {
      final handle = tester.ensureSemantics();
      await openListWith(tester, [
        await groupTask('t1', rank: 'A'),
        await groupTask('t2', text: 'Mapa', rank: 'B'),
      ]);
      expect(
        find.bySemanticsLabel('1 de 2. Tarea actual: 3 fotos'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('una tarea con una sola foto se lee y se nombra como siempre', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openListWith(tester, [
        await groupTask('t1', text: 'Horario', rank: 'A', n: 1),
        await groupTask('t2', rank: 'B', n: 1),
      ]);
      expect(
        find.bySemanticsLabel('1 de 2. Tarea actual: Horario. Con foto'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 de 2: Foto'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('en inglés: "{n} photos"', (tester) async {
      final handle = tester.ensureSemantics();
      for (final t in [
        await groupTask('t1', text: 'Schedule', rank: 'A'),
        await groupTask('t2', rank: 'B'),
      ]) {
        await repo.insert(t);
      }
      await pumpUnaApp(
        tester,
        repo: repo,
        overrides: overrides(),
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Task menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All my tasks'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('1 of 2. Current task: Schedule. 3 photos'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2 of 2: 3 photos'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CA-016-19: completar y eliminar', () {
    late MemoryAttachmentStore store;
    late InMemoryTaskRepository repo;

    setUp(() {
      store = MemoryAttachmentStore();
      repo = InMemoryTaskRepository();
    });

    Future<Task> groupTask(
      String id, {
      String? text,
      required String rank,
    }) async {
      final attachments = [
        for (var i = 0; i < 3; i++)
          await store.commit(stageImage(store, '$id-$i'), _at),
      ];
      return Task(
        id: id,
        text: text,
        status: TaskStatus.pending,
        rank: rank,
        colorKey: 1,
        createdAt: _at,
        updatedAt: _at,
        attachments: attachments,
      );
    }

    Future<void> complete(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(frame);
      await gesture.up();
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('CL-003-8: el anuncio dice "Siguiente: 3 fotos" sin texto y '
        '"Siguiente: {texto}" con texto', (tester) async {
      final announcements = listenAnnouncements(tester);
      await repo.insert(await groupTask('t1', text: 'Primera', rank: 'A'));
      await repo.insert(await groupTask('t2', rank: 'B'));
      await repo.insert(await groupTask('t3', text: 'Tercera', rank: 'C'));
      await pumpUnaApp(
        tester,
        repo: repo,
        screenReader: true,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pump();

      await complete(tester);
      expect(announcements, contains('Tarea completada. Siguiente: 3 fotos'));
    });

    testWidgets('CL-003-8: con texto, el anuncio dice "Siguiente: {texto}"', (
      tester,
    ) async {
      final announcements = listenAnnouncements(tester);
      await repo.insert(await groupTask('t1', rank: 'A'));
      await repo.insert(await groupTask('t2', text: 'Segunda', rank: 'B'));
      await pumpUnaApp(
        tester,
        repo: repo,
        screenReader: true,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pump();

      await complete(tester);
      expect(announcements, contains('Tarea completada. Siguiente: Segunda'));
    });

    testWidgets('CA-014-04: la card de deshacer dice "3 fotos" sin texto y '
        'se lee "Deshacer. Tarea eliminada: 3 fotos"', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await groupTask('t1', rank: 'A'));
      await repo.insert(await groupTask('t2', text: 'Segunda', rank: 'B'));
      await pumpUnaApp(
        tester,
        repo: repo,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(frame);
      await tester.pump(frame);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(frame);
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(UndoCard),
          matching: find.text('3 fotos'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: 3 fotos'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CA-014-04: con texto, la card dice el texto', (tester) async {
      await repo.insert(await groupTask('t1', text: 'Horario', rank: 'A'));
      await repo.insert(await groupTask('t2', rank: 'B'));
      await pumpUnaApp(
        tester,
        repo: repo,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(frame);
      await tester.pump(frame);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(frame);
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(UndoCard),
          matching: find.text('Horario'),
        ),
        findsOneWidget,
      );
    });
  });
}
