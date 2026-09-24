import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

class _FakeClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 24, 10);
  @override
  DateTime now() => value;
}

Future<InMemoryTaskRepository> _pumpApp(
  WidgetTester tester, {
  bool firstRunDone = false,
  bool withTask = false,
  Clock? clock,
}) async {
  final repo = InMemoryTaskRepository();
  final task = withTask ? sampleTask() : null;
  if (task != null) await repo.insert(task);
  if (firstRunDone) await repo.setFirstRunDone();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        bootStateProvider.overrideWithValue(
          BootState(currentTask: task, firstRunDone: firstRunDone),
        ),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      child: const UnaApp(),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  testWidgets(
    'CA-001-09: con una tarea pendiente, lo primero que se ve es la tarea actual',
    (tester) async {
      await _pumpApp(tester, firstRunDone: true, withTask: true);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.byType(WelcomeIntro), findsNothing);
    },
  );

  testWidgets(
    'CA-001-01 → CA-001-02: primer uso muestra la bienvenida y después el editor',
    (tester) async {
      final repo = await _pumpApp(tester);
      expect(find.byType(WelcomeIntro), findsOneWidget);
      await tester.tap(find.byType(WelcomeIntro)); // saltar
      await tester.pumpAndSettle();
      expect(find.byType(FirstTaskEditorScreen), findsOneWidget);
      expect(await repo.firstRunDone(), isTrue);
    },
  );

  testWidgets(
    'CA-001-05: si ya se vio la bienvenida y no hay tareas, se abre el editor sin animación',
    (tester) async {
      await _pumpApp(tester, firstRunDone: true);
      expect(find.byType(WelcomeIntro), findsNothing);
      expect(find.byType(FirstTaskEditorScreen), findsOneWidget);
    },
  );

  testWidgets(
    'CA-001-04: al guardar la primera tarea se ve como tarea actual',
    (tester) async {
      await _pumpApp(tester, firstRunDone: true);
      await tester.enterText(find.byType(TextField), 'Comprar pan');
      await tester.pump();
      await tester.tap(
        find.byType(BrutalButton),
      ); // UnaApp usa el idioma del sistema (en test, inglés)
      await tester.pumpAndSettle();
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Comprar pan'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-001-12: tras 10 minutos en segundo plano se descarta el editor; con menos, se conserva',
    (tester) async {
      final clock = _FakeClock();
      await _pumpApp(tester, firstRunDone: true, clock: clock);
      await tester.enterText(find.byType(TextField), 'Borrador');
      await tester.pump();

      void background(Duration d) {
        for (final s in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
        clock.value = clock.value.add(d);
        for (final s in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
      }

      background(const Duration(minutes: 9));
      await tester.pumpAndSettle();
      expect(find.text('Borrador'), findsOneWidget);

      background(UnaApp.resetAfter);
      await tester.pumpAndSettle();
      expect(find.text('Borrador'), findsNothing);
      expect(find.byType(FirstTaskEditorScreen), findsOneWidget);
    },
  );
}
