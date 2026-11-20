import Flutter
import UIKit

/// Lo único que `una/screen` toca del sistema: el temporizador de reposo. Es un protocolo para
/// probar el canal sin cambiar el de la app de pruebas.
protocol IdleTimer: AnyObject {
  var isIdleTimerDisabled: Bool { get set }
}

extension UIApplication: IdleTimer {}

/// Canal `una/screen` (contrato §5; espejo del `una/screen` de `MainActivity.kt`; spec 007
/// CA-007-12, spec 008 CA-008-11, spec 015 CA-015-04 y spec 028 CA-028-13):
/// - `keepOn(bool)`: pantalla encendida mientras se ve un adjunto. `isIdleTimerDisabled`; solo un
///   `true` exacto la enciende, cualquier otra cosa la devuelve al apagado normal (como
///   `call.arguments == true` en Kotlin). Sin permisos. Al pasar a segundo plano iOS lo ignora y,
///   al volver, Dart lo pide de nuevo (`KeepScreenOnController`, CA-015-04d).
/// - `rotateWithAttachment(bool)`: **sin efecto aquí**. El giro de la tarea con adjunto lo pide
///   Dart con `SystemChrome.setPreferredOrientations` (`AttachmentRotation`); en Android hace
///   falta el acelerómetro por HyperOS, en iOS no. El método existe para que Dart no lo reciba como
///   «no implementado» y para igualar los métodos de Kotlin (CA-028-20).
/// Nada se guarda ni se registra.
final class Screen {
  private let idleTimer: IdleTimer

  init(idleTimer: IdleTimer = UIApplication.shared) {
    self.idleTimer = idleTimer
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "keepOn":
      let on = Screen.isExactlyTrue(call.arguments)
      onMain {
        self.idleTimer.isIdleTimerDisabled = on
        result(nil)
      }
    case "rotateWithAttachment":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// `true` solo si el argumento es el booleano `true` (como `call.arguments == true` en Kotlin). Con
  /// el códec estándar un booleano y un número llegan ambos como `NSNumber`, y `1 as? Bool` daría
  /// `true`: se comprueba el tipo.
  private static func isExactlyTrue(_ argument: Any?) -> Bool {
    guard let number = argument as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
      return false
    }
    return number.boolValue
  }

  /// `UIApplication` solo se toca desde el hilo principal; la respuesta va después del cambio.
  private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}
