import 'dart:async';

import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';

/// Las cuatro respuestas del sistema al encender (CA-019-08b).
enum FakePermission {
  /// Notificaciones permitidas (o Android 12 o anterior): sin diálogo.
  granted,

  /// Hay que pedir el permiso, sale el diálogo y el usuario concede.
  dialogGranted,

  /// Hay que pedir el permiso, sale el diálogo y el usuario rechaza.
  dialogDenied,

  /// Rechazo sin mostrar el diálogo (rechazado antes sin poder preguntar, o
  /// notificaciones de la app o su canal apagados en el sistema).
  deniedImmediately,
}

typedef ConfigureCall = ({
  bool on,
  NotificationsPerDay perDay,
  LocaleChoice language,
});

/// [NotificationGateway] falso de los tests (spec 019): anota las llamadas,
/// responde según [FakePermission] y puede fallar o quedarse esperando.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway([FakePermission permission = FakePermission.granted])
    : _permission = permission,
      allowed = permission == FakePermission.granted;

  final FakePermission _permission;

  /// Lo que el sistema permite ahora: el test lo cambia para simular volver
  /// de los Ajustes del sistema (CA-019-09).
  bool allowed;

  /// Si `openSystemSettings` encuentra a dónde ir.
  bool openSettingsResult = true;

  /// Si no es nulo, `openSystemSettings` espera a que se complete (toques
  /// seguidos mientras abre, CA-019-08).
  Completer<void>? openSettingsGate;

  /// Si no es nulo, `configure` lo lanza (tras esperar [configureGate]).
  NotificationGatewayException? configureFailure;

  /// Si no es nulo, `configure` espera a que se complete (cola, 3 y enseguida 2).
  Completer<void>? configureGate;

  /// Si no es nulo, `canNotify` espera a que se complete (lectura en vuelo,
  /// CA-019-09).
  Completer<void>? canNotifyGate;

  /// Si no es nulo, `requestPermission` espera a que se complete (petición en
  /// curso, CA-019-09).
  Completer<void>? permissionGate;

  final List<ConfigureCall> configureCalls = [];
  final List<bool> foregroundCalls = [];
  int canNotifyCalls = 0;
  int requestPermissionCalls = 0;
  int cancelDeliveredCalls = 0;
  int openSystemSettingsCalls = 0;

  /// Olvida las llamadas hechas hasta ahora: las del arranque de la app
  /// (indicador «a la vista», quitar el aviso, reconciliar; T-019-12), para
  /// que un test de Ajustes cuente solo las suyas.
  void forgetCalls() {
    configureCalls.clear();
    foregroundCalls.clear();
    canNotifyCalls = 0;
    requestPermissionCalls = 0;
    cancelDeliveredCalls = 0;
    openSystemSettingsCalls = 0;
  }

  final StreamController<void> _open = StreamController<void>.broadcast();

  /// Simula que lo nativo acepta la orden de abrir la tarea actual.
  void emitOpenCurrentTask() => _open.add(null);

  @override
  Stream<void> get openCurrentTaskRequests => _open.stream;

  @override
  Future<bool> canNotify() async {
    canNotifyCalls++;
    final answer = allowed;
    await canNotifyGate?.future;
    return answer;
  }

  @override
  Future<PermissionResult> requestPermission() async {
    requestPermissionCalls++;
    await permissionGate?.future;
    switch (_permission) {
      case FakePermission.granted:
        return (granted: allowed, dialogShown: false);
      case FakePermission.dialogGranted:
        allowed = true;
        return (granted: true, dialogShown: true);
      case FakePermission.dialogDenied:
        return (granted: false, dialogShown: true);
      case FakePermission.deniedImmediately:
        return (granted: false, dialogShown: false);
    }
  }

  @override
  Future<void> configure({
    required bool on,
    required NotificationsPerDay perDay,
    required LocaleChoice language,
  }) async {
    configureCalls.add((on: on, perDay: perDay, language: language));
    await configureGate?.future;
    final failure = configureFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> cancelDelivered() async => cancelDeliveredCalls++;

  @override
  Future<void> setForeground(bool visible) async =>
      foregroundCalls.add(visible);

  @override
  Future<bool> openSystemSettings() async {
    openSystemSettingsCalls++;
    await openSettingsGate?.future;
    return openSettingsResult;
  }
}
