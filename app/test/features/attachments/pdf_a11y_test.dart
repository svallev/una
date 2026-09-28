import 'dart:convert';

import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/attachments.dart';
import '../../support/pdfrx.dart';

void main() {
  setUpAll(initPdfrxForTests);

  /// pdfrx deja temporizadores propios: se desmonta y se dejan correr.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<List<LinkTarget>> pumpPdf(WidgetTester tester, String name) async {
    final links = <LinkTarget>[];
    tester.view
      ..physicalSize = const Size(390, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskPdfView(
          args: TaskPdfArgs(
            source: (
              path: null,
              bytes: base64Decode(pdfFixtures[name]!),
              key: name,
            ),
            screen: MemoryImage(tinyImage),
            captionColor: const Color(0xFFFFE55C),
            initialPosition: PdfPosition.start,
            onPosition: (_) {},
            onLink: links.add,
          ),
        ),
      ),
    );
    // El motor carga el documento, el texto y los enlaces fuera del reloj
    // falso de los tests.
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    return links;
  }

  testWidgets('CA-008-20: cada página se lee "Página n de total" y su texto', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPdf(tester, 'pages_20.pdf');
    expect(
      find.bySemanticsLabel(RegExp(r'^Página 1 de 20\. Pagina 1 de 20')),
      findsOneWidget,
    );
    // No queda la etiqueta inglesa del visor.
    expect(find.bySemanticsLabel(RegExp(r'^Page \d')), findsNothing);
    await unmount(tester);
    handle.dispose();
  });

  testWidgets('CA-008-12/20: los enlaces que hacen algo se leen y se activan; '
      'los peligrosos no aparecen', (tester) async {
    final handle = tester.ensureSemantics();
    final links = await pumpPdf(tester, 'links.pdf');
    // Exactamente estos: ni los peligrosos (javascript:, file:, intent:,
    // data:, lanzar) ni el de usuario:contraseña (T-5). example.com sale dos
    // veces: el normal y el que lleva un carácter de dirección en el camino.
    final linkLabels = find.semantics
        .byPredicate((n) => n.label.startsWith('Enlace a '))
        .evaluate()
        .map((n) => n.label)
        .toList();
    expect(linkLabels, [
      'Enlace a example.com',
      'Enlace a example.org',
      'Enlace a info@example.com',
      'Enlace a +34600000000',
      'Enlace a example.com',
      'Enlace a xn--pple-43d.com',
      'Enlace a la página 2',
    ]);

    tester.semantics.tap(find.semantics.byLabel('Enlace a example.com').first);
    await tester.pump();
    expect(links.single, isA<WebLink>());
    expect((links.single as WebLink).host, 'example.com');
    await unmount(tester);
    handle.dispose();
  });
  testWidgets('CA-008-12: los enlaces no se marcan sobre la página '
      '(decisión del propietario, 2026-09-28)', (tester) async {
    await pumpPdf(tester, 'links.pdf');
    final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
    expect(viewer.params.linkHandlerParams?.linkColor, Colors.transparent);
    await unmount(tester);
  });

  testWidgets('CA-008-12: un enlace tocado con el dedo llega a la app (la '
      'capa de lectura no se queda los toques)', (tester) async {
    final handle = tester.ensureSemantics();
    final links = await pumpPdf(tester, 'links.pdf');
    final c = tester.getCenter(find.bySemanticsLabel('Enlace a example.org'));
    await tester.tapAt(c);
    // El visor espera por si es un doble toque.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    expect(links.single, isA<WebLink>());
    expect((links.single as WebLink).host, 'example.org');
    await unmount(tester);
    handle.dispose();
  });
}
