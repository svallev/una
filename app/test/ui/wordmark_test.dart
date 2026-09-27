import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  // Con el texto al 200 % el logotipo mide más de 48 dp: si su cabecera
  // tuviera un alto fijo de 48, se cortaría por abajo.
  for (final (name, screen) in <(String, Widget)>[
    ('del editor', const TaskEditorScreen(mode: EditorMode.first)),
    ('de "Todo hecho."', AllDoneScreen(onCreate: () {})),
    ('de la bienvenida', WelcomeIntro(onDone: () {})),
  ]) {
    testWidgets('CA-007-23: con el texto al 200 %, el logotipo $name no '
        'se corta', (tester) async {
      await pumpWithApp(tester, screen, textScale: 2);
      await tester.pump(const Duration(seconds: 1));
      final wordmark = find.byType(Wordmark);
      final painter = TextPainter(
        text: TextSpan(
          text: tester
              .widget<Text>(
                find.descendant(of: wordmark, matching: find.byType(Text)),
              )
              .data,
          style: tester
              .widget<Text>(
                find.descendant(of: wordmark, matching: find.byType(Text)),
              )
              .style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2),
      )..layout();
      expect(painter.height, greaterThan(kMinInteractiveDimension));
      expect(
        tester.getSize(wordmark).height,
        greaterThanOrEqualTo(painter.height),
      );
      painter.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
