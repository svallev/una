import 'dart:convert';
import 'dart:typed_data';

import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pdfrx.dart';
import '../../support/pump_app.dart';

/// Arranque en frío con un PDF en una página intermedia (CA-008-08): la
/// página se ve desde el primer fotograma y no se queda en blanco al entrar
/// el visor (T-008-22, fallo visto en el Xiaomi y en el emulador).
void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initPdfrxForTests();
  });

  final pages20 = base64Decode(pdfFixtures['pages_20.pdf']!);
  const saved = PdfPosition(page: 5, offset: 0.5);

  /// Desmonta el visor y deja pasar los temporizadores de pdfrx.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('CA-008-08: en frío, el primer fotograma ya pinta la versión de '
      'pantalla en la posición guardada (sin zona en blanco)', (tester) async {
    final store = MemoryAttachmentStore()
      ..putStaging('p1', 'document.pdf', pages20)
      ..putStaging('p1', 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      const StagedPdf(
        id: 'p1',
        byteSize: 4000,
        pageCount: 20,
        width: 595,
        height: 842,
        originalName: 'Programa.pdf',
      ),
      DateTime.utc(2026, 9, 28),
    );
    await store.writePosition('p1', saved);
    final base = sampleTask(text: 'Programa');
    final repo = InMemoryTaskRepository();
    await repo.insert(base.withContent('Programa', attachment, base.updatedAt));
    await repo.setFirstRunDone();

    Future<ImageServices> images() async => (
      store: store,
      images: MemoryAttachmentImages(store),
      importer: const UnavailableImageImporter(),
      pdfImporter: const UnavailablePdfImporter(),
    );

    await tester.runAsync(
      () => bootstrap(
        open: () async => (tasks: repo, settings: repo),
        openImages: images,
      ),
    );
    // Primer fotograma.
    await tester.pump();

    final face = find.byType(TaskPdfFace);
    expect(face, findsOneWidget);
    final raw = tester.widget<RawImage>(
      find.descendant(of: face, matching: find.byType(RawImage)),
    );
    expect(raw.image, isNotNull, reason: 'la imagen ya decodificada');
    expect(tester.widget<TaskPdfFace>(face).args.initialPosition, saved);

    await unmount(tester);
  });

  testWidgets('CA-008-08: la versión de pantalla se pinta arriba del todo: ya '
      'es lo que se ve desde la posición guardada', (tester) async {
    final screen = MemoryImage(tinyImage);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 700,
            child: TaskPdfFace(
              args: TaskPdfArgs(
                source: (path: null, bytes: null, key: 'k'),
                screen: screen,
                caption: 'Programa',
                captionColor: const Color(0xFFFFE55C),
                initialPosition: saved,
                onPosition: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(screen, tester.element(find.byType(TaskPdfFace))),
    );
    await tester.pump();
    final image = find.byType(RawImage);
    expect(tester.getSize(image).height, greaterThan(0));
    expect(tester.getTopLeft(image), Offset.zero);
    // Sin la banda: no se empieza por arriba.
    expect(find.text('Programa'), findsNothing);
  });

  testWidgets('CA-008-08: la versión de pantalla no se quita hasta que el '
      'visor ha dibujado las páginas que se ven (no se ve en blanco)', (
    tester,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 390,
              height: 700,
              child: TaskPdfView(
                args: TaskPdfArgs(
                  source: (path: null, bytes: pages20, key: 'k'),
                  screen: MemoryImage(tinyImage),
                  captionColor: const Color(0xFFFFE55C),
                  initialPosition: saved,
                  onPosition: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    var handedOver = false;
    for (var i = 0; i < 300 && !handedOver; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(TaskPdfFace).evaluate().isNotEmpty) continue;
      handedOver = true;
      // En cuanto se quita, lo que se ve es el visor con las páginas ya
      // dibujadas: la parte de arriba de la página 6 (su texto) está a la
      // vista, no un rectángulo blanco con el borde.
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rows = await tester.runAsync(() async {
        final image = await render.toImage();
        final data = await image.toByteData();
        final out = _textRows(data!, image.width, image.height);
        image.dispose();
        return out;
      });
      expect(
        rows,
        greaterThan(0),
        reason: 'páginas en blanco al quitar la cara',
      );
    }
    expect(handedOver, isTrue, reason: 'el visor nunca sustituyó a la cara');

    await unmount(tester);
  });
}

/// Filas con algo de tinta pero no de lado a lado (texto, no el borde entre
/// páginas ni la versión de pantalla, que es un bloque de color).
int _textRows(ByteData rgba, int width, int height) {
  var rows = 0;
  for (var y = 0; y < height; y++) {
    var ink = 0;
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final r = rgba.getUint8(i);
      final g = rgba.getUint8(i + 1);
      final b = rgba.getUint8(i + 2);
      if (r < 200 && g < 200 && b < 200) ink++;
    }
    if (ink > 0 && ink < width * 0.9) rows++;
  }
  return rows;
}
