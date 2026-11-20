import Flutter

/// Canales de plataforma de la app (los mismos seis que en Android, spec 028 y contrato §0).
///
/// Esqueleto de la T-028-05: cada canal existe y responde `FlutterMethodNotImplemented` hasta que
/// la tarea de su fase le ponga el manejador real (I3 a I5). Dart ya sabe tratar «no implementado»
/// como «no disponible» (`MissingPluginException`), así que un canal vacío nunca rompe la app.
enum UnaChannels {
  /// Nombres de los canales, iguales a los de Dart y a los de Kotlin.
  static let names = [
    "una/images",
    "una/webview",
    "una/notifications",
    "una/screen",
    "una/links",
    "una/a11y",
  ]

  /// Crea los seis canales sobre `messenger`. Quien llama conserva el resultado mientras viva el motor.
  @discardableResult
  static func register(messenger: FlutterBinaryMessenger) -> [FlutterMethodChannel] {
    return names.map { name in
      let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
      channel.setMethodCallHandler { _, result in
        result(FlutterMethodNotImplemented)
      }
      return channel
    }
  }
}
