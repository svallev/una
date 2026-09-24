import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
    'spec 001 §6: con lector de pantalla no avanza sola; se salta con la acción del lector',
    (tester) async {
      final handle = tester.ensureSemantics();
      var done = 0;
      await pumpWithApp(
        tester,
        WelcomeIntro(onDone: () => done++),
        accessibleNavigation: true,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(done, 0);
      final node = tester.getSemantics(find.bySemanticsLabel(_es));
      expect(node, isSemantics(hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel(_es));
      await tester.pump();
      expect(done, 1);
      handle.dispose();
    },
  );

  testWidgets('CL-001-4: avisa de que se ha mostrado nada más aparecer', (
    tester,
  ) async {
    var shown = 0;
    await pumpWithApp(
      tester,
      WelcomeIntro(onDone: () {}, onShown: () => shown++),
    );
    expect(shown, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(shown, 1);
  });

  testWidgets('se puede saltar con Intro', (tester) async {
    var done = 0;
    await pumpWithApp(tester, WelcomeIntro(onDone: () => done++));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('accesibilidad: contraste de la bienvenida', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(
      tester,
      WelcomeIntro(onDone: () {}),
      disableAnimations: true,
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.pump(const Duration(seconds: 2));
    handle.dispose();
  });
}
