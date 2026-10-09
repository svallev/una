import 'dart:async';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio de ajustes controlable: cada escritura espera a su compuerta
/// (la general o la de su clave) o falla con un texto que no debe escaparse.
/// Anota el orden de las escrituras y cuántas hay a la vez.
class _ControlledSettings extends InMemoryTaskRepository {
  final locales = <LocaleChoice>[];
  final keepScreenOnWrites = <bool>[];
  final lockZoomWrites = <bool>[];

  /// `start:<clave>` y `end:<clave>` en el orden en que ocurren.
  final log = <String>[];
  int active = 0;
  int maxActive = 0;

  /// Compuerta y error generales (todas las claves) y por clave.
  Completer<void>? gate;
  Object? error;
  final gates = <String, Completer<void>>{};
  final errors = <String, Object>{};

  /// Claves cuya escritura lanza de forma **síncrona** (sin ser `async`).
  final syncThrow = <String>{};

  /// Retraso de cada escritura (para ver el orden y la concurrencia).
  Duration delay = Duration.zero;

  Future<void> _write(
    String key,
    void Function() record,
    Future<void> Function() inner,
  ) {
    if (syncThrow.contains(key)) throw StateError('texto-secreto');
    return _asyncWrite(key, record, inner);
  }

  Future<void> _asyncWrite(
    String key,
    void Function() record,
    Future<void> Function() inner,
  ) async {
    log.add('start:$key');
    record();
    active++;
    if (active > maxActive) maxActive = active;
    try {
      final g = gates[key] ?? gate;
      if (g != null) await g.future;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if ((errors[key] ?? error) case final e?) throw e;
      await inner();
    } finally {
      active--;
      log.add('end:$key');
    }
  }

  @override
  Future<void> setLocale(LocaleChoice choice) => _write(
    'locale',
    () => locales.add(choice),
    () => super.setLocale(choice),
  );

  @override
  Future<void> setKeepScreenOn(bool value) => _write(
    'keepScreenOn',
    () => keepScreenOnWrites.add(value),
    () => super.setKeepScreenOn(value),
  );

  @override
  Future<void> setLockZoom(bool value) => _write(
    'lockZoom',
    () => lockZoomWrites.add(value),
    () => super.setLockZoom(value),
  );
}

