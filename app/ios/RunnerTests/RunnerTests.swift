import Flutter
import UIKit
import XCTest

@testable import Runner

/// Mensajero de mentira: guarda el manejador que cada canal registra y permite lanzarle llamadas.
private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
  var handlers: [String: FlutterBinaryMessageHandler] = [:]
  private var next: FlutterBinaryMessengerConnection = 1

  func send(onChannel channel: String, message: Data?) {}

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {}

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    next += 1
    return next
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  /// Devuelve la respuesta cruda del canal (`nil` = «no implementado»).
  func call(_ channel: String, method: String) -> Data? {
    let message = FlutterStandardMethodCodec.sharedInstance().encode(
      FlutterMethodCall(methodName: method, arguments: nil))
    var reply: Data?
    var answered = false
    handlers[channel]?(message) { data in
      reply = data
      answered = true
    }
    XCTAssertTrue(answered, "\(channel) no respondió")
    return reply
  }
}

class RunnerTests: XCTestCase {

  func testRegistersTheSixChannelsWithTheNamesOfDartAndKotlin() {
    // CA-028-20: los seis canales existen con los nombres de siempre.
    let messenger = RecordingMessenger()
    let channels = UnaChannels.register(messenger: messenger)
    XCTAssertEqual(channels.count, 6)
    let expected = [
      "una/a11y", "una/images", "una/links", "una/notifications", "una/screen", "una/webview",
    ]
    XCTAssertEqual(messenger.handlers.keys.sorted(), expected)
  }

  func testEveryChannelAnswersNotImplementedUntilItsPhase() {
    // CA-028-20: hasta que cada fase los implemente, ningún método responde otra cosa.
    let messenger = RecordingMessenger()
    UnaChannels.register(messenger: messenger)
    for name in UnaChannels.names {
      XCTAssertNil(messenger.call(name, method: "anything"), "\(name) debería no estar implementado")
    }
  }
}
