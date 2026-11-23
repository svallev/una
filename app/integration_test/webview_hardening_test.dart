// Endurecimiento nativo de la WebView de la tarea web (spec 009, T-009-09,
// ADR-0017; en iOS, spec 028, CA-028-19). Sin red externa: páginas `data:` y
// `loadHtmlString`. En el emulador (nunca en el móvil del propietario sin su
// permiso) o en el simulador de iOS:
//   flutter test integration_test/webview_hardening_test.dart -d emulator-5554
//   flutter test integration_test/webview_hardening_test.dart -d <simulador>
//
// Se repite en cada actualización de `webview_flutter_android` (R-21) y de
// `webview_flutter_wkwebview`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/data/web/web_data_janitor.dart';
import 'package:app/data/web/webview_hardening.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const hardening = ChannelWebViewHardening();

/// Página de prueba con un origen https (sin red: `loadDataWithBaseURL`).
const _page = '''
<!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
<body><h1>Una</h1></body></html>
''';
const _origin = 'https://una.test/';

/// Un campo de archivo arriba a la izquierda, su etiqueta y un botón; apunta
/// en `window.seen` cada clic que ve la página.
const _filePage = '''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<script>
window.seen = [];
document.addEventListener('click', function (e) {
  window.seen.push(e.target.id || e.target.tagName);
}, true);
</script></head><body style="margin:0">
<input type="file" id="archivo" style="display:block;width:300px;height:150px">
<label for="archivo" id="etiqueta">Elegir</label>
<button id="boton">Botón</button>
</body></html>
''';

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

  /// En iOS, las veces que el paquete avisó del fallo del proceso de la página
  /// (el error `webContentProcessTerminated`, contrato §3).
  var contentProcessGone = 0;

  int get id => switch (controller.platform) {
    final AndroidWebViewController android => android.webViewIdentifier,
    final WebKitWebViewController webKit => webKit.webViewIdentifier,
    final other => throw UnsupportedError('$other'),
  };

  Future<void> setDelegate() => controller.setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (r) {
        requests.add(r.url);
        return NavigationDecision.navigate;
      },
      onPageFinished: finished.add,
      onWebResourceError: (e) {
        if (e.errorType == WebResourceErrorType.webContentProcessTerminated) {
          contentProcessGone++;
        }
      },
    ),
  );
}

/// Mata el proceso de la página de [h] como solo puede hacerlo una prueba: en
/// Android, `chrome://crash`; en iOS, el gancho de depuración del Swift
/// (`debugKillContentProcess`, solo en Debug).
Future<void> _crash(_Harness h) => Platform.isIOS
    ? const MethodChannel('una/webview')
          .invokeMethod<void>('debugKillContentProcess', {'id': h.id})
    : h.controller.loadRequest(Uri.parse('chrome://crash'));

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
/// En iOS un `null` de JavaScript llega como `<null>` (`NSNull`): se da como en
/// Android, `null`.
Future<String> _js(_Harness h, String script) async {
  final raw = '${await h.controller.runJavaScriptReturningResult(script)}';
  final result = raw == '<null>' ? 'null' : raw;
  return result.length >= 2 && result.startsWith('"') && result.endsWith('"')
      ? result.substring(1, result.length - 1)
      : result;
}

