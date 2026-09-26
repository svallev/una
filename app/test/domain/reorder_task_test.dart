import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/usecases/delete_pending_task.dart';
import 'package:app/domain/usecases/reorder_task.dart';
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
  late ReorderTask reorder;

  Future<List<String>> order() async => [
    for (final t in await repo.pendingTasks()) t.id,
  ];

  setUp(() async {
    repo = InMemoryTaskRepository();
    clock = _FixedClock();
    reorder = ReorderTask(repository: repo, clock: clock);
    for (final (id, rank) in [('a', 'C'), ('b', 'H'), ('c', 'M'), ('d', 'X')]) {
      await repo.insert(sampleTask(id: id, rank: rank, colorKey: 2));
    }
  });

  tearDown(() => repo.dispose());

  test('CA-006-06: llevar una tarea a la posición 1 la hace actual', () async {
    final result = await reorder('c', 0);
    expect(await order(), ['c', 'a', 'b', 'd']);
    expect(result, (position: 1, total: 4));
    expect((await repo.currentTask())!.id, 'c');
  });

  test('CA-006-09: mover arriba, abajo y a la última posición', () async {
    await reorder('c', 1);
    expect(await order(), ['a', 'c', 'b', 'd']);
    await reorder('c', 2);
    expect(await order(), ['a', 'b', 'c', 'd']);
    final result = await reorder('a', 3);
    expect(await order(), ['b', 'c', 'd', 'a']);
    expect(result, (position: 4, total: 4));
  });

  test(
    'CA-006-10: solo cambian el rank y updatedAt de la tarea movida',
    () async {
      final before = {for (final t in await repo.pendingTasks()) t.id: t};
      clock.value = DateTime.utc(2026, 9, 26, 10);
      await reorder('d', 1);
      final after = {for (final t in await repo.pendingTasks()) t.id: t};
      expect(after['d']!.updatedAt, clock.value);
      expect(after['d']!.colorKey, before['d']!.colorKey);
      expect(after['d']!.text, before['d']!.text);
      for (final id in ['a', 'b', 'c']) {
        expect(after[id], before[id]);
      }
    },
  );

  test('CL-006-4: soltar en la misma posición no escribe nada', () async {
    final before = await repo.pendingTasks();
    expect(await reorder('b', 1), isNull);
    expect(await repo.pendingTasks(), before);
  });

  test('no mueve una tarea que ya no está pendiente', () async {
    await repo.complete('b', clock.now());
    await expectLater(reorder('b', 0), throwsA(isA<TaskNotPending>()));
    expect(await order(), ['a', 'c', 'd']);
  });

  test('un índice fuera de rango se ajusta a los extremos', () async {
    await reorder('a', 99);
    expect(await order(), ['b', 'c', 'd', 'a']);
    await reorder('a', -3);
    expect(await order(), ['a', 'b', 'c', 'd']);
  });

  test(
    'CL-006-8: 1000 movimientos alternos mantienen el orden y claves ≤ 50',
    () async {
      // Llevar alternativamente la 3.ª y la 2.ª al hueco entre la 1.ª y la 2.ª
      // hace crecer la clave en cada paso.
      var expected = await order();
      for (var i = 0; i < 1000; i++) {
        final id = expected[2];
        await reorder(id, 1);
        expected = [expected[0], id, expected[1], expected[3]];
        expect(await order(), expected, reason: 'paso $i');
      }
      for (final t in await repo.pendingTasks()) {
        expect(t.rank.length, lessThanOrEqualTo(Rank.maxLength));
      }
    },
  );
}
