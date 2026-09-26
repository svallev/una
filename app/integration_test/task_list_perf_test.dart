// Rendimiento del listado con 500 tareas (spec 006, CA-006-20). Se ejecuta
// en el dispositivo en modo profile (en el móvil del propietario, siempre con
// --keep-app-running):
//   flutter drive --profile --keep-app-running \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/task_list_perf_test.dart -d <serial>
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
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

  testWidgets('rendimiento: listado con 500 tareas', (tester) async {
    final semantics = tester.ensureSemantics();
    await _wipeDatabase();
    await bootstrap();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    final repo = container.read(taskRepositoryProvider);
    await container.read(settingsRepositoryProvider).setFirstRunDone();
    final ranks = Rank.evenlySpaced(500);
    final now = DateTime.now();
    for (var i = 0; i < 500; i++) {
      await repo.insert(
        Task(
          id: 'perf-$i',
          text: i % 7 == 0
              ? 'Tarea $i: ${List.filled(30, 'texto largo').join(' ')}'
              : 'Tarea $i',
          status: TaskStatus.pending,
          rank: ranks[i],
          colorKey: i % 5,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Abrir: desde que se elige "Todas mis tareas" hasta ver las filas.
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeRouter)));
    await tester.tap(find.bySemanticsLabel(l10n.menuButton));
    await tester.pumpAndSettle();
    final watch = Stopwatch()..start();
    await tester.tap(find.text(l10n.menuAllTasks));
    while (find.byType(TaskListRow).evaluate().isEmpty) {
      await tester.pump();
    }
    watch.stop();
    binding.reportData = {
      'open_list': {'open_list_ms': watch.elapsedMilliseconds},
    };
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);

    await binding.watchPerformance(() async {
      final list = find.byType(CustomScrollView);
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -900), 3000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, 900), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'list_scroll_frames');

    await binding.watchPerformance(() async {
      final handle = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_GripPainter',
      );
      final start = tester.getCenter(handle.at(3));
      final g = await tester.startGesture(start);
      for (var i = 0; i < 40; i++) {
        await g.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 40; i++) {
        await g.moveBy(const Offset(0, -12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }, reportKey: 'list_drag_frames');

    await tester.tap(find.bySemanticsLabel(l10n.listBack));
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
