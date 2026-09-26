import 'dart:ui' show Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sticky_note.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

class _Repo extends InMemoryTaskRepository {
  bool failInsert = false;

  @override
  Future<void> insert(Task task) async {
    if (failInsert) throw StateError('disk I/O error');
    return super.insert(task);
  }
}

final _menuButton = find.bySemanticsLabel('Menú de la tarea');
final _editorButton = find.byWidgetPredicate(
  (w) => w is BrutalButton && !w.iconOnly,
);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  expect(find.byType(MenuSheet), findsOneWidget);
}

Future<void> _openNewTask(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text('Nueva tarea'));
  await tester.pumpAndSettle();
  expect(find.byType(TaskEditorScreen), findsOneWidget);
}

Color _editorColor(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(TaskEditorScreen),
                        matching: find.descendant(
                          of: find.byType(StickyNote),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color!;

void main() {
  group('Menú (spec 005)', () {
    testWidgets('CA-005-01: el menú muestra "Esta tarea" y el bloque general', (
      tester,
    ) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera', 'Segunda']);
      await _openMenu(tester);
      for (final text in [
        'ESTA TAREA',
        'Editar',
        'Eliminar',
        'Todas mis tareas',
        'Nueva tarea',
        'Configuración y perfil',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets(
      'CA-005-02: se cierra con la X, tocando fuera y con el gesto atrás',
      (tester) async {
        await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
        await _openMenu(tester);
        await tester.tap(find.bySemanticsLabel('Cerrar menú').last);
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsNothing);

        await _openMenu(tester);
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsNothing);

        await _openMenu(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsNothing);
        expect(find.text('Primera'), findsOneWidget);
      },
    );

    testWidgets(
      'CA-005-03: con una sola tarea "Todas mis tareas" está desactivado y lo explica',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(tester, repo: _Repo(), tasks: ['Única']);
        await _openMenu(tester);
        final data = tester
            .getSemantics(find.bySemanticsLabel('Todas mis tareas'))
            .getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hint, 'Solo tienes esta tarea');
        handle.dispose();
      },
    );

    testWidgets(
      'CA-005-12: con varias tareas, el total aparece a la derecha, alineado con "Nueva tarea"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera', 'Segunda', 'Tercera'],
        );
        await _openMenu(tester);
        final count = find.text('3');
        expect(count, findsOneWidget);
        final button = find.ancestor(
          of: find.text('Nueva tarea'),
          matching: find.byType(BrutalButton),
        );
        expect(
          tester.getRect(count).right,
          closeTo(tester.getRect(button).right, 0.5),
        );
        expect(
          find.bySemanticsLabel('Todas mis tareas, 3 tareas'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('CA-005-12: con una sola tarea no se muestra el total', (
      tester,
    ) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Única']);
      await _openMenu(tester);
      expect(find.text('1'), findsNothing);
    });

    testWidgets(
      'CA-005-09: Configuración cierra el menú (Eliminar, spec 004: ver delete_confirm_test)',
      (tester) async {
        await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera', 'Segunda']);
        await _openMenu(tester);
        await tester.tap(find.text('Configuración y perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsNothing);
      },
    );
  });

  group('Nueva tarea (spec 002)', () {
    testWidgets(
      'CA-002-01: editor con Cancelar, "Continuar" y un color distinto del de la tarea actual',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
        await _openNewTask(tester);
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('Continuar'), findsOneWidget);
        expect(
          _editorColor(tester),
          isNot(UnaPalettes.classic[0]),
          reason: 'la tarea actual tiene el color 0',
        );
        expect(
          tester.getSemantics(find.byType(TextField)).label,
          startsWith('Nueva tarea'),
        );
        handle.dispose();
      },
    );

    testWidgets('CA-002-10: "Continuar" sin texto no hace nada', (
      tester,
    ) async {
      await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
      await _openNewTask(tester);
      await tester.tap(_editorButton);
      await tester.pumpAndSettle();
      expect(find.byType(PlacementSheet), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets(
      'CA-002-02/03: "Arriba del todo" la convierte en la tarea actual',
      (tester) async {
        final repo = await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera'],
        );
        await _openNewTask(tester);
        await tester.enterText(find.byType(TextField), 'Urgente');
        await tester.tap(_editorButton);
        await tester.pumpAndSettle();
        expect(find.byType(PlacementSheet), findsOneWidget);
        expect(find.text('¿Dónde la pones?'), findsOneWidget);
        expect(find.text('“Urgente”'), findsOneWidget);
        await tester.tap(find.text('Arriba del todo'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsNothing);
        expect(find.text('Urgente'), findsOneWidget);
        final current = await repo.currentTask();
        expect(current!.text, 'Urgente');
        expect(current.rank.compareTo('MB'), lessThan(0));
        expect(await repo.countPending(), 2);
        expect(Focus.of(tester.element(find.text('Urgente'))).hasFocus, isTrue);
      },
    );

    testWidgets(
      'CA-002-04: "A la cola" la deja al final, sin aviso visible y con anuncio',
      (tester) async {
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
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
        final repo = await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera'],
        );
        await _openNewTask(tester);
        await tester.enterText(find.byType(TextField), 'Luego');
        await tester.tap(_editorButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A la cola'));
        await tester.pumpAndSettle();
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Primera'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect((await repo.currentTask())!.text, 'Primera');
        expect(await repo.countPending(), 2);
        expect(announcements, contains('Tarea añadida a la cola'));
      },
    );

    testWidgets(
      'CA-002-05: "Seguir editando" cierra la hoja y conserva el texto',
      (tester) async {
        await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
        await _openNewTask(tester);
        await tester.enterText(find.byType(TextField), 'Borrador');
        await tester.tap(_editorButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(find.byType(PlacementSheet), findsNothing);
        expect(find.text('Borrador'), findsOneWidget);
      },
    );

    testWidgets(
      'CA-002-07: Cancelar (o el gesto atrás) descarta sin preguntar',
      (tester) async {
        final repo = await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera'],
        );
        await _openNewTask(tester);
        await tester.enterText(find.byType(TextField), 'Descartada');
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsNothing);
        expect(await repo.countPending(), 1);

        await _openNewTask(tester);
        await tester.enterText(find.byType(TextField), 'Otra');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsNothing);
        expect(await repo.countPending(), 1);
      },
    );

    testWidgets('CL-002-4: dos toques rápidos crean una sola tarea', (
      tester,
    ) async {
      final repo = await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
      await _openNewTask(tester);
      await tester.enterText(find.byType(TextField), 'Una vez');
      await tester.tap(_editorButton);
      await tester.pumpAndSettle();
      final top = find.text('Arriba del todo');
      await tester.tap(top);
      await tester.tap(top, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await repo.countPending(), 2);
    });

    testWidgets(
      'spec 002 §5: si falla al guardar se explica y el editor conserva el texto',
      (tester) async {
        final repo = await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera'],
        );
        await _openNewTask(tester);
        repo.failInsert = true;
        await tester.enterText(find.byType(TextField), 'No cabe');
        await tester.tap(_editorButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Arriba del todo'));
        await tester.pumpAndSettle();
        expect(find.text('No hemos podido guardar la tarea'), findsOneWidget);
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('No cabe'), findsOneWidget);
      },
    );
  });

  group('Editar (spec 005)', () {
    testWidgets(
      'CA-005-04/05: editar cambia el texto y conserva posición y color',
      (tester) async {
        final repo = await pumpUnaApp(
          tester,
          repo: _Repo(),
          tasks: ['Primera', 'Segunda'],
        );
        await _openMenu(tester);
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('Guardar cambios'), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'Primera');
        expect(field.controller!.selection.baseOffset, 'Primera'.length);
        expect(_editorColor(tester), UnaPalettes.classic[0]);

        await tester.enterText(find.byType(TextField), 'Primera corregida');
        await tester.tap(_editorButton);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsNothing);
        expect(find.text('Primera corregida'), findsOneWidget);
        final t = (await repo.findById('t0'))!;
        expect(t.text, 'Primera corregida');
        expect(t.rank, 'MB');
        expect(t.colorKey, 0);
      },
    );

    testWidgets('CA-005-06: sin texto "Guardar cambios" no guarda', (
      tester,
    ) async {
      final repo = await pumpUnaApp(tester, repo: _Repo(), tasks: ['Primera']);
      await _openMenu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(_editorButton);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect((await repo.findById('t0'))!.text, 'Primera');
    });
  });
}
