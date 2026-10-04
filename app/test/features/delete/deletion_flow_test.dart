import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/completion_controller.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/deletion_controller.dart';
import 'package:app/features/delete/trash_can.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';
import '../../support/undo.dart';

const _frame = Duration(milliseconds: 16);

class _Repo extends InMemoryTaskRepository {
  bool failDelete = false;
  bool failInsert = false;
  String insertMessage = 'disk I/O error';
  int inserts = 0;

  /// Lo que tarda la BD en dar la tarea actual (la de verdad avisa un instante
  /// después de escribir).
  Duration currentDelay = Duration.zero;

  @override
  Future<Task?> currentTask() async {
    if (currentDelay > Duration.zero) await Future<void>.delayed(currentDelay);
    return super.currentTask();
  }

  @override
  Future<void> insert(Task task) async {
    inserts++;
    if (failInsert) throw StateError('$insertMessage: ${task.text}');
    return super.insert(task);
  }

  @override
  Future<bool> remove(String id) async {
    if (failDelete) throw StateError('disk I/O error');
    return super.remove(id);
  }
}

final _menuButton = find.bySemanticsLabel('Menú de la tarea');
final _card = find.byType(UndoCard);

/// La app, con el reloj del test para que la cuenta atrás de la card avance
/// con `tester.pump`.
Future<_Repo> _pump(
  WidgetTester tester, {
  required List<String> tasks,
  bool screenReader = false,
  bool reduced = false,
  _Repo? repo,
}) => pumpUnaApp(
  tester,
  repo: repo ?? _Repo(),
  tasks: tasks,
  screenReader: screenReader,
  reduced: reduced,
  clock: TesterClock(tester),
  overrides: [
    accessibilityTimeoutsProvider.overrideWithValue(
      FakeAccessibilityTimeouts(),
    ),
  ],
);

/// Menú → Eliminar. Sin hoja de confirmación (CA-014-01). Deja la app justo al
/// empezar el arrugado.
Future<void> _delete(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pump(_frame);
  await tester.pump(_frame);
}

