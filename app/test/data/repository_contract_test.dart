import 'dart:convert';
import 'dart:io';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Repo = TaskRepository;

Task _task(
  String id,
  String rank, {
  int color = 0,
  Attachment? attachment,
  String? text,
}) {
  final t = DateTime.utc(2026, 9, 24, 10);
  return Task(
    id: id,
    text: attachment != null ? text : (text ?? 'Tarea $id'),
    attachment: attachment,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: color,
    createdAt: t,
    updatedAt: t,
  );
}

Attachment _image(
  String id, {
  AttachmentOrigin origin = AttachmentOrigin.camera,
}) => Attachment(
  id: id,
  kind: AttachmentKind.image,
  origin: origin,
  mime: 'image/jpeg',
  byteSize: 1234,
  width: 4000,
  height: 3000,
  createdAt: DateTime.utc(2026, 9, 26),
);

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

    test('CA-003-06 / CA-004-03 / CA-004-09 (ADR-0012): quitar borra la '
        'tarea y las filas de sus adjuntos', () async {
      await repo.insert(_task('a', 'C', attachment: _image('ia')));
      await repo.insert(_task('b', 'M', attachment: _image('ib')));

      expect(await repo.remove('a'), isTrue);

      expect((await repo.currentTask())!.id, 'b');
      expect(await repo.countPending(), 1);
      expect(await repo.findById('a'), isNull);
      expect(await repo.attachmentIds(), {'ib'});
    });

    test('quitar dos veces o una que no existe no hace nada', () async {
      await repo.insert(_task('a', 'C'));
      expect(await repo.remove('a'), isTrue);
      expect(await repo.remove('a'), isFalse);
      expect(await repo.remove('missing'), isFalse);
    });

    test('CA-001-05 / CA-003-11 / CA-004-08 (ADR-0012): guardar una tarea '
        'activa hasEverHadTasks; quitarla no lo desactiva', () async {
      expect(await settings.hasEverHadTasks(), isFalse);
      await repo.insert(_task('a', 'C'));
      expect(await settings.hasEverHadTasks(), isTrue);
      await repo.remove('a');
      expect(await repo.currentTask(), isNull);
      expect(await settings.hasEverHadTasks(), isTrue);
    });

    test(
      'watchCurrentTask emite la siguiente al quitar, y null al final',
      () async {
        await repo.insert(_task('a', 'C'));
        await repo.insert(_task('b', 'M'));
        final seen = <String?>[];
        final sub = repo.watchCurrentTask().listen((t) => seen.add(t?.id));
        await pumpEventQueue();
        await repo.remove('a');
        await pumpEventQueue();
        await repo.remove('b');
        await pumpEventQueue();
        await sub.cancel();
        expect(seen, ['a', 'b', null]);
      },
    );

    test(
      'CA-005-05: editar el texto conserva posición y color y cambia updatedAt',
      () async {
        await repo.insert(_task('a', 'C', color: 3));
        await repo.insert(_task('b', 'M'));
        final at = DateTime.utc(2026, 9, 25, 12);
        expect(await repo.updateContent('a', 'Nuevo texto', null, at), isTrue);
        final t = (await repo.findById('a'))!;
        expect(t.text, 'Nuevo texto');
        expect(t.rank, 'C');
        expect(t.colorKey, 3);
        expect(t.updatedAt, at);
        expect((await repo.currentTask())!.id, 'a');
        expect(await repo.updateContent('missing', 'x', null, at), isFalse);
      },
    );

    test('CA-006-02: pendingTasks devuelve las pendientes en orden', () async {
      await repo.insert(_task('b', 'M'));
      await repo.insert(_task('a', 'C'));
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
      await repo.remove('a');
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

    test('reordenar una tarea que ya no está no hace nada', () async {
      await repo.insert(_task('x', 'D'));
      await repo.remove('x');
      final at = DateTime.utc(2026, 9, 26);
      expect(await repo.reorder('x', 'A', at), isFalse);
      expect(await repo.reorder('missing', 'A', at), isFalse);
    });

    test('CL-006-8: renumerar conserva el orden con claves cortas y de igual longitud', () async {
      await repo.insert(_task('a', 'V'));
      await repo.insert(_task('b', 'V${'1' * 60}'));
      await repo.insert(_task('c', 'W'));
      final at = DateTime.utc(2026, 9, 26, 13);
      await repo.renumberPending(at);
      final after = await repo.pendingTasks();
      expect(after.map((t) => t.id), ['a', 'b', 'c']);
      expect(after.map((t) => t.rank.length).toSet().length, 1);
      expect(after.every((t) => t.rank.length <= Rank.maxLength), isTrue);
      expect(after.every((t) => t.updatedAt == at), isTrue);
    });

    test('CA-007-08: la tarea actual y la cola llegan con su imagen', () async {
      await repo.insert(_task('a', 'C', attachment: _image('img-a')));
      await repo.insert(_task('b', 'M'));
      await repo.insert(
        _task(
          'c',
          'X',
          text: 'Horario',
          attachment: _image('img-c', origin: AttachmentOrigin.gallery),
        ),
      );
      final current = (await repo.currentTask())!;
      expect(current.text, isNull);
      expect(current.attachment, _image('img-a'));
      final pending = await repo.pendingTasks();
      expect(pending.map((t) => t.attachment?.id), ['img-a', null, 'img-c']);
      expect(pending.last.attachment!.origin, AttachmentOrigin.gallery);
      expect(pending.last.text, 'Horario');
      expect((await repo.findById('c'))!.attachment!.id, 'img-c');
      expect((await repo.watchCurrentTask().first)!.attachment!.id, 'img-a');
      expect(await repo.attachmentIds(), {'img-a', 'img-c'});
    });

    test('CA-007-06: añadir, sustituir y quitar la imagen conserva posición y color', () async {
      await repo.insert(_task('a', 'C', color: 3));
      await repo.insert(_task('b', 'M'));
      final at = DateTime.utc(2026, 9, 26, 12);
      expect(
        await repo.updateContent('a', 'Con foto', _image('i1'), at),
        isTrue,
      );
      var t = (await repo.findById('a'))!;
      expect(
        (t.text, t.attachment?.id, t.rank, t.colorKey),
        ('Con foto', 'i1', 'C', 3),
      );
      expect(await repo.updateContent('a', null, _image('i2'), at), isTrue);
      t = (await repo.findById('a'))!;
      expect((t.text, t.attachment?.id), (null, 'i2'));
      expect(await repo.attachmentIds(), {'i2'});
      expect(await repo.updateContent('a', 'Sin foto', null, at), isTrue);
      t = (await repo.findById('a'))!;
      expect((t.text, t.attachment), ('Sin foto', null));
      expect(await repo.attachmentIds(), isEmpty);
      expect((await repo.currentTask())!.id, 'a');
    });

    test('ajuste de primer uso', () async {
      expect(await settings.firstRunDone(), isFalse);
      await settings.setFirstRunDone();
      expect(await settings.firstRunDone(), isTrue);
    });

    test('CA-007-12: "Mantener la pantalla encendida" está activo por '
        'defecto y se guarda', () async {
      expect(await settings.keepScreenOn(), isTrue);
      await settings.setKeepScreenOn(false);
      expect(await settings.keepScreenOn(), isFalse);
      await settings.setKeepScreenOn(true);
      expect(await settings.keepScreenOn(), isTrue);
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
    'CA-004-09: al quitar se borran las filas de sus adjuntos (drift)',
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

      await repo.remove('a');

      final left = await db.select(db.attachments).get();
      expect(left.map((r) => r.id), ['x2']);
      await db.close();
    },
  );

  test(
    'ADR-0012: secure_delete activo para no dejar texto en páginas libres',
    () async {
      final db = openInMemoryDatabase();
      final row = await db.customSelect('PRAGMA secure_delete').getSingle();
      expect(row.data.values.single, 1);
      await db.close();
    },
  );

  test(
    'ADR-0012 / CA-004-09: el texto quitado no queda en el archivo de la BD',
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
      expect(await repo.remove('a'), isTrue);
      expect(await repo.remove('b'), isTrue);
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
