import Flutter
import UIKit

/// Lo que `una/a11y` lee del sistema. Es un protocolo para probar los tres hechos sin tener
/// VoiceOver encendido.
protocol AccessibilityState {
  var isVoiceOverRunning: Bool { get }
  var isSwitchControlRunning: Bool { get }
}

/// `UIAccessibility` real: solo lecturas, sin permisos ni oyentes.
struct SystemAccessibilityState: AccessibilityState {
  var isVoiceOverRunning: Bool { UIAccessibility.isVoiceOverRunning }
  var isSwitchControlRunning: Bool { UIAccessibility.isSwitchControlRunning }
}

/// Canal `una/a11y` (contrato §7; espejo de `AccessibilityTimeouts.kt`; spec 014 CA-014-06 y spec
/// 028 CA-028-14, ADR-0031): tres hechos del sistema para la duración de la card de deshacer. La
/// regla (4 s o 10 s) está en Dart (`UndoDuration`); aquí no se decide nada.
/// - `recommendedMs`: **siempre `null`**: iOS no tiene «Tiempo para actuar». Dart aplica entonces
///   la regla de Android 8 y 9: 10 s si hay un servicio activo.
/// - `serviceEnabled`: VoiceOver o Control por botón en marcha.
/// - `touchExploration`: VoiceOver en marcha (es lo que Dart cuenta como «lector»; Control por
///   botón, como Switch Access en Android, no lo es).
/// Ninguno se guarda ni se registra: dejaría deducir que se usa tecnología de apoyo. Un solo
/// método, `timeouts`, sin argumentos; el resto, «no implementado».
final class A11y {
  private let state: AccessibilityState

  init(state: AccessibilityState = SystemAccessibilityState()) {
    self.state = state
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "timeouts":
      result(timeouts())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func timeouts() -> [String: Any] {
    let voiceOver = state.isVoiceOverRunning
    return [
      "recommendedMs": NSNull(),
      "serviceEnabled": voiceOver || state.isSwitchControlRunning,
      "touchExploration": voiceOver,
    ]
  }
}
