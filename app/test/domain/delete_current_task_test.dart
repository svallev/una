import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/complete_current_task.dart';
import 'package:app/domain/usecases/delete_current_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

/// Repositorio que puede fallar al quitar o al leer después de quitar, y que
/// anota qué estaba protegido en el momento de quitar.
class _Repo extends InMemoryTaskRepository {
  Set<String> Function()? heldAtRemove;
  Set<String>? seenHeld;
  bool failRemove = false;
  bool removeFindsNothing = false;
  bool failReadsAfterRemove = false;
  bool _removed = false;

  @override
  Future<bool> remove(String id) async {
    seenHeld = heldAtRemove?.call();
    if (failRemove) throw StateError('disk I/O error');
    if (removeFindsNothing) return false;
    return _removed = await super.remove(id);
  }

  @override
  Future<Task?> currentTask() async {
    if (failReadsAfterRemove && _removed) throw StateError('disk I/O error');
    return super.currentTask();
  }
}

void main() {
  late _Repo repo;
  late MemoryAttachmentStore store;
  late AttachmentJanitor janitor;
  late DeleteCurrentTask delete;
  final at = DateTime.utc(2026, 9, 26, 9);

  setUp(() {
    repo = _Repo();
    store = MemoryAttachmentStore();
    janitor = janitorFor(repo, store);
    delete = DeleteCurrentTask(repository: repo, janitor: janitor);
  });

  tearDown(() => repo.dispose());

  Future<Task> withImage(String id, {String rank = 'C'}) async {
    final a = await store.commit(stageImage(store, 'img-$id'), at);
    final t = sampleTask(id: id, rank: rank).withContent(null, a, at);
    await repo.insert(t);
    return t;
  }

  test('CA-004-03 / CA-014-14: quita la tarea de la cola y devuelve la '
      'siguiente tarea actual', () async {
    final first = sampleTask(id: 'a', rank: 'C', text: 'Primera');
    await repo.insert(first);
    await repo.insert(sampleTask(id: 'b', rank: 'M', text: 'Segunda'));

    final result = await delete(first);

    expect(result.deleted.id, 'a');
    expect(result.next?.id, 'b');
    expect(await repo.findById('a'), isNull);
    expect(await repo.countPending(), 1);
  });

  test('CA-004-07: al eliminar la última no queda siguiente', () async {
    final only = sampleTask(id: 'a');
    await repo.insert(only);
    final result = await delete(only);
    expect(result.next, isNull);
    expect(await repo.hasEverHadTasks(), isTrue);
  });

  test('CL-004-1: no elimina una tarea que ya no es la actual', () async {
    final first = sampleTask(id: 'a', rank: 'C');
    final second = sampleTask(id: 'b', rank: 'M');
    await repo.insert(first);
    await repo.insert(second);
    await delete(first);
    await expectLater(delete(first), throwsA(isA<TaskNotCurrent>()));
    expect((await repo.currentTask())!.id, 'b');
    expect(await repo.findById('b'), isNotNull);
  });

  test('CA-014-15 / ADR-0021: tras eliminar, la fila no está y los archivos '
      'sí, protegidos del barrido, hasta discardHeld', () async {
    final t = await withImage('a');
    await delete(t);
    expect(await repo.findById('a'), isNull);
    expect(await repo.attachmentIds(), isEmpty);
    expect(await store.storedIds(), {'img-a'});
    expect(janitor.held, {'img-a'});

    await janitor.sweep();
    expect(await store.storedIds(), {'img-a'});

    await janitor.discardHeld('img-a');
    expect(await store.storedIds(), isEmpty);
  });

  test('CA-014-09: devuelve la tarea leída de la BD (con su adjunto), no la '
      'copia que se le pasa', () async {
    final saved = await withImage('a');
    // La pantalla podría tener una copia sin el adjunto ni las fechas.
    final stale = sampleTask(id: 'a', rank: 'C');
    final result = await delete(stale);
    expect(result.deleted, saved);
    expect(result.deleted.attachment?.id, 'img-a');
  });

  test('ADR-0021: protege el adjunto antes de quitar la fila', () async {
    final t = await withImage('a');
    repo.heldAtRemove = () => janitor.held;
    await delete(t);
    expect(repo.seenHeld, {'img-a'});
  });

  test('CA-004-13: si falla al quitar, lanza y deja de proteger el adjunto '
      '(la tarea sigue en la BD con sus archivos)', () async {
    final t = await withImage('a');
    repo.failRemove = true;
    await expectLater(delete(t), throwsA(isA<StateError>()));
    expect(janitor.held, isEmpty);
    expect(await repo.findById('a'), t);
    expect(await store.storedIds(), {'img-a'});
  });

  test(
    'si al quitar ya no estaba, TaskNotCurrent y deja de protegerlo',
    () async {
      final t = await withImage('a');
      repo.removeFindsNothing = true;
      await expectLater(delete(t), throwsA(isA<TaskNotCurrent>()));
      expect(janitor.held, isEmpty);
    },
  );

  test('ADR-0021: un fallo al leer la siguiente tras quitar la fila no es un '
      'fallo al eliminar', () async {
    final t = await withImage('a');
    await repo.insert(sampleTask(id: 'b', rank: 'M'));
    repo.failReadsAfterRemove = true;
    final result = await delete(t);
    expect(result.deleted, t);
    // La siguiente la toma la pantalla del flujo de la tarea actual.
    expect(result.next, isNull);
    expect(janitor.held, {'img-a'});
  });

  test('ADR-0021: dos eliminaciones a la vez de la misma tarea no le quitan '
      'la protección', () async {
    final t = await withImage('a');
    final results = await Future.wait([
      delete(t).then<Object>((r) => r, onError: (Object e) => e),
      delete(t).then<Object>((r) => r, onError: (Object e) => e),
    ]);
    expect(results.whereType<TaskNotCurrent>(), hasLength(1));
    expect(janitor.held, {'img-a'});
    await janitor.sweep();
    expect(await store.storedIds(), {'img-a'});
  });
}
