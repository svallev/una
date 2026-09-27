import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<Color> _ringColors(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(FocusRing),
      matching: find.byType(DecoratedBox),
    ),
  ))
    ((box.decoration as BoxDecoration).border! as Border).top.color,
];

void main() {
  for (final inside in [false, true]) {
    testWidgets('spec 007 §6 / WCAG 1.4.11: el anillo es negro con borde '
        'blanco, para verse sobre una foto oscura (inside: $inside)', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: FocusRing(
              visible: true,
              inside: inside,
              child: const SizedBox.square(dimension: 48),
            ),
          ),
        ),
      );
      expect(_ringColors(tester), [UnaColors.surface, UnaColors.ink]);
      // El blanco queda por fuera del negro.
      final rects = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .map((p) => p.left!)
          .toList();
      expect(rects.first, lessThan(rects.last));
    });
  }

  testWidgets('oculto, no dibuja nada', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: FocusRing(
            visible: false,
            child: SizedBox.square(dimension: 48),
          ),
        ),
      ),
    );
    expect(_ringColors(tester), isEmpty);
  });
}
