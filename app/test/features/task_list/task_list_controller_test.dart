import 'package:app/app/providers.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/task_list/task_list_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// Repositorio que falla al reordenar (spec 006 §5).
class _FailingReorder extends InMemoryTaskRepository {
  bool fail = true;
  @override
  Future<bool> reorder(String id, String rank, DateTime at) async {
    if (fail) throw StateError('disco lleno');
    return super.reorder(id, rank, at);
  }
}

void main() {
  late _FailingReorder repo;
  late ProviderContainer container;
  late ProviderSubscription<TaskListState> sub;

  List<String> ids() => [
    for (final t in container.read(taskListProvider).tasks ?? <Task>[]) t.id,
  ];

  setUp(() async {
    repo = _FailingReorder()..fail = false;
    for (final (id, rank) in [('a', 'C'), ('b', 'M'), ('c', 'X')]) {
      await repo.insert(sampleTask(id: id, rank: rank));
    }
    container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    sub = container.listen(taskListProvider, (_, _) {});
    await pumpEventQueue();
  });

  tearDown(() {
    sub.close();
    container.dispose();
  });

  test('sigue la cola de la BD', () async {
    expect(ids(), ['a', 'b', 'c']);
    await repo.delete('b', DateTime.utc(2026));
    await pumpEventQueue();
    expect(ids(), ['a', 'c']);
  });

  test('CA-006-06: mover se ve al instante y queda guardado', () async {
    final ctrl = container.read(taskListProvider.notifier);
    final future = ctrl.move(container.read(taskListProvider).tasks!, 'c', 0);
    expect(ids(), ['c', 'a', 'b']); // antes de guardar
    final outcome = await future;
    expect(outcome, isA<Moved>());
    expect((outcome as Moved).position, 1);
    expect(outcome.total, 3);
    await pumpEventQueue();
    expect(ids(), ['c', 'a', 'b']);
    expect((await repo.currentTask())!.id, 'c');
  });

  test('CL-006-4: soltar en el mismo sitio no escribe', () async {
    final ctrl = container.read(taskListProvider.notifier);
    final before = await repo.pendingTasks();
    final outcome = await ctrl.move(before, 'b', 1);
    expect(outcome, isA<NotMoved>());
    expect(await repo.pendingTasks(), before);
  });

  test('spec 006 §5: si falla, la fila vuelve a su sitio', () async {
    repo.fail = true;
    final ctrl = container.read(taskListProvider.notifier);
    final outcome = await ctrl.move(
      container.read(taskListProvider).tasks!,
      'c',
      0,
    );
    expect(outcome, isA<MoveFailed>());
    await pumpEventQueue();
    expect(ids(), ['a', 'b', 'c']);
  });

  test('foco y resaltado cambian su contador en cada petición', () {
    final ctrl = container.read(taskListProvider.notifier);
    ctrl.focus('b');
    expect(container.read(taskListProvider).focus, (id: 'b', serial: 1));
    ctrl.flashAndFocus('c');
    final s = container.read(taskListProvider);
    expect(s.focus, (id: 'c', serial: 2));
    expect(s.flash, (id: 'c', serial: 1));
  });

  test(
    'dos movimientos seguidos de tareas distintas se guardan en orden',
    () async {
      final ctrl = container.read(taskListProvider.notifier);
      final first = ctrl.move(container.read(taskListProvider).tasks!, 'c', 0);
      // Sin esperar: la segunda parte de la cola que ya se ve (c, a, b).
      final second = ctrl.move(container.read(taskListProvider).tasks!, 'b', 1);
      await Future.wait([first, second]);
      await pumpEventQueue();
      expect(
        [for (final t in await repo.pendingTasks()) t.id],
        ['c', 'b', 'a'],
      );
      expect(ids(), ['c', 'b', 'a']);
      final ranks = [for (final t in await repo.pendingTasks()) t.rank];
      expect(ranks.toSet(), hasLength(3));
    },
  );
}
