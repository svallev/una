import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

double _fontSizeOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  testWidgets(
    'CA-001-06: muestra solo la tarea actual, el menú y el botón de completar',
    (tester) async {
      await pumpWithApp(tester, CurrentTaskScreen(task: sampleTask()));
      expect(find.text('Llamar a Marta'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tarea actual: Llamar a Marta'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
      expect(find.text('Mantén pulsado para completar'), findsOneWidget);
    },
  );

  testWidgets('CA-001-07: el tamaño del texto depende de su longitud', (
    tester,
  ) async {
    final cases = {
      'a' * 39: UnaFontSizes.noteXL,
      'a' * 40: UnaFontSizes.noteL,
      'a' * 90: UnaFontSizes.noteM,
      'a' * 160: UnaFontSizes.noteS,
    };
    for (final e in cases.entries) {
      await pumpWithApp(
        tester,
        CurrentTaskScreen(task: sampleTask(text: e.key)),
      );
      expect(
        _fontSizeOf(tester, e.key),
        e.value,
        reason: '${e.key.length} caracteres',
      );
    }
  });

  testWidgets('CL-001-9: con texto al 200 % no hay desbordamientos', (
    tester,
  ) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: sampleTask(text: 'Tarea larga ' * 60)),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('accesibilidad: objetivos táctiles y contraste (spec 001 §6)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, CurrentTaskScreen(task: sampleTask()));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
