import 'dart:math';

import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/entities/queue_position.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/usecases/create_task.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 24, 10);
  @override
  DateTime now() => value;
}

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'id-${_n++}';
}

void main() {
  late InMemoryTaskRepository repo;
  late CreateTask create;

  setUp(() {
    repo = InMemoryTaskRepository();
    create = CreateTask(
      repository: repo,
      clock: _FixedClock(),
      ids: _SeqIds(),
      colors: ColorPicker(Random(3)),
    );
  });

  tearDown(() => repo.dispose());

  test(
    'CA-001-04: la primera tarea queda pendiente y pasa a ser la actual',
    () async {
      final t = await create('  Llamar a Marta ');
      expect(t.text, 'Llamar a Marta');
      expect(t.status, TaskStatus.pending);
      expect(await repo.currentTask(), t);
      expect(t.createdAt, DateTime.utc(2026, 9, 24, 10));
    },
  );

  test('CA-001-04 / CL-001-1: no se crea una tarea con texto vacío', () async {
    await expectLater(create('   '), throwsA(isA<InvalidTaskText>()));
    expect(await repo.countPending(), 0);
  });

  test(
    'R4: "arriba del todo" la convierte en la actual; "a la cola" no',
    () async {
      final first = await create('Primera');
      final top = await create('Arriba', position: QueuePosition.top);
      expect((await repo.currentTask())!.id, top.id);
      await create('Al final', position: QueuePosition.end);
      expect((await repo.currentTask())!.id, top.id);
      expect(await repo.lastPendingRank(), isNot(first.rank));
    },
  );

  test(
    'CA-001-08: el color nuevo es distinto del de la tarea actual',
    () async {
      for (var i = 0; i < 50; i++) {
        final current = await repo.currentTask();
        final t = await create('Tarea $i');
        if (current != null) expect(t.colorKey, isNot(current.colorKey));
      }
    },
  );

  test('watchCurrentTask emite la nueva tarea actual', () async {
    final emitted = <String?>[];
    final sub = repo.watchCurrentTask().listen((t) => emitted.add(t?.text));
    await pumpEventQueue();
    await create('A');
    await create('B');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [null, 'A', 'B']);
  });

  test(
    'CL-002-1 / ADR-0002: 1000 inserciones arriba del todo dejan claves ≤ 50',
    () async {
      final ids = <String>[];
      for (var i = 0; i < 1000; i++) {
        ids.insert(0, (await create('Tarea $i')).id);
      }
      final pending = await repo.pendingTasks();
      expect([for (final t in pending) t.id], ids);
      for (final t in pending) {
        expect(t.rank.length, lessThanOrEqualTo(Rank.maxLength));
      }
    },
  );
}
