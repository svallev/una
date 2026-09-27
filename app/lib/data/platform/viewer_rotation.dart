import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Giro del visor en Android (CA-007-11): mientras está abierto, la parte
/// nativa lee el acelerómetro y fija la orientación, porque el sensor del
/// sistema de HyperOS no avisa hasta el siguiente toque. Respeta el bloqueo de
/// rotación. Las orientaciones permitidas se piden además con `SystemChrome`.
abstract final class ViewerRotation {
  static const _channel = MethodChannel('una/screen');

  static Future<void> follow(bool on) async {
    // En la web de pruebas no hay canal.
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('viewerRotation', on);
    } on MissingPluginException {
      // Plataforma sin el canal (iOS aún, D17; tests): basta `SystemChrome`.
    } on PlatformException {
      // Sin el sensor, el visor queda como lo decida el sistema.
    }
  }
}
