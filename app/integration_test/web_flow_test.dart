// Flujo completo de la tarea web en el emulador (spec 009, T-009-18): la app
// entera, la BD y la WebView reales, con servidores locales de Dart en el propio
// test (sin red externa). Complementa `web_page_controller_test` (el
// controlador con la WebView) y `webview_hardening_test` (lo nativo): aquí se
// prueba lo que ve y hace el usuario. En el emulador (nunca en el móvil del
// propietario sin su permiso):
//   flutter test integration_test/web_flow_test.dart -d emulator-5554
//
// Limitaciones (anotadas en `tasks.md`, T-009-18):
// - **Modo avión:** una app no puede activarlo (`cmd connectivity
//   airplane-mode` es del *shell*), y con él el tráfico local sigue
//   funcionando. Por eso "sin conexión" se prueba aquí con una dirección que
//   no conecta (puerto cerrado, `.invalid`) y "vuelve la red" con la carga
//   simulada por [_LocalPageDriver] (los servidores https locales no son de
//   fiar para la app, que nunca acepta un certificado que no es válido). El
//   modo avión real se prueba con el último test, que solo corre con
//   `--dart-define=UNA_AIRPLANE=true` y con el modo avión ya activado desde el
//   *shell* (`adb -s emulator-5554 shell cmd connectivity airplane-mode
//   enable`).
// - **PDF servido por http/https (CL-009-4):** el emulador no tiene un
//   certificado de confianza para un servidor local; la respuesta que se
//   descarga se sirve con una dirección `data:` (la WebView la trata igual:
//   `DownloadListener`), a nombre de una dirección guardada `https://una.test/…`.
import 'dart:convert';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/repository_factory.dart';
import 'package:app/data/web/web_data_janitor.dart';
import 'package:app/data/web/webview_hardening.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/queue_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/attachments/pdf_boot.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/features/web/web_page_driver_factory.dart';
import 'package:app/features/web/webview_page_driver.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'fixtures/selfsigned_tls.dart';

const _airplane = bool.fromEnvironment('UNA_AIRPLANE');
const _hardening = ChannelWebViewHardening();

const _page = '''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<title>Programa</title></head>
<body><h1>Programa del congreso</h1>
<a id="mismo" href="/ponentes">Ponentes</a>
<a id="otro" href="https://otro.una.test/">Otro</a>
<a id="tel" href="tel:+34600000000">Tel</a>
<a id="mail" href="mailto:info@una.test">Mail</a>
<a id="nueva" href="https://una.test/nueva" target="_blank">Nueva</a>
<a id="ancla" href="#b">B</a>
<div style="height:3000px"></div><h2 id="b">B</h2></body></html>
''';

// ---------------------------------------------------------------------------
// Lo que hace de "red" para la dirección `una.test`.
// ---------------------------------------------------------------------------

/// Si "hay red": con ella, `una.test` sirve [_html]; sin ella, la WebView
/// intenta conectar a un puerto cerrado (el mismo error real que sin red).
bool _online = false;
String _html = _page;

/// Cómo se sirve `una.test` cuando hay red (los PDF, con `data:`).
Future<void> Function(WebViewController web, Uri url) _serve = _servePage;

Future<void> _servePage(WebViewController web, Uri url) =>
    web.loadHtmlString(_html, baseUrl: url.toString());

/// La WebView real; solo cambia de dónde salen las páginas de `una.test`.
class _LocalPageDriver extends WebViewPageDriver {
  /// Lo que ha pedido cargar el controlador.
  final loaded = <Uri>[];

  @override
  Future<void> load(Uri url) {
    loaded.add(url);
    if (url.host != 'una.test') return super.load(url);
    return _online
        ? _serve(webView, url)
        : webView.loadRequest(Uri.parse('https://127.0.0.1:1/'));
  }
}

final _drivers = <_LocalPageDriver>[];

