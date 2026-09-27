import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/usecases/complete_current_task.dart';
import 'package:app/domain/usecases/delete_current_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late DeleteCurrentTask delete;
  final at = DateTime.utc(2026, 9, 26, 9);

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    delete = DeleteCurrentTask(
      repository: repo,
      janitor: janitorFor(repo, store),
    );
  });

  tearDown(() => repo.dispose());

  test(
    'CA-004-03 / CA-004-09 (ADR-0012): borra la tarea del todo y devuelve la '
    'siguiente tarea actual',
    () async {
      final first = sampleTask(id: 'a', rank: 'C', text: 'Primera');
      await repo.insert(first);
      await repo.insert(sampleTask(id: 'b', rank: 'M', text: 'Segunda'));

      final result = await delete(first);

      expect(result.deleted.id, 'a');
      expect(result.next?.id, 'b');
      expect(await repo.findById('a'), isNull);
    },
  );

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

  test('CA-007-16: eliminar borra los archivos de su imagen', () async {
    final a = await store.commit(stageImage(store, 'img'), at);
    final t = sampleTask(id: 'a').withContent(null, a, at);
    await repo.insert(t);
    await delete(t);
    expect(await store.storedIds(), isEmpty);
  });
}
