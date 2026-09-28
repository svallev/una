import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/entities/attachment.dart';
import '../domain/entities/rank.dart';
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
  static const _hasEverHadTasksKey = 'hasEverHadTasks';
  static const _keepScreenOnKey = 'keepScreenOn';

  SimpleSelectStatement<$TasksTable, TaskRow> _pendingQuery() =>
      db.select(db.tasks)
        ..where(
          (t) =>
              t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull(),
        )
        // El id desempata si dos claves coincidieran.
        ..orderBy([
          (t) => OrderingTerm.asc(t.rank),
          (t) => OrderingTerm.asc(t.id),
        ]);

  /// Tareas con su adjunto (v1: 0..1), en una sola consulta (I-1).
  JoinedSelectStatement<HasResultSet, dynamic> _withAttachment(
    Expression<bool> where, {
    bool ordered = false,
    int? limit,
  }) {
    final q = db.select(db.tasks).join([
      leftOuterJoin(
        db.attachments,
        db.attachments.taskId.equalsExp(db.tasks.id),
      ),
    ])..where(where);
    if (ordered) {
      q.orderBy([
        OrderingTerm.asc(db.tasks.rank),
        OrderingTerm.asc(db.tasks.id),
      ]);
    }
    if (limit != null) q.limit(limit);
    return q;
  }

  /// Pendiente: sin marca (tras la migración a v2 no queda ninguna, pero así
  /// las consultas siguen usando el índice `(status, deletedAt, rank)`).
  static Expression<bool> _pendingWhere($TasksTable t) =>
      t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull();

  Expression<bool> get _isPending =>
      db.tasks.status.equals(TaskStatus.pending.name) &
      db.tasks.deletedAt.isNull();

  Task _fromJoin(TypedResult r) => _toTask(
    r.readTable(db.tasks),
    attachment: r.readTableOrNull(db.attachments),
  );

  @override
  Future<Task?> currentTask() async {
    final row = await _withAttachment(
      _isPending,
      ordered: true,
      limit: 1,
    ).getSingleOrNull();
    return row == null ? null : _fromJoin(row);
  }

  @override
  Stream<Task?> watchCurrentTask() => _withAttachment(
    _isPending,
    ordered: true,
    limit: 1,
  ).watchSingleOrNull().map((r) => r == null ? null : _fromJoin(r));

  @override
  Future<String?> firstPendingRank() async =>
      (await (_pendingQuery()..limit(1)).getSingleOrNull())?.rank;

  @override
  Future<String?> lastPendingRank() async {
    final q = db.select(db.tasks)
      ..where(
        (t) => t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.rank),
        (t) => OrderingTerm.desc(t.id),
      ])
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
  Future<List<Task>> pendingTasks() async => (await _withAttachment(
    _isPending,
    ordered: true,
  ).get()).map(_fromJoin).toList();

  @override
  Stream<List<Task>> watchPending() => _withAttachment(
    _isPending,
    ordered: true,
  ).watch().map((rows) => rows.map(_fromJoin).toList());

  @override
  Future<bool> reorder(String id, String rank, DateTime at) async {
    final rows =
        await (db.update(db.tasks)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.equals(TaskStatus.pending.name) &
                  t.deletedAt.isNull(),
            ))
            .write(
              TasksCompanion(
                rank: Value(rank),
                updatedAt: Value(at.millisecondsSinceEpoch),
              ),
            );
    return rows > 0;
  }

  @override
  Future<void> renumberPending(DateTime at) => db.transaction(() async {
    final ids = [for (final r in await _pendingQuery().get()) r.id];
    final ranks = Rank.evenlySpaced(ids.length);
    final ms = at.millisecondsSinceEpoch;
    await db.batch((b) {
      for (var i = 0; i < ids.length; i++) {
        b.update(
          db.tasks,
          TasksCompanion(rank: Value(ranks[i]), updatedAt: Value(ms)),
          where: (t) => t.id.equals(ids[i]),
        );
      }
    });
  });

  @override
  Future<Task?> findById(String id) async {
    final row = await _withAttachment(db.tasks.id.equals(id)).getSingleOrNull();
    return row == null ? null : _fromJoin(row);
  }

  @override
  Future<void> insert(Task task) => db.transaction(() async {
    await db.into(db.tasks).insert(_toRow(task));
    final a = task.attachment;
    if (a != null) {
      await db.into(db.attachments).insert(_toAttachmentRow(task.id, a));
    }
    await _setFlag(_hasEverHadTasksKey, true);
  });

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    Attachment? attachment,
    DateTime at,
  ) => db.transaction(() async {
    final rows =
        await (db.update(
          db.tasks,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          TasksCompanion(
            body: Value(text),
            updatedAt: Value(at.millisecondsSinceEpoch),
          ),
        );
    if (rows == 0) return false;
    final old = await (db.select(
      db.attachments,
    )..where((a) => a.taskId.equals(id))).get();
    if (old.length == 1 && old.single.id == attachment?.id) return true;
    await (db.delete(db.attachments)..where((a) => a.taskId.equals(id))).go();
    if (attachment != null) {
      await db.into(db.attachments).insert(_toAttachmentRow(id, attachment));
    }
    return true;
  });

  @override
  Future<Set<String>> attachmentIds() async {
    final rows = await db.select(db.attachments).get();
    return {for (final r in rows) r.id};
  }

  @override
  Future<bool> remove(String id) => db.transaction(() async {
    final exists = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id) & _pendingWhere(t))).getSingleOrNull();
    if (exists == null) return false;
    // Primero los adjuntos (clave foránea). Los archivos los borra
    // AttachmentJanitor después (CA-007-16).
    await (db.delete(db.attachments)..where((a) => a.taskId.equals(id))).go();
    await (db.delete(db.tasks)..where((t) => t.id.equals(id))).go();
    return true;
  });

  @override
  Future<bool> hasEverHadTasks() => _flag(_hasEverHadTasksKey);

  Future<bool> _flag(String key) async {
    final row = await (db.select(
      db.settingEntries,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row != null && jsonDecode(row.value) == true;
  }

  Future<void> _setFlag(String key, bool value) => db
      .into(db.settingEntries)
      .insertOnConflictUpdate(
        SettingEntriesCompanion.insert(
          key: key,
          value: jsonEncode(value),
          updatedAt: clock.now().millisecondsSinceEpoch,
        ),
      );

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

  @override
  Future<bool> keepScreenOn() async {
    final row = await (db.select(
      db.settingEntries,
    )..where((s) => s.key.equals(_keepScreenOnKey))).getSingleOrNull();
    return row == null || jsonDecode(row.value) != false;
  }

  @override
  Future<void> setKeepScreenOn(bool value) => db
      .into(db.settingEntries)
      .insertOnConflictUpdate(
        SettingEntriesCompanion.insert(
          key: _keepScreenOnKey,
          value: jsonEncode(value),
          updatedAt: clock.now().millisecondsSinceEpoch,
        ),
      );

  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  static DateTime? _dateOrNull(int? ms) => ms == null ? null : _date(ms);

  static Task _toTask(TaskRow r, {AttachmentRow? attachment}) => Task(
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
    attachment: attachment == null ? null : _toAttachment(attachment),
  );

  static Attachment _toAttachment(AttachmentRow r) => Attachment(
    id: r.id,
    kind: AttachmentKind.values.byName(r.kind),
    origin: AttachmentOrigin.values.byName(r.origin),
    mime: r.mime,
    byteSize: r.byteSize,
    width: r.width ?? 0,
    height: r.height ?? 0,
    createdAt: _date(r.createdAt),
    originalName: r.originalName,
    pageCount: r.pageCount,
  );

  static AttachmentsCompanion _toAttachmentRow(String taskId, Attachment a) =>
      AttachmentsCompanion.insert(
        id: a.id,
        taskId: taskId,
        kind: a.kind.name,
        origin: a.origin.name,
        mime: a.mime,
        byteSize: a.byteSize,
        relPath: a.mainPath,
        displayRelPath: Value(a.screenPath),
        thumbRelPath: Value(a.thumbPath),
        originalName: Value(a.originalName),
        pageCount: Value(a.pageCount),
        width: Value(a.width),
        height: Value(a.height),
        createdAt: a.createdAt.millisecondsSinceEpoch,
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
