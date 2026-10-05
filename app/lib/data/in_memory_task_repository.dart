import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../domain/entities/attachment.dart';
import '../domain/entities/locale_choice.dart';
import '../domain/entities/rank.dart';
import '../domain/entities/task.dart';
import '../domain/ports/task_repository.dart';
import '../domain/services/settings_codec.dart';

/// Implementación en memoria del repositorio (tests y contrato común con drift).
class InMemoryTaskRepository implements TaskRepository, SettingsRepository {
  final Map<String, Task> _tasks = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Ajustes como en la tabla `settings`: clave → texto JSON, que leen los
  /// mismos decodificadores que Drift (CA-015-26).
  final Map<String, String> _settings = {};

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
  Future<void> insert(Task task) async {
    _tasks[task.id] = task;
    _settings[SettingKeys.hasEverHadTasks] = encodeFlag(true);
    _changes.add(null);
  }

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    Attachment? attachment,
    DateTime at,
  ) async {
    final task = _tasks[id];
    if (task == null) return false;
    _tasks[id] = task.withContent(text, attachment, at);
    _changes.add(null);
    return true;
  }

  @override
  Future<Set<String>> attachmentIds() async => {
    for (final t in _tasks.values)
      if (t.attachment case final a?) a.id,
  };

  @override
  Future<bool> remove(String id) async {
    final task = _tasks[id];
    if (task == null || !task.isPending) return false;
    _tasks.remove(id);
    _changes.add(null);
    return true;
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
  Future<LocaleChoice> locale() async =>
      decodeLocaleChoice(_settings[SettingKeys.locale]);

  @override
  Future<void> setLocale(LocaleChoice choice) async =>
      _settings[SettingKeys.locale] = encodeLocaleChoice(choice);

  Future<void> dispose() => _changes.close();
}
