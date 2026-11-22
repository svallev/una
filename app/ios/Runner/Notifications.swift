import Flutter
import UIKit
import UserNotifications

/// Lo que el canal sabe del permiso: el estado de la autorización y si iOS deja mostrar avisos.
struct NotificationPermission: Equatable {
  var status: UNAuthorizationStatus
  var alert: UNNotificationSetting

  /// `canNotify` (contrato §4): autorizada (también provisional o efímera) y con los avisos activos.
  var allowsNotifying: Bool {
    switch status {
    case .authorized, .provisional, .ephemeral: return alert == .enabled
    default: return false
    }
  }
}

/// Lo único que `una/notifications` necesita de `UNUserNotificationCenter`. Es un protocolo para
/// probar la lógica sin pedir permiso de verdad. Las respuestas pueden llegar en cualquier hilo.
protocol NotificationCenterClient: AnyObject {
  func permission(_ completion: @escaping (NotificationPermission) -> Void)
  func requestAuthorization(_ completion: @escaping () -> Void)
  func setCategories(_ categories: Set<UNNotificationCategory>)
  func removeAllPending()
  func removeAllDelivered()
  func add(_ request: UNNotificationRequest, completion: @escaping (Bool) -> Void)
}

/// El centro de notificaciones real.
final class SystemNotificationCenter: NotificationCenterClient {
  private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  func permission(_ completion: @escaping (NotificationPermission) -> Void) {
    center.getNotificationSettings { settings in
      completion(
        NotificationPermission(status: settings.authorizationStatus, alert: settings.alertSetting))
    }
  }

  func requestAuthorization(_ completion: @escaping () -> Void) {
    // Sin insignia: solo aviso y el sonido por defecto (contrato §4).
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in completion() }
  }

  func setCategories(_ categories: Set<UNNotificationCategory>) {
    center.setNotificationCategories(categories)
  }

  func removeAllPending() { center.removeAllPendingNotificationRequests() }

  func removeAllDelivered() { center.removeAllDeliveredNotifications() }

  func add(_ request: UNNotificationRequest, completion: @escaping (Bool) -> Void) {
    center.add(request) { error in completion(error == nil) }
  }
}

/// Un aviso ya escrito por Dart (`IosNotificationGateway`): la hora del día y sus tres textos.
struct NotificationSlot: Equatable {
  let hour: Int
  let minute: Int
  let title: String
  let body: String
  let publicBody: String
}

