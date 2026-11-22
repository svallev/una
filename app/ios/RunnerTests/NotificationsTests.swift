import Flutter
import UIKit
import UserNotifications
import XCTest

@testable import Runner

/// Centro de notificaciones de mentira: guarda lo que se le pide, en orden, y contesta lo que el
/// test decida (en el hilo que diga `replyOnBackground`).
private final class FakeNotificationCenter: NotificationCenterClient {
  var current = NotificationPermission(status: .authorized, alert: .enabled)
  /// Lo que valdrá el permiso tras el diálogo.
  var afterDialog = NotificationPermission(status: .authorized, alert: .enabled)
  var addSucceeds = true
  var replyOnBackground = false
  /// Si no es `nil`, `requestAuthorization` no contesta hasta llamarla.
  var holdDialog: (() -> Void)?
  var holdDialogs = false

  private(set) var log: [String] = []
  private(set) var added: [UNNotificationRequest] = []
  private(set) var categories: Set<UNNotificationCategory> = []
  private(set) var dialogs = 0

  private func reply(_ body: @escaping () -> Void) {
    if replyOnBackground {
      DispatchQueue.global().async(execute: body)
    } else {
      body()
    }
  }

  func permission(_ completion: @escaping (NotificationPermission) -> Void) {
    log.append("permission")
    let value = current
    reply { completion(value) }
  }

  func requestAuthorization(_ completion: @escaping () -> Void) {
    log.append("requestAuthorization")
    dialogs += 1
    let finish = { [self] in
      current = afterDialog
      reply(completion)
    }
    if holdDialogs { holdDialog = finish } else { finish() }
  }

  func setCategories(_ categories: Set<UNNotificationCategory>) {
    log.append("setCategories")
    self.categories = categories
  }

  func removeAllPending() { log.append("removeAllPending") }

  func removeAllDelivered() { log.append("removeAllDelivered") }

  func add(_ request: UNNotificationRequest, completion: @escaping (Bool) -> Void) {
    log.append("add")
    added.append(request)
    let ok = addSucceeds
    reply { completion(ok) }
  }
}

/// Abre de mentira (para `openSystemSettings`).
private final class FakeOpener: LinkApplication {
  var result = true
  private(set) var opened: [URL] = []
  func canOpenURL(_ url: URL) -> Bool { true }
  func open(_ url: URL, completion: @escaping (Bool) -> Void) {
    opened.append(url)
    completion(result)
  }
}

/// `una/notifications` en iOS (contrato §4, ADR-0030; CA-028-15 y 16): programa los avisos que
/// Dart manda ya escritos, quita los entregados al reprogramar, `on: false` cancela todo, errores
/// sin texto y nada guardado.
class NotificationsTests: XCTestCase {

  private let slot0: [String: Any] = [
    "hour": 8, "minute": 55, "title": "Tu tarea", "body": "Llamar a Marta",
    "publicBody": "Tienes una tarea pendiente.",
  ]
  private let slot1: [String: Any] = [
    "hour": 13, "minute": 55, "title": "Tu tarea", "body": "Llamar a Marta",
    "publicBody": "Tienes una tarea pendiente.",
  ]
  private let slot2: [String: Any] = [
    "hour": 18, "minute": 55, "title": "Tu tarea", "body": "Llamar a Marta",
    "publicBody": "Tienes una tarea pendiente.",
  ]

