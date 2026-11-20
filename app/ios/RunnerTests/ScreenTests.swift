import Flutter
import UIKit
import XCTest

@testable import Runner

/// Temporizador de reposo de mentira: guarda lo que se le pide y desde qué hilo.
private final class FakeIdleTimer: IdleTimer {
  var isIdleTimerDisabled = false {
    didSet { writes.append(isIdleTimerDisabled); wroteOnMainThread = Thread.isMainThread }
  }
  var writes: [Bool] = []
  var wroteOnMainThread = true
}

/// `una/screen` (contrato §5; espejo del `una/screen` de `MainActivity.kt`; CA-007-12, CA-008-11,
/// CA-015-04 y CA-028-13). `keepOn` apaga o enciende el temporizador de reposo del sistema; el giro
/// con adjunto lo hace `SystemChrome` desde Dart y aquí solo se responde.
class ScreenTests: XCTestCase {

  private func call(_ screen: Screen, _ method: String, _ arguments: Any?) -> Any? {
    var answer: Any?
    var answered = false
    screen.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      answer = $0
      answered = true
    }
    XCTAssertTrue(answered, "tiene que responder")
    return answer
  }

  func testKeepOnTrueDisablesTheIdleTimer() {
    // CA-028-13 y CA-007-12: encendida, la pantalla no se apaga por inactividad.
    let timer = FakeIdleTimer()
    let reply = call(Screen(idleTimer: timer), "keepOn", true)
    XCTAssertTrue(timer.isIdleTimerDisabled)
    XCTAssertTrue(reply == nil || reply is NSNull, "responde null")
  }

  func testKeepOnFalseGivesTheIdleTimerBack() {
    // CA-015-04: al retirar la petición vuelve el apagado normal.
    let timer = FakeIdleTimer()
    let screen = Screen(idleTimer: timer)
    _ = call(screen, "keepOn", true)
    _ = call(screen, "keepOn", false)
    XCTAssertFalse(timer.isIdleTimerDisabled)
    XCTAssertEqual(timer.writes, [true, false])
  }

  func testAnythingButExactlyTrueTurnsItOffLikeKotlin() {
    // Espejo de `call.arguments == true`: sin argumento, con texto o con un número, apagado normal.
    for argument: Any? in [nil, "true", 1, NSNull()] {
      let timer = FakeIdleTimer()
      timer.isIdleTimerDisabled = true
      _ = call(Screen(idleTimer: timer), "keepOn", argument)
      XCTAssertFalse(timer.isIdleTimerDisabled, "\(String(describing: argument)) no enciende")
    }
  }

  func testKeepOnWorksOnTheMainThreadEvenIfCalledFromAnother() {
    // `UIApplication` solo se toca desde el hilo principal.
    let timer = FakeIdleTimer()
    let screen = Screen(idleTimer: timer)
    let done = expectation(description: "respondió")
    DispatchQueue.global().async {
      screen.handle(FlutterMethodCall(methodName: "keepOn", arguments: true)) { _ in done.fulfill() }
    }
    wait(for: [done], timeout: 5)
    XCTAssertTrue(timer.isIdleTimerDisabled)
    XCTAssertTrue(timer.wroteOnMainThread)
  }

  func testRotateWithAttachmentJustAnswersBecauseDartAlreadyAsksSystemChrome() {
    // Contrato §5: `SystemChrome.setPreferredOrientations` (Dart) basta; el Swift no guarda nada
    // ni toca el temporizador.
    let timer = FakeIdleTimer()
    for argument: Any? in [true, false] {
      let reply = call(Screen(idleTimer: timer), "rotateWithAttachment", argument)
      XCTAssertTrue(reply == nil || reply is NSNull)
    }
    XCTAssertEqual(timer.writes, [])
  }

  func testUnknownMethodIsNotImplemented() {
    // Contrato §0.2.
    let reply = call(Screen(idleTimer: FakeIdleTimer()), "rotate", true)
    XCTAssertTrue((reply as AnyObject) === FlutterMethodNotImplemented)
  }

  func testTheRegisteredChannelAnswersAndTouchesTheTimer() {
    // CA-028-20: `una/screen` cableado en `UnaChannels`, con la respuesta nula del códec estándar.
    let messenger = RecordingMessenger()
    let timer = FakeIdleTimer()
    UnaChannels.register(messenger: messenger, screen: Screen(idleTimer: timer))
    XCTAssertNil(messenger.value("una/screen", method: "keepOn", arguments: true))
    XCTAssertTrue(timer.isIdleTimerDisabled)
    XCTAssertNil(messenger.value("una/screen", method: "rotateWithAttachment", arguments: true))
    XCTAssertNil(messenger.value("una/screen", method: "keepOn", arguments: false))
    XCTAssertFalse(timer.isIdleTimerDisabled)
  }

  func testTheSystemApplicationIsTheRealTimer() {
    // El adaptador real es `UIApplication`; se comprueba sin dejar el temporizador cambiado.
    let application: IdleTimer = UIApplication.shared
    let before = application.isIdleTimerDisabled
    application.isIdleTimerDisabled = !before
    XCTAssertEqual(UIApplication.shared.isIdleTimerDisabled, !before)
    application.isIdleTimerDisabled = before
  }

  func testTheDefaultScreenUsesTheSharedApplication() {
    // `Screen()` (el que registra la app) escribe en `UIApplication.shared`.
    let before = UIApplication.shared.isIdleTimerDisabled
    defer { UIApplication.shared.isIdleTimerDisabled = before }
    _ = call(Screen(), "keepOn", true)
    XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
    _ = call(Screen(), "keepOn", false)
    XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
  }
}
