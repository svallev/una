import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> _wipeDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // Solo en las apps de pruebas (`.debug`, `.profile`): nunca borra las
  // tareas reales.
  if (!dir.path.contains('.debug') && !dir.path.contains('.profile')) {
    throw StateError(
      'Pruebas de integración fuera de la app .debug: ${dir.path}',
    );
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dir.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

DriftTaskRepository _repo(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(tester.element(find.byType(screen)))
            .read(taskRepositoryProvider)
        as DriftTaskRepository;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-003-03a/05/06/11: completar en el dispositivo guarda en la BD real y al rearrancar se ve "Todo hecho."',
    (tester) async {
      await _wipeDatabase();
      await bootstrap();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(WelcomeIntro));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Comprar pan');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
      );
      await tester.pumpAndSettle();
      final task = tester
          .widget<CurrentTaskScreen>(find.byType(CurrentTaskScreen))
          .task;

      // Mantener pulsado 1,2 s.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(AllDoneScreen), findsOneWidget);

      final repo = _repo(tester, AllDoneScreen);
      final done = (await repo.findById(task.id))!;
      expect(done.status, TaskStatus.completed);
      expect(done.completedAt, isNotNull);
      expect(done.text, 'Comprar pan');

      // Rearranque: sin pendientes y con una completada → "Todo hecho.".
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.byType(AllDoneScreen), findsOneWidget);
    },
  );
}
