import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late DeletePendingTask delete;
  final at = DateTime.utc(2026, 9, 26, 9);

  setUp(() async {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    delete = DeletePendingTask(
      repository: repo,
      janitor: janitorFor(repo, store),
    );
    for (final (id, rank) in [('a', 'C'), ('b', 'M'), ('c', 'X')]) {
      await repo.insert(sampleTask(id: id, rank: rank, text: 'Tarea $id'));
    }
  });

  tearDown(() => repo.dispose());

  test(
    'CA-006-14: elimina una tarea intermedia y la actual no cambia',
    () async {
      final result = await delete('b');
      expect(result.deleted.id, 'b');
      expect(result.wasCurrent, isFalse);
      expect(result.next?.id, 'a');
      expect(result.remaining, 2);
      // Borrada del todo (ADR-0012).
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

  test(
    'CA-007-16: eliminar desde el listado usa el mismo borrado de archivos',
    () async {
      final a = await store.commit(stageImage(store, 'img'), at);
      await repo.insert(
        sampleTask(id: 'd', rank: 'Z').withContent('Foto', a, at),
      );
      await delete('d');
      expect(await store.storedIds(), isEmpty);
    },
  );
}
