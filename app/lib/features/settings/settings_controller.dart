import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/locale_choice.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/ports/task_repository.dart';
import 'notifications_state.dart';

/// Los ajustes de la app que se ven en Ajustes (spec 015).
@immutable
class AppSettings {
  const AppSettings({
    required this.locale,
    required this.keepScreenOn,
    required this.lockZoom,
    required this.notificationsOn,
    required this.notificationsPerDay,
  });

  /// Idioma elegido (CA-015-06): "Como el sistema" por defecto.
  final LocaleChoice locale;

  /// "Pantalla siempre activa" (CA-015-04): apagada por defecto.
  final bool keepScreenOn;

  /// "Bloquear zoom" (CA-017-02): apagado por defecto.
  final bool lockZoom;

  /// "Notificaciones" (CA-019-05): apagadas por defecto.
  final bool notificationsOn;

  /// Notificaciones al día (CA-019-05): 1 por defecto; se conserva con el
  /// ajuste apagado.
  final NotificationsPerDay notificationsPerDay;

  AppSettings copyWith({
    LocaleChoice? locale,
    bool? keepScreenOn,
    bool? lockZoom,
    bool? notificationsOn,
    NotificationsPerDay? notificationsPerDay,
  }) => AppSettings(
    locale: locale ?? this.locale,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    lockZoom: lockZoom ?? this.lockZoom,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    notificationsPerDay: notificationsPerDay ?? this.notificationsPerDay,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.keepScreenOn == keepScreenOn &&
      other.lockZoom == lockZoom &&
      other.notificationsOn == notificationsOn &&
      other.notificationsPerDay == notificationsPerDay;

  @override
  int get hashCode => Object.hash(
    locale,
    keepScreenOn,
    lockZoom,
    notificationsOn,
    notificationsPerDay,
  );
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

  /// Solo al encender las notificaciones (CA-019-08): el sistema las bloquea
  /// (permiso rechazado, avisos de la app o su canal apagados). No se guardó
  /// ni se programó nada y la pantalla enseña el aviso de bloqueo, no el de
  /// error.
  blocked,
}

/// Resultado de encender o apagar las notificaciones: el [SaveResult] y si el
/// sistema **mostró su diálogo** de permiso (CA-019-07: solo entonces se
/// anuncia «Notificaciones activadas.»).
typedef NotificationsOnResult = (SaveResult, {bool dialogShown});

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

  /// Cantidad pedida más reciente que aún no se ha aplicado (CA-019-03: dos
  /// opciones seguidas, gana la última). `null` si no hay ninguna en vuelo.
  NotificationsPerDay? _perDayWanted;

  /// ¿Hay un trabajo aplicando cantidades? Los toques que llegan entonces solo
  /// actualizan [_perDayWanted].
  bool _perDayRunning = false;

  @override
  AppSettings build() {
    final boot = ref.read(bootStateProvider);
    return AppSettings(
      locale: boot.locale,
      keepScreenOn: boot.keepScreenOn,
      lockZoom: boot.lockZoom,
      notificationsOn: boot.notificationsOn,
      notificationsPerDay: boot.notificationsPerDay,
    );
  }

