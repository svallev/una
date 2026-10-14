import 'package:app/data/db/app_database.dart';
import 'package:drift/drift.dart'
    show
        ApplyInterceptor,
        ApplyInterceptorConnection,
        OpeningDetails,
        QueryExecutor,
        QueryExecutorUser,
        QueryInterceptor,
        Variable;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

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
    /// Crea una BD v1 con [statements], la abre con el código actual (v3) y
    /// comprueba que el esquema migrado es el de la captura v3.
    Future<AppDatabase> migrate(List<String> statements) async {
      final schema = await verifier.schemaAt(1);
      statements.forEach(schema.rawDatabase.execute);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
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

    test('si falla a mitad, no cambia nada y se repite en el siguiente '
        'arranque (transacción explícita)', () async {
      final schema = await verifier.schemaAt(1);
      [
        firstRunDone,
        task('p1'),
        task('c1', status: 'completed', completedAt: t0 + 1),
        image('a-c1', 'c1'),
        // El último paso (borrar las tareas) falla.
        'CREATE TRIGGER boom BEFORE DELETE ON tasks '
            "BEGIN SELECT RAISE(ABORT, 'disco lleno'); END",
      ].forEach(schema.rawDatabase.execute);

      final failing = AppDatabase(schema.newConnection());
      await expectLater(
        failing.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await failing.close();

      final raw = schema.rawDatabase;
      int count(String sql) => raw.select(sql).first.values.first! as int;
      // Nada a medias: siguen el adjunto, la completada y la versión 1.
      expect(count('SELECT COUNT(*) FROM attachments'), 1);
      expect(count('SELECT COUNT(*) FROM tasks'), 2);
      expect(
        count("SELECT COUNT(*) FROM settings WHERE key = 'hasEverHadTasks'"),
        0,
      );
      expect(raw.userVersion, 1);

      raw.execute('DROP TRIGGER boom');
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      expect(await ids(db, 'tasks'), ['p1']);
      expect(await ids(db, 'attachments'), isEmpty);
      expect(await setting(db, 'hasEverHadTasks'), 'true');
      await db.close();
    });
  });

  group('v2/v1 → v3: orden de las fotos (spec 016, ADR-0024)', () {
    /// Un adjunto con la forma de la v2 (sin `position`), con `kind` y fecha
    /// propios para poder probar el orden `created_at, id`.
    String attachment(
      String id,
      String taskId, {
      String kind = 'image',
      int createdAt = t0,
      String? sourceUrl,
    }) =>
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        'rel_path, display_rel_path, thumb_rel_path, source_url, width, '
        'height, created_at) VALUES ('
        "'$id', '$taskId', '$kind', '${kind == 'web' ? 'url' : 'camera'}', "
        "'x/y', 100, 'attachments/$id/full', 'attachments/$id/screen.jpg', "
        "'attachments/$id/thumb.jpg', ${sourceUrl == null ? 'NULL' : "'$sourceUrl'"}, "
        '4000, 3000, $createdAt)';

    /// Datos de una instalación con de todo: solo texto, imagen, PDF, web,
    /// **una tarea con dos filas** (la de id menor, la más reciente: el orden
    /// es por fecha y luego por id) y adjuntos huérfanos (de una tarea que no
    /// existe; el de dos filas también se numera).
    List<String> installation() => [
      firstRunDone,
      task('t-text'),
      task('t-image'),
      attachment('a-image', 't-image'),
      task('t-pdf'),
      attachment('a-pdf', 't-pdf', kind: 'pdf'),
      task('t-web'),
      attachment('a-web', 't-web', kind: 'web', sourceUrl: 'https://a.example'),
      task('t-two'),
      attachment('a-two-1', 't-two', createdAt: t0 + 5),
      attachment('a-two-2', 't-two', createdAt: t0 + 1),
      attachment('a-orphan', 'ghost-1'),
      attachment('a-orphan-b', 'ghost-2', createdAt: t0 + 2),
      attachment('a-orphan-a', 'ghost-2', createdAt: t0 + 2),
    ];

    Future<List<Map<String, Object?>>> dump(AppDatabase db, String sql) async =>
        [for (final row in await db.customSelect(sql).get()) row.data];

    List<Map<String, Object?>> rawDump(InitializedSchema schema, String sql) =>
        [
          for (final row in schema.rawDatabase.select(sql))
            Map<String, Object?>.from(row),
        ];

    Future<Map<String, int>> positions(AppDatabase db) async => {
      for (final row
          in await db
              .customSelect('SELECT id, position FROM attachments')
              .get())
        row.read<String>('id'): row.read<int>('position'),
    };

    const tasksSql = 'SELECT * FROM tasks ORDER BY id';
    const attachmentsSql =
        'SELECT id, task_id, kind, origin, mime, byte_size, rel_path, '
        'display_rel_path, thumb_rel_path, source_url, width, height, '
        'created_at FROM attachments ORDER BY id';

    test('el esquema v3 capturado coincide con el código', () async {
      final connection = await verifier.startAt(3);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });

    test('CA-016-15: v2 → v3 no cambia ninguna tarea ni adjunto; solo la '
        'tarea de dos filas se numera, por fecha y luego por id', () async {
      final schema = await verifier.schemaAt(2);
      installation().forEach(schema.rawDatabase.execute);
      final tasksBefore = rawDump(schema, tasksSql);
      final attachmentsBefore = rawDump(schema, attachmentsSql);

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);

      expect(await dump(db, tasksSql), tasksBefore);
      expect(await dump(db, attachmentsSql), attachmentsBefore);
      expect(await positions(db), {
        'a-image': 0,
        'a-pdf': 0,
        'a-web': 0,
        // t-two: a-two-2 es más antigua aunque su id sea mayor.
        'a-two-2': 0,
        'a-two-1': 1,
        'a-orphan': 0,
        // Misma fecha: desempata el id.
        'a-orphan-a': 0,
        'a-orphan-b': 1,
      });
      // El archivo migrado abre y se lee con el código nuevo.
      expect((await db.select(db.tasks).get()).length, 5);
      expect((await db.select(db.attachments).get()).length, 8);
      await db.close();
    });

    test('CA-016-15: v1 → v3 llega al mismo resultado (las pendientes no '
        'cambian y los adjuntos de las borradas desaparecen)', () async {
      final schema = await verifier.schemaAt(1);
      [
        ...installation(),
        task('t-done', status: 'completed', completedAt: t0 + 1),
        attachment('a-done-1', 't-done'),
        attachment('a-done-2', 't-done', createdAt: t0 + 3),
      ].forEach(schema.rawDatabase.execute);
      final pendingBefore = rawDump(
        schema,
        "SELECT * FROM tasks WHERE status = 'pending' ORDER BY id",
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);

      expect(await dump(db, tasksSql), pendingBefore);
      final pos = await positions(db);
      expect(pos.keys, isNot(contains('a-done-1')));
      expect(pos['a-two-2'], 0);
      expect(pos['a-two-1'], 1);
      expect(pos['a-image'], 0);
      expect(pos['a-orphan-a'], 0);
      expect(pos['a-orphan-b'], 1);
      await db.close();
    });

    test('CA-016-25: el índice por posición no es único (una BD restaurada '
        'con posiciones repetidas se puede guardar y leer)', () async {
      final schema = await verifier.schemaAt(2);
      [
        task('t1'),
        attachment('a1', 't1'),
        attachment('a2', 't1'),
      ].forEach(schema.rawDatabase.execute);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);

      final indexes = await db
          .customSelect("PRAGMA index_list('attachments')")
          .get();
      final byName = {
        for (final r in indexes) r.read<String>('name'): r.read<int>('unique'),
      };
      expect(byName['idx_attachments_task_position'], 0);
      await db.customStatement('UPDATE attachments SET position = 7');
      expect((await positions(db)).values, [7, 7]);
      await db.close();
    });

    test('CA-016-15: una BD v2 con 50 000 filas en una tarea migra en tiempo '
        'lineal y las numera por fecha y luego por id', () async {
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase.execute(task('big'));
      // Fechas repetidas (i % 7) para que el desempate por id cuente; el id
      // se escribe al revés del orden de inserción para no coincidir con él.
      schema.rawDatabase.execute(
        'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 50000) '
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        'rel_path, created_at) '
        "SELECT printf('a%06d', 50001 - i), 'big', 'image', 'gallery', "
        "'image/jpeg', 1, 'x', $t0 + (i % 7) FROM n",
      );

      final stopwatch = Stopwatch()..start();
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      stopwatch.stop();

      // Presupuesto holgado (la migración mide ~1 s): una subconsulta
      // correlacionada por fila (O(n²)) tardaría minutos.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
      final rows = await db
          .customSelect(
            'SELECT id, position FROM attachments '
            'ORDER BY created_at, id',
          )
          .get();
      expect(rows.length, 50000);
      expect(
        [for (final r in rows) r.read<int>('position')],
        [for (var i = 0; i < 50000; i++) i],
      );
      await db.close();
    });
  });

  group('v2 → v3 por páginas (spec 020, CA-020-20)', () {
    /// Un adjunto v2 mínimo (sin `position`).
    String row(String id, String taskId, int createdAt) =>
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        "rel_path, created_at) VALUES ('$id', '$taskId', 'image', 'gallery', "
        "'image/jpeg', 1, 'x', $createdAt)";

    /// Referencia: la implementación de antes de la 020, copiada tal cual
    /// (carga **todas** las filas y numera en un solo recorrido) sobre la BD
    /// cruda ya con la columna `position`. Devuelve `id → position`.
    Map<String, int> referencePositions(InitializedSchema schema) {
      final raw = schema.rawDatabase;
      final rows = raw.select(
        'SELECT id, task_id FROM attachments WHERE task_id IN ('
        'SELECT task_id FROM attachments GROUP BY task_id HAVING COUNT(*) > 1) '
        'ORDER BY task_id, created_at, id',
      );
      final result = <String, int>{
        for (final r in raw.select('SELECT id FROM attachments'))
          r['id'] as String: 0,
      };
      String? current;
      var next = 0;
      for (final r in rows) {
        final taskId = r['task_id'] as String;
        if (taskId != current) {
          current = taskId;
          next = 0;
        }
        result[r['id'] as String] = next++;
      }
      return result;
    }

    Future<Map<String, int>> positionsOf(AppDatabase db) async => {
      for (final r
          in await db
              .customSelect('SELECT id, position FROM attachments')
              .get())
        r.read<String>('id'): r.read<int>('position'),
    };

    /// Compara sin `equals` sobre el mapa entero (cuadrático con decenas de
    /// miles de elementos): longitud y una comprobación por clave.
    void expectSamePositions(
      Map<String, int> actual,
      Map<String, int> expected,
    ) {
      expect(actual.length, expected.length);
      var different = 0;
      for (final e in expected.entries) {
        if (actual[e.key] != e.value) different++;
      }
      expect(different, 0, reason: 'posiciones distintas de la referencia');
    }

    /// Abre con un interceptor que anota cuántas filas devuelve cada `SELECT`
    /// de la migración sobre `attachments`.
    (AppDatabase, List<int>) openCounting(InitializedSchema schema) {
      final sizes = <int>[];
      final db = AppDatabase(
        schema.newConnection().interceptWith(_RowCounter(sizes)),
      );
      return (db, sizes);
    }

    Future<void> insertManyTasks(InitializedSchema schema) async {
      // 50 000 filas en 499 tareas (tamaños 100 y 101: casi ninguna página de
      // 500 termina en el límite de una tarea), fechas repetidas (i % 7) e ids
      // al revés del orden de inserción; más tareas de una sola fila mezcladas.
      schema.rawDatabase.execute(
        'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 50000) '
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        'rel_path, created_at) '
        "SELECT printf('a%06d', 50001 - i), printf('t%03d', i % 499), "
        "'image', 'gallery', 'image/jpeg', 1, 'x', $t0 + (i % 7) FROM n",
      );
      for (var i = 0; i < 40; i++) {
        schema.rawDatabase.execute(row('single-$i', 's${i * 13 % 40}', t0));
      }
    }

    test('CA-020-20: 50 000 filas en 499 tareas dan las mismas posiciones '
        'que la implementación anterior, con páginas de 500 filas como '
        'máximo', () async {
      final schema = await verifier.schemaAt(2);
      await insertManyTasks(schema);

      final (db, sizes) = openCounting(schema);
      await verifier.migrateAndValidate(db, 3);
      final pages = List<int>.of(sizes); // solo lo que lee la migración

      // La referencia se calcula sobre una copia ya migrada: las tareas de una
      // sola fila y las de varias salen del mismo SQL de antes.
      final reference = referencePositions(schema);
      expectSamePositions(await positionsOf(db), reference);
      expect(
        reference.values.where((p) => p > 0).length,
        greaterThan(49000),
        reason: 'la referencia debe numerar casi todo',
      );
      // Ninguna lectura de la migración trae más de una página.
      expect(pages, isNotEmpty);
      expect(pages.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(500));
      expect(pages.length, greaterThan(50000 ~/ 500));
      // Los dos únicos índices de `attachments` son los del esquema v3: el
      // auxiliar de la migración no queda.
      final indexes = await db
          .customSelect("PRAGMA index_list('attachments')")
          .get();
      expect(
        {for (final r in indexes) r.read<String>('name')}
            .where((n) => !n.startsWith('sqlite_autoindex')),
        unorderedEquals([
          'idx_attachments_task',
          'idx_attachments_task_position',
        ]),
      );
      await db.close();
    });

    test('CA-020-20: las tareas de una sola fila no se reescriben (solo se '
        'numeran las de varias)', () async {
      final schema = await verifier.schemaAt(2);
      for (var i = 0; i < 3; i++) {
        schema.rawDatabase.execute(row('multi$i', 'm', t0 + i));
      }
      schema.rawDatabase.execute(row('single', 's', t0));
      // Escribir en la fila de una tarea de una sola fila haría fallar.
      schema.rawDatabase.execute(
        'CREATE TRIGGER boom BEFORE UPDATE ON attachments '
        "WHEN NEW.id = 'single' BEGIN SELECT RAISE(ABORT, 'no tocar'); END",
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      expect(await positionsOf(db), {
        'multi0': 0,
        'multi1': 1,
        'multi2': 2,
        'single': 0,
      });
      await db.close();
    });

    test('CA-020-20: 50 000 filas en una sola tarea: mismas posiciones y '
        'páginas de 500 filas como máximo', () async {
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase.execute(
        'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 50000) '
        'INSERT INTO attachments (id, task_id, kind, origin, mime, byte_size, '
        'rel_path, created_at) '
        "SELECT printf('a%06d', 50001 - i), 'big', 'image', 'gallery', "
        "'image/jpeg', 1, 'x', $t0 + (i % 7) FROM n",
      );

      final stopwatch = Stopwatch()..start();
      final (db, sizes) = openCounting(schema);
      await verifier.migrateAndValidate(db, 3);
      final pages = List<int>.of(sizes); // solo lo que lee la migración
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
      expectSamePositions(await positionsOf(db), referencePositions(schema));
      expect(pages.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(500));
      await db.close();
    });

    test('CA-020-20: una tarea que cruza el límite de una página sigue '
        'numerándose sin reiniciar el contador', () async {
      final schema = await verifier.schemaAt(2);
      // 'a' tiene 499 filas y 'b' 3: la página 1 acaba con la primera de 'b'.
      // 'c' tiene una sola fila (no se numera).
      for (var i = 0; i < 499; i++) {
        schema.rawDatabase.execute(
          row('a${i.toString().padLeft(3, '0')}', 'a', t0 + i),
        );
      }
      for (var i = 0; i < 3; i++) {
        schema.rawDatabase.execute(row('b$i', 'b', t0 + 10 - i));
      }
      schema.rawDatabase.execute(row('c0', 'c', t0));

      final (db, sizes) = openCounting(schema);
      await verifier.migrateAndValidate(db, 3);
      final pages = List<int>.of(sizes); // solo lo que lee la migración
      final pos = await positionsOf(db);
      // b: la más antigua es b2 (t0 + 8), luego b1, luego b0.
      expect([pos['b2'], pos['b1'], pos['b0']], [0, 1, 2]);
      expect(pos['c0'], 0);
      expect(pos['a000'], 0);
      expect(pos['a498'], 498);
      expectSamePositions(pos, referencePositions(schema));
      expect(pages.first, 500);
      await db.close();
    });

    test('CA-020-20: si falla en la segunda página, la BD sigue en v2 y '
        'entera, y se repite en el siguiente arranque', () async {
      final schema = await verifier.schemaAt(2);
      await insertManyTasks(schema);
      final before = [
        for (final r in schema.rawDatabase.select(
          'SELECT * FROM attachments ORDER BY id',
        ))
          Map<String, Object?>.from(r),
      ];
      // La 501.ª fila numerada (ya en la segunda página) falla al actualizarse:
      // la primera página se había escrito.
      schema.rawDatabase.execute(
        'CREATE TRIGGER boom BEFORE UPDATE ON attachments '
        "WHEN NEW.id = 'a025000' BEGIN SELECT RAISE(ABORT, 'disco lleno'); END",
      );

      final failing = AppDatabase(schema.newConnection());
      await expectLater(
        failing.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await failing.close();

      final raw = schema.rawDatabase;
      expect(raw.userVersion, 2);
      final columns = [
        for (final r in raw.select("PRAGMA table_info('attachments')"))
          r['name'] as String,
      ];
      expect(columns, isNot(contains('position')));
      final after = [
        for (final r in raw.select('SELECT * FROM attachments ORDER BY id'))
          Map<String, Object?>.from(r),
      ];
      expect(after.length, before.length);
      var changed = 0;
      for (var i = 0; i < before.length; i++) {
        if (!_sameRow(before[i], after[i])) changed++;
      }
      expect(changed, 0);
      final indexes = [
        for (final r in raw.select("PRAGMA index_list('attachments')"))
          r['name'] as String,
      ];
      expect(indexes, isNot(contains('idx_attachments_task_position')));

      raw.execute('DROP TRIGGER boom');
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      expectSamePositions(await positionsOf(db), referencePositions(schema));
      await db.close();
    });
  });
}

bool _sameRow(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// Anota cuántas filas devuelve cada `SELECT` sobre `attachments`, también
/// los de la migración: drift ejecuta `beforeOpen` con el ejecutor **interior**,
/// así que se envuelve el usuario para que esa llamada también pase por aquí.
class _RowCounter extends QueryInterceptor {
  _RowCounter(this.sizes);

  final List<int> sizes;

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      executor.ensureOpen(_SpyUser(user, this));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await super.runSelect(executor, statement, args);
    if (statement.contains('attachments')) sizes.add(rows.length);
    return rows;
  }
}

class _SpyUser implements QueryExecutorUser {
  _SpyUser(this._inner, this._interceptor);

  final QueryExecutorUser _inner;
  final QueryInterceptor _interceptor;

  @override
  int get schemaVersion => _inner.schemaVersion;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) =>
      _inner.beforeOpen(executor.interceptWith(_interceptor), details);
}
