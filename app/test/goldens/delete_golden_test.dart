// Goldens de la spec 004. Se generan y comparan solo en Linux (CI).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
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

Future<void> _openConfirm(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-004-01: ¿Eliminar esta tarea? (texto ×$scale)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Llamar a Marta', 'Comprar pan'],
      );
      await _openConfirm(tester);
      await _golden(tester, 'delete_confirm_es_x$scale');
    }, skip: _skip);
  }

  // Puntos de control del arrugado frente al prototipo (`@keyframes crumple`).
  for (final at in [0.14, 0.43, 0.70]) {
    testWidgets('CA-004-04: arrugado al ${(at * 100).round()} %', (
      tester,
    ) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Llamar a Marta', 'Comprar pan'],
      );
      await _openConfirm(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is BrutalButton && w.label == 'Eliminar',
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(UnaMotion.crumple * at);
      await _golden(tester, 'crumple_${(at * 100).round()}_es');
      await tester.pump(UnaMotion.crumple);
      await tester.pumpAndSettle();
    }, skip: _skip);
  }

  testWidgets('CA-004-07: arrugado de la última, con "Todo hecho." detrás', (
    tester,
  ) async {
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Llamar a Marta'],
    );
    await _openConfirm(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is BrutalButton && w.label == 'Eliminar'),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(UnaMotion.crumple * 0.43);
    await _golden(tester, 'crumple_last_es');
    await tester.pump(UnaMotion.crumple);
    await tester.pumpAndSettle();
  }, skip: _skip);
}
