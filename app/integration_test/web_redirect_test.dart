// Redirecciones del servidor y respuestas que no son una página, con la WebView
// real y servidores locales de Dart (spec 009, T-009-12 y CL-009-1/4; spec 028,
// T-028-17, CA-028-19). Comprueba lo que lo nativo le dice a Dart:
// `mainFrameRequest` (si la petición del marco principal es una redirección del
// servidor, `takeServerRedirect`) y `downloadBlocked`. Lo que hace la app con
// ello (seguir la redirección, `BlockLocalAddress`, «no es una página») lo
// prueban `web_navigation_test` y `web_page_controller_test`.
//
// En http (sin TLS): una redirección es una redirección con o sin cifrar, y un
// certificado de pruebas de confianza en el simulador haría que CA-009-10
// (`web_flow_test`, «un certificado autofirmado nunca se acepta») dejara de
// fallar como debe. La redirección `http`→`https` solo necesita que se pida la
// dirección nueva (el certificado se rechaza después).
//
// En el emulador o en el simulador de iOS:
//   flutter test integration_test/web_redirect_test.dart -d emulator-5554
//   flutter test integration_test/web_redirect_test.dart -d <simulador>
import 'dart:async';
import 'dart:io';

import 'package:app/data/web/webview_hardening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const hardening = ChannelWebViewHardening();

/// **[Pendiente R-3, T-028-17]** En iOS, WebKit avisa de la redirección del
/// servidor después de pedir la decisión sobre la dirección nueva, así que la
/// opción (a) del contrato §3 no da el aviso a tiempo: hasta que el propietario
/// decida, `mainFrameRequest` va siempre con `redirect: false`.
final _redirectPending = Platform.isIOS;

/// Una WebView endurecida que deja pasar todo y apunta, por cada petición del
/// marco principal, su ruta y si lo nativo la dio como redirección.
class _Harness {
  _Harness() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  late final WebViewController controller;
  final requests = <(String, bool)>[];
  final finished = <String>[];
  final errors = <WebResourceError>[];

  int get id => switch (controller.platform) {
    final AndroidWebViewController android => android.webViewIdentifier,
    final WebKitWebViewController webKit => webKit.webViewIdentifier,
    final other => throw UnsupportedError('$other'),
  };

