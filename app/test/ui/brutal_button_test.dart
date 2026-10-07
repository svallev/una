import 'dart:ui' show Tristate;

import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Opacity;
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'accesibilidad (WCAG 2.1.1 / 2.4.7): se llega con Tab, se ve el foco y se activa con Intro o Espacio',
    (tester) async {
      var pressed = 0;
      await pumpWithApp(
        tester,
        BrutalButton(label: 'Guardar', onPressed: () => pressed++),
      );
      FocusRing ring() => tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring().visible, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring().visible, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, 2);
    },
  );

  testWidgets('deshabilitado: no recibe el foco ni se activa', (tester) async {
    await pumpWithApp(
      tester,
      const BrutalButton(label: 'Guardar', onPressed: null),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isFalse);
  });

  testWidgets(
    'CA-016-04: con semanticsEnabled false el lector lo anuncia como no '
    'disponible y sin activar, pero se ve y se pulsa igual',
    (tester) async {
      final handle = tester.ensureSemantics();
      var pressed = 0;
      await pumpWithApp(
        tester,
        BrutalButton(
          label: 'Continuar',
          semanticsEnabled: false,
          onPressed: () => pressed++,
        ),
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Continuar'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      // Se ve activo (DEV-17) y el toque llega a su acción.
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await tester.tap(find.text('Continuar'));
      expect(pressed, 1);
      handle.dispose();
    },
  );

  testWidgets(
    'CA-012-15: la pista (hint) llega al lector en el mismo nodo del botón',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(
        tester,
        BrutalButton(label: 'Reintentar', hint: 'Falló', onPressed: () {}),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Reintentar'));
      expect(node.hint, 'Falló');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    },
  );
}
