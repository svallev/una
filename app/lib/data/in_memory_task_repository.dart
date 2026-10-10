import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../domain/entities/attachment.dart';
import '../domain/entities/locale_choice.dart';
import '../domain/entities/rank.dart';
import '../domain/entities/task.dart';
import '../domain/ports/task_repository.dart';
import '../domain/services/settings_codec.dart';
import 'attachment_reader.dart';

/// Implementación en memoria del repositorio (tests y contrato común con drift).
class InMemoryTaskRepository implements TaskRepository, SettingsRepository {
  /// Las tareas **sin adjuntos**; las filas de adjuntos van aparte, como en la
  /// BD (`attachments`), y la lectura las junta ([_read]).
  final Map<String, Task> _tasks = {};
  final Map<String, List<_Row>> _rows = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Ajustes como en la tabla `settings`: clave → texto JSON, que leen los
  /// mismos decodificadores que Drift (CA-015-26).
  final Map<String, String> _settings = {};

  List<Task> get _pendingBases =>
      _tasks.values.where((t) => t.isPending).toList()
        // Con claves iguales (no debería haberlas), el id desempata: el orden
        // es el mismo en todas partes.
        ..sort((a, b) {
          final byRank = a.rank.compareTo(b.rank);
          return byRank != 0 ? byRank : a.id.compareTo(b.id);
        });

