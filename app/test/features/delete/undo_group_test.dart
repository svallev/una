import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/queue_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/complete_current_task.dart';
import 'package:app/domain/usecases/create_task.dart';
import 'package:app/domain/usecases/delete_current_task.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:app/domain/usecases/edit_task.dart';
import 'package:app/domain/usecases/restore_deleted_task.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/undo.dart';

/// Lo que miran los tests en el instante de quitar o de insertar la fila.
class _Repo extends InMemoryTaskRepository {
  Set<String> Function()? heldNow;
  Future<Set<String>> Function()? storedNow;
  Set<String>? heldAtRemove;
  Set<String>? storedAtRemove;
  Set<String>? heldAtInsert;
  bool failRemove = false;
  bool removeFindsNothing = false;
  bool failInsert = false;
  bool failUpdate = false;

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    DateTime at, {
    List<Attachment>? attachments,
  }) async {
    if (failUpdate) throw StateError('E/S');
    return super.updateContent(id, text, at, attachments: attachments);
  }

  @override
  Future<bool> remove(String id) async {
    heldAtRemove = heldNow?.call();
    storedAtRemove = await storedNow?.call();
    if (failRemove) throw StateError('E/S');
    if (removeFindsNothing) return false;
    return super.remove(id);
  }

  @override
  Future<void> insert(Task task) async {
    heldAtInsert = heldNow?.call();
    if (failInsert) throw StateError('E/S');
    return super.insert(task);
  }
}

class _Clock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 10, 6, 9);
}

class _Ids implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'task${_n++}';
}

final _at = DateTime.utc(2026, 10, 6, 8);

/// Los ids de las fotos de un grupo `g`, en su orden.
List<String> _ids(String g, [int n = 10]) => [
  for (var i = 0; i < n; i++) '$g-foto$i',
];

