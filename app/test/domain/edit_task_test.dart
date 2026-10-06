import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/edit_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 25, 12);
  @override
  DateTime now() => value;
}

class _FailingUpdateRepository extends InMemoryTaskRepository {
  @override
  Future<bool> updateContent(
    String id,
    String? text,
    DateTime at, {
    List<Attachment>? attachments,
  }) async => throw StateError('disco lleno');
}

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late ImportRegistry registry;
  late EditTask edit;

  EditTask editFor(InMemoryTaskRepository r) => EditTask(
    repository: r,
    store: store,
    janitor: janitorFor(r, store, registry),
    clock: _FixedClock(),
  );

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    edit = editFor(repo);
  });

  tearDown(() => repo.dispose());

  Future<Task> withImage(String id, {String? text}) async {
    final a = await store.commit(
      stageImage(store, 'img-$id'),
      DateTime.utc(2026),
    );
    final t = sampleTask(
      id: id,
      colorKey: 3,
      rank: 'C',
    ).withContent(text, a, DateTime.utc(2026));
    await repo.insert(t);
    return t;
  }

  group('Texto (spec 005)', () {
    test('CA-005-05: guarda el texto recortado', () async {
      final task = sampleTask(id: 'a');
      await repo.insert(task);
      final updated = await edit(task, '  Llamar a Lucía  ');
      expect(updated.text, 'Llamar a Lucía');
      expect((await repo.findById('a'))!.text, 'Llamar a Lucía');
    });

    test('CL-005-2: sin cambios no toca updatedAt', () async {
      final task = sampleTask(id: 'a', text: 'Igual');
      await repo.insert(task);
      final same = await edit(task, 'Igual');
      expect(same, task);
      expect((await repo.findById('a'))!.updatedAt, task.updatedAt);
    });

    test('CA-005-06: no deja una tarea vacía', () async {
      final task = sampleTask(id: 'a');
      await repo.insert(task);
      await expectLater(edit(task, '   '), throwsA(isA<InvalidTaskText>()));
    });
  });

  group('Imagen (spec 007)', () {
    test('CA-007-06: añadir una imagen conserva posición y color y deja el '
        'texto opcional', () async {
      final task = sampleTask(id: 'a', colorKey: 3, rank: 'C');
      await repo.insert(task);
      await repo.insert(sampleTask(id: 'b', rank: 'M'));
      registry.add('new');
      final t = await edit(
        task,
        '',
        attachment: ReplaceAttachment(stageImage(store, 'new')),
      );
      final stored = (await repo.findById('a'))!;
      expect((stored.text, stored.attachment?.id), (null, 'new'));
      expect((stored.rank, stored.colorKey), ('C', 3));
      expect(t, stored);
      expect(registry.active, isEmpty);
      expect((await repo.currentTask())!.id, 'a');
    });

    test('CA-007-06: sustituir borra los archivos de la anterior', () async {
      final task = await withImage('a', text: 'Horario');
      await edit(
        task,
        'Horario',
        attachment: ReplaceAttachment(stageImage(store, 'new')),
      );
      expect(await store.storedIds(), {'new'});
      expect((await repo.findById('a'))!.attachment!.id, 'new');
    });

    test(
      'CA-007-06: quitar la imagen deja el texto y borra los archivos',
      () async {
        final task = await withImage('a', text: 'Horario');
        await edit(task, 'Horario', attachment: const RemoveAttachment());
        expect((await repo.findById('a'))!.attachment, isNull);
        expect(await store.storedIds(), isEmpty);
      },
    );

    test('CA-007-06: sin texto ni imagen no guarda y no borra nada', () async {
      final task = await withImage('a');
      await expectLater(
        edit(task, '  ', attachment: const RemoveAttachment()),
        throwsA(isA<InvalidTaskText>()),
      );
      expect((await repo.findById('a'))!.attachment!.id, 'img-a');
      expect(await store.storedIds(), {'img-a'});
    });

    test('CA-007-06: conservar la imagen y cambiar solo el texto', () async {
      final task = await withImage('a');
      final t = await edit(task, 'Ahora con texto');
      expect((t.text, t.attachment!.id), ('Ahora con texto', 'img-a'));
      expect(await store.storedIds(), {'img-a'});
    });

    test('CA-007-16 / CL-007-3: si falla al guardar, la nueva vuelve a la '
        'preparación y la anterior sigue intacta', () async {
      final failing = _FailingUpdateRepository();
      final a = await store.commit(
        stageImage(store, 'old'),
        DateTime.utc(2026),
      );
      final task = sampleTask(id: 'a').withContent(null, a, DateTime.utc(2026));
      registry.add('new');
      await expectLater(
        editFor(failing)(
          task,
          '',
          attachment: ReplaceAttachment(stageImage(store, 'new')),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await store.storedIds(), {'old'});
      expect(await store.stagingIds(), {'new'});
      expect(registry.active, {'new'});
      await failing.dispose();
    });

    test(
      'CA-007-16: si la tarea ya no existe, la imagen nueva se borra',
      () async {
        final ghost = sampleTask(id: 'ghost');
        await edit(
          ghost,
          'x',
          attachment: ReplaceAttachment(stageImage(store, 'new')),
        );
        expect(await store.storedIds(), isEmpty);
      },
    );
  });

  group('Web (spec 009)', () {
    const url = 'https://congreso.example.org/programa';
    const other = 'https://otra.example.com/';

    Future<Task> withWeb(String id) async {
      final a = await store.commit(
        StagedWeb(id: 'web-$id', url: url),
        DateTime.utc(2026),
      );
      final t = sampleTask(
        id: id,
        colorKey: 3,
        rank: 'C',
      ).withContent(null, a, DateTime.utc(2026));
      await repo.insert(t);
      return t;
    }

    test('CA-009-05: sustituir la dirección conserva posición y color, y '
        'sigue sin texto', () async {
      final task = await withWeb('a');
      await repo.insert(sampleTask(id: 'b', rank: 'M'));
      final t = await edit(
        task,
        'texto que no se guarda',
        attachment: const ReplaceAttachment(StagedWeb(id: 'w2', url: other)),
      );
      final stored = (await repo.findById('a'))!;
      expect((stored.text, stored.attachment?.id), (null, 'w2'));
      expect(stored.attachment!.url, other);
      expect((stored.rank, stored.colorKey), ('C', 3));
      expect(t, stored);
      expect((await repo.currentTask())!.id, 'a');
      expect(await store.storedIds(), isEmpty);
    });

    test('CA-009-05: la misma dirección no cambia nada', () async {
      final task = await withWeb('a');
      final same = await edit(
        task,
        '',
        attachment: const ReplaceAttachment(StagedWeb(id: 'w2', url: url)),
      );
      expect(same, task);
      final stored = (await repo.findById('a'))!;
      expect(stored.attachment!.id, 'web-a');
      expect(stored.updatedAt, task.updatedAt);
    });

    test('CA-009-05: si falla al guardar, la tarea sigue como estaba y no '
        'queda nada', () async {
      final task = await withWeb('a');
      final failing = _FailingUpdateRepository();
      await failing.insert(task);
      await expectLater(
        editFor(failing)(
          task,
          '',
          attachment: const ReplaceAttachment(StagedWeb(id: 'w2', url: other)),
        ),
        throwsA(isA<StateError>()),
      );
      expect((await failing.findById('a'))!.attachment!.url, url);
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), isEmpty);
      await failing.dispose();
    });
  });
}