/// Deja terminar el arrugado.
Future<void> _crumple(WidgetTester tester, {Duration? duration}) async {
  await tester.pump(duration ?? UnaMotion.crumple);
  await tester.pump(_frame);
  await tester.pump(_frame);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

List<String> _listenAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'announce') {
        final data = map['data']! as Map<Object?, Object?>;
        announcements.add(data['message']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'CA-014-01: sin confirmación, guarda antes de animar; el menú se cierra, '
    'la nota se arruga con la siguiente detrás y la card aparece al acabar',
    (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester);

      // Ninguna hoja de confirmación y el menú cerrado.
      expect(find.text('¿Eliminar esta tarea?'), findsNothing);
      // Borrada antes de la animación (CA-004-03, ADR-0012).
      expect(await repo.findById('t0'), isNull);

      // A mitad: el menú cerrado, la nota arrugándose, la papelera, y detrás
      // solo la siguiente. Aún no hay card.
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(find.byType(MenuSheet), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsNWidgets(3));
      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(find.byType(TrashCan), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CrumpleOverlay),
          matching: find.text('Primera'),
        ),
        findsOneWidget,
      );
      expect(find.text('Segunda'), findsWidgets);
      expect(_card, findsNothing);

      // Al terminar, la nota nueva y la card con la eliminada.
      await _crumple(tester);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(_card, findsOneWidget);
      expect(
        find.descendant(of: _card, matching: find.text('Primera')),
        findsOneWidget,
      );
      expect(find.text('Tarea eliminada'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'CA-004-05: durante el arrugado no responden el menú, completar ni el '
    'gesto atrás',
    (tester) async {
      final repo = await _pump(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      final menuAt = tester.getCenter(_menuButton);
      await _delete(tester);
      await tester.pump(UnaMotion.crumple * 0.3);

      await tester.tapAt(menuAt);
      await tester.pump(_frame);
      expect(find.byType(MenuSheet), findsNothing);
      final popped = await tester.binding.handlePopRoute();
      await tester.pump(_frame);
      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(popped, isTrue, reason: 'el gesto atrás se consume sin salir');

      await _crumple(tester);
      expect(await repo.countPending(), 2);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-004-05: durante el arrugado el teclado no llega al menú ni completa '
    'la siguiente',
    (tester) async {
      final repo = await _pump(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester);
      await tester.pump(UnaMotion.crumple * 0.3);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(UnaMotion.holdToComplete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump(_frame);
      expect(find.byType(MenuSheet), findsNothing);
      await _crumple(tester);
      expect(await repo.countPending(), 2);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-014-03, CA-014-06: la card dura 4 s y al acabar desaparece de golpe, '
    'sin dejar ningún aviso (no existe "Nada pendiente.")',
    (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester);
      await _crumple(tester);
      expect(_card, findsOneWidget);

      await tester.pump(
        UnaMotion.undoWindow - const Duration(milliseconds: 300),
      );
      expect(_card, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_card, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Nada'), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-014-01, CL-014-16: al eliminar la última, "Todo hecho." con la card '
    'y sin "Crear una tarea", que vuelve cuando la card desaparece',
    (tester) async {
      await _pump(tester, tasks: ['Única']);
      await _delete(tester);

      // Detrás ya está "Todo hecho.", sin su botón mientras cae la bola.
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      final create = find.descendant(
        of: find.byType(AllDoneScreen),
        matching: find.byWidgetPredicate(
          (w) => w is Visibility && w.child is ExcludeFocus,
        ),
      );
      expect(_card, findsNothing);

      await _crumple(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('hecho.'), findsOneWidget);
      expect(_card, findsOneWidget);
      expect(find.bySemanticsLabel('Crear una tarea'), findsNothing);
      expect(tester.widget<Visibility>(create).visible, isFalse);
      expect(
        (tester.widget<Visibility>(create).child as ExcludeFocus).excluding,
        isTrue,
      );
      expect(find.textContaining('Nada'), findsNothing);
      expect(find.textContaining('No tienes ninguna tarea'), findsNothing);

      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
      expect(tester.widget<Visibility>(create).visible, isTrue);
      expect(
        find.descendant(
          of: find.byType(AllDoneScreen),
          matching: find.byWidgetPredicate(
            (w) => w is BrutalButton && w.label == 'Crear una tarea',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CA-014-05: mientras se ve la card, "Pulsa para completar" no se ve ni '
    'se lee, pero conserva su sitio; vuelve cuando desaparece',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, tasks: ['Primera', 'Segunda']);
      expect(find.bySemanticsLabel('Pulsa para completar'), findsOneWidget);
      await _delete(tester);
      await _crumple(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(_card, findsOneWidget);
      expect(find.bySemanticsLabel('Pulsa para completar'), findsNothing);
      final hidden = find.ancestor(
        of: find.byType(HoldToCompleteButton, skipOffstage: false),
        matching: find.byType(Visibility),
      );
      expect(tester.widget<Visibility>(hidden.first).visible, isFalse);
      expect(tester.widget<Visibility>(hidden.first).maintainSize, isTrue);

      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
      expect(find.bySemanticsLabel('Pulsa para completar'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-014-16: con lector, el arrugado no anuncia nada y la card tampoco '
    '(no es una región en vivo)',
    (tester) async {
      final announcements = _listenAnnouncements(tester);
      final handle = tester.ensureSemantics();
      await _pump(tester, tasks: ['Primera', 'Segunda'], screenReader: true);
      await _delete(tester);
      await tester.pump(UnaMotion.sheetOut);
      await _crumple(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(_card, findsOneWidget);
      expect(announcements, isEmpty);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-014-21: con reducir movimiento, la nota se desvanece en 0,6 s sin '
    'papelera y la card aparece igual',
    (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda'], reduced: true);
      await _delete(tester);
      await tester.pump(UnaMotion.crumpleReducedFade * 0.5);
      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(find.byType(TrashCan), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CrumpleOverlay),
          matching: find.byType(ClipPath),
        ),
        findsNothing,
      );
      await _crumple(tester, duration: UnaMotion.crumpleReducedFade * 0.5);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(_card, findsOneWidget);
    },
  );

  testWidgets(
    'CA-014-22: si falla al guardar, no hay animación ni card, la tarea '
    'sigue y se puede reintentar',
    (tester) async {
      final repo = await _pump(
        tester,
        tasks: ['Primera', 'Segunda'],
        repo: _Repo()..failDelete = true,
      );
      await _delete(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(_card, findsNothing);
      expect(find.text('No hemos podido eliminar la tarea'), findsOneWidget);
      expect(find.text('Primera'), findsOneWidget);
      expect(await repo.findById('t0'), isNotNull);

      repo.failDelete = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(_frame);
      expect(await repo.findById('t0'), isNull);
      await _crumple(tester);
      expect(find.text('Segunda'), findsOneWidget);
      expect(
        find.text('No hemos podido eliminar la tarea'),
        findsNothing,
        reason: 'el aviso se cierra al eliminar',
      );
      expect(_card, findsOneWidget);
    },
  );

  testWidgets(
    'CA-014-22: si había una card de otra tarea, desaparece al intentar '
    'eliminar y queda definitiva aunque falle: nunca se ven a la vez',
    (tester) async {
      final repo = await _pump(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await _delete(tester);
      await _crumple(tester);
      expect(_card, findsOneWidget);

      repo.failDelete = true;
      await _delete(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_card, findsNothing);
      expect(find.text('No hemos podido eliminar la tarea'), findsOneWidget);
      expect(_container(tester).read(undoProvider).phase, UndoPhase.none);
    },
  );

  testWidgets(
    'CA-014-08: la card de la anterior desaparece al empezar el arrugado de '
    'la siguiente y, al terminar, aparece la de esta',
    (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _delete(tester);
      await _crumple(tester);
      expect(
        find.descendant(of: _card, matching: find.text('Primera')),
        findsOneWidget,
      );

      await _delete(tester);
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(_card, findsNothing);
      expect(find.byType(CrumpleOverlay), findsOneWidget);

      await _crumple(tester);
      expect(_card, findsOneWidget);
      expect(
        find.descendant(of: _card, matching: find.text('Segunda')),
        findsOneWidget,
      );
      expect(find.text('Tercera'), findsOneWidget);
    },
  );

  testWidgets(
    'CL-014-1: una doble pulsación rápida en "Eliminar" del menú elimina una '
    'sola tarea',
    (tester) async {
      final repo = await _pump(
        tester,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await tester.tap(_menuButton);
      await tester.pumpAndSettle();
      final eliminar = find.text('Eliminar');
      final at = tester.getCenter(eliminar);
      await tester.tapAt(at);
      await tester.tapAt(at);
      await tester.pump(_frame);
      await _crumple(tester);
      expect(await repo.countPending(), 2);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Tercera'), findsNothing);
    },
  );

  testWidgets(
    'CA-014-11, CL-014-15: si la app pasa a segundo plano a mitad del '
    'arrugado, al volver se ve la siguiente, sin repetir la animación y sin '
    'card',
    (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester);
      await tester.pump(UnaMotion.crumple * 0.3);
      expect(find.byType(CrumpleOverlay), findsOneWidget);
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
      await tester.pump(_frame);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Primera'), findsNothing);
      expect(_card, findsNothing);
      expect(_container(tester).read(undoProvider).phase, UndoPhase.none);
    },
  );

  testWidgets(
    'CA-014-12: girar, abrir y cerrar el menú o bajar la cortina no cambian '
    'ni detienen la card',
    (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester);
      await _crumple(tester);
      expect(_card, findsOneWidget);

      await tester.tap(_menuButton);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MenuSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 400));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card, findsOneWidget);
      expect(_container(tester).read(undoProvider).cardVisible, isTrue);

      // El tiempo siguió corriendo todo ese rato.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(_card, findsNothing);
    },
  );

  testWidgets('CA-014-22: un fallo al guardar no deja nada retenido para '
      'deshacer', (tester) async {
    final repo = await _pump(
      tester,
      tasks: ['Primera', 'Segunda'],
      repo: _Repo()..failDelete = true,
    );
    final container = _container(tester);
    final task = container.read(currentTaskProvider)!;
    await expectLater(
      container.read(deletionProvider.notifier).delete(task),
      throwsA(isA<StateError>()),
    );
    expect(container.read(undoProvider).phase, UndoPhase.none);
    expect(await repo.findById('t0'), isNotNull);
  });

  group('Deshacer en la pantalla principal (CA-014-09, CA-014-10)', () {
    final undoButton = find.descendant(
      of: _card,
      matching: find.byKey(UndoCard.buttonKey),
    );

    /// Elimina la primera, deja pasar la guarda de 350 ms y vuelve a mirar.
    Future<void> deleteAndWait(WidgetTester tester) async {
      await _delete(tester);
      await _crumple(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card, findsOneWidget);
    }

    testWidgets('CA-014-09, CA-014-10: vuelve en la posición 1 con su texto, '
        'su color y sus fechas, como la actual, sin fundido, sin "¿Dónde la '
        'pones?" ni "Tarea añadida" y con un solo anuncio', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      final announcements = _listenAnnouncements(tester);
      final before = (await repo.findById('t0'))!;
      await deleteAndWait(tester);
      expect(await repo.findById('t0'), isNull);

      await tester.tap(undoButton);
      // Sin fundido: nunca se ven dos notas a la vez mientras vuelve.
      for (var i = 0; i < 12; i++) {
        await tester.pump(_frame);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
      }
      final after = (await repo.findById('t0'))!;
      expect(after.id, before.id);
      expect(after.rank, before.rank);
      expect(after.text, before.text);
      expect(after.colorKey, before.colorKey);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, before.updatedAt);
      expect((await repo.currentTask())!.id, 't0');
      expect((await repo.pendingTasks()).map((t) => t.id), ['t0', 't1']);

      expect(_card, findsNothing);
      expect(find.text('Primera'), findsOneWidget);
      expect(find.text('Segunda'), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.text('¿Dónde la pones?'), findsNothing);
      expect(find.textContaining('añadida'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(UnaMotion.sheetOut);
      await tester.pump(UnaMotion.undoWindow);
      expect(announcements, ['Tarea recuperada']);
      // Recuperada, la eliminación ya no es de nadie: nada que caducar.
      expect(_container(tester).read(undoProvider).phase, UndoPhase.none);
      expect(await repo.findById('t0'), isNotNull);
    });

    testWidgets('CA-014-10: si la BD tarda en dar la actual, no hay fundido: '
        'se espera a que lo sea antes de mostrarla', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      repo.currentDelay = const Duration(milliseconds: 200);

      await tester.tap(undoButton);
      for (var i = 0; i < 30; i++) {
        await tester.pump(_frame);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
      }
      expect(find.text('Primera'), findsOneWidget);
      expect(find.text('Segunda'), findsNothing);
      await tester.pump(UnaMotion.sheetOut * 2);
    });

    testWidgets('CA-014-10: al eliminar la última, deshacer vuelve de "Todo '
        'hecho." a la tarea', (tester) async {
      final repo = await _pump(tester, tasks: ['Única']);
      await deleteAndWait(tester);
      expect(find.byType(AllDoneScreen), findsOneWidget);

      await tester.tap(undoButton);
      for (var i = 0; i < 12; i++) {
        await tester.pump(_frame);
      }
      expect(find.byType(AllDoneScreen), findsNothing);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Única'), findsOneWidget);
      expect((await repo.currentTask())!.id, 't0');
      expect(_card, findsNothing);
    });

    testWidgets('CA-014-03: la card no usa el estilo de reserva (sin '
        'Material, el texto saldría subrayado en amarillo)', (tester) async {
      await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      final title = find.descendant(
        of: _card,
        matching: find.text('Tarea eliminada'),
      );
      final style = DefaultTextStyle.of(tester.element(title)).style;
      expect(style.decoration, isNot(TextDecoration.underline));
      expect(style.fontFamily, isNot('monospace'));
      await tester.pump(UnaMotion.undoWindow);
    });

    testWidgets('CL-014-3: una activación antes de 350 ms no hace nada; '
        'después sí', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await _delete(tester);
      await _crumple(tester);
      expect(_card, findsOneWidget);

      await tester.tap(undoButton);
      await tester.pump(_frame);
      expect(_card, findsOneWidget);
      expect(await repo.findById('t0'), isNull);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(undoButton);
      await tester.pump(_frame);
      expect(_card, findsNothing);
      expect(await repo.findById('t0'), isNotNull);
      await tester.pump(UnaMotion.sheetOut * 2);
    });

    testWidgets('CL-014-3: dos pulsaciones seguidas recuperan una sola vez', (
      tester,
    ) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      final announcements = _listenAnnouncements(tester);
      await deleteAndWait(tester);
      final inserts = repo.inserts;

      await tester.tap(undoButton);
      await tester.tap(undoButton, warnIfMissed: false);
      await tester.pump(_frame);
      await tester.pump(UnaMotion.sheetOut);
      await tester.pump(_frame);
      expect(repo.inserts, inserts + 1);
      expect(await repo.pendingTasks(), hasLength(2));
      expect(announcements, ['Tarea recuperada']);
    });

    testWidgets('CL-014-3: Intro mantenido es una sola activación y no '
        'completa nada de lo que hay detrás', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      final inserts = repo.inserts;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(_frame);
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.pump(_frame);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump(UnaMotion.holdToComplete);

      expect(repo.inserts, inserts + 1);
      expect(_container(tester).read(completionProvider).busy, isFalse);
      expect((await repo.pendingTasks()).map((t) => t.id), ['t0', 't1']);
      expect(find.text('Primera'), findsOneWidget);
    });

    testWidgets('CL-014-4: justo antes de acabar el tiempo se recupera; '
        'justo después ya no hay nada que pulsar', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      // Del primer fotograma de la card (400 ms) a 100 ms del final.
      await tester.pump(
        UnaMotion.undoWindow - const Duration(milliseconds: 500),
      );
      expect(_card, findsOneWidget);
      await tester.tap(undoButton);
      await tester.pump(_frame);
      expect(await repo.findById('t0'), isNotNull);

      // Otra eliminación que caduca: un "Deshacer" tardío no hace nada.
      await _delete(tester);
      await _crumple(tester);
      await tester.pump(UnaMotion.undoWindow + _frame);
      await tester.pump();
      expect(_card, findsNothing);
      expect(
        await _container(tester).read(undoProvider.notifier).undo(),
        isNull,
      );
      expect((await repo.pendingTasks()).map((t) => t.id), ['t1']);
    });

    testWidgets('CA-014-23: si falla al recuperar, el aviso con "Reintentar" '
        'no tapa el botón y "Reintentar" recupera la tarea', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      final announcements = _listenAnnouncements(tester);
      await deleteAndWait(tester);
      repo.failInsert = true;

      await tester.tap(undoButton);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card, findsNothing);
      expect(find.text('No hemos podido recuperar la tarea'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(await repo.findById('t0'), isNull);
      expect(_container(tester).read(undoProvider).phase, UndoPhase.failed);
      // Los botones vuelven a verse y el aviso flota por encima de ellos.
      final cta = find.byType(HoldToCompleteButton);
      expect(cta, findsOneWidget);
      expect(
        tester.getRect(find.text('Reintentar')).bottom,
        lessThanOrEqualTo(tester.getRect(cta).top),
      );
      // El texto del error no sale por ninguna parte.
      expect(find.textContaining('disk I/O'), findsNothing);
      expect(tester.takeException(), isNull);

      repo.failInsert = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      expect(await repo.findById('t0'), isNotNull);
      expect(find.text('Primera'), findsOneWidget);
      expect(announcements, ['Tarea recuperada']);
    });

    testWidgets('CA-014-23: un `commit` quita el aviso sin animación y '
        '"Reintentar" ya no recupera nada', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      repo.failInsert = true;
      await tester.tap(undoButton);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Reintentar'), findsOneWidget);

      final undo = _container(tester).read(undoProvider.notifier);
      undo.commit();
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      repo.failInsert = false;
      expect(await undo.undo(), isNull);
      expect(await repo.findById('t0'), isNull);
      expect(_container(tester).read(undoProvider).phase, UndoPhase.none);
    });

    testWidgets('CA-014-23: descartar el aviso la hace definitiva', (
      tester,
    ) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      repo.failInsert = true;
      await tester.tap(undoButton);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_container(tester).read(undoProvider).phase, UndoPhase.failed);

      await tester.fling(
        find.text('No hemos podido recuperar la tarea'),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(_container(tester).read(undoProvider).phase, UndoPhase.none);
      repo.failInsert = false;
      expect(
        await _container(tester).read(undoProvider.notifier).undo(),
        isNull,
      );
      expect(await repo.findById('t0'), isNull);
    });

    testWidgets('CA-014-23: sin espacio, el aviso lo dice', (tester) async {
      final repo = await _pump(tester, tasks: ['Primera', 'Segunda']);
      await deleteAndWait(tester);
      repo
        ..failInsert = true
        ..insertMessage = 'No space left on device';
      await tester.tap(undoButton);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No hemos podido recuperar la tarea'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('espacio'),
        ),
        findsOneWidget,
      );
      // Sin el aviso colgado.
      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump();
    });
  });
}
