import Flutter
import UIKit
import WebKit
import XCTest

@testable import Runner

/// Delegado de navegación de mentira: solo apunta si murió el proceso de la página.
private final class TerminationDelegate: NSObject, WKNavigationDelegate {
  var terminated = false
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { terminated = true }
}

/// Delegado de mentira: apunta la dirección de la vista cada vez que le llega `didStart…`.
private final class StartRecorder: NSObject, WKNavigationDelegate {
  var started: [String] = []
  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    started.append(webView.url?.absoluteString ?? "")
  }
}

/// Delegado de interfaz de mentira (el del paquete pone `createWebViewWith` y los diálogos):
/// apunta si le llegó el cierre de la ventana.
private final class CloseRecorder: NSObject, WKUIDelegate {
  var closed = 0
  func webViewDidClose(_ webView: WKWebView) { closed += 1 }
}

/// Un marco de mentira (principal o no).
private final class FakeFrame: WKFrameInfo {
  private let main: Bool
  init(main: Bool) {
    self.main = main
    super.init()
  }
  override var isMainFrame: Bool { main }
}

/// Una decisión de navegación de mentira hacia un marco principal o no. WebKit no deja liberar un
/// `WKFrameInfo` o un `WKNavigationAction` creados fuera de él (su `dealloc` falla con SIGTRAP):
/// se guardan hasta que termina el proceso de los tests.
private final class FakeAction: WKNavigationAction {
  private static var keepAlive: [NSObject] = []
  private let frame: WKFrameInfo
  init(mainFrame: Bool) {
    frame = FakeFrame(main: mainFrame)
    super.init()
    Self.keepAlive += [frame, self]
  }
  override var targetFrame: WKFrameInfo? { frame }
  override var request: URLRequest { URLRequest(url: URL(string: "https://una.test/")!) }
}

/// `una/webview` (contrato §3; espejo de `WebViewHardening.kt`; CA-009-13, CA-021-08, ADR-0017 y
/// CA-028-19). Trabaja con una `WKWebView` real del simulador: lo que `harden` pone se lee de vuelta
/// de la propia vista, y `clearData` vacía el almacén de datos web de verdad.
class WebViewHardeningTests: XCTestCase {

  private let id: Int64 = 7

  /// Una vista con lo que trae `webview_flutter_wkwebview` (configuración por defecto) y un canal
  /// que la encuentra por [id]. `inspectionAllowed` es lo que en la app decide `#if DEBUG`.
  private func make(
    inspectionAllowed: Bool = false, store: WKWebsiteDataStore = .default(),
    prepareWebData: @escaping () -> Void = {}
  ) -> (WebViewHardening, WKWebView) {
    let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let id = self.id
    let hardening = WebViewHardening(
      lookup: { $0 == id ? view : nil }, dataStore: { store }, prepareWebData: prepareWebData,
      inspectionAllowed: inspectionAllowed)
    return (hardening, view)
  }