/// Canal `una/notifications` en iOS (contrato §4, ADR-0030, spec 028 CA-028-15 y 16; espejo de
/// `NotificationsChannel.kt`). Mucho más pequeño que el de Android: no lee la BD ni calcula texto;
/// Dart manda los avisos ya escritos y aquí solo se programan con la hora del día.
///
/// Métodos: `canNotify`, `requestPermission` (`{granted, dialogShown}`), `configure`
/// (`{on, slots: [{hour, minute, title, body, publicBody}]}`, 0…3), `cancelDelivered`,
/// `setForeground` (bool) y `openSystemSettings`. Hacia Dart: `openCurrentTask` al tocar un aviso
/// propio.
///
/// **No guarda nada** (ni `UserDefaults` ni archivos): el texto de la tarea solo está en la
/// programación del sistema mientras el interruptor está encendido (excepción de CA-028-16).
/// Un argumento inválido o cualquier fallo contestan con un error **sin texto** (CA-019-23), y nada
/// se escribe en el registro.
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
  /// Prefijo de los identificadores de los avisos y las categorías de la app: solo esos abren la
  /// tarea actual al tocarlos.
  static let identifierPrefix = "current-task-"
  /// Todos los avisos van en el mismo grupo del centro de notificaciones.
  static let threadIdentifier = "current-task"
  static let maxSlots = 3

  private static let invalid = "invalid_argument"
  private static let failed = "failed"

  private let center: NotificationCenterClient
  private let application: LinkApplication

  /// Para mandar `openCurrentTask` a Dart; lo pone `UnaChannels` al registrar el canal.
  var send: ((String, Any?) -> Void)?

  /// «A la vista» (CA-019-19a), solo en memoria; empieza en `true` como en Dart.
  private(set) var foreground = true
  /// Dart ya oye el canal (llamó a `setForeground`): antes, un toque espera aquí.
  private var dartListening = false
  /// Un toque llegado antes de que Dart oyera el canal (app abierta en frío desde el aviso).
  private(set) var pendingOpen = false
  private var requestInFlight = false

  init(
    center: NotificationCenterClient = SystemNotificationCenter(),
    application: LinkApplication = SystemLinkApplication()
  ) {
    self.center = center
    self.application = application
  }

  // MARK: - Canal

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let reply = Notifications.onMain(result)
    switch call.method {
    case "canNotify":
      center.permission { reply($0.allowsNotifying) }
    case "requestPermission":
      requestPermission(reply)
    case "configure":
      guard let config = Notifications.parseConfigure(call.arguments) else {
        return reply(FlutterError(code: Notifications.invalid, message: nil, details: nil))
      }
      configure(on: config.on, slots: config.slots, reply: reply)
    case "cancelDelivered":
      center.removeAllDelivered()
      reply(nil)
    case "setForeground":
      guard let visible = Notifications.exactBool(call.arguments) else {
        return reply(FlutterError(code: Notifications.invalid, message: nil, details: nil))
      }
      setForeground(visible)
      reply(nil)
    case "openSystemSettings":
      guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
        return reply(false)
      }
      application.open(url) { reply($0) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(_ reply: @escaping FlutterResult) {
    // Con otra petición en curso, «no concedido» sin diálogo (`NotificationsChannel.kt`).
    if requestInFlight { return reply(["granted": false, "dialogShown": false]) }
    requestInFlight = true
    center.permission { [weak self] current in
      guard let self else { return reply(["granted": false, "dialogShown": false]) }
      guard current.status == .notDetermined else {
        DispatchQueue.main.async { self.requestInFlight = false }
        return reply(["granted": current.allowsNotifying, "dialogShown": false])
      }
      self.center.requestAuthorization {
        self.center.permission { after in
          DispatchQueue.main.async { self.requestInFlight = false }
          reply(["granted": after.allowsNotifying, "dialogShown": true])
        }
      }
    }
  }

  /// Cancela lo pendiente y lo entregado (también al encender: CA-028-16) y programa cada aviso.
  private func configure(on: Bool, slots: [NotificationSlot], reply: @escaping FlutterResult) {
    center.removeAllPending()
    center.removeAllDelivered()
    guard on, !slots.isEmpty else { return reply(nil) }
    center.setCategories(Set(slots.indices.map { Notifications.category(slots[$0], index: $0) }))
    let group = DispatchGroup()
    let lock = NSLock()
    var allAdded = true
    for (index, slot) in slots.enumerated() {
      group.enter()
      center.add(Notifications.request(slot, index: index)) { added in
        lock.lock()
        allAdded = allAdded && added
        lock.unlock()
        group.leave()
      }
    }
    group.notify(queue: .main) {
      reply(allAdded ? nil : FlutterError(code: Notifications.failed, message: nil, details: nil))
    }
  }

  private func setForeground(_ visible: Bool) {
    foreground = visible
    dartListening = true
    if visible && pendingOpen {
      pendingOpen = false
      send?("openCurrentTask", nil)
    }
  }

  // MARK: - Avisos

  /// Una categoría por aviso: con «Mostrar previsualizaciones: si está desbloqueado» la pantalla de
  /// bloqueo enseña `publicBody` en vez de la tarea (CA-028-16, CA-019-17).
  static func category(_ slot: NotificationSlot, index: Int) -> UNNotificationCategory {
    return UNNotificationCategory(
      identifier: identifierPrefix + String(index), actions: [], intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: slot.publicBody, options: [])
  }

  /// A la hora del día, todos los días; sonido por defecto del sistema y sin insignia.
  static func request(_ slot: NotificationSlot, index: Int) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = slot.title
    content.body = slot.body
    content.sound = .default
    content.badge = nil
    content.threadIdentifier = threadIdentifier
    content.categoryIdentifier = identifierPrefix + String(index)
    var time = DateComponents()
    time.hour = slot.hour
    time.minute = slot.minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
    return UNNotificationRequest(
      identifier: identifierPrefix + String(index), content: content, trigger: trigger)
  }

  /// Con la app a la vista no se enseña nada (CA-019-19a); si no, como llegaría con la app cerrada.
  func presentationOptions(identifier: String) -> UNNotificationPresentationOptions {
    if foreground || !identifier.hasPrefix(Notifications.identifierPrefix) { return [] }
    return [.banner, .list, .sound]
  }

  /// Tocar un aviso propio abre la tarea actual (CA-019-20). Si Dart aún no oye el canal, se guarda
  /// un único aviso hasta el primer `setForeground(true)`.
  func opened(identifier: String, action: String) {
    guard action == UNNotificationDefaultActionIdentifier,
      identifier.hasPrefix(Notifications.identifierPrefix)
    else { return }
    if dartListening, let send {
      send("openCurrentTask", nil)
    } else {
      pendingOpen = true
    }
  }

  // MARK: - UNUserNotificationCenterDelegate (se pone en `didFinishLaunching`)

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let identifier = notification.request.identifier
    DispatchQueue.main.async { completionHandler(self.presentationOptions(identifier: identifier)) }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let identifier = response.notification.request.identifier
    let action = response.actionIdentifier
    DispatchQueue.main.async {
      self.opened(identifier: identifier, action: action)
      completionHandler()
    }
  }

  // MARK: - Argumentos (entrada no fiable, como `ChannelArguments.kt`)

  /// `{on: bool, slots: [{hour 0…23, minute 0…59, title, body, publicBody}]}` con 0…3 avisos y
  /// textos no vacíos; las claves de más se ignoran. Cualquier otra cosa es `nil`.
  static func parseConfigure(_ arguments: Any?) -> (on: Bool, slots: [NotificationSlot])? {
    guard let map = arguments as? [String: Any], let on = exactBool(map["on"]),
      let list = map["slots"] as? [Any], list.count <= maxSlots
    else { return nil }
    var slots: [NotificationSlot] = []
    for item in list {
      guard let entry = item as? [String: Any],
        let hour = exactInt(entry["hour"]), (0...23).contains(hour),
        let minute = exactInt(entry["minute"]), (0...59).contains(minute),
        let title = entry["title"] as? String, !title.isEmpty,
        let body = entry["body"] as? String, !body.isEmpty,
        let publicBody = entry["publicBody"] as? String, !publicBody.isEmpty
      else { return nil }
      slots.append(
        NotificationSlot(hour: hour, minute: minute, title: title, body: body, publicBody: publicBody))
    }
    return (on, slots)
  }

  /// Solo un booleano de verdad (`1` o `"true"` no valen): un `Bool` y un `Int` llegan como `NSNumber`.
  static func exactBool(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
      return nil
    }
    return number.boolValue
  }

  /// Solo un entero (ni booleano ni decimal).
  static func exactInt(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
      !CFNumberIsFloatType(number)
    else { return nil }
    return number.intValue
  }

  /// La respuesta, siempre en el hilo principal (contrato §0.4).
  private static func onMain(_ result: @escaping FlutterResult) -> FlutterResult {
    return { value in
      if Thread.isMainThread {
        result(value)
      } else {
        DispatchQueue.main.async { result(value) }
      }
    }
  }
}
