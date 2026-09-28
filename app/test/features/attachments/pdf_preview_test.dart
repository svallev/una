import 'dart:convert';
import 'dart:typed_data';

import 'package:app/features/attachments/pdf_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/pdfrx.dart';

/// La vista previa del editor con el visor de verdad (PDFium). Hallazgos de la
/// revisión de seguridad de T-008-25: la vista previa no sustituía la pantalla
/// de error de pdfrx (texto del error en inglés, con la traza, y un enlace que
/// abre pub.dev en el navegador sin preguntar) y dejaba seleccionar y copiar
/// el texto del PDF (fuera de alcance, spec 008 §8).
void main() {
  setUpAll(initPdfrxForTests);

  /// pdfrx deja temporizadores propios: se desmonta y se dejan correr.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  /// El motor trabaja fuera del reloj falso de los tests.
  Future<void> settle(WidgetTester tester, [int rounds = 100]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpPreview(WidgetTester tester, Uint8List bytes) async {
    tester.view
      ..physicalSize = const Size(390, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ref.watch(pdfPreviewBuilderProvider)((
              path: null,
              bytes: bytes,
              key: 'preview.pdf',
            )),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('CA-008-04 / spec 008 §8: la vista previa no deja seleccionar '
      'ni copiar el texto del PDF', (tester) async {
    await pumpPreview(tester, base64Decode(pdfFixtures['one_page.pdf']!));
    final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
    expect(viewer.params.textSelectionParams?.enabled, isFalse);
    await unmount(tester);
  });

  testWidgets('CA-008-18 / P4: si el PDF de la vista previa no se puede abrir, '
      'no sale la pantalla de error de pdfrx (en inglés y con un enlace a '
      'internet)', (tester) async {
    await pumpPreview(tester, base64Decode(pdfFixtures['html_as.pdf']!));
    final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
    expect(viewer.params.errorBannerBuilder, isNotNull);
    expect(viewer.params.loadingBannerBuilder, isNotNull);
    expect(find.textContaining('errorBannerBuilder'), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);
    await unmount(tester);
  });
}
