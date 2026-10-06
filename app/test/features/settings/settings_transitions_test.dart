import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart' show sampleTask;
import 'settings_harness.dart';

/// Entrada a Ajustes desde el menú y vuelta a la tarea (spec 015, T-015-10,
/// P-015-1): el menú se cierra y Ajustes sube a la vez; Cerrar, atrás y Escape
/// vuelven a la tarea con el foco en el botón de menú.

const _menuButton = 'Menú de la tarea';
const _frame = Duration(milliseconds: 16);

final _menu = find.byType(MenuSheet);
final _settings = find.byType(SettingsScreen);

/// Estado de la animación de la ruta que contiene [type].
AnimationStatus _status(WidgetTester tester, Finder type) =>
    ModalRoute.of(tester.element(type))!.animation!.status;

/// Abre el menú y toca "Ajustes", sin esperar a que la ruta termine de subir.
Future<void> _tapSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(_menuButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajustes'));
  // El primer fotograma deja correr la continuación que empuja la ruta; el
  // segundo la construye y arranca su animación.
  await tester.pump();
  await tester.pump();
}

/// Los avisos de foco del lector (el id del nodo al que van).
List<int> _focusEvents(WidgetTester tester) {
  final events = <int>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'focus') events.add(map['nodeId']! as int);
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
  return events;
}

