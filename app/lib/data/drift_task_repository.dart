import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/entities/task.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/task_repository.dart';
import 'db/app_database.dart';

/// Repositorio sobre SQLite (drift). Mismo contrato que [InMemoryTaskRepository].
class DriftTaskRepository implements TaskRepository, SettingsRepository {
  DriftTaskRepository(this.db, {this.clock = const SystemClock()});

  final AppDatabase db;
  final Clock clock;

  static const _firstRunKey = 'firstRunDone';

  SimpleSelectStatement<$TasksTable, TaskRow> _pendingQuery() =>
      db.select(db.tasks)
        ..where(
          (t) =>
              t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull(),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.rank)]);

  @override
  Future<Task?> currentTask() async {
    final row = await (_pendingQuery()..limit(1)).getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  @override
  Stream<Task?> watchCurrentTask() => (_pendingQuery()..limit(1))
      .watchSingleOrNull()
      .map((r) => r == null ? null : _toTask(r));

  @override
  Future<String?> firstPendingRank() async =>
      (await (_pendingQuery()..limit(1)).getSingleOrNull())?.rank;

  @override
  Future<String?> lastPendingRank() async {
    final q = db.select(db.tasks)
      ..where(
        (t) => t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.rank)])
      ..limit(1);
    return (await q.getSingleOrNull())?.rank;
  }

  @override
  Future<int> countPending() async {
    final count = db.tasks.id.count();
    final q = db.selectOnly(db.tasks)
      ..addColumns([count])
      ..where(
        db.tasks.status.equals(TaskStatus.pending.name) &
            db.tasks.deletedAt.isNull(),
      );
    return (await q.getSingle()).read(count) ?? 0;
  }

  @override
  Future<Task?> findById(String id) async {
    final row = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  @override
  Future<bool> hasCompleted() async {
    final q = db.select(db.tasks)
      ..where(
        (t) =>
            t.status.equals(TaskStatus.completed.name) & t.deletedAt.isNull(),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  @override
  Future<void> insert(Task task) => db.into(db.tasks).insert(_toRow(task));

  @override
  Future<bool> updateText(String id, String text, DateTime at) async {
    final rows =
        await (db.update(
          db.tasks,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          TasksCompanion(
            body: Value(text),
            updatedAt: Value(at.millisecondsSinceEpoch),
          ),
        );
    return rows > 0;
  }

  @override
  Future<bool> complete(String id, DateTime at) async {
    final ms = at.millisecondsSinceEpoch;
    final rows =
        await (db.update(db.tasks)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.equals(TaskStatus.pending.name) &
                  t.deletedAt.isNull(),
            ))
            .write(
              TasksCompanion(
                status: Value(TaskStatus.completed.name),
                completedAt: Value(ms),
                updatedAt: Value(ms),
              ),
            );
    return rows > 0;
  }

  @override
  Future<bool> firstRunDone() async {
    final row = await (db.select(
      db.settingEntries,
    )..where((s) => s.key.equals(_firstRunKey))).getSingleOrNull();
    return row != null && jsonDecode(row.value) == true;
  }

  @override
  Future<void> setFirstRunDone() => db
      .into(db.settingEntries)
      .insertOnConflictUpdate(
        SettingEntriesCompanion.insert(
          key: _firstRunKey,
          value: jsonEncode(true),
          updatedAt: clock.now().millisecondsSinceEpoch,
        ),
      );

  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  static DateTime? _dateOrNull(int? ms) => ms == null ? null : _date(ms);

  static Task _toTask(TaskRow r) => Task(
    id: r.id,
    text: r.body,
    status: TaskStatus.values.byName(r.status),
    rank: r.rank,
    colorKey: r.colorKey,
    createdAt: _date(r.createdAt),
    updatedAt: _date(r.updatedAt),
    completedAt: _dateOrNull(r.completedAt),
    deletedAt: _dateOrNull(r.deletedAt),
    dueDate: _dateOrNull(r.dueDate),
    parentId: r.parentId,
    source: r.source,
    externalId: r.externalId,
  );

  static TasksCompanion _toRow(Task t) => TasksCompanion.insert(
    id: t.id,
    body: Value(t.text),
    status: t.status.name,
    rank: t.rank,
    colorKey: t.colorKey,
    createdAt: t.createdAt.millisecondsSinceEpoch,
    updatedAt: t.updatedAt.millisecondsSinceEpoch,
    completedAt: Value(t.completedAt?.millisecondsSinceEpoch),
    deletedAt: Value(t.deletedAt?.millisecondsSinceEpoch),
    dueDate: Value(t.dueDate?.millisecondsSinceEpoch),
    parentId: Value(t.parentId),
    source: Value(t.source),
    externalId: Value(t.externalId),
  );
}
