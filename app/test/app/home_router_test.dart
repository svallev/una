import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/license_detail_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sticky_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../features/task_list/list_harness.dart' show FakeClock, background;
import '../support/pump_app.dart';

class _FakeClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 24, 10);
  @override
  DateTime now() => value;
}

/// Fuente de licencias sin registro (spec 012): un elemento con un texto.
class _LicenseSource implements LicenseSource {
  @override
  Future<List<LicensePackage>> load() async => const [
    LicensePackage(
      name: 'zxq_pkg',
      texts: [
        LicenseText([(text: 'Zxq licence text.', indent: 0)]),
      ],
    ),
  ];
}

class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

Future<InMemoryTaskRepository> _pumpApp(
  WidgetTester tester, {
  bool firstRunDone = false,
  bool withTask = false,
  Clock? clock,
  InMemoryTaskRepository? existing,
  List<Override> overrides = const [],
}) async {
  final repo = existing ?? InMemoryTaskRepository();
  final task = withTask ? sampleTask() : null;
  if (task != null && existing == null) await repo.insert(task);
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
        ...overrides,
      ],
      child: const UnaApp(),
    ),
  );
  await tester.pump();
  return repo;
}

/// Los tres niveles de la Configuración (spec 012) y cómo llegar a cada uno
/// desde la tarea actual (el sistema, en test, está en inglés).
final _settingsLevels = <(String, Type, Future<void> Function(WidgetTester))>[
  ('nivel 1', SettingsScreen, (tester) async {}),
  (
    'nivel 2',
    LicensesScreen,
    (tester) async {
      await tester.tap(find.text('Open-source licenses'));
      await tester.pumpAndSettle();
    },
  ),
  (
    'nivel 3',
    LicenseDetailScreen,
    (tester) async {
      await tester.tap(find.text('Open-source licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('zxq_pkg'));
      await tester.pumpAndSettle();
    },
  ),
];

/// Abre el menú y "Settings and profile" sobre la tarea actual.
Future<void> _openSettingsLevel(
  WidgetTester tester,
  Future<void> Function(WidgetTester) goTo,
) async {
  await tester.tap(find.bySemanticsLabel('Task menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings and profile'));
  await tester.pumpAndSettle();
  await goTo(tester);
}

List<Override> get _settingsOverrides => [
  licenseSourceProvider.overrideWithValue(_LicenseSource()),
  linkOpenerProvider.overrideWithValue(_Opener()),
];

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
    'CA-011-03: con el reloj inyectado a 9:59 se ve la misma pantalla y a 10:00, la tarea actual (o el editor)',
    (tester) async {
      // La frontera exacta de CA-001-12 que pide la spec 011: el test anterior
      // prueba 9:00 y 10:00; aquí, 9:59 (se conserva) y 10:00 (se descarta).
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

      background(const Duration(minutes: 9, seconds: 59));
      await tester.pumpAndSettle();
      expect(find.text('Borrador'), findsOneWidget);

      background(const Duration(minutes: 10));
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

  testWidgets(
    'CA-001-05 / CA-004-08 (ADR-0012): al reabrir sin pendientes, pero con '
    'alguna tarea guardada antes, se ve "Todo hecho.", no el editor',
    (tester) async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask(id: 'a', rank: 'a'));
      await repo.remove('a');
      await repo.setFirstRunDone();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(repo),
            bootStateProvider.overrideWithValue(
              BootState(
                currentTask: null,
                firstRunDone: true,
                // Igual que main.dart: solo se consulta si no hay pendientes.
                hasEverHadTasks: await repo.hasEverHadTasks(),
              ),
            ),
          ],
          child: const UnaApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
    },
  );

  for (final (name, level, goTo) in _settingsLevels) {
    testWidgets(
      'CA-012-06: con el reloj a 9:59 se ve el mismo nivel de la Configuración ($name) y a 10:00, la tarea actual sin menú',
      (tester) async {
        final clock = FakeClock();
        await _pumpApp(
          tester,
          firstRunDone: true,
          withTask: true,
          clock: clock,
          overrides: _settingsOverrides,
        );
        await _openSettingsLevel(tester, goTo);
        expect(find.byType(level), findsOneWidget);

        background(tester, clock, const Duration(minutes: 9, seconds: 59));
        await tester.pumpAndSettle();
        expect(find.byType(level), findsOneWidget);
        expect(find.byType(CurrentTaskScreen), findsNothing);

        background(tester, clock, UnaApp.resetAfter);
        await tester.pumpAndSettle();
        expect(find.byType(level), findsNothing);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MenuSheet), findsNothing);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'CA-012-06: con la confirmación de la política abierta, a 10:00 se cierra todo y se ve la tarea actual',
    (tester) async {
      final clock = FakeClock();
      await _pumpApp(
        tester,
        firstRunDone: true,
        withTask: true,
        clock: clock,
        overrides: _settingsOverrides,
      );
      await _openSettingsLevel(tester, (_) async {});
      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsOneWidget);

      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);

      background(tester, clock, UnaApp.resetAfter);
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
    },
  );

  for (final (name, level, goTo) in _settingsLevels) {
    testWidgets(
      'CL-012-11: si el sistema cierra la app con la Configuración abierta ($name), el siguiente arranque es normal, a la tarea actual: ni ella ni el menú se restauran',
      (tester) async {
        final repo = await _pumpApp(
          tester,
          firstRunDone: true,
          withTask: true,
          overrides: _settingsOverrides,
        );
        await _openSettingsLevel(tester, goTo);
        expect(find.byType(level), findsOneWidget);

        // El sistema mata el proceso: se descarta todo el árbol y se vuelve a
        // arrancar con lo guardado.
        await tester.pumpWidget(const SizedBox());
        await _pumpApp(
          tester,
          firstRunDone: true,
          withTask: true,
          existing: repo,
          overrides: _settingsOverrides,
        );

        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(LicensesScreen), findsNothing);
        expect(find.byType(LicenseDetailScreen), findsNothing);
        expect(find.byType(MenuSheet), findsNothing);
      },
    );
  }
}
