import Flutter
import XCTest

@testable import Runner

/// Estado de accesibilidad de mentira.
private struct FakeAccessibilityState: AccessibilityState {
  var isVoiceOverRunning = false
  var isSwitchControlRunning = false
}

/// `una/a11y` (contrato §7, CA-028-14, CA-014-06; ADR-0031): tres hechos del sistema, sin
/// guardar ni registrar nada. La regla de la duración (4 s / 10 s) está en Dart (`UndoDuration`).
class A11yTests: XCTestCase {

  private func timeouts(_ state: FakeAccessibilityState) -> [String: Any]? {
    var answer: Any?
    A11y(state: state).handle(FlutterMethodCall(methodName: "timeouts", arguments: nil)) { answer = $0 }
    return answer as? [String: Any]
  }

  func testWithoutAssistiveTechnologyThereIsNothingToExtend() {
    // CA-028-14: sin VoiceOver ni Control por botón, nada que alargar (4 s en Dart).
    let reply = timeouts(FakeAccessibilityState())
    XCTAssertEqual(reply?["serviceEnabled"] as? Bool, false)
    XCTAssertEqual(reply?["touchExploration"] as? Bool, false)
  }

  func testVoiceOverIsAServiceAndATouchExplorer() {
    // CA-028-14: VoiceOver cuenta como servicio activo y como exploración táctil (lector).
    let reply = timeouts(FakeAccessibilityState(isVoiceOverRunning: true))
    XCTAssertEqual(reply?["serviceEnabled"] as? Bool, true)
    XCTAssertEqual(reply?["touchExploration"] as? Bool, true)
  }

  func testSwitchControlIsAServiceButNotATouchExplorer() {
    // CA-028-14: Control por botón cuenta como servicio (10 s) pero no como lector, igual que
    // Switch Access en Android (CA-014-17, T-014-10b).
    let reply = timeouts(FakeAccessibilityState(isSwitchControlRunning: true))
    XCTAssertEqual(reply?["serviceEnabled"] as? Bool, true)
    XCTAssertEqual(reply?["touchExploration"] as? Bool, false)
  }

  func testBothAtOnce() {
    // CA-028-14.
    let reply = timeouts(FakeAccessibilityState(isVoiceOverRunning: true, isSwitchControlRunning: true))
    XCTAssertEqual(reply?["serviceEnabled"] as? Bool, true)
    XCTAssertEqual(reply?["touchExploration"] as? Bool, true)
  }

  func testRecommendedMillisecondsIsAlwaysNull() {
    // CA-028-14: iOS no tiene «Tiempo para actuar»: `recommendedMs` va a `null` (NSNull) con
    // cualquier estado, para que Dart aplique la regla de Android 8 y 9 (ADR-0031).
    for state in [
      FakeAccessibilityState(),
      FakeAccessibilityState(isVoiceOverRunning: true),
      FakeAccessibilityState(isSwitchControlRunning: true),
    ] {
      let reply = timeouts(state)
      XCTAssertTrue(reply?.keys.contains("recommendedMs") == true, "la clave tiene que estar")
      XCTAssertTrue(reply?["recommendedMs"] is NSNull)
    }
  }

  func testTheReplyHasExactlyTheThreeFactsAndNothingElse() {
    // CA-014-06: tres hechos y nada más (nada que deje deducir otra cosa del usuario).
    let reply = timeouts(FakeAccessibilityState(isVoiceOverRunning: true))
    XCTAssertEqual(Set(reply?.keys ?? [:].keys), ["recommendedMs", "serviceEnabled", "touchExploration"])
  }

  func testUnknownMethodIsNotImplemented() {
    // Contrato §0.2.
    var answer: Any?
    A11y(state: FakeAccessibilityState()).handle(FlutterMethodCall(methodName: "recommended", arguments: nil)) {
      answer = $0
    }
    XCTAssertTrue((answer as AnyObject) === FlutterMethodNotImplemented)
  }

  func testTheRegisteredChannelAnswersWithTypesDartUnderstands() {
    // CA-028-20: `una/a11y` está cableado y la respuesta sobrevive al códec estándar
    // (`recommendedMs` llega como `null`, los otros dos como `bool`).
    let messenger = RecordingMessenger()
    UnaChannels.register(messenger: messenger, a11y: A11y(state: FakeAccessibilityState(isVoiceOverRunning: true)))
    let reply = messenger.value("una/a11y", method: "timeouts") as? [String: Any]
    XCTAssertEqual(Set(reply?.keys ?? [:].keys), ["recommendedMs", "serviceEnabled", "touchExploration"])
    XCTAssertTrue(reply?["recommendedMs"] is NSNull)
    XCTAssertEqual(reply?["serviceEnabled"] as? Bool, true)
    XCTAssertEqual(reply?["touchExploration"] as? Bool, true)
  }

  func testTheSystemStateReadsWithoutCrashing() {
    // El adaptador real lee `UIAccessibility`; en el simulador no hay lector activo.
    let state = SystemAccessibilityState()
    XCTAssertFalse(state.isVoiceOverRunning)
    XCTAssertFalse(state.isSwitchControlRunning)
  }
}
