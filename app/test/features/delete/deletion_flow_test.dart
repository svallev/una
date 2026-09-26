import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/delete/trash_can.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

const _frame = Duration(milliseconds: 16);

class _Repo extends InMemoryTaskRepository {
  bool failDelete = false;

  @override
  Future<bool> delete(String id, DateTime at) async {
    if (failDelete) throw StateError('disk I/O error');
    return super.delete(id, at);
  }
}

final _menuButton = find.bySemanticsLabel('Menú de la tarea');
final _confirmButton = find.byWidgetPredicate(
  (w) => w is BrutalButton && w.label == 'Eliminar',
);

/// Menú → Eliminar → Eliminar. Deja la app justo al empezar el arrugado.
Future<void> _delete(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pumpAndSettle();
  await tester.tap(_confirmButton);
  await tester.pump(_frame);
  await tester.pump(_frame);
}

/// Deja terminar la bajada de la hoja y el arrugado.
Future<void> _crumple(WidgetTester tester, {Duration? duration}) async {
  await tester.pump(duration ?? UnaMotion.crumple);
  await tester.pump(_frame);
  await tester.pump(_frame);
}

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
  testWidgets(
    'CA-004-03/04: guarda antes de animar, arruga la nota con la siguiente detrás y la deja como actual',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Primera', 'Segunda'],
      );
      await _delete(tester);

      // Guardada antes de la animación (CA-004-03).
      final gone = (await repo.findById('t0'))!;
      expect(gone.deletedAt, isNotNull);
      expect(gone.text, isNull);

      // A mitad: la hoja ya bajó; la nota arrugándose, la papelera, y detrás
      // solo la siguiente (sin la pantalla anterior fundiéndose).
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(find.byType(DeleteConfirmSheet), findsNothing);
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
      // Detrás, la siguiente (y encima, sus controles sin el texto).
      expect(find.text('Segunda'), findsWidgets);

      await _crumple(tester);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Primera'), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      // Vuelve el botón de completar de la nueva tarea actual.
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
    },
  );

  testWidgets(
    'CA-004-05: durante el arrugado no responden el menú, completar ni el gesto atrás',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo(),
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
    'CA-004-06: al terminar no aparece ningún aviso ni opción de deshacer',
    (tester) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera', 'Segunda']);
      await _delete(tester);
      await _crumple(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Deshacer'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    },
  );

  testWidgets(
    'CA-004-07: al eliminar la última se ve "Todo hecho." (no existe "Nada pendiente.")',
    (tester) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Única']);
      await _delete(tester);

      // Detrás ya está "Todo hecho.", sin su botón mientras cae la bola.
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      final create = find.byWidgetPredicate(
        (w) => w is Visibility && w.child is BrutalButton,
      );
      expect(tester.widget<Visibility>(create).visible, isFalse);

      await _crumple(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('hecho.'), findsOneWidget);
      expect(tester.widget<Visibility>(create).visible, isTrue);
      expect(find.textContaining('Nada'), findsNothing);
      expect(find.textContaining('No tienes ninguna tarea'), findsNothing);
    },
  );

  testWidgets(
    'CA-004-11: con lector, un único anuncio y el foco en la nueva tarea',
    (tester) async {
      final announcements = _listenAnnouncements(tester);
      final handle = tester.ensureSemantics();
      await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Primera', 'Segunda'],
        screenReader: true,
      );
      await _delete(tester);
      // Cuando la hoja ya ha bajado.
      await tester.pump(UnaMotion.sheetOut);
      expect(announcements, ['Tarea eliminada. Siguiente: Segunda']);
      await _crumple(tester);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        focused.findAncestorWidgetOfExactType<CurrentTaskScreen>()?.task.text,
        'Segunda',
      );
      expect(announcements, hasLength(1));
      handle.dispose();
    },
  );

  testWidgets(
    'CA-004-11: al eliminar la última se anuncia "Todo hecho." y el foco va al título',
    (tester) async {
      final announcements = _listenAnnouncements(tester);
      final handle = tester.ensureSemantics();
      await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Única'],
        screenReader: true,
      );
      await _delete(tester);
      await tester.pump(UnaMotion.sheetOut);
      expect(announcements, ['Tarea eliminada. Todo hecho.']);
      await _crumple(tester);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(focused.findAncestorWidgetOfExactType<AllDoneScreen>(), isNotNull);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-004-12: con reducir movimiento, la nota se desvanece en 0,6 s sin papelera',
    (tester) async {
      await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Primera', 'Segunda'],
        reduced: true,
      );
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
    },
  );

  testWidgets(
    'CA-004-13: si falla al guardar, no hay animación, la tarea sigue y se puede reintentar',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo()..failDelete = true,
        tasks: ['Primera', 'Segunda'],
      );
      await _delete(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.byType(DeleteConfirmSheet), findsNothing);
      expect(find.text('No hemos podido eliminar la tarea'), findsOneWidget);
      expect(find.text('Primera'), findsOneWidget);
      expect((await repo.findById('t0'))!.deletedAt, isNull);

      repo.failDelete = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(_frame);
      expect((await repo.findById('t0'))!.deletedAt, isNotNull);
      await _crumple(tester);
      expect(find.text('Segunda'), findsOneWidget);
      expect(
        find.text('No hemos podido eliminar la tarea'),
        findsNothing,
        reason: 'el aviso se cierra al eliminar',
      );
    },
  );

  testWidgets(
    'CA-004-03: si la app pasa a segundo plano a mitad, al volver se ve la siguiente sin repetir la animación',
    (tester) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera', 'Segunda']);
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
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Primera'), findsNothing);
    },
  );

  testWidgets(
    'CL-004-2: la hoja de confirmación sigue abierta tras volver de segundo plano (< 10 min)',
    (tester) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
      await tester.tap(_menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
    },
  );

  testWidgets(
    'CA-004-05: durante el arrugado el teclado no llega al menú ni completa la siguiente',
    (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo(),
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
    'CA-004-11: tras eliminar la última, el aviso de foco del lector sale del título "Todo hecho."',
    (tester) async {
      final focusEvents = <int>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message! as Map<Object?, Object?>;
            if (map['type'] == 'focus') focusEvents.add(map['nodeId']! as int);
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
      await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Única'],
        screenReader: true,
      );
      await _delete(tester);
      focusEvents.clear();
      await _crumple(tester);
      final title = tester.getSemantics(find.bySemanticsLabel('Todo hecho.'));
      expect(focusEvents, contains(title.id));
      handle.dispose();
    },
  );
}
