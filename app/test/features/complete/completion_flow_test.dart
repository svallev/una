import 'dart:math';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const _frame = Duration(milliseconds: 16);

class _Repo extends InMemoryTaskRepository {
  bool failComplete = false;

  @override
  Future<bool> complete(String id, DateTime at) async {
    if (failComplete) throw StateError('disk I/O error');
    return super.complete(id, at);
  }
}

Future<_Repo> _app(
  WidgetTester tester, {
  List<String> tasks = const [],
  bool hasCompleted = false,
  bool screenReader = false,
  bool reduced = false,
}) async {
  tester.platformDispatcher.localesTestValue = const [Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (screenReader || reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          accessibleNavigation: screenReader,
          disableAnimations: reduced,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final repo = _Repo();
  for (final (i, text) in tasks.indexed) {
    await repo.insert(
      sampleTask(id: 't$i', text: text, rank: 'M$i', colorKey: i % 5),
    );
  }
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
            hasCompleted: hasCompleted,
          ),
        ),
        colorPickerProvider.overrideWithValue(ColorPicker(Random(0))),
      ],
      child: const UnaApp(),
    ),
  );
  await tester.pump();
  return repo;
}

/// Mantiene pulsado el botón 1,2 s y lo suelta.
Future<void> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(HoldToCompleteButton)),
  );
  await tester.pump();
  await tester.pump(UnaMotion.holdToComplete);
  await tester.pump(_frame);
  await gesture.up();
  await tester.pump(_frame);
}

/// Espera a que termine la pausa, la rotura, la enhorabuena y el fundido.
Future<void> _celebrate(WidgetTester tester, {Duration? hold}) async {
  await tester.pump(UnaMotion.holdDonePause);
  await tester.pump(_frame);
  await tester.pump(hold ?? UnaMotion.successHold);
  await tester.pump(UnaMotion.successFade);
  await tester.pump(_frame);
  await tester.pump(UnaMotion.introFade);
}

void main() {
  testWidgets(
    'CA-003-03a/03b/04: guarda, rompe la nota sobre la enhorabuena y pasa a la siguiente',
    (tester) async {
      final repo = await _app(tester, tasks: ['Primera', 'Segunda']);
      await _hold(tester);

      // Guardada antes de animar; la tarea sigue en pantalla con el relleno.
      expect((await repo.findById('t0'))!.status, TaskStatus.completed);
      expect(find.text('Primera'), findsOneWidget);
      expect(find.byType(CelebrationOverlay), findsNothing);

      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(UnaMotion.tear ~/ 2);
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      expect(find.textContaining('¡Enhorabuena!'), findsOneWidget);
      expect(find.text('Ahora a por la siguiente →'), findsOneWidget);

      await tester.pump(UnaMotion.successHold);
      await tester.pump(UnaMotion.successFade);
      await tester.pump(_frame);
      await tester.pump(UnaMotion.introFade);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Primera'), findsNothing);
    },
  );

  testWidgets('CA-003-05: al completar la última se ve "Todo hecho."', (
    tester,
  ) async {
    await _app(tester, tasks: ['Única']);
    await _hold(tester);
    await tester.pump(UnaMotion.holdDonePause);
    await tester.pump(_frame);
    expect(find.text('Ahora a por la siguiente →'), findsNothing);
    await _celebrate(tester, hold: Duration.zero);
    expect(find.byType(AllDoneScreen), findsOneWidget);
    expect(find.text('Todo\nhecho.'), findsOneWidget);
    expect(
      find.text('No queda nada pendiente. Disfrútalo, o apunta lo siguiente.'),
      findsOneWidget,
    );
    expect(find.text('Crear una tarea'), findsOneWidget);
  });

  testWidgets(
    'CA-003-09: durante la animación se ignoran el menú y el gesto atrás',
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
      await _app(tester, tasks: ['Primera', 'Segunda']);
      await _hold(tester);
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      await tester.binding.handlePopRoute();
      await tester.pump(_frame);
      expect(calls, isNot(contains('SystemNavigator.pop')));
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      await _celebrate(tester, hold: Duration.zero);
    },
  );

  testWidgets(
    'CA-003-07: con lector se hace un único anuncio con la siguiente tarea',
    (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message! as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              final data = map['data']! as Map<Object?, Object?>;
              announcements.add(data['message']! as String);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final handle = tester.ensureSemantics();
      await _app(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
      tester.semantics.customAction(
        find.semantics.byLabel('Tarea actual: Primera'),
        const CustomSemanticsAction(label: 'Completar tarea'),
      );
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(announcements, ['Tarea completada. Siguiente: Segunda']);
      await _celebrate(tester, hold: CelebrationOverlay.screenReaderHold);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-003-13: con lector de pantalla la enhorabuena dura al menos 4 s',
    (tester) async {
      await _app(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
      await _hold(tester);
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 3500));
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(UnaMotion.successFade);
      await tester.pump(_frame);
      expect(find.byType(CelebrationOverlay), findsNothing);
      await tester.pump(UnaMotion.introFade);
    },
  );

  testWidgets(
    'CA-003-12: si falla al guardar, no se rompe, se explica y se puede reintentar',
    (tester) async {
      final repo = await _app(tester, tasks: ['Primera', 'Segunda'])
        ..failComplete = true;
      await _hold(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(find.text('No hemos podido completar la tarea'), findsOneWidget);
      expect((await repo.findById('t0'))!.status, TaskStatus.pending);
      expect(find.text('Primera'), findsWidgets);

      repo.failComplete = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(_frame);
      expect((await repo.findById('t0'))!.status, TaskStatus.completed);
      await _celebrate(tester);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CL-003-5: con reducir movimiento no hay rotura y la secuencia termina igual',
    (tester) async {
      await _app(tester, tasks: ['Primera', 'Segunda'], reduced: true);
      await _hold(tester);
      await _celebrate(tester);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CL-003-7: si la app pasa a segundo plano durante la enhorabuena, al volver se ve la siguiente',
    (tester) async {
      await _app(tester, tasks: ['Primera', 'Segunda']);
      await _hold(tester);
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(_frame);
      await tester.pump(UnaMotion.introFade);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-003-11: sin pendientes y con completadas, al abrir se ve "Todo hecho."',
    (tester) async {
      await _app(tester, hasCompleted: true);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(find.byType(FirstTaskEditorScreen), findsNothing);
      await tester.pump(UnaMotion.enter);
    },
  );

  testWidgets(
    'CA-003-10: "Crear una tarea" abre el editor; atrás vuelve a "Todo hecho." y al guardar se ve la tarea',
    (tester) async {
      await _app(tester, hasCompleted: true);
      await tester.tap(find.text('Crear una tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(FirstTaskEditorScreen), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FirstTaskEditorScreen), findsNothing);
      expect(find.byType(AllDoneScreen), findsOneWidget);

      await tester.tap(find.text('Crear una tarea'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Llamar al fontanero');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FirstTaskEditorScreen), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Llamar al fontanero'), findsOneWidget);
    },
  );
}
