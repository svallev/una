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

  test('CA-028-19, CA-009-08/09/10: los errores de red de WebKit (iOS) se '
      'traducen por su código; los de una navegación sustituida o cancelada '
      'por la app no son errores', () {
    const url = 'NSURLErrorDomain';
    for (final (code, expected) in [
      (-1003, WebLoadError.hostLookup),
      (-1006, WebLoadError.hostLookup),
      (-1009, WebLoadError.hostLookup),
      (-1004, WebLoadError.connect),
      (-1001, WebLoadError.timeout),
      (-1005, WebLoadError.noResponse),
      (-1011, WebLoadError.noResponse),
      (-1017, WebLoadError.noResponse),
      (-1200, WebLoadError.secureHandshake),
      (-1202, WebLoadError.certificate),
      (-1203, WebLoadError.certificate),
      (-1100, WebLoadError.other),
    ]) {
      expect(webKitLoadErrorOf(code, url), expected, reason: '$code');
    }
    expect(webKitLoadErrorOf(-999, url), isNull);
    expect(webKitLoadErrorOf(102, 'WebKitErrorDomain'), isNull);
    expect(webKitLoadErrorOf(101, 'WebKitErrorDomain'), WebLoadError.other);
    expect(webKitLoadErrorOf(-999, 'WKErrorDomain'), WebLoadError.other);
    // Sin red en un http:// intentado como https: «sin conexión», no «no
    // segura»; sin servidor, «no segura».
    WebLoadFailure? http(int code) => classifyLoadError(
      webKitLoadErrorOf(code, url)!,
      isMainFrame: true,
      upgradedFromHttp: true,
    );
    expect(http(-1009), WebLoadFailure.offline);
    expect(http(-1004), WebLoadFailure.insecure);
  });

  group('OwnLoadGate (iOS: la carga de la propia app pasa por '
      'onNavigationRequest)', () {
    final saved = Uri.parse('https://una.test/programa');

    test('CA-028-19, CA-009-11: la primera petición del marco principal a la '
        'dirección que carga la app pasa; una segunda a la misma dirección, '
        'hecha ya por la página, no', () {
      final gate = OwnLoadGate()..expect(saved);
      expect(gate.take(saved, isMainFrame: true), isTrue);
      expect(gate.take(saved, isMainFrame: true), isFalse);
    });

    test('CA-028-19, CA-009-11: otra dirección, otro marco o ninguna carga '
        'pendiente siguen ADR-0018 (y no gastan la carga pendiente)', () {
      final gate = OwnLoadGate();
      expect(gate.take(saved, isMainFrame: true), isFalse);
      gate.expect(saved);
      expect(gate.take(saved, isMainFrame: false), isFalse);
      expect(
        gate.take(Uri.parse('https://una.test/otra'), isMainFrame: true),
        isFalse,
      );
      expect(
        gate.take(Uri.parse('http://una.test/programa'), isMainFrame: true),
        isFalse,
      );
      expect(
        gate.take(
          Uri.parse('https://una.test/programa?a=1'),
          isMainFrame: true,
        ),
        isFalse,
      );
      expect(gate.take(null, isMainFrame: true), isFalse);
      expect(gate.take(saved, isMainFrame: true), isTrue);
    });

    test('CA-028-19: la dirección tal como la devuelve WebKit (barra final, '
        'mayúsculas en el dominio, escapes) es la misma carga', () {
      final gate = OwnLoadGate()..expect(Uri.parse('https://una.test'));
      expect(
        gate.take(Uri.parse('https://UNA.test/'), isMainFrame: true),
        isTrue,
      );
      gate.expect(Uri.parse('https://una.test/a~b%20c'));
      expect(
        gate.take(Uri.parse('https://una.test/a%7Eb%20c'), isMainFrame: true),
        isTrue,
      );
      gate.expect(Uri.parse('about:blank'));
      expect(gate.take(Uri.parse('about:blank'), isMainFrame: true), isTrue);
    });

    test('CA-028-19: una carga nueva sustituye a la pendiente y clear la '
        'olvida', () {
      final other = Uri.parse('https://una.test/otra');
      final gate = OwnLoadGate()
        ..expect(saved)
        ..expect(other);
      expect(gate.take(saved, isMainFrame: true), isFalse);
      expect(gate.take(other, isMainFrame: true), isTrue);
      gate
        ..expect(saved)
        ..clear();
      expect(gate.take(saved, isMainFrame: true), isFalse);
    });
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
