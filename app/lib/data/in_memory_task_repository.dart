import 'dart:async';

import '../domain/entities/task.dart';
import '../domain/ports/task_repository.dart';

/// Implementación en memoria del repositorio (tests y contrato común con drift).
class InMemoryTaskRepository implements TaskRepository, SettingsRepository {
  final Map<String, Task> _tasks = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _firstRunDone = false;

  List<Task> get _pending =>
      _tasks.values.where((t) => t.isPending).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));

  @override
  Future<Task?> currentTask() async => _pending.firstOrNull;

  @override
  Stream<Task?> watchCurrentTask() {
    StreamSubscription<void>? sub;
    late final StreamController<Task?> out;
    out = StreamController<Task?>(
      onListen: () async {
        out.add(await currentTask());
        sub = _changes.stream.listen((_) async => out.add(await currentTask()));
      },
      onCancel: () async {
        await sub?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  @override
  Future<String?> firstPendingRank() async => _pending.firstOrNull?.rank;

  @override
  Future<String?> lastPendingRank() async => _pending.lastOrNull?.rank;

  @override
  Future<int> countPending() async => _pending.length;

  @override
  Future<Task?> findById(String id) async => _tasks[id];

  @override
  Future<bool> hasCompleted() async => _tasks.values.any(
    (t) => t.status == TaskStatus.completed && t.deletedAt == null,
  );

  @override
  Future<void> insert(Task task) async {
    _tasks[task.id] = task;
    _changes.add(null);
  }

  @override
  Future<void> complete(String id, DateTime at) async {
    final task = _tasks[id];
    if (task == null || !task.isPending) return;
    _tasks[id] = task.complete(at);
    _changes.add(null);
  }

  @override
  Future<bool> firstRunDone() async => _firstRunDone;

  @override
  Future<void> setFirstRunDone() async => _firstRunDone = true;

  Future<void> dispose() => _changes.close();
}
