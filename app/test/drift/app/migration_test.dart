import 'package:app/data/db/app_database.dart';
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
}
