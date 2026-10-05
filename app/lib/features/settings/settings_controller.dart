import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/locale_choice.dart';
import '../../domain/ports/task_repository.dart';

/// Los ajustes de la app que se ven en Ajustes (spec 015).
@immutable
class AppSettings {
  const AppSettings({required this.locale, required this.keepScreenOn});

  /// Idioma elegido (CA-015-06): "Como el sistema" por defecto.
  final LocaleChoice locale;

  /// "Pantalla siempre activa" (CA-015-04): apagada por defecto.
  final bool keepScreenOn;

  AppSettings copyWith({LocaleChoice? locale, bool? keepScreenOn}) =>
      AppSettings(
        locale: locale ?? this.locale,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.keepScreenOn == keepScreenOn;

  @override
  int get hashCode => Object.hash(locale, keepScreenOn);
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
  /// Guardados **en serie**: mientras uno está en curso, un segundo toque se
  /// ignora, así que lo último que se ve es lo último que se guardó
  /// (CA-015-25). Un solo indicador para los dos ajustes.
  bool _saving = false;

  @override
  AppSettings build() {
    final boot = ref.read(bootStateProvider);
    return AppSettings(locale: boot.locale, keepScreenOn: boot.keepScreenOn);
  }

  /// Guarda el idioma **sin cambiar el estado** (CA-015-08: guardar primero;
  /// el idioma se aplica después, con [applyLocale]). El mismo idioma no
  /// escribe.
  Future<SaveResult> saveLocale(LocaleChoice choice) => _save(
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
      unchanged: value == state.keepScreenOn,
      write: (repo) => repo.setKeepScreenOn(value),
    );
    if (result == SaveResult.saved && ref.mounted) {
      state = state.copyWith(keepScreenOn: value);
    }
    return result;
  }

  Future<SaveResult> _save({
    required bool unchanged,
    required Future<void> Function(SettingsRepository repo) write,
  }) async {
    if (_saving || unchanged) return SaveResult.unchanged;
    _saving = true;
    try {
      await write(ref.read(settingsRepositoryProvider));
      return SaveResult.saved;
    } on Object {
      // No se relanza ni se registra (como `UndoController`): el texto del
      // error puede llevar datos del usuario (MASVS-STORAGE) y no se muestra.
      return SaveResult.failed;
    } finally {
      _saving = false;
    }
  }
}
