import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/task_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart' show sampleTask;

/// Un repositorio de ajustes que falla al leer lo que se le pida.
class _ThrowingSettings implements SettingsRepository {
  _ThrowingSettings(this._inner, {this.throwOn = const {}});

  final SettingsRepository _inner;
  final Set<String> throwOn;

  Never _fail(String key) => throw Exception('texto-secreto $key');

  @override
  Future<bool> firstRunDone() async => throwOn.contains('firstRunDone')
      ? _fail('firstRunDone')
      : _inner.firstRunDone();

  @override
  Future<bool> hasEverHadTasks() async => throwOn.contains('hasEverHadTasks')
      ? _fail('hasEverHadTasks')
      : _inner.hasEverHadTasks();

  @override
  Future<bool> keepScreenOn() async => throwOn.contains('keepScreenOn')
      ? _fail('keepScreenOn')
      : _inner.keepScreenOn();

  @override
  Future<bool> lockZoom() async {
    lockZoomReads++;
    return throwOn.contains('lockZoom') ? _fail('lockZoom') : _inner.lockZoom();
  }

  /// Cuántas veces se ha leído `lockZoom` (CA-017-11: una en el arranque).
  int lockZoomReads = 0;

  @override
  Future<bool> notificationsOn() async => throwOn.contains('notificationsOn')
      ? _fail('notificationsOn')
      : _inner.notificationsOn();

  @override
  Future<NotificationsPerDay> notificationsPerDay() async =>
      throwOn.contains('notificationsPerDay')
      ? _fail('notificationsPerDay')
      : _inner.notificationsPerDay();

  @override
  Future<void> setNotificationsOn(bool value) =>
      _inner.setNotificationsOn(value);

  @override
  Future<void> setNotificationsPerDay(NotificationsPerDay value) =>
      _inner.setNotificationsPerDay(value);

  @override
  Future<LocaleChoice> locale() async =>
      throwOn.contains('locale') ? _fail('locale') : _inner.locale();

  @override
  Future<void> setFirstRunDone() => _inner.setFirstRunDone();

  @override
  Future<void> setKeepScreenOn(bool value) => _inner.setKeepScreenOn(value);

  @override
  Future<void> setLockZoom(bool value) => _inner.setLockZoom(value);

  @override
  Future<void> setLocale(LocaleChoice choice) => _inner.setLocale(choice);
}

/// Un repositorio de tareas que no puede leer la tarea actual.
class _BrokenTasks extends InMemoryTaskRepository {
  @override
  Future<Task?> currentTask() async => throw Exception('disco');
}

