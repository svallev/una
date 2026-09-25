import 'package:app/app/web_preview_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('ADR-0010: la web de pruebas avisa de que los datos se borran', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(
      tester,
      const WebPreviewBanner(child: Placeholder()),
      textScale: 2.0,
    );
    expect(
      find.text('Versión de pruebas · los datos se borran al recargar'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
