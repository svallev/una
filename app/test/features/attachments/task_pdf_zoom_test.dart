import 'dart:convert';

import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/attachments.dart';
import '../../support/pdfrx.dart';

void main() {
  setUpAll(initPdfrxForTests);

  testWidgets('el visor de verdad se construye sin errores (T-008-14: un fallo '
      'así dejaba la pantalla en blanco sin avisar)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskPdfView(
          args: TaskPdfArgs(
            source: (
              path: null,
              bytes: base64Decode(pdfFixtures['one_page.pdf']!),
              key: 'k',
            ),
            screen: MemoryImage(tinyImage),
            caption: 'Programa',
            captionColor: const Color(0xFFFFE55C),
            initialPosition: PdfPosition.start,
            onPosition: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(PdfViewer), findsOneWidget);
    // Primer fotograma: la banda y la versión de pantalla, sin esperar al motor.
    expect(find.text('Programa'), findsOneWidget);
  });

  test('CA-008-10: los pasos de "Ampliar" van de ×1 a ×4 y ahí se paran', () {
    expect(pdfZoomLevels, [1.0, 1.5, 2.5, 4.0]);
    expect(zoomInStep(1), 1.5);
    expect(zoomInStep(1.5), 2.5);
    expect(zoomInStep(2.5), 4);
    expect(zoomInStep(4), isNull);
    // Tras un pellizco a ×2, el siguiente paso es ×2,5.
    expect(zoomInStep(2), 2.5);
  });

  test(
    'CA-008-10: los pasos de "Reducir" bajan hasta el ancho (×1), no más',
    () {
      expect(zoomOutStep(4), 2.5);
      expect(zoomOutStep(2.5), 1.5);
      expect(zoomOutStep(1.5), 1);
      expect(zoomOutStep(1), isNull);
      expect(zoomOutStep(3.2), 2.5);
      // Casi en el ancho (redondeo) cuenta como ×1.
      expect(zoomOutStep(1.005), isNull);
    },
  );
}
