import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

/// Repositorio que puede fallar al quitar o al leer después de quitar, y que
/// anota qué estaba protegido en el momento de quitar.
class _Repo extends InMemoryTaskRepository {
  Set<String> Function()? heldAtRemove;
  Set<String>? seenHeld;
  bool failRemove = false;
  bool failReadsAfterRemove = false;
  bool _removed = false;

  @override
  Future<bool> remove(String id) async {
    seenHeld = heldAtRemove?.call();
    if (failRemove) throw StateError('disk I/O error');
    return _removed = await super.remove(id);
  }

  void _check() {
    if (failReadsAfterRemove && _removed) throw StateError('disk I/O error');
  }

  @override
  Future<Task?> currentTask() async {
    _check();
    return super.currentTask();
  }

  @override
  Future<int> countPending() async {
    _check();
    return super.countPending();
  }

  @override
  Future<List<Task>> pendingTasks() async {
    _check();
    return super.pendingTasks();
  }
}

void main() {
  late _Repo repo;
  late MemoryAttachmentStore store;
  late AttachmentJanitor janitor;
  late DeletePendingTask delete;
  final at = DateTime.utc(2026, 9, 26, 9);

  setUp(() async {
    repo = _Repo();
    store = MemoryAttachmentStore();
    janitor = janitorFor(repo, store);
    delete = DeletePendingTask(repository: repo, janitor: janitor);
    for (final (id, rank) in [('a', 'C'), ('b', 'M'), ('c', 'X')]) {
      await repo.insert(sampleTask(id: id, rank: rank, text: 'Tarea $id'));
    }
  });

  tearDown(() => repo.dispose());

  Future<Task> withImage(String id, String rank) async {
    final a = await store.commit(stageImage(store, 'img-$id'), at);
    final t = sampleTask(id: id, rank: rank).withContent('Foto', a, at);
    await repo.insert(t);
    return t;
  }

  test(
    'CA-006-14: elimina una tarea intermedia y la actual no cambia',
    () async {
      final result = await delete('b');
      expect(result.deleted.id, 'b');
      expect(result.wasCurrent, isFalse);
      expect(result.next?.id, 'a');
      expect(result.remaining, 2);
      // Fuera de la cola desde el primer momento (CA-014-14).
      expect(await repo.findById('b'), isNull);
    },
  );

  test(
    'CA-006-14: eliminar la primera deja como actual la siguiente',
    () async {
      final result = await delete('a');
      expect(result.wasCurrent, isTrue);
      expect(result.next?.id, 'b');
      expect(result.remaining, 2);
    },
  );

  test('CL-006-3: eliminar la última pendiente deja la cola vacía', () async {
    await delete('a');
    await delete('b');
    final result = await delete('c');
    expect(result.next, isNull);
    expect(result.remaining, 0);
    expect(await repo.hasEverHadTasks(), isTrue);
  });

  test('no elimina una tarea que ya no está', () async {
    await delete('b');
    await expectLater(delete('b'), throwsA(isA<TaskNotPending>()));
    await expectLater(delete('missing'), throwsA(isA<TaskNotPending>()));
    expect(await repo.findById('a'), isNotNull);
  });

  test('CA-014-15 / ADR-0021: tras eliminar desde el listado, la fila no '
      'está y los archivos sí, protegidos, hasta discardHeld', () async {
    final t = await withImage('d', 'Z');
    final result = await delete('d');
    expect(result.deleted, t);
    expect(await repo.findById('d'), isNull);
    expect(await store.storedIds(), {'img-d'});
    expect(janitor.held, {'img-d'});

    await janitor.sweep();
    expect(await store.storedIds(), {'img-d'});

    await janitor.discardHeld('img-d');
    expect(await store.storedIds(), isEmpty);
  });

  test('ADR-0021: protege el adjunto antes de quitar la fila', () async {
    await withImage('d', 'Z');
    repo.heldAtRemove = () => janitor.held;
    await delete('d');
    expect(repo.seenHeld, {'img-d'});
  });

  test('CA-006-14: si falla al quitar, lanza y deja de proteger el adjunto '
      '(la tarea sigue con sus archivos)', () async {
    final t = await withImage('d', 'Z');
    repo.failRemove = true;
    await expectLater(delete('d'), throwsA(isA<StateError>()));
    expect(janitor.held, isEmpty);
    expect(await repo.findById('d'), t);
    expect(await store.storedIds(), {'img-d'});
  });

  test('ADR-0021: un fallo al leer la siguiente o el recuento tras quitar la '
      'fila no es un fallo al eliminar', () async {
    final t = await withImage('d', 'A');
    repo.failReadsAfterRemove = true;
    final result = await delete('d');
    expect(result.deleted, t);
    expect(result.wasCurrent, isTrue);
    expect(result.remaining, 3);
    // La siguiente la toma la pantalla del flujo de la cola.
    expect(result.next, isNull);
    expect(janitor.held, {'img-d'});
  });

  test(
    'ADR-0021: si no era la actual, la actual no se vuelve a leer',
    () async {
      await withImage('d', 'Z');
      repo.failReadsAfterRemove = true;
      final result = await delete('d');
      expect(result.wasCurrent, isFalse);
      expect(result.next?.id, 'a');
    },
  );

  test('CL-006-5 / ADR-0021: dos eliminaciones a la vez de la misma tarea no '
      'le quitan la protección', () async {
    await withImage('d', 'Z');
    final results = await Future.wait([
      delete('d').then<Object>((r) => r, onError: (Object e) => e),
      delete('d').then<Object>((r) => r, onError: (Object e) => e),
    ]);
    expect(results.whereType<TaskNotPending>(), hasLength(1));
    expect(janitor.held, {'img-d'});
    await janitor.sweep();
    expect(await store.storedIds(), {'img-d'});
  });
}
