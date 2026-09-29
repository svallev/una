import 'package:app/domain/entities/web_load_failure.dart';
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
    for (final other in [
      null,
      WebResourceErrorType.unknown,
      WebResourceErrorType.unsafeResource,
      WebResourceErrorType.io,
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
}