void main() {
  late _ControlledSettings repo;
  late ProviderContainer container;

  setUp(() async {
    repo = _ControlledSettings();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        bootStateProvider.overrideWithValue(await readBootState(repo, repo)),
      ],
    );
    addTearDown(container.dispose);
  });

  SettingsController controller() => container.read(settingsProvider.notifier);
  AppSettings state() => container.read(settingsProvider);

  test('CA-015-05: el estado sale del arranque (por defecto, apagada y '
      '"Como el sistema")', () {
    expect(state().keepScreenOn, isFalse);
    expect(state().locale, LocaleChoice.system);
  });

  test('CA-015-10: con un idioma y la pantalla guardados, el estado sale '
      'de ellos', () async {
    final other = _ControlledSettings();
    await other.setLocale(LocaleChoice.en);
    await other.setKeepScreenOn(true);
    final c = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(other),
        bootStateProvider.overrideWithValue(await readBootState(other, other)),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).locale, LocaleChoice.en);
    expect(c.read(settingsProvider).keepScreenOn, isTrue);
  });

  test(
    'CA-015-08: guardar el idioma no lo aplica; aplicar lo cambia',
    () async {
      expect(await controller().saveLocale(LocaleChoice.es), SaveResult.saved);
      expect(await repo.locale(), LocaleChoice.es);
      expect(state().locale, LocaleChoice.system);
      controller().applyLocale(LocaleChoice.es);
      expect(state().locale, LocaleChoice.es);
    },
  );

  test('CA-015-08: la misma opción no escribe', () async {
    controller().applyLocale(LocaleChoice.en);
    expect(
      await controller().saveLocale(LocaleChoice.en),
      SaveResult.unchanged,
    );
    expect(repo.locales, isEmpty);
  });

  test(
    'CA-015-03: el interruptor cambia solo cuando el guardado termina',
    () async {
      repo.gate = Completer<void>();
      final pending = controller().setKeepScreenOn(true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.keepScreenOnWrites, [true]);
      expect(state().keepScreenOn, isFalse, reason: 'sin cambio optimista');
      repo.gate!.complete();
      expect(await pending, SaveResult.saved);
      expect(state().keepScreenOn, isTrue);
      expect(await repo.keepScreenOn(), isTrue);
    },
  );

  test('CA-015-25: si falla el guardado, nada cambia', () async {
    repo.error = Exception('texto-secreto');
    expect(await controller().setKeepScreenOn(true), SaveResult.failed);
    expect(state().keepScreenOn, isFalse);
    expect(await controller().saveLocale(LocaleChoice.en), SaveResult.failed);
    expect(state().locale, LocaleChoice.system);
    // Un fallo no deja el guardado "en curso": el siguiente intento va.
    repo.error = null;
    expect(await controller().setKeepScreenOn(true), SaveResult.saved);
    expect(state().keepScreenOn, isTrue);
  });

  test('CA-017-02: un guardado de otro ajuste o del idioma, mientras hay uno '
      'en curso, espera y se aplica (ya no se ignora)', () async {
    repo.gates['keepScreenOn'] = Completer<void>();
    final first = controller().setKeepScreenOn(true);
    await Future<void>.delayed(Duration.zero);
    final language = controller().saveLocale(LocaleChoice.en);
    await Future<void>.delayed(Duration.zero);
    expect(repo.locales, isEmpty, reason: 'espera su turno');
    repo.gates['keepScreenOn']!.complete();
    expect(await first, SaveResult.saved);
    expect(await language, SaveResult.saved);
    expect(repo.keepScreenOnWrites, [true]);
    expect(repo.locales, [LocaleChoice.en]);
    expect(await repo.locale(), LocaleChoice.en);
    expect(state().keepScreenOn, isTrue);
    // Terminado el primero, el siguiente toque ya se guarda.
    expect(await controller().setKeepScreenOn(false), SaveResult.saved);
    expect(await repo.keepScreenOn(), isFalse);
    expect(state().keepScreenOn, isFalse);
  });

  test('CA-015-25: el error de un guardado no se escapa (ni `FlutterError`, '
      '`debugPrint`, `print` ni zona) ni se muestra', () async {
    final seen = <String>[];
    final flutterErrors = <FlutterErrorDetails>[];
    final zoneErrors = <Object>[];
    final oldOnError = FlutterError.onError;
    final oldDebugPrint = debugPrint;
    FlutterError.onError = flutterErrors.add;
    debugPrint = (String? message, {int? wrapWidth}) => seen.add('$message');
    repo.error = Exception('texto-secreto');

    await runZonedGuarded(
      () async {
        await controller().setKeepScreenOn(true);
        await controller().saveLocale(LocaleChoice.en);
        await controller().setLockZoom(true);
        await Future<void>.delayed(Duration.zero);
      },
      (e, _) => zoneErrors.add(e),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => seen.add(line),
      ),
    );

    FlutterError.onError = oldOnError;
    debugPrint = oldDebugPrint;
    expect(flutterErrors, isEmpty);
    expect(zoneErrors, isEmpty);
    expect(seen.where((l) => l.contains('texto-secreto')), isEmpty);
    expect(seen, isEmpty);
  });

  group('CA-017-02 / CA-017-04: bloquear zoom y la cola de guardados', () {
    Future<void> turn() => Future<void>.delayed(Duration.zero);

    test('CA-017-03: por defecto apagado; con el valor guardado, el estado '
        'sale de él', () async {
      expect(state().lockZoom, isFalse);
      final other = _ControlledSettings();
      await other.setLockZoom(true);
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(other),
          bootStateProvider.overrideWithValue(
            await readBootState(other, other),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(settingsProvider).lockZoom, isTrue);
    });

    test('CA-017-02: setLockZoom guarda y, solo entonces, cambia el estado '
        '(sin cambio optimista)', () async {
      final seen = <AppSettings>[];
      container.listen(settingsProvider, (_, next) => seen.add(next));
      repo.gates['lockZoom'] = Completer<void>();
      final pending = controller().setLockZoom(true);
      await turn();
      expect(repo.lockZoomWrites, [true]);
      expect(state().lockZoom, isFalse, reason: 'sin cambio optimista');
      expect(seen, isEmpty);
      repo.gates['lockZoom']!.complete();
      expect(await pending, SaveResult.saved);
      expect(state().lockZoom, isTrue);
      expect(seen, hasLength(1), reason: 'AppSettings == / hashCode');
      expect(await repo.lockZoom(), isTrue);
      expect(await controller().setLockZoom(false), SaveResult.saved);
      expect(state().lockZoom, isFalse);
    });

    test('AppSettings: lockZoom entra en ==, hashCode y copyWith', () {
      const a = AppSettings(
        locale: LocaleChoice.system,
        keepScreenOn: false,
        lockZoom: false,
      );
      final b = a.copyWith(lockZoom: true);
      expect(b.lockZoom, isTrue);
      expect(b.keepScreenOn, isFalse);
      expect(b, isNot(a));
      expect(b.hashCode, isNot(a.hashCode));
      expect(b.copyWith(lockZoom: false), a);
      expect(a.copyWith(keepScreenOn: true).lockZoom, isFalse);
    });

    test('CL-017-7: el mismo valor no escribe', () async {
      expect(await controller().setLockZoom(false), SaveResult.unchanged);
      expect(repo.lockZoomWrites, isEmpty);
    });

    test('CA-017-02: dos guardados de filas distintas que se solapan se '
        'escriben los dos, en orden, y ninguno pisa al otro', () async {
      repo.gates['keepScreenOn'] = Completer<void>();
      final first = controller().setKeepScreenOn(true);
      await turn();
      final second = controller().setLockZoom(true);
      await turn();
      expect(repo.lockZoomWrites, isEmpty, reason: 'espera al primero');
      expect(state().lockZoom, isFalse);
      repo.gates['keepScreenOn']!.complete();
      expect(await first, SaveResult.saved);
      expect(await second, SaveResult.saved);
      expect(repo.log, [
        'start:keepScreenOn',
        'end:keepScreenOn',
        'start:lockZoom',
        'end:lockZoom',
      ]);
      expect(await repo.keepScreenOn(), isTrue);
      expect(await repo.lockZoom(), isTrue);
      expect(state().keepScreenOn, isTrue);
      expect(state().lockZoom, isTrue);
    });

    test('CL-017-7: el segundo toque de la misma fila, mientras se guarda, '
        'es `unchanged` y no escribe', () async {
      repo.gates['lockZoom'] = Completer<void>();
      final first = controller().setLockZoom(true);
      await turn();
      expect(await controller().setLockZoom(false), SaveResult.unchanged);
      expect(await controller().setLockZoom(true), SaveResult.unchanged);
      repo.gates['lockZoom']!.complete();
      expect(await first, SaveResult.saved);
      expect(repo.lockZoomWrites, [true]);
      expect(state().lockZoom, isTrue);
    });

    test('CL-017-7: dos toques en la misma fila en el mismo microtask dan '
        'una escritura', () async {
      final a = controller().setLockZoom(true);
      final b = controller().setLockZoom(true);
      expect(await b, SaveResult.unchanged);
      expect(await a, SaveResult.saved);
      expect(repo.lockZoomWrites, [true]);
      final c = controller().setKeepScreenOn(true);
      final d = controller().setKeepScreenOn(true);
      expect(await d, SaveResult.unchanged);
      expect(await c, SaveResult.saved);
      expect(repo.keepScreenOnWrites, [true]);
    });

    test('CA-017-02: el fallo del primero no bloquea al segundo, y el estado '
        'solo trae el segundo', () async {
      repo.gates['keepScreenOn'] = Completer<void>();
      repo.errors['keepScreenOn'] = Exception('texto-secreto');
      final first = controller().setKeepScreenOn(true);
      await turn();
      final second = controller().setLockZoom(true);
      await turn();
      repo.gates['keepScreenOn']!.complete();
      expect(await first, SaveResult.failed);
      expect(await second, SaveResult.saved);
      expect(state().keepScreenOn, isFalse);
      expect(state().lockZoom, isTrue);
      expect(await repo.keepScreenOn(), isFalse);
    });

    test('CA-017-02: un `unchanged` no bloquea ni espera a la cola', () async {
      repo.gates['keepScreenOn'] = Completer<void>();
      final first = controller().setKeepScreenOn(true);
      await turn();
      // Otro ajuste con el mismo valor: vuelve ya, sin esperar al primero.
      expect(
        await controller()
            .setLockZoom(false)
            .timeout(const Duration(milliseconds: 200)),
        SaveResult.unchanged,
      );
      repo.gates['keepScreenOn']!.complete();
      expect(await first, SaveResult.saved);
      expect(await controller().setLockZoom(true), SaveResult.saved);
    });

    test(
      'CA-017-02: tras un fallo, reintentar la misma fila funciona',
      () async {
        repo.errors['lockZoom'] = Exception('x');
        expect(await controller().setLockZoom(true), SaveResult.failed);
        expect(state().lockZoom, isFalse);
        repo.errors.clear();
        expect(await controller().setLockZoom(true), SaveResult.saved);
        expect(state().lockZoom, isTrue);
      },
    );

    test('CA-017-02: una escritura que lanza de forma síncrona o un `Error` '
        '(no solo `Exception`) da `failed` y no bloquea la cola', () async {
      repo.syncThrow.add('lockZoom');
      expect(await controller().setLockZoom(true), SaveResult.failed);
      repo.syncThrow.clear();
      for (final e in <Object>[StateError('x'), TypeError(), 'texto']) {
        repo.errors['lockZoom'] = e;
        expect(await controller().setLockZoom(true), SaveResult.failed);
      }
      repo.errors.clear();
      repo.syncThrow.add('keepScreenOn');
      final a = controller().setKeepScreenOn(true);
      final b = controller().setLockZoom(true);
      expect(await a, SaveResult.failed);
      expect(await b, SaveResult.saved);
      expect(state().lockZoom, isTrue);
      expect(state().keepScreenOn, isFalse);
    });

    test('CA-017-02: concurrencia máxima 1 y orden FIFO entre ajustes e '
        'idioma', () async {
      repo.delay = const Duration(milliseconds: 5);
      final results = await Future.wait([
        controller().setKeepScreenOn(true),
        controller().setLockZoom(true),
        controller().saveLocale(LocaleChoice.en),
      ]);
      expect(results, everyElement(SaveResult.saved));
      expect(repo.maxActive, 1);
      expect(repo.log, [
        'start:keepScreenOn',
        'end:keepScreenOn',
        'start:lockZoom',
        'end:lockZoom',
        'start:locale',
        'end:locale',
      ]);
    });

    test('CA-017-02: con la primera colgada, la segunda espera sin escribir '
        'y al completarse se libera', () async {
      repo.gates['lockZoom'] = Completer<void>();
      final first = controller().setLockZoom(true);
      final second = controller().setKeepScreenOn(true);
      for (var i = 0; i < 5; i++) {
        await turn();
      }
      expect(repo.keepScreenOnWrites, isEmpty);
      var done = false;
      unawaited(second.then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse);
      repo.gates['lockZoom']!.complete();
      expect(await first, SaveResult.saved);
      expect(await second, SaveResult.saved);
      expect(repo.keepScreenOnWrites, [true]);
    });

    test('CA-017-02: varios fallos encadenados no dejan ningún error sin '
        'capturar (ni `FlutterError`, ni zona, ni `debugPrint`)', () async {
      final flutterErrors = <FlutterErrorDetails>[];
      final zoneErrors = <Object>[];
      final seen = <String>[];
      final oldOnError = FlutterError.onError;
      final oldDebugPrint = debugPrint;
      FlutterError.onError = flutterErrors.add;
      debugPrint = (String? message, {int? wrapWidth}) => seen.add('$message');
      repo.error = Exception('texto-secreto');
      repo.gates['keepScreenOn'] = Completer<void>();

      await runZonedGuarded(
        () async {
          final a = controller().setKeepScreenOn(true);
          final b = controller().setLockZoom(true);
          final c = controller().saveLocale(LocaleChoice.en);
          await turn();
          repo.gates['keepScreenOn']!.complete();
          expect(await Future.wait([a, b, c]), everyElement(SaveResult.failed));
          await Future<void>.delayed(Duration.zero);
        },
        (e, _) => zoneErrors.add(e),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => seen.add(line),
        ),
      );

      FlutterError.onError = oldOnError;
      debugPrint = oldDebugPrint;
      expect(flutterErrors, isEmpty);
      expect(zoneErrors, isEmpty);
      expect(seen, isEmpty);
    });

    test('CA-017-02: con Drift real, dos toques solapados guardan los dos '
        'valores y sobreviven a reabrir', () async {
      final dir = await Directory.systemTemp.createTemp('una_lock_zoom');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/una.sqlite');
      var db = openAppDatabaseFile(file);
      var drift = DriftTaskRepository(db);
      final c = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(drift),
          settingsRepositoryProvider.overrideWithValue(drift),
          bootStateProvider.overrideWithValue(
            await readBootState(drift, drift),
          ),
        ],
      );
      final settings = c.read(settingsProvider.notifier);
      final results = await Future.wait([
        settings.setKeepScreenOn(true),
        settings.setLockZoom(true),
        settings.saveLocale(LocaleChoice.en),
      ]);
      expect(results, everyElement(SaveResult.saved));
      expect(c.read(settingsProvider).keepScreenOn, isTrue);
      expect(c.read(settingsProvider).lockZoom, isTrue);
      c.dispose();
      await db.close();

      db = openAppDatabaseFile(file);
      addTearDown(db.close);
      drift = DriftTaskRepository(db);
      expect(await drift.keepScreenOn(), isTrue);
      expect(await drift.lockZoom(), isTrue);
      expect(await drift.locale(), LocaleChoice.en);
    });

    test('CA-017-04: el error de lockZoom no sale (`Exception` con texto '
        'secreto) ni cambia el estado', () async {
      repo.errors['lockZoom'] = Exception('texto-secreto');
      expect(await controller().setLockZoom(true), SaveResult.failed);
      expect(state().lockZoom, isFalse);
      expect(await repo.lockZoom(), isFalse);
    });
  });
}
