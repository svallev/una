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
/// **No** se sustituye el delegado de navegación del paquete: `harden` lo envuelve con un
/// [NavigationWatcher] que le reenvía todo (como `RenderGoneClient` en Android) y solo añade los
/// avisos `mainFrameRequest` (antes de cada petición del marco principal, con si es una redirección
/// del servidor, T-009-12) y `downloadBlocked` (una respuesta del marco principal que no es una
/// página, CL-009-4). El fallo del proceso de la página ya le llega al paquete
/// (`webViewWebContentProcessDidTerminate`) y lo da a Dart como el error
/// `webContentProcessTerminated`, así que no hay aviso `renderProcessGone`.
/// Nunca envía ni registra direcciones ni contenido de páginas (CL-009-9).
final class WebViewHardening {
  /// En la app, la vista del paquete con ese identificador (o `nil`).
  private let lookup: (Int64) -> WKWebView?
  private let dataStore: () -> WKWebsiteDataStore
  /// Deja `Library/WebKit` y `Library/Cookies` fuera de la copia de seguridad (R2 de la 028,
  /// `DataAtRest`): en `harden` (antes de la primera carga de cada vista) y antes de cada petición
  /// del marco principal, por si WebKit ha creado o recreado las carpetas.
  private let prepareWebData: () -> Void
  /// Si se deja la inspección como está (solo en depuración, como `isDebuggable` en Android).
  private let inspectionAllowed: Bool
  /// Avisos a Dart (`mainFrameRequest`, `downloadBlocked`); lo pone `UnaChannels` con el canal.
  var send: (String, [String: Any]) -> Void = { _, _ in }

  #if DEBUG
    static let isDebugBuild = true
  #else
    static let isDebugBuild = false
  #endif

