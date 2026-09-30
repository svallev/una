// Accesibilidad global de la tarea web (spec 009, T-009-19): orden de
// lectura, un único anuncio por acción, foco, objetivos táctiles y texto al
// 200 % en un móvil de 360 dp. Lo que solo se ve con TalkBack (a qué nodo va
// su foco al cambiar de ventana) se comprueba en el emulador (tasks.md).
import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_web_page_driver.dart';
import '../../support/focus.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _address = 'https://www.congreso.ejemplo.com/programa';
const _host = 'congreso.ejemplo.com';
const _node = 'Tarea actual: Página web de $_host';

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

  final opened = <LinkTarget>[];
  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return true;
  }
}

/// Un aviso de la §5: cómo se provoca, con qué dirección guardada, su texto
/// y sus acciones.
typedef _Notice = ({
  String name,
  String url,
  void Function(FakeWebPageDriver) fail,
  String text,
  List<String> actions,
});

final _notices = <_Notice>[
  (
    name: 'sin conexión',
    url: _address,
    fail: (d) => d.error(WebLoadError.hostLookup),
    text: 'Necesitas conexión para ver esta página.',
    actions: ['Reintentar'],
  ),
  (
    name: 'sin https',
    url: 'http://www.congreso.ejemplo.com/programa',
    fail: (d) => d.error(WebLoadError.connect),
    text: 'Esta página no usa conexión segura. Ábrela en el navegador.',
    actions: ['Abrir en el navegador'],
  ),
  (
    name: 'certificado',
    url: _address,
    fail: (d) => d.certificate(),
    text: 'No se ha podido cargar la página (certificado no válido).',
    actions: ['Abrir en el navegador', 'Reintentar'],
  ),
  (
    name: 'no es una página',
    url: _address,
    fail: (d) => d.download(),
    text: 'Esta dirección no es una página web. Ábrela en el navegador.',
    actions: ['Abrir en el navegador'],
  ),
  (
    name: 'intenta abrir otra página',
    url: _address,
    fail: (d) => d
      ..started(_address)
      ..started('https://formularios.otro.org/enviar')
      ..started(_address)
      ..started('https://formularios.otro.org/enviar'),
    text: 'No se ha podido cargar la página (intenta abrir otra página).',
    actions: ['Abrir en el navegador', 'Reintentar'],
  ),
];

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;
  late _Opener opener;
  late List<String> announcements;

  List<Override> overrides() => [
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(opener),
    attachmentStoreProvider.overrideWithValue(MemoryAttachmentStore()),
  ];

  setUp(() {
    web = FakeWebPages();
    opener = _Opener();
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

  /// La tarea web en la pantalla principal (con una tarea de texto detrás).
  Future<void> pumpWeb(
    WidgetTester tester, {
    Task? task,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    final repo = InMemoryTaskRepository();
    await repo.insert(task ?? _webTask());
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: task ?? _webTask()),
      repo: repo,
      size: size,
      textScale: textScale,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  /// La app pasa a segundo plano (otra app, el navegador) y vuelve.
  Future<void> awayAndBack(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Lo que lee el lector, en su orden, del primero al último.
  List<String> reading(WidgetTester tester) => [
    for (final node in tester.semantics.simulatedAccessibilityTraversal())
      if (node.label.isNotEmpty) node.label,
  ];

  group('CA-009-18: orden de lectura en vertical', () {
    testWidgets('la tarea (la barra) lo primero, luego la página, el menú y '
        'el botón de completar', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      web.last
        ..started(_address)
        ..finished(_address);
      await tester.pumpAndSettle();
      expect(reading(tester), [
        _node,
        'Menú de la tarea',
        'Pulsa para completar',
      ]);
      handle.dispose();
    });

    testWidgets('mientras carga: la tarea y después "Cargando página"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      expect(reading(tester), [
        _node,
        'Cargando página',
        'Menú de la tarea',
        'Pulsa para completar',
      ]);
      handle.dispose();
    });

    for (final n in _notices) {
      testWidgets('con el aviso (${n.name}): la tarea, el aviso y sus '
          'acciones, después el menú y completar', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWeb(tester, task: _webTask(url: n.url));
        n.fail(web.last);
        await tester.pumpAndSettle();
        expect(reading(tester), [
          _node,
          n.text,
          ...n.actions,
          'Menú de la tarea',
          'Pulsa para completar',
        ]);
        handle.dispose();
      });
    }
  });

  group('CA-009-19: foco y anuncios', () {
    for (final n in _notices) {
      testWidgets('aviso (${n.name}): un único anuncio, su texto; el foco no '
          'se mueve', (tester) async {
        await pumpWeb(tester, task: _webTask(url: n.url));
        listen(tester);
        final focused = FocusManager.instance.primaryFocus;
        n.fail(web.last);
        await tester.pumpAndSettle();
        expect(announcements, [n.text]);
        expect(FocusManager.instance.primaryFocus, same(focused));
      });
    }

    testWidgets('"Reintentar": un único anuncio, "Cargando página"; si '
        'vuelve a fallar, el aviso otra vez', (tester) async {
      await pumpWeb(tester);
      listen(tester);
      web.last.error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      announcements.clear();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(announcements, ['Cargando página']);
      web.last.error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      expect(announcements, [
        'Cargando página',
        'Necesitas conexión para ver esta página.',
      ]);
    });

    for (final n in _notices) {
      if (!n.actions.contains('Abrir en el navegador')) continue;
      testWidgets('vuelve del navegador con el aviso (${n.name}): sin '
          'anuncios (se reintenta sola y, si falla igual, no se repite)', (
        tester,
      ) async {
        await pumpWeb(tester, task: _webTask(url: n.url));
        listen(tester);
        n.fail(web.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abrir en el navegador'));
        await tester.pumpAndSettle();
        expect(opener.opened, hasLength(1));
        announcements.clear();
        final loads = web.last.loads.length;
        await awayAndBack(tester);
        // Se reintenta sola (CA-009-08) y vuelve el mismo aviso.
        expect(web.last.loads, hasLength(loads + 1));
        n.fail(web.last);
        await tester.pumpAndSettle();
        expect(find.text(n.text), findsOneWidget);
        expect(announcements, isEmpty);
      });
    }

    testWidgets('vuelve a la app sin conexión: el mismo aviso no se repite; '
        'uno distinto, sí', (tester) async {
      await pumpWeb(tester);
      listen(tester);
      web.last.error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      await awayAndBack(tester);
      web.last.error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      expect(announcements, ['Necesitas conexión para ver esta página.']);
      await awayAndBack(tester);
      web.last.certificate();
      await tester.pumpAndSettle();
      expect(announcements, [
        'Necesitas conexión para ver esta página.',
        'No se ha podido cargar la página (certificado no válido).',
      ]);
    });

    testWidgets('"Reintentar": hasta que la página empieza a verse, la WebView '
        'no se ve ni la lee el lector (lo que quedó de la carga fallida, p. ej. '
        'la página de error de la WebView, no se enfoca)', (tester) async {
      await pumpWeb(tester);
      Finder view() => find.byKey(const ValueKey('web-view-0'));
      web.last
        ..started(_address)
        ..error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-loading')), findsOneWidget);
      expect(view(), findsNothing);
      expect(view().hitTestable(), findsNothing);
      expect(
        find.byKey(const ValueKey('web-view-0'), skipOffstage: false),
        findsOneWidget,
      );
      web.last.started(_address);
      await tester.pumpAndSettle();
      expect(view(), findsOneWidget);
    });

    testWidgets('tocar un enlace de la página: ningún anuncio', (tester) async {
      await pumpWeb(tester);
      listen(tester);
      web.last.started(_address);
      await tester.pumpAndSettle();
      web.last.navigate('https://otro.example/');
      await tester.pumpAndSettle();
      expect(announcements, isEmpty);
    });
  });

  group('CA-009-20: objetivos táctiles y etiquetas', () {
    testWidgets('mientras carga', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWeb(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    for (final n in _notices) {
      testWidgets('con el aviso (${n.name})', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWeb(tester, task: _webTask(url: n.url));
        n.fail(web.last);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('CA-009-20 / spec §6 (WCAG 2.4.7): anillo de foco con teclado', () {
    testWidgets('con Tab, "Abrir en el navegador" y "Reintentar" del aviso '
        'muestran el anillo de foco', (tester) async {
      await pumpWeb(tester);
      web.last.certificate();
      await tester.pumpAndSettle();
      for (final label in ['Abrir en el navegador', 'Reintentar']) {
        expect(await tabUntilRing(tester, label), isTrue, reason: label);
      }
    });
  });

  group('CA-009-20: texto al 200 % en 360 dp', () {
    const small = Size(360, 740);

    testWidgets('la barra: el dominio largo se recorta por el principio, sin '
        'desbordar, y la lectura lo dice entero', (tester) async {
      final handle = tester.ensureSemantics();
      const long =
          'https://agenda.congreso-internacional-de-cardiologia.ejemplo.com/';
      await pumpWeb(
        tester,
        task: _webTask(url: long),
        size: small,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final shown = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(HeadEllipsisText),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(shown, startsWith('…'));
      expect(shown, endsWith('ejemplo.com'));
      expect(
        find.bySemanticsLabel(
          'Tarea actual: Página web de '
          'agenda.congreso-internacional-de-cardiologia.ejemplo.com',
        ),
        findsOneWidget,
      );
      final bar = tester.getRect(find.byType(WebBar));
      expect((bar.left, bar.right), (0, 360));
      handle.dispose();
    });

    for (final n in _notices) {
      testWidgets('el aviso (${n.name}) se ve entero y sus acciones miden '
          '≥ 48 dp', (tester) async {
        await pumpWeb(
          tester,
          task: _webTask(url: n.url),
          size: small,
          textScale: 2,
        );
        n.fail(web.last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final zone = tester.getRect(find.byKey(const ValueKey('web-page')));
        final shown = tester.getRect(find.text(n.text));
        expect(zone.contains(shown.topLeft), isTrue, reason: '$shown');
        expect(zone.contains(shown.bottomRight), isTrue, reason: '$shown');
        for (final label in n.actions) {
          final button = tester.getRect(find.bySemanticsLabel(label));
          expect(button.height, greaterThanOrEqualTo(48), reason: label);
          expect(button.width, greaterThanOrEqualTo(48), reason: label);
          expect(zone.contains(button.center), isTrue, reason: label);
        }
      });
    }
  });
}
