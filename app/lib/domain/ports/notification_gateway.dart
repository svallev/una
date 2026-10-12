import '../entities/locale_choice.dart';
import '../entities/notification_settings.dart';

/// Lo que contesta el sistema al pedir el permiso de notificaciones
/// (CA-019-07, 08b):
/// - `granted`: se puede notificar (permiso concedido y canal no apagado);
/// - `dialogShown`: la actividad perdió el foco entre la petición y la
///   respuesta, es decir, el sistema **mostró su diálogo** (P-019-14). Solo
///   decide si se anuncia «Notificaciones activadas.» (CA-019-07).
typedef PermissionResult = ({bool granted, bool dialogShown});

/// Fallo del canal de notificaciones. **No lleva el texto del error** de la
/// plataforma ni nada de la tarea (CA-019-23): quien lo recibe solo sabe que
/// falló y, con [unsupported], que esta plataforma no tiene canal (web, iOS).
class NotificationGatewayException implements Exception {
  const NotificationGatewayException({this.unsupported = false});

  /// No hay lado nativo (`MissingPluginException`); no es un fallo puntual.
  final bool unsupported;

  @override
  String toString() =>
      'NotificationGatewayException(unsupported: $unsupported)';
}

/// Puerto de las notificaciones de la tarea actual (spec 019, plan §3.5): el
/// canal `una/notifications` con lo nativo, que programa las alarmas, lee la
/// tarea y muestra el aviso con la app cerrada. Dart solo decide y pide.
///
/// Ningún método recibe ni devuelve texto de tareas (CA-019-23).
abstract interface class NotificationGateway {
  /// ¿Puede la app notificar ahora? Permiso concedido (Android 13+), avisos
  /// de la app no apagados y canal no apagado. No crea el canal ni pide nada
  /// (CA-019-09). Sin canal o con un fallo: `false`.
  Future<bool> canNotify();

  /// Pide el permiso (solo al encender el interruptor, CA-019-07). En Android
  /// 12 o anterior, o ya concedido, no hay diálogo: vuelve el estado actual.
  /// Sin canal o con un fallo: `(granted: false, dialogShown: false)`.
  Future<PermissionResult> requestPermission();

  /// Guarda la copia derivada y arma la próxima hora, o cancela si `on` es
  /// falso (CA-019-02). Lanza [NotificationGatewayException] si falla
  /// cualquier paso: quien llama deshace lo guardado en Dart.
  Future<void> configure({
    required bool on,
    required NotificationsPerDay perDay,
    required LocaleChoice language,
  });

  /// Quita la notificación de la bandeja (CA-019-19b). Mejor esfuerzo: nunca
  /// lanza.
  Future<void> cancelDelivered();

  /// Dice a lo nativo si la app está a la vista (CA-019-19a). Mejor esfuerzo:
  /// nunca lanza.
  Future<void> setForeground(bool visible);

  /// Abre los ajustes de notificaciones de esta app en el sistema
  /// (CA-019-08). `false` si no hay a dónde ir.
  Future<bool> openSystemSettings();

  /// Cada vez que el usuario toca la notificación con la app viva y lo nativo
  /// acepta la orden (acción fija y `nonce` vigente, CA-019-20). Sin datos.
  Stream<void> get openCurrentTaskRequests;
}
