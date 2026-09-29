import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/task_list/list_harness.dart' show FakeClock;
import '../support/app_harness.dart';
import '../support/l10n_leaks.dart' show semanticsTexts;

/// Cambio de idioma del sistema con la app abierta, sin adjuntos (spec 010,
/// T-010-07). La actividad no se recrea (`configChanges` con `locale`): la app
/// recibe el cambio como un nuevo `platformDispatcher.locales`.
///
/// Textos de tarea neutros (ni ES ni EN) para que no se confundan con la
/// interfaz.
const _tasks = ['Zxq 1', 'Zxq 2', 'Zxq 3'];

AppLocalizations _l10n(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

/// Idioma con el que se ha construido la pantalla actual.
AppLocalizations _current(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Cambia el idioma del sistema (como al volver de Ajustes) y deja asentar.
Future<void> _switchTo(WidgetTester tester, List<Locale> locales) async {
  tester.platformDispatcher.localesTestValue = locales;
  await tester.pumpAndSettle();
}

/// Sale de la app, cambia el idioma del sistema mientras está fuera y vuelve
/// tras [away] (Ajustes → volver, CA-010-06 / CA-001-12).
Future<void> _leaveAndReturn(
  WidgetTester tester,
  FakeClock clock, {
  required List<Locale> locales,
  required Duration away,
}) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  tester.platformDispatcher.localesTestValue = locales;
  clock.value = clock.value.add(away);
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

void main() {
  // Los dos sentidos: ES → EN y EN → ES.
  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CA-010-06 ($from → $to): cambio de idioma en caliente', () {
      testWidgets('la tarea actual sigue y el resto de la app cambia', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text(_tasks.first), findsOneWidget);
        expect(find.bySemanticsLabel(before.menuButton), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text(_tasks.first), findsOneWidget);
        expect(find.text(_tasks[1]), findsNothing);
        expect(find.bySemanticsLabel(after.menuButton), findsOneWidget);
        expect(find.bySemanticsLabel(before.menuButton), findsNothing);
        expect(
          find.bySemanticsLabel(after.currentTaskSemantics(_tasks.first)),
          findsOneWidget,
        );
      });

      testWidgets('el editor conserva el texto que se estaba escribiendo', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
        );
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        await tester.enterText(find.byType(EditableText), 'Zxq borrador');
        await tester.pump();
        expect(find.text(before.editorSaveFirst), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('Zxq borrador'), findsOneWidget);
        expect(find.text(after.editorSaveFirst), findsOneWidget);
        expect(find.text(before.editorSaveFirst), findsNothing);
        // El campo sigue enfocado y sin perder el texto.
        final field = tester.widget<EditableText>(find.byType(EditableText));
        expect(field.controller.text, 'Zxq borrador');
        expect(field.focusNode.hasFocus, isTrue);
      });

      testWidgets(
        'el editor de una tarea existente conserva el texto editado',
        (tester) async {
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(
            tester,
            repo: repo,
            locale: Locale(from),
            tasks: _tasks,
          );
          await tester.tap(find.bySemanticsLabel(before.menuButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(before.menuEdit));
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          await tester.enterText(find.byType(EditableText), 'Zxq editada');
          await tester.pump();

          await _switchTo(tester, [Locale(to)]);

          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(find.text('Zxq editada'), findsOneWidget);
          expect(find.text(after.editorSaveChanges), findsOneWidget);
          // Nada se ha guardado por el camino.
          expect((await repo.currentTask())!.text, _tasks.first);
        },
      );

      testWidgets('el menú abierto sigue abierto, en el idioma nuevo', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        final semantics = tester.ensureSemantics();
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsOneWidget);
        expect(find.text(before.menuEdit), findsOneWidget);
        expect(find.text(before.menuAllTasks), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(MenuSheet), findsOneWidget);
        expect(find.text(after.menuEdit), findsOneWidget);
        expect(find.text(after.menuAllTasks), findsOneWidget);
        // El recuento solo se lee (semántica, junto a "Todas mis tareas"), con
        // el plural del idioma nuevo.
        final reads = semanticsTexts(tester).join('\n');
        expect(reads, contains(after.menuAllTasksCount(_tasks.length)));
        expect(reads, isNot(contains(before.menuAllTasksCount(_tasks.length))));
        // Sigue en la misma tarea.
        expect(find.text(_tasks.first), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('la hoja de eliminar abierta sigue abierta y no elimina', (
        tester,
      ) async {
        final repo = InMemoryTaskRepository();
        await pumpUnaApp(
          tester,
          repo: repo,
          locale: Locale(from),
          tasks: _tasks,
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuDelete));
        await tester.pumpAndSettle();
        expect(find.byType(DeleteConfirmSheet), findsOneWidget);
        expect(find.text(before.deleteTitle), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(DeleteConfirmSheet), findsOneWidget);
        expect(find.text(after.deleteTitle), findsOneWidget);
        expect(find.text(before.deleteTitle), findsNothing);
        expect(find.text(after.deleteBody(_tasks.first)), findsOneWidget);
        expect((await repo.pendingTasks()).length, _tasks.length);
      });

      testWidgets('el listado abierto sigue abierto, con sus filas', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuAllTasks));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(find.text(before.listTitle), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(find.text(after.listTitle), findsOneWidget);
        expect(find.text(before.listTitle), findsNothing);
        for (final t in _tasks) {
          expect(find.text(t), findsOneWidget);
        }
      });

      testWidgets(
        'vuelta en menos de 10 minutos: se conserva lo que había, en el idioma nuevo',
        (tester) async {
          final clock = FakeClock();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            locale: Locale(from),
            clock: clock,
          );
          await tester.enterText(find.byType(EditableText), 'Zxq borrador');
          await tester.pump();

          await _leaveAndReturn(
            tester,
            clock,
            locales: [Locale(to)],
            away: UnaApp.resetAfter - const Duration(seconds: 1),
          );

          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(find.text('Zxq borrador'), findsOneWidget);
          expect(find.text(after.editorSaveFirst), findsOneWidget);
        },
      );

      testWidgets(
        'CA-001-12: vuelta en 10 minutos o más, se descarta el editor y la app ya está en el idioma nuevo',
        (tester) async {
          final clock = FakeClock();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            locale: Locale(from),
            clock: clock,
            tasks: _tasks,
          );
          // Editor con texto a medias, sobre la tarea actual.
          await tester.tap(find.bySemanticsLabel(before.menuButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(before.menuEdit));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(EditableText), 'Zxq borrador');
          await tester.pump();
          expect(find.byType(TaskEditorScreen), findsOneWidget);

          await _leaveAndReturn(
            tester,
            clock,
            locales: [Locale(to)],
            away: UnaApp.resetAfter,
          );

          expect(find.byType(TaskEditorScreen), findsNothing);
          expect(find.text('Zxq borrador'), findsNothing);
          expect(find.byType(CurrentTaskScreen), findsOneWidget);
          expect(find.text(_tasks.first), findsOneWidget);
          expect(find.bySemanticsLabel(after.menuButton), findsOneWidget);
          expect(find.bySemanticsLabel(before.menuButton), findsNothing);
          expect(_current(tester).localeName, to);
        },
      );
    });
  }

  group('CL-010-4: idioma de derecha a izquierda', () {
    for (final from in ['es', 'en']) {
      testWidgets(
        'CA-010-06: $from → ar: la app pasa a inglés, de izquierda a derecha, sin perder el estado',
        (tester) async {
          final en = _l10n('en');
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(
            tester,
            repo: repo,
            locale: Locale(from),
            tasks: _tasks,
          );
          await tester.tap(find.bySemanticsLabel(_l10n(from).menuButton));
          await tester.pumpAndSettle();
          expect(find.byType(MenuSheet), findsOneWidget);

          await _switchTo(tester, const [Locale('ar')]);

          expect(_current(tester).localeName, 'en');
          expect(find.byType(MenuSheet), findsOneWidget);
          expect(find.text(en.menuEdit), findsOneWidget);
          expect(find.text(_tasks.first), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(MenuSheet))),
            TextDirection.ltr,
          );
          expect(
            Directionality.of(tester.element(find.byType(CurrentTaskScreen))),
            TextDirection.ltr,
          );
        },
      );
    }

    testWidgets(
      'CA-010-06: ar → es con el editor a medias: pasa a español y conserva el texto',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: const Locale('ar'),
        );
        expect(_current(tester).localeName, 'en');
        await tester.enterText(find.byType(EditableText), 'Zxq borrador');
        await tester.pump();

        await _switchTo(tester, const [Locale('es')]);

        expect(_current(tester).localeName, 'es');
        expect(find.text('Zxq borrador'), findsOneWidget);
        expect(find.text(_l10n('es').editorSaveFirst), findsOneWidget);
      },
    );

    testWidgets(
      'CA-010-06: he → [ca, es-ES]: se usa el primer idioma admitido de la lista',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: const Locale('he'),
          tasks: _tasks,
        );
        expect(_current(tester).localeName, 'en');

        await _switchTo(tester, const [Locale('ca'), Locale('es', 'ES')]);

        expect(_current(tester).localeName, 'es');
        expect(find.text(_tasks.first), findsOneWidget);
      },
    );
  });
}
