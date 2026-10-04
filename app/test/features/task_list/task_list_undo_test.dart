import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import '../../support/undo.dart';
import 'list_harness.dart';

/// Eliminar y deshacer desde el listado (spec 014, CA-014-02, CA-014-05,
/// CA-014-08, CA-014-10, CA-014-11, CA-014-16, CA-014-18, CA-014-20,
/// CA-014-22, CA-014-23, CL-014-2, CL-014-11, CL-014-12). Lo que TalkBack hace
/// de verdad se mira en el emulador (`specs/014-…/dispositivo.md`).
class _Repo extends InMemoryTaskRepository {
  bool failDelete = false;
  bool failInsert = false;
  int inserts = 0;

  /// Si se indica, `remove` espera a que se complete.
  Completer<void>? gate;

  @override
  Future<bool> remove(String id) async {
    final g = gate;
    if (g != null) await g.future;
    if (failDelete) throw StateError('disk I/O error');
    return super.remove(id);
  }

  @override
  Future<void> insert(Task task) async {
    inserts++;
    if (failInsert) throw StateError('disk I/O error: ${task.text}');
    return super.insert(task);
  }
}

final _card = find.byType(UndoCard);
final _undoButton = find.descendant(of: _card, matching: find.text('Deshacer'));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

UndoController _undo(WidgetTester tester) =>
    _container(tester).read(undoProvider.notifier);

UndoState _undoState(WidgetTester tester) =>
    _container(tester).read(undoProvider);

Future<_Repo> _open(
  WidgetTester tester, {
  required List<String> tasks,
  bool screenReader = false,
  bool reduced = false,
  _Repo? repo,
}) => openList(
  tester,
  tasks: tasks,
  repo: repo ?? _Repo(),
  screenReader: screenReader,
  reduced: reduced,
  overrides: [
    accessibilityTimeoutsProvider.overrideWithValue(
      FakeAccessibilityTimeouts(),
    ),
  ],
).then((r) => r as _Repo);

/// El botón "Eliminar tarea" de la fila [text].
Finder _trash(String text) => find
    .descendant(
      of: rowOf(text).first,
      matching: find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_UnaIconPainter',
      ),
    )
    .at(1);

/// Pulsa "Eliminar tarea" de la fila [text] y deja que se guarde.
Future<void> _delete(WidgetTester tester, String text) async {
  await tester.tap(_trash(text));
  await tester.pump();
  await tester.pump(frame);
}

/// Una eliminación a ritmo normal, tras otra (pasada la ventana de CL-014-2).
Future<void> _deleteNext(WidgetTester tester, String text) async {
  await _waitCard(tester);
  await _delete(tester, text);
}

/// Pasa lo que tarda la card en aceptar un "Deshacer" (CL-014-3).
Future<void> _waitCard(WidgetTester tester) =>
    tester.pump(UnaMotion.doubleTapWindow + frame);

Future<void> _tapUndo(WidgetTester tester) async {
  await _waitCard(tester);
  await tester.tap(_undoButton);
  await tester.pump();
  await tester.pump(frame);
}

String? _focusedRow() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx?.findAncestorWidgetOfExactType<TaskListRow>()?.task.text;
}

TaskListRow _row(WidgetTester tester, String text) => tester
    .widgetList<TaskListRow>(find.byType(TaskListRow))
    .firstWhere((r) => r.task.text == text);

/// Los avisos de foco del lector (id del nodo) y los anuncios.
List<int> _listenFocusEvents(
  WidgetTester tester, {
  required List<String> announcements,
}) {
  final events = <int>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'focus') events.add(map['nodeId']! as int);
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
  return events;
}

