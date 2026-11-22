import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../data/web/webview_hardening.dart';
import '../../domain/entities/web_load_failure.dart';
import 'web_page_driver.dart';

/// La WebView de la tarea web con `webview_flutter` (spec 009, plan §1): la
/// `WebView` de Android y la `WKWebView` de iOS (spec 028, CA-028-19). Cada
/// instancia es una WebView nativa.
///
/// Endurecimiento desde Dart (T-4, CA-009-13): JavaScript sí, pero sin ningún
/// canal JS; permisos de la página denegados (también la geolocalización);
/// diálogos JS descartados sin mostrar nada; sin selector de archivos (en iOS,
/// el script de usuario de `harden`); sin pantalla completa en Android (el
/// callback se pasa siempre: si no, el paquete pone el suyo; en iOS el vídeo
/// puede ir a la pantalla completa nativa, diferencia aceptada, contrato §3); y los mensajes de la consola de la página no llegan al registro del
/// sistema (CL-009-9). Lo nativo, con `ChannelWebViewHardening.harden`,
/// **después** de `setNavigationDelegate`, que no se vuelve a llamar
/// (ADR-0017). En iOS el fallo del proceso de la página no llega por el canal
/// sino como el error `webContentProcessTerminated` del paquete
/// ([reportWebResourceError]).
///
/// En iOS, WebKit pasa también las cargas de la propia app (`loadRequest`,
/// `loadHtmlString`) por `onNavigationRequest`, como una petición del marco
/// principal sin redirección, y ADR-0018 las bloquearía; en Android `loadUrl`
/// no pasa por ahí. Por eso cada carga propia ([loadOwnRequest],
/// [loadOwnHtml]) se apunta y la **primera** petición del marco principal que
/// coincide se deja pasar sin preguntar al `WebPageListener` ([OwnLoadGate];
/// propietario, 2026-11-20, spec 028).
class WebViewPageDriver implements WebPageDriver {
  WebViewPageDriver({
    ChannelWebViewHardening hardening = const ChannelWebViewHardening(),
  }) : _native = hardening,
       webView = WebViewController(onPermissionRequest: (r) => r.deny());

  final ChannelWebViewHardening _native;

  /// El controlador del paquete. Solo para los tests de integración.
  @visibleForTesting
  final WebViewController webView;

  StreamSubscription<WebViewNativeEvent>? _events;
  bool _delegateSet = false;

  /// Solo en iOS (ver la clase).
  late final OwnLoadGate? _ownLoads = _webKit != null ? OwnLoadGate() : null;

  AndroidWebViewController? get _android {
    final platform = webView.platform;
    return platform is AndroidWebViewController ? platform : null;
  }

  WebKitWebViewController? get _webKit {
    final platform = webView.platform;
    return platform is WebKitWebViewController ? platform : null;
  }

  @override
  int? get nativeId =>
      _android?.webViewIdentifier ?? _webKit?.webViewIdentifier;

