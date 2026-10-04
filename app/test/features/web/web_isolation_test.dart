// Aislamiento de la tarea web (spec 009, T-009-14): nada de la página se
// queda en el móvil al salir de la tarea, por cualquier camino y en cualquier
// estado de la página (CA-009-13, CL-009-11); la página no tiene ningún
// puente con la app, y nada de las páginas llega al registro (CL-009-9).
//
// La WebView real se prueba en el emulador (`integration_test/`): aquí, con
// la falsa (`FakeWebPages`), se comprueba que la app pide el borrado.
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/task_web.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/features/web/web_page_driver_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../task_list/list_harness.dart' show FakeClock, background;

const _address = 'https://www.congreso.ejemplo.com/programa';
const _host = 'congreso.ejemplo.com';
const _otherPage = 'https://formularios.otro.org/enviar';

Task _webTask({String url = _address}) {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: 'w',
    text: null,
    status: TaskStatus.pending,
    rank: 'MA',
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-w', url: url), at),
  );
}

class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

/// Un estado de la página antes de salir de la tarea (spec 009 §5).
typedef _PageState = ({
  String name,
  String url,
  void Function(FakeWebPageDriver page) reach,
});

final List<_PageState> _states = [
  (name: 'mientras carga (CL-009-11)', url: _address, reach: (_) {}),
  (
    name: 'con la página a la vista',
    url: _address,
    reach: (p) => p.started(_address),
  ),
  (
    name: 'sin conexión',
    url: _address,
    reach: (p) => p.error(WebLoadError.hostLookup),
  ),
  (
    name: 'sin https',
    url: 'http://www.congreso.ejemplo.com/programa',
    reach: (p) => p.error(WebLoadError.connect),
  ),
  (name: 'certificado no válido', url: _address, reach: (p) => p.certificate()),
  (name: 'no es una página', url: _address, reach: (p) => p.download()),
  (
    // El aviso nuevo de T-009-12: la página intenta ir a otra dos veces
    // seguidas y se deja de recargar.
    name: 'tras recargas seguidas ("intenta abrir otra página")',
    url: _address,
    reach: (p) => p
      ..started(_address)
      ..started(_otherPage)
      ..started(_address)
      ..started(_otherPage),
  ),
];

/// Ejecuta la acción del lector [action] del nodo con la etiqueta [label].
Future<void> _semanticAction(
  WidgetTester tester,
  String label,
  String action,
) async {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)!.label == action,
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
  await tester.pumpAndSettle();
}

/// Un camino por el que se deja de ver la tarea web (CA-009-13: "otra
/// pantalla, otra tarea, completar, eliminar"). [released]: si la tarea web
/// se va de la pantalla principal (la WebView se suelta) o solo queda tapada.
typedef _Exit = ({
  String name,
  bool released,
  Future<void> Function(WidgetTester tester) run,
});

