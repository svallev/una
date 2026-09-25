import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import '../../support/pump_app.dart';

double _fontSizeOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  // Fuentes reales: con la de pruebas cada letra mide 1 em y las medidas de
  // ancho (palabras, una sola línea) no serían representativas.
  setUpAll(loadAppFonts);

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
      expect(find.text('Pulsa para completar'), findsOneWidget);
    },
  );

  testWidgets('CA-001-07: el tamaño del texto depende de su longitud', (
    tester,
  ) async {
    // Palabras cortas: el tamaño solo depende de la longitud total.
    String words(int n) => ('abc ' * n).substring(0, n);
    final cases = {
      words(39): UnaFontSizes.noteXL,
      words(40): UnaFontSizes.noteL,
      words(90): UnaFontSizes.noteM,
      words(160): UnaFontSizes.noteS,
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
      'Pulsa para completar',
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

  for (final (locale, label) in [
    (const Locale('es'), 'Pulsa para completar'),
    (const Locale('en'), 'Press to complete'),
  ]) {
    testWidgets(
      'CA-001-06: «$label» ocupa una sola línea, también al 200 % en un móvil estrecho',
      (tester) async {
        for (final (scale, size) in [
          (1.0, const Size(390, 844)),
          (2.0, const Size(320, 640)),
        ]) {
          await pumpWithApp(
            tester,
            CurrentTaskScreen(task: sampleTask()),
            locale: locale,
            textScale: scale,
            size: size,
          );
          expect(tester.takeException(), isNull);
          final text = find.text(label);
          expect(text, findsOneWidget);
          final p = tester.renderObject<RenderParagraph>(text);
          expect(
            p
                .getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: label.length),
                )
                .map((b) => b.top)
                .toSet(),
            hasLength(1),
            reason: 'escala $scale',
          );
          expect(
            tester.getRect(text).right,
            lessThanOrEqualTo(size.width),
            reason: 'escala $scale: no se corta',
          );
        }
      },
    );
  }

  testWidgets(
    'CA-001-07: con texto grande no se parte ninguna palabra (se reduce lo justo)',
    (tester) async {
      const text = 'Llamar a Marta para confirmar la cena';
      for (final (scale, width) in [(1.0, 320.0), (2.0, 390.0), (2.0, 320.0)]) {
        await pumpWithApp(
          tester,
          CurrentTaskScreen(task: sampleTask(text: text)),
          textScale: scale,
          size: Size(width, 844),
        );
        final p = tester.renderObject<RenderParagraph>(find.text(text));
        var start = 0;
        for (final word in text.split(' ')) {
          final boxes = p.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + word.length),
          );
          expect(
            boxes.map((b) => b.top).toSet(),
            hasLength(1),
            reason: '«$word» partida (escala $scale, ancho $width)',
          );
          start += word.length + 1;
        }
      }
    },
  );
}
