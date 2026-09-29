import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../data/web/webview_hardening.dart';
import '../../domain/entities/web_load_failure.dart';
import 'web_page_driver.dart';

/// La WebView de la tarea web con `webview_flutter` (spec 009, plan §1; solo
/// Android por ahora, D17). Cada instancia es una WebView nativa.
///
/// Endurecimiento desde Dart (T-4, CA-009-13): JavaScript sí, pero sin ningún
/// canal JS; permisos de la página denegados (también la geolocalización);
/// diálogos JS descartados sin mostrar nada; sin selector de archivos; sin
/// pantalla completa (el callback se pasa siempre: si no, el paquete pone el
/// suyo); y los mensajes de la consola de la página no llegan al registro del
/// sistema (CL-009-9). Lo nativo, con `ChannelWebViewHardening.harden`,
/// **después** de `setNavigationDelegate`, que no se vuelve a llamar
/// (ADR-0017).
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

  AndroidWebViewController? get _android {
    final platform = webView.platform;
    return platform is AndroidWebViewController ? platform : null;
  }

  @override
  int? get nativeId => _android?.webViewIdentifier;

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
    onNavigationRequest: (request) =>
        listener.onNavigationRequest(
          Uri.tryParse(request.url),
          isMainFrame: request.isMainFrame,
        )
        ? NavigationDecision.navigate
        : NavigationDecision.prevent,
    onPageStarted: (url) {
      final uri = Uri.tryParse(url);
      if (uri != null) listener.onPageStarted(uri);
    },
    onPageFinished: (url) {
      final uri = Uri.tryParse(url);
      if (uri != null) listener.onPageFinished(uri);
    },
    onProgress: listener.onProgress,
    onWebResourceError: (error) => listener.onLoadError(
      webLoadErrorOf(error.errorType),
      // Android siempre lo dice; si no, se trata como de la página.
      isMainFrame: error.isForMainFrame ?? true,
    ),
    onSslAuthError: (error) {
      // Nunca se acepta (CA-009-10).
      unawaited(error.cancel());
      listener.onCertificateError();
    },
  );

  @override
  Future<void> load(Uri url) => webView.loadRequest(url);

  @override
  Future<void> stop() => webView.loadRequest(Uri.parse('about:blank'));

  @override
  Future<void> destroy() async {
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

/// La WebView de la plataforma (`web_page_driver_factory.dart`).
WebPageDriver createWebPageDriver() => WebViewPageDriver();
