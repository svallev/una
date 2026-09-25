import 'dart:io';

import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Repo = TaskRepository;

Task _task(
  String id,
  String rank, {
  TaskStatus status = TaskStatus.pending,
  DateTime? deletedAt,
  int color = 0,
}) {
  final t = DateTime.utc(2026, 9, 24, 10);
  return Task(
    id: id,
    text: 'Tarea $id',
    status: status,
    rank: rank,
    colorKey: color,
    createdAt: t,
    updatedAt: t,
    completedAt: status == TaskStatus.completed ? t : null,
    deletedAt: deletedAt,
  );
}

/// Misma batería para todas las implementaciones del puerto (docs/testing.md).
void _contract(
  String name,
  Future<(_Repo, SettingsRepository, Future<void> Function())> Function()
  create,
) {
  group('Contrato TaskRepository · $name', () {
    late _Repo repo;
    late SettingsRepository settings;
    late Future<void> Function() dispose;

    setUp(() async => (repo, settings, dispose) = await create());
    tearDown(() => dispose());

    test('sin tareas: no hay tarea actual', () async {
      expect(await repo.currentTask(), isNull);
      expect(await repo.countPending(), 0);
      expect(await repo.firstPendingRank(), isNull);
    });

    test('la tarea actual es la pendiente con menor rank', () async {
      await repo.insert(_task('b', 'M'));
      await repo.insert(_task('a', 'C'));
      await repo.insert(_task('c', 'X'));
      expect((await repo.currentTask())!.id, 'a');
      expect(await repo.firstPendingRank(), 'C');
      expect(await repo.lastPendingRank(), 'X');
      expect(await repo.countPending(), 3);
    });

    test('completadas y eliminadas no cuentan como pendientes', () async {
      await repo.insert(_task('done', 'A', status: TaskStatus.completed));
      await repo.insert(_task('gone', 'B', deletedAt: DateTime.utc(2026)));
      await repo.insert(_task('live', 'C'));
      expect((await repo.currentTask())!.id, 'live');
      expect(await repo.countPending(), 1);
    });

    test(
      'CA-001-10: conserva todos los campos (texto, orden, color, fechas)',
      () async {
        final t = _task('x', Rank.initial(), color: 4);
        await repo.insert(t);
        expect(await repo.currentTask(), t);
      },
    );

    test('watchCurrentTask emite los cambios', () async {
      final seen = <String?>[];
      final sub = repo.watchCurrentTask().listen((t) => seen.add(t?.id));
      await pumpEventQueue();
      await repo.insert(_task('b', 'M'));
      await pumpEventQueue();
      await repo.insert(_task('a', 'C'));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [null, 'b', 'a']);
    });

    test('CA-003-03a / CA-003-06: completar saca la tarea de la cola y la conserva en el histórico', () async {
      await repo.insert(_task('a', 'C', color: 2));
      await repo.insert(_task('b', 'M'));
      expect(await repo.hasCompleted(), isFalse);
      final at = DateTime.utc(2026, 9, 25, 9, 30);

      expect(await repo.complete('a', at), isTrue);

      expect((await repo.currentTask())!.id, 'b');
      expect(await repo.countPending(), 1);
      expect(await repo.hasCompleted(), isTrue);
      final done = (await repo.findById('a'))!;
      expect(done.status, TaskStatus.completed);
      expect(done.completedAt, at);
      expect(done.updatedAt, at);
      expect(done.text, 'Tarea a');
      expect(done.colorKey, 2);
      expect(done.rank, 'C');
    });

    test('completar una tarea que ya no está pendiente no hace nada', () async {
      await repo.insert(_task('done', 'A', status: TaskStatus.completed));
      await repo.insert(_task('gone', 'B', deletedAt: DateTime.utc(2026)));
      final later = DateTime.utc(2027);
      expect(await repo.complete('done', later), isFalse);
      expect(await repo.complete('gone', later), isFalse);
      expect(await repo.complete('missing', later), isFalse);
      expect((await repo.findById('done'))!.completedAt, isNot(later));
      expect((await repo.findById('gone'))!.status, TaskStatus.pending);
      expect(await repo.findById('missing'), isNull);
    });

    test('las completadas eliminadas no cuentan para "Todo hecho."', () async {
      await repo.insert(
        _task(
          'x',
          'A',
          status: TaskStatus.completed,
          deletedAt: DateTime.utc(2026),
        ),
      );
      expect(await repo.hasCompleted(), isFalse);
    });

    test('watchCurrentTask emite la siguiente al completar', () async {
      await repo.insert(_task('a', 'C'));
      await repo.insert(_task('b', 'M'));
      final seen = <String?>[];
      final sub = repo.watchCurrentTask().listen((t) => seen.add(t?.id));
      await pumpEventQueue();
      await repo.complete('a', DateTime.utc(2026, 9, 25));
      await pumpEventQueue();
      await repo.complete('b', DateTime.utc(2026, 9, 25));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, ['a', 'b', null]);
    });

    test('ajuste de primer uso', () async {
      expect(await settings.firstRunDone(), isFalse);
      await settings.setFirstRunDone();
      expect(await settings.firstRunDone(), isTrue);
    });
  });
}

void main() {
  _contract('memoria', () async {
    final r = InMemoryTaskRepository();
    return (r as _Repo, r as SettingsRepository, r.dispose);
  });

  _contract('drift (SQLite en memoria)', () async {
    final db = openInMemoryDatabase();
    final r = DriftTaskRepository(db);
    return (r as _Repo, r as SettingsRepository, db.close);
  });

  test(
    'CA-001-10: los datos persisten al cerrar y reabrir la BD en disco',
    () async {
      final dir = await Directory.systemTemp.createTemp('una_db');
      final file = File('${dir.path}/app.sqlite');
      var db = openAppDatabaseFile(file);
      await DriftTaskRepository(db).insert(_task('p', 'K', color: 3));
      await DriftTaskRepository(db).setFirstRunDone();
      await db.close();

      db = openAppDatabaseFile(file);
      final repo = DriftTaskRepository(db);
      expect((await repo.currentTask())!.colorKey, 3);
      expect(await repo.firstRunDone(), isTrue);
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