  init(
    lookup: @escaping (Int64) -> WKWebView? = { _ in nil },
    dataStore: @escaping () -> WKWebsiteDataStore = { .default() },
    prepareWebData: @escaping () -> Void = { DataAtRest.prepareWebDataNow() },
    inspectionAllowed: Bool = WebViewHardening.isDebugBuild
  ) {
    self.lookup = lookup
    self.dataStore = dataStore
    self.prepareWebData = prepareWebData
    self.inspectionAllowed = inspectionAllowed
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "harden":
      guard let view = webView(call), let id = webViewId(call) else { return result(false) }
      result(harden(view, id: id))
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
  private func webViewId(_ call: FlutterMethodCall) -> Int64? {
    guard let args = call.arguments as? [String: Any],
      let id = args["id"] as? NSNumber, CFGetTypeID(id) != CFBooleanGetTypeID()
    else { return nil }
    return id.int64Value
  }

  private func webView(_ call: FlutterMethodCall) -> WKWebView? {
    webViewId(call).flatMap(lookup)
  }

  private func harden(_ view: WKWebView, id: Int64) -> Bool {
    // R2 (028): antes de que la vista cargue nada. No bloquea la carga si falla (como al arrancar).
    prepareWebData()
    // Una sola vez por vista: el delegado del paquete, envuelto (se llama tras
    // `setNavigationDelegate`, que no se vuelve a llamar; ADR-0017).
    if !(view.navigationDelegate is NavigationWatcher) {
      let watcher = NavigationWatcher(
        inner: view.navigationDelegate,
        onMainFrameRequest: { [weak self] in
          self?.prepareWebData()
          self?.send("mainFrameRequest", ["id": id, "redirect": $0])
        },
        onDownloadBlocked: { [weak self] in self?.send("downloadBlocked", ["id": id]) })
      // `navigationDelegate` es débil: la vista conserva al envoltorio.
      objc_setAssociatedObject(
        view, &NavigationWatcher.key, watcher, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      view.navigationDelegate = watcher
    }
    // Sin selector de archivos (`setOnShowFileSelector` en Android): iOS 16 no tiene API pública
    // para impedirlo (`runOpenPanelWith` llega en iOS 18.4), así que un script de usuario lo corta.
    let scripts = view.configuration.userContentController
    if !scripts.userScripts.contains(where: { $0.source == Self.noFileChooserScript }) {
      scripts.addUserScript(
        WKUserScript(
          source: Self.noFileChooserScript, injectionTime: .atDocumentStart,
          forMainFrameOnly: false))
    }
    if !scripts.userScripts.contains(where: { $0.source == Self.noFileChooserScript }) {
      return false
    }
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
  /// - `wrapped`: el delegado del paquete está envuelto por el [NavigationWatcher].
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
      "wrapped": view.navigationDelegate is NavigationWatcher,
    ]
  }

  /// Corta el selector de archivos de `<input type=file>` en todos los marcos: el clic en uno (del
  /// usuario, de una etiqueta o de `click()`, también dentro de un *shadow root*) se cancela antes de
  /// que la página lo vea, y `showPicker()` falla. Se registra en `window` en la fase de captura
  /// antes que cualquier script de la página, así que esta no puede pararlo antes.
  static let noFileChooserScript = """
    (function () {
      function isFile(el) {
        return el instanceof HTMLInputElement && String(el.type).toLowerCase() === 'file';
      }
      window.addEventListener('click', function (e) {
        var path = e.composedPath ? e.composedPath() : [e.target];
        for (var i = 0; i < path.length; i++) {
          if (isFile(path[i])) {
            e.preventDefault();
            e.stopImmediatePropagation();
            return;
          }
        }
      }, true);
      var proto = HTMLInputElement.prototype;
      if (proto.showPicker) {
        var showPicker = proto.showPicker;
        proto.showPicker = function () {
          if (isFile(this)) throw new DOMException('', 'NotAllowedError');
          return showPicker.apply(this, arguments);
        };
      }
    })();
    """

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

/// El delegado de navegación del paquete, envuelto sin cambiar nada de lo que hace (espejo de
/// `RenderGoneClient` en Android): le reenvía todos sus métodos (`forwardingTarget`) y solo añade,
/// en el principal y **antes** de pasarle cada decisión (el paquete la manda a Dart más tarde, con
/// `DispatchQueue.main.async`, así que el aviso llega antes a Dart):
/// - `mainFrameRequest` antes de cada petición del marco principal (T-009-12), con `redirect: true`
///   si llega mientras la navegación provisional del marco principal sigue abierta (entre
///   `didStartProvisionalNavigation` y `didCommit`/`didFailProvisionalNavigation`): opción (a') del
///   contrato §3 (R-3, propietario, 2026-11-22). WebKit avisa de la redirección del servidor
///   (`didReceiveServerRedirectForProvisionalNavigation`) **después** de pedir la decisión sobre la
///   dirección nueva, así que la opción (a) no servía; la propiedad `_isRedirect` es privada. Una
///   navegación nueva de la página (enlace, `location.href`) cancela antes la provisional (-999), así
///   que llega como `false`. Lo revisa `security-reviewer` en I8 (T-028-24; ADR-0018).
/// - `downloadBlocked`: una respuesta del marco principal que no es una página (CL-009-4) se cancela
///   sin descargar nada ni mostrarla ([isDownload]).
///
/// Y cambia **cuándo** le llega al paquete `didStartProvisionalNavigation` (su `onPageStarted`): en
/// WebKit sale al pedir la dirección, antes de la respuesta, y una descarga o un fallo de conexión
/// ya «empezaban a verse»; en Android (`WebViewClient.onPageStarted`) y en `WebPageListener`
/// significa que la página empieza a verse. Se le pasa al confirmarse la navegación (`didCommit`),
/// con la dirección final (tras las redirecciones); una navegación que no llega a confirmarse no
/// lo envía.
final class NavigationWatcher: NSObject, WKNavigationDelegate {
  static var key: UInt8 = 0

  /// El delegado del paquete (fuerte: `navigationDelegate` es débil y el envoltorio lo sustituye).
  private let inner: WKNavigationDelegate?
  private let onMainFrameRequest: (Bool) -> Void
  private let onDownloadBlocked: () -> Void

  init(
    inner: WKNavigationDelegate?, onMainFrameRequest: @escaping (Bool) -> Void,
    onDownloadBlocked: @escaping () -> Void
  ) {
    self.inner = inner
    self.onMainFrameRequest = onMainFrameRequest
    self.onDownloadBlocked = onDownloadBlocked
  }

  // WebKit pregunta qué métodos hay al poner el delegado: los del paquete, por reenvío.
  override func responds(to aSelector: Selector!) -> Bool {
    super.responds(to: aSelector) || (inner?.responds(to: aSelector) ?? false)
  }

  override func forwardingTarget(for aSelector: Selector!) -> Any? {
    if let inner, inner.responds(to: aSelector) { return inner }
    return super.forwardingTarget(for: aSelector)
  }

  /// Si la navegación provisional del marco principal sigue abierta: una decisión del marco
  /// principal que llega entonces es una redirección del servidor (opción (a'), ver la clase).
  private(set) var provisionalOpen = false

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    provisionalOpen = true
    // Al paquete se le pasa en `didCommit` (ver la clase).
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    provisionalOpen = false
    inner?.webView?(webView, didStartProvisionalNavigation: navigation)
    inner?.webView?(webView, didCommit: navigation)
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    provisionalOpen = false
    inner?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    provisionalOpen = false
    inner?.webViewWebContentProcessDidTerminate?(webView)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    // Sin marco de destino es una ventana nueva: el paquete la da como de otro marco.
    if navigationAction.targetFrame?.isMainFrame == true { onMainFrameRequest(provisionalOpen) }
    if let inner {
      inner.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
        ?? decisionHandler(.allow)
    } else {
      decisionHandler(.allow)
    }
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
  ) {
    if navigationResponse.isForMainFrame
      && Self.isDownload(
        mimeType: navigationResponse.response.mimeType,
        canShow: navigationResponse.canShowMIMEType,
        disposition: (navigationResponse.response as? HTTPURLResponse)?
          .value(forHTTPHeaderField: "Content-Disposition"))
    {
      onDownloadBlocked()
      return decisionHandler(.cancel)
    }
    if let inner {
      inner.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
        ?? decisionHandler(.allow)
    } else {
      decisionHandler(.allow)
    }
  }

  /// Si una respuesta del marco principal es una descarga y no una página, como la trataría la
  /// WebView de Android (que la pasa a su `DownloadListener`): un adjunto (`Content-Disposition:
  /// attachment`), algo que WebKit no sabe mostrar, o un documento que WebKit mostraría con su
  /// visor y Chromium no (un PDF, un documento de Office…). Es página el texto, las imágenes, el
  /// audio, el vídeo, el HTML/XHTML, el XML y el JSON.
  static func isDownload(mimeType: String?, canShow: Bool, disposition: String?) -> Bool {
    if let disposition,
      disposition.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("attachment")
    {
      return true
    }
    if !canShow { return true }
    let mime = (mimeType ?? "").lowercased()
    if mime.isEmpty { return false }
    for prefix in ["text/", "image/", "audio/", "video/"] where mime.hasPrefix(prefix) {
      return false
    }
    let pages: Set<String> = [
      "application/xhtml+xml", "application/xml", "application/json", "application/javascript",
    ]
    return !(pages.contains(mime) || mime.hasSuffix("+xml") || mime.hasSuffix("+json"))
  }
}
