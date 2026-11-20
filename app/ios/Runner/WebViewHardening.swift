import Flutter
import UIKit
import WebKit

/// Canal `una/webview` (contrato §3; espejo de `WebViewHardening.kt`; spec 009, ADR-0017, spec 021
/// CA-021-08 y spec 028 CA-028-19): la parte del endurecimiento de la WebView de la tarea web que no
/// da la API de `webview_flutter`. Trabaja con la `WKWebView` del paquete, que se busca por su
/// identificador (`WebKitWebViewController.webViewIdentifier`, con
/// `FWFWebViewFlutterWKWebViewExternalAPI`, en `AppDelegate`).
///
/// - `harden`: sin ventanas nuevas, aviso de sitios fraudulentos (el equivalente de Safe Browsing),
///   la página siempre en claro (la vista en `.light`: la página ve `prefers-color-scheme: light`)
///   y, fuera de depuración, sin inspección desde Safari. Lee todo de vuelta y devuelve si quedó.
/// - `state`: las mismas claves que en Android, leídas de la vista; las que no tienen equivalente en
///   WebKit valen `true` (contrato §3).
/// - `destroy`: deja de cargar y vacía la página tras el fallo de su proceso (ADR-0017); la vista la
///   libera el paquete al desmontarse.
/// - `clearData`: cookies, almacenamiento web y caché de todas las WebView (CA-009-13), sin
///   necesitar una vista viva.
///
/// **No** se toca el delegado de navegación del paquete: el fallo del proceso de la página ya le
/// llega (`webViewWebContentProcessDidTerminate`) y lo da a Dart como el error
/// `webContentProcessTerminated`, así que aquí no hay envoltorio ni aviso `renderProcessGone`.
/// Nunca envía ni registra direcciones ni contenido de páginas (CL-009-9).
final class WebViewHardening {
  /// En la app, la vista del paquete con ese identificador (o `nil`).
  private let lookup: (Int64) -> WKWebView?
  private let dataStore: () -> WKWebsiteDataStore
  /// Si se deja la inspección como está (solo en depuración, como `isDebuggable` en Android).
  private let inspectionAllowed: Bool

  #if DEBUG
    static let isDebugBuild = true
  #else
    static let isDebugBuild = false
  #endif

  init(
    lookup: @escaping (Int64) -> WKWebView? = { _ in nil },
    dataStore: @escaping () -> WKWebsiteDataStore = { .default() },
    inspectionAllowed: Bool = WebViewHardening.isDebugBuild
  ) {
    self.lookup = lookup
    self.dataStore = dataStore
    self.inspectionAllowed = inspectionAllowed
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "harden":
      guard let view = webView(call) else { return result(false) }
      result(harden(view))
    case "state":
      guard let view = webView(call) else { return result(nil) }
      result(state(view))
    case "destroy":
      if let view = webView(call) {
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
      }
      result(nil)
    case "clearData":
      clearData(result)
    case "debugKillContentProcess":
      #if DEBUG
        debugKillContentProcess(call, result)
      #else
        result(FlutterMethodNotImplemented)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// El `id` es un entero (contrato §0.3); un booleano, un texto o nada no valen.
  private func webView(_ call: FlutterMethodCall) -> WKWebView? {
    guard let args = call.arguments as? [String: Any],
      let id = args["id"] as? NSNumber, CFGetTypeID(id) != CFBooleanGetTypeID()
    else { return nil }
    return lookup(id.int64Value)
  }

  private func harden(_ view: WKWebView) -> Bool {
    let prefs = view.configuration.preferences
    prefs.javaScriptCanOpenWindowsAutomatically = false
    prefs.isFraudulentWebsiteWarningEnabled = true
    // CA-021-08: aunque el sistema esté en oscuro, la página se ve en su versión clara.
    view.overrideUserInterfaceStyle = .light
    // Antes de iOS 16.4 no existe el ajuste: una app que no es de depuración no se puede inspeccionar.
    if !inspectionAllowed, #available(iOS 16.4, *) {
      view.isInspectable = false
      if view.isInspectable { return false }
    }
    return state(view).values.allSatisfy { $0 }
  }

  /// Todo `true` si la vista está como la deja `harden`. Equivalencias (contrato §3):
  /// - `noFileAccess`: WebKit solo lee archivos con `loadFileURL`, que la app nunca usa; se comprueba
  ///   que la vista no muestra un archivo local.
  /// - `noContentAccess` (`content://`) y `noFormData` (WebKit no guarda formularios): sin
  ///   equivalente, `true`.
  /// - `noMixedContent`: WebKit bloquea el contenido mixto activo y, el pasivo, lo pasa a `https`
  ///   (comprobado en `webview_hardening_test`); no hay ajuste que leer, `true`.
  /// - `wrapped`: sin envoltorio en iOS (el paquete ya recibe el fallo del proceso), `true`.
  private func state(_ view: WKWebView) -> [String: Bool] {
    let prefs = view.configuration.preferences
    return [
      "noFileAccess": view.url?.isFileURL != true,
      "noContentAccess": true,
      "noFormData": true,
      "noMixedContent": true,
      "safeBrowsing": prefs.isFraudulentWebsiteWarningEnabled,
      "noMultipleWindows": !prefs.javaScriptCanOpenWindowsAutomatically,
      "noDarkening": view.overrideUserInterfaceStyle == .light,
      "wrapped": true,
    ]
  }

  /// Borra lo que haya dejado cualquier página (cookies, almacenamiento web, caché…) del almacén
  /// que usan las WebView del paquete. Responde `true` cuando WebKit confirma el borrado.
  private func clearData(_ result: @escaping FlutterResult) {
    dataStore().removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
    ) {
      DispatchQueue.main.async { result(true) }
    }
  }

  #if DEBUG
    /// Solo para los tests de integración (ADR-0017; en Android, `chrome://crash`): termina el
    /// proceso de la página con la llamada de pruebas de WebKit. Nunca entra en Profile ni Release.
    private func debugKillContentProcess(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
      let selector = NSSelectorFromString("_killWebContentProcess")
      if let view = webView(call), view.responds(to: selector) {
        view.perform(selector)
      }
      result(nil)
    }
  #endif
}
