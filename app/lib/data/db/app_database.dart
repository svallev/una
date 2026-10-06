import 'package:drift/drift.dart';

import 'app_database.steps.dart';

part 'app_database.g.dart';

/// Esquema completo (docs/architecture.md §3, ADR-0002). Incluye ya los campos
/// de la hoja de ruta (fechas, subtareas, importación, adjuntos) para no necesitar
/// migraciones en las specs 002–010. Fechas: epoch en ms UTC.
///
/// - v1: inicial.
/// - v2 (ADR-0012, sin histórico): mismas tablas; la migración borra una vez las
///   completadas y las marcas de borrado, y activa `hasEverHadTasks`.
///   `status`, `completedAt` y `deletedAt` se quedan sin uso.
/// - v3 (spec 016, ADR-0024): `attachments.position` (orden de las fotos de una
///   tarea) e índice no único `idx_attachments_task_position`; la migración
///   numera solo las tareas que ya tienen más de una fila.
///
/// Cualquier cambio: subir [AppDatabase.schemaVersion], `dart run drift_dev make-migrations`
/// y completar el test de migración generado (checklist de seguridad).
@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_current', columns: {#status, #deletedAt, #rank})
@TableIndex(name: 'idx_tasks_parent', columns: {#parentId})
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get body => text().nullable()(); // "text" choca con Table.text() en el código de migraciones
  TextColumn get status => text()(); // pending | completed
  TextColumn get rank => text()();
  IntColumn get colorKey => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get deletedAt =>
      integer().nullable()(); // sin uso desde v2 (ADR-0012)
  IntColumn get dueDate => integer().nullable()(); // Bloque 1
  TextColumn get parentId =>
      text().nullable().references(Tasks, #id)(); // Bloque 2
  TextColumn get source =>
      text().withDefault(const Constant('local'))(); // Bloque 3
  TextColumn get externalId => text().nullable()(); // Bloque 3

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AttachmentRow')
@TableIndex(name: 'idx_attachments_task', columns: {#taskId})
// No único a propósito (plan 016 §3): una BD restaurada con posiciones repetidas
// o con huecos debe poder leerse; la unicidad la garantiza la escritura.
@TableIndex(
  name: 'idx_attachments_task_position',
  columns: {#taskId, #position, #id},
)
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get kind => text()(); // image | pdf | document | web
  TextColumn get origin => text()(); // camera | gallery | file | url
  TextColumn get mime => text()();
  IntColumn get byteSize => integer()();
  TextColumn get relPath => text()();
  TextColumn get displayRelPath => text().nullable()();
  TextColumn get thumbRelPath => text().nullable()();
  TextColumn get originalName => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get sourceHost => text().nullable()();
  TextColumn get snapshotRelPath => text().nullable()();
  IntColumn get snapshotAt => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get sha256 => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Orden dentro de la tarea (v3, ADR-0024): 0..N-1 en las tareas con varias
  /// fotos; 0 en el resto. La lectura ordena por `(position, id)`.
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SettingRow')
class SettingEntries extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Tasks, Attachments, SettingEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// v2 → v3: numera `position` solo en las tareas con más de una fila (el
  /// resto se queda con el 0 por defecto). Un único recorrido **lineal** sobre
  /// `ORDER BY task_id, created_at, id`; una subconsulta correlacionada por
  /// fila sería O(n²) y una BD manipulada bloquearía el arranque (plan 016 §3).
  /// Corre dentro de la transacción de `onUpgrade`.
  Future<void> _numberMultiRowTasks() async {
    final rows = await customSelect(
      'SELECT id, task_id FROM attachments WHERE task_id IN ('
      'SELECT task_id FROM attachments GROUP BY task_id HAVING COUNT(*) > 1) '
      'ORDER BY task_id, created_at, id',
    ).get();
    String? current;
    var next = 0;
    for (final row in rows) {
      final taskId = row.read<String>('task_id');
      if (taskId != current) {
        current = taskId;
        next = 0;
      }
      await customUpdate(
        'UPDATE attachments SET position = ? WHERE id = ?',
        variables: [
          Variable.withInt(next++),
          Variable.withString(row.read<String>('id')),
        ],
        updates: {attachments},
        updateKind: UpdateKind.update,
      );
    }
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Drift no abre una transacción para migrar: se abre aquí, para que un
    // fallo a mitad no deje nada cambiado ni `user_version` subido; la app
    // muestra el error de almacenamiento (spec 001) y la migración se repite
    // en el siguiente arranque.
    onUpgrade: (m, from, to) => transaction(
      () => stepByStep(
        from1To2: (m, schema) async {
          // Sin histórico (ADR-0012). Primero el ajuste, que necesita ver las
          // filas; después los adjuntos (clave foránea) y las tareas. Los
          // archivos de los adjuntos borrados los recoge el barrido.
          await customStatement(
            'INSERT OR REPLACE INTO settings (key, value, updated_at) '
            "SELECT 'hasEverHadTasks', 'true', ? "
            'WHERE EXISTS (SELECT 1 FROM tasks)',
            [DateTime.now().millisecondsSinceEpoch],
          );
          await customStatement(
            'DELETE FROM attachments WHERE task_id IN (SELECT id FROM tasks '
            "WHERE status <> 'pending' OR deleted_at IS NOT NULL)",
          );
          await customStatement(
            "DELETE FROM tasks WHERE status <> 'pending' OR deleted_at IS NOT NULL",
          );
        },
        from2To3: (m, schema) async {
          await m.addColumn(schema.attachments, schema.attachments.position);
          await m.createIndex(schema.idxAttachmentsTaskPosition);
          await _numberMultiRowTasks();
        },
      )(m, from, to),
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
