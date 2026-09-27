import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/usecases/complete_current_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late CompleteCurrentTask complete;

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    complete = CompleteCurrentTask(
      repository: repo,
      janitor: janitorFor(repo, store),
    );
  });

  tearDown(() => repo.dispose());

  test('CA-003-03a / CA-003-06 (ADR-0012): borra la tarea del todo y '
      'devuelve la siguiente', () async {
    final first = sampleTask(id: 'a', rank: 'C', text: 'Primera');
    await repo.insert(first);
    await repo.insert(sampleTask(id: 'b', rank: 'M', text: 'Segunda'));

    final result = await complete(first);

    // La completada, tal como se veía (para la rotura).
    expect(result.completed, first);
    expect(result.next?.id, 'b');
    expect(await repo.findById('a'), isNull);
  });

  test('CA-003-05: al completar la última no queda siguiente', () async {
    final only = sampleTask(id: 'a');
    await repo.insert(only);
    final result = await complete(only);
    expect(result.next, isNull);
    expect(await repo.currentTask(), isNull);
    // "Todo hecho." (CA-003-11): ya se guardó una tarea alguna vez.
    expect(await repo.hasEverHadTasks(), isTrue);
  });

  test(
    'no completa una tarea que ya no es la actual (dos invocaciones seguidas)',
    () async {
      final first = sampleTask(id: 'a', rank: 'C');
      await repo.insert(first);
      await repo.insert(sampleTask(id: 'b', rank: 'M'));
      await complete(first);
      await expectLater(complete(first), throwsA(isA<TaskNotCurrent>()));
      expect((await repo.currentTask())!.id, 'b');
    },
  );

  test(
    'CA-007-17 (ADR-0012): completar borra los archivos de su imagen',
    () async {
      final at = DateTime.utc(2026, 9, 27);
      final a = await store.commit(stageImage(store, 'img'), at);
      final t = sampleTask(id: 'a').withContent(null, a, at);
      await repo.insert(t);
      final result = await complete(t);
      expect(result.completed.attachment!.id, 'img');
      expect(await store.storedIds(), isEmpty);
      expect(await repo.attachmentIds(), isEmpty);
    },
  );
}
