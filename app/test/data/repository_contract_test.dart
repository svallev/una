import 'dart:convert';
import 'dart:io';

import 'package:app/data/db/app_database.dart';
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
      expect(await repo.hasHistory(), isFalse);
      final at = DateTime.utc(2026, 9, 25, 9, 30);

      expect(await repo.complete('a', at), isTrue);

      expect((await repo.currentTask())!.id, 'b');
      expect(await repo.countPending(), 1);
      expect(await repo.hasHistory(), isTrue);
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

    test(
      'CA-004-08: una eliminada también cuenta como historia ("Todo hecho.")',
      () async {
        expect(await repo.hasHistory(), isFalse);
        await repo.insert(_task('live', 'C'));
        expect(await repo.hasHistory(), isFalse);
        await repo.insert(_task('gone', 'B', deletedAt: DateTime.utc(2026)));
        expect(await repo.hasHistory(), isTrue);
      },
    );

    test('CA-004-03 / CA-004-09: eliminar saca la tarea de la cola y no deja contenido', () async {
      await repo.insert(_task('a', 'C', color: 2));
      await repo.insert(_task('b', 'M'));
      final at = DateTime.utc(2026, 9, 26, 11);

      expect(await repo.delete('a', at), isTrue);

      expect((await repo.currentTask())!.id, 'b');
      expect(await repo.countPending(), 1);
      final gone = (await repo.findById('a'))!;
      expect(gone.deletedAt, at);
      expect(gone.updatedAt, at);
      expect(gone.text, isNull);
      expect(gone.status, TaskStatus.pending); // no cuenta como hecha
      expect(gone.completedAt, isNull);
      expect(gone.isPending, isFalse);
    });

    test('eliminar dos veces o una que no existe no hace nada', () async {
      await repo.insert(_task('a', 'C'));
      final first = DateTime.utc(2026, 9, 26, 11);
      expect(await repo.delete('a', first), isTrue);
      expect(await repo.delete('a', DateTime.utc(2027)), isFalse);
      expect((await repo.findById('a'))!.deletedAt, first);
      expect(await repo.delete('missing', first), isFalse);
    });

    test('eliminar la última deja la cola vacía y con historia', () async {
      await repo.insert(_task('a', 'C'));
      final seen = <String?>[];
      final sub = repo.watchCurrentTask().listen((t) => seen.add(t?.id));
      await pumpEventQueue();
      await repo.delete('a', DateTime.utc(2026, 9, 26));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, ['a', null]);
      expect(await repo.currentTask(), isNull);
      expect(await repo.hasHistory(), isTrue);
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

    test(
      'CA-005-05: editar el texto conserva posición y color y cambia updatedAt',
      () async {
        await repo.insert(_task('a', 'C', color: 3));
        await repo.insert(_task('b', 'M'));
        final at = DateTime.utc(2026, 9, 25, 12);
        expect(await repo.updateText('a', 'Nuevo texto', at), isTrue);
        final t = (await repo.findById('a'))!;
        expect(t.text, 'Nuevo texto');
        expect(t.rank, 'C');
        expect(t.colorKey, 3);
        expect(t.updatedAt, at);
        expect((await repo.currentTask())!.id, 'a');
        expect(await repo.updateText('missing', 'x', at), isFalse);
      },
    );

    test('CA-006-02: pendingTasks devuelve las pendientes en orden', () async {
      await repo.insert(_task('b', 'M'));
      await repo.insert(_task('a', 'C'));
      await repo.insert(_task('x', 'D', status: TaskStatus.completed));
      await repo.insert(_task('y', 'E', deletedAt: DateTime.utc(2026)));
      await repo.insert(_task('c', 'X'));
      expect((await repo.pendingTasks()).map((t) => t.id), ['a', 'b', 'c']);
    });

    test('watchPending emite la cola ordenada con cada cambio', () async {
      await repo.insert(_task('a', 'C'));
      await repo.insert(_task('b', 'M'));
      final seen = <List<String>>[];
      final sub = repo.watchPending().listen(
        (l) => seen.add([for (final t in l) t.id]),
      );
      await pumpEventQueue();
      await repo.reorder('b', 'A', DateTime.utc(2026, 9, 26));
      await pumpEventQueue();
      await repo.delete('a', DateTime.utc(2026, 9, 26));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, ['a', 'b']);
      expect(seen[seen.length - 2], ['b', 'a']);
      expect(seen.last, ['b']);
    });

    test(
      'CA-006-10: reordenar solo cambia el rank y updatedAt de esa tarea',
      () async {
        await repo.insert(_task('a', 'C', color: 1));
        await repo.insert(_task('b', 'M', color: 2));
        await repo.insert(_task('c', 'X', color: 3));
        final before = {for (final t in await repo.pendingTasks()) t.id: t};
        final at = DateTime.utc(2026, 9, 26, 12);
        expect(await repo.reorder('c', 'A', at), isTrue);
        final after = await repo.pendingTasks();
        expect(after.map((t) => t.id), ['c', 'a', 'b']);
        final moved = after.first;
        expect(moved.rank, 'A');
        expect(moved.updatedAt, at);
        expect(moved.colorKey, 3);
        expect(moved.text, before['c']!.text);
        expect(after[1], before['a']);
        expect(after[2], before['b']);
      },
    );

    test('reordenar una tarea que no está pendiente no hace nada', () async {
      await repo.insert(_task('x', 'D', status: TaskStatus.completed));
      await repo.insert(_task('y', 'E', deletedAt: DateTime.utc(2026)));
      final at = DateTime.utc(2026, 9, 26);
      expect(await repo.reorder('x', 'A', at), isFalse);
      expect(await repo.reorder('y', 'A', at), isFalse);
      expect(await repo.reorder('missing', 'A', at), isFalse);
      expect((await repo.findById('x'))!.rank, 'D');
    });

    test('CL-006-8: renumerar conserva el orden con claves cortas y de igual longitud', () async {
      await repo.insert(_task('a', 'V'));
      await repo.insert(_task('b', 'V${'1' * 60}'));
      await repo.insert(_task('c', 'W'));
      await repo.insert(_task('x', 'A', status: TaskStatus.completed));
      final at = DateTime.utc(2026, 9, 26, 13);
      await repo.renumberPending(at);
      final after = await repo.pendingTasks();
      expect(after.map((t) => t.id), ['a', 'b', 'c']);
      expect(after.map((t) => t.rank.length).toSet().length, 1);
      expect(after.every((t) => t.rank.length <= Rank.maxLength), isTrue);
      expect(after.every((t) => t.updatedAt == at), isTrue);
      // Las que no están pendientes no se tocan.
      expect((await repo.findById('x'))!.rank, 'A');
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
    'CA-004-09: al eliminar se borran las filas de sus adjuntos (drift)',
    () async {
      final db = openInMemoryDatabase();
      final repo = DriftTaskRepository(db);
      await repo.insert(_task('a', 'C'));
      await repo.insert(_task('b', 'M'));
      Future<void> attach(String id, String taskId) => db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: id,
              taskId: taskId,
              kind: 'image',
              origin: 'gallery',
              mime: 'image/jpeg',
              byteSize: 10,
              relPath: 'attachments/$id.jpg',
              createdAt: 0,
            ),
          );
      await attach('x1', 'a');
      await attach('x2', 'b');

      await repo.delete('a', DateTime.utc(2026, 9, 26));

      final left = await db.select(db.attachments).get();
      expect(left.map((r) => r.id), ['x2']);
      await db.close();
    },
  );

  test(
    'ADR-0011: secure_delete activo para no dejar texto en páginas libres',
    () async {
      final db = openInMemoryDatabase();
      final row = await db.customSelect('PRAGMA secure_delete').getSingle();
      expect(row.data.values.single, 1);
      await db.close();
    },
  );

  test(
    'ADR-0011 / CA-004-09: el texto eliminado no queda en el archivo de la BD',
    () async {
      final dir = await Directory.systemTemp.createTemp('una_secure_delete');
      final file = File('${dir.path}/una.sqlite');
      // Uno corto y otro de más de 4 KB (páginas de desbordamiento).
      const short = 'MARCADOR-CORTO-7Q2X';
      final long = 'MARCADOR-LARGO-9Z4K ' * 300;
      var db = openAppDatabaseFile(file);
      var repo = DriftTaskRepository(db);
      final at = DateTime.utc(2026, 9, 26);
      await repo.insert(_task('a', 'C').withText(short, at));
      await repo.insert(_task('b', 'M').withText(long, at));
      await repo.insert(_task('c', 'X'));
      await db.close();

      db = openAppDatabaseFile(file);
      repo = DriftTaskRepository(db);
      expect(await repo.delete('a', at), isTrue);
      expect(await repo.delete('b', at), isTrue);
      await db.close();

      final bytes = [
        for (final suffix in ['', '-journal', '-wal'])
          if (File('${file.path}$suffix').existsSync())
            ...File('${file.path}$suffix').readAsBytesSync(),
      ];
      final content = latin1.decode(bytes);
      expect(content.contains('MARCADOR-CORTO'), isFalse);
      expect(content.contains('MARCADOR-LARGO'), isFalse);
      // La que no se eliminó sigue ahí.
      expect(content.contains('Tarea c'), isTrue);
      await dir.delete(recursive: true);
    },
  );

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
