import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sticky_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(await repo.firstRunDone(), isTrue);
      // CA-001-02: el campo tiene el foco (y en el móvil, el teclado abierto).
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'CA-001-05: si ya se vio la bienvenida y no hay tareas, se abre el editor sin animación',
    (tester) async {
      await _pumpApp(tester, firstRunDone: true);
      expect(find.byType(WelcomeIntro), findsNothing);
      expect(find.byType(TaskEditorScreen), findsOneWidget);
    },
  );

  testWidgets(
    'CA-001-04: al guardar la primera tarea se ve como tarea actual',
    (tester) async {
      await _pumpApp(tester, firstRunDone: true);
      await tester.enterText(find.byType(TextField), 'Comprar pan');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
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
      expect(find.byType(TaskEditorScreen), findsOneWidget);
    },
  );

  testWidgets(
    'CL-001-4: el primer uso queda guardado en cuanto se muestra la bienvenida',
    (tester) async {
      final repo = await _pumpApp(tester);
      expect(find.byType(WelcomeIntro), findsOneWidget);
      // Aún se está escribiendo: si la app muere aquí, al reabrir irá al editor.
      expect(await repo.firstRunDone(), isTrue);
      expect(find.byType(WelcomeIntro), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'CA-001-03: el gesto atrás en el editor de la primera tarea cierra la app sin salir del editor',
    (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpApp(tester, firstRunDone: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
      expect(find.byType(TaskEditorScreen), findsOneWidget);
    },
  );

  testWidgets('CA-001-06: con varias tareas solo se ve la primera de la cola', (
    tester,
  ) async {
    final repo = InMemoryTaskRepository();
    await repo.insert(sampleTask(id: 'b', text: 'Segunda', rank: 'b'));
    await repo.insert(sampleTask(id: 'a', text: 'Primera', rank: 'a'));
    await repo.setFirstRunDone();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(repo),
          bootStateProvider.overrideWithValue(
            BootState(
              currentTask: await repo.currentTask(),
              firstRunDone: true,
            ),
          ),
        ],
        child: const UnaApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Primera'), findsOneWidget);
    expect(find.text('Segunda'), findsNothing);
  });

  testWidgets(
    'CL-001-8: si cambia el idioma del sistema, los textos se actualizan',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'ES')];
      await _pumpApp(tester, firstRunDone: true);
      expect(find.text('Guardar'), findsOneWidget);

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
    },
  );

  testWidgets(
    'CA-001-01: la bienvenida tiene el color de la primera nota y se funde con el editor del mismo color',
    (tester) async {
      await _pumpApp(tester);
      Color noteColor() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(StickyNote),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color!;
      }

      final introColor = noteColor();
      await tester.tap(find.byType(WelcomeIntro));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(noteColor(), introColor);
    },
  );

  testWidgets('CA-001-08: la primera tarea es amarilla, como la bienvenida', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Comprar pan');
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
    );
    await tester.pumpAndSettle();
    final task = await repo.currentTask();
    expect(task?.colorKey, ColorPicker.firstTaskColorKey);
    expect(UnaPalettes.classic[task!.colorKey], const Color(0xFFFFE55C));
  });
}
