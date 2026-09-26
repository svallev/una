import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import 'list_harness.dart';

void main() {
  testWidgets(
    'CA-006-01: se abre desde el menú en dos pasos y sin transición',
    (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      // Ningún atajo en la pantalla principal.
      expect(find.byType(TaskListScreen), findsNothing);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pump(); // lee la cola
      await tester.pump(); // sin transición: ya está
      expect(find.text('Todas las tareas'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-006-02: cabecera, ayuda, filas en orden, primera distinta y "Nueva tarea"',
    (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      expect(find.text('Todas las tareas'), findsOneWidget);
      expect(
        find.text(
          'La primera es la que tienes ahora. Arrastra otra por encima para '
          'que ocupe su lugar. Toca dos veces una tarea para editarla.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Volver a la tarea'), findsOneWidget);
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(shownOrder(tester), ['Primera', 'Segunda', 'Tercera']);
      // "Lo siguiente" no se muestra (oculto en el prototipo).
      expect(find.text('Lo siguiente'), findsNothing);
      final rows = tester
          .widgetList<TaskListRow>(find.byType(TaskListRow))
          .toList();
      expect(rows.first.first, isTrue);
      expect(rows.skip(1).every((r) => !r.first), isTrue);
      // La primera: texto de 20 y sin asa; las demás: 16 y con asa.
      expect(
        tester.widget<Text>(find.text('Primera')).style!.fontSize,
        UnaFontSizes.listFirst,
      );
      expect(
        tester.widget<Text>(find.text('Segunda')).style!.fontSize,
        UnaFontSizes.listItem,
      );
      expect(handleOf('Primera'), findsNothing);
      expect(handleOf('Segunda'), findsOneWidget);
    },
  );

  testWidgets('CL-006-11: los textos largos se recortan a 3 líneas', (
    tester,
  ) async {
    final long = List.filled(400, 'palabra').join(' ');
    await openList(tester, tasks: ['Primera', long]);
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(rowOf(long)).height, lessThan(120));
  });

  testWidgets(
    'CA-006-03: "Volver a la tarea" y el gesto atrás vuelven a la tarea actual',
    (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(find.bySemanticsLabel('Volver a la tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.text('Primera'), findsOneWidget);
    },
  );

  testWidgets(
    'CL-006-10: con texto al 200 % nada se desborda y la cabecera se desplaza',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1.0;
      await openList(
        tester,
        tasks: [
          'Primera',
          'Segunda tarea con un texto algo más largo',
          'Tercera',
        ],
      );
      expect(tester.takeException(), isNull);
      // La cabecera está dentro de la lista desplazable.
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text('Todas las tareas'),
        ),
        findsOneWidget,
      );
      for (final label in ['Volver a la tarea']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets(
    'CL-006-9: tras < 10 min en segundo plano sigue el listado; tras 10 min, la tarea actual',
    (tester) async {
      final clock = FakeClock();
      await openList(tester, tasks: ['Primera', 'Segunda'], clock: clock);
      background(tester, clock, const Duration(minutes: 9));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      background(tester, clock, UnaApp.resetAfter);
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
    },
  );
}
