import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/current_task/image_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// La página de foto que comparten la imagen suelta y el carrusel (T-016-15).
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  var seq = 0;

  setUp(() => store = MemoryAttachmentStore());

  Future<Attachment> photo({int width = 4000, int height = 3000}) =>
      store.commit(
        stageImage(store, 'z${seq++}', width: width, height: height),
        DateTime.utc(2026, 9, 20),
      );

  Future<void> pumpPhoto(
    WidgetTester tester,
    Attachment attachment, {
    ScrollController? scroll,
    bool disableAnimations = false,
  }) async {
    await pumpWithApp(
      tester,
      ZoomablePhoto(attachment: attachment, scroll: scroll),
      disableAnimations: disableAnimations,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    await tester.pump();
  }

  double zoom(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ZoomablePhoto),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getMaxScaleOnAxis();

  /// Separa dos dedos sobre la foto (`spread` px por paso, 10 pasos).
  Future<(TestGesture, TestGesture)> pinch(
    WidgetTester tester, {
    double spread = 6,
    double drift = 0,
  }) async {
    final center = tester.getCenter(find.byType(ZoomablePhoto));
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 31,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 32,
    );
    // Un fotograma con los dos dedos puestos, como en el dispositivo.
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 1; i <= 10; i++) {
      await a.moveBy(Offset(-spread, drift));
      await b.moveBy(Offset(spread, drift));
      await tester.pump(const Duration(milliseconds: 16));
    }
    return (a, b);
  }

  group('CA-007-08: la versión de pantalla sale en el primer fotograma', () {
    testWidgets('a todo el ancho y arriba, sin esperar a nada', (tester) async {
      final a = await photo();
      await pumpWithApp(
        tester,
        ZoomablePhoto(attachment: a),
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      // Un solo fotograma, sin `pump` extra.
      final image = tester.widget<Image>(
        find
            .descendant(
              of: find.byType(ZoomablePhoto),
              matching: find.byType(Image),
            )
            .first,
      );
      expect(image.fit, BoxFit.fitWidth);
      // 4000 × 3000 a 390 de ancho: 292,5 de alto, centrada en vertical.
      expect(
        tester.getRect(
          find
              .descendant(
                of: find.byType(ZoomablePhoto),
                matching: find.byType(Image),
              )
              .first,
        ),
        Rect.fromLTWH(0, (844 - 292.5) / 2, 390, 292.5),
      );
    });

    testWidgets('lleva las teselas encima de la versión de pantalla', (
      tester,
    ) async {
      final a = await photo(width: 9000, height: 3000);
      await pumpPhoto(tester, a);
      expect(
        find.descendant(
          of: find.byType(ZoomablePhoto),
          matching: find.byType(Image),
        ),
        findsNWidgets(1 + a.tiles.rows * a.tiles.columns),
      );
    });
  });

  group('CA-007-09: desplazamiento vertical con su propio controlador', () {
    testWidgets('una foto alta se desplaza en vertical y usa el controlador '
        'recibido', (tester) async {
      final a = await photo(width: 1080, height: 20000);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpPhoto(tester, a, scroll: controller);
      expect(controller.position.pixels, 0);
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(controller.position.pixels, greaterThan(1000));
      expect(controller.position.axis, Axis.vertical);
    });

    testWidgets('un arrastre horizontal no la desplaza', (tester) async {
      final a = await photo(width: 1080, height: 20000);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpPhoto(tester, a, scroll: controller);
      await tester.drag(find.byType(ZoomablePhoto), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(controller.position.pixels, 0);
    });
  });

  group('CA-007-10: el pellizco amplía y vuelve al soltar', () {
    testWidgets('amplía ahí mismo, con tope ×8, y al soltar vuelve al 100 %', (
      tester,
    ) async {
      await pumpPhoto(tester, await photo());
      final (a, b) = await pinch(tester, spread: 60);
      expect(zoom(tester), 8);
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(zoom(tester), greaterThan(1)); // Vuelve con animación.
      await tester.pumpAndSettle();
      expect(zoom(tester), 1);
    });

    testWidgets('el zoom no se conserva: tras soltar y quedar quieta, 1', (
      tester,
    ) async {
      await pumpPhoto(tester, await photo());
      final (a, b) = await pinch(tester);
      expect(zoom(tester), greaterThan(2));
      await a.up();
      await b.up();
      // El primer fotograma arranca la animación; el segundo la acaba.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(zoom(tester), 1);
    });

    testWidgets('CA-007-23: con reducir movimiento vuelve al instante', (
      tester,
    ) async {
      await pumpPhoto(tester, await photo(), disableAnimations: true);
      final (a, b) = await pinch(tester);
      expect(zoom(tester), greaterThan(2));
      await a.up();
      await b.up();
      await tester.pump();
      expect(zoom(tester), 1);
    });

    testWidgets('mientras hay dos dedos no se desplaza, aunque se muevan en '
        'vertical', (tester) async {
      final a = await photo(width: 1080, height: 20000);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpPhoto(tester, a, scroll: controller);
      final (f1, f2) = await pinch(tester, drift: -40);
      expect(controller.position.pixels, 0);
      // Con dos dedos la física no deja desplazar.
      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(ZoomablePhoto),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollable.physics, isA<NeverScrollableScrollPhysics>());
      await f1.up();
      await f2.up();
      await tester.pumpAndSettle();
      expect(controller.position.pixels, 0);
      final after = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(ZoomablePhoto),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(after.physics, isA<ClampingScrollPhysics>());
    });
  });

  group('ImageScroll: el controlador actual es intercambiable', () {
    testWidgets('las acciones siguen al controlador de la foto que se ve', (
      tester,
    ) async {
      final tall = await photo(width: 1080, height: 20000);
      final c1 = ScrollController();
      final c2 = ScrollController();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);
      final scroll = ImageScroll(c1, () => true);
      // Sin clientes no hay nada que desplazar.
      expect(scroll.canForward, isFalse);
      expect(scroll.canBack, isFalse);

      await pumpWithApp(
        tester,
        Column(
          children: [
            Expanded(
              child: ZoomablePhoto(attachment: tall, scroll: c1),
            ),
            Expanded(
              child: ZoomablePhoto(attachment: tall, scroll: c2),
            ),
          ],
        ),
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pump();
      expect(scroll.canForward, isTrue);
      expect(scroll.canBack, isFalse);
      scroll.forward();
      expect(c1.position.pixels, greaterThan(100));
      expect(c2.position.pixels, 0);
      expect(scroll.canBack, isTrue);

      // Se cambia al de la otra foto: lo suyo no ha avanzado.
      scroll.controller = c2;
      expect(scroll.canBack, isFalse);
      expect(scroll.canForward, isTrue);
      scroll.forward();
      expect(c2.position.pixels, greaterThan(100));
      scroll.back();
      expect(c2.position.pixels, 0);
    });
  });
}
