import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 26, 9);
  @override
  DateTime now() => value;
}

void main() {
  late InMemoryTaskRepository repo;
  late _FixedClock clock;
  late DeletePendingTask delete;

  setUp(() async {
    repo = InMemoryTaskRepository();
    clock = _FixedClock();
    delete = DeletePendingTask(repository: repo, clock: clock);
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
      final stored = (await repo.findById('b'))!;
      expect(stored.deletedAt, clock.value);
      expect(stored.text, isNull);
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
    expect(await repo.hasHistory(), isTrue);
  });

  test('no elimina una tarea que ya no está pendiente', () async {
    await delete('b');
    await expectLater(delete('b'), throwsA(isA<TaskNotPending>()));
    await repo.complete('a', clock.now());
    await expectLater(delete('a'), throwsA(isA<TaskNotPending>()));
    await expectLater(delete('missing'), throwsA(isA<TaskNotPending>()));
    expect((await repo.findById('a'))!.deletedAt, isNull);
  });
}
