import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio de ajustes controlable: cada escritura espera a su compuerta o
/// falla con un texto que no debe escaparse.
class _ControlledSettings extends InMemoryTaskRepository {
  final locales = <LocaleChoice>[];
  final keepScreenOnWrites = <bool>[];
  Completer<void>? gate;
  Object? error;

  Future<void> _maybeWait() async {
    final g = gate;
    if (g != null) await g.future;
    if (error case final e?) throw e;
  }

  @override
  Future<void> setLocale(LocaleChoice choice) async {
    locales.add(choice);
    await _maybeWait();
    await super.setLocale(choice);
  }

  @override
  Future<void> setKeepScreenOn(bool value) async {
    keepScreenOnWrites.add(value);
    await _maybeWait();
    await super.setKeepScreenOn(value);
  }
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

  test('CA-015-25: dos guardados que se solapan se serializan: el segundo '
      'toque se ignora y queda lo último guardado', () async {
    repo.gate = Completer<void>();
    final first = controller().setKeepScreenOn(true);
    await Future<void>.delayed(Duration.zero);
    // Mientras el primero está en curso, ni otro interruptor ni el idioma
    // escriben.
    expect(await controller().setKeepScreenOn(false), SaveResult.unchanged);
    expect(
      await controller().saveLocale(LocaleChoice.en),
      SaveResult.unchanged,
    );
    repo.gate!.complete();
    expect(await first, SaveResult.saved);
    expect(repo.keepScreenOnWrites, [true]);
    expect(repo.locales, isEmpty);
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
}
