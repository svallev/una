import 'dart:convert';
import 'dart:io';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/task_repository.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
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

Attachment _pdf(String id, {String? name = 'Programa.pdf'}) => Attachment(
  id: id,
  kind: AttachmentKind.pdf,
  origin: AttachmentOrigin.file,
  mime: 'application/pdf',
  byteSize: 2400000,
  width: 595,
  height: 842,
  createdAt: DateTime.utc(2026, 9, 27),
  originalName: name,
  pageCount: 12,
);

const _webUrl = 'https://congreso.example.org/programa?dia=2';

Attachment _web(String id, {String url = _webUrl}) => Attachment(
  id: id,
  kind: AttachmentKind.web,
  origin: AttachmentOrigin.url,
  mime: 'text/html',
  byteSize: 0,
  width: 0,
  height: 0,
  createdAt: DateTime.utc(2026, 9, 28),
  url: url,
);

/// Misma batería para todas las implementaciones del puerto (docs/testing.md).
/// Escribe un valor crudo en la tabla `settings` (en Drift, un `insert`
/// directo; en memoria, `putRawSetting`): lo que dejaría un dato corrupto o
/// una copia de seguridad restaurada (CA-015-26, CL-015-18).
typedef _PutRaw = Future<void> Function(String key, String raw);

/// Una fila de `attachments` tal cual (spec 016, CA-016-25): lo que dejaría
/// una base restaurada o manipulada, con tipos y medidas que no hay que creer.
class _RawRow {
  const _RawRow(
    this.taskId,
    this.id, {
    this.kind = 'image',
    this.origin = 'gallery',
    this.position = 0,
    this.width = 4000,
    this.height = 3000,
  });
  final String taskId;
  final String id;
  final String kind;
  final String origin;
  final int position;
  final int? width;
  final int? height;
}

typedef _PutRawRows = Future<void> Function(Iterable<_RawRow> rows);