  Future<void> mount(WidgetTester tester) async {
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          if (r.isMainFrame) {
            final path = Uri.parse(r.url);
            requests.add((
              '${path.scheme}:${path.path}',
              hardening.takeServerRedirect(id),
            ));
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: finished.add,
        onWebResourceError: errors.add,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: WebViewWidget(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(await hardening.harden(id), isTrue);
  }
}

/// Un servidor http local con respuestas fijas por ruta.
Future<HttpServer> _serve(
  void Function(HttpRequest request, int port) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((r) => handler(r, server.port), onError: (_) {});
  addTearDown(() => server.close(force: true));
  return server;
}

void _redirect(HttpRequest r, String location) => r.response
  ..statusCode = HttpStatus.found
  ..headers.set(HttpHeaders.locationHeader, location)
  ..close();

void _html(HttpRequest r, String body) => r.response
  ..headers.contentType = ContentType.html
  ..write('<!doctype html><html><body>$body</body></html>')
  ..close();

Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Tiempo agotado: ${reason ?? ''}');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Las peticiones apuntadas, sin la de la propia carga de la app (en Android
/// `loadUrl` no pasa por `onNavigationRequest`; en iOS sí, sin redirección).
List<(String, bool)> _withoutOwnLoad(_Harness h, String own) =>
    h.requests.first == (own, false) ? h.requests.sublist(1) : h.requests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final events = <WebViewNativeEvent>[];
  late StreamSubscription<WebViewNativeEvent> sub;
  // Escuchar hace que `takeServerRedirect` apunte los avisos.
  setUpAll(() => sub = hardening.events.listen(events.add));
  tearDownAll(() => sub.cancel());
  setUp(events.clear);

  testWidgets('CA-028-19, T-009-12, CL-009-1: una redirección del servidor '
      'llega como tal (dos seguidas, también); la carga y una navegación de la '
      'página, no', (tester) async {
    final server = await _serve((r, port) {
      switch (r.uri.path) {
        case '/a':
          _redirect(r, '/b');
        case '/b':
          _redirect(r, 'http://127.0.0.1:$port/c');
        case '/c':
          _html(r, '<h1>C</h1><a id="d" href="/d">D</a>');
        default:
          _html(r, '<h1>D</h1>');
      }
    });
    final h = _Harness();
    await h.mount(tester);
    await h.controller.loadRequest(
      Uri.parse('http://127.0.0.1:${server.port}/a'),
    );
    await _until(
      tester,
      () => h.finished.any((u) => u.endsWith('/c')),
      reason: 'C',
    );
    expect(_withoutOwnLoad(h, 'http:/a'), [
      ('http:/b', true),
      ('http:/c', true),
    ]);

    // Un enlace de la página no es una redirección del servidor.
    h.requests.clear();
    await h.controller.runJavaScript("document.getElementById('d').click()");
    await _until(
      tester,
      () => h.finished.any((u) => u.endsWith('/d')),
      reason: 'D',
    );
    expect(h.requests, [('http:/d', false)]);
    // Sin avisos que se queden colgando para la petición siguiente.
    expect(hardening.takeServerRedirect(h.id), isFalse);
  }, skip: _redirectPending);

  testWidgets('CA-028-19, CA-009-09: una redirección del servidor de http a '
      'https llega como redirección (el certificado de pruebas se rechaza '
      'después)', (tester) async {
    final server = await _serve((r, port) {
      _redirect(r, 'https://127.0.0.1:$port/seguro');
    });
    final h = _Harness();
    await h.mount(tester);
    await h.controller.loadRequest(
      Uri.parse('http://127.0.0.1:${server.port}/x'),
    );
    await _until(
      tester,
      () => h.requests.any((r) => r.$1 == 'https:/seguro'),
      reason: 'https',
    );
    expect(_withoutOwnLoad(h, 'http:/x'), [('https:/seguro', true)]);
    await _wait(tester, const Duration(seconds: 1));
  }, skip: _redirectPending);

  testWidgets('CA-028-19, T-009-12: un location.href de la página antes de '
      'terminar de cargar no es una redirección del servidor', (tester) async {
    final server = await _serve((r, port) {
      if (r.uri.path == '/head') {
        _html(r, '<script>location.href = "/fuera";</script>');
      } else {
        _html(r, '<h1>Fuera</h1>');
      }
    });
    final h = _Harness();
    await h.mount(tester);
    await h.controller.loadRequest(
      Uri.parse('http://127.0.0.1:${server.port}/head'),
    );
    await _until(
      tester,
      () => h.finished.any((u) => u.endsWith('/fuera')),
      reason: 'fuera',
    );
    expect(_withoutOwnLoad(h, 'http:/head'), [('http:/fuera', false)]);
  });

  for (final (name, type, disposition) in [
    ('un PDF', 'application/pdf', null),
    ('un archivo binario', 'application/octet-stream', null),
    ('un documento de Office', 'application/msword', null),
    ('un HTML como adjunto', 'text/html', 'attachment; filename="a.html"'),
  ]) {
    testWidgets('CL-009-4, CA-028-19: $name en el marco principal no se '
        'muestra ni se descarga: downloadBlocked', (tester) async {
      final server = await _serve((r, _) {
        r.response.headers.set(HttpHeaders.contentTypeHeader, type);
        if (disposition != null) {
          r.response.headers.set('content-disposition', disposition);
        }
        r.response
          ..write(
            type == 'text/html' ? '<h1>Adjunto</h1>' : '%PDF-1.4\n%%EOF\n',
          )
          ..close();
      });
      final h = _Harness();
      await h.mount(tester);
      await h.controller.loadRequest(
        Uri.parse('http://127.0.0.1:${server.port}/archivo'),
      );
      await _until(
        tester,
        () => events.whereType<WebDownloadBlocked>().isNotEmpty,
        reason: 'downloadBlocked',
      );
      expect(events.whereType<WebDownloadBlocked>().single.webViewId, h.id);
      await _wait(tester, const Duration(seconds: 1));
      expect(h.finished.where((u) => u.endsWith('/archivo')), isEmpty);
    });
  }

  for (final (name, type) in [
    ('una página', 'text/html'),
    ('texto', 'text/plain'),
    ('una imagen', 'image/svg+xml'),
    ('JSON', 'application/json'),
  ]) {
    testWidgets('CL-009-4, CA-028-19: $name sí es una página (sin '
        'downloadBlocked)', (tester) async {
      final server = await _serve((r, _) {
        r.response.headers.set(HttpHeaders.contentTypeHeader, type);
        r.response
          ..write(switch (type) {
            'image/svg+xml' =>
              '<svg xmlns="http://www.w3.org/2000/svg" width="10" '
                  'height="10"></svg>',
            'application/json' => '{"a":1}',
            _ => '<h1>Hola</h1>',
          })
          ..close();
      });
      final h = _Harness();
      await h.mount(tester);
      await h.controller.loadRequest(
        Uri.parse('http://127.0.0.1:${server.port}/pagina'),
      );
      await _until(
        tester,
        () => h.finished.any((u) => u.endsWith('/pagina')),
        reason: 'página',
      );
      expect(events.whereType<WebDownloadBlocked>(), isEmpty);
    });
  }
}
