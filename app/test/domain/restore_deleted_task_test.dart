import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/delete_current_task.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:app/domain/usecases/restore_deleted_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

/// Repositorio cuya escritura al recuperar puede fallar.
class _Repo extends InMemoryTaskRepository {
  bool failInsert = false;

  @override
  Future<void> insert(Task task) async {
    if (failInsert) throw StateError('disk I/O error');
    return super.insert(task);
  }
}

/// Almacén que anota si alguien mueve archivos a la preparación o desde ella.
class _Store extends MemoryAttachmentStore {
  int restaged = 0;
  int committed = 0;

  @override
  Future<void> restage(String id) async {
    restaged++;
    return super.restage(id);
  }

  @override
  Future<Attachment> commit(StagedAttachment staged, DateTime at) async {
    committed++;
    return super.commit(staged, at);
  }
}

void main() {
  late _Repo repo;
  late _Store store;
  late AttachmentJanitor janitor;
  late DeletePendingTask delete;
  late RestoreDeletedTask restore;
  final created = DateTime.utc(2026, 9, 20, 8);
  final edited = DateTime.utc(2026, 9, 25, 18);

  setUp(() async {
    repo = _Repo();
    store = _Store();
    janitor = janitorFor(repo, store);
    delete = DeletePendingTask(repository: repo, janitor: janitor);
    restore = RestoreDeletedTask(repository: repo, janitor: janitor);
    for (final (id, rank, color) in [('a', 'C', 2), ('b', 'M', 5)]) {
      await repo.insert(
        Task(
          id: id,
          text: 'Tarea $id',
          status: TaskStatus.pending,
          rank: rank,
          colorKey: color,
          createdAt: created,
          updatedAt: edited,
        ),
      );
    }
  });

  tearDown(() => repo.dispose());

  Future<Task> withImage(String id, String rank) async {
    final a = await store.commit(stageImage(store, 'img-$id'), created);
    final t = Task(
      id: id,
      text: null,
      attachment: a,
      status: TaskStatus.pending,
      rank: rank,
      colorKey: 7,
      createdAt: created,
      updatedAt: edited,
    );
    await repo.insert(t);
    return t;
  }

  Future<List<Task>> queue() => repo.pendingTasks();

  test('CA-014-09: eliminar y recuperar deja la tarea idéntica (id, rank, '
      'color, fechas y adjunto) en la misma posición', () async {
    final t = await withImage('x', 'G');
    final before = await queue();
    expect(before.map((t) => t.id), ['a', 'x', 'b']);

    final result = await delete('x');
    await restore(result.deleted);

    expect(await queue(), before);
    expect(await repo.findById('x'), t);
    // Sus archivos siguen y ya no están protegidos: pertenecen a una tarea.
    expect(janitor.held, isEmpty);
    expect(await store.storedIds(), {'img-x'});
    await janitor.sweep();
    expect(await store.storedIds(), {'img-x'});
  });

  test('CA-014-09: si vuelve a la posición 1, es otra vez la tarea actual '
      '(la que lo era pasa a la 2)', () async {
    final current = DeleteCurrentTask(repository: repo, janitor: janitor);
    final first = (await repo.currentTask())!;
    final before = await queue();
    final result = await current(first);
    expect(result.next?.id, 'b');

    await restore(result.deleted);

    expect(await repo.currentTask(), first);
    expect(await queue(), before);
  });

  test('CA-014-09: el PDF vuelve con su última posición', () async {
    store.putStaging('pdf', 'document.pdf', tinyImage);
    final pdf = await store.commit(
      const StagedPdf(
        id: 'pdf',
        byteSize: 10,
        width: 595,
        height: 842,
        pageCount: 12,
        originalName: 'Programa.pdf',
      ),
      created,
    );
    await repo.insert(
      sampleTask(id: 'p', rank: 'A').withContent(null, pdf, created),
    );
    const position = PdfPosition(page: 7, offset: 0.25);
    await store.writePosition('pdf', position);

    final result = await delete('p');
    await restore(result.deleted);

    expect((await repo.findById('p'))!.attachment, pdf);
    expect(await store.readPosition('pdf'), position);
  });

  test('CA-014-09: no cuenta como tarea nueva: nunca usa la preparación '
      '(ni restage ni commit)', () async {
    final t = await withImage('x', 'G');
    final committed = store.committed;
    await delete('x');
    await restore(t);
    expect(store.restaged, 0);
    expect(store.committed, committed);
    expect(await store.stagingIds(), isEmpty);
  });

  test('CL-014-3: recuperar dos veces la misma tarea la deja una sola vez y '
      'no falla', () async {
    final t = await withImage('x', 'G');
    await delete('x');
    await restore(t);
    await restore(t);
    expect((await queue()).where((q) => q.id == 'x'), hasLength(1));
    expect(await repo.countPending(), 3);
  });

  test('ADR-0021: si otra pendiente ocupa ese rank, error tipado y ninguna '
      'fila nueva (nunca dos con el mismo)', () async {
    final t = await withImage('x', 'G');
    await delete('x');
    await repo.insert(sampleTask(id: 'intrusa', rank: 'G'));

    await expectLater(restore(t), throwsA(isA<RankTaken>()));

    expect(await repo.findById('x'), isNull);
    expect(await repo.countPending(), 3);
    // Sigue protegido: lo hará definitivo quien lo retuvo.
    expect(janitor.held, {'img-x'});
  });

  test('CA-014-23: si falla la escritura, lanza y el adjunto sigue '
      'protegido (se puede reintentar)', () async {
    final t = await withImage('x', 'G');
    await delete('x');
    repo.failInsert = true;

    await expectLater(restore(t), throwsA(isA<StateError>()));

    expect(await repo.findById('x'), isNull);
    expect(janitor.held, {'img-x'});
    await janitor.sweep();
    expect(await store.storedIds(), {'img-x'});

    // Reintentar: ahora sí.
    repo.failInsert = false;
    await restore(t);
    expect(await repo.findById('x'), t);
    expect(janitor.held, isEmpty);
  });

  test('CA-014-09: recupera también una tarea sin adjunto', () async {
    final b = (await repo.findById('b'))!;
    final result = await delete('b');
    await restore(result.deleted);
    expect(await repo.findById('b'), b);
  });
}