void _contract(
  String name,
  Future<
    (_Repo, SettingsRepository, Future<void> Function(), _PutRaw, _PutRawRows)
  >
  Function()
  create,
) {
  group('Contrato TaskRepository · $name', () {
    late _Repo repo;
    late SettingsRepository settings;
    late Future<void> Function() dispose;
    late _PutRaw putRaw;
    late _PutRawRows putRows;

    setUp(
      () async => (repo, settings, dispose, putRaw, putRows) = await create(),
    );
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

    test('CA-014-09 (ADR-0021): quitar y volver a guardar la misma tarea la '
        'deja idéntica (id, rank, color, fechas y adjunto) y en el mismo '
        'sitio, también la primera', () async {
      Task dated(Task t) => Task(
        id: t.id,
        text: t.text,
        attachment: t.attachment,
        status: t.status,
        rank: t.rank,
        colorKey: t.colorKey,
        createdAt: DateTime.utc(2026, 9, 20, 8, 15),
        updatedAt: DateTime.utc(2026, 9, 25, 18, 40, 12, 345),
      );
      final tasks = [
        dated(_task('a', 'C', color: 2, attachment: _image('ia'))),
        dated(_task('b', 'M', color: 5, attachment: _pdf('pb'))),
        dated(_task('c', 'T', color: 7, attachment: _web('wc'))),
        dated(_task('d', 'X', color: 3, text: 'Sin adjunto')),
      ];
      for (final t in tasks) {
        await repo.insert(t);
      }
      final before = await repo.pendingTasks();
      expect(before, tasks);

      for (final t in [tasks[1], tasks[0], tasks[2], tasks[3]]) {
        expect(await repo.remove(t.id), isTrue);
        expect(await repo.findById(t.id), isNull);
        await repo.insert(t);
        expect(await repo.findById(t.id), t);
        expect(await repo.pendingTasks(), before);
      }
      expect(await repo.currentTask(), tasks.first);
      expect(await repo.attachmentIds(), {'ia', 'pb', 'wc'});
      expect(await repo.countPending(), 4);
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
        expect(await repo.updateContent('a', 'Nuevo texto', at), isTrue);
        final t = (await repo.findById('a'))!;
        expect(t.text, 'Nuevo texto');
        expect(t.rank, 'C');
        expect(t.colorKey, 3);
        expect(t.updatedAt, at);
        expect((await repo.currentTask())!.id, 'a');
        expect(await repo.updateContent('missing', 'x', at), isFalse);
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

    test(
      'CA-008-07/19: una tarea con PDF vuelve con su nombre y sus páginas',
      () async {
        await repo.insert(_task('a', 'C', attachment: _pdf('pdf-a')));
        await repo.insert(
          _task(
            'b',
            'M',
            text: 'Congreso',
            attachment: _pdf('pdf-b', name: null),
          ),
        );
        final current = (await repo.currentTask())!;
        expect(current.attachment, _pdf('pdf-a'));
        expect(current.attachment!.isPdf, isTrue);
        final b = (await repo.findById('b'))!.attachment!;
        expect(b.originalName, isNull);
        expect(b.pageCount, 12);
        expect(await repo.attachmentIds(), {'pdf-a', 'pdf-b'});
      },
    );

    test('CA-009-04: una tarea web vuelve sin texto, con su tipo, su origen y '
        'solo su dirección', () async {
      await repo.insert(_task('a', 'C', attachment: _web('web-a')));
      await repo.insert(_task('b', 'M'));
      final current = (await repo.currentTask())!;
      expect(current.text, isNull);
      expect(current.attachment, _web('web-a'));
      final a = current.attachment!;
      expect(
        (a.isWeb, a.kind, a.origin),
        (true, AttachmentKind.web, AttachmentOrigin.url),
      );
      expect((a.url, a.mime, a.byteSize), (_webUrl, 'text/html', 0));
      expect((await repo.findById('a'))!.attachment!.url, _webUrl);
      expect((await repo.pendingTasks()).first.attachment!.url, _webUrl);
      expect((await repo.watchCurrentTask().first)!.attachment!.url, _webUrl);
      expect(await repo.attachmentIds(), {'web-a'});
    });

    test(
      'CA-009-05: sustituir la dirección conserva posición y color',
      () async {
        await repo.insert(_task('a', 'C', color: 3, attachment: _web('w1')));
        await repo.insert(_task('b', 'M'));
        const other = 'https://otra.example.com/';
        final at = DateTime.utc(2026, 9, 28, 12);
        expect(
          await repo.updateContent(
            'a',
            null,
            at,
            attachments: [_web('w2', url: other)],
          ),
          isTrue,
        );
        final t = (await repo.findById('a'))!;
        expect(
          (t.text, t.attachment?.id, t.attachment?.url, t.rank, t.colorKey),
          (null, 'w2', other, 'C', 3),
        );
        expect(await repo.attachmentIds(), {'w2'});
        expect((await repo.currentTask())!.id, 'a');
      },
    );

    test('CA-007-06: añadir, sustituir y quitar la imagen conserva posición y color', () async {
      await repo.insert(_task('a', 'C', color: 3));
      await repo.insert(_task('b', 'M'));
      final at = DateTime.utc(2026, 9, 26, 12);
      expect(
        await repo.updateContent(
          'a',
          'Con foto',
          at,
          attachments: [_image('i1')],
        ),
        isTrue,
      );
      var t = (await repo.findById('a'))!;
      expect(
        (t.text, t.attachment?.id, t.rank, t.colorKey),
        ('Con foto', 'i1', 'C', 3),
      );
      expect(
        await repo.updateContent('a', null, at, attachments: [_image('i2')]),
        isTrue,
      );
      t = (await repo.findById('a'))!;
      expect((t.text, t.attachment?.id), (null, 'i2'));
      expect(await repo.attachmentIds(), {'i2'});
      expect(
        await repo.updateContent('a', 'Sin foto', at, attachments: const []),
        isTrue,
      );
      t = (await repo.findById('a'))!;
      expect((t.text, t.attachment), ('Sin foto', null));
      expect(await repo.attachmentIds(), isEmpty);
      expect((await repo.currentTask())!.id, 'a');
    });

    // ---- Spec 016: lectura con grupos (CA-016-25) ----

    /// Una tarea sin adjuntos propios y sus filas crudas.
    Future<void> seed(String id, String rank, List<_RawRow> rows) async {
      await repo.insert(_task(id, rank, text: 'Tarea $id'));
      await putRows(rows);
    }

    List<String> ids(Task? t) => [for (final a in t!.attachments) a.id];

    test('CA-016-25: un grupo de 3 vuelve en su orden por todas las lecturas '
        'aunque las filas estén guardadas desordenadas', () async {
      await seed('a', 'C', [
        const _RawRow('a', 'z3', position: 2),
        const _RawRow('a', 'z1', position: 0),
        const _RawRow('a', 'z2', position: 1),
      ]);
      await seed('b', 'M', [
        const _RawRow('b', 'y2', position: 1),
        const _RawRow('b', 'y1', position: 0),
      ]);
      expect(ids(await repo.currentTask()), ['z1', 'z2', 'z3']);
      expect(ids(await repo.findById('a')), ['z1', 'z2', 'z3']);
      expect(ids(await repo.findById('b')), ['y1', 'y2']);
      final pending = await repo.pendingTasks();
      expect(pending.map((t) => t.id), ['a', 'b']);
      expect(ids(pending[0]), ['z1', 'z2', 'z3']);
      expect(ids(pending[1]), ['y1', 'y2']);
      expect(ids(await repo.watchCurrentTask().first), ['z1', 'z2', 'z3']);
      expect((await repo.watchPending().first).map(ids), [
        ['z1', 'z2', 'z3'],
        ['y1', 'y2'],
      ]);
      expect((await repo.currentTask())!.attachments.isPhotoGroup, isTrue);
    });

    test('CA-016-25: la primera tarea no corta el grupo (limit(1) sobre el '
        'JOIN devolvería una sola foto) y una tarea sin adjuntos sigue '
        'siendo una tarea', () async {
      await seed('a', 'C', [
        for (var i = 0; i < 3; i++) _RawRow('a', 'p$i', position: i),
      ]);
      await repo.insert(_task('b', 'M'));
      final current = (await repo.currentTask())!;
      expect(current.attachments, hasLength(3));
      expect(current.attachment!.id, 'p0');
      expect((await repo.findById('b'))!.attachments, isEmpty);
      expect((await repo.pendingTasks()).map((t) => t.attachments.length), [
        3,
        0,
      ]);
    });

    test('CA-016-25: las posiciones repetidas se ordenan por id y las que '
        'tienen huecos, por posición', () async {
      await seed('a', 'C', [
        const _RawRow('a', 'b', position: 4),
        const _RawRow('a', 'd', position: 9),
        const _RawRow('a', 'c', position: 4),
        const _RawRow('a', 'a', position: 4),
        const _RawRow('a', 'e', position: 0),
      ]);
      expect(ids(await repo.currentTask()), ['e', 'a', 'b', 'c', 'd']);
    });

    test('CA-016-25: una fila con un tipo desconocido deja la tarea no válida '
        '(sola o junto a 2 buenas) y no lanza', () async {
      await seed('a', 'C', [const _RawRow('a', 'xa', kind: 'document')]);
      await seed('b', 'M', [
        const _RawRow('b', 'g1', position: 0),
        const _RawRow('b', 'xb', kind: 'hologram', position: 1),
        const _RawRow('b', 'g2', position: 2),
      ]);
      final a = (await repo.findById('a'))!;
      expect(a.attachments.single.unreadable, isTrue);
      expect(a.attachments.isValidGroup, isFalse);
      final b = (await repo.findById('b'))!;
      expect(ids(b), ['g1', 'xb', 'g2']);
      expect(b.attachments.map((x) => x.unreadable), [false, true, false]);
      expect(b.attachments.isValidGroup, isFalse);
      expect(b.attachments.isPhotoGroup, isFalse);
      expect((await repo.pendingTasks()).map((t) => t.id), ['a', 'b']);
    });

    test(
      'CA-016-25: un origen desconocido también deja la tarea no válida',
      () async {
        await seed('a', 'C', [const _RawRow('a', 'xo', origin: 'telepathy')]);
        final a = (await repo.currentTask())!;
        expect(a.attachments.single.unreadable, isTrue);
        expect(a.attachments.isValidGroup, isFalse);
      },
    );

    for (final (label, id) in <(String, String)>[
      ('con ../', '../x'),
      ('de 65 caracteres', 'x' * 65),
      ('con una barra', 'a/b'),
      ('con un espacio', 'a b'),
    ]) {
      test('CA-016-25: una fila de imagen válida con un id inválido ($label) '
          'se lee como no válida y sin lanzar (T-7)', () async {
        await seed('a', 'C', [
          const _RawRow('a', 'ok', position: 0),
          _RawRow('a', id, position: 1),
        ]);
        final t = (await repo.currentTask())!;
        final bad = t.attachments.last;
        expect(bad.unreadable, isTrue);
        expect((bad.width, bad.height), (1, 1));
        expect(t.attachments.isValidGroup, isFalse);
        expect(t.attachments.first.unreadable, isFalse);
      });
    }

    test('CA-016-25: un id válido en el límite (64 caracteres, guiones y '
        'guiones bajos) se lee igual que siempre', () async {
      await seed('a', 'C', [
        _RawRow('a', 'A-z_9' * 12 + 'abcd', position: 0),
        const _RawRow('a', 'g2', position: 1),
      ]);
      final t = (await repo.currentTask())!;
      expect(t.attachments.map((a) => a.unreadable), [false, false]);
      expect(t.attachments.first.id, hasLength(64));
      expect(t.attachments.isPhotoGroup, isTrue);
    });

    for (final (label, w, h) in <(String, int?, int?)>[
      ('ancho 0', 0, 3000),
      ('alto -1', 4000, -1),
      ('ancho 2^31', 2147483648, 3000),
      ('los dos 2^31 (el producto desbordaría)', 2147483648, 2147483648),
      ('sin medidas', null, null),
      ('64 MP y un píxel más', 8001, 8000),
    ]) {
      test('CA-016-25: una imagen con medidas fuera de rango ($label) se lee '
          'como no válida con medidas 1 × 1 y sin lanzar', () async {
        await seed('a', 'C', [
          _RawRow('a', 'ok', position: 0),
          _RawRow('a', 'bad', position: 1, width: w, height: h),
        ]);
        final t = (await repo.currentTask())!;
        final bad = t.attachments.last;
        expect(bad.unreadable, isTrue);
        expect((bad.width, bad.height), (1, 1));
        expect(t.attachments.isValidGroup, isFalse);
        expect(t.attachments.first.unreadable, isFalse);
        expect(t.attachments.first.width, 4000);
      });
    }

    test('CA-016-25: una imagen grande pero real (24 MP, un lado de 20 000) '
        'se lee bien', () async {
      await seed('a', 'C', [
        const _RawRow('a', 'tall', width: 1080, height: 20000),
        const _RawRow('a', 'pano', position: 1, width: 20000, height: 1200),
      ]);
      final t = (await repo.currentTask())!;
      expect(t.attachments.map((a) => a.unreadable), [false, false]);
      expect(t.attachments.isPhotoGroup, isTrue);
    });

    test('CA-016-25: un PDF o una web con imágenes se lee tal cual y la '
        'mezcla no es válida', () async {
      await seed('a', 'C', [
        const _RawRow('a', 'i1', position: 0),
        const _RawRow('a', 'pd', kind: 'pdf', origin: 'file', position: 1),
      ]);
      await seed('b', 'M', [
        const _RawRow(
          'b',
          'w1',
          kind: 'web',
          origin: 'url',
          position: 0,
          width: null,
          height: null,
        ),
        const _RawRow('b', 'i2', position: 1),
        const _RawRow('b', 'i3', position: 2),
      ]);
      final a = (await repo.findById('a'))!;
      expect(a.attachments.map((x) => x.kind), [
        AttachmentKind.image,
        AttachmentKind.pdf,
      ]);
      expect(a.attachments.isValidGroup, isFalse);
      final b = (await repo.findById('b'))!;
      expect(b.attachments.map((x) => x.kind), [
        AttachmentKind.web,
        AttachmentKind.image,
        AttachmentKind.image,
      ]);
      expect(b.attachments.isValidGroup, isFalse);
      expect(b.attachments.any((x) => x.unreadable), isFalse);
    });

    test('CA-016-25: con 11 filas se leen solo las 10 primeras por '
        '(posición, id), pero attachmentIds() las devuelve todas', () async {
      await seed('a', 'C', [
        for (var i = 10; i >= 0; i--)
          _RawRow('a', 'f${i.toString().padLeft(2, '0')}', position: i),
      ]);
      final t = (await repo.currentTask())!;
      expect(t.attachments, hasLength(10));
      expect(ids(t).first, 'f00');
      expect(ids(t).last, 'f09');
      expect(t.attachments.isValidGroup, isTrue);
      expect(await repo.attachmentIds(), hasLength(11));
      expect(await repo.attachmentIds(), contains('f10'));
    });

    test(
      'CA-016-25: 100 000 filas en una tarea: se leen 10, dentro de un '
      'presupuesto de tiempo, y el resto de tareas no se ven afectadas',
      () async {
        await seed('a', 'C', [
          for (var i = 99999; i >= 0; i--)
            _RawRow('a', 'm${i.toString().padLeft(6, '0')}', position: i),
        ]);
        await repo.insert(_task('b', 'M'));
        final watch = Stopwatch()..start();
        final current = (await repo.currentTask())!;
        final byId = (await repo.findById('a'))!;
        final pending = await repo.pendingTasks();
        final streamed = (await repo.watchCurrentTask().first)!;
        watch.stop();
        for (final t in [current, byId, pending.first, streamed]) {
          expect(t.attachments, hasLength(10));
          expect(ids(t).first, 'm000000');
          expect(ids(t).last, 'm000009');
        }
        expect(pending.map((t) => t.id), ['a', 'b']);
        expect(
          watch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'cuatro lecturas de una tarea con 100 000 filas',
        );
        expect(await repo.attachmentIds(), hasLength(100000));
      },
    );

    test(
      'CA-016-25: el flujo emite al cambiar una fila de attachments',
      () async {
        await seed('a', 'C', [const _RawRow('a', 'p0')]);
        final seen = <List<String>>[];
        final sub = repo.watchCurrentTask().listen((t) => seen.add(ids(t)));
        await pumpEventQueue();
        await putRows([const _RawRow('a', 'p1', position: 1)]);
        await pumpEventQueue();
        await putRows([const _RawRow('a', 'p2', position: 2)]);
        await pumpEventQueue();
        await sub.cancel();
        expect(seen.first, ['p0']);
        expect(seen.last, ['p0', 'p1', 'p2']);
      },
    );

    test('CA-016-25: el flujo de la cola también emite al cambiar una fila '
        'de attachments', () async {
      await seed('a', 'C', [const _RawRow('a', 'p0')]);
      await repo.insert(_task('b', 'M'));
      final seen = <List<int>>[];
      final sub = repo.watchPending().listen(
        (l) => seen.add([for (final t in l) t.attachments.length]),
      );
      await pumpEventQueue();
      await putRows([const _RawRow('b', 'q0')]);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, [1, 0]);
      expect(seen.last, [1, 1]);
    });

    test('CA-016-25: existingAttachmentIds devuelve solo los que tienen fila, '
        'por lote', () async {
      await seed('a', 'C', [
        const _RawRow('a', 'k1'),
        const _RawRow('a', 'k2', position: 1),
      ]);
      expect(await repo.existingAttachmentIds([]), isEmpty);
      expect(await repo.existingAttachmentIds(['k1', 'nope', 'k1']), {'k1'});
      expect(await repo.existingAttachmentIds(['nope', 'tampoco']), isEmpty);
      // Más ids que variables por consulta: se parte en lotes y no falla.
      final many = [for (var i = 0; i < 1300; i++) 'n$i', 'k2'];
      expect(await repo.existingAttachmentIds(many), {'k2'});
    });

    // ---- Spec 016: escritura con grupos (CA-016-14, 15, 25) ----

    Task group(String id, String rank, List<String> photoIds) => Task(
      id: id,
      text: null,
      attachments: [for (final p in photoIds) _image(p)],
      status: TaskStatus.pending,
      rank: rank,
      colorKey: 2,
      createdAt: DateTime.utc(2026, 9, 24, 10),
      updatedAt: DateTime.utc(2026, 9, 24, 10),
    );
    final at16 = DateTime.utc(2026, 10, 6, 9);

    test('CA-016-14: insertar un grupo de 3 y leerlo en su orden por todas '
        'las lecturas', () async {
      final task = group('a', 'C', ['g3', 'g1', 'g2']);
      await repo.insert(task);
      expect(ids(await repo.currentTask()), ['g3', 'g1', 'g2']);
      expect(ids(await repo.findById('a')), ['g3', 'g1', 'g2']);
      expect((await repo.pendingTasks()).map(ids), [
        ['g3', 'g1', 'g2'],
      ]);
      expect(await repo.findById('a'), task);
      expect(await repo.attachmentIds(), {'g1', 'g2', 'g3'});
    });

    test('CA-016-14: el grupo de 10 se guarda y se lee entero', () async {
      final names = [for (var i = 0; i < 10; i++) 'p${9 - i}'];
      await repo.insert(group('a', 'C', names));
      expect(ids(await repo.currentTask()), names);
      expect(await repo.attachmentIds(), hasLength(10));
    });

    test('CA-016-15: insertar con un id de foto repetido lanza y no deja ni '
        'la tarea, ni ninguna fila, ni la marca de "alguna vez hubo tareas" '
        '(una sola transacción)', () async {
      await expectLater(
        repo.insert(group('a', 'C', ['dup', 'ok', 'dup'])),
        throwsA(anything),
      );
      expect(await repo.findById('a'), isNull);
      expect(await repo.countPending(), 0);
      expect(await repo.attachmentIds(), isEmpty);
      expect(await settings.hasEverHadTasks(), isFalse);
      // Chocar con la foto de otra tarea también deshace todo.
      await repo.insert(group('b', 'M', ['b1']));
      await expectLater(
        repo.insert(group('c', 'X', ['c1', 'b1'])),
        throwsA(anything),
      );
      expect(await repo.findById('c'), isNull);
      expect(await repo.attachmentIds(), {'b1'});
    });

    test('CA-016-25: editar solo el texto (attachments: null) no borra las '
        'filas: ni las de un grupo, ni 11 restauradas, ni una mezcla rara '
        'ni una con tipo desconocido', () async {
      await repo.insert(group('a', 'C', ['a1', 'a2', 'a3']));
      await seed('b', 'M', [
        for (var i = 0; i < 11; i++) _RawRow('b', 'f$i', position: i),
      ]);
      await seed('c', 'T', [
        const _RawRow('c', 'c1'),
        const _RawRow('c', 'c2', kind: 'pdf', origin: 'file', position: 1),
        const _RawRow('c', 'c3', kind: 'hologram', position: 2),
      ]);
      final before = await repo.attachmentIds();
      expect(before, hasLength(3 + 11 + 3));
      for (final id in ['a', 'b', 'c']) {
        expect(await repo.updateContent(id, 'Solo texto', at16), isTrue);
        expect((await repo.findById(id))!.text, 'Solo texto');
        expect((await repo.findById(id))!.updatedAt, at16);
      }
      expect(await repo.attachmentIds(), before);
      expect(ids(await repo.findById('a')), ['a1', 'a2', 'a3']);
      expect(ids(await repo.findById('b')), hasLength(10));
      expect((await repo.findById('c'))!.attachments.map((x) => x.unreadable), [
        false,
        false,
        true,
      ]);
    });

    test('CA-016-14: reemplazar un grupo por otro cambia las filas y deja el '
        'orden de la lista nueva; conserva posición y color', () async {
      await repo.insert(group('a', 'C', ['a1', 'a2', 'a3']));
      await repo.insert(group('b', 'M', ['b1']));
      expect(
        await repo.updateContent(
          'a',
          'Con texto',
          at16,
          attachments: [_image('n2'), _image('n1')],
        ),
        isTrue,
      );
      final t = (await repo.findById('a'))!;
      expect(ids(t), ['n2', 'n1']);
      expect((t.text, t.rank, t.colorKey), ('Con texto', 'C', 2));
      expect(await repo.attachmentIds(), {'n1', 'n2', 'b1'});
      expect((await repo.currentTask())!.id, 'a');
      // Una foto sola por un PDF, y el PDF por un grupo.
      await repo.updateContent('b', null, at16, attachments: [_pdf('pb')]);
      expect((await repo.findById('b'))!.attachment!.isPdf, isTrue);
      await repo.updateContent(
        'b',
        null,
        at16,
        attachments: [_image('q1'), _image('q2'), _image('q3')],
      );
      expect(ids(await repo.findById('b')), ['q1', 'q2', 'q3']);
      expect(await repo.attachmentIds(), {'n1', 'n2', 'q1', 'q2', 'q3'});
    });

    test('CA-016-14: una lista vacía quita todas las filas, también las que '
        'la lectura no muestra', () async {
      await seed('a', 'C', [
        for (var i = 0; i < 12; i++) _RawRow('a', 'f$i', position: i),
      ]);
      await repo.insert(group('b', 'M', ['b1', 'b2']));
      expect(
        await repo.updateContent('a', 'Sin fotos', at16, attachments: const []),
        isTrue,
      );
      expect((await repo.findById('a'))!.attachments, isEmpty);
      expect(await repo.attachmentIds(), {'b1', 'b2'});
    });

    test('CA-016-15: si el reemplazo falla a mitad (id repetido) no cambia '
        'nada: ni el texto ni las filas anteriores', () async {
      await repo.insert(group('a', 'C', ['a1', 'a2']));
      await repo.insert(group('b', 'M', ['b1']));
      await expectLater(
        repo.updateContent(
          'a',
          'Nuevo',
          at16,
          attachments: [_image('x1'), _image('b1')],
        ),
        throwsA(anything),
      );
      final t = (await repo.findById('a'))!;
      expect(ids(t), ['a1', 'a2']);
      expect(t.text, isNull);
      expect(await repo.attachmentIds(), {'a1', 'a2', 'b1'});
      await expectLater(
        repo.updateContent(
          'a',
          'Nuevo',
          at16,
          attachments: [_image('y1'), _image('y1')],
        ),
        throwsA(anything),
      );
      expect(ids(await repo.findById('a')), ['a1', 'a2']);
    });

    test('CA-016-14: quitar borra todas las filas del grupo y deja las de '
        'las demás tareas', () async {
      await repo.insert(group('a', 'C', ['a1', 'a2', 'a3']));
      await repo.insert(group('b', 'M', ['b1', 'b2']));
      expect(await repo.remove('a'), isTrue);
      expect(await repo.attachmentIds(), {'b1', 'b2'});
      expect(await repo.findById('a'), isNull);
    });

    test('CA-016-14: quitar una tarea con 100 000 filas borra todas (no solo '
        'las 10 que se leen)', () async {
      await seed('a', 'C', [
        for (var i = 0; i < 100000; i++)
          _RawRow('a', 'm${i.toString().padLeft(6, '0')}', position: i),
      ]);
      await repo.insert(group('b', 'M', ['b1']));
      expect(await repo.attachmentIds(), hasLength(100001));
      expect(await repo.remove('a'), isTrue);
      expect(await repo.attachmentIds(), {'b1'});
    });

    test('CA-016-14: el flujo emite al reemplazar las fotos', () async {
      await repo.insert(group('a', 'C', ['a1']));
      final seen = <List<String>>[];
      final sub = repo.watchCurrentTask().listen((t) => seen.add(ids(t)));
      await pumpEventQueue();
      await repo.updateContent(
        'a',
        null,
        at16,
        attachments: [_image('n1'), _image('n2')],
      );
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, ['a1']);
      expect(seen.last, ['n1', 'n2']);
    });

    test('ajuste de primer uso', () async {
      expect(await settings.firstRunDone(), isFalse);
      await settings.setFirstRunDone();
      expect(await settings.firstRunDone(), isTrue);
    });

    test('CA-015-05: "Pantalla siempre activa" está apagada por defecto y '
        'se guarda', () async {
      expect(await settings.keepScreenOn(), isFalse);
      await settings.setKeepScreenOn(true);
      expect(await settings.keepScreenOn(), isTrue);
      await settings.setKeepScreenOn(false);
      expect(await settings.keepScreenOn(), isFalse);
    });

    test(
      'CA-015-06: el idioma es "Como el sistema" por defecto y se guarda',
      () async {
        expect(await settings.locale(), LocaleChoice.system);
        for (final choice in [
          LocaleChoice.es,
          LocaleChoice.en,
          LocaleChoice.system,
        ]) {
          await settings.setLocale(choice);
          expect(await settings.locale(), choice);
        }
      },
    );

    for (final raw in <String>[
      'fr',
      '"fr"',
      '',
      '"es-MX"',
      '[[[[[[[[[[[[[[[[',
      '{"a":',
      '1',
      '0',
      '"true"',
      'false',
      'null',
      '["es"]',
      '"${'a' * 5000}"',
    ]) {
      final shown = raw.length > 20 ? '${raw.substring(0, 20)}…' : raw;
      test('CA-015-26: el idioma guardado como `$shown` da "Como el '
          'sistema" y no lanza', () async {
        await putRaw('locale', raw);
        expect(await settings.locale(), LocaleChoice.system);
      });

      test('CA-015-26: "Pantalla siempre activa" guardada como `$shown` '
          'está apagada y no lanza', () async {
        await putRaw('keepScreenOn', raw);
        expect(await settings.keepScreenOn(), isFalse);
      });

      test('CL-015-18: las marcas guardadas como `$shown` fallan cerradas '
          'a false y no lanzan', () async {
        await putRaw('firstRunDone', raw);
        await putRaw('hasEverHadTasks', raw);
        expect(await settings.firstRunDone(), isFalse);
        expect(await settings.hasEverHadTasks(), isFalse);
      });
    }

    test('CA-015-26: los valores exactos válidos se leen', () async {
      await putRaw('locale', '"es"');
      expect(await settings.locale(), LocaleChoice.es);
      await putRaw('locale', '"en"');
      expect(await settings.locale(), LocaleChoice.en);
      await putRaw('locale', '"system"');
      expect(await settings.locale(), LocaleChoice.system);
      await putRaw('keepScreenOn', 'true');
      expect(await settings.keepScreenOn(), isTrue);
    });
  });
}