  @override
  Future<bool> attach(WebPageListener listener) async {
    try {
      await webView.setJavaScriptMode(JavaScriptMode.unrestricted);
      await webView.setOnJavaScriptAlertDialog((_) async {});
      await webView.setOnJavaScriptConfirmDialog((_) async => false);
      await webView.setOnJavaScriptTextInputDialog((_) async => '');
      await webView.setOnConsoleMessage((_) {});
      final android = _android;
      if (android != null) {
        await android.setOnShowFileSelector((_) async => const <String>[]);
        await android.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (_) async =>
              const GeolocationPermissionsResponse(allow: false, retain: false),
        );
        await android.setCustomWidgetCallbacks(
          onShowCustomWidget: (_, hide) => hide(),
          onHideCustomWidget: () {},
        );
      }
      final id = nativeId;
      await _events?.cancel();
      _events = _native.events
          .where((e) => e.webViewId == id)
          .listen(
            (e) => switch (e) {
              WebRenderProcessGone(:final crashed) => listener.onProcessGone(
                crashed: crashed,
              ),
              WebDownloadBlocked() => listener.onDownloadBlocked(),
            },
          );
      // El delegado, una sola vez (si antes fue bien): uno posterior quitaría
      // el envoltorio del cliente y el bloqueo de descargas (ADR-0017).
      if (!_delegateSet) {
        await webView.setNavigationDelegate(_delegate(listener));
        _delegateSet = true;
      }
      if (id == null) return false;
      return await _native.harden(id);
    } on Object {
      // Sin registrar nada (CL-009-9): sin endurecer no se carga.
      return false;
    }
  }

  NavigationDelegate _delegate(WebPageListener listener) => NavigationDelegate(
    onNavigationRequest: (request) {
      // El paquete no dice si es una redirección del servidor: lo avisa
      // justo antes el envoltorio del cliente (T-009-12).
      final id = nativeId;
      final serverRedirect = id != null && _native.takeServerRedirect(id);
      final url = Uri.tryParse(request.url);
      if (_ownLoads?.take(url, isMainFrame: request.isMainFrame) ?? false) {
        return NavigationDecision.navigate;
      }
      return listener.onNavigationRequest(
            url,
            isMainFrame: request.isMainFrame,
            isServerRedirect: serverRedirect,
          )
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    },
    onPageStarted: (url) {
      final uri = Uri.tryParse(url);
      if (uri != null) listener.onPageStarted(uri);
    },
    onPageFinished: (url) {
      final uri = Uri.tryParse(url);
      if (uri != null) listener.onPageFinished(uri);
    },
    onProgress: listener.onProgress,
    onWebResourceError: (error) => reportWebResourceError(listener, error),
    onSslAuthError: (error) {
      // Nunca se acepta (CA-009-10).
      unawaited(error.cancel());
      listener.onCertificateError();
    },
  );

  @override
  Future<void> load(Uri url) => loadOwnRequest(url);

  @override
  Future<void> stop() => loadOwnRequest(Uri.parse('about:blank'));

  /// Carga [url] en el marco principal como carga de la propia app (en iOS
  /// no la decide el `WebPageListener`). Los tests de integración que sirven
  /// sus páginas en local también cargan por aquí.
  @protected
  Future<void> loadOwnRequest(Uri url) {
    _ownLoads?.expect(url);
    return webView.loadRequest(url);
  }

  /// Carga [html] con el origen [baseUrl], como carga propia (solo los tests
  /// de integración, que no tienen red).
  @protected
  Future<void> loadOwnHtml(String html, Uri baseUrl) {
    _ownLoads?.expect(baseUrl);
    return webView.loadHtmlString(html, baseUrl: baseUrl.toString());
  }

  @override
  Future<void> destroy() async {
    _ownLoads?.clear();
    final id = nativeId;
    if (id != null) await _native.destroy(id);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _events = null;
  }

  @override
  Widget buildView({Key? key}) {
    final android = _android;
    if (android == null) return WebViewWidget(key: key, controller: webView);
    // Composición híbrida (plan §1).
    return WebViewWidget.fromPlatformCreationParams(
      key: key,
      params: AndroidWebViewWidgetCreationParams(
        controller: android,
        displayWithHybridComposition: true,
      ),
    );
  }
}

/// La carga propia pendiente de una WebView de iOS (ver [WebViewPageDriver]):
/// la primera petición del marco principal a la misma dirección es la suya y
/// pasa; cualquier otra (de otro marco, a otra dirección, o una segunda a la
/// misma, que ya sería de la página) sigue la regla de ADR-0018.
@visibleForTesting
class OwnLoadGate {
  Uri? _pending;

  /// La app va a cargar [url] (sustituye a la anterior, si no llegó).
  void expect(Uri url) => _pending = url;

  void clear() => _pending = null;

  /// Si la petición a [url] es la carga propia pendiente; si lo es, la gasta.
  bool take(Uri? url, {required bool isMainFrame}) {
    final pending = _pending;
    if (!isMainFrame || url == null || pending == null) return false;
    if (_canonical(url) != _canonical(pending)) return false;
    _pending = null;
    return true;
  }

