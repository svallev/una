// Estado de la página de la tarea web con la WebView real (spec 009, T-009-10,
// ADR-0017). Sin red externa: la página de `una.test` se sirve con
// `loadHtmlString` (origen https ficticio) y el resto son direcciones locales.
// En el emulador (nunca en el móvil del propietario sin su permiso):
//   flutter test integration_test/web_page_controller_test.dart -d emulator-5554
//
// Se repite en cada actualización de `webview_flutter_android` (R-21).
import 'dart:convert';
import 'dart:io';

import 'package:app/data/web/web_data_janitor.dart';
import 'package:app/data/web/webview_hardening.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/features/web/web_page_controller.dart';
import 'package:app/features/web/webview_page_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const hardening = ChannelWebViewHardening();

const _page = '''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<title>Una</title></head>
<body><h1>Una</h1><div style="height:3000px"></div><h2 id="b">B</h2></body></html>
''';

/// Si no es null, la página de `una.test` (en lugar de [_page]).
String? _pageOverride;

/// La WebView real, pero las páginas de `una.test` salen de [_page].
class _LocalPageDriver extends WebViewPageDriver {
  @override
  Future<void> load(Uri url) => url.host == 'una.test'
      ? webView.loadHtmlString(_pageOverride ?? _page, baseUrl: url.toString())
      : super.load(url);
}

/// Monta la vista de la WebView actual (con la clave de su generación) y la
/// carga tras el primer fotograma, como la pantalla de la tarea (T-009-11).
class _Host extends StatefulWidget {
  const _Host(this.controller);
  final WebPageController controller;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.controller.start(),
    );
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.controller,
    builder: (context, state, _) =>
        widget.controller.driver.buildView(key: ValueKey(state.viewGeneration)),
  );
}

final _drivers = <_LocalPageDriver>[];

