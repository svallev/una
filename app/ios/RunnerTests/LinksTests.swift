import Flutter
import UIKit
import XCTest

@testable import Runner

/// Aplicación de mentira: guarda lo que se le pide y responde lo que el test decida.
private final class FakeLinkApplication: LinkApplication {
  var canOpenResult = true
  var openResult = true
  private(set) var canOpenAsked: [URL] = []
  private(set) var opened: [URL] = []

  func canOpenURL(_ url: URL) -> Bool {
    canOpenAsked.append(url)
    return canOpenResult
  }

  func open(_ url: URL, completion: @escaping (Bool) -> Void) {
    opened.append(url)
    completion(openResult)
  }
}

/// `una/links` (contrato §6, CA-028-13, CA-008-12, CA-015-12a/b): abre un enlace ya comprobado en
/// Dart con la app del sistema, solo de los tres tipos de siempre y diciendo `false` si no hay app.
class LinksTests: XCTestCase {

  private func reply(
    _ links: Links, _ method: String, kind: String?, uri: String?
  ) -> Any? {
    var arguments: [String: Any] = [:]
    if let kind { arguments["kind"] = kind }
    if let uri { arguments["uri"] = uri }
    var answer: Any?
    var answered = false
    links.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      answer = $0
      answered = true
    }
    XCTAssertTrue(answered, "\(method) no respondió")
    return answer
  }

  // MARK: - Qué esquema vale para cada tipo (los mismos tres intents de LinkOpener.kt)

  func testWebAcceptsOnlyHttpAndHttps() {
    // CA-028-13: `web` solo abre `http(s)`.
    XCTAssertEqual(Links.url(kind: "web", uri: "https://example.org/a")?.absoluteString, "https://example.org/a")
    XCTAssertEqual(Links.url(kind: "web", uri: "http://example.org")?.absoluteString, "http://example.org")
    for bad in [
      "mailto:a@example.org", "tel:+34600000000", "javascript:alert(1)", "file:///etc/passwd",
      "ftp://example.org", "sms:600000000", "una://abrir", "data:text/html,hola", "example.org",
      "//example.org", "",
    ] {
      XCTAssertNil(Links.url(kind: "web", uri: bad), "web no debería aceptar «\(bad)»")
    }
  }

  func testMailAcceptsOnlyMailto() {
    // CA-028-13: `mail` solo abre `mailto:`.
    XCTAssertEqual(
      Links.url(kind: "mail", uri: "mailto:hola@example.org")?.absoluteString, "mailto:hola@example.org")
    for bad in ["https://example.org", "tel:+34600000000", "javascript:alert(1)", "hola@example.org", ""] {
      XCTAssertNil(Links.url(kind: "mail", uri: bad), "mail no debería aceptar «\(bad)»")
    }
  }

  func testTelAcceptsOnlyTel() {
    // CA-028-13: `tel` solo abre `tel:` (marcar; la app del sistema pide confirmar la llamada).
    XCTAssertEqual(Links.url(kind: "tel", uri: "tel:+34600000000")?.absoluteString, "tel:+34600000000")
    for bad in ["https://example.org", "mailto:a@example.org", "facetime:+34600000000", "telprompt:600", ""] {
      XCTAssertNil(Links.url(kind: "tel", uri: bad), "tel no debería aceptar «\(bad)»")
    }
  }

  func testUnknownOrMissingKindAndUriAreRefused() {
    // CA-028-13: sin tipo, con otro tipo o sin dirección, nada se abre.
    XCTAssertNil(Links.url(kind: nil, uri: "https://example.org"))
    XCTAssertNil(Links.url(kind: "", uri: "https://example.org"))
    XCTAssertNil(Links.url(kind: "internal", uri: "https://example.org"))
    XCTAssertNil(Links.url(kind: "WEB", uri: "https://example.org"))
    XCTAssertNil(Links.url(kind: "web", uri: nil))
  }

  // MARK: - open y canOpen

  func testOpenRespondsWithWhatTheSystemSaysAndPassesTheSameUrl() {
    // CA-028-13: `open` responde con el resultado del sistema (true si se abrió, false si no).
    let app = FakeLinkApplication()
    let links = Links(application: app)
    app.openResult = true
    XCTAssertEqual(reply(links, "open", kind: "web", uri: "https://example.org/p") as? Bool, true)
    app.openResult = false
    XCTAssertEqual(reply(links, "open", kind: "mail", uri: "mailto:a@example.org") as? Bool, false)
    XCTAssertEqual(app.opened.map(\.absoluteString), ["https://example.org/p", "mailto:a@example.org"])
  }

  func testOpenOfAnInvalidLinkAnswersFalseAndNeverTouchesTheSystem() {
    // CA-028-13: lo que no pasa la validación de esquema no llega nunca al sistema.
    let app = FakeLinkApplication()
    let links = Links(application: app)
    XCTAssertEqual(reply(links, "open", kind: "web", uri: "javascript:alert(1)") as? Bool, false)
    XCTAssertEqual(reply(links, "open", kind: "tel", uri: "https://example.org") as? Bool, false)
    XCTAssertEqual(reply(links, "open", kind: nil, uri: "https://example.org") as? Bool, false)
    XCTAssertEqual(reply(links, "open", kind: "web", uri: nil) as? Bool, false)
    XCTAssertTrue(app.opened.isEmpty)
    XCTAssertTrue(app.canOpenAsked.isEmpty)
  }

  func testCanOpenAsksTheSystemWithoutOpening() {
    // CA-028-13: `canOpen` solo pregunta (`canOpenURL`), no abre.
    let app = FakeLinkApplication()
    let links = Links(application: app)
    app.canOpenResult = true
    XCTAssertEqual(reply(links, "canOpen", kind: "tel", uri: "tel:+34600000000") as? Bool, true)
    app.canOpenResult = false
    XCTAssertEqual(reply(links, "canOpen", kind: "tel", uri: "tel:+34600000000") as? Bool, false)
    XCTAssertEqual(app.canOpenAsked.count, 2)
    XCTAssertTrue(app.opened.isEmpty)
  }

  func testCanOpenOfAnInvalidLinkAnswersFalseWithoutAskingTheSystem() {
    // CA-028-13: la misma validación de esquema antes de preguntar.
    let app = FakeLinkApplication()
    let links = Links(application: app)
    XCTAssertEqual(reply(links, "canOpen", kind: "web", uri: "file:///etc/passwd") as? Bool, false)
    XCTAssertEqual(reply(links, "canOpen", kind: "bogus", uri: "https://example.org") as? Bool, false)
    XCTAssertTrue(app.canOpenAsked.isEmpty)
  }

  func testWithoutArgumentsOrWithTheWrongTypesTheAnswerIsFalseNotAnError() {
    // Contrato §0.1: sin errores con texto; Dart ya cuenta cualquier fallo como «no».
    let app = FakeLinkApplication()
    let links = Links(application: app)
    for arguments in [nil, "texto", 3, ["kind": 1, "uri": 2]] as [Any?] {
      for method in ["open", "canOpen"] {
        var answer: Any?
        links.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { answer = $0 }
        XCTAssertEqual(answer as? Bool, false, "\(method) con \(String(describing: arguments))")
      }
    }
    XCTAssertTrue(app.opened.isEmpty)
  }

  func testUnknownMethodIsNotImplemented() {
    // Contrato §0.2.
    let links = Links(application: FakeLinkApplication())
    var answer: Any?
    links.handle(FlutterMethodCall(methodName: "share", arguments: nil)) { answer = $0 }
    XCTAssertTrue((answer as AnyObject) === FlutterMethodNotImplemented)
  }

  // MARK: - El canal registrado

  func testTheRegisteredChannelOpensThroughTheInjectedApplication() {
    // CA-028-20 y CA-028-13: `una/links` está cableado a `Links` y responde con tipos de Dart.
    let app = FakeLinkApplication()
    let messenger = RecordingMessenger()
    UnaChannels.register(messenger: messenger, links: Links(application: app))
    let ok = messenger.value("una/links", method: "open", arguments: ["kind": "web", "uri": "https://example.org"])
    XCTAssertEqual(ok as? Bool, true)
    let no = messenger.value("una/links", method: "open", arguments: ["kind": "web", "uri": "javascript:1"])
    XCTAssertEqual(no as? Bool, false)
    app.canOpenResult = false
    let cannot = messenger.value("una/links", method: "canOpen", arguments: ["kind": "tel", "uri": "tel:600"])
    XCTAssertEqual(cannot as? Bool, false)
    XCTAssertEqual(app.opened.map(\.absoluteString), ["https://example.org"])
  }

  // MARK: - El sistema de verdad

  func testTheSystemAdapterKnowsHttpsWithoutDeclaringAnyQuerySchemes() {
    // [Suposición del contrato §6 comprobada en el simulador]: `canOpenURL` de `https` responde
    // `true` sin `LSApplicationQueriesSchemes`.
    XCTAssertTrue(SystemLinkApplication().canOpenURL(URL(string: "https://example.org")!))
  }

  func testTheQuerySchemesDeclaredInTheAppMatchTheDecision() throws {
    // T-028-09: `LSApplicationQueriesSchemes` solo existe si `canOpenURL` lo exige para
    // `mailto`/`tel` (comprobado en el simulador); la lista, si está, es exactamente esa.
    let declared = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]
    XCTAssertEqual(Set(declared ?? []), Links.declaredQuerySchemes)
  }
}
