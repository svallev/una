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

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Drift ejecuta la migración en una transacción: si falla, no cambia nada
    // y la app muestra el error de almacenamiento (spec 001).
    onUpgrade: stepByStep(
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
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