List<String> _reading(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((n) => n.label)
    .where((l) => l.isNotEmpty)
    .toList();

void main() {
  setUpAll(loadAppFonts);

  group('Eliminar sin hoja (CA-014-02)', () {
    testWidgets('CA-014-02: sin hoja, la fila desaparece sin animación y la '
        'card aparece a la vez', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await tester.tap(_trash('Segunda'));
      // Fotograma a fotograma: la fila y la card cambian en el mismo.
      for (var i = 0; i < 6; i++) {
        await tester.pump(frame);
        expect(
          rowOf('Segunda').evaluate().isEmpty,
          _card.evaluate().isNotEmpty,
          reason: 'fotograma $i',
        );
      }
      expect(find.text('¿Eliminar esta tarea?'), findsNothing);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(shownOrder(tester), ['Primera', 'Tercera']);
      expect(_card, findsOneWidget);
      expect(find.text('Tarea eliminada'), findsOneWidget);
      expect(
        find.descendant(of: _card, matching: find.text('Segunda')),
        findsOneWidget,
      );
      // "Nueva tarea" cede su sitio a la card (CA-014-05).
      expect(find.text('Nueva tarea'), findsNothing);
      expect(await order(repo), ['Primera', 'Tercera']);
      // La eliminación espera, retenida (ADR-0021): aún se puede deshacer.
      expect(_undoState(tester).phase, UndoPhase.visible);
      expect(_undoState(tester).host, UndoHost.list);
    });

    testWidgets('CA-014-02: eliminar la primera deja la siguiente como actual '
        '(aspecto de primera, sin asa)', (tester) async {
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester, 'Primera');
      final rows = tester.widgetList<TaskListRow>(find.byType(TaskListRow));
      expect(rows.first.task.text, 'Segunda');
      expect(rows.first.first, isTrue);
      expect(handleOf('Segunda'), findsNothing);
      expect(_card, findsOneWidget);
    });

    testWidgets('CA-014-19: la acción "Eliminar tarea" del lector elimina '
        'directamente', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('2 de 3: Segunda'),
      );
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Eliminar tarea',
      );
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      await tester.pump();
      await tester.pump(frame);
      expect(find.text('¿Eliminar esta tarea?'), findsNothing);
      expect(await order(repo), ['Primera', 'Tercera']);
      expect(_card, findsOneWidget);
      handle.dispose();
    });

    testWidgets('CL-014-2: un segundo toque en menos de 350 ms sobre los '
        'botones de la fila que sube no hace nada; a ritmo normal, sí', (
      tester,
    ) async {
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta']);
      final at = tester.getCenter(_trash('Segunda'));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(at);
      await tester.pump(frame);
      expect(shownOrder(tester), ['Primera', 'Tercera', 'Cuarta']);

      // Pasada la ventana, la misma posición sí elimina la siguiente.
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tapAt(at);
      await tester.pump(frame);
      expect(shownOrder(tester), ['Primera', 'Cuarta']);
    });
  });

  group('La card en el listado (CA-014-05, CA-014-16)', () {
    testWidgets('CA-014-16: la card va la primera para el lector y el resto '
        'del orden no cambia', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      final before = _reading(tester);
      expect(before, contains('Nueva tarea'));
      await _delete(tester, 'Segunda');
      final after = _reading(tester);
      expect(after.first, 'Deshacer. Tarea eliminada: Segunda');
      expect(after.where((l) => l.startsWith('Deshacer')), hasLength(1));
      // Lo demás, igual: sin "Nueva tarea" (la card ocupa su sitio) y sin la
      // fila eliminada.
      final rest = after.skip(1).toList();
      expect(rest, [
        for (final l in before)
          if (l == '1 de 3. Tarea actual: Primera')
            '1 de 2. Tarea actual: Primera'
          else if (l == '3 de 3: Tercera')
            '2 de 2: Tercera'
          else if (l != 'Nueva tarea' && l != '2 de 3: Segunda')
            l,
      ]);
      handle.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('CA-014-05: la card nunca tapa la última fila (×$scale)', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _open(tester, tasks: [for (var i = 1; i <= 12; i++) 'Tarea $i']);
        await _delete(tester, 'Tarea 2');
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump(frame);
        await tester.pump(frame);
        final card = tester.getRect(_card);
        expect(
          tester.getRect(rowOf('Tarea 12').first).bottom,
          lessThanOrEqualTo(card.top),
        );
        expect(
          tester.getRect(find.byType(CustomScrollView)).bottom,
          lessThanOrEqualTo(card.top),
        );
        // Y sigue a todo el ancho, abajo del todo.
        expect(card.bottom, tester.view.physicalSize.height);
      });
    }

    testWidgets('CA-014-16: el aviso de foco y el foco de entrada llegan a la '
        'card (con el lector)', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = <String>[];
      final events = _listenFocusEvents(tester, announcements: announcements);
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      await _delete(tester, 'Segunda');
      await tester.pump(frame);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: Segunda'),
      );
      expect(events, contains(node.id));
      expect(tester.widget<UndoCard>(_card).focusNode!.hasFocus, isTrue);
      // El lector no dice nada más (CA-014-16).
      expect(announcements, isEmpty);
      handle.dispose();
    });

    testWidgets('CA-014-17: con el lector, la cuenta espera al primer foco', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      await _delete(tester, 'Segunda');
      expect(_card, findsOneWidget);
      // Sin foco del lector aún, no corre: tras 10 s sigue.
      await tester.pump(const Duration(seconds: 10));
      expect(_card, findsOneWidget);
      handle.dispose();
    });
  });

  group('Varias eliminaciones seguidas (CA-014-08)', () {
    testWidgets('CA-014-08: la card se queda, cambia al texto y al color de B '
        'y empieza de nuevo, sin volver a entrar', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
        screenReader: true,
      );
      final events = _listenFocusEvents(tester, announcements: []);
      await _delete(tester, 'Segunda');
      final element = tester.element(_card);
      final focusNode = tester.widget<UndoCard>(_card).focusNode;
      final serialA = _undoState(tester).serial;
      // A mitad de su tiempo (el lector la leyó y siguió).
      _undo(tester)
        ..focusChanged(serialA, UndoFocus.reader, focused: true)
        ..focusChanged(serialA, UndoFocus.reader, focused: false);
      await tester.pump(const Duration(seconds: 2));

      await _deleteNext(tester, 'Tercera');
      expect(await order(repo), ['Primera', 'Cuarta']);
      // La misma card (sin volver a entrar), con la tarea de B.
      expect(tester.element(_card), same(element));
      expect(tester.widget<UndoCard>(_card).focusNode, same(focusNode));
      expect(tester.widget<UndoCard>(_card).task.text, 'Tercera');
      expect(_undoState(tester).serial, isNot(serialA));
      expect(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: Tercera'),
        findsOneWidget,
      );
      // Barra llena de nuevo y foco pedido otra vez.
      expect(_undo(tester).fraction, 1.0);
      expect(focusNode!.hasFocus, isTrue);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: Tercera'),
      );
      expect(events, contains(node.id));

      // El tiempo de B cuenta de nuevo: a los 3 s de B (5 s desde A) sigue.
      final serialB = _undoState(tester).serial;
      _undo(tester)
        ..focusChanged(serialB, UndoFocus.reader, focused: true)
        ..focusChanged(serialB, UndoFocus.reader, focused: false);
      await tester.pump(const Duration(seconds: 3));
      expect(_card, findsOneWidget);
      await tester.pump(const Duration(seconds: 1) + frame);
      expect(_card, findsNothing);
      // La de A era definitiva desde que se eliminó B: no vuelve.
      expect(await order(repo), ['Primera', 'Cuarta']);
      handle.dispose();
    });

    testWidgets('CA-014-08: solo se puede deshacer la última', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
      );
      await _delete(tester, 'Segunda');
      await _deleteNext(tester, 'Tercera');
      await _tapUndo(tester);
      await tester.pump(UnaMotion.sheetOut * 2);
      expect(await order(repo), ['Primera', 'Tercera', 'Cuarta']);
    });

    testWidgets('CA-014-22: si falla al eliminar, ni card ni aviso a la vez: '
        'la card de la anterior desaparece y queda definitiva', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
      );
      await _delete(tester, 'Segunda');
      expect(_card, findsOneWidget);
      repo.failDelete = true;
      await _deleteNext(tester, 'Tercera');
      await tester.pump(frame);
      expect(_card, findsNothing);
      expect(find.text('No hemos podido eliminar la tarea'), findsOneWidget);
      expect(_undoState(tester).phase, UndoPhase.none);
      expect(shownOrder(tester), ['Primera', 'Tercera', 'Cuarta']);

      repo.failDelete = false;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(shownOrder(tester), ['Primera', 'Cuarta']);
      expect(_card, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Cuándo es definitiva (CA-014-11, CA-014-12)', () {
    testWidgets('CL-014-11: levantar una fila para arrastrarla la hace '
        'definitiva', (tester) async {
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta']);
      await _delete(tester, 'Segunda');
      expect(_card, findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(handleOf('Cuarta')));
      await g.moveBy(const Offset(0, -10));
      await tester.pump();
      expect(_card, findsNothing);
      expect(_undoState(tester).phase, UndoPhase.none);
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('Nueva tarea'), findsOneWidget);
    });

    testWidgets('CL-014-11: abrir y cerrar "Mover" no la hace definitiva; '
        'elegir una opción, sí', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
      );
      await _delete(tester, 'Segunda');
      await _waitCard(tester);
      await tester.tap(handleOf('Cuarta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MOVER TAREA'), findsOneWidget);
      expect(_card, findsOneWidget, reason: 'la hoja no es otra pantalla');
      await tester.tapAt(const Offset(195, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MOVER TAREA'), findsNothing);
      expect(_card, findsOneWidget);
      expect(_undoState(tester).phase, UndoPhase.visible);

      await tester.tap(handleOf('Cuarta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Hacer actual'));
      await tester.pump();
      expect(_undoState(tester).phase, UndoPhase.none);
      await tester.pump(UnaMotion.sheetOut * 2);
      expect(_card, findsNothing);
      expect(await order(repo), ['Cuarta', 'Primera', 'Tercera']);
    });

    testWidgets('CL-014-11: la acción del lector de mover la hace definitiva', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
        screenReader: true,
      );
      await _delete(tester, 'Segunda');
      final node = tester.getSemantics(find.bySemanticsLabel('3 de 3: Cuarta'));
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Mover arriba',
      );
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      await tester.pump();
      expect(_undoState(tester).phase, UndoPhase.none);
      await tester.pump(UnaMotion.sheetOut * 2);
      handle.dispose();
    });

    testWidgets('CA-014-11: volver con el botón hace definitiva y lleva a la '
        'tarea', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester, 'Segunda');
      await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
      await tester.pump();
      expect(_undoState(tester).phase, UndoPhase.none);
      await tester.pumpAndSettle();
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(_card, findsNothing);
      expect(await order(repo), ['Primera', 'Tercera']);
    });

    testWidgets('CL-014-17: el gesto atrás vuelve a la pantalla principal y '
        'la hace definitiva', (tester) async {
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester, 'Segunda');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(_card, findsNothing);
      expect(_undoState(tester).phase, UndoPhase.none);
    });

    testWidgets('CA-014-11: ir al editor (crear o editar) la hace definitiva '
        'aunque luego se cancele', (tester) async {
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta']);
      await _delete(tester, 'Segunda');
      // "Nueva tarea" cede su sitio a la card: se va con un doble toque.
      await tester.tapAt(tester.getCenter(find.text('Tercera')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(tester.getCenter(find.text('Tercera')));
      await tester.pump(frame);
      await tester.pump(frame);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(_undoState(tester).phase, UndoPhase.none);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(_card, findsNothing);
      expect(find.text('Nueva tarea'), findsOneWidget);
    });

    testWidgets('CA-014-12: desplazar la lista no la hace definitiva y el '
        'tiempo sigue', (tester) async {
      await _open(tester, tasks: [for (var i = 1; i <= 15; i++) 'Tarea $i']);
      await _delete(tester, 'Tarea 2');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump(const Duration(seconds: 1));
      expect(_card, findsOneWidget);
      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
      expect(find.text('Nueva tarea'), findsOneWidget);
    });

    testWidgets('CA-014-06: a los 4 s la card desaparece y "Nueva tarea" '
        'vuelve', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester, 'Segunda');
      await tester.pump(UnaMotion.undoWindow - const Duration(seconds: 1));
      expect(_card, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(_card, findsNothing);
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(await order(repo), ['Primera', 'Tercera']);
    });
  });

  group('Teclado (CA-014-20)', () {
    testWidgets('CA-014-20: con teclado, el foco va a "Deshacer" y, si la card '
        'desaparece con él, a la fila que ocupa el lugar', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester, 'Segunda');
      expect(tester.widget<UndoCard>(_card).focusNode!.hasFocus, isTrue);
      _undo(tester).commit();
      await tester.pump();
      await tester.pump(frame);
      expect(_card, findsNothing);
      expect(_focusedRow(), 'Tercera');
    });

    testWidgets('CA-014-20: si era la última, a la anterior', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester, 'Tercera');
      _undo(tester).commit();
      await tester.pump();
      await tester.pump(frame);
      expect(_focusedRow(), 'Segunda');
    });

    testWidgets('CA-014-20: con teclado, Escape no hace nada y la card queda '
        'debajo de las filas', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _open(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester, 'Segunda');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(frame);
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(_card, findsOneWidget);
      final card = tester.getRect(_card);
      for (final text in ['Primera', 'Tercera']) {
        expect(tester.getRect(rowOf(text).first).bottom, lessThan(card.top));
      }
    });
  });

  group('Deshacer en el listado (CA-014-09, CA-014-10, CA-014-18)', () {
    testWidgets('CA-014-10: la fila reaparece en su sitio y resaltada, sin '
        '"Tarea añadida"', (tester) async {
      final announcements = listenAnnouncements(tester);
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      final before = (await repo.findById('t1'))!;
      await _delete(tester, 'Segunda');
      await _tapUndo(tester);
      await tester.pump(frame);
      expect(_card, findsNothing);
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(shownOrder(tester), ['Primera', 'Segunda', 'Tercera']);
      expect(_row(tester, 'Segunda').shadow, UnaShadows.listItemFlash);
      final after = (await repo.findById('t1'))!;
      expect(after.rank, before.rank);
      expect(after.colorKey, before.colorKey);
      expect(after.createdAt, before.createdAt);
      expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
      expect(find.text('¿Dónde la pones?'), findsNothing);
      await tester.pump(UnaMotion.listFlash);
      await tester.pump(frame);
      expect(_row(tester, 'Segunda').shadow, UnaShadows.listItem);
      // Un único anuncio, sin "Tarea añadida".
      expect(announcements, ['Tarea recuperada']);
    });

    testWidgets('CA-014-18: con el lector, el foco va a la fila recuperada, '
        'no al título', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = <String>[];
      final events = _listenFocusEvents(tester, announcements: announcements);
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      await _delete(tester, 'Segunda');
      events.clear();
      await _tapUndo(tester);
      await tester.pump(UnaMotion.sheetOut + frame);
      await tester.pump(frame);
      expect(_focusedRow(), 'Segunda');
      final row = tester.getSemantics(find.bySemanticsLabel('2 de 3: Segunda'));
      expect(events, contains(row.id));
      // El nodo de la fila sigue el foco de entrada: TalkBack lo sigue y lleva
      // su foco a la fila (comprobado en el emulador, T-014-08).
      expect(row.getSemanticsData().flagsCollection.isFocused, Tristate.isTrue);
      expect(announcements, ['Tarea recuperada']);
      handle.dispose();
    });

    testWidgets('CA-014-10: la lista se desplaza hasta la fila si no está a '
        'la vista', (tester) async {
      final repo = await _open(
        tester,
        tasks: [for (var i = 1; i <= 30; i++) 'Tarea $i'],
      );
      await _delete(tester, 'Tarea 3');
      // Se va lejos antes de deshacer: la lista baja al final y vuelve arriba.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump(frame);
      await _tapUndo(tester);
      await tester.pumpAndSettle();
      expect(find.text('Tarea 3'), findsOneWidget);
      expect(tester.getRect(find.text('Tarea 3')).top, greaterThanOrEqualTo(0));
      expect(
        tester.getRect(find.text('Tarea 3')).bottom,
        lessThan(tester.view.physicalSize.height),
      );
      expect((await order(repo))[2], 'Tarea 3');
    });

    testWidgets('CA-006-19: con reducir movimiento, el resaltado es fijo y '
        'dura 0,9 s', (tester) async {
      await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        reduced: true,
      );
      await _delete(tester, 'Segunda');
      await _tapUndo(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_row(tester, 'Segunda').shadow, UnaShadows.listItemFlash);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_row(tester, 'Segunda').shadow, UnaShadows.listItem);
    });

    testWidgets('CL-014-3: dos pulsaciones recuperan una sola vez y una '
        'antes de 350 ms no hace nada', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester, 'Segunda');
      await tester.tap(_undoButton);
      await tester.pump(frame);
      expect(_card, findsOneWidget);
      expect(await repo.findById('t1'), isNull);

      final inserts = repo.inserts;
      await _waitCard(tester);
      await tester.tap(_undoButton);
      await tester.tap(_undoButton, warnIfMissed: false);
      await tester.pump(frame);
      await tester.pump(UnaMotion.sheetOut);
      expect(repo.inserts, inserts + 1);
      expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
    });

    testWidgets('CA-014-23: si falla al recuperar, aviso con "Reintentar" '
        'y reintentar recupera la fila', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester, 'Segunda');
      repo.failInsert = true;
      await _tapUndo(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card, findsNothing);
      expect(find.text('No hemos podido recuperar la tarea'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Nueva tarea'), findsOneWidget);
      // Flota por encima de "Nueva tarea".
      expect(
        tester.getRect(find.text('Reintentar')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Nueva tarea')).top),
      );
      expect(find.textContaining('disk I/O'), findsNothing);
      expect(tester.takeException(), isNull);

      repo.failInsert = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
      expect(shownOrder(tester), ['Primera', 'Segunda', 'Tercera']);
    });

    testWidgets('CA-014-23: lo que la hace definitiva cierra el aviso y '
        '"Reintentar" ya no recupera nada', (tester) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester, 'Segunda');
      repo.failInsert = true;
      await _tapUndo(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      repo.failInsert = false;
      expect(await _undo(tester).undo(), isNull);
      expect(await order(repo), ['Primera', 'Tercera']);
      await tester.pumpAndSettle();
    });
  });

  group('La última pendiente (CA-014-02, CA-014-10)', () {
    Future<_Repo> deleteAll(WidgetTester tester, {bool reader = false}) async {
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda'],
        screenReader: reader,
      );
      await _delete(tester, 'Segunda');
      await _waitCard(tester);
      // La primera es la última pendiente.
      await tester.tap(_trash('Primera'));
      await tester.pump();
      await tester.pump(frame);
      return repo;
    }

    testWidgets('CA-014-02, CL-006-3: "Todo hecho." con la card, sin "Crear '
        'una tarea" y sin volver al listado con atrás', (tester) async {
      final repo = await deleteAll(tester);
      await tester.pump(frame);
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(_card, findsOneWidget);
      expect(
        find.descendant(of: _card, matching: find.text('Primera')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Crear una tarea'), findsNothing);
      expect(find.byType(CrumpleOverlay), findsNothing);
      // Ir a "Todo hecho." desde el listado no la hace definitiva.
      expect(_undoState(tester).phase, UndoPhase.visible);
      expect(_undoState(tester).host, UndoHost.home);
      expect(_undoState(tester).returnTo, UndoHost.list);
      expect(await order(repo), isEmpty);
      expect(await tester.binding.handlePopRoute(), isFalse);
    });

    testWidgets('CA-014-16: sin señal de foco de pantalla al ir a "Todo '
        'hecho." (la card se lleva el foco)', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await _open(
        tester,
        tasks: ['Primera', 'Segunda'],
        screenReader: true,
      );
      await _delete(tester, 'Segunda');
      await _waitCard(tester);
      final signal = _container(tester).read(screenFocusProvider);
      await tester.tap(_trash('Primera'));
      await tester.pump();
      await tester.pump(frame);
      await tester.pump(frame);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(_container(tester).read(screenFocusProvider), signal);
      expect(tester.widget<UndoCard>(_card).focusNode!.hasFocus, isTrue);
      expect(await order(repo), isEmpty);
      handle.dispose();
    });

    testWidgets('CA-014-10: deshacer desde "Todo hecho." abre otra vez el '
        'listado con la fila resaltada, a la vista y con el foco, y un '
        'anuncio', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = <String>[];
      _listenFocusEvents(tester, announcements: announcements);
      final repo = await deleteAll(tester, reader: true);
      await tester.pump(frame);
      expect(find.byType(AllDoneScreen), findsOneWidget);

      await _tapUndo(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(frame);
      }
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(find.byType(AllDoneScreen), findsNothing);
      expect(_card, findsNothing);
      expect(find.text('Nueva tarea'), findsOneWidget);
      // Resalte inmediato; foco y anuncio, cuando ya se ve (el lector tarda en
      // soltar el foco de la ruta nueva: 600 ms, medido en el emulador).
      expect(_row(tester, 'Primera').shadow, UnaShadows.listItemFlash);
      expect(_focusedRow(), isNull);
      await tester.pump(const Duration(milliseconds: 600) + frame);
      await tester.pump(frame);
      expect(_focusedRow(), 'Primera');
      expect(announcements, ['Tarea recuperada']);
      expect(shownOrder(tester), ['Primera']);
      expect(await order(repo), ['Primera']);
      expect(_undoState(tester).phase, UndoPhase.none);

      // Volver a la tarea: la recuperada, y la señal de foco funciona.
      await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Primera'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CA-014-11: desde "Todo hecho." con la card, ir a otra '
        'pantalla la hace definitiva', (tester) async {
      final repo = await deleteAll(tester);
      await tester.pump(frame);
      _undo(tester).commit();
      await tester.pump();
      expect(_card, findsNothing);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(await _undo(tester).undo(), isNull);
      expect(await order(repo), isEmpty);
    });

    testWidgets('CA-014-11: si la app pasa a segundo plano mientras se guarda '
        'la última, "Todo hecho." sin card', (tester) async {
      final repo = await _open(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester, 'Segunda');
      await _waitCard(tester);
      repo.gate = Completer<void>();
      await tester.tap(_trash('Primera'));
      await tester.pump();
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      repo.gate!.complete();
      await tester.pump();
      await tester.pump(frame);
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(frame);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(_card, findsNothing);
      expect(_undoState(tester).phase, UndoPhase.none);
      expect(await order(repo), isEmpty);
    });
  });
}