  /// Llama al canal y espera su respuesta (`clearData` responde más tarde, en el principal).
  private func call(
    _ hardening: WebViewHardening, _ method: String, _ arguments: Any? = nil,
    timeout: TimeInterval = 10
  ) -> Any? {
    let done = expectation(description: method)
    var answer: Any?
    hardening.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      XCTAssertTrue(Thread.isMainThread, "\(method) responde en el hilo principal")
      answer = $0
      done.fulfill()
    }
    wait(for: [done], timeout: timeout)
    return answer
  }

  private static let keys: Set<String> = [
    "noFileAccess", "noContentAccess", "noFormData", "noMixedContent", "safeBrowsing",
    "noMultipleWindows", "noDarkening", "wrapped",
  ]

  // MARK: harden y state

  func testHardenSetsEverythingAndReadsItBackFromTheView() {
    // CA-009-13 y CA-028-19: sin ventanas nuevas, aviso de sitios fraudulentos (el equivalente de
    // Safe Browsing), la página siempre en claro (CA-021-08) y sin inspección fuera de depuración.
    let (hardening, view) = make()
    let prefs = view.configuration.preferences
    prefs.javaScriptCanOpenWindowsAutomatically = true
    prefs.isFraudulentWebsiteWarningEnabled = false
    view.overrideUserInterfaceStyle = .dark
    if #available(iOS 16.4, *) { view.isInspectable = true }

    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)

    let after = view.configuration.preferences
    XCTAssertFalse(after.javaScriptCanOpenWindowsAutomatically)
    XCTAssertTrue(after.isFraudulentWebsiteWarningEnabled)
    XCTAssertEqual(view.overrideUserInterfaceStyle, .light)
    if #available(iOS 16.4, *) { XCTAssertFalse(view.isInspectable) }
  }

  func testStateHasTheSameKeysAsAndroidAndAllTrueAfterHarden() {
    // CA-028-19: las mismas claves que `WebViewHardening.kt`; Dart las compara igual.
    let (hardening, _) = make()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let state = call(hardening, "state", ["id": id]) as? [String: Bool]
    XCTAssertEqual(state.map { Set($0.keys) }, Self.keys)
    XCTAssertEqual(state?.values.allSatisfy { $0 }, true, "\(String(describing: state))")
  }

  func testStateReadsTheViewBackAndCatchesWhatChangesAfterHarden() {
    // La comprobación no es una lista fija: si algo se deshace después, `state` lo dice.
    let (hardening, view) = make()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    view.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    view.configuration.preferences.isFraudulentWebsiteWarningEnabled = false
    view.overrideUserInterfaceStyle = .unspecified
    let state = call(hardening, "state", ["id": id]) as? [String: Bool]
    XCTAssertEqual(state?["noMultipleWindows"], false)
    XCTAssertEqual(state?["safeBrowsing"], false)
    XCTAssertEqual(state?["noDarkening"], false)
    XCTAssertEqual(state?["noFormData"], true)
  }

  func testStateSaysFileAccessWhenTheViewShowsALocalFile() {
    // CA-009-13: la app nunca carga archivos (`loadFileURL`); si una vista mostrara uno, no está
    // endurecida.
    let (hardening, view) = make()
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("una-webview.html")
    XCTAssertNoThrow(try Data("<p>x</p>".utf8).write(to: file))
    defer { try? FileManager.default.removeItem(at: file) }
    let loaded = expectation(for: NSPredicate { _, _ in view.url?.isFileURL == true }, evaluatedWith: nil)
    view.loadFileURL(file, allowingReadAccessTo: file)
    wait(for: [loaded], timeout: 10)
    let state = call(hardening, "state", ["id": id]) as? [String: Bool]
    XCTAssertEqual(state?["noFileAccess"], false)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, false)
  }

  func testInDebugBuildsInspectionIsLeftAsItIs() {
    // Como Android (`isDebuggable`): en depuración no se toca la inspección.
    let (hardening, view) = make(inspectionAllowed: true)
    if #available(iOS 16.4, *) { view.isInspectable = true }
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    if #available(iOS 16.4, *) { XCTAssertTrue(view.isInspectable) }
  }

  func testHardenIsIdempotent() {
    let (hardening, _) = make()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
  }

  func testUnknownOrInvalidIdIsNotHardenedAndHasNoState() {
    // Contrato §3: sin esa vista, `harden` → false y `state` → null; nunca un error con texto.
    let (hardening, _) = make()
    for arguments: Any? in [
      ["id": 99], ["id": "7"], ["id": true], ["nada": 7], nil, "7",
    ] {
      XCTAssertEqual(call(hardening, "harden", arguments) as? Bool, false, "\(String(describing: arguments))")
      let state = call(hardening, "state", arguments)
      XCTAssertTrue(state == nil || state is NSNull, "\(String(describing: arguments))")
      let destroyed = call(hardening, "destroy", arguments)
      XCTAssertTrue(destroyed == nil || destroyed is NSNull)
    }
  }

  // MARK: destroy

  func testDestroyStopsAndEmptiesThePage() {
    // ADR-0017: tras el fallo del proceso de la página la vista vieja no vuelve a mostrar nada.
    let (hardening, view) = make()
    let shown = expectation(for: NSPredicate { _, _ in view.url?.host == "una.test" }, evaluatedWith: nil)
    view.loadHTMLString("<h1>Una</h1>", baseURL: URL(string: "https://una.test/"))
    wait(for: [shown], timeout: 10)
    let reply = call(hardening, "destroy", ["id": id])
    XCTAssertTrue(reply == nil || reply is NSNull)
    let blank = expectation(
      for: NSPredicate { _, _ in view.url?.host != "una.test" && !view.isLoading }, evaluatedWith: nil)
    wait(for: [blank], timeout: 10)
  }

  // MARK: clearData

  func testClearDataEmptiesTheWebsiteDataStore() {
    // CA-009-13 y CA-028-19: cookies, almacenamiento web y caché de todas las WebView; sin una vista
    // viva (el arranque) también, y responde `true` cuando ya se ha borrado.
    let store = WKWebsiteDataStore.default()
    let (hardening, _) = make(store: store)
    let cookie = HTTPCookie(properties: [
      .name: "una", .value: "1", .domain: "una.test", .path: "/", .secure: "TRUE",
      .expires: Date(timeIntervalSinceNow: 3600),
    ])!
    let set = expectation(description: "cookie")
    store.httpCookieStore.setCookie(cookie) { set.fulfill() }
    wait(for: [set], timeout: 10)
    XCTAssertFalse(records(store).isEmpty, "antes hay datos")

    XCTAssertEqual(call(hardening, "clearData", nil) as? Bool, true)
    XCTAssertTrue(records(store).isEmpty, "después no queda nada")
    XCTAssertTrue(cookies(store).isEmpty)

    // Con la vista que se ve (al salir de la tarea), igual.
    let again = expectation(description: "cookie 2")
    store.httpCookieStore.setCookie(cookie) { again.fulfill() }
    wait(for: [again], timeout: 10)
    XCTAssertEqual(call(hardening, "clearData", ["id": id]) as? Bool, true)
    XCTAssertTrue(cookies(store).isEmpty)
  }

  private func records(_ store: WKWebsiteDataStore) -> [WKWebsiteDataRecord] {
    let done = expectation(description: "records")
    var found: [WKWebsiteDataRecord] = []
    store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) {
      found = $0
      done.fulfill()
    }
    wait(for: [done], timeout: 10)
    return found
  }

  private func cookies(_ store: WKWebsiteDataStore) -> [HTTPCookie] {
    let done = expectation(description: "cookies")
    var found: [HTTPCookie] = []
    store.httpCookieStore.getAllCookies {
      found = $0
      done.fulfill()
    }
    wait(for: [done], timeout: 10)
    return found
  }

  // MARK: debugKillContentProcess (solo depuración, para los IT de ADR-0017)

  func testDebugKillContentProcessEndsThePageProcessAndThePackageDelegateHearsIt() {
    // ADR-0017 en iOS: el paquete recibe `webViewWebContentProcessDidTerminate` (lo da a Dart como
    // `webContentProcessTerminated`); el Swift no envía `renderProcessGone`. La app sigue viva.
    let (hardening, view) = make()
    let delegate = TerminationDelegate()
    view.navigationDelegate = delegate
    let shown = expectation(for: NSPredicate { _, _ in view.url?.host == "una.test" && !view.isLoading }, evaluatedWith: nil)
    view.loadHTMLString("<h1>Una</h1>", baseURL: URL(string: "https://una.test/"))
    wait(for: [shown], timeout: 10)
    let reply = call(hardening, "debugKillContentProcess", ["id": id])
    XCTAssertTrue(reply == nil || reply is NSNull)
    let gone = expectation(for: NSPredicate { _, _ in delegate.terminated }, evaluatedWith: nil)
    wait(for: [gone], timeout: 10)
    // Sin esa vista no hace nada y responde igual.
    let other = call(hardening, "debugKillContentProcess", ["id": 99])
    XCTAssertTrue(other == nil || other is NSNull)
  }

  func testTheDebugHookOnlyExistsInDebugBuilds() throws {
    // Como `debugCopyFile` (contrato §9): dentro de `#if DEBUG`; en Profile y Release es «no
    // implementado» y la API privada de WebKit no entra en el binario.
    let swift = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Runner/WebViewHardening.swift"),
      encoding: .utf8)
    for marker in [
      "private func debugKillContentProcess(", "_killWebContentProcess",
      "FilePanelBlocker.requests(of:",
    ] {
      let hook = try XCTUnwrap(swift.range(of: marker), marker)
      let guardStart = try XCTUnwrap(
        swift.range(of: "#if DEBUG", options: .backwards, range: swift.startIndex..<hook.lowerBound), marker)
      XCTAssertNil(
        swift.range(of: "#endif", range: guardStart.upperBound..<hook.lowerBound),
        "\(marker), dentro de #if DEBUG")
    }
  }

  // MARK: envoltorio del delegado (mainFrameRequest, downloadBlocked) y selector de archivos

  func testHardenWrapsThePackageDelegateOnceAndStateSaysSo() {
    // ADR-0017 y R-21: el delegado del paquete queda envuelto (como `RenderGoneClient`), una sola
    // vez; si otro `setNavigationDelegate` lo quita, `state` lo dice y `harden` lo vuelve a poner.
    let (hardening, view) = make()
    let inner = TerminationDelegate()
    view.navigationDelegate = inner
    XCTAssertEqual((call(hardening, "state", ["id": id]) as? [String: Bool])?["wrapped"], false)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let watcher = view.navigationDelegate
    XCTAssertTrue(watcher is NavigationWatcher)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertTrue(view.navigationDelegate === watcher, "no se envuelve dos veces")
    view.navigationDelegate = inner
    XCTAssertEqual((call(hardening, "state", ["id": id]) as? [String: Bool])?["wrapped"], false)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertEqual((call(hardening, "state", ["id": id]) as? [String: Bool])?["wrapped"], true)
  }

  func testTheWrapperForwardsEverythingToThePackageDelegate() {
    // El paquete sigue recibiendo todo lo suyo (aquí, el fallo del proceso de la página).
    let inner = TerminationDelegate()
    let watcher = NavigationWatcher(
      inner: inner, onMainFrameRequest: { _ in }, onDownloadBlocked: {})
    let selector = #selector(WKNavigationDelegate.webViewWebContentProcessDidTerminate(_:))
    XCTAssertTrue(watcher.responds(to: selector))
    XCTAssertFalse(
      watcher.responds(to: #selector(WKNavigationDelegate.webView(_:didFinish:))),
      "no dice tener lo que el paquete no tiene")
    (watcher as WKNavigationDelegate).webViewWebContentProcessDidTerminate?(WKWebView())
    XCTAssertTrue(inner.terminated)
  }

  func testMainFrameRequestBeforeEachMainFrameDecisionAndThePageStillLoads() {
    // T-009-12: `mainFrameRequest {id, redirect}` antes de cada decisión del marco principal.
    // La carga de la app no es una redirección (R-3, opción (a')).
    let (hardening, view) = make()
    var sent: [(String, [String: Any])] = []
    hardening.send = { sent.append(($0, $1)) }
    view.navigationDelegate = TerminationDelegate()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let shown = expectation(
      for: NSPredicate { _, _ in view.url?.host == "una.test" && !view.isLoading }, evaluatedWith: nil)
    view.loadHTMLString("<h1>Una</h1>", baseURL: URL(string: "https://una.test/"))
    wait(for: [shown], timeout: 10)
    XCTAssertEqual(sent.map(\.0), ["mainFrameRequest"])
    XCTAssertEqual(sent.first?.1["id"] as? Int64, id)
    XCTAssertEqual(sent.first?.1["redirect"] as? Bool, false)
  }

  // MARK: datos de la WebView fuera de la copia de seguridad (R2 de la 028, opción (b))

  private func isExcluded(_ url: URL) throws -> Bool {
    let fresh = URL(fileURLWithPath: url.path, isDirectory: true)
    return try fresh.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
  }

  private func load(_ view: WKWebView, _ page: String) {
    let shown = expectation(
      for: NSPredicate { _, _ in view.url?.path == "/\(page)" && !view.isLoading },
      evaluatedWith: nil)
    view.loadHTMLString("<h1>\(page)</h1>", baseURL: URL(string: "https://una.test/\(page)"))
    wait(for: [shown], timeout: 10)
  }

  func testHardenAndEveryMainFrameRequestPrepareTheWebDataBeforeTheLoad() {
    // R2 (028, opción (b)): `Library/WebKit` y `Library/Cookies` se marcan en `harden` (antes de la
    // primera carga) y antes de cada petición del marco principal, antes de avisar a Dart.
    var log: [String] = []
    let (hardening, view) = make(prepareWebData: { log.append("prepare") })
    hardening.send = { method, _ in log.append(method) }
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertEqual(log, ["prepare"])
    load(view, "a")
    load(view, "b")
    XCTAssertEqual(
      log, ["prepare", "prepare", "mainFrameRequest", "prepare", "mainFrameRequest"])
  }

  func testAWebViewLoadLeavesBothFoldersExcludedEvenIfWebKitRecreatedThem() throws {
    // R2 (028, opción (b)): con un `Library` de mentira, tras `harden` y tras una carga (con las
    // carpetas borradas entre medias, como si WebKit las recrease) las dos quedan excluidas.
    let library = FileManager.default.temporaryDirectory
      .appendingPathComponent("una-web-data-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: library) }
    let folders = ["WebKit", "Cookies"].map {
      library.appendingPathComponent($0, isDirectory: true)
    }
    let (hardening, view) = make(prepareWebData: {
      DataAtRest.prepareWebDataNow(library: library)
    })
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    for folder in folders { XCTAssertTrue(try isExcluded(folder), folder.lastPathComponent) }
    for folder in folders { try FileManager.default.removeItem(at: folder) }
    load(view, "a")
    for folder in folders { XCTAssertTrue(try isExcluded(folder), folder.lastPathComponent) }
  }

  func testByDefaultHardenMarksTheRealWebDataFolders() throws {
    // R2 (028, opción (b)): la `WebViewHardening` que crea `AppDelegate` (sin inyectar nada) marca
    // las carpetas reales del contenedor.
    let library = try XCTUnwrap(DataAtRest.libraryDirectory())
    try DataAtRest.prepareWebData(in: library)
    for name in ["WebKit", "Cookies"] {
      var folder = library.appendingPathComponent(name, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = false
      try folder.setResourceValues(values)
      XCTAssertFalse(try isExcluded(folder))
    }
    let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let id = self.id
    let hardening = WebViewHardening(lookup: { $0 == id ? view : nil }, inspectionAllowed: false)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    for name in ["WebKit", "Cookies"] {
      XCTAssertTrue(try isExcluded(library.appendingPathComponent(name, isDirectory: true)), name)
    }
  }

  func testRedirectIsADecisionWhileTheProvisionalNavigationIsOpen() {
    // R-3, opción (a') (propietario, 2026-11-22): `redirect: true` solo si la decisión del marco
    // principal llega con la navegación provisional abierta; confirmarla, que falle o que muera el
    // proceso de la página la cierran. Un marco que no es el principal no avisa.
    var sent: [Bool] = []
    let inner = TerminationDelegate()
    let watcher = NavigationWatcher(
      inner: inner, onMainFrameRequest: { sent.append($0) }, onDownloadBlocked: {})
    let delegate = watcher as WKNavigationDelegate
    let view = WKWebView()
    func decide(mainFrame: Bool = true) {
      delegate.webView?(
        view, decidePolicyFor: FakeAction(mainFrame: mainFrame), decisionHandler: { _ in })
    }
    decide()
    delegate.webView?(view, didStartProvisionalNavigation: nil)
    decide()
    decide()
    decide(mainFrame: false)
    delegate.webView?(view, didCommit: nil)
    decide()
    delegate.webView?(view, didStartProvisionalNavigation: nil)
    delegate.webView?(
      view, didFailProvisionalNavigation: nil, withError: URLError(.cancelled))
    decide()
    delegate.webView?(view, didStartProvisionalNavigation: nil)
    delegate.webViewWebContentProcessDidTerminate?(view)
    XCTAssertTrue(inner.terminated, "el paquete sigue oyendo el fallo del proceso")
    decide()
    XCTAssertEqual(sent, [false, true, true, false, false, false])
  }

  func testOwnLoadsAreNotRedirectsInARealView() {
    // La carga de la app (`loadHTMLString`, `load`) llega sin navegación provisional abierta.
    let (hardening, view) = make()
    var sent: [Bool] = []
    hardening.send = { method, arguments in
      if method == "mainFrameRequest" { sent.append(arguments["redirect"] as? Bool ?? true) }
    }
    view.navigationDelegate = TerminationDelegate()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    for page in ["a", "b"] {
      let shown = expectation(
        for: NSPredicate { _, _ in view.url?.path == "/\(page)" && !view.isLoading },
        evaluatedWith: nil)
      view.loadHTMLString("<h1>\(page)</h1>", baseURL: URL(string: "https://una.test/\(page)"))
      wait(for: [shown], timeout: 10)
    }
    XCTAssertEqual(sent, [false, false])
  }

  func testAResponseThatIsNotAPageIsCancelledWithDownloadBlocked() {
    // CL-009-4: un PDF en el marco principal no se muestra (WebKit sabría) ni se descarga.
    let (hardening, view) = make()
    var sent: [String] = []
    hardening.send = { method, arguments in
      sent.append(method)
      XCTAssertEqual(arguments.count, method == "downloadBlocked" ? 1 : 2, "sin la dirección")
    }
    view.navigationDelegate = TerminationDelegate()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let blocked = expectation(
      for: NSPredicate { _, _ in sent.contains("downloadBlocked") && !view.isLoading },
      evaluatedWith: nil)
    view.load(URLRequest(url: URL(string: "data:application/pdf;base64,JVBERi0xLjQKJSVFT0YK")!))
    wait(for: [blocked], timeout: 10)
    XCTAssertNotEqual(view.url?.scheme, "data", "no se muestra")
  }

  func testThePackageHearsThatThePageStartsOnlyWhenItIsCommitted() {
    // Como `onPageStarted` en Android y en `WebPageListener`: «empieza a verse», no «se pide». Una
    // descarga (no llega a confirmarse) no lo envía; una página, una vez y con su dirección.
    let (hardening, view) = make()
    let inner = StartRecorder()
    view.navigationDelegate = inner
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    var sent: [String] = []
    hardening.send = { method, _ in sent.append(method) }
    let blocked = expectation(
      for: NSPredicate { _, _ in sent.contains("downloadBlocked") && !view.isLoading },
      evaluatedWith: nil)
    view.load(URLRequest(url: URL(string: "data:application/pdf;base64,JVBERi0xLjQKJSVFT0YK")!))
    wait(for: [blocked], timeout: 10)
    XCTAssertEqual(inner.started, [])
    let shown = expectation(
      for: NSPredicate { _, _ in view.url?.host == "una.test" && !view.isLoading }, evaluatedWith: nil)
    view.loadHTMLString("<h1>Una</h1>", baseURL: URL(string: "https://una.test/a"))
    wait(for: [shown], timeout: 10)
    XCTAssertEqual(inner.started, ["https://una.test/a"])
  }

  func testWhatIsADownload() {
    // CL-009-4: como la WebView de Android (`DownloadListener`).
    let cases: [(String?, Bool, String?, Bool)] = [
      ("text/html", true, nil, false),
      ("text/plain", true, nil, false),
      ("image/png", true, nil, false),
      ("image/svg+xml", true, nil, false),
      ("video/mp4", true, nil, false),
      ("application/xhtml+xml", true, nil, false),
      ("application/json", true, nil, false),
      ("application/rss+xml", true, nil, false),
      ("text/html", true, " Attachment; filename=a.html", true),
      ("text/html", true, "inline", false),
      ("application/pdf", true, nil, true),
      ("application/msword", true, nil, true),
      ("application/octet-stream", false, nil, true),
      ("text/html", false, nil, true),
      (nil, true, nil, false),
    ]
    for (mime, canShow, disposition, expected) in cases {
      XCTAssertEqual(
        NavigationWatcher.isDownload(mimeType: mime, canShow: canShow, disposition: disposition),
        expected, "\(mime ?? "nil") \(canShow) \(disposition ?? "nil")")
    }
  }

  func testHardenAddsTheNoFileChooserScriptOnceToEveryFrame() {
    // CA-009-13 (sin selector de archivos): iOS 16 no tiene `runOpenPanelWith` (iOS 18.4).
    let (hardening, view) = make()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let scripts = view.configuration.userContentController.userScripts.filter {
      $0.source == WebViewHardening.noFileChooserScript
    }
    XCTAssertEqual(scripts.count, 1)
    XCTAssertEqual(scripts.first?.injectionTime, .atDocumentStart)
    XCTAssertEqual(scripts.first?.isForMainFrameOnly, false)
  }

  func testTheNoFileChooserScriptCancelsFileInputClicksOnly() {
    // El script, en una página real: el clic en el campo de archivo (directo o de su etiqueta) no
    // llega a la página y `showPicker()` falla; el de un botón, sí.
    let (hardening, view) = make()
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let shown = expectation(
      for: NSPredicate { _, _ in view.url?.host == "una.test" && !view.isLoading }, evaluatedWith: nil)
    view.loadHTMLString(
      """
      <script>window.seen=[];document.addEventListener('click',function(e){
      window.seen.push(e.target.id);},true);</script>
      <input type=file id=f><label for=f id=l>L</label><button id=b>B</button>
      """, baseURL: URL(string: "https://una.test/"))
    wait(for: [shown], timeout: 10)
    let done = expectation(description: "js")
    var result: Any?
    view.evaluateJavaScript(
      """
      document.getElementById('f').click(); document.getElementById('l').click();
      document.getElementById('b').click();
      var p; try { document.getElementById('f').showPicker(); p = 'abierto'; } catch (e) { p = e.name; }
      window.seen.join(',') + '|' + p
      """
    ) { value, _ in
      result = value
      done.fulfill()
    }
    wait(for: [done], timeout: 10)
    XCTAssertEqual(result as? String, "l,b|NotAllowedError")
  }

  // MARK: selector de archivos desde iOS 18.4 (FilePanelBlocker, S-M2 de la 028)

  func testHardenWrapsThePackageUIDelegateOnceAndStateSaysSo() throws {
    // CA-009-13 y CA-028-19: como el de navegación, una sola vez; si otro lo quita, `state` lo dice
    // (`wrapped`) y `harden` lo vuelve a poner.
    guard #available(iOS 18.4, *) else { throw XCTSkip("runOpenPanelWith es de iOS 18.4") }
    let (hardening, view) = make()
    let inner = CloseRecorder()
    view.uiDelegate = inner
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    let blocker = try XCTUnwrap(view.uiDelegate as? FilePanelBlocker)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertTrue(view.uiDelegate === blocker, "no se envuelve dos veces")
    view.uiDelegate = inner
    XCTAssertEqual((call(hardening, "state", ["id": id]) as? [String: Bool])?["wrapped"], false)
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    XCTAssertEqual((call(hardening, "state", ["id": id]) as? [String: Bool])?["wrapped"], true)
  }

  func testTheUIWrapperForwardsEverythingElseToThePackageDelegate() {
    // El paquete sigue recibiendo lo suyo (ventanas nuevas, diálogos…); lo que no tiene, tampoco
    // lo dice el envoltorio (WebKit pregunta `responds(to:)` al ponerlo).
    let inner = CloseRecorder()
    let blocker = FilePanelBlocker(inner: inner)
    let close = #selector(WKUIDelegate.webViewDidClose(_:))
    XCTAssertTrue(blocker.responds(to: close))
    XCTAssertFalse(FilePanelBlocker(inner: nil).responds(to: close))
    let alert = #selector(
      WKUIDelegate.webView(_:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:))
    XCTAssertFalse(blocker.responds(to: alert), "el de mentira no lo tiene")
    let view = WKWebView(frame: .zero)
    (blocker as WKUIDelegate).webViewDidClose?(view)
    XCTAssertEqual(inner.closed, 1)
    if #available(iOS 18.4, *) {
      let panel = #selector(
        WKUIDelegate.webView(_:runOpenPanelWith:initiatedByFrame:completionHandler:))
      XCTAssertTrue(FilePanelBlocker(inner: nil).responds(to: panel))
    }
  }

  func testWebKitAsksTheBlockerAndTheScriptStopsFileInputsThatAreNotInTheDocument() throws {
    // S-M2: un campo creado y no insertado (`click()`, `dispatchEvent`) no pasa por `window`. Con
    // el script, la página no llega a pedir el selector (lo único que lo corta en iOS 16–18.3);
    // sin él, WebKit lo pide y el envoltorio responde «cancelar».
    guard #available(iOS 18.4, *) else { throw XCTSkip("runOpenPanelWith es de iOS 18.4") }
    let (hardening, view) = make()
    // En una ventana, como en la app.
    let window = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }
        .first)
    view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    window.addSubview(view)
    defer { view.removeFromSuperview() }
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
    // Uno por llamada: con una petición pendiente, WebKit no atiende otra en la misma página.
    let loose = [
      "var i = document.createElement('input'); i.type = 'file'; i.click(); 1",
      "var i = document.createElement('input'); i.type = 'file';"
        + " i.dispatchEvent(new MouseEvent('click')); 1",
    ]
    func load() {
      let shown = expectation(
        for: NSPredicate { _, _ in view.url?.host == "una.test" && !view.isLoading },
        evaluatedWith: nil)
      view.loadHTMLString("<h1>Una</h1>", baseURL: URL(string: "https://una.test/"))
      wait(for: [shown], timeout: 10)
    }
    func run() {
      for js in loose {
        let done = expectation(description: "js")
        view.evaluateJavaScript(js) { _, _ in done.fulfill() }
        wait(for: [done], timeout: 10)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
      }
    }
    load()
    run()
    XCTAssertEqual(FilePanelBlocker.requests(of: view), 0, "lo corta el script")
    view.configuration.userContentController.removeAllUserScripts()
    load()
    run()
    let asked = expectation(
      for: NSPredicate { _, _ in FilePanelBlocker.requests(of: view) == 2 }, evaluatedWith: nil)
    wait(for: [asked], timeout: 10)
    // `harden` vuelve a poner el script.
    XCTAssertEqual(call(hardening, "harden", ["id": id]) as? Bool, true)
  }

  // MARK: canal

  func testUnknownMethodIsNotImplemented() {
    let (hardening, _) = make()
    var answer: Any?
    hardening.handle(FlutterMethodCall(methodName: "renderProcessGone", arguments: nil)) { answer = $0 }
    XCTAssertTrue(answer as AnyObject === FlutterMethodNotImplemented)
  }

  func testRegisteredOnTheChannelWithItsHandler() {
    // CA-028-20: `una/webview` responde con su manejador (no «no implementado»).
    let messenger = RecordingMessenger()
    let (hardening, _) = make()
    UnaChannels.register(messenger: messenger, webView: hardening)
    XCTAssertEqual(messenger.value("una/webview", method: "harden", arguments: ["id": id]) as? Bool, true)
  }

  func testTheSwiftNeverLogsNorTouchesTheNetwork() throws {
    // CL-009-9: ni direcciones ni contenido; tampoco red propia (sección `network`).
    let source = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Runner/WebViewHardening.swift"),
      encoding: .utf8)
    for forbidden in ["print(", "NSLog", "os_log", "Logger", "URLSession", "FlutterError("] {
      XCTAssertFalse(source.contains(forbidden), forbidden)
    }
  }
}
