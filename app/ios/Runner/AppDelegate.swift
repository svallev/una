import Flutter
import UIKit
import UserNotifications
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Canales de plataforma (`UnaChannels`); viven tanto como el motor.
  private var channels: [FlutterMethodChannel] = []
  /// `una/notifications`: también es el delegado del centro de notificaciones (contrato §4).
  private let notifications = Notifications()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Antes de que iOS entregue el toque que abrió la app (contrato §4).
    UNUserNotificationCenter.current().delegate = notifications
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // `una/webview` busca la `WKWebView` del paquete por su identificador (contrato §3).
    let webViews = engineBridge.pluginRegistry.registrar(forPlugin: "UnaWebViewHardening")
    let webView = WebViewHardening(lookup: { id in
      guard let registrar = webViews else { return nil }
      return FWFWebViewFlutterWKWebViewExternalAPI.webView(
        forIdentifier: id, withPluginRegistrar: registrar)
    })
    channels = UnaChannels.register(
      messenger: engineBridge.applicationRegistrar.messenger(), webView: webView,
      notifications: notifications)
    // CA-028-18: `attachments/` creada y fuera de la copia de seguridad antes del primer fotograma.
    DataAtRest.prepareAttachmentsAtLaunch()
    // R2 (028): los datos de la WebView (`Library/WebKit`, `Library/Cookies`), fuera de la copia.
    DataAtRest.prepareWebDataNow()
    // S-B2 (028): copias de PDF elegidas y sin usar que dejó una sesión anterior en `tmp/*-Inbox`.
    Images.purgeDocumentInboxes()
  }
}