void main() {
  setUpAll(loadAppFonts);

  group(
    'CA-015-01a, CA-015-01d: el menú se cierra y Ajustes sube a la vez',
    () {
      testWidgets('CA-015-01a: la acción "Ajustes" cierra el menú y empuja '
          'Ajustes; durante la subida se ven los dos y luego solo Ajustes', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await _tapSettings(tester);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_settings, findsOneWidget);
        expect(_menu, findsOneWidget, reason: 'el menú aún baja');
        await tester.pumpAndSettle();
        expect(_settings, findsOneWidget);
        expect(_menu, findsNothing);
        // La tarea de debajo no tiene el menú abierto.
        await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
        await settleSettings(tester);
        expect(_settings, findsNothing);
        expect(_menu, findsNothing);
        expect(find.text('Primera'), findsOneWidget);
      });

      testWidgets('CA-015-01d: Ajustes sube en 200 ms y baja en 160 ms', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await _tapSettings(tester);
        expect(_status(tester, _settings), AnimationStatus.forward);
        // Arranca desde abajo del todo.
        expect(
          tester.getTopLeft(_settings).dy,
          tester.view.physicalSize.height,
        );
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.getTopLeft(_settings).dy;
        expect(mid, inExclusiveRange(0, tester.view.physicalSize.height));
        await tester.pump(const Duration(milliseconds: 90));
        expect(_status(tester, _settings), AnimationStatus.forward);
        await tester.pump(const Duration(milliseconds: 20));
        expect(_status(tester, _settings), AnimationStatus.completed);
        expect(tester.getTopLeft(_settings).dy, 0);
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
        await tester.pump();
        expect(_status(tester, _settings), AnimationStatus.reverse);
        await tester.pump(const Duration(milliseconds: 150));
        expect(_settings, findsOneWidget);
        expect(_status(tester, _settings), AnimationStatus.reverse);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(_frame);
        expect(_settings, findsNothing);
      });

      testWidgets('CA-015-01d: el nivel 2 es un fundido de 160 ms', (
        tester,
      ) async {
        await openSettingsScreen(tester);
        await tester.tap(inSettings(find.text('Idioma')));
        await tester.pump();
        await tester.pump();
        final page = find.byType(LanguagePage);
        expect(_status(tester, page), AnimationStatus.forward);
        await tester.pump(const Duration(milliseconds: 150));
        expect(_status(tester, page), AnimationStatus.forward);
        await tester.pump(const Duration(milliseconds: 20));
        expect(_status(tester, page), AnimationStatus.completed);
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(_status(tester, page), AnimationStatus.reverse);
        await tester.pump(const Duration(milliseconds: 150));
        expect(_status(tester, page), AnimationStatus.reverse);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(_frame);
        expect(page, findsNothing);
      });

      testWidgets('CA-015-01d: con reducir movimiento todo es instantáneo '
          '(sube, baja y el nivel 2)', (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
          reduced: true,
        );
        await _tapSettings(tester);
        await tester.pump(_frame);
        expect(_status(tester, _settings), AnimationStatus.completed);
        expect(tester.getTopLeft(_settings).dy, 0);
        expect(_menu, findsNothing);

        await tester.tap(inSettings(find.text('Idioma')));
        await tester.pump();
        await tester.pump(_frame);
        final page = find.byType(LanguagePage);
        expect(_status(tester, page), AnimationStatus.completed);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(_frame);
        expect(page, findsNothing);

        await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
        await tester.pump();
        await tester.pump(_frame);
        expect(_settings, findsNothing);
      });
    },
  );

  group('CL-015-1: doble toque en "Ajustes"', () {
    testWidgets('dos toques seguidos abren una sola pantalla y un solo Cerrar '
        'vuelve a la tarea', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await tester.tap(find.bySemanticsLabel(_menuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.tap(find.text('Ajustes'), warnIfMissed: false);
      await settleSettings(tester);
      expect(_settings, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      expect(_settings, findsNothing);
      expect(_menu, findsNothing);
      expect(find.text('Primera'), findsOneWidget);
    });

    testWidgets('un segundo toque con la ruta subiendo no cae sobre la fila '
        'que pasa bajo el dedo (la ruta absorbe los punteros)', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await _tapSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_status(tester, _settings), AnimationStatus.forward);
      // El dedo está justo donde, en este instante, pasa la fila "Idioma".
      final under = tester.getCenter(inSettings(find.text('Idioma')));
      await tester.tapAt(under);
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePage), findsNothing);
      expect(_settings, findsOneWidget);
      // Ya subida, la misma fila sí responde.
      await tester.tap(inSettings(find.text('Idioma')));
      await settleSettings(tester);
      expect(find.byType(LanguagePage), findsOneWidget);
    });
  });

  group('CA-015-02: Cerrar, atrás y Escape vuelven a la tarea', () {
    final closers = <(String, Future<void> Function(WidgetTester))>[
      (
        'Cerrar ajustes',
        (tester) => tester.tap(find.bySemanticsLabel('Cerrar ajustes')),
      ),
      ('atrás del sistema', (tester) => tester.binding.handlePopRoute()),
      ('Escape', (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape)),
    ];
    for (final (name, close) in closers) {
      testWidgets('$name: la tarea con el menú ya cerrado y el foco de '
          'teclado y del lector en el botón de menú', (tester) async {
        final handle = tester.ensureSemantics();
        final events = _focusEvents(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
          screenReader: true,
        );
        await tester.tap(find.bySemanticsLabel(_menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await settleSettings(tester);
        expect(_settings, findsOneWidget);
        events.clear();

        await close(tester);
        await settleSettings(tester);

        expect(_settings, findsNothing);
        expect(_menu, findsNothing);
        expect(find.text('Primera'), findsOneWidget);
        expect(focusedLabel(tester), _menuButton);
        final node = tester.getSemantics(find.bySemanticsLabel(_menuButton));
        expect(events, [node.id], reason: 'un solo aviso, al botón de menú');
        handle.dispose();
      });
    }

    testWidgets('con reducir movimiento, el foco también llega al botón de '
        'menú', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
        reduced: true,
      );
      await _tapSettings(tester);
      await settleSettings(tester);
      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      expect(_settings, findsNothing);
      expect(focusedLabel(tester), _menuButton);
    });

    testWidgets('desde el nivel 2: Volver sube al 1 y solo Cerrar vuelve a la '
        'tarea', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await _tapSettings(tester);
      await settleSettings(tester);
      await tester.tap(inSettings(find.text('Idioma')));
      await settleSettings(tester);
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(_settings, findsOneWidget);
      expect(focusedLabel(tester), 'Idioma');
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(_settings, findsNothing);
      expect(focusedLabel(tester), _menuButton);
    });
  });

  group('CA-015-01a: el botón y sus accesos', () {
    testWidgets('CA-015-22: el botón "Ajustes" mide 48 dp de alto '
        '(androidTapTargetGuideline sobre el menú abierto)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await tester.tap(find.bySemanticsLabel(_menuButton));
      await tester.pumpAndSettle();
      final button = find.ancestor(
        of: find.text('Ajustes'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(button).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('CL-015-4: sin tareas ("Todo hecho.") no hay forma de abrir '
        'Ajustes', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask(id: 'a', rank: 'a'));
      await repo.remove('a');
      await pumpUnaApp(tester, repo: repo);
      await tester.pumpAndSettle();
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(find.bySemanticsLabel(_menuButton), findsNothing);
      expect(find.text('Ajustes'), findsNothing);
      expect(find.bySemanticsLabel('Ajustes'), findsNothing);
      expect(_settings, findsNothing);
      handle.dispose();
    });
  });

  group('CA-015-24: abrir Ajustes confirma una eliminación pendiente', () {
    testWidgets('con la card a la vista, "Ajustes" la hace definitiva antes '
        'de que se vea Ajustes y no se puede recuperar al volver', (
      tester,
    ) async {
      final repo = InMemoryTaskRepository();
      await pumpUnaApp(
        tester,
        repo: repo,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await tester.tap(find.bySemanticsLabel(_menuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(_frame);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 300));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(undoProvider).phase, UndoPhase.visible);

      await tester.tap(find.bySemanticsLabel(_menuButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(undoProvider).phase,
        UndoPhase.visible,
        reason: 'abrir el menú no la confirma',
      );
      await tester.tap(find.text('Ajustes'));
      await tester.pump();
      await tester.pump();
      // Ya al empujar la ruta: definitiva, sin esperar a que suba.
      expect(_settings, findsOneWidget);
      expect(container.read(undoProvider).phase, UndoPhase.none);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(undoProvider).phase, UndoPhase.none);
      expect(await repo.findById('t0'), isNull);
    });
  });
}
