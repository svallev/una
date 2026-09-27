import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Giro de la tarea actual con imagen (CA-007-11), la única pantalla que gira:
/// el resto de la app queda en vertical. En Android, la parte nativa lee el
/// acelerómetro y fija la orientación, porque el sensor del sistema de HyperOS
/// no avisa hasta el siguiente toque; respeta el bloqueo de rotación. Las
/// orientaciones permitidas se piden además con `SystemChrome`.
abstract final class ImageRotation {
  static const _channel = MethodChannel('una/screen');

  static Future<void> follow(bool on) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      if (on) ...[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ]);
    // En la web de pruebas no hay canal.
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('rotateWithImage', on);
    } on MissingPluginException {
      // Plataforma sin el canal (iOS aún, D17; tests): basta `SystemChrome`.
    } on PlatformException {
      // Sin el sensor, gira como lo decida el sistema.
    }
  }
}
