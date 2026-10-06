import 'dart:math' show min;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../domain/entities/attachment.dart';
import '../domain/entities/locale_choice.dart';
import '../domain/entities/rank.dart';
import '../domain/entities/task.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/task_repository.dart';
import '../domain/services/settings_codec.dart';
import 'attachment_reader.dart';
import 'db/app_database.dart';

/// Repositorio sobre SQLite (drift). Mismo contrato que [InMemoryTaskRepository].
class DriftTaskRepository implements TaskRepository, SettingsRepository {
  DriftTaskRepository(this.db, {this.clock = const SystemClock()});

  final AppDatabase db;
  final Clock clock;

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

  /// Columnas de [table] con el alias `<alias>.<columna>`, que es el prefijo
  /// que espera `TableInfo.map(tablePrefix: alias)`.
  static String _columns(String alias, List<GeneratedColumn> columns) =>
      [for (final c in columns) '$alias."${c.$name}" AS "$alias.${c.$name}"']
          .join(', ');

  /// Tareas con sus adjuntos (spec 016, plan §3), **en una sola consulta** y
  /// acotada **en SQL** a [maxReadAttachments] filas por tarea, ordenadas por
  /// `(position, id)`: una BD restaurada con un millón de filas en una tarea no
  /// se carga entera (CA-016-25). El `IN (… LIMIT 10)` deja que SQLite use
  /// `idx_attachments_task_position` y busque cada fila por clave primaria.
  /// [where] filtra las tareas; el flujo escucha las dos tablas.
  String _selectSql(String where) =>
      'SELECT ${_columns('t', db.tasks.$columns)}, '
      '${_columns('a', db.attachments.$columns)} '
      'FROM tasks t '
      'LEFT JOIN attachments a ON a.id IN ('
      'SELECT a2.id FROM attachments a2 WHERE a2.task_id = t.id '
      'ORDER BY a2.position, a2.id LIMIT $maxReadAttachments) '
      'WHERE $where '
      'ORDER BY t.rank, t.id, a.position, a.id';

  static const String _pendingSql =
      "t.status = 'pending' AND t.deleted_at IS NULL";

  /// La primera pendiente en la misma consulta, sin `LIMIT 1` sobre el `JOIN`
  /// (cortaría el grupo): se elige en una subconsulta.
  static const String _currentSql =
      't.id = (SELECT t2.id FROM tasks t2 '
      "WHERE t2.status = 'pending' AND t2.deleted_at IS NULL "
      'ORDER BY t2.rank, t2.id LIMIT 1)';

  /// Las consultas de lectura, para comprobar su plan en los tests.
  @visibleForTesting
  String get currentTaskSql => _selectSql(_currentSql);

  Selectable<QueryRow> _query(
    String where, [
    List<Variable> variables = const [],
  ]) => db.customSelect(
    _selectSql(where),
    variables: variables,
    readsFrom: {db.tasks, db.attachments},
  );

  /// Agrupa las filas (una por foto, en orden) en tareas, en el mismo orden.
  List<Task> _tasksFrom(List<QueryRow> rows) {
    final tasks = <String, TaskRow>{};
    final attachments = <String, List<Attachment>>{};
    for (final row in rows) {
      final task = db.tasks.map(row.data, tablePrefix: 't');
      tasks.putIfAbsent(task.id, () => task);
      final list = attachments.putIfAbsent(task.id, () => []);
      if (row.data['a.id'] != null) {
        list.add(_toAttachment(db.attachments.map(row.data, tablePrefix: 'a')));
      }
    }
    return [
      for (final e in tasks.entries) _toTask(e.value, attachments[e.key]!),
    ];
  }

  /// Pendiente: sin marca (tras la migración a v2 no queda ninguna, pero así
  /// las consultas siguen usando el índice `(status, deletedAt, rank)`).
  static Expression<bool> _pendingWhere($TasksTable t) =>
      t.status.equals(TaskStatus.pending.name) & t.deletedAt.isNull();

  @override
  Future<Task?> currentTask() async =>
      _tasksFrom(await _query(_currentSql).get()).firstOrNull;

  @override
  Stream<Task?> watchCurrentTask() =>
      _query(_currentSql).watch().map((rows) => _tasksFrom(rows).firstOrNull);

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
  Future<List<Task>> pendingTasks() async =>
      _tasksFrom(await _query(_pendingSql).get());