/// Una dirección IPv4 del dispositivo que no es de bucle local, o null.
Future<InternetAddress?> _nonLoopbackIPv4() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  for (final i in interfaces) {
    for (final a in i.addresses) {
      if (!a.isLoopback && !a.isLinkLocal) return a;
    }
  }
  return null;
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
      'noDarkening': true,
      'wrapped': true,
    });
    // Idempotente: no envuelve dos veces.
    expect(await hardening.harden(h.id), isTrue);

    // Con el envoltorio, el delegado del paquete sigue recibiendo todo.
    await _loadPage(tester, h);
    expect(h.finished.last, _origin);

    // R-21: un setNavigationDelegate posterior quita el envoltorio (en iOS,
    // el `NavigationWatcher`, contrato §3); la comprobación lo detecta y
    // harden lo vuelve a poner.
    await h.setDelegate();
    expect((await hardening.state(h.id))!['wrapped'], isFalse);
    expect(await hardening.harden(h.id), isTrue);
    expect((await hardening.state(h.id))!['wrapped'], isTrue);
  });

  testWidgets('CA-009-13, CA-028-19: un <input type=file> no abre el selector '
      'de archivos (ni con un toque, ni con click(), ni con showPicker())', (
    tester,
  ) async {
    final h = _Harness(12);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    final before = h.finished.length;
    await h.controller.loadHtmlString(_filePage, baseUrl: _origin);
    await _until(tester, () => h.finished.length > before);
    // Un toque real sobre el campo (en Android el selector ya lo corta
    // `setOnShowFileSelector` en Dart; en iOS, el script de `harden`).
    await tester.tapAt(const Offset(100, 60));
    await tester.pump(const Duration(milliseconds: 800));
    await h.controller.runJavaScript(
      "document.getElementById('archivo').click();"
      "document.getElementById('etiqueta').click();"
      "document.getElementById('boton').click();"
      "try { document.getElementById('archivo').showPicker();"
      " window.picker = 'abierto'; } catch (e) { window.picker = e.name; }",
    );
    await tester.pump(const Duration(milliseconds: 500));
    if (Platform.isIOS) {
      // La página no ve ningún clic en el campo de archivo (ni el del toque ni
      // el que la etiqueta le pasa); los de la etiqueta y el botón, sí.
      expect(await _js(h, "window.seen.join(',')"), 'etiqueta,boton');
      expect(await _js(h, 'window.picker'), 'NotAllowedError');
    }
    // Sigue la página a la vista, sin el selector encima.
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(await _js(h, 'document.visibilityState'), 'visible');
  });

  testWidgets('CA-009-13, CA-028-19: tampoco con un campo de archivo que la '
      'página no inserta, en un iframe about:blank, en un shadow root cerrado '
      'o con dispatchEvent (S-M2 de la 028)', (tester) async {
    final h = _Harness(13);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    await _loadPage(tester, h);
    // Cada caso, en su propia llamada (`evaluateJavaScript` cuenta como gesto
    // del usuario, así que el campo pediría el selector de verdad).
    const cases = {
      'campo insertado':
          "var i = document.createElement('input'); i.type = 'file';"
          ' document.body.appendChild(i); i.click();',
      'campo sin insertar, click()':
          "var i = document.createElement('input'); i.type = 'file';"
          ' i.click();',
      'campo sin insertar, dispatchEvent':
          "var i = document.createElement('input'); i.type = 'file';"
          " i.dispatchEvent(new MouseEvent('click'));",
      'campo sin insertar, showPicker()':
          "var i = document.createElement('input'); i.type = 'file';"
          ' try { i.showPicker(); } catch (e) {}',
      'etiqueta sin insertar':
          "var l = document.createElement('label');"
          " l.innerHTML = '<input type=file>'; l.click();",
      'etiqueta sin insertar, dispatchEvent':
          "var l = document.createElement('label');"
          " l.innerHTML = '<input type=file>';"
          " l.dispatchEvent(new MouseEvent('click'));",
      'shadow root cerrado':
          "var d = document.createElement('div');"
          ' document.body.appendChild(d);'
          " var r = d.attachShadow({mode: 'closed'});"
          " r.innerHTML = '<input type=file id=s>';"
          " r.getElementById('s').click();",
      // El clic que la etiqueta pasa a su campo no se ve desde `window`.
      'etiqueta en un shadow root cerrado':
          "var d = document.createElement('div');"
          ' document.body.appendChild(d);'
          " var r = d.attachShadow({mode: 'closed'});"
          " r.innerHTML = '<label>L<input type=file></label>';"
          " r.querySelector('label').click();",
      'iframe about:blank':
          "var f = document.createElement('iframe');"
          ' document.body.appendChild(f); var d = f.contentDocument;'
          " d.body.innerHTML = '<input type=file id=x>';"
          " d.getElementById('x').click();",
      'iframe about:blank, campo sin insertar':
          "var f = document.createElement('iframe');"
          ' document.body.appendChild(f);'
          " var i = f.contentDocument.createElement('input');"
          " i.type = 'file'; i.click();",
      'iframe about:blank, showPicker()':
          "var f = document.createElement('iframe');"
          ' document.body.appendChild(f); var d = f.contentDocument;'
          " d.body.innerHTML = '<input type=file id=x>';"
          " try { d.getElementById('x').showPicker(); } catch (e) {}",
      'funciones de otro marco':
          "var f = document.createElement('iframe');"
          ' document.body.appendChild(f); var w = f.contentWindow;'
          " var i = document.createElement('input'); i.type = 'file';"
          ' w.HTMLElement.prototype.click.call(i);'
          " w.EventTarget.prototype.dispatchEvent.call(i, new MouseEvent('click'));"
          ' try { w.HTMLInputElement.prototype.showPicker.call(i); }'
          ' catch (e) {}',
      'iframe srcdoc':
          "var f = document.createElement('iframe');"
          " f.srcdoc = '<input type=file id=y><script>"
          "document.getElementById(\"y\").click()<\\/script>';"
          ' document.body.appendChild(f);',
    };
    for (final MapEntry(key: name, value: js) in cases.entries) {
      await h.controller.runJavaScript('(function () { $js })();');
      await tester.pump(const Duration(milliseconds: 900));
      if (Platform.isIOS) {
        // Las veces que la página llegó a pedir el selector a WebKit (que,
        // desde iOS 18.4, corta el `FilePanelBlocker`): 0 = lo cortó el
        // script, que es lo único que hay en iOS 16–18.3 (contrato §3).
        final asked = await const MethodChannel('una/webview')
            .invokeMethod<int>('debugOpenPanelRequests', {'id': h.id});
        expect(asked, 0, reason: name);
      }
    }
    // Sigue la página a la vista, sin el selector encima.
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(await _js(h, 'document.visibilityState'), 'visible');
  });

  testWidgets('CA-021-08, CA-028-05: con el sistema en oscuro, la página se ve '
      'en su versión clara', (tester) async {
    final h = _Harness(10);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    await _loadPage(tester, h);
    // Lo comprueba con el sistema en claro o en oscuro: la página nunca ve
    // `prefers-color-scheme: dark` (el simulador se pone en oscuro con
    // `xcrun simctl ui <id> appearance dark`).
    expect(
      await _js(h, "matchMedia('(prefers-color-scheme: dark)').matches"),
      anyOf('false', '0'),
    );
    expect(
      await _js(h, "matchMedia('(prefers-color-scheme: light)').matches"),
      anyOf('true', '1'),
    );
  });

  testWidgets('CA-009-13: una página https no carga contenido por http '
      '(contenido mixto)', (tester) async {
    // Un servidor en el propio dispositivo apunta lo que le llega: una
    // petición en claro empieza por el método («GET »). En una dirección que
    // no es de bucle local: `http://127.0.0.1` cuenta como origen de confianza
    // y no es contenido mixto (comprobado en el simulador de iOS).
    final address = await _nonLoopbackIPv4();
    if (address == null) {
      markTestSkipped('sin una interfaz de red que no sea de bucle local');
      return;
    }
    final server = await ServerSocket.bind(address, 0);
    final plain = <String>[];
    var connections = 0;
    server.listen((socket) {
      connections++;
      socket.listen((data) {
        final head = String.fromCharCodes(data.take(4));
        if (head == 'GET ' || head == 'POST') plain.add(head);
        socket.destroy();
      }, onError: (_) {});
    });
    addTearDown(server.close);
    final h = _Harness(11);
    await h.setDelegate();
    await _mount(tester, h);
    expect(await hardening.harden(h.id), isTrue);
    final before = h.finished.length;
    final port = server.port;
    await h.controller.loadHtmlString(
      '<!doctype html><html><body><h1>Una</h1>'
      '<img src="http://${address.address}:$port/a.png">'
      '<script src="http://${address.address}:$port/b.js"></script>'
      '</body></html>',
      baseUrl: _origin,
    );
    await _until(tester, () => h.finished.length > before);
    final end = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(plain, isEmpty, reason: 'conexiones: $connections');
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
      await _crash(h);
      if (Platform.isIOS) {
        // En iOS lo avisa el delegado del paquete, no el canal (contrato §3).
        await _until(tester, () => h.contentProcessGone > 0);
        expect(events.whereType<WebRenderProcessGone>(), isEmpty);
      } else {
        await _until(
          tester,
          () => events.whereType<WebRenderProcessGone>().any(
            (e) => e.webViewId == h.id,
          ),
        );
        // Todas las WebView de la app comparten el proceso de la página:
        // avisan todas las que sigan vivas (en la app solo hay una).
        final gone = events.whereType<WebRenderProcessGone>().firstWhere(
          (e) => e.webViewId == h.id,
        );
        expect(gone.crashed, isTrue);
      }
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
