import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/usecases/update_task_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 25, 12);
  @override
  DateTime now() => value;
}

void main() {
  late InMemoryTaskRepository repo;
  late UpdateTaskText update;

  setUp(() {
    repo = InMemoryTaskRepository();
    update = UpdateTaskText(repository: repo, clock: _FixedClock());
  });

  tearDown(() => repo.dispose());

  test('CA-005-05: guarda el texto recortado', () async {
    final task = sampleTask(id: 'a');
    await repo.insert(task);
    final updated = await update(task, '  Llamar a Lucía  ');
    expect(updated.text, 'Llamar a Lucía');
    expect((await repo.findById('a'))!.text, 'Llamar a Lucía');
  });

  test('CL-005-2: sin cambios no toca updatedAt', () async {
    final task = sampleTask(id: 'a', text: 'Igual');
    await repo.insert(task);
    final same = await update(task, 'Igual');
    expect(same, task);
    expect((await repo.findById('a'))!.updatedAt, task.updatedAt);
  });

  test('CA-005-06: no deja una tarea vacía', () async {
    final task = sampleTask(id: 'a');
    await repo.insert(task);
    await expectLater(update(task, '   '), throwsA(isA<InvalidTaskText>()));
  });
}
