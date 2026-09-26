import 'package:app/features/task_list/move_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'list_harness.dart';

/// Nombres de las acciones del lector de la fila con [label].
List<String> _actionsOf(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  final data = node.getSemanticsData();
  // Sin la pista de activación ("editar"), que es una acción sin nombre.
  return [
    for (final id in data.customSemanticsActionIds ?? <int>[])
      if (CustomSemanticsAction.getAction(id)!.label case final String label)
        label,
  ];
}

void main() {
  test('CA-006-09: opciones de mover según la posición', () {
    expect(moveChoicesFor(1, 4), isEmpty);
    expect(moveChoicesFor(2, 4), [MoveChoice.makeCurrent, MoveChoice.down]);
    expect(moveChoicesFor(3, 4), [
      MoveChoice.makeCurrent,
      MoveChoice.up,
      MoveChoice.down,
    ]);
    expect(moveChoicesFor(4, 4), [MoveChoice.makeCurrent, MoveChoice.up]);
    expect(moveChoicesFor(2, 2), [MoveChoice.makeCurrent]);
    expect(moveTargetIndex(MoveChoice.makeCurrent, 3), 0);
    expect(moveTargetIndex(MoveChoice.up, 3), 1);
    expect(moveTargetIndex(MoveChoice.down, 3), 3);
  });

  testWidgets(
    'CA-006-08: tocar el asa abre "Mover" y elegir mueve la tarea',
    (tester) async {
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
      );
      await tester.tap(handleOf('Tercera'));
      await tester.pumpAndSettle();
      expect(find.byType(MoveSheet), findsOneWidget);
      expect(find.text('MOVER TAREA'), findsOneWidget);
      for (final t in ['Hacer actual', 'Mover arriba', 'Mover abajo']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.text('Mover abajo'));
      await tester.pumpAndSettle();
      expect(find.byType(MoveSheet), findsNothing);
      expect(await order(repo), ['Primera', 'Segunda', 'Cuarta', 'Tercera']);

      await tester.tap(handleOf('Tercera'));
      await tester.pumpAndSettle();
      expect(find.text('Mover abajo'), findsNothing, reason: 'es la última');
      await tester.tap(find.text('Hacer actual'));
      await tester.pumpAndSettle();
      expect(await order(repo), ['Tercera', 'Primera', 'Segunda', 'Cuarta']);
    },
  );

  testWidgets('CA-006-08: cerrar "Mover" sin elegir no cambia nada', (
    tester,
  ) async {
    final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
    await tester.tap(handleOf('Segunda'));
    await tester.pumpAndSettle();
    expect(find.text('Mover arriba'), findsNothing, reason: 'en la 2.ª');
    await tester.tap(find.bySemanticsLabel('Cerrar menú').last);
    await tester.pumpAndSettle();
    expect(find.byType(MoveSheet), findsNothing);
    expect(await order(repo), ['Primera', 'Segunda']);
  });

  testWidgets('CA-006-08: con el teclado, Tab llega al asa e Intro abre "Mover"', (
    tester,
  ) async {
    await openList(tester, tasks: ['Primera', 'Segunda']);
    // Volver → Editar y Eliminar de la 1.ª → asa de la 2.ª.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(MoveSheet), findsOneWidget);
  });

  testWidgets(
    'CA-006-16: acciones del lector por fila, en orden y sin duplicados',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      expect(_actionsOf(tester, '1 de 3. Tarea actual: Primera'), [
        'Editar tarea',
        'Eliminar tarea',
      ]);
      expect(_actionsOf(tester, '2 de 3: Segunda'), [
        'Hacer actual',
        'Mover abajo',
        'Editar tarea',
        'Eliminar tarea',
      ]);
      expect(_actionsOf(tester, '3 de 3: Tercera'), [
        'Hacer actual',
        'Mover arriba',
        'Editar tarea',
        'Eliminar tarea',
      ]);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-006-16: "Hacer actual" desde el lector mueve al instante',
    (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
        screenReader: true,
      );
      final node = tester.getSemantics(find.bySemanticsLabel('3 de 3: Tercera'));
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Hacer actual',
      );
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        id,
      );
      await tester.pumpAndSettle();
      expect(await order(repo), ['Tercera', 'Primera', 'Segunda']);
      expect(find.bySemanticsLabel('1 de 3. Tarea actual: Tercera'), findsOneWidget);
      handle.dispose();
    },
  );
}
