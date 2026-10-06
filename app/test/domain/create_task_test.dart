import 'dart:math';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/entities/queue_position.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/commit_group.dart';
import 'package:app/domain/usecases/create_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 24, 10);
  @override
  DateTime now() => value;
}

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'id-${_n++}';
}

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late ImportRegistry registry;
  late CreateTask create;

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    create = CreateTask(
      repository: repo,
      store: store,
      janitor: janitorFor(repo, store, registry),
      clock: _FixedClock(),
      ids: _SeqIds(),
      colors: ColorPicker(Random(3)),
    );
  });

  tearDown(() => repo.dispose());

  test(
    'CA-001-04: la primera tarea queda pendiente y pasa a ser la actual',
    () async {
      final t = await create('  Llamar a Marta ');
      expect(t.text, 'Llamar a Marta');
      expect(t.status, TaskStatus.pending);
      expect(await repo.currentTask(), t);
      expect(t.createdAt, DateTime.utc(2026, 9, 24, 10));
    },
  );

  test('CA-001-04 / CL-001-1: no se crea una tarea con texto vacío', () async {
    await expectLater(create('   '), throwsA(isA<InvalidTaskText>()));
    expect(await repo.countPending(), 0);
  });

  test(
    'R4: "arriba del todo" la convierte en la actual; "a la cola" no',
    () async {
      final first = await create('Primera');
      final top = await create('Arriba', position: QueuePosition.top);
      expect((await repo.currentTask())!.id, top.id);
      await create('Al final', position: QueuePosition.end);
      expect((await repo.currentTask())!.id, top.id);
      expect(await repo.lastPendingRank(), isNot(first.rank));
    },
  );

  test(
    'CA-001-08: el color nuevo es distinto del de la tarea actual',
    () async {
      for (var i = 0; i < 50; i++) {
        final current = await repo.currentTask();
        final t = await create('Tarea $i');
        if (current != null) expect(t.colorKey, isNot(current.colorKey));
      }
    },
  );

  test('watchCurrentTask emite la nueva tarea actual', () async {
    final emitted = <String?>[];
    final sub = repo.watchCurrentTask().listen((t) => emitted.add(t?.text));
    await pumpEventQueue();
    await create('A');
    await create('B');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [null, 'A', 'B']);
  });

  test(
    'CL-002-1 / ADR-0002: 1000 inserciones arriba del todo dejan claves ≤ 50',
    () async {
      final ids = <String>[];
      for (var i = 0; i < 1000; i++) {
        ids.insert(0, (await create('Tarea $i')).id);
      }
      final pending = await repo.pendingTasks();
      expect([for (final t in pending) t.id], ids);
      for (final t in pending) {
        expect(t.rank.length, lessThanOrEqualTo(Rank.maxLength));
      }
    },
  );

  group('Con imagen (spec 007)', () {
    test(
      'CA-007-05: va arriba del todo aunque se pida a la cola, sin texto',
      () async {
        await create('Primera');
        await create('Segunda', position: QueuePosition.end);
        registry.add('img');
        final staged = stageImage(store, 'img');
        final t = await create(
          '   ',
          position: QueuePosition.end,
          attachments: [staged],
        );
        expect(t.text, isNull);
        expect(t.attachment!.id, 'img');
        expect(t.attachment!.origin, AttachmentOrigin.camera);
        expect((await repo.currentTask())!.id, t.id);
        expect(await store.stagingIds(), isEmpty);
        expect(await store.storedIds(), {'img'});
        expect(registry.active, isEmpty);
      },
    );

    test('CA-007-04: con imagen, el texto se guarda recortado', () async {
      final t = await create(
        '  Horario  ',
        attachments: [
          stageImage(store, 'img', origin: AttachmentOrigin.gallery),
        ],
      );
      expect(t.text, 'Horario');
      expect(
        (await repo.findById(t.id))!.attachment!.origin,
        AttachmentOrigin.gallery,
      );
    });

    test(
      'CA-007-16 / CL-007-3: si falla al guardar, la imagen vuelve a la '
      'preparación para reintentar y no queda ningún adjunto guardado',
      () async {
        final failing = _FailingInsertRepository();
        final c = CreateTask(
          repository: failing,
          store: store,
          janitor: janitorFor(failing, store, registry),
          clock: _FixedClock(),
          ids: _SeqIds(),
        );
        registry.add('img');
        final staged = stageImage(store, 'img');
        await expectLater(
          c('x', attachments: [staged]),
          throwsA(isA<StateError>()),
        );
        expect(await store.storedIds(), isEmpty);
        expect(await store.stagingIds(), {'img'});
        expect(registry.active, {'img'});
        await failing.dispose();
      },
    );
  });

  group('Grupo de fotos (spec 016)', () {
    List<StagedImage> stageGroup(int n) => [
      for (var i = 0; i < n; i++) stageImage(store, 'g$i'),
    ];

    test('CA-016-07: un grupo de 3 va arriba, en orden, con texto opcional y '
        'sin dejar preparaciones', () async {
      await create('Primera');
      final group = stageGroup(3);
      ['g0', 'g1', 'g2'].forEach(registry.add);
      final t = await create(
        '  ',
        position: QueuePosition.end,
        attachments: group,
      );
      expect(t.text, isNull);
      expect([for (final a in t.attachments) a.id], ['g0', 'g1', 'g2']);
      final stored = (await repo.currentTask())!;
      expect(stored.id, t.id);
      expect([for (final a in stored.attachments) a.id], ['g0', 'g1', 'g2']);
      expect(await store.stagingIds(), isEmpty);
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
      expect(registry.active, isEmpty);
    });

    test('CA-016-16 / CL-016-6b: si falla la transacción, las 10 fotos '
        'vuelven a la preparación y siguen protegidas', () async {
      final failing = _FailingInsertRepository();
      final c = CreateTask(
        repository: failing,
        store: store,
        janitor: janitorFor(failing, store, registry),
        clock: _FixedClock(),
        ids: _SeqIds(),
      );
      final group = stageGroup(10);
      [for (final g in group) g.id].forEach(registry.add);
      await expectLater(c('x', attachments: group), throwsA(isA<StateError>()));
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), {for (final g in group) g.id});
      expect(registry.active, {for (final g in group) g.id});
      await failing.dispose();
    });

    test('CL-016-6b: si falta una preparación (el sistema vació la zona '
        'temporal), no se mueve nada ni se crea la tarea', () async {
      final group = stageGroup(3);
      await store.deleteStaging('g1');
      ['g0', 'g1', 'g2'].forEach(registry.add);
      await expectLater(
        create('x', attachments: group),
        throwsA(isA<StagedPhotosLost>()),
      );
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), {'g0', 'g2'});
      expect(await repo.countPending(), 0);
    });

    test('CL-016-8: dos llamadas a la vez con el mismo grupo crean una sola '
        'tarea', () async {
      final group = stageGroup(3);
      final results = await Future.wait([
        create(
          'x',
          attachments: group,
        ).then<Object?>((t) => t).onError((e, _) => e),
        create(
          'x',
          attachments: group,
        ).then<Object?>((t) => t).onError((e, _) => e),
      ]);
      expect(results.whereType<Task>(), hasLength(1));
      expect(await repo.countPending(), 1);
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
      expect(await store.stagingIds(), isEmpty);
    });

    test('CA-016-14: un grupo no válido (11 fotos, o una foto con un PDF) '
        'se rechaza sin tocar nada', () async {
      final eleven = stageGroup(11);
      await expectLater(
        create('x', attachments: eleven),
        throwsA(isA<ArgumentError>()),
      );
      final mixed = [
        stageImage(store, 'm0'),
        const StagedPdf(
          id: 'm1',
          byteSize: 1,
          pageCount: 1,
          width: 10,
          height: 10,
          originalName: null,
        ),
      ];
      await expectLater(
        create('x', attachments: mixed),
        throwsA(isA<ArgumentError>()),
      );
      expect(await store.storedIds(), isEmpty);
      expect(await repo.countPending(), 0);
    });
  });

  group('Web (spec 009)', () {
    const url = 'https://congreso.example.org/programa';

    test('CA-009-03: se crea arriba del todo, sin texto (el del editor se '
        'descarta) y sin archivos', () async {
      await create('Primera');
      await create('Segunda', position: QueuePosition.end);
      final t = await create(
        '  Texto del editor  ',
        position: QueuePosition.end,
        attachments: [const StagedWeb(id: 'web', url: url)],
      );
      expect(t.text, isNull);
      expect((t.attachment!.id, t.attachment!.url), ('web', url));
      expect(t.attachment!.kind, AttachmentKind.web);
      expect(t.attachment!.origin, AttachmentOrigin.url);
      final current = (await repo.currentTask())!;
      expect((current.id, current.text), (t.id, null));
      expect(current.attachment!.url, url);
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
    });

    test('CA-009-03: si falla al guardar, no queda nada y se puede '
        'reintentar', () async {
      final failing = _FailingInsertRepository();
      final c = CreateTask(
        repository: failing,
        store: store,
        janitor: janitorFor(failing, store, registry),
        clock: _FixedClock(),
        ids: _SeqIds(),
      );
      await expectLater(
        c(
          '',
          attachments: [const StagedWeb(id: 'web', url: url)],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), isEmpty);
      await failing.dispose();
    });
  });
}

class _FailingInsertRepository extends InMemoryTaskRepository {
  @override
  Future<void> insert(Task task) async => throw StateError('disco lleno');
}
