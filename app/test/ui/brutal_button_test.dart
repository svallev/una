import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:flutter/services.dart';
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
}
