// Goldens de la spec 001 (T-001-05, T-001-14). El texto se dibuja distinto en
// macOS y en Linux, así que se generan y se comparan solo en Linux (CI):
// ver docs/testing.md, "Goldens".
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

/// `GOLDENS_ANY_OS=1` permite generarlos en local para revisarlos (no se suben).
final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

void main() {
  setUpAll(loadAppFonts);

  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets(
        'CA-001-06/07: tarea actual (${locale.languageCode}, texto ×$scale)',
        (tester) async {
          await pumpWithApp(
            tester,
            CurrentTaskScreen(
              task: sampleTask(
                text: locale.languageCode == 'es'
                    ? 'Llamar a Marta para confirmar la cena'
                    : 'Call Marta to confirm dinner',
              ),
            ),
            locale: locale,
            textScale: scale,
          );
          await expectLater(
            find.byType(CurrentTaskScreen),
            matchesGoldenFile(
              'goldens/current_task_${locale.languageCode}_x$scale.png',
            ),
          );
        },
        skip: _skip,
      );
    }
  }

  testWidgets('CA-001-07: nota larga (tamaño S)', (tester) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(
        task: sampleTask(
          colorKey: 3,
          text:
              'Revisar el contrato del alquiler, llamar al casero para '
              'preguntar por la fianza y enviar los justificantes de pago de '
              'los últimos tres meses antes del viernes.',
        ),
      ),
    );
    await expectLater(
      find.byType(CurrentTaskScreen),
      matchesGoldenFile('goldens/current_task_long_es.png'),
    );
  }, skip: _skip);

  testWidgets('CA-001-01: bienvenida (texto completo)', (tester) async {
    await pumpWithApp(
      tester,
      WelcomeIntro(onDone: () {}),
      disableAnimations: true,
    );
    await expectLater(
      find.byType(WelcomeIntro),
      matchesGoldenFile('goldens/welcome_es.png'),
    );
    await tester.pump(const Duration(seconds: 2));
  }, skip: _skip);

  testWidgets('CA-001-02: editor de la primera tarea (vacío)', (tester) async {
    await pumpWithApp(tester, const FirstTaskEditorScreen());
    await expectLater(
      find.byType(FirstTaskEditorScreen),
      matchesGoldenFile('goldens/editor_empty_es.png'),
    );
  }, skip: _skip);

  testWidgets('CL-001-6: error de almacenamiento', (tester) async {
    await pumpWithApp(
      tester,
      StorageErrorScreen(noSpace: false, onRetry: () {}),
    );
    await expectLater(
      find.byType(StorageErrorScreen),
      matchesGoldenFile('goldens/storage_error_es.png'),
    );
  }, skip: _skip);

  testWidgets('BrutalButton: normal, deshabilitado y con foco', (tester) async {
    await pumpWithApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              BrutalButton(label: 'Guardar', onPressed: () {}),
              const SizedBox(height: 24),
              const BrutalButton(label: 'Guardar', onPressed: null),
              const SizedBox(height: 24),
              BrutalButton(
                label: 'Pulsa para completar',
                icon: Icons.check,
                singleLine: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
      size: const Size(390, 330),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/brutal_button.png'),
    );
  }, skip: _skip);
}
