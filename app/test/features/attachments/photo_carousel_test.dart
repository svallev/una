// Movimiento del carrusel de fotos (T-016-16a; CA-016-08, 09, 10, 22 y
// CL-016-4, 5, 10): infinito, foto actual + vecina hacia la que se arrastra,
// transición de 280 ms, un desplazamiento por foto vista, caché de las
// contiguas y "Foto no disponible" en su sitio. Sobre un anfitrión de test, sin
// la pantalla principal (pie y puntos son de T-016-16b).
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/attachment_health.dart';
import 'package:app/features/attachments/group_health.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Un dedo con su propio reloj: cada paso avanza el tiempo, que es lo que lee
/// el cálculo de la velocidad del gesto.
class _Finger {
  _Finger(this.gesture);
  final TestGesture gesture;
  Duration clock = Duration.zero;

  Future<void> move(Offset total, {int steps = 20, int ms = 320}) async {
    final step = total / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      clock += Duration(microseconds: ms * 1000 ~/ steps);
      await gesture.moveBy(step, timeStamp: clock);
    }
  }

  Future<void> up() => gesture.up(timeStamp: clock);
}

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late PhotoCarouselController controller;
  var seq = 0;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    controller = PhotoCarouselController();
    addTearDown(controller.dispose);
  });

  /// [n] fotos guardadas (`c0`, `c1`…) con bytes **distintos** en cada
  /// versión de pantalla: la caché de imágenes las distingue por identidad.
  Future<List<Attachment>> photos(
    int n, {
    int width = 4000,
    int height = 3000,
  }) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'c${base + i}';
      all.add(
        await store.commit(
          stageImage(store, id, width: width, height: height),
          DateTime.utc(2026, 9, 20),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  Future<void> pumpCarousel(
    WidgetTester tester,
    List<Attachment> photos, {
    bool disableAnimations = false,
    PhotoCarouselController? ctl,
  }) async {
    await pumpWithApp(
      tester,
      SizedBox.expand(
        child: PhotoCarousel(photos: photos, controller: ctl ?? controller),
      ),
      disableAnimations: disableAnimations,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
  }

  Future<_Finger> down(
    WidgetTester tester, {
    Offset? at,
    int pointer = 1,
  }) async => _Finger(
    await tester.startGesture(at ?? const Offset(300, 400), pointer: pointer),
  );

  /// Swipe horizontal de [dx] dp (negativo = a la izquierda) en 320 ms.
  Future<void> swipe(
    WidgetTester tester,
    double dx, {
    int ms = 320,
    Offset? at,
  }) async {
    final f = await down(tester, at: at ?? Offset(dx < 0 ? 330 : 60, 400));
    await f.move(Offset(dx, 0), ms: ms);
    await f.up();
  }

  /// Termina la transición (280 ms) y todo lo que arrastre.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Los ids de las fotos montadas, en el orden del árbol.
  List<String> mounted(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ];

  Finder photoOf(String id) => find.byWidgetPredicate(
    (w) => w is ZoomablePhoto && w.attachment.id == id,
  );

  double leftOf(WidgetTester tester, String id) =>
      tester.getTopLeft(photoOf(id)).dx;

  group('CA-016-09: carrusel infinito con swipe', () {
    testWidgets('a la izquierda es la siguiente y a la derecha la anterior', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      expect(controller.index, 0);
      expect(mounted(tester), [all[0].id]);

      await swipe(tester, -200);
      await settle(tester);
      expect(controller.index, 1);
      expect(mounted(tester), [all[1].id]);

      await swipe(tester, 200);
      await settle(tester);
      expect(controller.index, 0);
      expect(mounted(tester), [all[0].id]);
    });

    testWidgets('es infinito: tras la última, la primera; antes de la '
        'primera, la última', (tester) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);

      await swipe(tester, 200);
      await settle(tester);
      expect(controller.index, 2, reason: 'antes de la primera, la última');
      expect(mounted(tester), [all[2].id]);

      await swipe(tester, -200);
      await settle(tester);
      expect(controller.index, 0, reason: 'tras la última, la primera');
      expect(mounted(tester), [all[0].id]);
    });

    testWidgets('CL-016-4: con 2 fotos la vecina es siempre la otra', (
      tester,
    ) async {
      final all = await photos(2);
      await pumpCarousel(tester, all);

      // Arrastrando a la izquierda se ve la otra a la derecha...
      var f = await down(tester, at: const Offset(330, 400));
      await f.move(const Offset(-120, 0), ms: 200);
      await tester.pump();
      expect(mounted(tester).toSet(), {all[0].id, all[1].id});
      expect(leftOf(tester, all[1].id), greaterThan(0));
      await f.up();
      await settle(tester);
      expect(controller.index, 1);

      // ...y arrastrando a la derecha, la misma, a la izquierda.
      f = await down(tester, at: const Offset(60, 400));
      await f.move(const Offset(120, 0), ms: 200);
      await tester.pump();
      expect(mounted(tester).toSet(), {all[0].id, all[1].id});
      expect(leftOf(tester, all[0].id), lessThan(0));
      await f.up();
      await settle(tester);
      expect(controller.index, 0);

      // Con 2 fotos también da la vuelta en los dos sentidos.
      controller.next();
      await settle(tester);
      controller.next();
      await settle(tester);
      expect(controller.index, 0);
      controller.previous();
      await settle(tester);
      expect(controller.index, 1);
    });

    testWidgets('CA-016-08: con 1 y con 10 fotos se monta una sola en el '
        'primer fotograma', (tester) async {
      for (final n in [1, 10]) {
        final all = await photos(n);
        await pumpCarousel(tester, all, ctl: PhotoCarouselController());
        expect(find.byType(ZoomablePhoto), findsOneWidget, reason: '$n fotos');
        expect(mounted(tester), [all[0].id]);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('con una sola foto el swipe no hace nada', (tester) async {
      final all = await photos(1);
      await pumpCarousel(tester, all);
      await swipe(tester, -250);
      await settle(tester);
      expect(controller.index, 0);
      expect(mounted(tester), [all[0].id]);
      expect(leftOf(tester, all[0].id), 0);
    });

    testWidgets('un arrastre vertical desplaza la foto alta y no cambia', (
      tester,
    ) async {
      final all = await photos(3, width: 1080, height: 20000);
      await pumpCarousel(tester, all);
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(controller.scroll.position.pixels, greaterThan(300));
      expect(mounted(tester), [all[0].id]);
    });

    testWidgets('el controlador expone la foto actual y su desplazamiento', (
      tester,
    ) async {
      final all = await photos(3, width: 1080, height: 20000);
      final seen = <int>[];
      controller.addListener(() => seen.add(controller.index));
      await pumpCarousel(tester, all);
      expect(controller.scroll.hasClients, isTrue);
      final first = controller.scroll;
      controller.next();
      await settle(tester);
      expect(seen, [1]);
      expect(controller.scroll, isNot(same(first)));
      expect(controller.scroll.hasClients, isTrue);
      controller.previous();
      await settle(tester);
      expect(seen, [1, 0]);
      expect(controller.scroll, same(first));
    });
  });

  group('CA-016-09: la transición dura 280 ms', () {
    testWidgets('el cambio se anima hasta los 280 ms y la vecina entra', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      final f = await down(tester, at: const Offset(330, 400));
      await f.move(const Offset(-200, 0));
      await f.up();
      await tester.pump(); // arranca el AnimationController
      await tester.pump(const Duration(milliseconds: 140));
      // A mitad: aún no ha cambiado el índice y la siguiente está entrando.
      expect(controller.index, 0);
      expect(mounted(tester).toSet(), {all[0].id, all[1].id});
      final x = leftOf(tester, all[1].id);
      expect(x, greaterThan(0));
      expect(x, lessThan(390));
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.index, 1);
      expect(mounted(tester), [all[1].id]);
      expect(leftOf(tester, all[1].id), 0);
    });

    testWidgets('si no llega al umbral, vuelve animada y no cambia', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      final f = await down(tester, at: const Offset(330, 400));
      // 40 dp en 320 ms: ni el 18 % ni 700 dp/s.
      await f.move(const Offset(-40, 0));
      await tester.pump();
      expect(leftOf(tester, all[0].id), lessThan(-20));
      await f.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Sigue volviendo: no es instantáneo.
      final x = leftOf(tester, all[0].id);
      expect(x, lessThan(0));
      expect(x, greaterThan(-40));
      expect(mounted(tester).toSet(), {all[0].id, all[1].id});
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.index, 0);
      expect(mounted(tester), [all[0].id]);
      expect(leftOf(tester, all[0].id), 0);
    });

    testWidgets('un segundo dedo cancela el swipe y la foto vuelve a su '
        'sitio', (tester) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      final f = await down(tester, at: const Offset(330, 400));
      await f.move(const Offset(-100, 0), ms: 200);
      await tester.pump();
      expect(leftOf(tester, all[0].id), lessThan(-50));
      final second = await down(tester, at: const Offset(200, 400), pointer: 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Vuelve con transición (sin reducir movimiento).
      final x = leftOf(tester, all[0].id);
      expect(x, lessThan(0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(leftOf(tester, all[0].id), 0);
      await second.up();
      await f.up();
      await settle(tester);
      expect(controller.index, 0);
    });

    testWidgets('CA-016-22: con reducir movimiento todo es instantáneo, '
        'también el regreso y el cancelado', (tester) async {
      final all = await photos(3);
      await pumpCarousel(tester, all, disableAnimations: true);

      // Cambio.
      await swipe(tester, -200);
      await tester.pump();
      expect(controller.index, 1);
      expect(mounted(tester), [all[1].id]);
      expect(leftOf(tester, all[1].id), 0);

      // Regreso: no llega al umbral.
      final f = await down(tester, at: const Offset(330, 400));
      await f.move(const Offset(-40, 0));
      await f.up();
      await tester.pump();
      expect(controller.index, 1);
      expect(mounted(tester), [all[1].id]);
      expect(leftOf(tester, all[1].id), 0);

      // Cancelado con el segundo dedo.
      final g = await down(tester, at: const Offset(330, 400), pointer: 3);
      await g.move(const Offset(-100, 0), ms: 200);
      final second = await down(tester, at: const Offset(200, 400), pointer: 4);
      await tester.pump();
      expect(mounted(tester), [all[1].id]);
      expect(leftOf(tester, all[1].id), 0);
      await second.up();
      await g.up();
      await tester.pump();

      // "Foto siguiente" y "Foto anterior" (acciones del lector).
      controller.next();
      await tester.pump();
      expect(controller.index, 2);
      expect(mounted(tester), [all[2].id]);
      controller.previous();
      await tester.pump();
      expect(controller.index, 1);
    });

    testWidgets('sin reducir movimiento, "Foto siguiente" también anima', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.index, 0);
      expect(mounted(tester).toSet(), {all[0].id, all[1].id});
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.index, 1);
      expect(mounted(tester), [all[1].id]);
    });

    testWidgets('un segundo cambio durante la transición termina el primero '
        'y se suma', (tester) async {
      final all = await photos(4);
      await pumpCarousel(tester, all);
      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.next();
      await settle(tester);
      expect(controller.index, 2);
      expect(mounted(tester), [all[2].id]);
    });
  });

  group('CA-016-10: cada foto, como la imagen única', () {
    testWidgets('cada foto conserva su desplazamiento y una sin ver empieza '
        'arriba', (tester) async {
      final all = await photos(3, width: 1080, height: 20000);
      await pumpCarousel(tester, all);

      // La primera, desplazada.
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -500));
      await tester.pumpAndSettle();
      final first = controller.scroll.position.pixels;
      expect(first, greaterThan(300));

      // La segunda no se ha visto: empieza arriba. Se desplaza otro tanto.
      controller.next();
      await settle(tester);
      expect(controller.scroll.position.pixels, 0);
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -300));
      await tester.pumpAndSettle();
      final second = controller.scroll.position.pixels;
      expect(second, greaterThan(150));
      expect(second, isNot(first));

      // La tercera, sin ver: arriba.
      controller.next();
      await settle(tester);
      expect(controller.scroll.position.pixels, 0);

      // De vuelta: cada una donde la dejó.
      controller.previous();
      await settle(tester);
      expect(controller.scroll.position.pixels, second);
      controller.previous();
      await settle(tester);
      expect(controller.scroll.position.pixels, first);
    });

    testWidgets('el zoom no se conserva al cambiar de foto', (tester) async {
      final all = await photos(3);
      await pumpCarousel(tester, all);
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 11,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 12,
      );
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      double zoom() => tester
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
      expect(zoom(), greaterThan(2));
      await a.up();
      await b.up();
      // Cambia de foto con el zoom aún volviendo y regresa.
      controller.next();
      await settle(tester);
      controller.previous();
      await settle(tester);
      expect(controller.index, 0);
      expect(zoom(), 1);
    });

    testWidgets('CL-016-5: una foto muy alta y una panorámica, cada una a su '
        'ancho y empezando arriba', (tester) async {
      final tall = (await photos(1, width: 1080, height: 20000)).single;
      final wide = (await photos(1, width: 6000, height: 1000)).single;
      await pumpCarousel(tester, [tall, wide]);
      final tallImage = find.descendant(
        of: photoOf(tall.id),
        matching: find.byType(Image),
      );
      expect(tester.getSize(tallImage.first).width, 390);
      expect(tester.getSize(tallImage.first).height, greaterThan(844));
      controller.next();
      await settle(tester);
      final wideImage = find.descendant(
        of: photoOf(wide.id),
        matching: find.byType(Image),
      );
      expect(tester.getSize(wideImage.first), const Size(390, 65));
      expect(controller.scroll.position.pixels, 0);
    });
  });

  group('CA-016-23: las contiguas se calientan en la caché', () {
    ImageCache cache() => PaintingBinding.instance.imageCache;

    bool cached(String id) {
      final key = MemoryImage(store.bytes('attachments/$id/screen.jpg')!);
      final status = cache().statusForKey(key);
      return status.keepAlive || status.live;
    }

    Future<void> warm(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    testWidgets('la anterior y la siguiente, sin hacer falta verlas', (
      tester,
    ) async {
      final all = await photos(6);
      await pumpCarousel(tester, all);
      await tester.pump(); // el fotograma tras el primero
      await warm(tester);
      expect(cached(all[0].id), isTrue);
      expect(cached(all[1].id), isTrue, reason: 'la siguiente');
      expect(cached(all[5].id), isTrue, reason: 'la anterior (infinito)');
      expect(cached(all[3].id), isFalse);
    });

    testWidgets('como mucho 3 versiones de pantalla decodificadas al '
        'recorrerlas', (tester) async {
      final all = await photos(6);
      await pumpCarousel(tester, all);
      for (var i = 0; i < 6; i++) {
        controller.next();
        await settle(tester);
        await warm(tester);
        final n = all.where((a) => cached(a.id)).length;
        expect(n, lessThanOrEqualTo(3), reason: 'tras ${i + 1} cambios');
        expect(cached(all[controller.index].id), isTrue);
      }
    });
  });

  group('CA-016-18a / CA-016-23: foto que falta y regeneración', () {
    testWidgets('una foto que falta se ve como "Foto no disponible" en su '
        'sitio y las demás, normales', (tester) async {
      final all = await photos(3);
      store.removeFile(all[1].id, 'full-0-0.jpg');
      await pumpCarousel(tester, all);
      await tester.pump();
      await tester.pump();
      expect(find.byType(PhotoMissingBox), findsNothing);

      controller.next();
      await settle(tester);
      expect(controller.index, 1);
      expect(find.byType(PhotoMissingBox), findsOneWidget);
      expect(find.text('Foto no disponible'), findsOneWidget);
      expect(find.byType(ZoomablePhoto), findsNothing);

      controller.next();
      await settle(tester);
      expect(find.byType(PhotoMissingBox), findsNothing);
      expect(mounted(tester), [all[2].id]);
    });

    testWidgets('mientras se arrastra, la que falta ocupa su lado', (
      tester,
    ) async {
      final all = await photos(3);
      store.removeFile(all[1].id, 'full-0-0.jpg');
      await pumpCarousel(tester, all);
      await tester.pump();
      await tester.pump();
      final f = await down(tester, at: const Offset(330, 400));
      await f.move(const Offset(-120, 0), ms: 200);
      await tester.pump();
      expect(find.byType(PhotoMissingBox), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(PhotoMissingBox)).dx,
        greaterThan(0),
      );
      await f.up();
      await settle(tester);
    });

    testWidgets('una foto que no se pudo regenerar avisa a la salud del '
        'grupo (reportMissing) y se ve "Foto no disponible"', (tester) async {
      final all = await photos(3);
      store.removeFile(all[1].id, 'screen.jpg');
      importer.regenerateErrorsById[all[1].id] = const FormatException('rota');
      await pumpCarousel(tester, all);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhotoCarousel)),
      );
      final key = AttachmentGroupKey(all);
      // `check` solo ve que faltan derivadas: lo avisa el carrusel.
      expect(container.read(groupHealthProvider(key)).missingIds, {all[1].id});
      expect(
        container.read(groupHealthProvider(key)).health,
        AttachmentHealth.ok,
      );

      controller.next();
      await settle(tester);
      expect(find.byType(PhotoMissingBox), findsOneWidget);
    });

    testWidgets('solo se regenera la que se ve y las contiguas, de una en '
        'una', (tester) async {
      final all = await photos(6);
      for (final a in all) {
        store.removeFile(a.id, 'screen.jpg');
      }
      importer.regenerateDelay = const Duration(milliseconds: 20);
      await pumpCarousel(tester, all);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(importer.regenerated.toSet(), {all[0].id, all[1].id, all[5].id});
      expect(importer.maxRegenerating, 1);
    });
  });
}
