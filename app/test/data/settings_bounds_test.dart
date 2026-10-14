import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// CA-020-16: la lectura de los ajustes se acota **antes** de llegar a Dart:
/// lo que devuelve `readRawSetting` (la lectura cruda que usan todos los
/// ajustes) nunca supera los 16 caracteres, y lo demás se lee como ausente.
///
/// En Drift, el valor se mete con SQL tal cual (`customStatement`): lo que
/// dejaría una copia restaurada o una base manipulada.
const _maxLength = 16;
const _keys = [
  'firstRunDone',
  'hasEverHadTasks',
  'keepScreenOn',
  'lockZoom',
  'locale',
  'notificationsOn',
  'notificationsPerDay',
];

/// Un literal SQL de [n] caracteres (`x` repetida).
String _repeated(int n) => "replace(hex(zeroblob(${n ~/ 2})), '0', 'x')";

void main() {
  group('CA-020-16: lectura acotada (drift)', () {
    late AppDatabase db;
    late DriftTaskRepository repo;

    setUp(() {
      db = openInMemoryDatabase();
      repo = DriftTaskRepository(db);
    });
    tearDown(() => db.close());

    Future<void> put(String key, String valueSql) => db.customStatement(
      'INSERT OR REPLACE INTO settings (key, value, updated_at) '
      "VALUES ('$key', $valueSql, 0)",
    );

    test('CL-020-10: 16 caracteres se leen tal cual y 17 llegan como '
        'ausentes', () async {
      await put('locale', "'${'a' * 16}'");
      expect(await repo.readRawSetting('locale'), 'a' * 16);
      await put('locale', "'${'a' * 17}'");
      expect(await repo.readRawSetting('locale'), isNull);
    });

    test(
      'CA-020-16: un valor de 1 MB no llega a Dart (llega como ausente)',
      () async {
        await put('locale', _repeated(1000000));
        final length = await db
            .customSelect('SELECT length(value) AS n FROM settings')
            .map((r) => r.read<int>('n'))
            .getSingle();
        expect(length, 1000000, reason: 'la fila de la prueba es de 1 MB');
        expect(await repo.readRawSetting('locale'), isNull);
        expect(await repo.locale(), LocaleChoice.system);
      },
    );

    test('CA-020-16: un texto con un NUL dentro no esquiva el límite '
        '(length() de SQLite se detiene en el NUL)', () async {
      await put('lockZoom', "'true' || char(0) || ${_repeated(1000000)}");
      expect(await repo.readRawSetting('lockZoom'), isNull);
      expect(await repo.lockZoom(), isFalse);
    });

    test('CA-020-16: 16 caracteres de varios bytes (emoji) se leen; el '
        'tope de bytes no los corta', () async {
      final emoji = String.fromCharCodes([0x1F600]) * 4; // 4 caracteres.
      await put('locale', "'$emoji'");
      expect(await repo.readRawSetting('locale'), emoji);
    });

    final odd = <String, String>{
      'entero': '1',
      'entero grande': '9223372036854775807',
      'real': '1.5',
      'BLOB con los bytes de `true`': "X'74727565'",
      'BLOB vacío': "X''",
      'BLOB de 1 MB': 'zeroblob(1000000)',
      '`"yes"`': "'\"yes\"'",
    };
    for (final key in _keys) {
      for (final MapEntry(key: label, value: sql) in odd.entries) {
        test('CA-020-16, 17: `$key` guardada como $label se lee como '
            'ausente o ilegible y no lanza', () async {
          await put(key, sql);
          final raw = await repo.readRawSetting(key);
          // Un entero o un real se guardan como texto en una columna TEXT
          // (`1`, `1.5`): son texto de 16 caracteres o menos y los decodifica
          // `settings_codec` (ilegibles → defecto). Un BLOB no es texto.
          if (label.startsWith('BLOB')) expect(raw, isNull);
          expect(raw == null || raw.length <= _maxLength, isTrue);
          await _expectDefaults(repo);
        });
      }
    }

    test('CA-020-16, 17: un `NULL` (tabla sin NOT NULL, de una copia '
        'ajena) se lee como ausente en cada clave', () async {
      await db.customStatement('DROP TABLE settings');
      await db.customStatement(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT, '
        'updated_at INTEGER)',
      );
      for (final key in _keys) {
        await put(key, 'NULL');
        expect(await repo.readRawSetting(key), isNull, reason: key);
      }
      await _expectDefaults(repo);
    });

    test('CA-020-16: los valores válidos se leen igual que antes', () async {
      await put('locale', "'\"en\"'");
      await put('keepScreenOn', "'true'");
      await put('lockZoom', "'true'");
      await put('notificationsOn', "'true'");
      await put('notificationsPerDay', "'3'");
      await put('firstRunDone', "'true'");
      await put('hasEverHadTasks', "'true'");
      expect(await repo.locale(), LocaleChoice.en);
      expect(await repo.keepScreenOn(), isTrue);
      expect(await repo.lockZoom(), isTrue);
      expect(await repo.notificationsOn(), isTrue);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
      expect(await repo.firstRunDone(), isTrue);
      expect(await repo.hasEverHadTasks(), isTrue);
    });

    test('CA-020-16: una clave sin fila se lee como ausente', () async {
      expect(await repo.readRawSetting('locale'), isNull);
    });

    test('CA-020-16: la clave va como parámetro (una clave con comillas no '
        'rompe la consulta)', () async {
      expect(await repo.readRawSetting("a'b\" OR 1=1 --"), isNull);
    });
  });

  group('CA-020-16: la misma regla en memoria', () {
    late InMemoryTaskRepository repo;
    setUp(() => repo = InMemoryTaskRepository());
    tearDown(() => repo.dispose());

    test(
      'CL-020-10: 16 caracteres se leen y 17 llegan como ausentes',
      () async {
        repo.putRawSetting('locale', 'a' * 16);
        expect(await repo.readRawSetting('locale'), 'a' * 16);
        repo.putRawSetting('locale', 'a' * 17);
        expect(await repo.readRawSetting('locale'), isNull);
      },
    );

    test('CA-020-16: 1 MB llega como ausente y se lee el defecto', () async {
      repo.putRawSetting('locale', 'x' * 1000000);
      expect(await repo.readRawSetting('locale'), isNull);
      expect(await repo.locale(), LocaleChoice.system);
    });

    test('CA-020-16: un texto con un NUL dentro cuenta entero', () async {
      repo.putRawSetting('lockZoom', 'true\u0000${'x' * 100}');
      expect(await repo.readRawSetting('lockZoom'), isNull);
    });

    test('CA-020-16: sin fila, ausente', () async {
      expect(await repo.readRawSetting('locale'), isNull);
    });
  });
}

/// Los siete ajustes dan su valor por defecto y ninguno lanza (cada test deja
/// en una sola clave un valor que no es el exacto válido).
Future<void> _expectDefaults(SettingsRepository repo) async {
  expect(await repo.locale(), LocaleChoice.system);
  expect(await repo.keepScreenOn(), isFalse);
  expect(await repo.lockZoom(), isFalse);
  expect(await repo.notificationsOn(), isFalse);
  expect(await repo.notificationsPerDay(), NotificationsPerDay.one);
  expect(await repo.firstRunDone(), isFalse);
  expect(await repo.hasEverHadTasks(), isFalse);
}
