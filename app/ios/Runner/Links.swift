import Flutter
import UIKit

/// Lo único que `una/links` necesita del sistema: preguntar si hay app y abrir. Es un protocolo para
/// probar la lógica sin abrir nada de verdad.
protocol LinkApplication {
  func canOpenURL(_ url: URL) -> Bool
  /// Abre `url` con la app del sistema; `completion` dice si se abrió (siempre en el hilo principal).
  func open(_ url: URL, completion: @escaping (Bool) -> Void)
}

/// `UIApplication` real. No pasa opciones: un enlace `https` puede abrirse con la app que lo
/// reclame o con Safari, igual que Android abre lo que atienda el intent.
struct SystemLinkApplication: LinkApplication {
  func canOpenURL(_ url: URL) -> Bool {
    return UIApplication.shared.canOpenURL(url)
  }

  func open(_ url: URL, completion: @escaping (Bool) -> Void) {
    UIApplication.shared.open(url, options: [:], completionHandler: completion)
  }
}

/// Canal `una/links` (contrato §6; espejo de `LinkOpener.kt`; spec 008 CA-008-12, spec 015
/// CA-015-12a/b y spec 028 CA-028-13): abre un enlace **ya comprobado en Dart** con la app del
/// sistema y dice antes si hay app que lo abra. Por aquí pasan Ajustes (política, licencias, ayuda),
/// los enlaces del PDF (que Dart confirma antes) y «Abrir en el navegador» de la tarea web.
///
/// Solo tres tipos, cada uno con su único esquema (los mismos tres intents de Android):
/// - `web`: `http` y `https`;
/// - `mail`: `mailto`;
/// - `tel`: `tel` (marca; la app del sistema pide confirmar la llamada).
/// Cualquier otra cosa (tipo desconocido, esquema ajeno, argumentos que faltan o no son texto) es
/// `false` y no llega al sistema. Nunca registra ni guarda el enlace (CL-008-11, P4): este archivo no
/// escribe nada, ni siquiera en el registro del sistema.
final class Links {
  /// Esquemas que la app declara en `LSApplicationQueriesSchemes` (ver `Info.plist`). Hoy ninguno:
  /// `canOpenURL` responde bien para `https`, `mailto` y `tel` sin declararlos (T-028-09).
  static let declaredQuerySchemes: Set<String> = []

  private let application: LinkApplication

  init(application: LinkApplication = SystemLinkApplication()) {
    self.application = application
  }

  /// La URL de la llamada, solo si el esquema es el único permitido para su tipo.
  static func url(kind: String?, uri: String?) -> URL? {
    guard let kind, let uri, !uri.isEmpty, let url = URL(string: uri), let scheme = url.scheme else {
      return nil
    }
    switch kind {
    case "web": return scheme == "https" || scheme == "http" ? url : nil
    case "mail": return scheme == "mailto" ? url : nil
    case "tel": return scheme == "tel" ? url : nil
    default: return nil
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard let url = Links.url(from: call) else { return result(false) }
      application.open(url) { opened in
        // Contrato §0.4: la respuesta, siempre en el hilo principal.
        if Thread.isMainThread {
          result(opened)
        } else {
          DispatchQueue.main.async { result(opened) }
        }
      }
    case "canOpen":
      guard let url = Links.url(from: call) else { return result(false) }
      result(application.canOpenURL(url))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func url(from call: FlutterMethodCall) -> URL? {
    guard let arguments = call.arguments as? [String: Any] else { return nil }
    return url(kind: arguments["kind"] as? String, uri: arguments["uri"] as? String)
  }
}
