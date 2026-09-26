import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

final _menuButton = find.bySemanticsLabel('Menú de la tarea');

Future<void> _openConfirm(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pumpAndSettle();
  expect(find.byType(DeleteConfirmSheet), findsOneWidget);
}

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is BrutalButton && w.label == label);

void main() {
  group('Confirmación (spec 004)', () {
    testWidgets(
      'CA-004-01: menú → Eliminar cierra el menú y abre "¿Eliminar esta tarea?" con el texto de la tarea',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Llamar a Marta', 'Segunda'],
        );
        await _openConfirm(tester);
        expect(find.byType(MenuSheet), findsNothing);
        expect(find.text('¿Eliminar esta tarea?'), findsOneWidget);
        expect(
          find.text('“Llamar a Marta” desaparecerá sin marcarse como hecha.'),
          findsOneWidget,
        );
        final confirm = tester.widget<BrutalButton>(_button('Eliminar'));
        expect(confirm.background, const Color(0xFFFF5A4E));
        expect(tester.widget<BrutalButton>(_button('Cancelar')).ghost, isTrue);
      },
    );

    testWidgets(
      'CA-004-01 / DEV-23: un texto largo se recorta a 3 líneas y el lector lo lee entero',
      (tester) async {
        final handle = tester.ensureSemantics();
        final long = 'Revisar ' * 60;
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: [long.trim()],
        );
        await _openConfirm(tester);
        final body = tester.widget<Text>(
          find.textContaining('desaparecerá sin marcarse'),
        );
        expect(body.maxLines, 3);
        expect(body.overflow, TextOverflow.ellipsis);
        expect(
          find.bySemanticsLabel(
            '“${long.trim()}” desaparecerá sin marcarse como hecha.',
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('Cancelar', (t) => t.tap(find.text('Cancelar'))),
      ('tocar fuera', (t) => t.tapAt(const Offset(195, 60))),
      ('gesto atrás', (t) => t.binding.handlePopRoute()),
      (
        'deslizar hacia abajo (DEV-21)',
        (t) => t.fling(
          find.text('¿Eliminar esta tarea?'),
          const Offset(0, 400),
          1500,
        ),
      ),
      ('Esc', (t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
    ]) {
      testWidgets(
        'CA-004-02: $name no cambia nada y vuelve a la tarea (no al menú)',
        (tester) async {
          final repo = await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            tasks: ['Primera', 'Segunda'],
          );
          await _openConfirm(tester);
          await close(tester);
          await tester.pumpAndSettle();
          expect(find.byType(DeleteConfirmSheet), findsNothing);
          expect(find.byType(MenuSheet), findsNothing);
          expect(await repo.countPending(), 2);
          expect((await repo.currentTask())!.text, 'Primera');
        },
      );
    }

    testWidgets('CA-004-10: el foco empieza en "Cancelar", la acción segura', (
      tester,
    ) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera'],
      );
      await _openConfirm(tester);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        focused.findAncestorWidgetOfExactType<BrutalButton>()?.label,
        'Cancelar',
      );
      // Intro sobre el foco inicial cancela, no elimina.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsNothing);
      expect(find.text('Primera'), findsOneWidget);
    });

    testWidgets(
      'CA-004-10: la acción accesible "Eliminar tarea" abre la confirmación y no elimina',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
          screenReader: true,
        );
        tester.semantics.customAction(
          find.semantics.byLabel('Tarea actual: Primera'),
          const CustomSemanticsAction(label: 'Eliminar tarea'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DeleteConfirmSheet), findsOneWidget);
        expect(await repo.countPending(), 1);
        handle.dispose();
      },
    );

    testWidgets(
      'CL-004-1: una doble pulsación rápida en "Eliminar" elimina una sola vez',
      (tester) async {
        final repo = await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda', 'Tercera'],
        );
        await _openConfirm(tester);
        await tester.tap(_button('Eliminar'));
        await tester.tap(_button('Eliminar'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(await repo.countPending(), 2);
        expect((await repo.currentTask())!.text, 'Segunda');
      },
    );

    testWidgets(
      'CL-004-4: con texto al 200 % la hoja se desplaza y los botones siguen alcanzables',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Llamar a Marta para confirmar la cena del sábado'],
        );
        await _openConfirm(tester);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_button('Cancelar'));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(_button('Cancelar')).height,
          greaterThanOrEqualTo(44),
        );
        expect(
          tester.getSize(_button('Eliminar')).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(_button('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(DeleteConfirmSheet), findsNothing);
      },
    );

    for (final reduced in [false, true]) {
      testWidgets(
        'CA-004-10: el aviso de foco del lector sale del botón "Cancelar"${reduced ? ' (reducir movimiento)' : ''}',
        (tester) async {
          final focusEvents = <int>[];
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                (message) async {
                  final map = message! as Map<Object?, Object?>;
                  if (map['type'] == 'focus') {
                    focusEvents.add(map['nodeId']! as int);
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
          final handle = tester.ensureSemantics();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            tasks: ['Primera'],
            screenReader: true,
            reduced: reduced,
          );
          await _openConfirm(tester);
          final cancel = tester.getSemantics(
            find.descendant(
              of: find.byType(DeleteConfirmSheet),
              matching: find.bySemanticsLabel('Cancelar'),
            ),
          );
          expect(focusEvents, contains(cancel.id));
          handle.dispose();
        },
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'P6: la hoja cumple contraste y objetivos táctiles (texto ×$scale)',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final handle = tester.ensureSemantics();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            tasks: ['Llamar a Marta'],
          );
          await _openConfirm(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );
    }

    testWidgets(
      'CA-004-02: al cancelar con teclado, el foco vuelve a la tarea',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
        );
        await _openConfirm(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          focused.findAncestorWidgetOfExactType<CurrentTaskScreen>(),
          isNotNull,
        );
        expect(focused.findAncestorWidgetOfExactType<BrutalButton>(), isNull);
      },
    );

    testWidgets(
      'CA-004-10: con TalkBack, "Cancelar" es lo primero de la hoja (TalkBack enfoca el primer elemento de la ruta)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
          screenReader: true,
        );
        await _openConfirm(tester);
        final labelled = tester.semantics
            .simulatedAccessibilityTraversal()
            .where((n) => n.label.isNotEmpty)
            .map((n) => n.label)
            .toList();
        expect(labelled.take(4), [
          'Cancelar',
          '¿Eliminar esta tarea?',
          '“Primera” desaparecerá sin marcarse como hecha.',
          'Eliminar',
        ]);
        handle.dispose();
      },
    );
  });
}
