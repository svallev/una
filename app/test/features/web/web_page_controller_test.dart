import 'package:app/data/web/web_data_janitor.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/features/web/web_page_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_web_page_driver.dart';

class _Clock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 29, 10);
  @override
  DateTime now() => value;
}

/// Registra la marca y los borrados, sin disco ni canal.
class _Janitor extends WebDataJanitor {
  _Janitor() : super.inactive();

  bool marked = false;
  final cleared = <int?>[];

  @override
  Future<void> markUsed() async => marked = true;

  @override
  Future<bool> clearOnLeave({int? webViewId}) async {
    cleared.add(webViewId);
    return true;
  }
}

/// Un controlador con WebViews falsas (la primera, `drivers.first`).
class _Harness {
  _Harness({String address = 'https://congreso.ejemplo.com/programa'}) {
    controller = WebPageController(
      address: Uri.parse(address),
      createDriver: () {
        final d = FakeWebPageDriver(nativeId: 40 + drivers.length);
        d.onLoad = (_) => markedAtLoad.add(janitor.marked);
        drivers.add(d);
        return d;
      },
      janitor: janitor,
      clock: clock,
      afterFrame: () async => frames++,
    );
  }

  final drivers = <FakeWebPageDriver>[];
  final janitor = _Janitor();
  final clock = _Clock();
  final markedAtLoad = <bool>[];
  int frames = 0;
  late final WebPageController controller;

  FakeWebPageDriver get driver => drivers.last;
  WebPageState get state => controller.value;

  Future<void> start(WidgetTester tester) async {
    await controller.start();
    await tester.pump();
  }
}

/// Monta un widget que suelta el controlador al desmontarse, como la
/// pantalla de la tarea (T-009-11).
Future<_Harness> _mount(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(_Owner(h.controller));
  return h;
}

class _Owner extends StatefulWidget {
  const _Owner(this.controller);
  final WebPageController controller;
  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> _lifecycle(WidgetTester tester, AppLifecycleState s) async {
  tester.binding.handleAppLifecycleStateChanged(s);
  await tester.pump();
}

Future<void> _hideApp(WidgetTester tester) async {
  await _lifecycle(tester, AppLifecycleState.inactive);
  await _lifecycle(tester, AppLifecycleState.hidden);
  await _lifecycle(tester, AppLifecycleState.paused);
}

Future<void> _showApp(WidgetTester tester) async {
  await _lifecycle(tester, AppLifecycleState.hidden);
  await _lifecycle(tester, AppLifecycleState.inactive);
  await _lifecycle(tester, AppLifecycleState.resumed);
}

void main() {
  group('Cargar (CA-009-07)', () {
    testWidgets('CA-009-07: se carga la dirección guardada, con la marca '
        'escrita antes (CA-009-13); mientras, "cargando"', (tester) async {
      final h = await _mount(tester, _Harness());
      // La WebView se crea con el controlador, pero no carga hasta start.
      expect(h.drivers, hasLength(1));
      expect(h.driver.loads, isEmpty);
      await h.start(tester);
      expect(h.driver.attachCount, 1);
      expect(h.driver.loads, [
        Uri.parse('https://congreso.ejemplo.com/programa'),
      ]);
      expect(h.markedAtLoad, [true]);
      expect(h.state.status, WebPageStatus.loading);
      expect(h.state.failure, isNull);
      expect(h.state.pageUrl.host, 'congreso.ejemplo.com');
    });

    testWidgets('CA-009-06: al empezar a verse, "se ve", con el progreso '
        'hasta que termina', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.progress(10);
      expect(h.state.progress, 10);
      h.driver.started('https://congreso.ejemplo.com/programa');
      expect(h.state.status, WebPageStatus.shown);
      expect(h.state.pageLoading, isTrue);
      h.driver.progress(70);
      expect(h.state.progress, 70);
      h.driver.finished('https://congreso.ejemplo.com/programa');
      expect(h.state.status, WebPageStatus.shown);
      expect(h.state.pageLoading, isFalse);
    });

    testWidgets('ADR-0017: si la WebView no queda endurecida, no se carga '
        'nada y se ve el aviso con "Reintentar"', (tester) async {
      final h = await _mount(tester, _Harness());
      h.driver.hardens = false;
      await h.start(tester);
      expect(h.driver.loads, isEmpty);
      expect(h.state.status, WebPageStatus.offline);
      expect(h.state.failure!.canRetry, isTrue);
    });

    testWidgets('CA-009-07: de segundo plano en menos de 10 minutos se '
        'conserva la página', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      await _hideApp(tester);
      h.clock.value = h.clock.value.add(const Duration(minutes: 9));
      await _showApp(tester);
      await tester.pump();
      expect(h.driver.loads, hasLength(1));
      expect(h.janitor.cleared, isEmpty);
      expect(h.state.status, WebPageStatus.shown);
    });

    testWidgets('CA-009-07: tras 10 minutos o más en segundo plano, se borra '
        'la sesión y se carga desde cero', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      await _hideApp(tester);
      h.clock.value = h.clock.value.add(const Duration(minutes: 10));
      await _showApp(tester);
      await tester.pump();
      expect(h.janitor.cleared, [40]);
      expect(h.driver.loads, hasLength(2));
      expect(h.state.status, WebPageStatus.loading);
    });