/// Recuerda lo que la app quiso abrir fuera de ella (sin abrir nada).
class _RecordingOpener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  final opened = <LinkTarget>[];

  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return true;
  }
}

final _opener = _RecordingOpener();

// ---------------------------------------------------------------------------
// Arranque de la app (como `bootstrap`, más los proveedores de pruebas).
// ---------------------------------------------------------------------------

Future<void> _wipe() async {
  final docs = await getApplicationDocumentsDirectory();
  // Solo en las apps de pruebas (`.debug`, `.profile`): nunca borra datos
  // reales.
  if (!docs.path.contains('.debug') && !docs.path.contains('.profile')) {
    throw StateError('Pruebas de integración fuera de la app .debug: $docs');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${docs.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  final support = await getApplicationSupportDirectory();
  final marker = File('${support.path}/${WebDataJanitor.markerName}');
  if (marker.existsSync()) marker.deleteSync();
}

Future<void> _boot(WidgetTester tester) async {
  final repos = await openRepositories();
  final images = await openImageServices();
  final boot = await readBootState(repos.tasks, repos.settings);
  final pdfSeed = await readPdfBootSeed(
    task: boot.currentTask,
    store: images.store,
    images: images.images,
  );
  runApp(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repos.tasks),
        settingsRepositoryProvider.overrideWithValue(repos.settings),
        attachmentStoreProvider.overrideWithValue(images.store),
        attachmentImagesProvider.overrideWithValue(images.images),
        imageImporterProvider.overrideWithValue(images.importer),
        pdfImporterProvider.overrideWithValue(images.pdfImporter),
        bootStateProvider.overrideWithValue(boot),
        pdfBootSeedProvider.overrideWithValue(pdfSeed),
        linkOpenerProvider.overrideWithValue(_opener),
        webPageDriverFactoryProvider.overrideWithValue(() {
          final driver = _LocalPageDriver();
          _drivers.add(driver);
          return driver;
        }),
      ],
      child: const UnaApp(),
    ),
  );
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeRouter)));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Desmonta la app (suelta la WebView, que borra sus datos) y cierra la BD.
Future<void> _shutdown(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
  await repo.db.close();
}

/// Deja pasar [time] en tiempo real con fotogramas (con una WebView a la vista
/// no se usa `pumpAndSettle`).
Future<void> _settle(
  WidgetTester tester, [
  Duration time = const Duration(seconds: 1),
]) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Tiempo agotado: $reason');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Arranca con la BD limpia, crea las tareas y vuelve a arrancar: primero las
/// de texto (al final de la cola) y, si hay, la web (arriba del todo).
Future<void> _seed(
  WidgetTester tester, {
  List<String> texts = const [],
  String? web,
}) async {
  await _wipe();
  await _boot(tester);
  final container = _container(tester);
  await container.read(settingsRepositoryProvider).setFirstRunDone();
  final create = container.read(createTaskProvider);
  for (final text in texts) {
    await create.call(text, position: QueuePosition.end);
  }
  if (web != null) {
    await create.call(
      '',
      attachment: StagedWeb(
        id: container.read(idGeneratorProvider).newId(),
        url: web,
      ),
    );
  }
  await _shutdown(tester);
  _drivers.clear();
  await _boot(tester);
}

// ---------------------------------------------------------------------------
// Lo que se ve de la tarea web.
// ---------------------------------------------------------------------------

Finder get _loadingLine => find.byKey(const ValueKey('web-loading'));

List<String> _noticeTexts(AppLocalizations l10n) => [
  l10n.urlNeedsConnection,
  l10n.urlInsecure,
  l10n.urlLoadFailed(l10n.urlReasonCertificate),
  l10n.urlNotAPage,
  l10n.urlLoadFailed(l10n.urlReasonKeepsLeaving),
];

bool _hasNotice(WidgetTester tester) =>
    [for (final text in _noticeTexts(_l10n(tester))) find.text(text)]
        .any((f) => f.evaluate().isNotEmpty);

