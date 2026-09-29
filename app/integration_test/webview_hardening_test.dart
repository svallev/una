// Endurecimiento nativo de la WebView de la tarea web (spec 009, T-009-09,
// ADR-0017). Sin red externa: páginas `data:` y `loadHtmlString`. En el
// emulador (nunca en el móvil del propietario sin su permiso):
//   flutter test integration_test/webview_hardening_test.dart -d emulator-5554
//
// Se repite en cada actualización de `webview_flutter_android` (R-21).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/data/web/web_data_janitor.dart';
import 'package:app/data/web/webview_hardening.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const hardening = ChannelWebViewHardening();

/// Página de prueba con un origen https (sin red: `loadDataWithBaseURL`).
const _page = '''
<!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
<body><h1>Una</h1></body></html>
''';
const _origin = 'https://una.test/';

/// Una WebView montada, con su delegado y lo que ha recibido.
class _Harness {
  _Harness(this.generation) {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  final int generation;
  late final WebViewController controller;
  final finished = <String>[];
  final requests = <String>[];

  int get id =>
      (controller.platform as AndroidWebViewController).webViewIdentifier;

  Future<void> setDelegate() => controller.setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (r) {
        requests.add(r.url);
        return NavigationDecision.navigate;
      },
      onPageFinished: finished.add,
    ),
  );
}

Future<void> _mount(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WebViewWidget(
        key: ValueKey(h.generation),
        controller: h.controller,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Espera (con fotogramas) a que se cumpla [done].
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Tiempo agotado');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _loadPage(WidgetTester tester, _Harness h) async {
  final before = h.finished.length;
  await h.controller.loadHtmlString(_page, baseUrl: _origin);
  await _until(tester, () => h.finished.length > before);
}

/// Resultado de [script] como texto, sin las comillas de JSON.
Future<String> _js(_Harness h, String script) async {
  final result = '${await h.controller.runJavaScriptReturningResult(script)}';
  return result.length >= 2 && result.startsWith('"') && result.endsWith('"')
      ? result.substring(1, result.length - 1)
      : result;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final events = <WebViewNativeEvent>[];
  late StreamSubscription<WebViewNativeEvent> sub;
  setUpAll(() => sub = hardening.events.listen(events.add));
  tearDownAll(() => sub.cancel());

  testWidgets('CA-009-13: ajustes leídos de vuelta y envoltorio puesto tras '
      'setNavigationDelegate (ADR-0017)', (tester) async {
    final h = _Harness(0);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    expect(await hardening.state(h.id), {
      'noFileAccess': true,
      'noContentAccess': true,
      'noFormData': true,
      'noMixedContent': true,
      'safeBrowsing': true,
      'noMultipleWindows': true,
      'wrapped': true,
    });
    // Idempotente: no envuelve dos veces.
    expect(await hardening.harden(h.id), isTrue);

    // Con el envoltorio, el delegado del paquete sigue recibiendo todo.
    await _loadPage(tester, h);
    expect(h.finished.last, _origin);

    // R-21: un setNavigationDelegate posterior quita el envoltorio; la
    // comprobación lo detecta y harden lo vuelve a poner.
    await h.setDelegate();
    expect((await hardening.state(h.id))!['wrapped'], isFalse);
    expect(await hardening.harden(h.id), isTrue);
  });

  testWidgets('CL-009-4: una descarga no descarga nada y avisa', (
    tester,
  ) async {
    final h = _Harness(1);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    events.clear();
    final pdf = base64.encode(utf8.encode('%PDF-1.4\n%%EOF\n'));
    await h.controller.loadRequest(
      Uri.parse('data:application/pdf;base64,$pdf'),
    );
    await _until(
      tester,
      () => events.whereType<WebDownloadBlocked>().isNotEmpty,
    );
    expect(events.whereType<WebDownloadBlocked>().single.webViewId, h.id);
    // Nada en Descargas ni en la carpeta de la app.
    final downloads = await getDownloadsDirectory();
    if (downloads != null && downloads.existsSync()) {
      expect(downloads.listSync(), isEmpty);
    }
  });

  testWidgets('CA-009-13: al salir y en el arranque se borran cookies, '
      'almacenamiento web y caché', (tester) async {
    final h = _Harness(2);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    await _loadPage(tester, h);
    await h.controller.runJavaScript(
      "document.cookie = 'una=1; max-age=3600; secure';"
      "localStorage.setItem('una', '1');",
    );
    await WebViewCookieManager().setCookie(
      const WebViewCookie(name: 'nativa', value: '1', domain: 'una.test'),
    );
    await _loadPage(tester, h);
    expect(await _js(h, 'document.cookie'), contains('una=1'));
    expect(await _js(h, 'document.cookie'), contains('nativa=1'));
    expect(await _js(h, "localStorage.getItem('una')"), '1');

    // Al salir de la tarea, con la WebView que se ve.
    expect(await hardening.clearWebData(webViewId: h.id), isTrue);
    await _loadPage(tester, h);
    expect(await _js(h, 'document.cookie'), isEmpty);
    expect(await _js(h, "localStorage.getItem('una')"), 'null');

    // En el arranque, con la marca y sin WebView (una temporal).
    final files = await getApplicationSupportDirectory();
    final marker = File('${files.path}/${WebDataJanitor.markerName}');
    final janitor = WebDataJanitor(
      filesDir: getApplicationSupportDirectory,
      cleaner: hardening,
    );
    await janitor.markUsed();
    expect(marker.existsSync(), isTrue);
    await h.controller.runJavaScript(
      "document.cookie = 'otra=1; max-age=3600; secure';"
      "localStorage.setItem('otra', '1');",
    );
    await tester.pumpWidget(const SizedBox()); // sale de la página
    await tester.pump(const Duration(milliseconds: 500));
    await janitor.clearAfterLaunch();
    expect(marker.existsSync(), isFalse);

    final again = _Harness(3);
    await again.setDelegate();
    await _mount(tester, again);
    expect(await hardening.harden(again.id), isTrue);
    await _loadPage(tester, again);
    expect(await _js(again, 'document.cookie'), isEmpty);
    expect(await _js(again, "localStorage.getItem('otra')"), 'null');
  });

  testWidgets('ADR-0017: chrome://crash no cierra la app; la WebView se '
      'destruye y otra nueva funciona', (tester) async {
    var h = _Harness(4);
    for (var round = 0; round < 2; round++) {
      await h.setDelegate();
      await _mount(tester, h);
      expect(await hardening.harden(h.id), isTrue);
      await _loadPage(tester, h);
      events.clear();
      await h.controller.loadRequest(Uri.parse('chrome://crash'));
      await _until(
        tester,
        () => events.whereType<WebRenderProcessGone>().any(
          (e) => e.webViewId == h.id,
        ),
      );
      // Todas las WebView de la app comparten el proceso de la página: avisan
      // todas las que sigan vivas (en la app solo hay una).
      final gone = events.whereType<WebRenderProcessGone>().firstWhere(
        (e) => e.webViewId == h.id,
      );
      expect(gone.crashed, isTrue);
      // La app sigue: se destruye la vieja y se monta otra. Solo **después**
      // del aviso (que tarda unos segundos): una WebView creada antes, aún sin
      // envoltorio, comparte el proceso que muere y Android cierra la app
      // (comprobado en el emulador, T-009-09).
      final old = h.id;
      h = _Harness(5 + round);
      await tester.pumpWidget(const SizedBox());
      await hardening.destroy(old);
      await tester.pump(const Duration(milliseconds: 500));
    }
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    await _loadPage(tester, h);
    expect(h.finished.last, _origin);
  });
}
