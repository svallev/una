import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/usecases/complete_current_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 25, 9);
  @override
  DateTime now() => value;
}

void main() {
  late InMemoryTaskRepository repo;
  late _FixedClock clock;
  late CompleteCurrentTask complete;

  setUp(() {
    repo = InMemoryTaskRepository();
    clock = _FixedClock();
    complete = CompleteCurrentTask(repository: repo, clock: clock);
  });

  tearDown(() => repo.dispose());

  test(
    'CA-003-03a: guarda la tarea como completada y devuelve la siguiente',
    () async {
      final first = sampleTask(id: 'a', rank: 'C', text: 'Primera');
      await repo.insert(first);
      await repo.insert(sampleTask(id: 'b', rank: 'M', text: 'Segunda'));

      final result = await complete(first);

      expect(result.completed.status, TaskStatus.completed);
      expect(result.completed.completedAt, clock.value);
      expect(result.next?.id, 'b');
      expect((await repo.findById('a'))!.completedAt, clock.value);
    },
  );

  test('CA-003-05: al completar la última no queda siguiente', () async {
    final only = sampleTask(id: 'a');
    await repo.insert(only);
    final result = await complete(only);
    expect(result.next, isNull);
    expect(await repo.hasHistory(), isTrue);
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
}