final List<_Exit> _exits = [
  (
    name: 'otra pantalla: el listado',
    released: false,
    run: (tester) async {
      await _openMenu(tester);
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
    },
  ),
  (
    name: 'otra pantalla: el editor de una tarea nueva',
    released: false,
    run: (tester) async {
      await _openMenu(tester);
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'otra tarea: "Hacer actual" desde el listado',
    released: true,
    run: (tester) async {
      await _openMenu(tester);
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      await _semanticAction(tester, '2 de 2: Segunda', 'Hacer actual');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.byType(TaskWeb), findsNothing);
    },
  ),
  (
    name: 'otra dirección: editar la tarea web',
    released: true,
    run: (tester) async {
      await _openMenu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(UrlSheet),
          matching: find.byType(TextField),
        ),
        'agenda.festival.example/lunes',
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      // Otra WebView, con la dirección nueva.
      expect(find.byType(TaskWeb), findsOneWidget);
      expect(
        tester.widget<WebBar>(find.byType(WebBar)).host,
        'agenda.festival.example',
      );
    },
  ),
  (
    name: 'completar (acción del lector)',
    released: true,
    run: (tester) async {
      await _semanticAction(
        tester,
        'Tarea actual: Página web de $_host',
        'Completar tarea',
      );
      expect(find.text('Segunda'), findsOneWidget);
    },
  ),
  (
    name: 'eliminar (menú)',
    released: true,
    run: (tester) async {
      await _openMenu(tester);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Segunda'), findsOneWidget);
    },
  ),
];

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;

  List<Override> overrides() => [
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(_Opener()),
    attachmentStoreProvider.overrideWithValue(MemoryAttachmentStore()),
    imageImporterProvider.overrideWithValue(
      FakeImageImporter(MemoryAttachmentStore()),
    ),
  ];

  setUp(() => web = FakeWebPages());

  Future<void> pumpWeb(
    WidgetTester tester, {
    String url = _address,
    FakeClock? clock,
  }) async {
    final repo = InMemoryTaskRepository();
    await repo.insert(_webTask(url: url));
    await pumpUnaApp(
      tester,
      repo: repo,
      tasks: const ['Segunda'],
      clock: clock,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  group('CA-009-13, CL-009-11: al dejar de ver la tarea se deja de cargar y '
      'se borran cookies, almacenamiento web y caché', () {
    for (final exit in _exits) {
      for (final state in _states) {
        testWidgets('${exit.name}, ${state.name}', (tester) async {
          final handle = tester.ensureSemantics();
          await pumpWeb(tester, url: state.url);
          final page = web.last;
          state.reach(page);
          await tester.pumpAndSettle();
          final stops = page.stops;
          final loads = page.loads.length;
          expect(web.janitor.cleared, isEmpty);

          await exit.run(tester);

          // Se deja de cargar y se borra con la WebView que se veía.
          expect(page.stops, greaterThan(stops));
          expect(web.janitor.cleared, contains(page.nativeId));
          expect(page.disposed, exit.released);
          // Lo que llegue después de esa WebView no carga nada.
          page
            ..started(_address)
            ..started(_otherPage)
            ..error(WebLoadError.hostLookup, url: _otherPage);
          await tester.pumpAndSettle();
          expect(page.loads, hasLength(loads));
          handle.dispose();
        });
      }
    }
  });

  testWidgets('CA-009-13: al volver de otra pantalla, la página se carga '
      'después del borrado (con la marca escrita otra vez)', (tester) async {
    await pumpWeb(tester);
    final page = web.last;
    page.started(_address);
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(web.janitor.cleared, [page.nativeId]);
    expect(web.janitor.marks, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(web.janitor.marks, 2);
    expect(page.loads, hasLength(2));
  });

  testWidgets('CA-009-07, CA-009-13: tras 10 minutos en segundo plano, se '
      'borra todo antes de volver a cargar', (tester) async {
    final clock = FakeClock();
    await pumpWeb(tester, clock: clock);
    final page = web.last;
    page.started(_address);
    await tester.pumpAndSettle();
    background(tester, clock, UnaApp.resetAfter);
    await tester.pumpAndSettle();
    expect(web.janitor.cleared, contains(page.nativeId));
    // La tarea se ve otra vez, cargando desde cero.
    expect(find.byType(WebBar), findsOneWidget);
    expect(web.last.loads.last, Uri.parse(_address));
  });

  testWidgets('CA-009-13, ADR-0017: tras el fallo del proceso de la página, '
      'al salir se borra con la WebView nueva', (tester) async {
    await pumpWeb(tester);
    final dead = web.last;
    dead
      ..started(_address)
      ..processGone();
    await tester.pumpAndSettle();
    expect(web.drivers, hasLength(2));
    final fresh = web.last;
    expect(dead.destroyed, isTrue);
    await _openMenu(tester);
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(web.janitor.cleared, [fresh.nativeId]);
    expect(fresh.stops, 1);
  });

  group(
    'CA-009-13: si la app se cerró sin borrar, en el siguiente arranque',
    () {
      testWidgets('se borra después del primer fotograma y antes de cargar '
          'ninguna página', (tester) async {
        final janitor = _LaunchJanitor();
        final repo = InMemoryTaskRepository();
        await repo.insert(_webTask());
        final drivers = <FakeWebPageDriver>[];
        await pumpUnaApp(
          tester,
          repo: repo,
          overrides: [
            webPageDriverFactoryProvider.overrideWithValue(() {
              final driver = FakeWebPageDriver(
                nativeId: 90,
                onLoad: (_) => janitor.events.add('load'),
              );
              drivers.add(driver);
              return driver;
            }),
            webDataJanitorProvider.overrideWithValue(janitor),
            linkOpenerProvider.overrideWithValue(_Opener()),
          ],
        );
        await tester.pumpAndSettle();
        // Una sola vez, con la barra ya pintada (primer fotograma), y antes de
        // la marca y de la primera carga.
        expect(janitor.events, ['launch', 'mark', 'load']);
        expect(janitor.barPaintedAtLaunch, isTrue);
      });
    },
  );

  group('CA-009-13: la página no tiene ningún puente con la app', () {
    test('ningún canal JS ni interfaz JavaScript en lib/ ni en el código '
        'nativo', () {
      final bridges = RegExp(
        r'addJavaScriptChannel|JavaScriptChannel|addJavascriptInterface|'
        r'JavascriptInterface|addWebMessageListener|createWebMessageChannel|'
        r'postWebMessage|WebMessagePort',
      );
      final offenders = [
        for (final file in _sources('lib', '.dart'))
          if (bridges.hasMatch(file.readAsStringSync())) file.path,
        for (final file in _sources('android/app/src/main/kotlin', '.kt'))
          if (bridges.hasMatch(file.readAsStringSync())) file.path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('CL-009-9: ningún registro con direcciones, dominios ni contenido', () {
    test('lib/ no escribe en el registro (ni print, ni debugPrint, ni '
        'dart:developer)', () {
      final logs = RegExp(
        r'''\bprint\(|debugPrint|dart:developer|\blog\(|stdout|stderr''',
      );
      final offenders = [
        for (final file in _sources('lib', '.dart'))
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && logs.hasMatch(line))
              '${file.path}:${i + 1}',
      ];
      expect(offenders, isEmpty);
    });

    test('el código nativo de la app no escribe en el registro', () {
      final logs = RegExp(
        r'android\.util\.Log|\bLog\.[a-z]\(|println|printStackTrace',
      );
      final offenders = [
        for (final file in _sources('android/app/src/main/kotlin', '.kt'))
          if (logs.hasMatch(file.readAsStringSync())) file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('la consola de la página no llega al registro del sistema', () {
      final driver = File('lib/features/web/webview_page_driver.dart')
          .readAsStringSync();
      expect(driver, contains('setOnConsoleMessage((_) {})'));
    });
  });
}

Iterable<File> _sources(String dir, String extension) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith(extension));

/// Registra el orden del borrado del arranque, la marca y la primera carga.
class _LaunchJanitor extends FakeWebDataJanitor {
  final events = <String>[];
  bool? barPaintedAtLaunch;

  @override
  Future<void> clearAfterLaunch() async {
    barPaintedAtLaunch = find.byType(WebBar).evaluate().isNotEmpty;
    events.add('launch');
  }

  @override
  Future<void> markUsed() async {
    events.add('mark');
    await super.markUsed();
  }
}
