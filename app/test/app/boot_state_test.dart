import 'package:app/app/providers.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/task_repository.dart';
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
  Future<bool> hasEverHadTasks() => _inner.hasEverHadTasks();

  @override
  Future<bool> keepScreenOn() async => throwOn.contains('keepScreenOn')
      ? _fail('keepScreenOn')
      : _inner.keepScreenOn();

  @override
  Future<LocaleChoice> locale() async =>
      throwOn.contains('locale') ? _fail('locale') : _inner.locale();

  @override
  Future<void> setFirstRunDone() => _inner.setFirstRunDone();

  @override
  Future<void> setKeepScreenOn(bool value) => _inner.setKeepScreenOn(value);

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

  for (final key in ['locale', 'keepScreenOn']) {
    test('CL-015-16: un repositorio que lanza al leer `$key` no impide el '
        'arranque (la tarea actual sí se lee)', () async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask());
      await repo.setLocale(LocaleChoice.en);
      await repo.setKeepScreenOn(true);
      final boot = await readBootState(
        repo,
        _ThrowingSettings(repo, throwOn: {key}),
      );
      expect(boot.currentTask?.id, 't1');
      // Solo el que falla toma su valor por defecto.
      expect(
        boot.locale,
        key == 'locale' ? LocaleChoice.system : LocaleChoice.en,
      );
      expect(boot.keepScreenOn, key == 'keepScreenOn' ? isFalse : isTrue);
    });
  }

  test('CL-015-16: una base de datos inaccesible falla al leer la tarea '
      'actual (pantalla de error de almacenamiento), no se traga', () async {
    final tasks = _BrokenTasks();
    await expectLater(readBootState(tasks, tasks), throwsException);
  });
}
