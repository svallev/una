import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

Widget _button({
  FocusNode? focusNode,
  GlobalKey? semanticsKey,
  bool autofocus = false,
  VoidCallback? onPressed,
}) => Scaffold(
  body: Center(
    child: SquareIconButton(
      icon: UnaIcons.close,
      label: 'Cerrar ajustes',
      fill: UnaColors.paper,
      onPressed: onPressed ?? () {},
      focusNode: focusNode,
      semanticsKey: semanticsKey,
      autofocus: autofocus,
    ),
  ),
);

void main() {
  testWidgets('CA-015-21: el botón admite su FocusNode, para dárselo desde '
      'fuera (el botón de menú al volver)', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _button(focusNode: focus));
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('CA-015-21: con autofocus pide el foco al montarse (Cerrar o '
      'Volver con teclado físico)', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _button(focusNode: focus, autofocus: true));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('CA-015-21: sin autofocus no toma el foco', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _button(focusNode: focus));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('CA-015-20: la clave marca el nodo accesible del botón, para su '
      'aviso de foco', (tester) async {
    final handle = tester.ensureSemantics();
    final key = GlobalKey();
    await pumpWithApp(tester, _button(semanticsKey: key));
    expect(key.currentContext!.findRenderObject(), isNotNull);
    final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
    expect(data.label, 'Cerrar ajustes');
    handle.dispose();
  });
}
