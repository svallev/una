import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/task_web.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _address = 'https://www.congreso.ejemplo.com/programa';
const _host = 'congreso.ejemplo.com';
final _saved = Uri.parse(_address);

/// Tarea web guardada ([id] del adjunto, [url]).
Task _webTask({String url = _address, String attachmentId = 'a-w'}) {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: 'w',
    text: null,
    status: TaskStatus.pending,
    rank: 'MA',
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: attachmentId, url: url), at),
  );
}

class _Opener implements LinkOpener {
  final opened = <LinkTarget>[];
  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return true;
  }
}

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;
  late _Opener opener;
  late MemoryAttachmentStore store;
  late FakeImageImporter images;
  late List<String> announcements;

  List<Override> overrides() => [
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(opener),
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(images),
  ];

  setUp(() {
    web = FakeWebPages();
    opener = _Opener();
    store = MemoryAttachmentStore();
    images = FakeImageImporter(store);
  });

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  /// La app con la tarea web como actual y [others] detrás.
  Future<InMemoryTaskRepository> pumpWeb(
    WidgetTester tester, {
    Task? task,
    List<String> others = const ['Segunda'],
  }) async {
    final repo = InMemoryTaskRepository();
    await repo.insert(task ?? _webTask());
    await pumpUnaApp(tester, repo: repo, tasks: others, overrides: overrides());
    await tester.pumpAndSettle();
    return repo;
  }

  Finder notice(String text) => find.text(text);

  group('CA-009-06: tarea actual web', () {
    testWidgets('logotipo y menú arriba, barra con el dominio real (sin '
        '"www.") y "WEB", la página debajo y el botón de completar abajo', (
      tester,
    ) async {
      await pumpWeb(tester);
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.byType(SquareIconButton), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      final bar = tester.widget<WebBar>(find.byType(WebBar));
      expect((bar.host, bar.badge), (_host, 'WEB'));
      final view = find.byKey(const ValueKey('web-view-0'));
      expect(view, findsOneWidget);
      final barRect = tester.getRect(find.byType(WebBar));
      final viewRect = tester.getRect(view);
      final cta = tester.getRect(find.byType(HoldToCompleteButton));
      // Página al ancho, entre la barra y el botón.
      expect((viewRect.left, viewRect.width), (0, 390));
      expect(viewRect.top, greaterThanOrEqualTo(barRect.bottom - 0.5));
      expect(viewRect.bottom, lessThan(cta.top));
      expect(
        tester.getRect(find.byType(Wordmark)).bottom,
        lessThan(barRect.top),
      );
      // Nota blanca y menú blanco, como con el PDF (prototipo).
      expect(
        tester.widget<SquareIconButton>(find.byType(SquareIconButton)).fill,
        UnaColors.surface,
      );
    });

    testWidgets('P2: la barra está en el primer fotograma; la WebView se '
        'crea después y carga la dirección guardada con la vista ya puesta', (
      tester,
    ) async {
      await pumpWithApp(
        tester,
        CurrentTaskScreen(task: _webTask()),
        overrides: overrides(),
      );
      // El primer fotograma, con la barra y sin la vista de la WebView: se
      // crea al acabar el fotograma, sin cargar nada.
      expect(find.byType(WebBar), findsOneWidget);
      expect(find.byKey(const ValueKey('web-view-0')), findsNothing);
      expect(web.drivers, hasLength(1));
      expect(web.last.attachCount, 0);
      expect(web.last.loads, isEmpty);
      // En el siguiente, la vista; al acabar, la carga.
      await tester.pump();
      expect(find.byKey(const ValueKey('web-view-0')), findsOneWidget);
      await tester.pump();
      expect(web.last.attachCount, 1);
      expect(web.last.loads, [_saved]);
      expect(web.janitor.marks, 1);
    });

    testWidgets('mientras carga, la línea de carga ("Cargando página" para '
        'el lector); se quita al terminar', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      final line = find.byKey(const ValueKey('web-loading'));
      expect(line, findsOneWidget);
      expect(find.bySemanticsLabel('Cargando página'), findsOneWidget);
      expect(tester.getSize(line).height, UnaSizes.webLoadingHeight);
      web.last.started(_address);
      web.last.progress(60);
      await tester.pumpAndSettle();
      expect(line, findsOneWidget);
      web.last.finished(_address);
      await tester.pumpAndSettle();
      expect(line, findsNothing);
      expect(find.bySemanticsLabel('Cargando página'), findsNothing);
      handle.dispose();
    });

    testWidgets('CA-009-20: con reducir movimiento, la línea no se anima', (
      tester,
    ) async {
      final repo = InMemoryTaskRepository();
      await repo.insert(_webTask());
      await pumpUnaApp(
        tester,
        repo: repo,
        tasks: const ['Segunda'],
        reduced: true,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      web.last.progress(50);
      await tester.pump();
      final bar = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(bar.duration, Duration.zero);
      expect(bar.widthFactor, 0.5);
    });

    testWidgets('T-009-07: la web no se trata como imagen (sin imagen ni '
        'versión de pantalla)', (tester) async {
      await pumpWeb(tester);
      expect(find.byType(TaskImage), findsNothing);
      expect(images.regenerated, isEmpty);
    });

    testWidgets('la barra muestra el dominio de la página que se ve '
        '(redirección de la carga inicial, CL-009-1)', (tester) async {
      await pumpWeb(tester);
      web.last.started('https://m.otro-sitio.example/inicio');
      await tester.pumpAndSettle();
      expect(
        tester.widget<WebBar>(find.byType(WebBar)).host,
        'm.otro-sitio.example',
      );
    });
  });

  group('CA-009-07: se carga cada vez', () {
    testWidgets('abrir y cerrar el menú no recarga la página', (tester) async {
      await pumpWeb(tester);
      web.last.started(_address);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(web.drivers, hasLength(1));
      expect(web.last.loads, [_saved]);
      expect(web.last.stops, 0);
      expect(web.janitor.cleared, isEmpty);
    });

    testWidgets('otra pantalla encima (el listado): se quita la página y se '
        'borran sus datos; al volver, se carga desde cero', (tester) async {
      await pumpWeb(tester);
      web.last.started(_address);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(web.last.stops, 1);
      expect(web.janitor.cleared, [web.last.nativeId]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(web.drivers, hasLength(1));
      expect(web.last.loads, [_saved, _saved]);
      expect(find.byKey(const ValueKey('web-loading')), findsOneWidget);
    });

    testWidgets('el editor de una tarea nueva encima: igual', (tester) async {
      await pumpWeb(tester);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(web.last.stops, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(web.last.loads, [_saved, _saved]);
    });
  });

  group('CA-009-05 (T-009-08): editar carga la nueva dirección', () {
    testWidgets('desde el menú, "Abrir" con otra dirección: WebView nueva '
        'con la nueva dirección; la anterior se suelta y se borra', (
      tester,
    ) async {
      await pumpWeb(tester);
      final first = web.last;
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.byType(UrlSheet), findsOneWidget);
      // La hoja no tapa la tarea: no se quita la página.
      expect(first.stops, 0);
      await tester.enterText(
        find.descendant(
          of: find.byType(UrlSheet),
          matching: find.byType(TextField),
        ),
        'agenda.festival.example/lunes',
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(web.drivers, hasLength(2));
      expect(first.disposed, isTrue);
      expect(web.janitor.cleared, contains(first.nativeId));
      expect(web.last.loads, [
        Uri.parse('https://agenda.festival.example/lunes'),
      ]);
      expect(
        tester.widget<WebBar>(find.byType(WebBar)).host,
        'agenda.festival.example',
      );
    });
  });

  group('Avisos (spec 009 §5)', () {
    testWidgets('CA-009-08: sin conexión, "Necesitas conexión…" y '
        '"Reintentar" (anunciados); "Reintentar" vuelve a cargar y anuncia '
        '"Cargando página"', (tester) async {
      listen(tester);
      await pumpWeb(tester);
      web.last.started(_address);
      web.last.error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      expect(
        notice('Necesitas conexión para ver esta página.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Abrir en el navegador'), findsNothing);
      // La página no se ve (ni la lee el lector) bajo el aviso.
      expect(
        find.byKey(const ValueKey('web-view-0'), skipOffstage: true),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('web-loading')), findsNothing);
      expect(announcements, ['Necesitas conexión para ver esta página.']);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(web.last.loads, [_saved, _saved]);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.byKey(const ValueKey('web-loading')), findsOneWidget);
      expect(announcements.last, 'Cargando página');
    });

    testWidgets('CA-009-08: 20 s sin que empiece a verse → sin conexión', (
      tester,
    ) async {
      await pumpWeb(tester);
      await tester.pump(webLoadTimeout);
      await tester.pumpAndSettle();
      expect(
        notice('Necesitas conexión para ver esta página.'),
        findsOneWidget,
      );
    });

    testWidgets('CA-009-09: el servidor no admite https → aviso y "Abrir en '
        'el navegador", que abre la dirección guardada sin confirmar', (
      tester,
    ) async {
      listen(tester);
      const http = 'http://viejo.ejemplo.com/carta';
      await pumpWeb(tester, task: _webTask(url: http));
      expect(web.last.loads, [Uri.parse('https://viejo.ejemplo.com/carta')]);
      web.last.error(WebLoadError.connect);
      await tester.pumpAndSettle();
      const text =
          'Esta página no usa conexión segura. Ábrela en el navegador.';
      expect(notice(text), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(announcements, [text]);
      await tester.tap(find.text('Abrir en el navegador'));
      await tester.pumpAndSettle();
      final opened = opener.opened.single as WebLink;
      expect(opened.uri, Uri.parse(http));
      expect(opened.host, 'viejo.ejemplo.com');
      // Sin confirmación.
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('CA-009-10: certificado no válido → aviso con "Abrir en el '
        'navegador" y "Reintentar", en ese orden', (tester) async {
      listen(tester);
      await pumpWeb(tester);
      web.last.certificate();
      await tester.pumpAndSettle();
      const text = 'No se ha podido cargar la página (certificado no válido).';
      expect(notice(text), findsOneWidget);
      expect(announcements, [text]);
      final open = tester.getRect(find.text('Abrir en el navegador'));
      final retry = tester.getRect(find.text('Reintentar'));
      expect(open.top, lessThan(retry.top));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(web.last.loads, [_saved, _saved]);
    });

    testWidgets('CA-009-06, CA-009-09: con el aviso de conexión no segura la '
        'barra no muestra el candado (propietario, 2026-09-29); con los '
        'demás estados, sí; el dominio, "WEB" y la lectura no cambian', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Finder lock() => find.descendant(
        of: find.byType(WebBar),
        matching: find.byType(UnaIcon),
      );
      const label = 'Tarea actual: Página web de viejo.ejemplo.com';
      await pumpWeb(tester, task: _webTask(url: 'http://viejo.ejemplo.com/'));
      // Cargando: con candado.
      expect(lock(), findsOneWidget);
      final hostRect = tester.getRect(find.byType(HeadEllipsisText));
      web.last.error(WebLoadError.connect);
      await tester.pumpAndSettle();
      expect(
        notice('Esta página no usa conexión segura. Ábrela en el navegador.'),
        findsOneWidget,
      );
      expect(lock(), findsNothing);
      final bar = tester.widget<WebBar>(find.byType(WebBar));
      expect((bar.host, bar.badge), ('viejo.ejemplo.com', 'WEB'));
      expect(tester.getRect(find.byType(HeadEllipsisText)), hostRect);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        tester.getRect(find.bySemanticsLabel(label)),
        tester.getRect(find.byType(WebBar)),
      );
      handle.dispose();
    });

    for (final (name, fail) in <(String, void Function(FakeWebPageDriver))>[
      ('sin conexión', (d) => d.error(WebLoadError.hostLookup)),
      ('certificado', (d) => d.certificate()),
      ('no es una página', (d) => d.download()),
      ('página vista', (d) => d.started(_address)),
    ]) {
      testWidgets('CA-009-06: con "$name", la barra sigue con el candado', (
        tester,
      ) async {
        await pumpWeb(tester);
        fail(web.last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(WebBar),
            matching: find.byType(UnaIcon),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('CL-009-4: no es una página → aviso y "Abrir en el '
        'navegador"', (tester) async {
      await pumpWeb(tester);
      web.last.download();
      await tester.pumpAndSettle();
      expect(
        notice('Esta dirección no es una página web. Ábrela en el navegador.'),
        findsOneWidget,
      );
      expect(find.text('Abrir en el navegador'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('CA-009-20: con el texto al 200 % en 360 dp, el aviso y sus '
        'botones se ven enteros (≥ 48 dp)', (tester) async {
      await pumpWithApp(
        tester,
        CurrentTaskScreen(task: _webTask()),
        size: const Size(360, 740),
        textScale: 2,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      web.last.certificate();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Abrir en el navegador', 'Reintentar']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(Semantics),
        );
        expect(tester.getSize(button.first).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('CA-009-18: lectura', () {
    testWidgets('la barra es el nodo de la tarea, con el dominio entero, '
        'Completar y Eliminar', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      const label = 'Tarea actual: Página web de $_host';
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          customActions: const [
            CustomSemanticsAction(label: 'Completar tarea'),
            CustomSemanticsAction(label: 'Eliminar tarea'),
          ],
        ),
      );
      // Es la barra.
      expect(
        tester.getRect(find.bySemanticsLabel(label)),
        tester.getRect(find.byType(WebBar)),
      );
      handle.dispose();
    });

    testWidgets('"Eliminar tarea" del lector abre la confirmación', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Tarea actual: Página web de $_host'),
      );
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Eliminar tarea',
      );
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
      // Una hoja: la página sigue.
      expect(web.last.stops, 0);
      handle.dispose();
    });
  });

  group('CA-009-12: atrás', () {
    testWidgets('hace lo mismo que en cualquier tarea (cierra la app) y no '
        'toca la página', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpWeb(tester);
      web.last.started(_address);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
      expect(web.last.loads, [_saved]);
    });
  });

  group('CL-009-11: completar o eliminar', () {
    testWidgets('al irse la tarea, se deja de cargar, se borran los datos y '
        'se suelta la WebView', (tester) async {
      await pumpWeb(tester);
      final driver = web.last;
      final node = find.byType(TaskWeb);
      expect(node, findsOneWidget);
      // Se elimina por el menú.
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(find.byType(TaskWeb), findsNothing);
      expect(driver.disposed, isTrue);
      expect(web.janitor.cleared, contains(driver.nativeId));
    });
  });
}
