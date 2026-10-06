import 'dart:ui' show Tristate;

import 'package:app/ui/una_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-20f: el nodo del enlace refleja el foco de teclado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(
      tester,
      Scaffold(
        body: Center(
          child: UnaLinkButton(
            label: 'Ajustes',
            onPressed: () {},
            focusNode: focus,
          ),
        ),
      ),
    );
    SemanticsData data() =>
        tester.getSemantics(find.byType(UnaLinkButton)).getSemanticsData();
    expect(data().flagsCollection.isFocused, isNot(Tristate.isTrue));

    focus.requestFocus();
    await tester.pump();
    expect(data().flagsCollection.isFocused, Tristate.isTrue);
    handle.dispose();
  });
}
