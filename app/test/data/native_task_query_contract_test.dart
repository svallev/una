import 'dart:io';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 019, T-019-07, P-019-10: contrato entre la consulta fija que el receptor de Android lee con
/// la app cerrada (`TaskQuery.kt`) y la de la app (`TaskRepository.currentTask()`).
///
/// El SQL se **extrae del propio archivo Kotlin** y se ejecuta aquí con `customSelect` de drift
/// (SQLite de `sqlite3_flutter_libs`, no el del sistema: la lectura real con el de Android se
/// comprueba en el emulador, T-019-14) sobre una BD creada por las migraciones de la app. Cualquier
/// cambio de esquema que toque esa consulta rompe esta prueba (consecuencia del ADR-0025).
const _kotlin =
    'android/app/src/main/kotlin/invalid/pending/app/notifications/TaskQuery.kt';

/// El valor de una constante de texto de `TaskQuery.kt` (cadena de triple comilla).
String _rawConst(String name) {
  final source = File(_kotlin).readAsStringSync();
  final match = RegExp(
    'const val $name = """(.*?)"""',
    dotAll: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'falta `const val $name = """…"""`');
  return match!.group(1)!.trim();
}

int _intConst(String name) {
  final source = File(_kotlin).readAsStringSync();
  final match = RegExp('const val $name = (\\d+)').firstMatch(source);
  expect(match, isNotNull, reason: 'falta `const val $name = <entero>`');
  return int.parse(match!.group(1)!);
}

/// Lo que lee el receptor de una fila: el texto, si hay adjunto y sus tres datos.
typedef _NativeRow = ({
  String? body,
  bool hasAttachment,
  String? kind,
  String? origin,
  String? url,
});

Future<List<_NativeRow>> _nativeRows(AppDatabase db, String sql) async => [
  for (final r in await db.customSelect(sql).get())
    (
      body: r.read<String?>('body'),
      hasAttachment: r.read<int>('has_attachment') == 1,
      kind: r.read<String?>('kind'),
      origin: r.read<String?>('origin'),
      url: r.read<String?>('url'),
    ),
];

Task _task(
  String id,
  String rank, {
  String? text,
  List<Attachment> attachments = const [],
  TaskStatus status = TaskStatus.pending,
}) {
  final t = DateTime.utc(2026, 10, 12, 8);
  return Task(
    id: id,
    text: text,
    attachments: attachments,
    status: status,
    rank: rank,
    colorKey: 0,
    createdAt: t,
    updatedAt: t,
  );
}

Attachment _image(String id, AttachmentOrigin origin) => Attachment(
  id: id,
  kind: AttachmentKind.image,
  origin: origin,
  mime: 'image/jpeg',
  byteSize: 1234,
  width: 4000,
  height: 3000,
  createdAt: DateTime.utc(2026, 10, 12),
);

Attachment _pdf(String id) => Attachment(
  id: id,
  kind: AttachmentKind.pdf,
  origin: AttachmentOrigin.file,
  mime: 'application/pdf',
  byteSize: 2400000,
  width: 595,
  height: 842,
  createdAt: DateTime.utc(2026, 10, 12),
  originalName: 'Programa.pdf',
  pageCount: 12,
);

Attachment _web(String id, String url) => Attachment(
  id: id,
  kind: AttachmentKind.web,
  origin: AttachmentOrigin.url,
  mime: 'text/html',
  byteSize: 0,
  width: 0,
  height: 0,
  createdAt: DateTime.utc(2026, 10, 12),
  url: url,
);