void main() {
  test('CA-015-05: sin nada guardado, el arranque da los valores por '
      'defecto (pantalla apagada, idioma "Como el sistema")', () async {
    final repo = InMemoryTaskRepository();
    final boot = await readBootState(repo, repo);
    expect(boot.keepScreenOn, isFalse);
    expect(boot.locale, LocaleChoice.system);
    // Los valores por defecto de BootState son los mismos.
    const defaults = BootState(currentTask: null, firstRunDone: false);
    expect(defaults.keepScreenOn, isFalse);
    expect(defaults.locale, LocaleChoice.system);
  });

  test(
    'CA-015-10: el arranque lee el idioma y la pantalla guardados',
    () async {
      final repo = InMemoryTaskRepository();
      await repo.setLocale(LocaleChoice.en);
      await repo.setKeepScreenOn(true);
      final boot = await readBootState(repo, repo);
      expect(boot.locale, LocaleChoice.en);
      expect(boot.keepScreenOn, isTrue);
    },
  );

  test('CA-015-26: valores ilegibles no impiden el arranque', () async {
    final repo = InMemoryTaskRepository()
      ..putRawSetting('locale', '[[[[[[[[[[[[[[[[')
      ..putRawSetting('keepScreenOn', '"true"')
      ..putRawSetting('firstRunDone', 'basura')
      ..putRawSetting('hasEverHadTasks', 'basura');
    final boot = await readBootState(repo, repo);
    expect(boot.locale, LocaleChoice.system);
    expect(boot.keepScreenOn, isFalse);
    expect(boot.firstRunDone, isFalse);
    expect(boot.hasEverHadTasks, isFalse);
  });

  for (final key in ['firstRunDone', 'hasEverHadTasks']) {
    test('CA-020-17: un repositorio que lanza al leer `$key` no impide el '
        'arranque: como si la clave no existiera', () async {
      final repo = InMemoryTaskRepository();
      await repo.setFirstRunDone();
      await repo.setLocale(LocaleChoice.en);
      final boot = await readBootState(
        repo,
        _ThrowingSettings(repo, throwOn: {key}),
      );
      expect(boot.firstRunDone, key == 'firstRunDone' ? isFalse : isTrue);
      expect(boot.hasEverHadTasks, isFalse);
      expect(boot.locale, LocaleChoice.en, reason: 'los demás se leen');
    });
  }

  test('CA-020-17: con una tarea, `hasEverHadTasks` es verdadero aunque su '
      'lectura lance (no se lee)', () async {
    final repo = InMemoryTaskRepository();
    await repo.insert(sampleTask());
    final boot = await readBootState(
      repo,
      _ThrowingSettings(repo, throwOn: {'hasEverHadTasks'}),
    );
    expect(boot.hasEverHadTasks, isTrue);
  });

  // Los valores raros guardados en la base real (Drift), en cada clave de
  // marca: arranca sin error, sin registrar nada y como si no existiera.
  final oddValues = <String, String>{
    'un entero': '1',
    'un real': '1.5',
    'un BLOB': "X'74727565'",
    'un BLOB de 1 MB': 'zeroblob(1000000)',
    'un `NULL`': 'NULL',
    '`"yes"`': "'\"yes\"'",
    '`TRUE`': "'TRUE'",
    'un texto de 17 caracteres': "'${'t' * 17}'",
    'un texto de 1 MB': "replace(hex(zeroblob(500000)), '0', 't')",
  };
  for (final key in ['firstRunDone', 'hasEverHadTasks']) {
    for (final MapEntry(key: label, value: sql) in oddValues.entries) {
      test('CA-020-17: `$key` guardada como $label: arranca sin error, '
          'como si no existiera', () async {
        final db = openInMemoryDatabase();
        addTearDown(db.close);
        final repo = DriftTaskRepository(db);
        if (label.contains('NULL')) {
          await db.customStatement('DROP TABLE settings');
          await db.customStatement(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT, '
            'updated_at INTEGER)',
          );
        }
        await db.customStatement(
          'INSERT OR REPLACE INTO settings (key, value, updated_at) '
          "VALUES ('$key', $sql, 0)",
        );
        final printed = <String>[];
        final oldDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
        FlutterErrorDetails? reported;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) => reported = details;
        try {
          final boot = await readBootState(repo, repo);
          expect(boot.firstRunDone, isFalse);
          expect(boot.hasEverHadTasks, isFalse);
          expect(boot.currentTask, isNull);
        } finally {
          FlutterError.onError = oldOnError;
          debugPrint = oldDebugPrint;
        }
        expect(printed, isEmpty);
        expect(reported, isNull);
      });
    }
  }

  for (final key in ['locale', 'keepScreenOn', 'lockZoom']) {
    test('CL-015-16, CA-017-03: un repositorio que lanza al leer `$key` no '
        'impide el arranque (la tarea actual sí se lee)', () async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask());
      await repo.setLocale(LocaleChoice.en);
      await repo.setKeepScreenOn(true);
      await repo.setLockZoom(true);
      final boot = await readBootState(
        repo,
        _ThrowingSettings(repo, throwOn: {key}),
      );
      expect(boot.currentTask?.id, 't1');
      // Solo el que falla toma su valor por defecto; los otros dos, el
      // guardado (aislamiento entre ajustes).
      expect(
        boot.locale,
        key == 'locale' ? LocaleChoice.system : LocaleChoice.en,
      );
      expect(boot.keepScreenOn, key == 'keepScreenOn' ? isFalse : isTrue);
      expect(boot.lockZoom, key == 'lockZoom' ? isFalse : isTrue);
    });
  }

  test('CA-017-03: sin nada guardado, el bloqueo arranca apagado (también '
      'el valor por defecto de BootState)', () async {
    final repo = InMemoryTaskRepository();
    expect((await readBootState(repo, repo)).lockZoom, isFalse);
    const defaults = BootState(currentTask: null, firstRunDone: false);
    expect(defaults.lockZoom, isFalse);
  });

  test('CA-017-11: el arranque lee el bloqueo guardado', () async {
    final repo = InMemoryTaskRepository();
    await repo.setLockZoom(true);
    expect((await readBootState(repo, repo)).lockZoom, isTrue);
  });

  test('CA-017-03, CL-017-8: un valor ilegible del bloqueo no impide el '
      'arranque y deja los otros dos ajustes como estaban', () async {
    final repo = InMemoryTaskRepository()
      ..putRawSetting('lockZoom', '[[[[[[[[[[[[[[[[[')
      ..putRawSetting('keepScreenOn', 'true')
      ..putRawSetting('locale', '"en"');
    final boot = await readBootState(repo, repo);
    expect(boot.lockZoom, isFalse);
    expect(boot.keepScreenOn, isTrue);
    expect(boot.locale, LocaleChoice.en);
  });

  test('CA-017-11: `lockZoom` se lee una sola vez en el arranque, y ninguna '
      'si la tarea actual no se puede leer', () async {
    final repo = InMemoryTaskRepository();
    final counting = _ThrowingSettings(repo);
    await readBootState(repo, counting);
    expect(counting.lockZoomReads, 1);

    final broken = _BrokenTasks();
    final countingBroken = _ThrowingSettings(broken);
    await expectLater(readBootState(broken, countingBroken), throwsException);
    expect(countingBroken.lockZoomReads, 0);
  });

  test('CA-017-03: el texto de un fallo al leer el bloqueo no sale por '
      'ningún canal (debugPrint, print, FlutterError)', () async {
    final printed = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    FlutterErrorDetails? reported;
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) => reported = details;
    final repo = InMemoryTaskRepository();
    final zonePrinted = <String>[];
    try {
      await runZoned(
        () =>
            readBootState(repo, _ThrowingSettings(repo, throwOn: {'lockZoom'})),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => zonePrinted.add(line),
        ),
      );
    } finally {
      FlutterError.onError = oldOnError;
      debugPrint = oldDebugPrint;
    }
    expect(
      printed.join() + zonePrinted.join(),
      isNot(contains('texto-secreto')),
    );
    expect(reported, isNull);
  });

  test('CA-019-05: sin nada guardado, las notificaciones arrancan apagadas y '
      'en 1 al día (también los valores por defecto de BootState)', () async {
    final repo = InMemoryTaskRepository();
    final boot = await readBootState(repo, repo);
    expect(boot.notificationsOn, isFalse);
    expect(boot.notificationsPerDay, NotificationsPerDay.one);
    const defaults = BootState(currentTask: null, firstRunDone: false);
    expect(defaults.notificationsOn, isFalse);
    expect(defaults.notificationsPerDay, NotificationsPerDay.one);
  });

  test('CA-019-05: el arranque lee el interruptor y la cantidad '
      'guardados', () async {
    final repo = InMemoryTaskRepository();
    await repo.setNotificationsOn(true);
    await repo.setNotificationsPerDay(NotificationsPerDay.three);
    final boot = await readBootState(repo, repo);
    expect(boot.notificationsOn, isTrue);
    expect(boot.notificationsPerDay, NotificationsPerDay.three);
  });

  test('CA-019-05: la cantidad se conserva con el ajuste apagado', () async {
    final repo = InMemoryTaskRepository();
    await repo.setNotificationsOn(false);
    await repo.setNotificationsPerDay(NotificationsPerDay.two);
    final boot = await readBootState(repo, repo);
    expect(boot.notificationsOn, isFalse);
    expect(boot.notificationsPerDay, NotificationsPerDay.two);
  });

  test('CA-019-05: valores ilegibles no impiden el arranque ni se ven como '
      'error', () async {
    final repo = InMemoryTaskRepository()
      ..putRawSetting('notificationsOn', '"true"')
      ..putRawSetting('notificationsPerDay', '2.0')
      ..putRawSetting('lockZoom', 'true');
    final boot = await readBootState(repo, repo);
    expect(boot.notificationsOn, isFalse);
    expect(boot.notificationsPerDay, NotificationsPerDay.one);
    expect(boot.lockZoom, isTrue);
  });

  for (final key in ['notificationsOn', 'notificationsPerDay']) {
    test('CA-019-05: un repositorio que lanza al leer `$key` no impide el '
        'arranque, y el otro ajuste conserva lo guardado', () async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask());
      await repo.setNotificationsOn(true);
      await repo.setNotificationsPerDay(NotificationsPerDay.three);
      await repo.setLockZoom(true);
      final boot = await readBootState(
        repo,
        _ThrowingSettings(repo, throwOn: {key}),
      );
      expect(boot.currentTask?.id, 't1');
      expect(boot.notificationsOn, key == 'notificationsOn' ? isFalse : isTrue);
      expect(
        boot.notificationsPerDay,
        key == 'notificationsPerDay'
            ? NotificationsPerDay.one
            : NotificationsPerDay.three,
      );
      expect(boot.lockZoom, isTrue);
      expect(boot.keepScreenOn, isFalse);
    });
  }

  test('CA-019-05: el texto de un fallo al leer las notificaciones no sale '
      'por ningún canal (debugPrint, print, FlutterError)', () async {
    final printed = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    FlutterErrorDetails? reported;
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) => reported = details;
    final repo = InMemoryTaskRepository();
    final zonePrinted = <String>[];
    try {
      await runZoned(
        () => readBootState(
          repo,
          _ThrowingSettings(
            repo,
            throwOn: {'notificationsOn', 'notificationsPerDay'},
          ),
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => zonePrinted.add(line),
        ),
      );
    } finally {
      FlutterError.onError = oldOnError;
      debugPrint = oldDebugPrint;
    }
    expect(
      printed.join() + zonePrinted.join(),
      isNot(contains('texto-secreto')),
    );
    expect(reported, isNull);
  });

  test('CL-015-16: una base de datos inaccesible falla al leer la tarea '
      'actual (pantalla de error de almacenamiento), no se traga', () async {
    final tasks = _BrokenTasks();
    await expectLater(readBootState(tasks, tasks), throwsException);
  });
}