  /// Llama y espera la respuesta (que puede llegar en el siguiente giro del hilo principal).
  private func call(
    _ channel: Notifications, _ method: String, _ arguments: Any? = nil,
    file: StaticString = #filePath, line: UInt = #line
  ) -> Any? {
    let answered = expectation(description: method)
    var answer: Any?
    var onMain = false
    channel.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      answer = $0
      onMain = Thread.isMainThread
      answered.fulfill()
    }
    wait(for: [answered], timeout: 5)
    XCTAssertTrue(onMain, "la respuesta va en el hilo principal (contrato §0.4)", file: file, line: line)
    return answer
  }

  private func assertBareError(
    _ answer: Any?, _ code: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard let error = answer as? FlutterError else {
      return XCTFail("se esperaba un error, llegó \(String(describing: answer))", file: file, line: line)
    }
    XCTAssertEqual(error.code, code, file: file, line: line)
    XCTAssertNil(error.message, "sin texto (CA-019-23)", file: file, line: line)
    XCTAssertNil(error.details, "sin texto (CA-019-23)", file: file, line: line)
  }

  private func isNull(_ answer: Any?) -> Bool { answer == nil || answer is NSNull }

  // MARK: - configure

  func testConfigureSchedulesWhatDartSentAtTheTimeOfDay() {
    // CA-028-16: un aviso por elemento, a la hora del día y todos los días, con los textos de Dart.
    let center = FakeNotificationCenter()
    let channel = Notifications(center: center)
    let answer = call(channel, "configure", ["on": true, "slots": [slot0, slot1, slot2]])
    XCTAssertTrue(isNull(answer))
    XCTAssertEqual(center.added.count, 3)
    let expected = [(8, 55), (13, 55), (18, 55)]
    for (index, request) in center.added.enumerated() {
      XCTAssertEqual(request.identifier, "current-task-\(index)")
      guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
        return XCTFail("disparador de calendario")
      }
      XCTAssertTrue(trigger.repeats)
      XCTAssertEqual(trigger.dateComponents.hour, expected[index].0)
      XCTAssertEqual(trigger.dateComponents.minute, expected[index].1)
      XCTAssertNil(trigger.dateComponents.day, "todos los días")
      XCTAssertEqual(request.content.title, "Tu tarea")
      XCTAssertEqual(request.content.body, "Llamar a Marta")
      XCTAssertEqual(request.content.threadIdentifier, "current-task")
      XCTAssertEqual(request.content.categoryIdentifier, "current-task-\(index)")
    }
  }

  func testDefaultSoundAndNoBadge() {
    // CA-028-16: sin sonido propio (el del sistema) ni insignia.
    let center = FakeNotificationCenter()
    _ = call(Notifications(center: center), "configure", ["on": true, "slots": [slot0]])
    let content = center.added[0].content
    XCTAssertEqual(content.sound, UNNotificationSound.default)
    XCTAssertNil(content.badge)
  }

  func testLockScreenPlaceholderIsThePublicBody() {
    // CA-028-16 y CA-019-17: con previsualizaciones ocultas, el texto genérico en vez de la tarea.
    let center = FakeNotificationCenter()
    var other = slot1
    other["publicBody"] = "You have a pending task."
    _ = call(Notifications(center: center), "configure", ["on": true, "slots": [slot0, other]])
    let byId = Dictionary(uniqueKeysWithValues: center.categories.map { ($0.identifier, $0) })
    XCTAssertEqual(byId["current-task-0"]?.hiddenPreviewsBodyPlaceholder, "Tienes una tarea pendiente.")
    XCTAssertEqual(byId["current-task-1"]?.hiddenPreviewsBodyPlaceholder, "You have a pending task.")
    XCTAssertEqual(center.categories.count, 2)
  }

  func testReschedulingClearsPendingAndDeliveredFirst() {
    // CA-028-16: `on: true` también quita las entregadas (el texto viejo de la tarea) antes de programar.
    let center = FakeNotificationCenter()
    let channel = Notifications(center: center)
    _ = call(channel, "configure", ["on": true, "slots": [slot0, slot1]])
    _ = call(channel, "configure", ["on": true, "slots": [slot0]])
    XCTAssertEqual(
      center.log,
      [
        "removeAllPending", "removeAllDelivered", "setCategories", "add", "add",
        "removeAllPending", "removeAllDelivered", "setCategories", "add",
      ])
  }

  func testOffCancelsEverything() {
    // CA-028-16: al apagar, el texto de la tarea sale de la programación en ese momento.
    let center = FakeNotificationCenter()
    let answer = call(Notifications(center: center), "configure", ["on": false, "slots": []])
    XCTAssertTrue(isNull(answer))
    XCTAssertEqual(center.log, ["removeAllPending", "removeAllDelivered"])
    XCTAssertTrue(center.added.isEmpty)
  }

  func testOffWithSlotsStillSchedulesNothing() {
    let center = FakeNotificationCenter()
    _ = call(Notifications(center: center), "configure", ["on": false, "slots": [slot0]])
    XCTAssertTrue(center.added.isEmpty)
  }

  func testNoTasksCancelsEverything() {
    // CA-019-10: sin tareas (lista vacía) no queda nada programado ni entregado.
    let center = FakeNotificationCenter()
    let answer = call(Notifications(center: center), "configure", ["on": true, "slots": []])
    XCTAssertTrue(isNull(answer))
    XCTAssertEqual(center.log, ["removeAllPending", "removeAllDelivered"])
  }

  func testInvalidArgumentsAnswerWithoutTextAndTouchNothing() {
    // Contrato §0.1 y §4: entrada no fiable; `invalid_argument` sin mensaje ni detalles.
    var badHour = slot0
    badHour["hour"] = 24
    var negativeMinute = slot0
    negativeMinute["minute"] = -1
    var bigMinute = slot0
    bigMinute["minute"] = 60
    var boolHour = slot0
    boolHour["hour"] = true
    var doubleHour = slot0
    doubleHour["hour"] = 8.5
    var textHour = slot0
    textHour["hour"] = "8"
    var noTitle = slot0
    noTitle.removeValue(forKey: "title")
    var emptyBody = slot0
    emptyBody["body"] = ""
    var emptyTitle = slot0
    emptyTitle["title"] = ""
    var emptyPublic = slot0
    emptyPublic["publicBody"] = ""
    var numberPublic = slot0
    numberPublic["publicBody"] = 3
    let cases: [Any?] = [
      nil, "configure", ["slots": [slot0]], ["on": true], ["on": 1, "slots": [slot0]],
      ["on": "true", "slots": [slot0]], ["on": true, "slots": slot0],
      ["on": true, "slots": [slot0, slot1, slot2, slot0]], ["on": true, "slots": ["x"]],
      ["on": true, "slots": [badHour]], ["on": true, "slots": [negativeMinute]],
      ["on": true, "slots": [bigMinute]], ["on": true, "slots": [boolHour]],
      ["on": true, "slots": [doubleHour]], ["on": true, "slots": [textHour]],
      ["on": true, "slots": [noTitle]], ["on": true, "slots": [emptyBody]],
      ["on": true, "slots": [emptyTitle]], ["on": true, "slots": [emptyPublic]],
      ["on": true, "slots": [numberPublic]], ["on": false, "slots": [badHour]],
    ]
    for arguments in cases {
      let center = FakeNotificationCenter()
      assertBareError(
        call(Notifications(center: center), "configure", arguments), "invalid_argument")
      XCTAssertTrue(center.log.isEmpty, "\(String(describing: arguments)) no toca el centro")
    }
  }

  func testExtraKeysAreIgnoredLikeKotlin() {
    let center = FakeNotificationCenter()
    var extra = slot0
    extra["lang"] = "es"
    let answer = call(
      Notifications(center: center), "configure", ["on": true, "slots": [extra], "perDay": 3])
    XCTAssertTrue(isNull(answer))
    XCTAssertEqual(center.added.count, 1)
  }

  func testAFailedAddIsFailedWithoutText() {
    // Contrato §4: cualquier otro fallo es `failed`, sin texto.
    let center = FakeNotificationCenter()
    center.addSucceeds = false
    assertBareError(
      call(Notifications(center: center), "configure", ["on": true, "slots": [slot0]]), "failed")
  }

  func testAnswersOnTheMainThreadWhenTheCenterRepliesFromAnother() {
    // Contrato §0.4 (lo comprueba `call`).
    let center = FakeNotificationCenter()
    center.replyOnBackground = true
    let channel = Notifications(center: center)
    XCTAssertTrue(isNull(call(channel, "configure", ["on": true, "slots": [slot0, slot1]])))
    XCTAssertEqual(call(channel, "canNotify") as? Bool, true)
  }

  // MARK: - Permiso

  func testCanNotifyNeedsAuthorizationAndAlerts() {
    // CA-019-03 y contrato §4: autorizada (o provisional, efímera) y con los avisos activos.
    let cases: [(UNAuthorizationStatus, UNNotificationSetting, Bool)] = [
      (.authorized, .enabled, true), (.provisional, .enabled, true), (.ephemeral, .enabled, true),
      (.authorized, .disabled, false), (.authorized, .notSupported, false),
      (.denied, .enabled, false), (.notDetermined, .enabled, false), (.denied, .disabled, false),
    ]
    for (status, alert, expected) in cases {
      let center = FakeNotificationCenter()
      center.current = NotificationPermission(status: status, alert: alert)
      XCTAssertEqual(
        call(Notifications(center: center), "canNotify") as? Bool, expected, "\(status) \(alert)")
    }
  }

  func testRequestPermissionShowsTheDialogOnlyWhenUndetermined() {
    // CA-019-01 y 02 (P5): el diálogo, solo si nunca se preguntó.
    let center = FakeNotificationCenter()
    center.current = NotificationPermission(status: .notDetermined, alert: .notSupported)
    let answer = call(Notifications(center: center), "requestPermission") as? [String: Bool]
    XCTAssertEqual(answer, ["granted": true, "dialogShown": true])
    XCTAssertEqual(center.dialogs, 1)

    let refused = FakeNotificationCenter()
    refused.current = NotificationPermission(status: .notDetermined, alert: .notSupported)
    refused.afterDialog = NotificationPermission(status: .denied, alert: .disabled)
    XCTAssertEqual(
      call(Notifications(center: refused), "requestPermission") as? [String: Bool],
      ["granted": false, "dialogShown": true])
  }

  func testRequestPermissionWithoutDialogAnswersWhatTheSystemSays() {
    // CA-019-04: bloqueadas, sin diálogo; ya concedidas, tampoco.
    for (permission, granted) in [
      (NotificationPermission(status: .denied, alert: .disabled), false),
      (NotificationPermission(status: .authorized, alert: .enabled), true),
      (NotificationPermission(status: .authorized, alert: .disabled), false),
    ] {
      let center = FakeNotificationCenter()
      center.current = permission
      XCTAssertEqual(
        call(Notifications(center: center), "requestPermission") as? [String: Bool],
        ["granted": granted, "dialogShown": false])
      XCTAssertEqual(center.dialogs, 0)
    }
  }

  func testASecondRequestWhileTheDialogIsOpenIsRefused() {
    // Como `NotificationsChannel.kt`: con otra petición en curso, `{false, false}`.
    let center = FakeNotificationCenter()
    center.current = NotificationPermission(status: .notDetermined, alert: .notSupported)
    center.holdDialogs = true
    let channel = Notifications(center: center)
    let first = expectation(description: "first")
    var firstAnswer: Any?
    channel.handle(FlutterMethodCall(methodName: "requestPermission", arguments: nil)) {
      firstAnswer = $0
      first.fulfill()
    }
    XCTAssertEqual(
      call(channel, "requestPermission") as? [String: Bool], ["granted": false, "dialogShown": false])
    center.holdDialog?()
    wait(for: [first], timeout: 5)
    XCTAssertEqual(firstAnswer as? [String: Bool], ["granted": true, "dialogShown": true])
    XCTAssertEqual(center.dialogs, 1)
    // Terminada la primera, se puede volver a pedir.
    let next = expectation(description: "free")
    DispatchQueue.main.async { next.fulfill() }
    wait(for: [next], timeout: 5)
    XCTAssertEqual(
      call(channel, "requestPermission") as? [String: Bool], ["granted": true, "dialogShown": false])
  }

  func testOpenSystemSettingsOpensTheNotificationSettingsOfTheApp() {
    // CA-019-04: el botón lleva a los ajustes de notificaciones de la app.
    let opener = FakeOpener()
    let channel = Notifications(center: FakeNotificationCenter(), application: opener)
    XCTAssertEqual(call(channel, "openSystemSettings") as? Bool, true)
    XCTAssertEqual(opener.opened, [URL(string: UIApplication.openNotificationSettingsURLString)!])
    opener.result = false
    XCTAssertEqual(call(channel, "openSystemSettings") as? Bool, false)
  }

  func testCancelDeliveredRemovesOnlyTheDelivered() {
    // CA-019-19b: al abrir la app se quita lo mostrado; lo programado sigue.
    let center = FakeNotificationCenter()
    XCTAssertTrue(isNull(call(Notifications(center: center), "cancelDelivered")))
    XCTAssertEqual(center.log, ["removeAllDelivered"])
  }

  // MARK: - A la vista y al tocar

  func testNothingIsShownWithTheAppInView() {
    // CA-019-19a: con la app a la vista no se notifica.
    let channel = Notifications(center: FakeNotificationCenter())
    XCTAssertTrue(isNull(call(channel, "setForeground", true)))
    XCTAssertEqual(channel.presentationOptions(identifier: "current-task-0"), [])
    XCTAssertTrue(isNull(call(channel, "setForeground", false)))
    XCTAssertEqual(
      channel.presentationOptions(identifier: "current-task-0"), [.banner, .list, .sound])
    XCTAssertEqual(channel.presentationOptions(identifier: "otra-0"), [])
  }

  func testSetForegroundOnlyTakesABool() {
    let channel = Notifications(center: FakeNotificationCenter())
    for argument: Any? in [nil, 1, "true", ["on": true]] {
      assertBareError(call(channel, "setForeground", argument), "invalid_argument")
    }
    XCTAssertTrue(channel.foreground, "sigue como estaba")
  }

  func testTappingOwnNotificationOpensTheCurrentTask() {
    // CA-019-20: tocar un aviso propio abre la tarea actual, sin datos.
    let messenger = RecordingMessenger()
    let channel = Notifications(center: FakeNotificationCenter())
    let channels = UnaChannels.register(messenger: messenger, notifications: channel)
    defer { withExtendedLifetime(channels) {} }
    XCTAssertTrue(isNull(call(channel, "setForeground", true)))
    channel.opened(identifier: "current-task-1", action: UNNotificationDefaultActionIdentifier)
    XCTAssertEqual(messenger.sent.count, 1)
    XCTAssertEqual(messenger.sent.first?.channel, "una/notifications")
    XCTAssertEqual(messenger.sent.first?.call.method, "openCurrentTask")
    XCTAssertTrue(isNull(messenger.sent.first?.call.arguments))
  }

  func testOtherNotificationsOrDismissDoNothing() {
    let messenger = RecordingMessenger()
    let channel = Notifications(center: FakeNotificationCenter())
    let channels = UnaChannels.register(messenger: messenger, notifications: channel)
    defer { withExtendedLifetime(channels) {} }
    _ = call(channel, "setForeground", true)
    channel.opened(identifier: "otra-cosa", action: UNNotificationDefaultActionIdentifier)
    channel.opened(identifier: "current-task-0", action: UNNotificationDismissActionIdentifier)
    XCTAssertTrue(messenger.sent.isEmpty)
    XCTAssertFalse(channel.pendingOpen)
  }

  func testATapBeforeDartListensWaitsForTheFirstForeground() {
    // Contrato §4 [Suposición]: en frío, el toque espera al primer `setForeground(true)`, una vez.
    let messenger = RecordingMessenger()
    let channel = Notifications(center: FakeNotificationCenter())
    let channels = UnaChannels.register(messenger: messenger, notifications: channel)
    defer { withExtendedLifetime(channels) {} }
    channel.opened(identifier: "current-task-0", action: UNNotificationDefaultActionIdentifier)
    channel.opened(identifier: "current-task-0", action: UNNotificationDefaultActionIdentifier)
    XCTAssertTrue(messenger.sent.isEmpty)
    _ = call(channel, "setForeground", false)
    XCTAssertTrue(messenger.sent.isEmpty)
    _ = call(channel, "setForeground", true)
    _ = call(channel, "setForeground", true)
    XCTAssertEqual(messenger.sent.map(\.call.method), ["openCurrentTask"])
  }

  func testTheCenterDelegateIsSetWhenTheAppLaunches() {
    // Contrato §4: el delegado, en `didFinishLaunching` (antes de que iOS entregue el toque).
    XCTAssertTrue(UNUserNotificationCenter.current().delegate is Notifications)
    let source = try? String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Runner/AppDelegate.swift"),
      encoding: .utf8)
    guard let source,
      let launch = source.range(of: "didFinishLaunchingWithOptions"),
      let delegate = source.range(of: "UNUserNotificationCenter.current().delegate = notifications"),
      let superCall = source.range(of: "super.application(application, didFinishLaunchingWithOptions")
    else { return XCTFail("AppDelegate.swift sin el delegado") }
    XCTAssertTrue(launch.upperBound < delegate.lowerBound && delegate.upperBound < superCall.lowerBound)
  }

  // MARK: - Con el centro real del simulador

  /// Todo lo que la app tiene en disco (ruta, tamaño y fecha), salvo cachés y temporales del sistema.
  private func diskSnapshot() -> [String: String] {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    var snapshot: [String: String] = [:]
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
    guard let walker = FileManager.default.enumerator(at: home, includingPropertiesForKeys: keys)
    else { return snapshot }
    for case let url as URL in walker {
      let path = String(url.path.dropFirst(home.path.count))
      if path.hasPrefix("/Library/Caches") || path.hasPrefix("/tmp") { continue }
      let values = try? url.resourceValues(forKeys: Set(keys))
      snapshot[path] =
        "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }
    return snapshot
  }

  private func realCenter<T>(_ body: (@escaping (T) -> Void) -> Void) -> T? {
    let done = expectation(description: "centro")
    var value: T?
    body {
      value = $0
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
    return value
  }

  private func pendingIds() -> [String]? {
    realCenter { done in
      UNUserNotificationCenter.current().getPendingNotificationRequests { done($0.map(\.identifier)) }
    }
  }

  private func deliveredIds() -> [String]? {
    realCenter { done in
      UNUserNotificationCenter.current().getDeliveredNotifications {
        done($0.map(\.request.identifier))
      }
    }
  }

  /// Delegado espía: apunta lo que llega y lo que decide el delegado de la app, y deja la
  /// notificación en la lista para poder comprobar que reprogramar la quita.
  private final class SpyDelegate: NSObject, UNUserNotificationCenterDelegate {
    let app: Notifications
    var arrived: [(id: String, title: String, body: String, options: UNNotificationPresentationOptions)] = []
    var onArrival: (() -> Void)?
    init(app: Notifications) { self.app = app }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      app.userNotificationCenter(center, willPresent: notification) { options in
        let request = notification.request
        self.arrived.append((request.identifier, request.content.title, request.content.body, options))
        completionHandler([.list])
        self.onArrival?()
      }
    }
  }

  func testANearTimeProgrammedThroughTheChannelArrivesAndNothingIsSaved() throws {
    // CA-028-15 y 16 con el centro real del simulador: lo programado por el canal llega a su hora
    // con los textos de Dart, con la app a la vista no se enseña (CA-019-19a), reprogramar quita lo
    // entregado, apagar no deja nada y la app no guarda nada (ni `UserDefaults` ni archivos).
    let center = UNUserNotificationCenter.current()
    // Sin diálogo: la autorización provisional basta para que iOS acepte y entregue (solo en el test;
    // deja el simulador así, por eso conviene uno aparte).
    let status: UNAuthorizationStatus? = realCenter { done in
      center.getNotificationSettings { done($0.authorizationStatus) }
    }
    if status == .notDetermined {
      _ = realCenter { done in center.requestAuthorization(options: [.provisional]) { ok, _ in done(ok) } }
    }
    // Los clones de las pruebas en paralelo a veces rechazan toda programación («Source is not authorized»,
    // aun con la autorización provisional): ahí no se puede comprobar la llegada.
    let accepted: Bool? = realCenter { done in
      let content = UNMutableNotificationContent()
      content.title = "probe"
      content.body = "probe"
      let probe = UNNotificationRequest(
        identifier: "probe", content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false))
      center.add(probe) { done($0 == nil) }
    }
    center.removePendingNotificationRequests(withIdentifiers: ["probe"])
    if accepted != true {
      throw XCTSkip(
        "Este simulador no deja programar avisos (clon de pruebas en paralelo o denegadas): "
          + "correr con -parallel-testing-enabled NO en un simulador aparte")
    }

    let original = center.delegate
    let channel = Notifications()
    let spy = SpyDelegate(app: channel)
    center.delegate = spy
    defer { center.delegate = original }
    _ = call(channel, "setForeground", true)

    let domain = Bundle.main.bundleIdentifier ?? ""
    let defaultsBefore = UserDefaults.standard.persistentDomain(forName: domain) as NSDictionary?
    let diskBefore = diskSnapshot()
    let soon = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(60))
    var slot = slot0
    slot["hour"] = soon.hour!
    slot["minute"] = soon.minute!
    let arrived = expectation(description: "llega")
    spy.onArrival = { arrived.fulfill() }
    let first = call(channel, "configure", ["on": true, "slots": [slot]])
    XCTAssertTrue(isNull(first), "configure: \(String(describing: (first as? FlutterError)?.code))")
    // La siguiente vez que el reloj marque esa hora y minuto: en menos de un minuto.
    wait(for: [arrived], timeout: 75)
    XCTAssertEqual(spy.arrived.first?.id, "current-task-0")
    XCTAssertEqual(spy.arrived.first?.title, "Tu tarea")
    XCTAssertEqual(spy.arrived.first?.body, "Llamar a Marta")
    XCTAssertEqual(spy.arrived.first?.options, [], "a la vista no se enseña")
    XCTAssertEqual(deliveredIds(), ["current-task-0"])

    // Reprogramar (encendido) quita la entregada con el texto viejo.
    XCTAssertTrue(isNull(call(channel, "configure", ["on": true, "slots": [slot0]])))
    XCTAssertEqual(deliveredIds(), [])
    XCTAssertEqual(pendingIds(), ["current-task-0"])

    XCTAssertTrue(isNull(call(channel, "configure", ["on": false, "slots": []])))
    XCTAssertEqual(pendingIds(), [], "apagado no queda nada programado")
    XCTAssertEqual(UserDefaults.standard.persistentDomain(forName: domain) as NSDictionary?, defaultsBefore)
    XCTAssertEqual(diskSnapshot(), diskBefore)
  }

  func testSourceSavesNothing() {
    // CA-028-16: ni `UserDefaults`, ni archivos, ni registro en el canal.
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Runner/Notifications.swift")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
      return XCTFail("sin Notifications.swift")
    }
    // Solo el código: los comentarios pueden nombrar lo que no se usa.
    let source = text.split(separator: "\n")
      .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
      .joined(separator: "\n")
    for forbidden in [
      "UserDefaults", "FileManager", "write(to", "NSLog", "print(", "os_log", "Logger",
    ] {
      XCTAssertFalse(source.contains(forbidden), "Notifications.swift usa \(forbidden)")
    }
  }
}
