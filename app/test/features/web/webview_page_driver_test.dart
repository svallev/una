import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/features/web/web_page_driver.dart';
import 'package:app/features/web/webview_page_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  test('CA-009-08/09: los errores de la WebView se traducen para '
      'classifyLoadError', () {
    expect(
      webLoadErrorOf(WebResourceErrorType.hostLookup),
      WebLoadError.hostLookup,
    );
    expect(webLoadErrorOf(WebResourceErrorType.connect), WebLoadError.connect);
    expect(
      webLoadErrorOf(WebResourceErrorType.failedSslHandshake),
      WebLoadError.secureHandshake,
    );
    expect(webLoadErrorOf(WebResourceErrorType.timeout), WebLoadError.timeout);
    // Respuesta vacía (ERR_EMPTY_RESPONSE llega como `unknown`, comprobado en
    // el emulador) o conexión cortada (`io`).
    expect(
      webLoadErrorOf(WebResourceErrorType.unknown),
      WebLoadError.noResponse,
    );
    expect(webLoadErrorOf(WebResourceErrorType.io), WebLoadError.noResponse);
    for (final other in [
      null,
      WebResourceErrorType.unsafeResource,
      WebResourceErrorType.badUrl,
    ]) {
      expect(webLoadErrorOf(other), WebLoadError.other, reason: '$other');
    }
  });

  test('CA-009-09: con http:// y el intento https, un fallo de conexión o de '
      'TLS de la WebView es "sin conexión segura"; el DNS, "sin conexión"', () {
    WebLoadFailure? classify(WebResourceErrorType type) => classifyLoadError(
      webLoadErrorOf(type),
      isMainFrame: true,
      upgradedFromHttp: true,
    );
    expect(classify(WebResourceErrorType.connect), WebLoadFailure.insecure);
    expect(
      classify(WebResourceErrorType.failedSslHandshake),
      WebLoadFailure.insecure,
    );
    expect(classify(WebResourceErrorType.hostLookup), WebLoadFailure.offline);
  });

  test('CA-009-09: con http:// y el intento https, una respuesta vacía o una '
      'conexión cortada también es "sin conexión segura" (neverssl.com); '
      'Safe Browsing no', () {
    WebLoadFailure? classify(WebResourceErrorType type, {bool http = true}) =>
        classifyLoadError(
          webLoadErrorOf(type),
          isMainFrame: true,
          upgradedFromHttp: http,
        );
    expect(classify(WebResourceErrorType.unknown), WebLoadFailure.insecure);
    expect(classify(WebResourceErrorType.io), WebLoadFailure.insecure);
    expect(
      classify(WebResourceErrorType.unsafeResource),
      WebLoadFailure.offline,
    );
    // Con https:// guardada, "sin conexión" (con "Reintentar").
    expect(
      classify(WebResourceErrorType.unknown, http: false),
      WebLoadFailure.offline,
    );
  });

  test('CA-028-19, ADR-0017: en iOS el fallo del proceso de la página llega '
      'como error webContentProcessTerminated y es onProcessGone, no un error '
      'de carga', () {
    final listener = _RecordingListener();
    reportWebResourceError(
      listener,
      const WebResourceError(
        errorCode: 2,
        description: '',
        errorType: WebResourceErrorType.webContentProcessTerminated,
        isForMainFrame: true,
      ),
    );
    expect(listener.gone, [true]);
    expect(listener.errors, isEmpty);
  });

  test('CA-009-08/09: los demás errores siguen siendo errores de carga, con '
      'su marco y su dirección', () {
    final listener = _RecordingListener();
    reportWebResourceError(
      listener,
      const WebResourceError(
        errorCode: -1003,
        description: '',
        errorType: WebResourceErrorType.hostLookup,
        isForMainFrame: false,
        url: 'https://una.test/x.png',
      ),
    );
    // Sin marco (no lo dice la plataforma): se trata como el de la página.
    reportWebResourceError(
      listener,
      const WebResourceError(errorCode: -1, description: ''),
    );
    expect(listener.gone, isEmpty);
    expect(listener.errors, [
      (WebLoadError.hostLookup, false, Uri.parse('https://una.test/x.png')),
      (WebLoadError.other, true, null),
    ]);
  });
}

/// Solo apunta lo que le llega de los errores.
class _RecordingListener implements WebPageListener {
  final gone = <bool>[];
  final errors = <(WebLoadError, bool, Uri?)>[];

  @override
  void onProcessGone({required bool crashed}) => gone.add(crashed);

  @override
  void onLoadError(WebLoadError error, {required bool isMainFrame, Uri? url}) =>
      errors.add((error, isMainFrame, url));

  @override
  bool onNavigationRequest(
    Uri? url, {
    required bool isMainFrame,
    required bool isServerRedirect,
  }) => false;

  @override
  void onPageStarted(Uri url) {}

  @override
  void onPageFinished(Uri url) {}

  @override
  void onProgress(int percent) {}

  @override
  void onCertificateError() {}

  @override
  void onDownloadBlocked() {}
}