  /// La tarea con sus adjuntos como los lee la BD (CA-016-25): ordenados por
  /// `(position, id)` y **como mucho [maxReadAttachments]**.
  Task _read(Task base) {
    final rows = [...?_rows[base.id]]
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0
            ? byPosition
            : a.attachment.id.compareTo(b.attachment.id);
      });
    return base.withContent(
      base.text,
      null,
      base.updatedAt,
      attachments: [
        for (final r in rows.take(maxReadAttachments)) r.attachment,
      ],
    );
  }

  List<Task> get _pending => [for (final t in _pendingBases) _read(t)];

  @override
  Future<Task?> currentTask() async {
    final base = _pendingBases.firstOrNull;
    return base == null ? null : _read(base);
  }

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
  Future<String?> firstPendingRank() async => _pendingBases.firstOrNull?.rank;

  @override
  Future<String?> lastPendingRank() async => _pendingBases.lastOrNull?.rank;

  @override
  Future<int> countPending() async => _pendingBases.length;

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
    final pending = _pendingBases;
    final ranks = Rank.evenlySpaced(pending.length);
    for (var i = 0; i < pending.length; i++) {
      _tasks[pending[i].id] = pending[i].withRank(ranks[i], at);
    }
    _changes.add(null);
  }

  @override
  Future<Task?> findById(String id) async {
    final base = _tasks[id];
    return base == null ? null : _read(base);
  }

  @override
  Future<void> insert(Task task) async {
    // Como una transacción de la BD: una clave repetida (de la tarea o de un
    // adjunto) lanza **antes** de cambiar nada.
    if (_tasks.containsKey(task.id)) {
      throw StateError('UNIQUE constraint failed: tasks.id');
    }
    _checkNewIds(task.attachments, replacing: null);
    _tasks[task.id] = task.withContent(
      task.text,
      null,
      task.updatedAt,
      attachments: const [],
    );
    _rows[task.id] = _rowsFor(task.attachments);
    _settings[SettingKeys.hasEverHadTasks] = encodeFlag(true);
    _changes.add(null);
  }

  static List<_Row> _rowsFor(List<Attachment> list) => [
    for (final (i, a) in list.indexed) _Row(i, a),
  ];

  /// Lanza (sin haber cambiado nada) si [list] repite un id o choca con el de
  /// una fila de otra tarea que no sea [replacing]: la BD lo rechazaría por su
  /// clave primaria y desharía la transacción entera.
  void _checkNewIds(List<Attachment> list, {required String? replacing}) {
    final seen = <String>{
      for (final e in _rows.entries)
        if (e.key != replacing)
          for (final r in e.value) r.attachment.id,
    };
    for (final a in list) {
      if (!seen.add(a.id)) {
        throw StateError('UNIQUE constraint failed: attachments.id');
      }
    }
  }

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    DateTime at, {
    List<Attachment>? attachments,
  }) async {
    final task = _tasks[id];
    if (task == null) return false;
    if (attachments != null) _checkNewIds(attachments, replacing: id);
    _tasks[id] = task.withContent(text, null, at, attachments: const []);
    // null = no tocar las filas (ver el puerto).
    if (attachments != null) _rows[id] = _rowsFor(attachments);
    _changes.add(null);
    return true;
  }

  @override
  Future<Set<String>> attachmentIds() async => {
    for (final rows in _rows.values)
      for (final r in rows) r.attachment.id,
  };

  @override
  Future<Set<String>> existingAttachmentIds(Iterable<String> ids) async =>
      ids.toSet().intersection(await attachmentIds());

  @override
  Future<bool> remove(String id) async {
    final task = _tasks[id];
    if (task == null || !task.isPending) return false;
    _tasks.remove(id);
    _rows.remove(id);
    _changes.add(null);
    return true;
  }

  /// Añade una fila de adjuntos tal cual, sin validar, como una fila de la
  /// tabla `attachments` (también de una copia de seguridad restaurada o
  /// manipulada): posiciones repetidas o con huecos, tipo u origen que no se
  /// conocen, medidas absurdas, más de 10 filas... Se lee con la misma
  /// tolerancia que Drift ([readAttachment]); para probar CA-016-25.
  @visibleForTesting
  void putRawAttachment(
    String taskId, {
    required String id,
    String kind = 'image',
    String origin = 'gallery',
    int position = 0,
    String mime = 'image/jpeg',
    int byteSize = 1234,
    int? width = 4000,
    int? height = 3000,
    String? originalName,
    int? pageCount,
    String? url,
  }) {
    (_rows[taskId] ??= []).add(
      _Row(
        position,
        readAttachment(
          id: id,
          kind: kind,
          origin: origin,
          mime: mime,
          byteSize: byteSize,
          width: width,
          height: height,
          createdAt: DateTime.utc(2026, 9, 26),
          originalName: originalName,
          pageCount: pageCount,
          url: url,
        ),
      ),
    );
    _changes.add(null);
  }

  /// Guarda [raw] tal cual, sin validar, como una fila de la tabla `settings`
  /// (también ilegible o de una copia de seguridad): para probar CA-015-26
  /// igual que en Drift.
  @visibleForTesting
  void putRawSetting(String key, String raw) => _settings[key] = raw;

  @override
  Future<bool> hasEverHadTasks() async =>
      decodeFlag(_settings[SettingKeys.hasEverHadTasks]);

  @override
  Future<bool> firstRunDone() async =>
      decodeFlag(_settings[SettingKeys.firstRunDone]);

  @override
  Future<void> setFirstRunDone() async =>
      _settings[SettingKeys.firstRunDone] = encodeFlag(true);

  @override
  Future<bool> keepScreenOn() async =>
      decodeKeepScreenOn(_settings[SettingKeys.keepScreenOn]);

  @override
  Future<void> setKeepScreenOn(bool value) async =>
      _settings[SettingKeys.keepScreenOn] = encodeFlag(value);

  @override
  Future<bool> lockZoom() async =>
      decodeLockZoom(_settings[SettingKeys.lockZoom]);

  @override
  Future<void> setLockZoom(bool value) async =>
      _settings[SettingKeys.lockZoom] = encodeFlag(value);

  @override
  Future<LocaleChoice> locale() async =>
      decodeLocaleChoice(_settings[SettingKeys.locale]);

  @override
  Future<void> setLocale(LocaleChoice choice) async =>
      _settings[SettingKeys.locale] = encodeLocaleChoice(choice);

  Future<void> dispose() => _changes.close();
}

/// Una fila de `attachments`: el adjunto y su `position`.
class _Row {
  const _Row(this.position, this.attachment);
  final int position;
  final Attachment attachment;
}