/// La página se ve: ni aviso ni línea de carga.
bool _pageShown(WidgetTester tester) =>
    find.byType(WebBar).evaluate().isNotEmpty &&
    _drivers.isNotEmpty &&
    _loadingLine.evaluate().isEmpty &&
    !_hasNotice(tester);

Future<void> _untilShown(WidgetTester tester) =>
    _until(tester, () => _pageShown(tester), reason: 'página a la vista');

Future<void> _untilNotice(WidgetTester tester, String text) =>
    _until(tester, () => find.text(text).evaluate().isNotEmpty, reason: text);

WebBar _bar(WidgetTester tester) => tester.widget<WebBar>(find.byType(WebBar));

/// El resultado de [script] en la WebView actual, sin las comillas de JSON.
Future<String> _js(String script) async {
  final result =
      '${await _drivers.last.webView.runJavaScriptReturningResult(script)}';
  return result.length >= 2 && result.startsWith('"') && result.endsWith('"')
      ? result.substring(1, result.length - 1)
      : result;
}

/// Menú → Todas mis tareas.
Future<void> _openList(WidgetTester tester) async {
  final l10n = _l10n(tester);
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await _settle(tester);
  await tester.tap(find.text(l10n.menuAllTasks));
  await _settle(tester);
  expect(find.byType(TaskListScreen), findsOneWidget);
}

/// Menú → Eliminar → Eliminar.
Future<void> _deleteFromMenu(WidgetTester tester) async {
  final l10n = _l10n(tester);
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await _settle(tester);
  await tester.tap(find.text(l10n.menuDelete));
  await _settle(tester);
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
    ),
  );
  await _settle(tester, const Duration(seconds: 4));
}

/// Una WebView suelta, sin la app, para mirar qué queda de `una.test`.
class _Probe {
  _Probe() {
    web = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
  }
  late final WebViewController web;
  var finished = 0;

  Future<void> mount(WidgetTester tester) async {
    await web.setNavigationDelegate(
      NavigationDelegate(onPageFinished: (_) => finished++),
    );
    await tester.pumpWidget(MaterialApp(home: WebViewWidget(controller: web)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> load(WidgetTester tester) async {
    final before = finished;
    await web.loadHtmlString(
      '<!doctype html><html><body>Una</body></html>',
      baseUrl: 'https://una.test/',
    );
    await _until(tester, () => finished > before, reason: 'sonda cargada');
  }

  Future<String> js(String script) async {
    final r = '${await web.runJavaScriptReturningResult(script)}';
    return r.length >= 2 && r.startsWith('"') && r.endsWith('"')
        ? r.substring(1, r.length - 1)
        : r;
  }
}

const _setStorage =
    "document.cookie = 'una=1; max-age=3600; secure';"
    "localStorage.setItem('una', '1');";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _drivers.clear();
    _opener.opened.clear();
    _online = false;
    _html = _page;
    _serve = _servePage;
  });

  // -------------------------------------------------------------------------
  // (1) Crear, sin conexión, "Reintentar" y vuelve la red.
  // -------------------------------------------------------------------------