    testWidgets('CA-009-07, CA-009-13: al salir a otra pantalla se quita la '
        'página y se borran sus datos; al volver, se carga desde cero', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.controller.leave();
      await tester.pump();
      expect(h.driver.stops, 1);
      expect(h.janitor.cleared, [40]);
      // Lo que llegue mientras tanto no cambia nada.
      h.driver.error(WebLoadError.hostLookup);
      await _hideApp(tester);
      await _showApp(tester);
      expect(h.driver.loads, hasLength(1));
      await h.controller.comeBack();
      await tester.pump();
      expect(h.driver.loads, hasLength(2));
      expect(h.state.status, WebPageStatus.loading);
    });
  });

  group('Sin conexión (CA-009-08, CL-009-7)', () {
    testWidgets('CA-009-08: sin red, el error del marco principal da el aviso '
        'aunque antes llegue onPageStarted', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.driver.error(WebLoadError.hostLookup);
      expect(h.state.status, WebPageStatus.offline);
      expect(h.state.failure, WebLoadFailure.offline);
    });

    testWidgets('CA-009-08: el error de un recurso suelto no tapa la página', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.driver.error(WebLoadError.connect, mainFrame: false);
      expect(h.state.status, WebPageStatus.shown);
    });

    testWidgets('CA-009-08: 20 s sin que la página empiece a verse → sin '
        'conexión, y se deja de cargar', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      await tester.pump(const Duration(seconds: 19));
      expect(h.state.status, WebPageStatus.loading);
      await tester.pump(const Duration(seconds: 1));
      expect(h.state.status, WebPageStatus.offline);
      expect(h.driver.stops, 1);
      // Lo que llegue después de la carga abandonada no cambia nada.
      h.driver.started('about:blank');
      h.driver.started('https://congreso.ejemplo.com/programa');
      expect(h.state.status, WebPageStatus.offline);
    });

    testWidgets('CL-009-7: una página que empieza a verse y nunca termina no '
        'cuenta como sin conexión', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      await tester.pump(const Duration(seconds: 5));
      h.driver.started('https://congreso.ejemplo.com/programa');
      await tester.pump(const Duration(seconds: 60));
      expect(h.state.status, WebPageStatus.shown);
      expect(h.state.pageLoading, isTrue);
      expect(h.driver.stops, 0);
    });

    testWidgets('CA-009-08: "Reintentar" vuelve a cargar la dirección '
        'guardada, con sus 20 s', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.error(WebLoadError.hostLookup);
      await h.controller.retry();
      await tester.pump();
      expect(h.driver.loads, [
        Uri.parse('https://congreso.ejemplo.com/programa'),
        Uri.parse('https://congreso.ejemplo.com/programa'),
      ]);
      expect(h.state.status, WebPageStatus.loading);
      // Un about:blank tardío de la carga anterior no cuenta.
      h.driver.started('about:blank');
      expect(h.state.status, WebPageStatus.loading);
      await tester.pump(webLoadTimeout);
      expect(h.state.status, WebPageStatus.offline);
    });

    testWidgets('CA-009-08: al volver a la app con un aviso, se reintenta '
        'sola (aunque sean menos de 10 minutos)', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.error(WebLoadError.hostLookup);
      await _hideApp(tester);
      h.clock.value = h.clock.value.add(const Duration(minutes: 1));
      await _showApp(tester);
      await tester.pump();
      expect(h.driver.loads, hasLength(2));
      expect(h.state.status, WebPageStatus.loading);
    });

    testWidgets('CA-009-08: al volver a la tarea con un aviso, se carga de '
        'nuevo', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.error(WebLoadError.hostLookup);
      h.controller.leave();
      await h.controller.comeBack();
      await tester.pump();
      expect(h.driver.loads, hasLength(2));
      expect(h.state.status, WebPageStatus.loading);
    });
  });

  group('Solo conexión segura (CA-009-09, CA-009-10)', () {
    testWidgets('CA-009-09: una dirección http:// se carga como https://', (
      tester,
    ) async {
      final h = await _mount(
        tester,
        _Harness(address: 'http://congreso.ejemplo.com:80/programa'),
      );
      await h.start(tester);
      expect(h.driver.loads, [
        Uri.parse('https://congreso.ejemplo.com/programa'),
      ]);
    });

    testWidgets('CA-009-09: si el servidor no admite https, "sin conexión '
        'segura"', (tester) async {
      for (final error in [
        WebLoadError.connect,
        WebLoadError.secureHandshake,
      ]) {
        final h = await _mount(
          tester,
          _Harness(address: 'http://congreso.ejemplo.com/'),
        );
        await h.start(tester);
        h.driver.error(error);
        expect(h.state.status, WebPageStatus.insecure, reason: '$error');
        expect(h.state.failure!.canOpenInBrowser, isTrue);
        h.controller.dispose();
      }
    });

    // Lo que llega de verdad (emulador, neverssl.com y un servidor local que
    // cierra la conexión): onPageStarted, el error del marco principal y
    // después onPageFinished con la página de error de Chromium.
    for (final (name, events) in <(String, List<String>)>[
      ('antes de empezar a verse', ['error', 'started', 'finished']),
      ('ya empezada', ['started', 'error', 'finished']),
      ('ya terminada', ['started', 'finished', 'error']),
    ]) {
      for (final error in [WebLoadError.noResponse, WebLoadError.connect]) {
        for (final (address, expected) in [
          ('http://congreso.ejemplo.com/', WebPageStatus.insecure),
          ('https://congreso.ejemplo.com/', WebPageStatus.offline),
        ]) {
          testWidgets('CA-009-08/09: $error del marco principal en la carga '
              'inicial ($name) con $address nunca deja la página en blanco: '
              '$expected', (tester) async {
            final h = await _mount(tester, _Harness(address: address));
            await h.start(tester);
            for (final e in events) {
              switch (e) {
                case 'error':
                  h.driver.error(error);
                case 'started':
                  h.driver.started('https://congreso.ejemplo.com/');
                case 'finished':
                  h.driver.finished('https://congreso.ejemplo.com/');
              }
            }
            expect(h.state.status, expected);
            expect(h.state.pageLoading, isFalse);
          });
        }
      }
    }

    testWidgets('CA-009-09: sin red, una dirección http:// es "sin conexión" '
        '(DNS)', (tester) async {
      final h = await _mount(
        tester,
        _Harness(address: 'http://congreso.ejemplo.com/'),
      );
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/');
      h.driver.error(WebLoadError.hostLookup);
      expect(h.state.status, WebPageStatus.offline);
    });

    testWidgets('CA-009-09: una dirección https:// que falla al conectar es '
        '"sin conexión", no "sin conexión segura"', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.error(WebLoadError.connect);
      expect(h.state.status, WebPageStatus.offline);
    });

    testWidgets('CA-009-10: certificado no válido de la página → aviso con '
        '"Abrir en el navegador" y "Reintentar"', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.certificate();
      // Después llega onPageFinished sin onPageStarted (T-009-01).
      h.driver.finished('https://congreso.ejemplo.com/programa');
      expect(h.state.status, WebPageStatus.certificate);
      expect(h.state.failure!.canRetry, isTrue);
      expect(h.state.failure!.canOpenInBrowser, isTrue);
    });

    testWidgets('CA-009-10: el certificado no válido de un recurso de una '
        'página ya visible no la tapa (el recurso no se carga)', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.driver.certificate();
      expect(h.state.status, WebPageStatus.shown);
    });
  });

  group('No es una página (CL-009-4)', () {
    testWidgets('CL-009-4: si la dirección es una descarga, "no es una página '
        'web"', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.download();
      expect(h.state.status, WebPageStatus.notAPage);
      expect(h.state.failure!.canOpenInBrowser, isTrue);
    });

    testWidgets('CA-009-13: una descarga desde una página ya visible no hace '
        'nada: la página sigue', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.driver.download();
      expect(h.state.status, WebPageStatus.shown);
    });
  });

  group('Navegación (CA-009-11, CL-009-1)', () {
    testWidgets('CL-009-1: en la carga inicial se siguen las redirecciones '
        'del servidor; las de http se cargan como https', (tester) async {
      final h = await _mount(tester, _Harness(address: 'https://ejemplo.com/'));
      await h.start(tester);
      expect(h.driver.navigate('https://www.ejemplo.com/'), isTrue);
      expect(h.driver.navigate('http://m.ejemplo.com/'), isFalse);
      expect(h.driver.loads.last, Uri.parse('https://m.ejemplo.com/'));
      // El intento https de una redirección a http también es "sin https".
      h.driver.error(WebLoadError.secureHandshake);
      expect(h.state.status, WebPageStatus.insecure);
    });

    testWidgets('CL-009-1: si acaba en otro dominio, la barra lo muestra y se '
        'avisa una sola vez', (tester) async {
      final h = await _mount(tester, _Harness(address: 'https://ejemplo.com/'));
      await h.start(tester);
      h.driver.navigate('https://m.ejemplo.com/');
      h.driver.started('https://m.ejemplo.com/');
      expect(h.state.pageUrl, Uri.parse('https://m.ejemplo.com/'));
      expect(h.state.redirectNotice, 'm.ejemplo.com');
      h.controller.redirectNoticeShown();
      expect(h.state.redirectNotice, isNull);
      await h.controller.retry();
      h.driver.started('https://m.ejemplo.com/');
      expect(h.state.redirectNotice, isNull);
    });

    testWidgets('CL-009-1: de ejemplo.com a www.ejemplo.com no se avisa', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness(address: 'https://ejemplo.com/'));
      await h.start(tester);
      h.driver.started('https://www.ejemplo.com/');
      expect(h.state.redirectNotice, isNull);
    });

    testWidgets('CA-009-11: vista la página, solo las anclas de la misma '
        'página; nada más carga', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      expect(
        h.driver.navigate('https://congreso.ejemplo.com/programa#martes'),
        isTrue,
      );
      for (final url in [
        'https://congreso.ejemplo.com/ponentes',
        'https://congreso.ejemplo.com/programa?dia=2',
        'https://otro.ejemplo.org/',
        'mailto:info@ejemplo.com',
        'tel:+34600000000',
        'intent://x#Intent;end',
      ]) {
        expect(h.driver.navigate(url), isFalse, reason: url);
      }
      expect(h.driver.loads, hasLength(1));
      expect(h.state.pageUrl.path, '/programa');
    });

    testWidgets('CA-009-11: con un aviso a la vista, ninguna petición carga', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.error(WebLoadError.hostLookup);
      expect(h.driver.navigate('https://congreso.ejemplo.com/'), isFalse);
    });
  });

  group('Fallo del proceso de la página (ADR-0017)', () {
    testWidgets('ADR-0017: solo tras el aviso se crea otra WebView; la vieja '
        'se destruye fuera de la pantalla y se carga la dirección guardada', (
      tester,
    ) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      final old = h.driver;
      final generation = h.state.viewGeneration;
      // Hasta el aviso (que tarda unos segundos), nada nuevo: crear otra
      // WebView antes cerraría la app (T-009-09).
      await tester.pump(const Duration(seconds: 5));
      expect(h.drivers, hasLength(1));

      final framesBefore = h.frames;
      old.processGone();
      expect(h.drivers, hasLength(2));
      expect(identical(h.controller.driver, h.driver), isTrue);
      expect(h.state.viewGeneration, isNot(generation));
      expect(h.state.status, WebPageStatus.loading);
      await tester.pump();
      // Tras un fotograma (la vista vieja ya no está): la vieja destruida y
      // soltada; la nueva preparada y cargando la dirección guardada.
      expect(h.frames, greaterThan(framesBefore));
      expect(old.destroyed, isTrue);
      expect(old.disposed, isTrue);
      expect(h.driver.attachCount, 1);
      expect(h.driver.loads, [
        Uri.parse('https://congreso.ejemplo.com/programa'),
      ]);
      // Lo que aún llegue de la vieja no cuenta.
      old.error(WebLoadError.hostLookup);
      old.processGone();
      expect(h.drivers, hasLength(2));
      expect(h.state.status, WebPageStatus.loading);
      h.driver.started('https://congreso.ejemplo.com/programa');
      expect(h.state.status, WebPageStatus.shown);
    });

    testWidgets('ADR-0017: dos veces seguidas', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      for (var i = 0; i < 2; i++) {
        h.driver.started('https://congreso.ejemplo.com/programa');
        h.driver.processGone();
        await tester.pump();
      }
      expect(h.drivers, hasLength(3));
      expect(h.drivers.take(2).every((d) => d.destroyed), isTrue);
      expect(h.driver.loads, hasLength(1));
      expect(h.state.status, WebPageStatus.loading);
    });

    testWidgets('CA-009-07: si el sistema descarta la página en segundo '
        'plano, se vuelve a cargar la dirección guardada', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.started('https://congreso.ejemplo.com/programa');
      await _hideApp(tester);
      h.driver.processGone(crashed: false);
      await tester.pump();
      await _showApp(tester);
      expect(h.drivers, hasLength(2));
      expect(h.driver.loads, hasLength(1));
    });

    testWidgets('ADR-0017: fuera de la tarea, la WebView se recrea pero no '
        'carga hasta volver', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.controller.leave();
      h.driver.processGone();
      await tester.pump();
      expect(h.drivers.first.destroyed, isTrue);
      expect(h.driver.loads, isEmpty);
      await h.controller.comeBack();
      expect(h.driver.attachCount, 1);
      expect(h.driver.loads, hasLength(1));
    });
  });

  group('Cancelar (CL-009-11)', () {
    testWidgets('CL-009-11: al completar o eliminar mientras carga, se '
        'cancela la carga y se borra todo', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.controller.dispose();
      await tester.pump();
      expect(h.driver.stops, 1);
      expect(h.janitor.cleared, [40]);
      expect(h.driver.disposed, isTrue);
      // Lo que llegue después (o los 20 s) no hace nada ni lanza.
      h.driver.started('https://congreso.ejemplo.com/programa');
      h.driver.error(WebLoadError.hostLookup);
      h.driver.processGone();
      await tester.pump(webLoadTimeout);
      expect(h.drivers, hasLength(1));
    });

    testWidgets('CL-009-11: si se cierra mientras se recrea la WebView, no se '
        'carga nada', (tester) async {
      final h = await _mount(tester, _Harness());
      await h.start(tester);
      h.driver.processGone();
      h.controller.dispose();
      await tester.pump();
      expect(h.drivers.first.destroyed, isTrue);
      expect(h.driver.loads, isEmpty);
      expect(h.driver.disposed, isTrue);
    });
  });
}
