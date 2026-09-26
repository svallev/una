import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// "Guardar" (el otro botón grande es el "+" de adjuntar).
final _saveFinder = find.byWidgetPredicate(
  (w) => w is BrutalButton && !w.iconOnly,
);
BrutalButton _save(WidgetTester t) => t.widget<BrutalButton>(_saveFinder);

void main() {
  testWidgets(
    'CA-001-02: como el prototipo: sin etiqueta visible, placeholder, «+» y Guardar activos, sin Cancelar',
    (tester) async {
      await pumpWithApp(tester, const TaskEditorScreen());
      // La etiqueta del prototipo está oculta: solo nombra el campo (§6).
      expect(find.text('TU PRIMERA TAREA'), findsNothing);
      expect(
        find.bySemanticsLabel('Añadir foto, imagen o archivo'),
        findsOneWidget,
      );
      expect(
        find.text('¿Qué es eso que tienes que hacer y no has hecho?'),
        findsOneWidget,
      );
      expect(find.text('Guardar'), findsOneWidget);
      expect(_save(tester).onPressed, isNotNull);
      expect(_save(tester).trailingIcon, isNotNull, reason: 'flecha →');
      expect(find.text('Cancelar'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    },
  );

  testWidgets(
    'CL-001-1: con solo espacios, Guardar no guarda y devuelve el foco al campo',
    (tester) async {
      final repo = await pumpWithApp(tester, const TaskEditorScreen());
      await tester.enterText(find.byType(TextField), '   \n  ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(_saveFinder);
      await tester.pumpAndSettle();
      expect(await repo.currentTask(), isNull);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'CA-001-04: guardar crea la tarea pendiente (recortada) como actual',
    (tester) async {
      final repo = await pumpWithApp(tester, const TaskEditorScreen());
      await tester.enterText(find.byType(TextField), '  Llamar a Marta  ');
      await tester.pump();
      expect(_save(tester).onPressed, isNotNull);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final current = await repo.currentTask();
      expect(current?.text, 'Llamar a Marta');
    },
  );

  testWidgets('CL-001-2: el contador aparece a partir de 9000 caracteres', (
    tester,
  ) async {
    await pumpWithApp(tester, const TaskEditorScreen());
    await tester.enterText(find.byType(TextField), 'a' * 8999);
    await tester.pump();
    expect(find.textContaining('caracteres'), findsNothing);
    await tester.enterText(find.byType(TextField), 'a' * 9999);
    await tester.pump();
    expect(find.text('Queda 1 carácter'), findsOneWidget);
  });

  testWidgets(
    'CA-001-02 + §6: el campo se anuncia como «Tu primera tarea» y no hay menú',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(tester, const TaskEditorScreen());
      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(
          // La etiqueta y, detrás, el placeholder como pista.
          label: 'Tu primera tarea\n¿Qué es eso que tienes que hacer y no has hecho?',
          isTextField: true,
          isFocusable: true,
          isEnabled: true,
          hasEnabledState: true,
          isMultiline: true,
          hasTapAction: true,
          hasFocusAction: true,
          maxValueLength: 10000,
          currentValueLength: 0,
        ),
      );
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      handle.dispose();
    },
  );

  for (final (error, message) in [
    (StateError('disk I/O error'), 'No hemos podido guardar la tarea'),
    (
      StateError('SqliteException(13): database or disk is full'),
      'Tu teléfono no tiene espacio libre',
    ),
  ]) {
    testWidgets(
      'spec 001 §5: si falla al guardar se explica, se conserva el texto y se puede reintentar ($message)',
      (tester) async {
        final repo = _FailingRepository(error);
        await pumpWithApp(tester, const TaskEditorScreen(), repo: repo);
        await tester.enterText(find.byType(TextField), 'Llamar a Marta');
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);

        repo.fail = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect((await repo.currentTask())?.text, 'Llamar a Marta');
      },
    );
  }

  testWidgets(
    'CL-001-9: al 200 % con el teclado abierto no se corta nada y es accesible',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(
        tester,
        const TaskEditorScreen(),
        textScale: 2.0,
        size: const Size(360, 640),
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Llamar a Marta');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  testWidgets('CA-001-02: el botón Guardar se ve entero, con su margen', (
    tester,
  ) async {
    await pumpWithApp(tester, const TaskEditorScreen());
    final button = tester.getRect(_saveFinder);
    expect(button.bottom, lessThanOrEqualTo(844 - 24 + 0.01));
  });
}

class _FailingRepository extends InMemoryTaskRepository {
  _FailingRepository(this.error);
  final Object error;
  bool fail = true;

  @override
  Future<void> insert(Task task) async {
    if (fail) throw error;
    return super.insert(task);
  }
}
