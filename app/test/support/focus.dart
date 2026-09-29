import 'package:app/ui/focus_ring.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// El anillo de foco del control cuyo nodo semántico se llama [label].
Finder focusRingOf(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
  matching: find.byType(FocusRing),
);

/// Pulsa Tab (como con un teclado físico) hasta que el control [label]
/// muestra su anillo de foco (WCAG 2.4.7). False si no llega a verse tras
/// [maxTabs] pulsaciones.
Future<bool> tabUntilRing(
  WidgetTester tester,
  String label, {
  int maxTabs = 20,
}) async {
  final ring = focusRingOf(label);
  for (var i = 0; i < maxTabs; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (ring.evaluate().isNotEmpty &&
        tester.widget<FocusRing>(ring.first).visible) {
      return true;
    }
  }
  return false;
}
