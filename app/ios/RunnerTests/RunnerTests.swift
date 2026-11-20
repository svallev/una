import Flutter
import UIKit
import XCTest

@testable import Runner

/// Mensajero de mentira: guarda el manejador que cada canal registra y permite lanzarle llamadas.
final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
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
  func call(_ channel: String, method: String, arguments: Any? = nil) -> Data? {
    let message = FlutterStandardMethodCodec.sharedInstance().encode(
      FlutterMethodCall(methodName: method, arguments: arguments))
    var reply: Data?
    var answered = false
    handlers[channel]?(message) { data in
      reply = data
      answered = true
    }
    XCTAssertTrue(answered, "\(channel) no respondió")
    return reply
  }

  /// La respuesta ya decodificada: el valor del éxito, o el `FlutterError` si la llamada falló.
  /// Falla el test si el canal respondió «no implementado».
  func value(_ channel: String, method: String, arguments: Any? = nil) -> Any? {
    guard let data = call(channel, method: method, arguments: arguments) else {
      XCTFail("\(channel).\(method) responde «no implementado»")
      return nil
    }
    return FlutterStandardMethodCodec.sharedInstance().decodeEnvelope(data)
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

  /// Los canales que ya tienen su manejador (cada tarea de canal añade el suyo, T-028-09 a 19).
  private let implemented: Set<String> = ["una/links", "una/a11y"]

  func testEveryChannelAnswersNotImplementedUntilItsPhase() {
    // CA-028-20: hasta que cada fase los implemente, ningún método responde otra cosa.
    let messenger = RecordingMessenger()
    UnaChannels.register(messenger: messenger)
    for name in UnaChannels.names where !implemented.contains(name) {
      XCTAssertNil(messenger.call(name, method: "anything"), "\(name) debería no estar implementado")
    }
  }

  func testImplementedChannelsStillRefuseUnknownMethods() {
    // CA-028-20 y contrato §0.2: un método desconocido es siempre «no implementado».
    let messenger = RecordingMessenger()
    UnaChannels.register(messenger: messenger)
    for name in implemented {
      XCTAssertNil(messenger.call(name, method: "anything"), "\(name) debería rechazar lo desconocido")
    }
  }
}
