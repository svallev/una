import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/commit_group.dart';
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

/// Mira el disco en el instante de escribir y lo que se le pide guardar.
class _ObservingRepository extends InMemoryTaskRepository {
  _ObservingRepository(this._storedIds);

  final Future<Set<String>> Function() _storedIds;
  Set<String>? seen;
  List<Attachment>? lastAttachments;
  int calls = 0;

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    DateTime at, {
    List<Attachment>? attachments,
  }) async {
    calls++;
    lastAttachments = attachments;
    seen = await _storedIds();
    return super.updateContent(id, text, at, attachments: attachments);
  }
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
        attachment: ReplaceAttachment.one(stageImage(store, 'new')),
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
        attachment: ReplaceAttachment.one(stageImage(store, 'new')),
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
          attachment: ReplaceAttachment.one(stageImage(store, 'new')),
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
          attachment: ReplaceAttachment.one(stageImage(store, 'new')),
        );
        expect(await store.storedIds(), isEmpty);
      },
    );
  });

  group('Grupo de fotos (spec 016)', () {
    List<StagedImage> stageGroup(String prefix, int n) => [
      for (var i = 0; i < n; i++) stageImage(store, '$prefix$i'),
    ];

    Future<Task> withGroup(String id, int n, {String? text}) async {
      final saved = [
        for (final s in stageGroup('old', n))
          await store.commit(s, DateTime.utc(2026)),
      ];
      final t = sampleTask(
        id: id,
        colorKey: 3,
        rank: 'C',
      ).withContent(text, null, DateTime.utc(2026), attachments: saved);
      await repo.insert(t);
      return t;
    }

    test('CA-016-07: reemplazar por un grupo de 3 conserva posición y color, '
        'guarda el orden y borra el anterior', () async {
      final task = await withGroup('a', 2, text: 'Horario');
      await repo.insert(sampleTask(id: 'b', rank: 'M'));
      final group = stageGroup('new', 3);
      [for (final g in group) g.id].forEach(registry.add);
      final t = await edit(
        task,
        'Horario',
        attachment: ReplaceAttachment(group),
      );
      final stored = (await repo.findById('a'))!;
      expect(
        [for (final a in stored.attachments) a.id],
        ['new0', 'new1', 'new2'],
      );
      expect((stored.rank, stored.colorKey), ('C', 3));
      expect(t, stored);
      expect(await store.storedIds(), {'new0', 'new1', 'new2'});
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
    });

    test('CA-016-16: el grupo anterior se borra solo tras confirmar la '
        'escritura', () async {
      final observing = _ObservingRepository(() => store.storedIds());
      final task = await withGroup('a', 2);
      await observing.insert(task);
      final group = stageGroup('new', 2);
      await editFor(observing)(task, '', attachment: ReplaceAttachment(group));
      // En el momento de escribir, el anterior seguía en disco.
      expect(observing.seen, {'old0', 'old1', 'new0', 'new1'});
      expect(await store.storedIds(), {'new0', 'new1'});
      await observing.dispose();
    });

    test('CA-016-16 / CL-016-6b: si falla la escritura, las nuevas vuelven a '
        'la preparación y el grupo anterior sigue intacto', () async {
      final failing = _FailingUpdateRepository();
      final task = await withGroup('a', 3);
      await failing.insert(task);
      final group = stageGroup('new', 10);
      [for (final g in group) g.id].forEach(registry.add);
      await expectLater(
        editFor(failing)(task, '', attachment: ReplaceAttachment(group)),
        throwsA(isA<StateError>()),
      );
      expect(await store.storedIds(), {'old0', 'old1', 'old2'});
      expect(await store.stagingIds(), {for (final g in group) g.id});
      expect(registry.active, {for (final g in group) g.id});
      await failing.dispose();
    });

    test('CL-016-6b: si falta una preparación, no se mueve nada y el grupo '
        'anterior sigue intacto', () async {
      final task = await withGroup('a', 2);
      final group = stageGroup('new', 3);
      await store.deleteStaging('new2');
      await expectLater(
        edit(task, '', attachment: ReplaceAttachment(group)),
        throwsA(isA<StagedPhotosLost>()),
      );
      expect(await store.storedIds(), {'old0', 'old1'});
      expect(await store.stagingIds(), {'new0', 'new1'});
      expect((await repo.findById('a'))!.attachments, hasLength(2));
    });

    test('CL-016-13: editar solo el texto de un grupo no toca ningún archivo '
        'ni ninguna fila de adjuntos', () async {
      final spy = _ObservingRepository(() => store.storedIds());
      final task = await withGroup('a', 3, text: 'Antes');
      await spy.insert(task);
      final t = await editFor(spy)(task, 'Después');
      expect(spy.lastAttachments, isNull);
      expect(spy.calls, 1);
      expect(t.text, 'Después');
      expect(t.attachments, task.attachments);
      expect(await store.storedIds(), {'old0', 'old1', 'old2'});
    });

    test('CA-016-07: quitar el grupo borra los archivos de todas', () async {
      final task = await withGroup('a', 3, text: 'Horario');
      final t = await edit(
        task,
        'Horario',
        attachment: const RemoveAttachment(),
      );
      expect(t.attachments, isEmpty);
      expect((await repo.findById('a'))!.attachments, isEmpty);
      expect(await store.storedIds(), isEmpty);
    });

    test(
      'CA-016-16: si la tarea ya no existe, el grupo nuevo se borra entero',
      () async {
        final group = stageGroup('new', 3);
        await edit(
          sampleTask(id: 'ghost'),
          'x',
          attachment: ReplaceAttachment(group),
        );
        expect(await store.storedIds(), isEmpty);
        expect(await store.stagingIds(), isEmpty);
      },
    );

    test(
      'CA-016-14: un grupo no válido o vacío se rechaza sin tocar nada',
      () async {
        final task = await withGroup('a', 2);
        await expectLater(
          edit(task, '', attachment: ReplaceAttachment(stageGroup('n', 11))),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          edit(task, '', attachment: const ReplaceAttachment([])),
          throwsA(isA<ArgumentError>()),
        );
        expect(await store.storedIds(), {'old0', 'old1'});
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
        attachment: ReplaceAttachment.one(
          const StagedWeb(id: 'w2', url: other),
        ),
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
        attachment: ReplaceAttachment.one(const StagedWeb(id: 'w2', url: url)),
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
          attachment: ReplaceAttachment.one(
            const StagedWeb(id: 'w2', url: other),
          ),
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
