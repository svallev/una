import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'list_harness.dart';

class _Repo extends InMemoryTaskRepository {
  bool failDelete = false;
  bool failReorder = false;

  @override
  Future<bool> delete(String id, DateTime at) async {
    if (failDelete) throw StateError('disk I/O error');
    return super.delete(id, at);
  }

  @override
  Future<bool> reorder(String id, String rank, DateTime at) async {
    if (failReorder) throw StateError('disk I/O error');
    return super.reorder(id, rank, at);
  }
}

Future<void> _doubleTap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester, String text) async {
  await tester.tap(
    find
        .descendant(
          of: rowOf(text).first,
          matching: find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_UnaIconPainter',
          ),
        )
        .last,
  );
  await tester.pumpAndSettle();
  expect(find.byType(DeleteConfirmSheet), findsOneWidget);
  // Pasada la ventana del doble toque (CL-006-5).
  await tester.pump(UnaMotion.doubleTapWindow);
  await tester.tap(
    find.descendant(
      of: find.byType(DeleteConfirmSheet),
      matching: find.text('Eliminar'),
    ),
  );
  await tester.pump();
  await tester.pump(UnaMotion.sheetOut + frame);
}

Finder _buttonOf(String text, {required bool edit}) => find
    .descendant(
      of: rowOf(text).first,
      matching: find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_UnaIconPainter',
      ),
    )
    .at(edit ? 0 : 1);