void main() {
  _contract('memoria', () async {
    final r = InMemoryTaskRepository();
    return (
      r as _Repo,
      r as SettingsRepository,
      r.dispose,
      (String key, String raw) async => r.putRawSetting(key, raw),
      (Iterable<_RawRow> rows) async {
        for (final row in rows) {
          r.putRawAttachment(
            row.taskId,
            id: row.id,
            kind: row.kind,
            origin: row.origin,
            position: row.position,
            width: row.width,
            height: row.height,
          );
        }
      },
    );
  });

  _contract('drift (SQLite en memoria)', () async {
    final db = openInMemoryDatabase();
    final r = DriftTaskRepository(db);
    return (
      r as _Repo,
      r as SettingsRepository,
      db.close,
      (String key, String raw) async => db
          .into(db.settingEntries)
          .insertOnConflictUpdate(
            SettingEntriesCompanion.insert(key: key, value: raw, updatedAt: 0),
          ),
      (Iterable<_RawRow> rows) => db.batch(
        (b) => b.insertAll(db.attachments, [
          for (final row in rows)
            AttachmentsCompanion.insert(
              id: row.id,
              taskId: row.taskId,
              kind: row.kind,
              origin: row.origin,
              mime: 'image/jpeg',
              byteSize: 1234,
              relPath: 'attachments/${row.id}/full',
              width: Value(row.width),
              height: Value(row.height),
              createdAt: 0,
              position: Value(row.position),
            ),
        ]),
      ),
    );
  });

  test('CA-016-25 (plan §3): la lectura acotada usa el índice '
      '(task_id, position, id) y busca cada foto por clave, sin recorrer todas '
      'las filas de la tarea (drift)', () async {
    final db = openInMemoryDatabase();
    final repo = DriftTaskRepository(db);
    final plan = await db
        .customSelect('EXPLAIN QUERY PLAN ${repo.currentTaskSql}')
        .get();
    final details = plan.map((r) => r.read<String>('detail')).join('\n');
    expect(details, contains('idx_attachments_task_position'));
    // La unión busca por la clave primaria de `attachments` (IN de la
    // subconsulta acotada), no por un recorrido de la tabla.
    expect(
      details,
      matches(RegExp(r'SEARCH a USING INDEX sqlite_autoindex_attachments_1')),
    );
    expect(details, isNot(contains('SCAN a')));
    await db.close();
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

  test('CA-016-14 (plan §3): insertar y reemplazar numeran `position` de 0 a '
      'N-1 en el orden de la lista (drift)', () async {
    final db = openInMemoryDatabase();
    final repo = DriftTaskRepository(db);
    await repo.insert(
      Task(
        id: 'a',
        text: null,
        attachments: [_image('z'), _image('y'), _image('x')],
        status: TaskStatus.pending,
        rank: 'C',
        colorKey: 0,
        createdAt: DateTime.utc(2026, 10, 6),
        updatedAt: DateTime.utc(2026, 10, 6),
      ),
    );
    Future<List<(String, int)>> rows() async => [
      for (final r in await (db.select(
        db.attachments,
      )..orderBy([(a) => OrderingTerm.asc(a.position)])).get())
        (r.id, r.position),
    ];
    expect(await rows(), [('z', 0), ('y', 1), ('x', 2)]);
    await repo.updateContent(
      'a',
      null,
      DateTime.utc(2026, 10, 6, 1),
      attachments: [_image('n2'), _image('n1')],
    );
    expect(await rows(), [('n2', 0), ('n1', 1)]);
    await db.close();
  });

  test('CA-009-04 (plan §3): la fila de una tarea web guarda solo la '
      'dirección, sin archivos ni medidas, en el esquema actual', () async {
    final db = openInMemoryDatabase();
    final repo = DriftTaskRepository(db);
    expect(db.schemaVersion, 3); // v3: spec 016 (position)
    await repo.insert(_task('a', 'C', attachment: _web('web-a')));

    final row = await db.select(db.attachments).getSingle();
    expect(
      (row.id, row.taskId, row.kind, row.origin),
      ('web-a', 'a', 'web', 'url'),
    );
    expect((row.mime, row.byteSize, row.relPath), ('text/html', 0, ''));
    expect(row.sourceUrl, _webUrl);
    expect([
      row.displayRelPath,
      row.thumbRelPath,
      row.originalName,
      row.sourceHost,
      row.snapshotRelPath,
      row.snapshotAt,
      row.width,
      row.height,
      row.pageCount,
      row.sha256,
    ], everyElement(isNull));
    await db.close();
  });

  test('CA-009-04: la dirección no aparece en el toString del adjunto ni de '
      'la tarea (CL-009-9)', () {
    final task = _task('a', 'C', attachment: _web('web-a'));
    expect(task.attachment.toString(), isNot(contains('congreso')));
    expect(task.toString(), isNot(contains('congreso')));
  });

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
