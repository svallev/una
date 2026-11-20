import Flutter

/// Canales de plataforma de la app (los mismos seis que en Android, spec 028 y contrato §0).
///
/// Cada canal responde `FlutterMethodNotImplemented` hasta que la tarea de su fase le ponga el
/// manejador real (`una/links` y `una/a11y` en T-028-09, `una/screen` en T-028-10, `una/images` en
/// T-028-13 y 14; `una/webview` y `una/notifications`, en I5 e I6). Dart ya sabe tratar
/// «no implementado» como «no disponible» (`MissingPluginException`), así que un canal vacío nunca
/// rompe la app.
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
  /// Los manejadores de los canales ya implementados se pueden sustituir (los tests inyectan los suyos).
  @discardableResult
  static func register(
    messenger: FlutterBinaryMessenger,
    links: Links = Links(),
    a11y: A11y = A11y(),
    screen: Screen = Screen(),
    images: Images = Images(),
    webView: WebViewHardening = WebViewHardening()
  ) -> [FlutterMethodChannel] {
    return names.map { name in
      let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
      switch name {
      case "una/links":
        channel.setMethodCallHandler { call, result in links.handle(call, result: result) }
      case "una/a11y":
        channel.setMethodCallHandler { call, result in a11y.handle(call, result: result) }
      case "una/screen":
        channel.setMethodCallHandler { call, result in screen.handle(call, result: result) }
      case "una/images":
        channel.setMethodCallHandler { call, result in images.handle(call, result: result) }
      case "una/webview":
        // Los avisos de lo nativo (`mainFrameRequest`, `downloadBlocked`) salen por el mismo canal.
        webView.send = { [weak channel] method, arguments in
          channel?.invokeMethod(method, arguments: arguments)
        }
        channel.setMethodCallHandler { call, result in webView.handle(call, result: result) }
      default:
        channel.setMethodCallHandler { _, result in result(FlutterMethodNotImplemented) }
      }
      return channel
    }
  }
}
