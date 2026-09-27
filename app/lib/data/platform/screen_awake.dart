import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Evita que la pantalla se apague por inactividad (CA-007-12). En Android,
/// `FLAG_KEEP_SCREEN_ON` de la ventana: sin permisos (`WAKE_LOCK` no hace
/// falta) y se quita solo al salir de la app.
abstract interface class ScreenAwake {
  Future<void> keepOn(bool on);
}

class ChannelScreenAwake implements ScreenAwake {
  const ChannelScreenAwake();

  static const _channel = MethodChannel('una/screen');

  @override
  Future<void> keepOn(bool on) async {
    // En la web de pruebas no hay canal.
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } on MissingPluginException {
      // Plataforma sin el canal (iOS aún, D17; tests): sin efecto.
    } on PlatformException {
      // Solo es comodidad: sin registrar nada.
    }
  }
}