void main() {
  late String sql;

  setUpAll(() => sql = _rawConst('CURRENT_TASK_SQL'));

  group('la consulta fija (CA-019-16, 30)', () {
    test('CA-019-16: es una constante sin parámetros, de solo lectura y '
        'compatible con SQLite 3.18 (Android 8)', () {
      expect(sql.toUpperCase(), startsWith('SELECT'));
      expect(sql, isNot(contains('?')), reason: 'sin parámetros');
      expect(sql, isNot(contains(r'$')), reason: 'sin plantillas de Kotlin');
      expect(sql, isNot(contains(';')), reason: 'una sola sentencia');
      final upper = sql.toUpperCase();
      // Palabras enteras: `deleted_at` es una columna, `DELETE` una sentencia.
      for (final banned in [
        'INSERT',
        'UPDATE',
        'DELETE',
        'REPLACE',
        'DROP',
        'ALTER',
        'CREATE',
        'PRAGMA',
        'ATTACH',
        'RETURNING', // SQLite 3.35
        'OVER', // funciones de ventana: SQLite 3.25
        'WITH', // CTE: no hace falta
        'FILTER', // SQLite 3.30
        'NULLS', // SQLite 3.30
      ]) {
        expect(
          RegExp('\\b$banned\\b').hasMatch(upper),
          isFalse,
          reason: banned,
        );
      }
    });

    test('CA-019-16: acota cada columna de texto en SQL (una BD manipulada no '
        'carga 10 MB) y como mucho dos filas de adjuntos', () {
      expect(sql, contains('substr(t.body, 1, 1000)'));
      expect(sql, contains('substr(a.kind, 1,'));
      expect(sql, contains('substr(a.origin, 1,'));
      expect(sql, contains('substr(a.source_url, 1, 2048)'));
      expect(sql, contains('LIMIT 2'));
      // Ninguna columna de texto sale sin acotar.
      expect(RegExp(r'\bt\.body\b(?!, 1, 1000)').hasMatch(sql), isFalse);
      expect(RegExp(r'\ba\.source_url\b(?!, 1, 2048)').hasMatch(sql), isFalse);
    });

    test('CA-019-30: la versión de esquema que espera Kotlin es la de la app '
        '(un cambio de esquema obliga a revisar la consulta)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.read<int>('user_version'), db.schemaVersion);
      expect(_intConst('EXPECTED_USER_VERSION'), db.schemaVersion);
    });

    test('CA-019-16: el SQL no se aparta de las columnas del esquema '
        '(tablas y columnas que existen)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      // Si cambiara el nombre de una columna, esto lanzaría.
      expect(await db.customSelect(sql).get(), isEmpty);
    });
  });

  group('misma tarea y mismo primer adjunto que currentTask()', () {
    Future<void> expectSame(AppDatabase db, DriftTaskRepository repo) async {
      final current = await repo.currentTask();
      final rows = await _nativeRows(db, sql);
      if (current == null) {
        expect(rows, isEmpty);
        return;
      }
      expect(rows, isNotEmpty);
      final text = current.text;
      for (final row in rows) {
        expect(row.body, text, reason: 'el texto de la tarea actual');
      }
      final expected = current.attachments.take(2).toList();
      final real = rows.where((r) => r.hasAttachment).toList();
      expect(real, hasLength(expected.length));
      for (final (i, a) in expected.indexed) {
        expect(real[i].kind, a.kind.name, reason: 'tipo del adjunto $i');
        expect(real[i].origin, a.origin.name, reason: 'origen del adjunto $i');
        expect(real[i].url, a.url, reason: 'dirección del adjunto $i');
      }
      // Sin adjuntos: una sola fila, con el adjunto vacío.
      if (expected.isEmpty) {
        expect(rows, hasLength(1));
        expect(rows.single.hasAttachment, isFalse);
        expect(
          [rows.single.kind, rows.single.origin, rows.single.url],
          [null, null, null],
        );
      }
    }

    test('CA-019-16: sin tareas no hay filas (NoTask)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      await expectSame(db, DriftTaskRepository(db));
    });

    test('CA-019-16: una tarea de texto (y la actual es la de menor rank, no '
        'la primera insertada ni la de menor id)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      await repo.insert(_task('a', 'M', text: 'Segunda'));
      await repo.insert(_task('z', 'C', text: 'Llamar a Marta'));
      await repo.insert(_task('c', 'X', text: 'Tercera'));
      await expectSame(db, repo);
      final rows = await _nativeRows(db, sql);
      expect(rows.single.body, 'Llamar a Marta');
    });

    test('CA-019-16: foto de la cámara, imagen de la galería, PDF y web '
        '(con y sin texto)', () async {
      final cases = <String, Task>{
        'foto': _task(
          'a',
          'C',
          attachments: [_image('ia', AttachmentOrigin.camera)],
        ),
        'imagen': _task(
          'a',
          'C',
          attachments: [_image('ia', AttachmentOrigin.gallery)],
        ),
        'pdf': _task('a', 'C', attachments: [_pdf('pa')]),
        'web': _task(
          'a',
          'C',
          attachments: [_web('wa', 'https://www.example.org/ruta?q=1')],
        ),
        'foto con texto': _task(
          'a',
          'C',
          text: 'Revisar',
          attachments: [_image('ia', AttachmentOrigin.camera)],
        ),
        'web con texto': _task(
          'a',
          'C',
          text: 'Leer',
          attachments: [_web('wa', 'https://example.org')],
        ),
      };
      for (final MapEntry(key: label, value: task) in cases.entries) {
        final db = openInMemoryDatabase();
        final repo = DriftTaskRepository(db);
        await repo.insert(task);
        await expectSame(db, repo);
        final rows = await _nativeRows(db, sql);
        expect(rows, hasLength(1), reason: label);
        expect(rows.single.hasAttachment, isTrue, reason: label);
        await db.close();
      }
    });

    test('CA-019-16: un grupo de fotos da dos filas, las dos primeras por '
        'posición (no por id) y en ese orden (basta para saber "varios")', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      // Ids sin relación con la posición, y un origen por posición que distingue
      // «las dos primeras» de «las dos de menor id» y de «las dos de mayor id».
      const ids = ['d', 'j', 'b', 'h', 'f', 'a', 'i', 'c', 'g', 'e'];
      await repo.insert(
        _task(
          'a',
          'C',
          attachments: [
            for (final (i, id) in ids.indexed)
              _image(
                id,
                i == 1 ? AttachmentOrigin.gallery : AttachmentOrigin.camera,
              ),
          ],
        ),
      );
      await expectSame(db, repo);
      final rows = await _nativeRows(db, sql);
      expect(rows, hasLength(2), reason: 'LIMIT 2: no se leen las diez');
      expect([for (final r in rows) r.origin], ['camera', 'gallery']);
    });

    test('CA-019-16: las eliminadas y las marcadas como borradas no cuentan '
        '(la actual es la primera pendiente de verdad)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      await repo.insert(_task('a', 'C', text: 'Hecha antes'));
      await repo.insert(_task('b', 'F', text: 'La actual'));
      // Lo que dejaría una copia restaurada de antes del ADR-0012.
      await db.customStatement(
        "UPDATE tasks SET status = 'completed' WHERE id = 'a'",
      );
      await expectSame(db, repo);
      expect((await _nativeRows(db, sql)).single.body, 'La actual');

      await db.customStatement(
        'UPDATE tasks SET deleted_at = 1 WHERE id = \'b\'',
      );
      await expectSame(db, repo);
      expect(await _nativeRows(db, sql), isEmpty);
    });

    test('CA-019-16: un texto de 10 000 caracteres sale acotado a 1000 '
        '(la etiqueta usa 120)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      final long = List.generate(
        Task.maxTextLength,
        (i) => 'abcdefghij'[i % 10],
      ).join();
      await repo.insert(_task('a', 'C', text: long));
      final rows = await _nativeRows(db, sql);
      expect(rows.single.body, long.substring(0, 1000));
    });

    test('CA-019-16: una dirección de 100 000 caracteres sale acotada a '
        '2048', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      await repo.insert(
        _task('a', 'C', attachments: [_web('wa', 'https://e.org')]),
      );
      await db.customStatement(
        "UPDATE attachments SET source_url = 'https://e.org/' || "
        "replace(hex(zeroblob(50000)), '00', 'a')",
      );
      final rows = await _nativeRows(db, sql);
      expect(rows.single.url, hasLength(2048));
    });

    test('CA-019-16: un tipo o un origen larguísimos salen acotados '
        '(una base manipulada)', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      await repo.insert(
        _task('a', 'C', attachments: [_image('ia', AttachmentOrigin.camera)]),
      );
      await db.customStatement(
        "UPDATE attachments SET kind = replace(hex(zeroblob(5000)), '00', 'k'), "
        "origin = replace(hex(zeroblob(5000)), '00', 'o')",
      );
      final row = (await _nativeRows(db, sql)).single;
      expect(row.kind!.length, lessThanOrEqualTo(64));
      expect(row.origin!.length, lessThanOrEqualTo(64));
    });
  });

  group('el plan de la consulta (CA-019-16)', () {
    Future<String> plan(AppDatabase db) async =>
        (await db.customSelect('EXPLAIN QUERY PLAN $sql').get())
            .map((r) => r.read<String>('detail'))
            .join('\n');

    test('CA-019-16: sin SCAN de tasks ni de attachments; busca cada foto por '
        'clave', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final details = await plan(db);
      expect(
        RegExp(r'\bSCAN\b').hasMatch(details),
        isFalse,
        reason: 'plan:\n$details',
      );
      expect(details, contains('idx_attachments_task_position'));
      expect(details, contains('idx_tasks_current'));
    });

    test('CA-019-16: con 100 000 tareas el plan sigue sin SCAN y la lectura '
        'tarda menos de un segundo', () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      // Rellenado en SQL puro (rápido): 100 000 tareas con rank distinto y la primera con 3 fotos.
      await db.customStatement('''
        WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 99999)
        INSERT INTO tasks (id, body, status, rank, color_key, created_at, updated_at, source)
        SELECT 't' || i, 'Tarea ' || i, 'pending', printf('%08d', i + 10), 0, 0, 0, 'local' FROM n
      ''');
      await db.customStatement('''
        WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 99999)
        INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, rel_path, created_at, position)
        SELECT 'a' || i, 't' || i, 'image', 'gallery', 'image/jpeg', 1, 'p', 0, 0 FROM n
      ''');
      await db.customStatement('''
        INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, rel_path, created_at, position)
        VALUES ('x1', 't0', 'image', 'gallery', 'image/jpeg', 1, 'p', 0, 1),
               ('x2', 't0', 'image', 'gallery', 'image/jpeg', 1, 'p', 0, 2)
      ''');
      final details = await plan(db);
      expect(
        RegExp(r'\bSCAN\b').hasMatch(details),
        isFalse,
        reason: 'plan:\n$details',
      );
      final watch = Stopwatch()..start();
      final rows = await _nativeRows(db, sql);
      watch.stop();
      expect(rows, hasLength(2));
      expect(rows.first.body, 'Tarea 0');
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
