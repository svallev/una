import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'list_harness.dart';

TaskListRow? _lifted(WidgetTester tester) => tester
    .widgetList<TaskListRow>(find.byType(TaskListRow))
    .where((r) => r.lifted)
    .firstOrNull;

void main() {
  testWidgets(
    'CA-006-04 / CA-006-06: desde el asa se levanta a los 6 px y al soltar arriba del todo pasa a ser la actual',
    (tester) async {
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      final g = await tester.startGesture(tester.getCenter(handleOf('Tercera')));
      await g.moveBy(const Offset(0, -4));
      await tester.pump();
      expect(_lifted(tester), isNull, reason: 'por debajo del umbral');
      await g.moveBy(const Offset(0, -4));
      await tester.pump();
      final lifted = _lifted(tester);
      expect(lifted, isNotNull);
      expect(lifted!.task.text, 'Tercera');
      await tester.pump(UnaMotion.listLift);
      expect(_lifted(tester)!.shadow, UnaShadows.listItemDragging);
      // Inclinada −1,5°.
      expect(
        find.descendant(
          of: find.byWidget(_lifted(tester)!),
          matching: find.byWidgetPredicate(
            (w) => w is Transform && w.transform.getRotation()[1] != 0,
          ),
        ),
        findsOneWidget,
      );
      // Por encima de la primera.
      final firstTop = tester.getTopLeft(rowOf('Primera').first).dy;
      final thirdTop = tester.getTopLeft(rowOf('Tercera').first).dy;
      await g.moveBy(Offset(0, firstTop - thirdTop - 20));
      await tester.pump(UnaMotion.listShift);
      // Las demás se apartan.
      expect(shownOrder(tester), ['Primera', 'Segunda']);
      await g.up();
      await tester.pumpAndSettle();
      expect(await order(repo), ['Tercera', 'Primera', 'Segunda']);
      expect(shownOrder(tester), ['Tercera', 'Primera', 'Segunda']);
      expect(handleOf('Tercera'), findsNothing, reason: 'ahora es la primera');
      expect(handleOf('Primera'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Tercera'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-006-05: con pulsación larga se arrastra desde el resto de la fila',
    (tester) async {
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      final g = await tester.startGesture(tester.getCenter(find.text('Tercera')));
      await tester.pump(kLongPressTimeout + frame);
      expect(_lifted(tester), isNotNull);
      final secondTop = tester.getTopLeft(rowOf('Segunda').first).dy;
      final thirdTop = tester.getTopLeft(rowOf('Tercera').first).dy;
      await g.moveBy(Offset(0, secondTop - thirdTop - 10));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(await order(repo), ['Primera', 'Tercera', 'Segunda']);
    },
  );

  testWidgets(
    'CA-006-05: deslizar sin mantener pulsado desplaza la lista y no arrastra',
    (tester) async {
      final tasks = [for (var i = 1; i <= 30; i++) 'Tarea $i'];
      final repo = await openList(tester, tasks: tasks);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.drag(find.text('Tarea 3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(100));
      expect(await order(repo), tasks);
    },
  );

  testWidgets('CA-006-07: la primera fila no se arrastra', (tester) async {
    final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
    final g = await tester.startGesture(tester.getCenter(find.text('Primera')));
    await tester.pump(kLongPressTimeout + frame);
    await g.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(_lifted(tester), isNull);
    await g.up();
    await tester.pumpAndSettle();
    expect(await order(repo), ['Primera', 'Segunda']);
  });

  testWidgets(
    'CA-006-11: si el sistema cancela el arrastre, vuelve a su sitio y no se guarda',
    (tester) async {
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      final g = await tester.startGesture(tester.getCenter(handleOf('Tercera')));
      await g.moveBy(const Offset(0, -150));
      await tester.pump();
      expect(_lifted(tester), isNotNull);
      await g.cancel();
      await tester.pumpAndSettle();
      expect(_lifted(tester), isNull);
      expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
      expect(shownOrder(tester), ['Primera', 'Segunda', 'Tercera']);
    },
  );

  testWidgets('CA-006-11: pasar a segundo plano cancela el arrastre', (
    tester,
  ) async {
    final repo = await openList(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
    final g = await tester.startGesture(tester.getCenter(handleOf('Tercera')));
    await g.moveBy(const Offset(0, -150));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(_lifted(tester), isNull);
    await g.up();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(await order(repo), ['Primera', 'Segunda', 'Tercera']);
  });

  testWidgets(
    'CA-006-12: cerca del borde la lista se desplaza sola y se puede soltar lejos',
    (tester) async {
      final tasks = [for (var i = 1; i <= 40; i++) 'Tarea $i'];
      final repo = await openList(tester, tasks: tasks);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final g = await tester.startGesture(
        tester.getCenter(handleOf('Tarea 2')),
      );
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
      // Al borde inferior de la zona de la lista.
      final listBottom = tester.getBottomLeft(find.byType(CustomScrollView)).dy;
      await g.moveTo(Offset(tester.getCenter(handleOf('Tarea 2')).dx, listBottom - 5));
      for (var i = 0; i < 60; i++) {
        await tester.pump(frame);
      }
      expect(scrollable.position.pixels, greaterThan(200));
      await g.up();
      await tester.pumpAndSettle();
      final after = await order(repo);
      expect(after.indexOf('Tarea 2'), greaterThan(10));
      expect(after.toSet(), tasks.toSet());
    },
  );

  testWidgets('CL-006-4: soltar en la misma posición no escribe nada', (
    tester,
  ) async {
    final repo = await openList(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
    final before = await repo.pendingTasks();
    final g = await tester.startGesture(tester.getCenter(handleOf('Segunda')));
    await g.moveBy(const Offset(0, 12));
    await tester.pump();
    await g.moveBy(const Offset(0, -12));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(await repo.pendingTasks(), before);
  });

  testWidgets(
    'CA-006-19: con reducir movimiento la fila levantada no se inclina',
    (tester) async {
      await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        reduced: true,
      );
      final g = await tester.startGesture(tester.getCenter(handleOf('Tercera')));
      await g.moveBy(const Offset(0, -40));
      await tester.pump();
      final lifted = _lifted(tester)!;
      expect(lifted.shadow, UnaShadows.listItemDragging);
      expect(
        find.descendant(
          of: find.byWidget(lifted),
          matching: find.byWidgetPredicate(
            (w) => w is Transform && w.transform.getRotation()[1] != 0,
          ),
        ),
        findsNothing,
      );
      await g.up();
      await tester.pumpAndSettle();
    },
  );
}
