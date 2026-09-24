import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('spec 001 §6: orden de lectura tarea → menú → completar', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, CurrentTaskScreen(task: sampleTask()));
    final labels = tester.semantics
        .simulatedAccessibilityTraversal()
        .map((n) => n.label)
        .where((l) => l.isNotEmpty)
        .toList();
    expect(labels, [
      'Tarea actual: Llamar a Marta',
      'Menú de la tarea',
      'Mantén pulsado para completar',
    ]);
    handle.dispose();
  });

  testWidgets(
    'CA-001-07: la escala de texto del sistema se aplica con un límite de ×1,6',
    (tester) async {
      for (final (scale, expected) in [(1.3, 1.3), (2.0, 1.6)]) {
        await pumpWithApp(
          tester,
          CurrentTaskScreen(task: sampleTask()),
          textScale: scale,
        );
        final p = tester.renderObject<RenderParagraph>(
          find.text('Llamar a Marta'),
        );
        expect(p.textScaler.scale(10), closeTo(10 * expected, 0.001));
      }
    },
  );

  testWidgets('CA-001-07: si no cabe, la nota se desplaza verticalmente', (
    tester,
  ) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: sampleTask(text: 'palabra ' * 400)),
    );
    expect(tester.takeException(), isNull);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets(
    'CL-001-3: emojis, RTL, CJK y una URL larga sin espacios no desbordan',
    (tester) async {
      for (final text in [
        'https://example.com/${'a' * 300}?q=${'b' * 100}',
        'Comprar 🍞🥛🧀 y 🎂 para 👨‍👩‍👧‍👦',
        'اتصل بمارتا غدا صباحا',
        '明日の朝にマルタに電話する',
      ]) {
        await pumpWithApp(
          tester,
          CurrentTaskScreen(task: sampleTask(text: text)),
        );
        expect(tester.takeException(), isNull, reason: text);
        expect(
          tester.getRect(find.text(text)).right,
          lessThanOrEqualTo(390),
          reason: text,
        );
      }
    },
  );
}
