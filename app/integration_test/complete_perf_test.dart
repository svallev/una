// Fluidez de completar (spec 003, T-003-09): resumen de fotogramas de la
// rotura y la enhorabuena. Se ejecuta en el dispositivo en modo profile:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/complete_perf_test.dart -d <serial>
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/completion_controller.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> _wipeDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // Solo en las apps de pruebas (`.debug`, `.profile`).
  if (!dir.path.contains('.debug') && !dir.path.contains('.profile')) {
    throw StateError('Pruebas fuera de la app de pruebas: ${dir.path}');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dir.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fotogramas reales al ritmo de la pantalla (no solo los que pide el test).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('rendimiento: rotura y enhorabuena al completar', (tester) async {
    await _wipeDatabase();
    await bootstrap();
    await tester.pumpAndSettle();
    // La tarea se crea directamente: solo se mide completar.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    await container
        .read(createTaskProvider)
        .call('Llamar a Marta para confirmar la cena');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byType(HoldToCompleteButton), findsOneWidget);

    final task = await container.read(taskRepositoryProvider).currentTask();

    // Se completa como lo haría la acción accesible (sin simular el dedo) y se
    // miden los fotogramas de la rotura y la enhorabuena.
    await binding.watchPerformance(() async {
      await container.read(completionProvider.notifier).complete(task!);
      await tester.pumpAndSettle();
    }, reportKey: 'complete_frames');

    expect(find.byType(AllDoneScreen), findsOneWidget);
  });
}
