// Goldens de la spec 006. Se generan y comparan solo en Linux (CI).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/task_list/list_harness.dart';
import '../support/fonts.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

const _tasks = [
  'Llamar a Marta',
  'Comprar pan',
  'Enviar el presupuesto de la reforma de la cocina antes del viernes, '
      'con las tres opciones de encimera y el plazo de entrega de cada una',
  'Pedir cita al dentista',
  'Regar las plantas',
];

void main() {
  setUpAll(loadAppFonts);

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-006-02: Todas las tareas (texto ×$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openList(tester, tasks: _tasks, repo: InMemoryTaskRepository());
      await _golden(tester, 'task_list_es_x$scale');
    }, skip: _skip);
  }

  testWidgets('CA-006-04: fila levantada a mitad de arrastre', (tester) async {
    await openList(tester, tasks: _tasks);
    final g = await tester.startGesture(
      tester.getCenter(handleOf('Pedir cita al dentista')),
    );
    await g.moveBy(const Offset(0, -110));
    await tester.pump();
    await tester.pump(UnaMotion.listShift);
    await _golden(tester, 'task_list_dragging_es');
    await g.up();
    await tester.pumpAndSettle();
  }, skip: _skip);

  testWidgets('CA-006-08: hoja "Mover"', (tester) async {
    await openList(tester, tasks: _tasks);
    await tester.tap(handleOf('Pedir cita al dentista'));
    await tester.pumpAndSettle();
    await _golden(tester, 'task_list_move_es');
  }, skip: _skip);

  testWidgets('CA-006-15: fila resaltada al crearla', (tester) async {
    await openList(tester, tasks: _tasks.take(3).toList());
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sacar la basura');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A la cola'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await _golden(tester, 'task_list_flash_es');
    await tester.pumpAndSettle();
  }, skip: _skip);
}
