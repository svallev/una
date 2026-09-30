import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/sheet_row.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/focus.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

Widget _row({
  String label = 'Política de privacidad',
  String? hint,
  bool enabled = true,
  FocusNode? focusNode,
  GlobalKey? semanticsKey,
}) => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SheetRow(
        icon: UnaIcons.lock,
        label: label,
        hint: hint,
        enabled: enabled,
        focusNode: focusNode,
        semanticsKey: semanticsKey,
        onTap: () {},
      ),
    ],
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'CA-012-13: con el texto al 200 % la fila crece en lugar de cortar el texto',
    (tester) async {
      await pumpWithApp(
        tester,
        Scaffold(body: _row(label: 'Licencias de código abierto')),
        textScale: 2,
        size: const Size(360, 640),
      );
      final height = tester.getSize(find.byType(SheetRow)).height;
      expect(
        height,
        greaterThan(58),
        reason: 'el texto ocupa dos líneas o más',
      );
      expect(tester.takeException(), isNull);
      // El texto cabe dentro de la fila (con su margen vertical).
      final text = tester.getRect(find.text('Licencias de código abierto'));
      final row = tester.getRect(find.byType(SheetRow));
      expect(text.top, greaterThan(row.top));
      expect(text.bottom, lessThan(row.bottom));
    },
  );

  testWidgets('CA-012-13: al 100 % la fila mide 58, como en el menú', (
    tester,
  ) async {
    await pumpWithApp(tester, Scaffold(body: _row()));
    expect(tester.getSize(find.byType(SheetRow)).height, 58);
  });

  testWidgets('CA-012-12: con el foco del teclado la fila muestra su anillo', (
    tester,
  ) async {
    await pumpWithApp(tester, Scaffold(body: _row()));
    expect(await tabUntilRing(tester, 'Política de privacidad'), isTrue);
  });

  testWidgets('CA-012-12: con el tacto, sin anillo', (tester) async {
    await pumpWithApp(tester, Scaffold(body: _row()));
    await tester.tap(find.byType(SheetRow));
    await tester.pump();
    final ring = focusRingOf('Política de privacidad');
    expect(ring, findsOneWidget);
    expect(tester.widget<FocusRing>(ring.first).visible, isFalse);
  });

  testWidgets('CA-012-11: la pista se lee aunque la fila esté activada', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(
      tester,
      Scaffold(body: _row(hint: 'Abre una página web en el navegador')),
    );
    final node = tester.getSemantics(find.byType(SheetRow));
    expect(node.hint, 'Abre una página web en el navegador');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('CA-012-11: sin pista ni desactivada, la fila no lleva ninguna', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, Scaffold(body: _row()));
    expect(tester.getSemantics(find.byType(SheetRow)).hint, isEmpty);
    handle.dispose();
  });

  testWidgets('CA-012-11: la clave semántica es la del nodo de la fila', (
    tester,
  ) async {
    final key = GlobalKey();
    await pumpWithApp(tester, Scaffold(body: _row(semanticsKey: key)));
    expect(key.currentContext, isNotNull);
    expect(
      key.currentContext!.findAncestorWidgetOfExactType<SheetRow>(),
      isNotNull,
    );
  });

  testWidgets('CA-012-12: la fila recibe el foco que se le pide', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpWithApp(tester, Scaffold(body: _row(focusNode: node)));
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });
}
