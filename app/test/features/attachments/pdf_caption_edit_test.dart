import 'dart:convert';

import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pdfrx.dart';

const _short = 'Programa del congreso';
const _long =
    'Revisar el programa del congreso de otoño en Valencia, confirmar la '
    'sala, avisar a los ponentes y reservar el hotel para tres noches';

/// Fallo visto en el emulador (T-008-24): al editar el texto de una tarea con
/// PDF y alargarlo, al volver la parte de arriba de la banda quedaba por
/// encima de la vista (bajo la franja negra). pdfrx, al cambiar el hueco de la
/// banda, conservaba la posición relativa a la página 1, que había bajado.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initPdfrxForTests();
  });

  /// pdfrx deja temporizadores propios: se desmonta y se dejan correr.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  /// El motor trabaja fuera del reloj falso de los tests.
  Future<void> settle(WidgetTester tester, [int rounds = 60]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// El visor con el texto de [caption]; devuelve las posiciones avisadas y,
  /// al desmontarlo, la que se guarda (`onLeave`).
  Future<List<PdfPosition>> pumpPdf(
    WidgetTester tester,
    ValueNotifier<String> caption, {
    PdfPosition initial = PdfPosition.start,
  }) async {
    final positions = <PdfPosition>[];
    tester.view
      ..physicalSize = const Size(390, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bytes = base64Decode(pdfFixtures['pages_20.pdf']!);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<String>(
          valueListenable: caption,
          builder: (context, text, _) => TaskPdfView(
            args: TaskPdfArgs(
              source: (path: null, bytes: bytes, key: 'pages_20.pdf'),
              screen: MemoryImage(tinyImage),
              caption: text,
              captionColor: const Color(0xFFFFE55C),
              initialPosition: initial,
              onPosition: positions.add,
              onLeave: positions.add,
            ),
          ),
        ),
      ),
    );
    await settle(tester, 200);
    return positions;
  }

  /// La banda se ve entera, arriba del todo de la vista.
  void expectBandAtTop(WidgetTester tester, String text) {
    final band = tester.getRect(find.byType(PdfCaptionBand).last);
    expect(band.top, moreOrLessEquals(0, epsilon: 0.5), reason: '$band');
    final expected = PdfCaptionBand.heightFor(
      text,
      390,
      PdfCaptionBand.scalerOf(tester.element(find.text(text).last)),
      TextDirection.ltr,
    );
    expect(band.height, moreOrLessEquals(expected, epsilon: 0.5));
  }

  for (final (from, to, what) in [
    (_short, _long, 'se alarga'),
    (_long, _short, 'se acorta'),
  ]) {
    testWidgets('CA-008-08 / CA-008-06: al principio del PDF, si el texto '
        '$what, la banda se ve entera arriba del todo', (tester) async {
      final caption = ValueNotifier(from);
      addTearDown(caption.dispose);
      final positions = await pumpPdf(tester, caption);
      expectBandAtTop(tester, from);

      caption.value = to;
      await settle(tester);
      expect(tester.takeException(), isNull);
      expectBandAtTop(tester, to);
      // Sigue al principio: la posición que se guarda no cambia.
      await unmount(tester);
      expect(positions, everyElement(PdfPosition.start));
    });

    testWidgets('CA-008-09 / CA-008-06: a media lectura, si el texto $what, '
        'las páginas no saltan', (tester) async {
      const at = PdfPosition(page: 3, offset: 0.25);
      final caption = ValueNotifier(from);
      addTearDown(caption.dispose);
      final positions = await pumpPdf(tester, caption, initial: at);

      caption.value = to;
      await settle(tester);
      expect(tester.takeException(), isNull);
      // La que se guarda al dejar de verlo: la misma.
      await unmount(tester);
      expect(positions.last.page, at.page);
      expect(positions.last.offset, moreOrLessEquals(at.offset, epsilon: .01));
    });
  }
}
