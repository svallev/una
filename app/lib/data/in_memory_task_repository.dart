import 'dart:async';

import '../domain/entities/rank.dart';
import '../domain/entities/task.dart';
import '../domain/ports/task_repository.dart';

/// Implementación en memoria del repositorio (tests y contrato común con drift).
class InMemoryTaskRepository implements TaskRepository, SettingsRepository {
  final Map<String, Task> _tasks = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _firstRunDone = false;

  List<Task> get _pending => _tasks.values.where((t) => t.isPending).toList()
    // Con claves iguales (no debería haberlas), el id desempata: el orden
    // es el mismo en todas partes.
    ..sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.id.compareTo(b.id);
    });

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
  Future<List<Task>> pendingTasks() async => _pending;

  @override
  Stream<List<Task>> watchPending() {
    StreamSubscription<void>? sub;
    late final StreamController<List<Task>> out;
    out = StreamController<List<Task>>(
      onListen: () {
        out.add(_pending);
        sub = _changes.stream.listen((_) => out.add(_pending));
      },
      onCancel: () async {
        await sub?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  @override
  Future<bool> reorder(String id, String rank, DateTime at) async {
    final task = _tasks[id];
    if (task == null || !task.isPending) return false;
    _tasks[id] = task.withRank(rank, at);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> renumberPending(DateTime at) async {
    final pending = _pending;
    final ranks = Rank.evenlySpaced(pending.length);
    for (var i = 0; i < pending.length; i++) {
      _tasks[pending[i].id] = pending[i].withRank(ranks[i], at);
    }
    _changes.add(null);
  }

  @override
  Future<Task?> findById(String id) async => _tasks[id];

  @override
  Future<bool> hasHistory() async => _tasks.values.any((t) => !t.isPending);

  @override
  Future<void> insert(Task task) async {
    _tasks[task.id] = task;
    _changes.add(null);
  }

  @override
  Future<bool> updateText(String id, String text, DateTime at) async {
    final task = _tasks[id];
    if (task == null || task.deletedAt != null) return false;
    _tasks[id] = task.withText(text, at);
    _changes.add(null);
    return true;
  }

  @override
  Future<bool> complete(String id, DateTime at) async {
    final task = _tasks[id];
    if (task == null || !task.isPending) return false;
    _tasks[id] = task.complete(at);
    _changes.add(null);
    return true;
  }

  @override
  Future<bool> delete(String id, DateTime at) async {
    final task = _tasks[id];
    if (task == null || task.deletedAt != null) return false;
    _tasks[id] = task.tombstone(at);
    _changes.add(null);
    return true;
  }

  @override
  Future<bool> firstRunDone() async => _firstRunDone;

  @override
  Future<void> setFirstRunDone() async => _firstRunDone = true;

  Future<void> dispose() => _changes.close();
}
