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

/// `una/webview` (contrato §3; espejo de `WebViewHardening.kt`; CA-009-13, CA-021-08, ADR-0017 y
/// CA-028-19). Trabaja con una `WKWebView` real del simulador: lo que `harden` pone se lee de vuelta
/// de la propia vista, y `clearData` vacía el almacén de datos web de verdad.
class WebViewHardeningTests: XCTestCase {

  private let id: Int64 = 7

  /// Una vista con lo que trae `webview_flutter_wkwebview` (configuración por defecto) y un canal
  /// que la encuentra por [id]. `inspectionAllowed` es lo que en la app decide `#if DEBUG`.
  private func make(
    inspectionAllowed: Bool = false, store: WKWebsiteDataStore = .default()
  ) -> (WebViewHardening, WKWebView) {
    let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let id = self.id
    let hardening = WebViewHardening(
      lookup: { $0 == id ? view : nil }, dataStore: { store }, inspectionAllowed: inspectionAllowed)
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
    for marker in ["private func debugKillContentProcess(", "_killWebContentProcess"] {
      let hook = try XCTUnwrap(swift.range(of: marker), marker)
      let guardStart = try XCTUnwrap(
        swift.range(of: "#if DEBUG", options: .backwards, range: swift.startIndex..<hook.lowerBound), marker)
      XCTAssertNil(
        swift.range(of: "#endif", range: guardStart.upperBound..<hook.lowerBound),
        "\(marker), dentro de #if DEBUG")
    }
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
