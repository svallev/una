import 'package:app/data/db/app_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

/// Migraciones de la BD (ADR-0002, R-06). Cada nueva `schemaVersion` añade aquí
/// un test "vN → vN+1" con datos reales antes de aceptarse.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('el esquema v1 capturado coincide con el código', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  group('v1 → v2: sin histórico (ADR-0012)', () {
    const t0 = 1758880000000; // 2025-09-26, ms UTC

    /// Una tarea v1: pendiente, completada o marca de borrado (ADR-0011).
    String task(
      String id, {
      String status = 'pending',
      String? body = 'Tarea',
      int? completedAt,
      int? deletedAt,
    }) =>
        'INSERT INTO tasks (id, body, status, rank, color_key, created_at, '
        "updated_at, completed_at, deleted_at, source) VALUES ('$id', "
        "${body == null ? 'NULL' : "'$body'"}, '$status', 'M$id', 0, $t0, "
        '$t0, ${completedAt ?? 'NULL'}, ${deletedAt ?? 'NULL'}, '
        "'local')";

    String image(String id, String taskId) =>
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        'rel_path, display_rel_path, thumb_rel_path, width, height, created_at) '
        "VALUES ('$id', '$taskId', 'image', 'camera', 'image/jpeg', 100, "
        "'attachments/$id/full-0-0.jpg', 'attachments/$id/screen.jpg', "
        "'attachments/$id/thumb.jpg', 4000, 3000, $t0)";

    const firstRunDone =
        "INSERT INTO settings (key, value, updated_at) VALUES ('firstRunDone', "
        "'true', $t0)";

    /// Crea una BD v1 con [statements], la abre con el código actual (v2) y
    /// comprueba que el esquema migrado es el de la captura v2.
    Future<AppDatabase> migrate(List<String> statements) async {
      final schema = await verifier.schemaAt(1);
      statements.forEach(schema.rawDatabase.execute);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);
      return db;
    }

    Future<List<String>> ids(AppDatabase db, String table) async => [
      for (final row
          in await db.customSelect('SELECT id FROM $table ORDER BY id').get())
        row.read<String>('id'),
    ];

    Future<String?> setting(AppDatabase db, String key) async {
      final rows = await db
          .customSelect(
            'SELECT value FROM settings WHERE key = ?',
            variables: [Variable.withString(key)],
          )
          .get();
      return rows.isEmpty ? null : rows.single.read<String>('value');
    }

    test('borra completadas, marcas y sus adjuntos; quedan las pendientes y '
        'hasEverHadTasks = true', () async {
      final db = await migrate([
        firstRunDone,
        task('p1'),
        task('p2'),
        image('a-p2', 'p2'),
        task('c1', status: 'completed', completedAt: t0 + 1),
        task('c2', status: 'completed', completedAt: t0 + 2),
        image('a-c2', 'c2'),
        task('d1', body: null, deletedAt: t0 + 3),
      ]);
      expect(await ids(db, 'tasks'), ['p1', 'p2']);
      expect(await ids(db, 'attachments'), ['a-p2']);
      expect(await setting(db, 'hasEverHadTasks'), 'true');
      expect(await setting(db, 'firstRunDone'), 'true');
      await db.close();
    });

    test('BD vacía: sin tareas y sin hasEverHadTasks', () async {
      final db = await migrate([firstRunDone]);
      expect(await ids(db, 'tasks'), isEmpty);
      expect(await setting(db, 'hasEverHadTasks'), isNull);
      await db.close();
    });

    test('solo una marca de borrado: sin tareas y hasEverHadTasks = true '
        '(sigue viéndose "Todo hecho.")', () async {
      final db = await migrate([
        firstRunDone,
        task('d1', body: null, deletedAt: t0),
      ]);
      expect(await ids(db, 'tasks'), isEmpty);
      expect(await setting(db, 'hasEverHadTasks'), 'true');
      await db.close();
    });
  });
}
