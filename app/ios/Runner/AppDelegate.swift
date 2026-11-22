import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Canales de plataforma (`UnaChannels`); viven tanto como el motor.
  private var channels: [FlutterMethodChannel] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
      messenger: engineBridge.applicationRegistrar.messenger(), webView: webView)
    // CA-028-18: `attachments/` creada y fuera de la copia de seguridad antes del primer fotograma.
    DataAtRest.prepareAttachmentsAtLaunch()
  }
}
