import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/locale_choice.dart';
import '../../domain/ports/task_repository.dart';

/// Los ajustes de la app que se ven en Ajustes (spec 015).
@immutable
class AppSettings {
  const AppSettings({
    required this.locale,
    required this.keepScreenOn,
    required this.lockZoom,
  });

  /// Idioma elegido (CA-015-06): "Como el sistema" por defecto.
  final LocaleChoice locale;

  /// "Pantalla siempre activa" (CA-015-04): apagada por defecto.
  final bool keepScreenOn;

  /// "Bloquear zoom" (CA-017-02): apagado por defecto.
  final bool lockZoom;

  AppSettings copyWith({
    LocaleChoice? locale,
    bool? keepScreenOn,
    bool? lockZoom,
  }) => AppSettings(
    locale: locale ?? this.locale,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    lockZoom: lockZoom ?? this.lockZoom,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.keepScreenOn == keepScreenOn &&
      other.lockZoom == lockZoom;

  @override
  int get hashCode => Object.hash(locale, keepScreenOn, lockZoom);
}

/// Resultado de guardar un ajuste: lo que la pantalla dibuja (aviso o no).
enum SaveResult {
  /// Se guardó.
  saved,

  /// No había nada que guardar (el mismo valor) o hay otro guardado en curso
  /// y este toque se ignora (CA-015-25). No es un error: no hay aviso.
  unchanged,

  /// No se pudo guardar: el ajuste no cambia y la pantalla avisa.
  failed,
}

/// Los ajustes de Ajustes, sin `autoDispose`: viven lo que la app (spec 015,
/// plan §1). Ninguna lógica de UI: los avisos los dibuja la pantalla.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  /// Ajustes con un guardado en curso o en cola (CA-017-04, CL-017-7): un
  /// segundo toque en el **mismo** ajuste se ignora; el de otro espera su turno.
  final Set<_Setting> _inFlight = {};

  /// Final de la cola de guardados: cada uno espera al anterior, de cualquier
  /// ajuste. Solo se completa con `complete()`, nunca con un error (plan §4).
  Future<void> _tail = Future<void>.value();

  @override
  AppSettings build() {
    final boot = ref.read(bootStateProvider);
    return AppSettings(
      locale: boot.locale,
      keepScreenOn: boot.keepScreenOn,
      lockZoom: boot.lockZoom,
    );
  }

  /// Guarda el idioma **sin cambiar el estado** (CA-015-08: guardar primero;
  /// el idioma se aplica después, con [applyLocale]). El mismo idioma no
  /// escribe.
  Future<SaveResult> saveLocale(LocaleChoice choice) => _save(
    setting: _Setting.locale,
    unchanged: choice == state.locale,
    write: (repo) => repo.setLocale(choice),
  );

  /// Aplica un idioma ya guardado: cambia el estado y con él la app, sin
  /// reiniciarla (CA-015-08, paso 3).
  void applyLocale(LocaleChoice choice) {
    if (!ref.mounted) return;
    state = state.copyWith(locale: choice);
  }

  /// Guarda "Pantalla siempre activa" y, **solo si se guardó**, cambia el
  /// estado: el interruptor no se mueve antes (CA-015-03, CA-015-25).
  Future<SaveResult> setKeepScreenOn(bool value) async {
    final result = await _save(
      setting: _Setting.keepScreenOn,
      unchanged: value == state.keepScreenOn,
      write: (repo) => repo.setKeepScreenOn(value),
    );
    if (result == SaveResult.saved && ref.mounted) {
      state = state.copyWith(keepScreenOn: value);
    }
    return result;
  }

  /// Guarda "Bloquear zoom" y, **solo si se guardó**, cambia el estado (sin
  /// cambio optimista; CA-017-02).
  Future<SaveResult> setLockZoom(bool value) async {
    final result = await _save(
      setting: _Setting.lockZoom,
      unchanged: value == state.lockZoom,
      write: (repo) => repo.setLockZoom(value),
    );
    if (result == SaveResult.saved && ref.mounted) {
      state = state.copyWith(lockZoom: value);
    }
    return result;
  }

  /// Orden fijo (plan §4): (a) `unchanged` o ajuste ya en curso: no se toca
  /// nada; (b) se anota el ajuste **antes de cualquier `await`**; (c) el
  /// relevo de la cola, sin código entre medias; (d) esperar al anterior y
  /// escribir dentro del `try`; (e) el `finally` libera ajuste y cola.
  Future<SaveResult> _save({
    required _Setting setting,
    required bool unchanged,
    required Future<void> Function(SettingsRepository repo) write,
  }) async {
    if (unchanged || _inFlight.contains(setting)) return SaveResult.unchanged;
    _inFlight.add(setting);
    final done = Completer<void>();
    final prev = _tail;
    _tail = done.future;
    try {
      await prev;
      await write(ref.read(settingsRepositoryProvider));
      return SaveResult.saved;
    } on Object {
      // No se relanza ni se registra (como `UndoController`): el texto del
      // error puede llevar datos del usuario (MASVS-STORAGE) y no se muestra.
      return SaveResult.failed;
    } finally {
      _inFlight.remove(setting);
      done.complete();
    }
  }
}

/// Los ajustes que se guardan (uno por fila de Ajustes y el idioma).
enum _Setting { locale, keepScreenOn, lockZoom }
