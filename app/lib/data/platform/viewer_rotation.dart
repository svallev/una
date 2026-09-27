import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Giro del visor en Android (CA-007-11). La parte nativa lee el acelerómetro,
/// porque el sensor del sistema de HyperOS no avisa hasta el siguiente toque,
/// y respeta el bloqueo de rotación:
/// - con la tarea actual con imagen a la vista ([watchLandscape]), avisa en
///   [landscape] al poner el móvil en horizontal, para abrir el visor;
/// - con el visor abierto ([follow]), fija la orientación. Las orientaciones
///   permitidas se piden además con `SystemChrome`.
abstract final class ViewerRotation {
  static const _channel = MethodChannel('una/screen');
  static final _landscape = StreamController<void>.broadcast();
  static var _listening = false;

  /// El móvil se ha puesto en horizontal (solo mientras se vigila).
  static Stream<void> get landscape {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'landscape') _landscape.add(null);
      });
    }
    return _landscape.stream;
  }

  static Future<void> watchLandscape(bool on) => _invoke('watchLandscape', on);

  static Future<void> follow(bool on) => _invoke('viewerRotation', on);

  static Future<void> _invoke(String method, bool on) async {
    // En la web de pruebas no hay canal.
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method, on);
    } on MissingPluginException {
      // Plataforma sin el canal (iOS aún, D17; tests): basta `SystemChrome`.
    } on PlatformException {
      // Sin el sensor, el visor queda como lo decida el sistema.
    }
  }
}