  /// Guarda el idioma **sin cambiar el estado** (CA-015-08: guardar primero;
  /// el idioma se aplica después, con [applyLocale]). El mismo idioma no
  /// escribe.
  ///
  /// Con las notificaciones encendidas, avisa también a lo nativo del idioma
  /// nuevo, como mejor esfuerzo (CA-019-21).
  Future<SaveResult> saveLocale(LocaleChoice choice) => _save(
    setting: _Setting.locale,
    unchanged: choice == state.locale,
    write: (repo) async {
      await repo.setLocale(choice);
      await _syncLanguage(choice);
    },
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
  }) {
    if (unchanged || _inFlight.contains(setting)) {
      return Future.value(SaveResult.unchanged);
    }
    _inFlight.add(setting);
    return _enqueue(
      () => write(ref.read(settingsRepositoryProvider)),
      release: () => _inFlight.remove(setting),
    );
  }

  /// Mete [body] en la cola de guardados (el relevo, sin código entre medias,
  /// y el trabajo dentro del `try`). [release] se llama antes de liberar la
  /// cola. Nunca lanza: un fallo es `failed`, sin texto.
  Future<SaveResult> _enqueue(
    Future<void> Function() body, {
    void Function()? release,
  }) async {
    final done = Completer<void>();
    final prev = _tail;
    _tail = done.future;
    try {
      await prev;
      await body();
      return SaveResult.saved;
    } on Object {
      // No se relanza ni se registra (como `UndoController`): el texto del
      // error puede llevar datos del usuario (MASVS-STORAGE) y no se muestra.
      return SaveResult.failed;
    } finally {
      release?.call();
      done.complete();
    }
  }

  /// Enciende o apaga las notificaciones (spec 019, CA-019-02, 07, 08, 08b).
  ///
  /// **Encender:** primero lo del sistema, **fuera de la cola** y protegido solo
  /// por la guardia del propio ajuste (el diálogo puede quedarse abierto y los
  /// demás ajustes no esperan): `canNotify`; si no puede, `requestPermission`
  /// (la app no sabe si el sistema aún preguntará, así que lo averigua pidiendo)
  /// y, si lo rechaza, [SaveResult.blocked] sin guardar nada. Después, **dentro
  /// de la cola**: guardar y `configure`; si `configure` falla, el valor
  /// guardado vuelve al anterior (todo o nada) y el resultado es `failed`.
  /// **Apagar:** guardar y `configure(off)`, con la misma marcha atrás.
  ///
  /// El estado cambia **solo al terminar** (sin cambio optimista). Un segundo
  /// toque mientras la fila trabaja se ignora (`unchanged`). Con el ajuste
  /// guardado encendido y el sistema bloqueando (CA-019-09), tocar el
  /// interruptor sigue el flujo de encender.
  Future<NotificationsOnResult> setNotificationsOn(bool value) async {
    if (!value && !state.notificationsOn) {
      return (SaveResult.unchanged, dialogShown: false);
    }
    if (!_inFlight.add(_Setting.notificationsOn)) {
      return (SaveResult.unchanged, dialogShown: false);
    }
    try {
      var dialogShown = false;
      if (value) {
        final permission = await _ensurePermission();
        if (permission.result != null) {
          return (permission.result!, dialogShown: permission.dialogShown);
        }
        dialogShown = permission.dialogShown;
      }
      final result = await _enqueue(() async {
        final repo = ref.read(settingsRepositoryProvider);
        final gateway = ref.read(notificationGatewayProvider);
        final previous = state.notificationsOn;
        await repo.setNotificationsOn(value);
        try {
          await gateway.configure(
            on: value,
            perDay: state.notificationsPerDay,
            language: state.locale,
          );
        } on Object {
          await _undo(() => repo.setNotificationsOn(previous));
          rethrow;
        }
        // Dentro de la cola: el siguiente guardado ya ve el estado nuevo.
        if (ref.mounted) state = state.copyWith(notificationsOn: value);
      });
      return (result, dialogShown: dialogShown);
    } finally {
      _inFlight.remove(_Setting.notificationsOn);
    }
  }

  /// Pregunta al sistema y, si hace falta, pide el permiso (CA-019-07). Vuelve
  /// `result == null` si se puede seguir; si no, `blocked` o `failed`.
  Future<({SaveResult? result, bool dialogShown})> _ensurePermission() async {
    final gateway = ref.read(notificationGatewayProvider);
    final system = ref.read(systemAllowsNotificationsProvider.notifier);
    var dialogShown = false;
    try {
      final allowed = await gateway.canNotify();
      system.setAllowed(allowed);
      if (allowed) return (result: null, dialogShown: false);
      bool? granted;
      system.beginRequest();
      try {
        final reply = await gateway.requestPermission();
        granted = reply.granted;
        dialogShown = reply.dialogShown;
      } finally {
        system.endRequest(allowed: granted);
      }
      if (!granted) {
        return (result: SaveResult.blocked, dialogShown: dialogShown);
      }
      return (result: null, dialogShown: dialogShown);
    } on Object {
      // Sin texto del error (CA-019-23); el canal no debería lanzar.
      return (result: SaveResult.failed, dialogShown: dialogShown);
    }
  }

  /// Cambia cuántas notificaciones al día (CA-019-03, 12) por **su propia
  /// vía**: no usa la guardia que ignora el segundo toque. Mientras se aplica
  /// una opción, la siguiente solo anota lo pedido y **gana la última**; las
  /// aplica una tras otra, dentro de la cola. Devuelve el resultado de la
  /// última aplicada; el toque que quedó anotado devuelve `unchanged` (no hay
  /// aviso propio: lo da la que lo aplica). Con el ajuste apagado solo guarda
  /// la cantidad (se conserva, CA-019-05).
  Future<SaveResult> setNotificationsPerDay(NotificationsPerDay value) async {
    if (value == (_perDayWanted ?? state.notificationsPerDay)) {
      return SaveResult.unchanged;
    }
    _perDayWanted = value;
    if (_perDayRunning) return SaveResult.unchanged;
    _perDayRunning = true;
    var result = SaveResult.unchanged;
    try {
      while (ref.mounted) {
        final target = _perDayWanted;
        if (target == null || target == state.notificationsPerDay) break;
        result = await _applyPerDay(target);
        if (_perDayWanted == target) break; // Nadie pidió otra cosa.
      }
    } finally {
      _perDayWanted = null;
      _perDayRunning = false;
    }
    return result;
  }

  Future<SaveResult> _applyPerDay(NotificationsPerDay target) =>
      _enqueue(() async {
        final repo = ref.read(settingsRepositoryProvider);
        final gateway = ref.read(notificationGatewayProvider);
        final previous = state.notificationsPerDay;
        final on = state.notificationsOn;
        await repo.setNotificationsPerDay(target);
        if (on) {
          try {
            await gateway.configure(
              on: true,
              perDay: target,
              language: state.locale,
            );
          } on Object {
            await _undo(() => repo.setNotificationsPerDay(previous));
            rethrow;
          }
        }
        if (ref.mounted) state = state.copyWith(notificationsPerDay: target);
      });

  /// Avisa a lo nativo del idioma recién guardado (CA-019-21): mejor esfuerzo,
  /// un fallo no deshace el idioma (el arranque lo corrige). Con las
  /// notificaciones apagadas no hay nada que avisar.
  Future<void> _syncLanguage(LocaleChoice choice) async {
    if (!ref.mounted || !state.notificationsOn) return;
    try {
      await ref
          .read(notificationGatewayProvider)
          .configure(
            on: true,
            perDay: state.notificationsPerDay,
            language: choice,
          );
    } on Object {
      // Sin registrar nada: el siguiente arranque reconcilia.
    }
  }

  /// La marcha atrás de un guardado: si también falla, la BD manda y el
  /// siguiente arranque reprograma (CL-019-12).
  Future<void> _undo(Future<void> Function() undo) async {
    try {
      await undo();
    } on Object {
      // Sin registrar nada (CA-019-23).
    }
  }
}

/// Los ajustes que se guardan (uno por fila de Ajustes y el idioma).
enum _Setting { locale, keepScreenOn, lockZoom, notificationsOn }