  testWidgets(
    'CA-009-03/08: crear la tarea web desde "Cargar URL" sin conexión: se '
    'crea igual, "Necesitas conexión…", "Reintentar" hasta que vuelve la red',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _wipe();
      await _boot(tester);
      await tester.tap(find.byType(WelcomeIntro));
      await _settle(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.bySemanticsLabel(l10n.attachButton));
      await _settle(tester, const Duration(seconds: 2));
      await tester.tap(find.text(l10n.attachUrl));
      await _settle(tester, const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField).last, 'una.test/programa');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is BrutalButton && w.label == l10n.urlOpen,
        ),
      );
      await _settle(tester);

      // Se crea al momento, sin texto y con `https://` (CA-009-03/04).
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      final task = (await _container(tester)
          .read(taskRepositoryProvider)
          .currentTask())!;
      expect(task.text, isNull);
      expect(task.attachment!.kind, AttachmentKind.web);
      expect(task.attachment!.url, 'https://una.test/programa');

      // Sin conexión: el aviso y "Reintentar" en lugar de la página.
      await _untilNotice(tester, l10n.urlNeedsConnection);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(_drivers.single.loaded, [Uri.parse('https://una.test/programa')]);

      // Sigue sin red: "Reintentar" vuelve a cargar y vuelve el aviso.
      await tester.tap(find.text(l10n.retry));
      await _settle(tester);
      await _untilNotice(tester, l10n.urlNeedsConnection);
      expect(_drivers.last.loaded, hasLength(2));

      // Vuelve la red: "Reintentar" carga la dirección guardada.
      _online = true;
      await tester.tap(find.text(l10n.retry));
      await _untilShown(tester);
      expect(_drivers.last.loaded, hasLength(3));
      expect(await _js('document.title'), 'Programa');
      expect(await _js('location.href'), 'https://una.test/programa');
      expect(find.text(l10n.urlNeedsConnection), findsNothing);
      expect(_bar(tester).host, 'una.test');
      expect(_bar(tester).secure, isTrue);
      await _shutdown(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'CA-009-08: el aviso "sin conexión" se reintenta solo al volver a la app',
    (tester) async {
      await _seed(tester, texts: ['Llamar'], web: 'https://una.test/programa');
      final l10n = _l10n(tester);
      await _untilNotice(tester, l10n.urlNeedsConnection);
      // Vuelve la red mientras la app está en segundo plano.
      _online = true;
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _untilShown(tester);
      expect(await _js('document.title'), 'Programa');
      await _shutdown(tester);
    },
  );

  testWidgets(
    'CA-009-08: una dirección que nunca responde (20 s sin ver nada) da '
    '"Necesitas conexión…"',
    (tester) async {
      // Acepta la conexión y no dice nada: la página no llega a verse.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add);
      addTearDown(() async {
        for (final s in held) {
          s.destroy();
        }
        await server.close();
      });
      await _seed(tester, web: 'https://127.0.0.1:${server.port}/');
      final l10n = _l10n(tester);
      final started = DateTime.now();
      await _untilNotice(tester, l10n.urlNeedsConnection);
      final took = DateTime.now().difference(started);
      expect(took, greaterThan(const Duration(seconds: 15)));
      expect(took, lessThan(const Duration(seconds: 30)));
      expect(find.text(l10n.retry), findsOneWidget);
      await _shutdown(tester);
    },
  );

  // -------------------------------------------------------------------------
  // (2) http en claro.
  // -------------------------------------------------------------------------

  testWidgets(
    'CA-009-06/09: una dirección http:// se intenta como https://; si el '
    'servidor no habla TLS, "no usa conexión segura" sin candado y nada viaja '
    'sin cifrar',
    (tester) async {
      // Un servidor http en claro: contesta con una página a lo que le llegue.
      final received = <List<int>>[];
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) {
        socket.listen((data) {
          received.add(data);
          try {
            socket.add(
              utf8.encode(
                'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n'
                'Content-Length: 18\r\nConnection: close\r\n\r\n'
                '<h1>en claro</h1>\n',
              ),
            );
            socket.destroy();
          } on Object {
            // La WebView ya cerró.
          }
        }, onError: (_) {});
      });
      addTearDown(server.close);
      final port = server.port;
      await _seed(tester, web: 'http://127.0.0.1:$port/');
      final l10n = _l10n(tester);
      await _untilNotice(tester, l10n.urlInsecure);

      // Solo el saludo TLS (0x16), nunca una petición http (CA-009-09).
      expect(received, isNotEmpty);
      for (final data in received) {
        expect(data.first, 0x16);
        expect(latin1.decode(data), isNot(contains('GET ')));
      }
      expect(_drivers.single.loaded, [Uri.parse('https://127.0.0.1:$port/')]);
      // Sin candado (CA-009-06), con el aviso y "Abrir en el navegador"; sin
      // "Reintentar" (§5).
      expect(_bar(tester).secure, isFalse);
      expect(find.text(l10n.urlOpenInBrowser), findsOneWidget);
      expect(find.text(l10n.retry), findsNothing);
      expect(find.text('en claro'), findsNothing);

      // Abre la dirección guardada (la http:// tal cual) fuera de la app.
      await tester.tap(find.text(l10n.urlOpenInBrowser));
      await tester.pump(const Duration(milliseconds: 300));
      final opened = _opener.opened.single as WebLink;
      expect(opened.uri, Uri.parse('http://127.0.0.1:$port/'));
      await _shutdown(tester);
    },
  );

  testWidgets(
    'CA-009-09: una página https no carga nada sin cifrar (contenido mixto)',
    (tester) async {
      // Un servidor http que cuenta lo que le piden.
      var hits = 0;
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      server.listen((socket) {
        hits++;
        socket.destroy();
      });
      addTearDown(server.close);
      // Preferiblemente una dirección que no sea de bucle local (que Chromium
      // trata como de confianza); si el emulador no tiene, la de bucle.
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final host = [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (!a.isLoopback) a.address,
      ].firstOrNull;
      final target = 'http://${host ?? '127.0.0.1'}:${server.port}';
      _online = true;
      _html =
          '''
<!doctype html><html><body><h1>Mixto</h1>
<img src="$target/i.png">
<script>
window.result = 'pending';
fetch('$target/f').then(function () { window.result = 'loaded'; },
  function () { window.result = 'blocked'; });
</script></body></html>
''';
      await _seed(tester, web: 'https://una.test/programa');
      await _untilShown(tester);
      await _settle(tester, const Duration(seconds: 3));
      // El `fetch` se rechaza (no se queda pendiente ni se completa).
      expect(await _js('window.result'), 'blocked');
      expect(hits, 0, reason: 'nada debe salir sin cifrar ($target)');
      await _shutdown(tester);
    },
  );

  // -------------------------------------------------------------------------
  // (3) https con certificado autofirmado.
  // -------------------------------------------------------------------------

  testWidgets(
    'CA-009-10: un certificado autofirmado nunca se acepta: aviso con '
    '"Abrir en el navegador" y "Reintentar", y el servidor no ve ninguna '
    'petición',
    (tester) async {
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(selfSignedCertPem))
        ..usePrivateKeyBytes(utf8.encode(selfSignedKeyPem));
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      var requests = 0;
      server.listen((request) {
        requests++;
        request.response
          ..headers.contentType = ContentType.html
          ..write('<h1>secreto</h1>')
          ..close();
        // El saludo TLS que la WebView aborta llega como error del servidor.
      }, onError: (_) {});
      addTearDown(() => server.close(force: true));
      final address = 'https://127.0.0.1:${server.port}/';
      await _seed(tester, web: address);
      final l10n = _l10n(tester);
      final notice = l10n.urlLoadFailed(l10n.urlReasonCertificate);
      await _untilNotice(tester, notice);
      expect(find.text(l10n.urlOpenInBrowser), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text('secreto'), findsNothing);

      // "Reintentar" lo vuelve a intentar y vuelve a rechazarlo.
      await tester.tap(find.text(l10n.retry));
      await _settle(tester, const Duration(seconds: 2));
      await _untilNotice(tester, notice);
      expect(_drivers.last.loaded, hasLength(2));

      // Ni la página ni sus recursos: el servidor nunca llegó a recibir una
      // petición http.
      expect(requests, 0);

      await tester.tap(find.text(l10n.urlOpenInBrowser));
      await tester.pump(const Duration(milliseconds: 300));
      expect((_opener.opened.single as WebLink).uri, Uri.parse(address));
      await _shutdown(tester);
    },
  );

  // -------------------------------------------------------------------------
  // (4) Una respuesta que no es una página.
  // -------------------------------------------------------------------------

  for (final type in ['application/pdf', 'application/octet-stream']) {
    testWidgets(
      'CL-009-4: la dirección devuelve $type (una descarga): "no es una '
      'página web", solo "Abrir en el navegador" y no se descarga nada',
      (tester) async {
        final body = base64.encode(utf8.encode('%PDF-1.4\n%%EOF\n'));
        _online = true;
        _serve = (web, url) =>
            web.loadRequest(Uri.parse('data:$type;base64,$body'));
        await _seed(tester, web: 'https://una.test/carta.pdf');
        final l10n = _l10n(tester);
        await _untilNotice(tester, l10n.urlNotAPage);
        expect(find.text(l10n.urlOpenInBrowser), findsOneWidget);
        expect(find.text(l10n.retry), findsNothing);
        final downloads = await getDownloadsDirectory();
        if (downloads != null && downloads.existsSync()) {
          expect(downloads.listSync(), isEmpty);
        }
        await tester.tap(find.text(l10n.urlOpenInBrowser));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          (_opener.opened.single as WebLink).uri,
          Uri.parse('https://una.test/carta.pdf'),
        );
        await _shutdown(tester);
      },
    );
  }

  // -------------------------------------------------------------------------
  // (5) Un enlace tocado no cambia la página.
  // -------------------------------------------------------------------------

  testWidgets('CA-009-11: tocar un enlace (mismo sitio, otro, tel:, mailto:, '
      'target=_blank) no carga nada ni abre el navegador ni otra app; un ancla '
      'desplaza', (tester) async {
    _online = true;
    await _seed(tester, web: 'https://una.test/programa');
    await _untilShown(tester);
    final l10n = _l10n(tester);
    await _js('window.una = 7');
    for (final id in ['mismo', 'otro', 'tel', 'mail', 'nueva']) {
      await _drivers.last.webView.runJavaScript(
        "document.getElementById('$id').click();",
      );
      await _settle(tester, const Duration(milliseconds: 800));
    }
    expect(await _js('window.una'), '7');
    expect(await _js('location.href'), 'https://una.test/programa');
    expect(_drivers.last.loaded, [Uri.parse('https://una.test/programa')]);
    expect(_opener.opened, isEmpty);
    expect(_hasNotice(tester), isFalse);
    expect(_bar(tester).host, 'una.test');
    expect(find.text(l10n.urlNeedsConnection), findsNothing);

    await _drivers.last.webView.runJavaScript(
      "document.getElementById('ancla').click();",
    );
    await _settle(tester);
    expect(await _js('location.href'), 'https://una.test/programa#b');
    expect(await _js('window.scrollY > 1000'), 'true');
    expect(await _js('window.una'), '7');
    expect(_drivers.last.loaded, hasLength(1));
    expect(_opener.opened, isEmpty);
    await _shutdown(tester);
  });

  // -------------------------------------------------------------------------
  // (6) Cookies y localStorage al salir y al arrancar.
  // -------------------------------------------------------------------------

  testWidgets(
    'CA-009-07/13, CL-009-11: al ir al listado y volver, y al eliminar, no '
    'queda ninguna cookie ni localStorage; la página se carga de cero',
    (tester) async {
      final semantics = tester.ensureSemantics();
      _online = true;
      await _seed(tester, texts: ['Llamar'], web: 'https://una.test/programa');
      await _untilShown(tester);
      final l10n = _l10n(tester);
      final web = (await _container(tester)
          .read(taskRepositoryProvider)
          .currentTask())!;
      expect(web.attachment!.kind, AttachmentKind.web);
      await _js(_setStorage);
      expect(await _js('document.cookie'), contains('una=1'));
      expect(await _js("localStorage.getItem('una')"), '1');
      await _js('window.scrollTo(0, 1500)');

      // A otra pantalla y de vuelta: otra WebView, de cero y sin sesión.
      await _openList(tester);
      await tester.tap(find.bySemanticsLabel(l10n.listBack));
      await _settle(tester);
      await _untilShown(tester);
      // Cargada otra vez, desde cero.
      expect(_drivers.last.loaded, [
        Uri.parse('https://una.test/programa'),
        Uri.parse('https://una.test/programa'),
      ]);
      expect(await _js('document.cookie'), isEmpty);
      expect(await _js("localStorage.getItem('una')"), 'null');
      expect(await _js('window.scrollY'), '0');

      // Abrir y cerrar el menú no recarga (CA-009-07).
      await tester.tap(find.bySemanticsLabel(l10n.menuButton));
      await _settle(tester);
      expect(find.text(l10n.menuDelete), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text(l10n.menuDelete), findsNothing);
      expect(_drivers.last.loaded, hasLength(2));

      // Eliminar la tarea (CL-009-11): no queda nada de ella.
      await _js(_setStorage);
      expect(await _js('document.cookie'), contains('una=1'));
      final repo = _container(
        tester,
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      await _deleteFromMenu(tester);
      expect(await repo.findById(web.id), isNull);
      expect(find.text('Llamar'), findsOneWidget);
      expect(find.byType(AllDoneScreen), findsNothing);
      await _shutdown(tester);

      final probe = _Probe();
      await probe.mount(tester);
      await probe.load(tester);
      expect(await probe.js('document.cookie'), isEmpty);
      expect(await probe.js("localStorage.getItem('una')"), 'null');
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'CA-009-13: si la app se cerró sin borrar los datos de la página, se '
    'borran en el siguiente arranque, después del primer fotograma',
    (tester) async {
      await _wipe();
      final support = await getApplicationSupportDirectory();
      final marker = File('${support.path}/${WebDataJanitor.markerName}');
      // Una visita anterior que se quedó con datos y con la marca.
      final probe = _Probe();
      await probe.mount(tester);
      await probe.load(tester);
      await probe.web.runJavaScript(_setStorage);
      await WebViewCookieManager().setCookie(
        const WebViewCookie(name: 'nativa', value: '1', domain: 'una.test'),
      );
      await probe.load(tester);
      expect(await probe.js('document.cookie'), contains('una=1'));
      expect(await probe.js('document.cookie'), contains('nativa=1'));
      await tester.pumpWidget(const SizedBox());
      await WebDataJanitor(
        filesDir: getApplicationSupportDirectory,
        cleaner: _hardening,
      ).markUsed();
      expect(marker.existsSync(), isTrue);

      // Arranque en frío: la limpieza va tras el primer fotograma.
      await _boot(tester);
      await _until(tester, () => !marker.existsSync(), reason: 'marca quitada');
      await _shutdown(tester);

      final after = _Probe();
      await after.mount(tester);
      await after.load(tester);
      expect(await after.js('document.cookie'), isEmpty);
      expect(await after.js("localStorage.getItem('una')"), 'null');
      await tester.pumpWidget(const SizedBox());
    },
  );

  // -------------------------------------------------------------------------
  // Modo avión real (solo a mano; ver la cabecera).
  // -------------------------------------------------------------------------

  testWidgets(
    'CA-009-08: con el modo avión activado (a mano, desde el shell), una '
    'dirección externa da "Necesitas conexión…" enseguida',
    (tester) async {
      await _seed(tester, web: 'https://192.0.2.1/');
      final l10n = _l10n(tester);
      final started = DateTime.now();
      await _untilNotice(tester, l10n.urlNeedsConnection);
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 10)),
      );
      expect(find.text(l10n.retry), findsOneWidget);
      await _shutdown(tester);
    },
    skip: !_airplane,
  );
}
