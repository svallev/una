import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

BrutalButton _save(WidgetTester t) =>
    t.widget<BrutalButton>(find.byType(BrutalButton));

void main() {
  testWidgets(
    'CA-001-02: etiqueta, placeholder, Guardar deshabilitado y sin Cancelar',
    (tester) async {
      await pumpWithApp(tester, const FirstTaskEditorScreen());
      expect(find.text('TU PRIMERA TAREA'), findsOneWidget);
      expect(
        find.text('¿Qué es eso que tienes que hacer y no has hecho?'),
        findsOneWidget,
      );
      expect(find.text('Guardar'), findsOneWidget);
      expect(_save(tester).onPressed, isNull);
      expect(find.text('Cancelar'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    },
  );

  testWidgets('CL-001-1: solo espacios no habilita Guardar', (tester) async {
    await pumpWithApp(tester, const FirstTaskEditorScreen());
    await tester.enterText(find.byType(TextField), '   \n  ');
    await tester.pump();
    expect(_save(tester).onPressed, isNull);
  });

  testWidgets(
    'CA-001-04: guardar crea la tarea pendiente (recortada) como actual',
    (tester) async {
      final repo = await pumpWithApp(tester, const FirstTaskEditorScreen());
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
    await pumpWithApp(tester, const FirstTaskEditorScreen());
    await tester.enterText(find.byType(TextField), 'a' * 8999);
    await tester.pump();
    expect(find.textContaining('caracteres'), findsNothing);
    await tester.enterText(find.byType(TextField), 'a' * 9999);
    await tester.pump();
    expect(find.text('Queda 1 carácter'), findsOneWidget);
  });
}
