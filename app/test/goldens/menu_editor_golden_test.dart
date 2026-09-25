// Goldens de las specs 002 y 005. Se generan y comparan solo en Linux (CI).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-005-01: menú de la tarea', (tester) async {
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Llamar a Marta', 'Comprar pan'],
    );
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await _golden(tester, 'menu_es');
  }, skip: _skip);

  testWidgets('CA-002-01: editor de una tarea nueva', (tester) async {
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Llamar a Marta'],
    );
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    await _golden(tester, 'editor_new_es');
  }, skip: _skip);

  testWidgets('CA-002-02: ¿Dónde la pones?', (tester) async {
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Llamar a Marta'],
    );
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Comprar pan y leche');
    await tester.tap(
      find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
    );
    await tester.pumpAndSettle();
    await _golden(tester, 'placement_es');
  }, skip: _skip);

  testWidgets('CA-005-04: editar una tarea', (tester) async {
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Llamar a Marta para confirmar la cena'],
    );
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
    await _golden(tester, 'editor_edit_es');
  }, skip: _skip);
}
