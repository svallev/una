import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';

const _long = 'programa-oficial.congreso-internacional-de-ejemplo.example.com';

final _style = UnaTheme.mono.copyWith(
  fontSize: UnaFontSizes.micro,
  color: UnaColors.onInk,
);

Future<void> _pumpBar(
  WidgetTester tester,
  String host, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = Size(width, 200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 200),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topCenter,
          child: WebBar(host: host, badge: 'WEB'),
        ),
      ),
    ),
  );
}

String _shown(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(HeadEllipsisText),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  setUpAll(loadAppFonts);

  group('CA-009-06: barra del prototipo', () {
    testWidgets('negra, con el candado, el dominio y "WEB"', (tester) async {
      await _pumpBar(tester, 'congreso.ejemplo.com');
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == UnaColors.ink,
        ),
        findsOneWidget,
      );
      final lock = tester.widget<UnaIcon>(find.byType(UnaIcon));
      expect(lock.icon, UnaIcons.lock);
      expect(lock.size, UnaSizes.webBarIcon);
      expect(lock.color, UnaColors.onInk);
      expect(_shown(tester), 'congreso.ejemplo.com');
      expect(find.text('WEB'), findsOneWidget);
      // Candado a la izquierda, "WEB" a la derecha.
      expect(
        tester.getRect(find.byType(UnaIcon)).left,
        lessThan(tester.getRect(find.byType(HeadEllipsisText)).left),
      );
      expect(
        tester.getRect(find.text('WEB')).left,
        greaterThan(tester.getRect(find.byType(HeadEllipsisText)).right - 1),
      );
    });

    testWidgets('CA-009-18: decorativa para el lector (la lee la tarea)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpBar(tester, 'congreso.ejemplo.com');
      expect(find.bySemanticsLabel(RegExp('congreso')), findsNothing);
      expect(find.bySemanticsLabel('WEB'), findsNothing);
      handle.dispose();
    });
  });

  group('CA-009-14: dominio recortado por el principio', () {
    testWidgets('si cabe, entero y sin "…"', (tester) async {
      await _pumpBar(tester, 'ejemplo.com');
      expect(_shown(tester), 'ejemplo.com');
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('si no cabe (360 dp, texto al ${scale * 100} %), "…" y '
          'el final del dominio, sin desbordar', (tester) async {
        await _pumpBar(tester, _long, width: 360, textScale: scale);
        final shown = _shown(tester);
        expect(shown, startsWith(headEllipsisMark));
        expect(shown.length, lessThan(_long.length));
        expect(_long, endsWith(shown.substring(1)));
        expect(tester.takeException(), isNull);
        // "WEB" sigue entero dentro de la pantalla.
        expect(tester.getRect(find.text('WEB')).right, lessThanOrEqualTo(360));
      });
    }

    test('headEllipsis: el final más largo que cabe', () {
      const width = 120.0;
      final shown = headEllipsis(_long, style: _style, maxWidth: width);
      expect(shown, startsWith(headEllipsisMark));
      double measure(String s) {
        final p = TextPainter(
          text: TextSpan(text: s, style: _style),
          textDirection: TextDirection.ltr,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      expect(measure(shown), lessThanOrEqualTo(width));
      // Con un carácter más ya no cabría.
      final tail = shown.substring(1);
      final longer =
          headEllipsisMark + _long.substring(_long.length - tail.length - 1);
      expect(measure(longer), greaterThan(width));
    });

    test('headEllipsis: no parte un carácter de dos unidades', () {
      const host = 'ejemplo.𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳𝒳.com';
      for (var width = 20.0; width < 200; width += 7) {
        final shown = headEllipsis(host, style: _style, maxWidth: width);
        // Sin sustitutos sueltos: se puede codificar en UTF-8 y volver.
        expect(shown.runes.every((r) => r < 0xD800 || r > 0xDFFF), isTrue);
      }
    });
  });
}
