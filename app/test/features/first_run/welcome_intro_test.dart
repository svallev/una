import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const _es = 'Ya puedes crear tu primera tarea';

void main() {
  testWidgets(
    'CA-001-01: el texto se escribe letra a letra y después termina',
    (tester) async {
      var done = 0;
      await pumpWithApp(tester, WelcomeIntro(onDone: () => done++));
      // Se anuncia completo aunque todavía no se vea (spec 001 §6).
      expect(find.bySemanticsLabel(_es), findsOneWidget);
      await tester.pump(WelcomeIntro.startDelay + UnaMotion.introCharStep * 5);
      expect(done, 0);
      await tester.pump(
        UnaMotion.introCharStep * _es.length + WelcomeIntro.pauseAtEnd,
      );
      expect(done, 1);
    },
  );

  testWidgets(
    'CA-001-01 (reducir movimiento): el texto aparece de golpe y termina tras la pausa',
    (tester) async {
      var done = 0;
      await pumpWithApp(
        tester,
        WelcomeIntro(onDone: () => done++),
        disableAnimations: true,
      );
      await tester.pump(WelcomeIntro.pauseAtEnd);
      expect(done, 1);
    },
  );

  testWidgets('se puede saltar con un toque', (tester) async {
    var done = 0;
    await pumpWithApp(tester, WelcomeIntro(onDone: () => done++));
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pump();
    expect(done, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(done, 1, reason: 'no se repite');
  });

  testWidgets('en inglés', (tester) async {
    await pumpWithApp(
      tester,
      WelcomeIntro(onDone: () {}),
      locale: const Locale('en'),
    );
    expect(
      find.bySemanticsLabel('You can now create your first task'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });
}
