import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Lo que permite el sistema ahora mismo (spec 019, CA-019-09, plan §4):
/// `true` = puede notificar; `false` = bloqueadas (permiso rechazado, avisos
/// de la app o su canal apagados); `null` = todavía no se ha leído (la pantalla
/// se ve con el valor guardado, sin aviso).
///
/// **Un solo dueño de los anuncios:** quien relee ([refresh]) recibe si esa
/// lectura es la transición «bloqueadas → permitidas» que merece el anuncio
/// «Notificaciones permitidas…» (CA-019-08), y nunca lo es mientras hay una
/// petición de permiso en curso: de lo que ocurre entonces se encarga el
/// flujo de encender (`SettingsController.setNotificationsOn`).
///
/// No es `autoDispose` ni se lee al arrancar: se pide al abrir Ajustes y al
/// volver a primer plano con Ajustes abierto (P2: nada antes del primer
/// fotograma).
final systemAllowsNotificationsProvider =
    NotifierProvider<SystemAllowsNotifications, bool?>(
      SystemAllowsNotifications.new,
    );

class SystemAllowsNotifications extends Notifier<bool?> {
  /// Peticiones de permiso en curso (el diálogo del sistema abierto).
  int _requests = 0;

  /// Sube al empezar y al acabar cada petición: una lectura que empezó antes
  /// y termina después trae un valor viejo y se descarta.
  int _epoch = 0;

  @override
  bool? build() => null;

  /// ¿Hay una petición de permiso en curso? (Mientras la hay, el estado se
  /// actualiza pero no se anuncia nada.)
  bool get requestInFlight => _requests > 0;

  /// Lee lo que permite el sistema. Devuelve `true` solo si es la transición
  /// bloqueadas → permitidas **y** no hay petición en curso: es lo que hace
  /// anunciar «Notificaciones permitidas…». La primera lectura (estado
  /// desconocido) y las repetidas no lo son. Nunca lanza: un fallo vale como
  /// bloqueadas (CA-019-23: sin texto del error).
  Future<bool> refresh() async {
    final gateway = ref.read(notificationGatewayProvider);
    final epoch = _epoch;
    bool allowed;
    try {
      allowed = await gateway.canNotify();
    } on Object {
      allowed = false;
    }
    if (!ref.mounted || epoch != _epoch) return false;
    final before = state;
    state = allowed;
    return before == false && allowed && !requestInFlight;
  }

  /// Olvida lo leído (al salir de Ajustes): la siguiente apertura vuelve a
  /// empezar «sin leer», así que su primera lectura no anuncia nada aunque el
  /// valor anterior fuera «bloqueadas» (CA-019-09).
  void forget() {
    if (!ref.mounted) return;
    state = null;
  }

  /// Anota lo que sabe el flujo de encender (sin anunciar): la lectura del
  /// sistema que acaba de hacer o la respuesta del diálogo.
  void setAllowed(bool allowed) {
    if (!ref.mounted) return;
    state = allowed;
  }

  /// Empieza una petición de permiso (el diálogo del sistema).
  void beginRequest() {
    _requests++;
    _epoch++;
  }

  /// Acaba una petición de permiso: [allowed] es lo que respondió el sistema
  /// (se anota sin anunciar); `null` si la petición falló y no se sabe.
  void endRequest({bool? allowed}) {
    if (_requests > 0) _requests--;
    _epoch++;
    if (allowed != null) setAllowed(allowed);
  }
}
