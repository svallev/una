// Fluidez del arrugado (spec 004, T-004-11): resumen de fotogramas. Se
// ejecuta en el dispositivo en modo profile (en el móvil del propietario,
// siempre con --keep-app-running):
//   flutter drive --profile --keep-app-running \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/delete_perf_test.dart -d <serial>
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/deletion_controller.dart';
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

  testWidgets('rendimiento: arrugar y tirar a la papelera', (tester) async {
    await _wipeDatabase();
    await bootstrap();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    final create = container.read(createTaskProvider);
    await create.call('Comprar pan');
    await create.call('Llamar a Marta para confirmar la cena');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final task = await container.read(taskRepositoryProvider).currentTask();

    // Se elimina como tras confirmar (sin simular los toques) y se miden los
    // fotogramas del arrugado.
    await binding.watchPerformance(() async {
      await container.read(deletionProvider.notifier).delete(task!);
      await tester.pumpAndSettle();
    }, reportKey: 'delete_frames');

    expect(find.byType(CurrentTaskScreen), findsOneWidget);
  });
}