void main() {
  group('Editar (CA-006-13)', () {
    testWidgets('el doble toque en la misma fila abre el editor', (
      tester,
    ) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await _doubleTap(tester, find.text('Segunda'));
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets('un solo toque no hace nada', (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(find.text('Segunda'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsNothing);
    });

    testWidgets('CL-006-6: dos toques en filas distintas no editan', (
      tester,
    ) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(find.text('Primera'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Segunda'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsNothing);
    });

    testWidgets('dos toques separados más de 350 ms no editan', (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(find.text('Segunda'));
      await tester.pump(UnaMotion.doubleTapWindow + frame);
      await tester.tap(find.text('Segunda'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsNothing);
    });

    testWidgets(
      'el botón Editar abre el editor y al guardar se vuelve al listado',
      (tester) async {
        final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
        await tester.tap(_buttonOf('Segunda', edit: true));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Segunda editada');
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(find.text('Segunda editada'), findsOneWidget);
        expect(await order(repo), ['Primera', 'Segunda editada']);
      },
    );

    testWidgets('cancelar la edición vuelve al listado sin cambios', (
      tester,
    ) async {
      final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(_buttonOf('Segunda', edit: true));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Otra cosa');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(await order(repo), ['Primera', 'Segunda']);
    });
  });

  group('Eliminar (CA-006-14)', () {
    testWidgets(
      'una intermedia: sin arrugado, la fila desaparece y se anuncia cuántas quedan',
      (tester) async {
        final announcements = listenAnnouncements(tester);
        final repo = await openList(
          tester,
          tasks: ['Primera', 'Segunda', 'Tercera'],
        );
        await _confirmDelete(tester, 'Segunda');
        expect(find.byType(CrumpleOverlay), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(shownOrder(tester), ['Primera', 'Tercera']);
        expect(await order(repo), ['Primera', 'Tercera']);
        expect(announcements, ['Tarea eliminada. Quedan 2']);
      },
    );

    testWidgets('la primera: la siguiente pasa a ser la actual', (
      tester,
    ) async {
      final announcements = listenAnnouncements(tester);
      await openList(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
      await _confirmDelete(tester, 'Primera');
      await tester.pumpAndSettle();
      final rows = tester.widgetList<TaskListRow>(find.byType(TaskListRow));
      expect(rows.first.task.text, 'Segunda');
      expect(rows.first.first, isTrue);
      expect(handleOf('Segunda'), findsNothing);
      expect(announcements, ['Tarea eliminada. Siguiente: Segunda']);
    });

    testWidgets(
      'CL-006-3: la última pendiente lleva a "Todo hecho." y atrás no vuelve al listado',
      (tester) async {
        final announcements = listenAnnouncements(tester);
        await openList(tester, tasks: ['Primera', 'Segunda']);
        await _confirmDelete(tester, 'Segunda');
        await tester.pumpAndSettle();
        // CL-006-2: queda una sola, con sus acciones y "Nueva tarea".
        expect(shownOrder(tester), ['Primera']);
        expect(find.text('Nueva tarea'), findsOneWidget);
        await _confirmDelete(tester, 'Primera');
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsNothing);
        expect(find.byType(AllDoneScreen), findsOneWidget);
        expect(find.byType(CrumpleOverlay), findsNothing);
        expect(announcements.last, 'Tarea eliminada. Todo hecho.');
        expect(await tester.binding.handlePopRoute(), isFalse);
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsNothing);
      },
    );

    testWidgets('cancelar la confirmación vuelve al listado sin cambios', (
      tester,
    ) async {
      final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(_buttonOf('Segunda', edit: false));
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(await order(repo), ['Primera', 'Segunda']);
    });

    testWidgets(
      'CL-006-5: un doble toque sobre Eliminar no activa ni cierra la hoja',
      (tester) async {
        await openList(tester, tasks: ['Primera', 'Segunda']);
        await tester.tap(_buttonOf('Segunda', edit: false));
        await tester.pump(const Duration(milliseconds: 60));
        // El segundo toque cae en el fondo de la hoja mientras sube.
        await tester.tapAt(const Offset(195, 100));
        await tester.pumpAndSettle();
        expect(find.byType(DeleteConfirmSheet), findsOneWidget);
        expect(find.byType(TaskEditorScreen), findsNothing);
      },
    );

    testWidgets('si falla, aviso con "Reintentar" y la fila sigue', (
      tester,
    ) async {
      final repo = _Repo()..failDelete = true;
      await openList(tester, repo: repo, tasks: ['Primera', 'Segunda']);
      await _confirmDelete(tester, 'Segunda');
      await tester.pumpAndSettle();
      expect(find.text('No hemos podido eliminar la tarea'), findsOneWidget);
      expect(shownOrder(tester), ['Primera', 'Segunda']);
      repo.failDelete = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(shownOrder(tester), ['Primera']);
    });
  });

  testWidgets(
    'spec 006 §5: si falla al mover, la fila vuelve y se puede reintentar',
    (tester) async {
      final repo = _Repo()..failReorder = true;
      await openList(
        tester,
        repo: repo,
        tasks: ['Primera', 'Segunda', 'Tercera'],
      );
      await tester.tap(handleOf('Tercera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer actual'));
      await tester.pumpAndSettle();
      expect(find.text('No hemos podido mover la tarea'), findsOneWidget);
      expect(shownOrder(tester), ['Primera', 'Segunda', 'Tercera']);
      repo.failReorder = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(await order(repo), ['Tercera', 'Primera', 'Segunda']);
    },
  );

  group('Crear (CA-006-15)', () {
    Future<void> create(WidgetTester tester, String text, String where) async {
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(where));
      await tester.pump();
      await tester.pump(frame);
    }

    testWidgets('"A la cola" vuelve al listado, baja hasta ella y la resalta', (
      tester,
    ) async {
      final announcements = listenAnnouncements(tester);
      final tasks = [for (var i = 1; i <= 25; i++) 'Tarea $i'];
      final repo = await openList(tester, tasks: tasks);
      await create(tester, 'Nueva al final', 'A la cola');
      await tester.pump(frame);
      // Resaltada: sombra grande al principio del resaltado.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TaskListScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Nueva al final'), findsOneWidget);
      expect(tester.getRect(find.text('Nueva al final')).bottom, lessThan(844));
      expect((await order(repo)).last, 'Nueva al final');
      expect(announcements, ['Tarea añadida en la posición 26 de 26']);
    });

    testWidgets(
      '"Arriba del todo" la deja primera y anuncia que es la actual',
      (tester) async {
        final announcements = listenAnnouncements(tester);
        final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
        await create(tester, 'Urgente', 'Arriba del todo');
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(shownOrder(tester).first, 'Urgente');
        expect((await order(repo)).first, 'Urgente');
        expect(announcements, ['Ahora es la tarea actual']);
      },
    );

    testWidgets('el resaltado dura 0,9 s', (tester) async {
      await openList(tester, tasks: ['Primera', 'Segunda']);
      await create(tester, 'Urgente', 'Arriba del todo');
      await tester.pump(const Duration(milliseconds: 200));
      TaskListRow row() => tester
          .widgetList<TaskListRow>(find.byType(TaskListRow))
          .firstWhere((r) => r.task.text == 'Urgente');
      expect(row().shadow, UnaShadows.listItemFlash);
      await tester.pump(UnaMotion.listFlash);
      await tester.pump(frame);
      expect(row().shadow, UnaShadows.listItem);
    });

    testWidgets('CA-006-19: con reducir movimiento, resaltado fijo', (
      tester,
    ) async {
      await openList(tester, tasks: ['Primera', 'Segunda'], reduced: true);
      await create(tester, 'Urgente', 'Arriba del todo');
      await tester.pump(const Duration(milliseconds: 700));
      TaskListRow row() => tester
          .widgetList<TaskListRow>(find.byType(TaskListRow))
          .firstWhere((r) => r.task.text == 'Urgente');
      expect(row().shadow, UnaShadows.listItemFlash);
      await tester.pumpAndSettle();
      expect(row().shadow, UnaShadows.listItem);
    });

    testWidgets('cancelar el editor vuelve al listado sin guardar', (
      tester,
    ) async {
      final repo = await openList(tester, tasks: ['Primera', 'Segunda']);
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Borrador');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(await order(repo), ['Primera', 'Segunda']);
    });
  });
}