Future<WebPageController> _mount(WidgetTester tester, String address) async {
  final controller = WebPageController(
    address: Uri.parse(address),
    createDriver: () {
      final d = _LocalPageDriver();
      _drivers.add(d);
      return d;
    },
    janitor: WebDataJanitor(
      filesDir: getApplicationSupportDirectory,
      cleaner: hardening,
    ),
    clock: const SystemClock(),
  );
  await tester.pumpWidget(MaterialApp(home: _Host(controller)));
  return controller;
}

Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Tiempo agotado');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool _loaded(WebPageController c) =>
    c.value.status == WebPageStatus.shown && !c.value.pageLoading;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    _drivers.clear();
    _pageOverride = null;
  });

  testWidgets('CA-009-07, CA-009-13: carga la dirección guardada en una '
      'WebView endurecida, con la marca escrita', (tester) async {
    final c = await _mount(tester, 'https://una.test/programa');
    await _until(tester, () => _loaded(c));
    expect(c.value.pageUrl, Uri.parse('https://una.test/programa'));
    final id = c.driver.nativeId!;
    expect((await hardening.state(id))!.values.every((v) => v), isTrue);
    final files = await getApplicationSupportDirectory();
    expect(
      File('${files.path}/${WebDataJanitor.markerName}').existsSync(),
      isTrue,
    );
    await _unmount(tester);
  });

  testWidgets('CA-009-11: vista la página, un enlace a otra no carga nada y '
      'un ancla de la misma página sí', (tester) async {
    final c = await _mount(tester, 'https://una.test/programa');
    await _until(tester, () => _loaded(c));
    final web = _drivers.last.webView;
    Future<String> js(String script) async =>
        '${await web.runJavaScriptReturningResult(script)}';
    await web.runJavaScript('window.una = 7;');
    await web.runJavaScript("location.href = 'https://una.test/otra';");
    await tester.pump(const Duration(seconds: 2));
    // Sigue el mismo documento, en la misma dirección.
    expect(await js('window.una'), '7');
    expect(await js('location.href'), '"https://una.test/programa"');
    expect(c.value.status, WebPageStatus.shown);
    await web.runJavaScript("location.href = '#b';");
    await tester.pump(const Duration(seconds: 1));
    expect(await js('location.href'), '"https://una.test/programa#b"');
    expect(await js('window.una'), '7');
    expect(c.value.status, WebPageStatus.shown);
    await _unmount(tester);
  });

  testWidgets('CA-009-08/09: sin servidor, https es "sin conexión" y http '
      '(intentado como https) es "sin conexión segura"', (tester) async {
    var c = await _mount(tester, 'https://127.0.0.1:49999/');
    await _until(tester, () => c.value.status == WebPageStatus.offline);
    await _unmount(tester);
    c = await _mount(tester, 'http://127.0.0.1:49999/');
    await _until(tester, () => c.value.status == WebPageStatus.insecure);
    await _unmount(tester);
  });

  // Un servidor en el propio dispositivo que corta la conexión sin responder
  // (al aceptarla o tras leer el saludo TLS): nunca la página en blanco.
  // La respuesta vacía tras el TLS (ERR_EMPTY_RESPONSE, neverssl.com) no se
  // puede servir aquí sin un certificado válido; su traducción la cubren
  // `webview_page_driver_test` y `web_page_controller_test`.
  for (final readFirst in [false, true]) {
    testWidgets('CA-009-08/09: el servidor corta la conexión sin responder '
        '(${readFirst ? 'tras leer' : 'al aceptar'}): https es "sin '
        'conexión" y http, "sin conexión segura"', (tester) async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) {
        if (!readFirst) {
          socket.destroy();
          return;
        }
        socket.listen((_) => socket.destroy(), onError: (_) {});
      });
      addTearDown(server.close);
      final port = server.port;
      var c = await _mount(tester, 'https://127.0.0.1:$port/');
      await _until(tester, () => c.value.status == WebPageStatus.offline);
      await _unmount(tester);
      c = await _mount(tester, 'http://127.0.0.1:$port/');
      await _until(tester, () => c.value.status == WebPageStatus.insecure);
      await _unmount(tester);
    });
  }

  testWidgets('CA-009-09, CA-009-11: con http:// guardada, si la página '
      'intenta ir a otra http:// antes de terminar de cargar (neverssl.com), '
      'aviso "no segura"; ya cargada, no hace nada', (tester) async {
    // Una imagen de un servidor que no responde mantiene abierta la carga.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    server.listen(held.add);
    addTearDown(() async {
      for (final s in held) {
        s.destroy();
      }
      await server.close();
    });
    String page(String when) =>
        '<!doctype html><html><body><h1>Una</h1>'
        '<img src="https://127.0.0.1:${server.port}/x.png">'
        '<script>$when</script></body></html>';
    const jump = "location.href = 'http://abc.una.test/online';";
    _pageOverride = page('setTimeout(function () { $jump }, 300);');
    var c = await _mount(tester, 'http://una.test/');
    await _until(tester, () => c.value.status == WebPageStatus.insecure);
    await _unmount(tester);
    // Terminada la carga (sin la imagen; 3 s después del `load`, para que
    // haya llegado `onPageFinished`), el mismo intento no hace nada.
    _pageOverride =
        '<!doctype html><html><body><h1>Una</h1><script>'
        "addEventListener('load', function () { setTimeout(function () { "
        '$jump }, 3000); });</script></body></html>';
    c = await _mount(tester, 'http://una.test/');
    await _until(tester, () => _loaded(c));
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.value.status, WebPageStatus.shown);
    expect(c.value.pageUrl.host, 'una.test');
    await _unmount(tester);
  });

  testWidgets('CL-009-4: una dirección que es una descarga es "no es una '
      'página"', (tester) async {
    final pdf = base64.encode(utf8.encode('%PDF-1.4\n%%EOF\n'));
    final c = await _mount(tester, 'data:application/pdf;base64,$pdf');
    await _until(tester, () => c.value.status == WebPageStatus.notAPage);
    await _unmount(tester);
  });

  testWidgets('ADR-0017: chrome://crash no cierra la app; tras el aviso, '
      'WebView nueva y la dirección guardada otra vez (dos veces)', (
    tester,
  ) async {
    final c = await _mount(tester, 'https://una.test/programa');
    await _until(tester, () => _loaded(c));
    for (var round = 0; round < 2; round++) {
      final old = c.driver;
      final oldId = old.nativeId!;
      final generation = c.value.viewGeneration;
      // Solo la prueba carga esto: la página no puede (CA-009-11).
      await old.load(Uri.parse('chrome://crash'));
      await _until(tester, () => c.value.viewGeneration != generation);
      expect(identical(c.driver, old), isFalse);
      await _until(tester, () => _loaded(c));
      expect(c.value.pageUrl, Uri.parse('https://una.test/programa'));
      final id = c.driver.nativeId!;
      expect(id, isNot(oldId));
      expect((await hardening.state(id))!['wrapped'], isTrue);
    }
    expect(_drivers, hasLength(3));
    await _unmount(tester);
  });
}