  @override
  Stream<List<Task>> watchPending() =>
      _query(_pendingSql).watch().map(_tasksFrom);

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
  Future<Task?> findById(String id) async =>
      _tasksFrom(await _query('t.id = ?', [Variable.withString(id)]).get())
          .firstOrNull;

  @override
  Future<void> insert(Task task) => db.transaction(() async {
    await db.into(db.tasks).insert(_toRow(task));
    final a = task.attachment;
    if (a != null) {
      await db.into(db.attachments).insert(_toAttachmentRow(task.id, a));
    }
    await _setFlag(SettingKeys.hasEverHadTasks, true);
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

  /// Trozos de [existingAttachmentIds]: bien por debajo del límite de
  /// variables de SQLite.
  static const int _idsPerQuery = 500;

  @override
  Future<Set<String>> existingAttachmentIds(Iterable<String> ids) async {
    final all = ids.toSet().toList();
    final found = <String>{};
    for (var i = 0; i < all.length; i += _idsPerQuery) {
      final chunk = all.sublist(i, min(i + _idsPerQuery, all.length));
      final rows =
          await (db.selectOnly(db.attachments)
                ..addColumns([db.attachments.id])
                ..where(db.attachments.id.isIn(chunk)))
              .get();
      found.addAll(rows.map((r) => r.read(db.attachments.id)!));
    }
    return found;
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

  /// Texto guardado de [key], tal cual (null si no hay fila). Lo decodifica
  /// siempre `settings_codec.dart`, que no lanza (CA-015-26).
  Future<String?> _raw(String key) async {
    final row = await (db.select(
      db.settingEntries,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setRaw(String key, String value) => db
      .into(db.settingEntries)
      .insertOnConflictUpdate(
        SettingEntriesCompanion.insert(
          key: key,
          value: value,
          updatedAt: clock.now().millisecondsSinceEpoch,
        ),
      );

  Future<void> _setFlag(String key, bool value) =>
      _setRaw(key, encodeFlag(value));

  @override
  Future<bool> hasEverHadTasks() async =>
      decodeFlag(await _raw(SettingKeys.hasEverHadTasks));

  @override
  Future<bool> firstRunDone() async =>
      decodeFlag(await _raw(SettingKeys.firstRunDone));

  @override
  Future<void> setFirstRunDone() => _setFlag(SettingKeys.firstRunDone, true);

  @override
  Future<bool> keepScreenOn() async =>
      decodeKeepScreenOn(await _raw(SettingKeys.keepScreenOn));

  @override
  Future<void> setKeepScreenOn(bool value) =>
      _setFlag(SettingKeys.keepScreenOn, value);

  @override
  Future<LocaleChoice> locale() async =>
      decodeLocaleChoice(await _raw(SettingKeys.locale));

  @override
  Future<void> setLocale(LocaleChoice choice) =>
      _setRaw(SettingKeys.locale, encodeLocaleChoice(choice));

  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  static DateTime? _dateOrNull(int? ms) => ms == null ? null : _date(ms);

  static Task _toTask(TaskRow r, List<Attachment> attachments) => Task(
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
    attachments: attachments,
  );

  /// Lectura tolerante (CA-016-25): nunca lanza, ver [readAttachment].
  static Attachment _toAttachment(AttachmentRow r) => readAttachment(
    id: r.id,
    kind: r.kind,
    origin: r.origin,
    mime: r.mime,
    byteSize: r.byteSize,
    width: r.width,
    height: r.height,
    createdAt: _date(r.createdAt),
    originalName: r.originalName,
    pageCount: r.pageCount,
    url: r.sourceUrl,
  );

  /// Una página web no tiene archivos ni medidas: `relPath` vacío (es
  /// obligatorio) y solo la dirección en `sourceUrl`; `sourceHost` y la
  /// captura quedan nulos (plan §3, ADR-0016). Sin cambio de esquema.
  static AttachmentsCompanion _toAttachmentRow(String taskId, Attachment a) =>
      a.isWeb
      ? AttachmentsCompanion.insert(
          id: a.id,
          taskId: taskId,
          kind: a.kind.name,
          origin: a.origin.name,
          mime: a.mime,
          byteSize: a.byteSize,
          relPath: '',
          sourceUrl: Value(a.url),
          createdAt: a.createdAt.millisecondsSinceEpoch,
        )
      : AttachmentsCompanion.insert(
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
