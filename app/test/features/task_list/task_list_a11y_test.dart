import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'list_harness.dart';

/// Etiquetas de todos los nodos, en el orden en que los recorre el lector.
List<String> _readingOrder(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    final label = node.label;
    if (label.isNotEmpty) out.add(label);
    for (final c in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(c);
    }
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// Texto de la fila que tiene el foco de teclado (su asa o su "Editar").
String? _focusedRow() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx?.findAncestorWidgetOfExactType<TaskListRow>()?.task.text;
}

/// El foco se pide cuando la hoja o el editor ya se han cerrado.
Future<void> _settleFocus(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

Future<void> _action(WidgetTester tester, String row, String action) async {
  final node = tester.getSemantics(find.bySemanticsLabel(row));
  final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)!.label == action,
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

void main() {
  testWidgets(
    'CA-006-18: orden de lectura, una parada por fila y el título primero',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      final order = _readingOrder(tester);
      final start = order.indexOf('Todas las tareas');
      expect(order.sublist(start), [
        'Todas las tareas', // nombre de la pantalla
        'Todas las tareas', // título (encabezado)
        'La primera es la que tienes ahora. Usa las acciones de cada tarea '
            'para cambiar el orden, editarla o eliminarla.',
        '1 de 3. Tarea actual: Primera',
        '2 de 3: Segunda',
        '3 de 3: Tercera',
        'Nueva tarea',
        'Volver a la tarea',
      ]);
      // Los botones de la fila no se leen por separado.
      expect(find.bySemanticsLabel('Editar tarea'), findsNothing);
      expect(find.bySemanticsLabel('Mover tarea'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Todas las tareas').last),
        matchesSemantics(label: 'Todas las tareas', isHeader: true),
      );
      handle.dispose();
    },
  );

  testWidgets('CA-006-18: activar una fila edita, con la pista "editar"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openList(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
    final node = tester.getSemantics(find.bySemanticsLabel('2 de 2: Segunda'));
    final data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    final hints = [
      for (final id in data.customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!,
    ].where((a) => a.action == SemanticsAction.tap).map((a) => a.hint);
    expect(hints, ['editar']);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'CA-006-17: mover anuncia la posición y el foco sigue a la tarea',
    (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = listenAnnouncements(tester);
      await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      await _action(tester, '2 de 3: Segunda', 'Mover abajo');
      await tester.pumpAndSettle();
      expect(announcements, ['Movida a la posición 3 de 3']);
      expect(_focusedRow(), 'Segunda');

      await _action(tester, '3 de 3: Segunda', 'Hacer actual');
      await tester.pumpAndSettle();
      expect(announcements.last, 'Ahora es la tarea actual');
      expect(_focusedRow(), 'Segunda');
      expect(announcements, hasLength(2));
      handle.dispose();
    },
  );

  testWidgets(
    'CA-006-17: "Hacer actual" desde la fila 40 lleva la lista arriba con el foco',
    (tester) async {
      final handle = tester.ensureSemantics();
      final tasks = [for (var i = 1; i <= 40; i++) 'Tarea $i'];
      await openList(tester, tasks: tasks, screenReader: true);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await _action(tester, '40 de 40: Tarea 40', 'Hacer actual');
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(_focusedRow(), 'Tarea 40');
      handle.dispose();
    },
  );

  testWidgets(
    'CA-006-17: eliminar deja el foco en la fila que ocupa su lugar; cancelar, en la misma',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      await _action(tester, '2 de 3: Segunda', 'Eliminar tarea');
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tap(find.text('Cancelar'));
      await _settleFocus(tester);
      expect(_focusedRow(), 'Segunda');

      await _action(tester, '2 de 3: Segunda', 'Eliminar tarea');
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tap(find.text('Eliminar').last);
      await _settleFocus(tester);
      expect(_focusedRow(), 'Tercera');

      await _action(tester, '2 de 2: Tercera', 'Eliminar tarea');
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tap(find.text('Eliminar').last);
      await _settleFocus(tester);
      expect(_focusedRow(), 'Primera', reason: 'era la última: la anterior');
      handle.dispose();
    },
  );

  testWidgets('CA-006-17: tras editar, el foco vuelve a la fila', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openList(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
    await _action(tester, '2 de 2: Segunda', 'Editar tarea');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await _settleFocus(tester);
    expect(_focusedRow(), 'Segunda');
    handle.dispose();
  });

  testWidgets('CA-006-17: tras crear, el foco en la fila nueva', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openList(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nueva');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A la cola'));
    await _settleFocus(tester);
    expect(_focusedRow(), 'Nueva');
    handle.dispose();
  });

  testWidgets('CA-006-03: al volver, el foco en la tarea actual', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openList(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
    await _action(tester, '2 de 2: Segunda', 'Hacer actual');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      focused.findAncestorWidgetOfExactType<CurrentTaskScreen>()?.task.text,
      'Segunda',
    );
    handle.dispose();
  });

  testWidgets(
    'Guías de accesibilidad: tamaño y etiqueta de los objetivos, y contraste',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openList(
        tester,
        tasks: ['Amarilla', 'Rosa', 'Azul', 'Verde', 'Naranja'],
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  testWidgets('CA-006-16: una fila de cada botón mide al menos 48 dp', (
    tester,
  ) async {
    await openList(tester, tasks: ['Primera', 'Segunda']);
    final row = tester.getSize(rowOf('Segunda').first);
    expect(row.height, greaterThanOrEqualTo(48 + 2 * UnaSpace.xs));
  });

  testWidgets(
    'CA-006-17: la fila movida conserva su nodo de accesibilidad (TalkBack no pierde el foco)',
    (tester) async {
      final handle = tester.ensureSemantics();
      final tasks = [for (var i = 1; i <= 40; i++) 'Tarea $i'];
      await openList(tester, tasks: tasks, screenReader: true);
      int idOf(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label)).id;

      final before = idOf('3 de 40: Tarea 3');
      await _action(tester, '3 de 40: Tarea 3', 'Mover abajo');
      await tester.pumpAndSettle();
      expect(idOf('4 de 40: Tarea 3'), before);

      await _action(tester, '4 de 40: Tarea 3', 'Hacer actual');
      await tester.pumpAndSettle();
      expect(idOf('1 de 40. Tarea actual: Tarea 3'), before);

      // Desde el final de una lista larga.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = idOf('40 de 40: Tarea 40');
      await _action(tester, '40 de 40: Tarea 40', 'Hacer actual');
      await tester.pumpAndSettle();
      expect(idOf('1 de 40. Tarea actual: Tarea 40'), last);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-006-17 (teclado): tras mover con "Mover", el foco queda en el asa de la fila, visible',
    (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      // Con teclado: el anillo se ve en modo tradicional.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.tap(handleOf('Segunda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover abajo'));
      await _settleFocus(tester);
      expect(_focusedRow(), 'Segunda');
      final focused = FocusManager.instance.primaryFocus!.context!;
      // Es un control de la fila (el asa), no un nodo invisible.
      expect(
        focused.findAncestorWidgetOfExactType<FocusableActionDetector>(),
        isNotNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('MOVER TAREA'), findsOneWidget);
    },
  );

  testWidgets('CA-006-17: el aviso de foco sale del nodo de la fila', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final focusEvents = <int>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'focus') focusEvents.add(map['nodeId']! as int);
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
    await openList(
      tester,
      tasks: ['Primera', 'Segunda', 'Tercera'],
      screenReader: true,
    );
    await _action(tester, '2 de 3: Segunda', 'Mover abajo');
    await _settleFocus(tester);
    final row = tester.getSemantics(find.bySemanticsLabel('3 de 3: Segunda'));
    expect(focusEvents, contains(row.id));
    handle.dispose();
  });

  testWidgets(
    'CL-006-5: con el lector, la confirmación responde desde el principio',
    (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda'],
        screenReader: true,
      );
      await _action(tester, '2 de 2: Segunda', 'Eliminar tarea');
      await tester.pumpAndSettle(); // sin esperar la ventana del doble toque
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(await order(repo), ['Primera']);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-006-18 / CL-006-10: con texto al 200 %, título, ayuda y filas en orden',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final handle = tester.ensureSemantics();
      await openList(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
      final order = _readingOrder(tester);
      final start = order.indexOf('Todas las tareas');
      final rest = order.sublist(start + 1);
      expect(rest.indexOf('Todas las tareas'), 0, reason: 'título primero');
      expect(
        rest.indexOf('1 de 2. Tarea actual: Primera'),
        lessThan(rest.indexOf('Volver a la tarea')),
      );
      expect(
        rest.indexOf('2 de 2: Segunda'),
        lessThan(rest.indexOf('Volver a la tarea')),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'Guías de accesibilidad con texto al 200 % y con las hojas abiertas',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final handle = tester.ensureSemantics();
      await openList(tester, tasks: ['Amarilla', 'Rosa', 'Azul']);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.tap(handleOf('Rosa'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
