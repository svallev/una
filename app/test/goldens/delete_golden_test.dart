// Goldens de las specs 004 y 014. Se generan y comparan solo en Linux (CI).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart' show sampleTask;

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

/// La card de deshacer sola, abajo, sobre el papel (spec 014), con la barra
/// al 60 % y ya entrada.
Future<void> _pumpUndoCard(
  WidgetTester tester, {
  required double scale,
  required double height,
  bool focused = false,
}) async {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final node = FocusNode();
  addTearDown(node.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: UnaTheme.light(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Material(
        color: UnaColors.paper,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: UndoCard(
                task: sampleTask(
                  text:
                      'Llamar a Marta para confirmar la cita del dentista '
                      'del jueves por la tarde',
                  colorKey: 0,
                ),
                serial: 1,
                fraction: () => 0.6,
                onUndo: () {},
                onShown: (_, {required screenReader}) {},
                onFocusChanged: (_, _, {required focused}) {},
                focusNode: node,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump(UnaMotion.undoEnter);
  if (focused) {
    // Como con un teclado físico: Tab hasta "Deshacer".
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(node.hasFocus, isTrue);
  }
}

void main() {
  setUpAll(loadAppFonts);

  // Tablero 12: la card sola. A ×2,0 en 360 dp, "Deshacer" pasa debajo
  // (CL-014-6: dos filas).
  for (final (scale, height) in [(1.0, 240.0), (2.0, 400.0)]) {
    for (final focused in [false, true]) {
      final name = 'undo_card${focused ? '_focus' : ''}_es_x$scale';
      testWidgets('CA-014-03${focused ? ', CA-014-20' : ''}${scale == 2 ? ', '
                    'CL-014-6' : ''}: card de deshacer (texto ×$scale'
          '${focused ? ', con foco de teclado' : ''})', (tester) async {
        await _pumpUndoCard(
          tester,
          scale: scale,
          height: height,
          focused: focused,
        );
        await _golden(tester, name);
      }, skip: _skip);
    }
  }

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