void main() {
  late _Repo repo;
  late MemoryAttachmentStore store;
  late ImportRegistry registry;
  late AttachmentJanitor janitor;

  setUp(() {
    repo = _Repo();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    janitor = janitorFor(repo, store, registry);
    repo
      ..heldNow = (() => janitor.held)
      ..storedNow = store.storedIds;
  });

  tearDown(() => repo.dispose());

  /// Una tarea guardada con [n] fotos (ya en su sitio definitivo).
  Future<Task> groupTask(
    String id, {
    int n = 10,
    String rank = 'M',
    String? text,
  }) async {
    final attachments = <Attachment>[];
    for (final photo in _ids(id, n)) {
      attachments.add(await store.commit(stageImage(store, photo), _at));
    }
    final task = Task(
      id: id,
      text: text,
      status: TaskStatus.pending,
      rank: rank,
      colorKey: 1,
      createdAt: _at,
      updatedAt: _at,
      attachments: attachments,
    );
    await repo.insert(task);
    repo.heldAtInsert = null;
    return task;
  }

  /// Prepara [n] fotos del grupo [g] y las deja protegidas como un editor
  /// abierto.
  List<StagedImage> stageGroup(String g, {int n = 10}) => [
    for (final id in _ids(g, n))
      () {
        registry.add(id);
        return stageImage(store, id);
      }(),
  ];

  Future<void> expectNoFiles() async {
    expect(await store.storedIds(), isEmpty, reason: 'ni una foto guardada');
    expect(await store.stagingIds(), isEmpty, reason: 'ni un temporal');
  }

  group('CA-016-16: eliminar el grupo', () {
    for (final pending in [false, true]) {
      final name = pending ? 'DeletePendingTask' : 'DeleteCurrentTask';

      Future<Task> run(Task task) async {
        if (pending) {
          return (await DeletePendingTask(
            repository: repo,
            janitor: janitor,
          ).call(task.id)).deleted;
        }
        return (await DeleteCurrentTask(
          repository: repo,
          janitor: janitor,
        ).call(task)).deleted;
      }

      test('CA-016-16, CA-014-15: $name retiene las 10 fotos antes de quitar '
          'la fila y las deja retenidas', () async {
        final task = await groupTask('g');
        final deleted = await run(task);

        expect(deleted.attachments.map((a) => a.id), _ids('g'));
        expect(repo.heldAtRemove, _ids('g').toSet(), reason: 'antes de quitar');
        expect(janitor.held, _ids('g').toSet());
        expect(await repo.findById('g'), isNull);
        expect(await store.storedIds(), _ids('g').toSet(), reason: 'aún ahí');
      });

      test('CA-016-16, CA-014-15: $name, si no se quita la fila (error o ya no '
          'estaba), no deja ninguna foto retenida ni borra ninguna', () async {
        final task = await groupTask('g');
        repo.failRemove = true;
        await expectLater(run(task), throwsStateError);
        expect(janitor.held, isEmpty);

        repo
          ..failRemove = false
          ..removeFindsNothing = true;
        await expectLater(run(task), throwsA(anything));
        expect(janitor.held, isEmpty);
        expect(await store.storedIds(), _ids('g').toSet());
      });

      test('CA-016-16: $name, eliminación definitiva: se borran las 10 y '
          'no queda nada', () async {
        final task = await groupTask('g');
        final deleted = await run(task);
        await janitor.discardHeldAll([
          for (final a in deleted.attachments) a.id,
        ]);
        expect(janitor.held, isEmpty);
        await expectNoFiles();
      });
    }

    test('CA-016-16: una eliminación sin fotos no retiene nada', () async {
      final plain = Task(
        id: 'p',
        text: 'Llamar',
        status: TaskStatus.pending,
        rank: 'M',
        colorKey: 1,
        createdAt: _at,
        updatedAt: _at,
      );
      await repo.insert(plain);
      await DeleteCurrentTask(repository: repo, janitor: janitor)(plain);
      expect(janitor.held, isEmpty);
    });
  });

  group('CA-016-16: completar el grupo', () {
    test('CA-016-16, CA-016-13: se descartan las 10 fotos, y solo después '
        'de quitar la fila (la captura de la cara ya se tomó con los '
        'archivos en su sitio)', () async {
      final task = await groupTask('g');
      final result = await CompleteCurrentTask(
        repository: repo,
        janitor: janitor,
      )(task);

      expect(
        repo.storedAtRemove,
        _ids('g').toSet(),
        reason:
            'al quitar la fila los archivos siguen: la cara se captura '
            'antes de llamar',
      );
      expect(result.completed.attachments.length, 10);
      expect(await repo.findById('g'), isNull);
      await expectNoFiles();
    });

    test(
      'CA-016-16: si no se quita la fila, no se borra ninguna foto',
      () async {
        final task = await groupTask('g');
        repo.removeFindsNothing = true;
        await expectLater(
          CompleteCurrentTask(repository: repo, janitor: janitor)(task),
          throwsA(isA<TaskNotCurrent>()),
        );
        expect(await store.storedIds(), _ids('g').toSet());
      },
    );
  });

  group('CA-016-16: deshacer', () {
    test('CA-016-16, CA-014-09: devuelve la tarea con las 10 fotos y en su '
        'orden, y las suelta después de insertar la fila', () async {
      final task = await groupTask('g');
      final deleted = (await DeleteCurrentTask(
        repository: repo,
        janitor: janitor,
      )(task)).deleted;

      await RestoreDeletedTask(repository: repo, janitor: janitor)(deleted);

      expect(
        repo.heldAtInsert,
        _ids('g').toSet(),
        reason: 'al insertar la fila siguen retenidas',
      );
      expect(janitor.held, isEmpty);
      final back = await repo.findById('g');
      expect(back!.attachments.map((a) => a.id), _ids('g'));
      expect(await store.storedIds(), _ids('g').toSet());
    });

    test('CA-016-16, CA-014-23: si la recuperación falla, las 10 siguen '
        'retenidas (se puede reintentar o borrar)', () async {
      final task = await groupTask('g');
      final deleted = (await DeleteCurrentTask(
        repository: repo,
        janitor: janitor,
      )(task)).deleted;
      repo.failInsert = true;
      await expectLater(
        RestoreDeletedTask(repository: repo, janitor: janitor)(deleted),
        throwsStateError,
      );
      expect(janitor.held, _ids('g').toSet());
      await janitor.sweep();
      expect(await store.storedIds(), _ids('g').toSet(), reason: 'no se barre');
    });
  });

  group('CA-016-16: el barrido protege el grupo como una unidad', () {
    test('CA-016-16: durante la importación (las 10 preparaciones en el '
        'registro) el barrido no borra ninguna', () async {
      stageGroup('g');
      await janitor.sweep();
      expect(await store.stagingIds(), _ids('g').toSet());
    });

    test(
      'CA-016-16: con el editor abierto sobre una tarea de 10 fotos y un '
      'grupo nuevo preparado, el barrido no borra ninguna de las dos',
      () async {
        await groupTask('old');
        stageGroup('new', n: 4);
        await janitor.sweep();
        expect(await store.storedIds(), _ids('old').toSet());
        expect(await store.stagingIds(), _ids('new', 4).toSet());
      },
    );

    test(
      'CA-016-16, CA-014-15: con un grupo en deshacer el barrido no borra '
      'ninguna; cuando es definitiva y el barrido pasa, no queda nada',
      () async {
        final task = await groupTask('g');
        await DeleteCurrentTask(repository: repo, janitor: janitor)(task);
        await janitor.sweep();
        expect(await store.storedIds(), _ids('g').toSet());

        await janitor.discardHeldAll(_ids('g'));
        await janitor.sweep();
        await expectNoFiles();
      },
    );

    test(
      'CL-016-7, CA-016-16: arranque con una preparación huérfana (la app '
      'murió con el selector abierto o importando): el barrido la borra',
      () async {
        for (final id in _ids('huerfano', 6)) {
          stageImage(store, id);
        }
        // Sin registro: el proceso es nuevo.
        await janitorFor(repo, store).sweep();
        await expectNoFiles();
      },
    );

    test('CL-016-7: tras morir con una eliminación sin confirmar, el barrido '
        'del siguiente arranque recoge las 10', () async {
      final task = await groupTask('g');
      await DeleteCurrentTask(repository: repo, janitor: janitor)(task);
      // Proceso nuevo: sin retenciones.
      await janitorFor(repo, store).sweep();
      await expectNoFiles();
    });
  });

  group('CA-016-16: editar, cancelar y fallos al guardar', () {
    EditTask editor() => EditTask(
      repository: repo,
      store: store,
      janitor: janitor,
      clock: _Clock(),
    );

    test('CA-016-16: quitar el grupo al editar ("Quitar adjunto", también '
        'el de "Adjunto no disponible") borra las 10', () async {
      final task = await groupTask('g', text: 'Con fotos');
      await editor()(task, 'Con fotos', attachment: const RemoveAttachment());
      expect((await repo.findById('g'))!.attachments, isEmpty);
      await expectNoFiles();
    });

    test('CA-016-16: sustituir el grupo por otro borra las 10 anteriores y '
        'deja solo las nuevas', () async {
      final task = await groupTask('old', text: 'Con fotos');
      final next = stageGroup('new', n: 3);
      await editor()(task, 'Con fotos', attachment: ReplaceAttachment(next));
      expect(await store.storedIds(), _ids('new', 3).toSet());
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
    });

    test(
      'CA-016-16: sustituir 10 por una sola foto borra las otras 9',
      () async {
        final task = await groupTask('old', text: 'Con fotos');
        final next = stageGroup('new', n: 1);
        await editor()(task, 'Con fotos', attachment: ReplaceAttachment(next));
        expect(await store.storedIds(), {'new-foto0'});
      },
    );

    test('CA-016-16: cancelar el editor o la importación (también a medias) '
        'descarta las preparaciones de todo el grupo', () async {
      final staged = stageGroup('g', n: 7);
      for (final s in staged) {
        await janitor.discardStaging(s.id);
      }
      expect(registry.active, isEmpty);
      await expectNoFiles();
    });

    test('CA-016-16: fallo al guardar al editar: no se borra el grupo '
        'anterior y el nuevo vuelve a la preparación; al cancelar no queda '
        'nada nuevo', () async {
      final task = await groupTask('old', text: 'Con fotos');
      final next = stageGroup('new', n: 3);
      repo.failUpdate = true;
      final edit = editor();
      await expectLater(
        edit(task, 'Con fotos', attachment: ReplaceAttachment(next)),
        throwsStateError,
      );
      expect(await store.storedIds(), _ids('old').toSet());
      expect(await store.stagingIds(), _ids('new', 3).toSet());
      for (final s in next) {
        await janitor.discardStaging(s.id);
      }
      expect(await store.storedIds(), _ids('old').toSet());
      expect(await store.stagingIds(), isEmpty);
    });

    test('CA-016-16: fallo al guardar una tarea nueva con 10 fotos: vuelven a '
        'la preparación y al cancelar no queda ningún archivo', () async {
      final staged = stageGroup('g');
      repo.failInsert = true;
      final create = CreateTask(
        repository: repo,
        store: store,
        janitor: janitor,
        clock: _Clock(),
        ids: _Ids(),
      );
      await expectLater(
        create('', position: QueuePosition.top, attachments: staged),
        throwsStateError,
      );
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), _ids('g').toSet());
      for (final s in staged) {
        await janitor.discardStaging(s.id);
      }
      await expectNoFiles();
    });
  });

  group('CA-016-16 / CA-014-15: UndoController con el grupo', () {
    Future<ProviderContainer> harness(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(repo),
            attachmentStoreProvider.overrideWithValue(store),
            attachmentJanitorProvider.overrideWithValue(janitor),
            clockProvider.overrideWithValue(TesterClock(tester)),
            accessibilityTimeoutsProvider.overrideWithValue(
              FakeAccessibilityTimeouts(),
            ),
          ],
          child: const SizedBox(),
        ),
      );
      return ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
    }

    Future<void> deleteAndShow(
      WidgetTester tester,
      ProviderContainer c,
      String id,
    ) async {
      final undo = c.read(undoProvider.notifier);
      final deleted = (await c.read(deletePendingTaskProvider).call(id))
          .deleted;
      expect(
        undo.hold(deleted, host: UndoHost.list, epoch: undo.epoch),
        isTrue,
      );
      await tester.pump();
      undo.cardShown(c.read(undoProvider).serial);
    }

    testWidgets('CA-016-16, CA-014-15: a los 4 s la eliminación es '
        'definitiva y se borran las 10 fotos', (tester) async {
      await groupTask('g');
      final c = await harness(tester);
      await deleteAndShow(tester, c, 'g');

      await tester.pump(const Duration(milliseconds: 3900));
      expect(await store.storedIds(), _ids('g').toSet());
      expect(janitor.held, _ids('g').toSet());

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(janitor.held, isEmpty);
      await expectNoFiles();
    });

    testWidgets('CA-016-16, CA-014-09: deshacer devuelve la tarea con las 10 '
        'fotos y en su orden, sin borrar ninguna', (tester) async {
      await groupTask('g');
      final c = await harness(tester);
      await deleteAndShow(tester, c, 'g');
      await tester.pump(const Duration(milliseconds: 500));

      final outcome = await c.read(undoProvider.notifier).undo();

      expect(outcome, isA<Restored>());
      expect(janitor.held, isEmpty);
      expect(
        (await repo.findById('g'))!.attachments.map((a) => a.id),
        _ids('g'),
      );
      expect(await store.storedIds(), _ids('g').toSet());
    });

    testWidgets('CA-016-16, CA-014-15: otra eliminación hace definitiva la '
        'anterior y se borran sus 10 fotos; las de la nueva siguen '
        'retenidas', (tester) async {
      await groupTask('a', rank: 'M');
      await groupTask('b', rank: 'N');
      final c = await harness(tester);
      await deleteAndShow(tester, c, 'a');
      await deleteAndShow(tester, c, 'b');
      await tester.pump();

      expect(await store.storedIds(), _ids('b').toSet());
      expect(janitor.held, _ids('b').toSet());
    });

    testWidgets('CA-016-16, CA-014-11: ir a otra pantalla (commit) hace '
        'definitiva la eliminación del grupo', (tester) async {
      await groupTask('g');
      final c = await harness(tester);
      await deleteAndShow(tester, c, 'g');
      c.read(undoProvider.notifier).commit();
      await tester.pump();
      await expectNoFiles();
    });
  });
}