  /// La dirección tal como la compara: WebKit devuelve `https://una.test` como
  /// `https://una.test/` y puede cambiar el escape de la ruta.
  static String _canonical(Uri u) {
    String decoded(String s) {
      try {
        return Uri.decodeFull(s);
      } on FormatException {
        return s;
      }
    }

    final scheme = u.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return decoded(u.toString());
    final path = u.path.isEmpty ? '/' : u.path;
    return '$scheme://${u.host.toLowerCase()}:${u.port}${decoded(path)}'
        '?${decoded(u.query)}#${decoded(u.fragment)}';
  }
}

/// Un error de la WebView para [listener]. En iOS el fallo del proceso de la
/// página (`webViewWebContentProcessDidTerminate`) llega así, como el error
/// `webContentProcessTerminated` del paquete, y es [WebPageListener.onProcessGone]
/// (ADR-0017, contrato §3): WebKit no dice si lo mató el sistema, así que
/// `crashed: true`. Lo demás es un error de carga.
@visibleForTesting
void reportWebResourceError(WebPageListener listener, WebResourceError error) {
  if (error.errorType == WebResourceErrorType.webContentProcessTerminated) {
    listener.onProcessGone(crashed: true);
    return;
  }
  final domain = error is WebKitWebResourceError ? error.domain : null;
  final WebLoadError type;
  if (domain != null) {
    final webKit = webKitLoadErrorOf(error.errorCode, domain);
    if (webKit == null) return;
    type = webKit;
  } else {
    type = webLoadErrorOf(error.errorType);
  }
  listener.onLoadError(
    type,
    // Android siempre lo dice; si no, se trata como de la página.
    isMainFrame: error.isForMainFrame ?? true,
    url: error.url == null ? null : Uri.tryParse(error.url!),
  );
}

/// El error de la WebView, para `classifyLoadError` (T-009-05).
WebLoadError webLoadErrorOf(WebResourceErrorType? type) => switch (type) {
  WebResourceErrorType.hostLookup => WebLoadError.hostLookup,
  WebResourceErrorType.connect => WebLoadError.connect,
  WebResourceErrorType.failedSslHandshake => WebLoadError.secureHandshake,
  WebResourceErrorType.timeout => WebLoadError.timeout,
  // `ERR_EMPTY_RESPONSE` llega como `unknown`; un corte, como `io`.
  WebResourceErrorType.unknown ||
  WebResourceErrorType.io => WebLoadError.noResponse,
  _ => WebLoadError.other,
};

/// El error de WebKit (iOS) por su dominio y código, para `classifyLoadError`;
/// null si no es un error de carga y no se avisa (CA-028-19). El paquete solo
/// traduce los de `WKErrorDomain`; los de red llegan como `NSURLErrorDomain`.
/// - `NSURLErrorCancelled` (-999): una navegación sustituida por otra (la carga
///   de la app, `stop`); en Android no llega como error.
/// - `WebKitErrorFrameLoadInterruptedByPolicyChange` (102): una navegación o
///   una respuesta cancelada por la app (una descarga ya avisada con
///   `downloadBlocked`, una petición bloqueada por ADR-0018); en Android
///   tampoco es un error.
@visibleForTesting
WebLoadError? webKitLoadErrorOf(int code, String domain) {
  switch (domain) {
    case 'NSURLErrorDomain':
      return switch (code) {
        -999 => null,
        // Sin dominio o sin red: «sin conexión», nunca «no segura».
        -1003 || -1006 || -1009 || -1018 || -1020 => WebLoadError.hostLookup,
        -1004 => WebLoadError.connect,
        -1001 => WebLoadError.timeout,
        // Conexión cortada o respuesta vacía o ilegible.
        -1005 || -1011 || -1015 || -1016 || -1017 => WebLoadError.noResponse,
        -1200 => WebLoadError.secureHandshake,
        -1201 ||
        -1202 ||
        -1203 ||
        -1204 ||
        -1205 ||
        -1206 => WebLoadError.certificate,
        _ => WebLoadError.other,
      };
    case 'WebKitErrorDomain':
      return code == 102 ? null : WebLoadError.other;
    default:
      return WebLoadError.other;
  }
}

/// La WebView de la plataforma (`web_page_driver_factory.dart`).
WebPageDriver createWebPageDriver() => WebViewPageDriver();
