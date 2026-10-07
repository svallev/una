import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Un gesto: [step] avanza un fotograma y comprueba lo que toque (ni un
/// instante, CA-017-08).
typedef Gesture = Future<void> Function(
  WidgetTester tester,
  Offset center,
  Future<void> Function() step,
);

/// Bloquear zoom en la página de foto (T-017-04a, CA-017-08 y 12): con el
/// ajuste, ni pellizco ni desplazamiento por contacto, ni un instante.
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  var seq = 0;

  setUp(() => store = MemoryAttachmentStore());

  /// La ventana de la foto: 390 × 600. Una 1:2 (780) es más alta; una 3:4
  /// (520), más baja.
  const view = Size(390, 600);

  Future<Attachment> photo({int width = 1080, int height = 2160}) =>
      store.commit(
        stageImage(store, 'l${seq++}', width: width, height: height),
        DateTime.utc(2026, 10, 7),
      );

  Future<ScrollController> pumpPhoto(
    WidgetTester tester,
    Attachment attachment, {
    bool disableAnimations = false,
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpWithApp(
      tester,
      ZoomablePhoto(attachment: attachment, scroll: controller),
      size: view,
      disableAnimations: disableAnimations,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> setLock(WidgetTester tester, bool value) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ZoomablePhoto)),
    );
    await container.read(settingsProvider.notifier).setLockZoom(value);
    await tester.pump();
  }

  Finder inPhoto(Type type) => find.descendant(
    of: find.byType(ZoomablePhoto),
    matching: find.byType(type),
  );

  Matrix4 zoomMatrix(WidgetTester tester) =>
      tester.widget<Transform>(inPhoto(Transform).first).transform;

  double zoom(WidgetTester tester) => zoomMatrix(tester).getMaxScaleOnAxis();

  /// Lo que se ve de la foto: zoom, desplazamiento y tamaño/posición.
  String look(WidgetTester tester, ScrollController scroll) {
    final physics = scroll.hasClients ? scroll.position.pixels : null;
    final rect = tester.getRect(inPhoto(Image).first);
    return '${zoomMatrix(tester).storage}|$physics|$rect';
  }

  const frame = Duration(milliseconds: 16);

  final touch = PointerDeviceKind.touch;

  Gesture dragBy(Offset delta, PointerDeviceKind kind, {int fingers = 1}) =>
      (tester, center, step) async {
        final fingersDown = <TestGesture>[];
        for (var i = 0; i < fingers; i++) {
          fingersDown.add(
            await tester.startGesture(
              center + Offset(i * 40.0, 0),
              pointer: 50 + i,
              kind: kind,
            ),
          );
        }
        await step();
        for (var i = 1; i <= 12; i++) {
          for (final g in fingersDown) {
            await g.moveBy(delta / 12);
          }
          await step();
        }
        for (final g in fingersDown) {
          await g.up();
        }
        await step();
      };

  Gesture pinchWith(int fingers) => (tester, center, step) async {
    final starts = <Offset>[
      center - const Offset(20, 0),
      center + const Offset(20, 0),
      center + const Offset(0, 40),
    ];
    final dirs = <Offset>[
      const Offset(-1, 0),
      const Offset(1, 0),
      const Offset(0, 1),
    ];
    final gs = <TestGesture>[];
    for (var i = 0; i < fingers; i++) {
      gs.add(await tester.startGesture(starts[i], pointer: 60 + i));
    }
    await step();
    for (var i = 1; i <= 10; i++) {
      for (var j = 0; j < fingers; j++) {
        await gs[j].moveBy(dirs[j] * 8);
      }
      await step();
    }
    for (final g in gs) {
      await g.up();
    }
    await step();
  };

  final gestures = <String, Gesture>{
    'pellizco con 2 dedos': pinchWith(2),
    'pellizco con 3 dedos': pinchWith(3),
    'arrastre vertical con el dedo': dragBy(const Offset(0, -240), touch),
    'arrastre diagonal 1,2 con el dedo': dragBy(const Offset(50, -60), touch),
    'arrastre diagonal 2 con el dedo': dragBy(const Offset(40, -80), touch),
    'arrastre vertical con lápiz': dragBy(
      const Offset(0, -240),
      PointerDeviceKind.stylus,
    ),
    'arrastre diagonal 2 con lápiz': dragBy(
      const Offset(40, -80),
      PointerDeviceKind.stylus,
    ),
    'arrastre vertical con lápiz invertido': dragBy(
      const Offset(0, -240),
      PointerDeviceKind.invertedStylus,
    ),
    'arrastre vertical con ratón': dragBy(
      const Offset(0, -240),
      PointerDeviceKind.mouse,
    ),
    'arrastre diagonal 1,2 con ratón': dragBy(
      const Offset(50, -60),
      PointerDeviceKind.mouse,
    ),
    'arrastre vertical con 2 dedos': dragBy(
      const Offset(0, -240),
      touch,
      fingers: 2,
    ),
    'rueda del ratón': (tester, center, step) async {
      final wheel = TestPointer(70, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(center));
      for (var i = 0; i < 4; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 120)));
        await step();
      }
    },
    'desplazamiento del trackpad': (tester, center, step) async {
      final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
      await pad.panZoomStart(center);
      await step();
      for (var i = 1; i <= 10; i++) {
        await pad.panZoomUpdate(center, pan: Offset(0, -24.0 * i));
        await step();
      }
      await pad.panZoomEnd();
      await step();
    },
    'pellizco del trackpad': (tester, center, step) async {
      final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
      await pad.panZoomStart(center);
      await step();
      for (var i = 1; i <= 10; i++) {
        await pad.panZoomUpdate(center, scale: 1 + 0.3 * i);
        await step();
      }
      await pad.panZoomEnd();
      await step();
    },
    'tocar': (tester, center, step) async {
      final g = await tester.startGesture(center);
      await step();
      await g.up();
      await step();
    },
  };

  /// Los gestos que mueven o amplían una foto alta sin el bloqueo (la rueda
  /// y el trackpad incluidos). El arrastre con ratón y tocar no hacen nada
  /// ni sin él (el ratón no está en `dragDevices`).
  const moveOrZoomUnlocked = {
    'pellizco con 2 dedos',
    'pellizco con 3 dedos',
    'arrastre vertical con el dedo',
    'arrastre diagonal 1,2 con el dedo',
    'arrastre diagonal 2 con el dedo',
    'arrastre vertical con lápiz',
    'arrastre diagonal 2 con lápiz',
    'arrastre vertical con lápiz invertido',
    'rueda del ratón',
    'desplazamiento del trackpad',
  };

  group('CA-017-08: con el bloqueo, la foto no se mueve ni un instante', () {
    for (final (name, ratio) in const [
      ('alta 1:2', (1080, 2160)),
      ('baja 3:4', (3000, 4000)),
    ]) {
      for (final entry in gestures.entries) {
        testWidgets('${entry.key}, foto $name: idéntica en cada fotograma, '
            'sin animación pendiente al soltar', (tester) async {
          final scroll = await pumpPhoto(
            tester,
            await photo(width: ratio.$1, height: ratio.$2),
          );
          await setLock(tester, true);
          await tester.pumpAndSettle();
          final before = look(tester, scroll);
          final center = tester.getCenter(find.byType(ZoomablePhoto));

          await entry.value(tester, center, () async {
            await tester.pump(frame);
            expect(look(tester, scroll), before);
          });
          // Ningún fotograma pendiente: no hay animación de vuelta.
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(tester.hasRunningAnimations, isFalse);
          expect(look(tester, scroll), before);
        });
      }
    }

    testWidgets('con reducir movimiento tampoco se mueve', (tester) async {
      final scroll = await pumpPhoto(
        tester,
        await photo(),
        disableAnimations: true,
      );
      await setLock(tester, true);
      final before = look(tester, scroll);
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      await gestures['pellizco con 2 dedos']!(tester, center, () async {
        await tester.pump(frame);
        expect(look(tester, scroll), before);
      });
      await gestures['arrastre vertical con el dedo']!(
        tester,
        center,
        () async {
          await tester.pump(frame);
          expect(look(tester, scroll), before);
        },
      );
    });

    testWidgets('la foto sigue en la pantalla con el tamaño de siempre', (
      tester,
    ) async {
      final scroll = await pumpPhoto(tester, await photo());
      final unlocked = look(tester, scroll);
      await setLock(tester, true);
      await tester.pumpAndSettle();
      // 1080 × 2160 a 390 de ancho: 780 de alto, a todo el ancho.
      expect(tester.getSize(inPhoto(Image).first), const Size(390, 780));
      expect(look(tester, scroll), unlocked);
    });
  });

  group('CA-017-12: sin el bloqueo, los mismos gestos hacen lo de la 007', () {
    for (final name in moveOrZoomUnlocked) {
      testWidgets('$name: algo cambia (control positivo)', (tester) async {
        final scroll = await pumpPhoto(tester, await photo());
        final before = look(tester, scroll);
        final center = tester.getCenter(find.byType(ZoomablePhoto));
        var changed = false;
        await gestures[name]!(tester, center, () async {
          await tester.pump(frame);
          if (look(tester, scroll) != before) changed = true;
        });
        expect(changed, isTrue, reason: name);
      });
    }

    testWidgets('el pellizco del trackpad y tocar no hacen nada, como en la '
        '007', (tester) async {
      final scroll = await pumpPhoto(tester, await photo());
      final before = look(tester, scroll);
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      for (final name in ['pellizco del trackpad', 'tocar']) {
        await gestures[name]!(tester, center, () async {
          await tester.pump(frame);
          expect(look(tester, scroll), before, reason: name);
        });
      }
    });
  });

  group('CA-017-07 y 12: encender y apagar no mueve la foto', () {
    testWidgets('encender con la foto desplazada: mismos píxeles, mismo '
        'controlador; apagar desplaza desde donde estaba', (tester) async {
      final scroll = await pumpPhoto(tester, await photo());
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -100));
      await tester.pumpAndSettle();
      final moved = scroll.position.pixels;
      expect(moved, greaterThan(50));
      final state = tester.state(find.byType(ZoomablePhoto));
      final look0 = look(tester, scroll);

      await setLock(tester, true);
      expect(tester.state(find.byType(ZoomablePhoto)), same(state));
      expect(scroll.position.pixels, moved);
      expect(look(tester, scroll), look0);
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, moved);

      await setLock(tester, false);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ZoomablePhoto)), same(state));
      expect(scroll.position.pixels, moved);
      // Y se desplaza desde ahí, no desde arriba.
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(moved));
    });

    testWidgets('encender con un pellizco en curso lo suelta: zoom al 100 %, '
        'sin animación y sin quedarse a medias', (tester) async {
      final scroll = await pumpPhoto(tester, await photo());
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      // Un pellizco que se queda con los dedos puestos.
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 81,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 82,
      );
      await tester.pump(frame);
      await a.moveBy(const Offset(-60, 0));
      await b.moveBy(const Offset(60, 0));
      await tester.pump(frame);
      expect(zoom(tester), greaterThan(1));

      await setLock(tester, true);
      expect(zoom(tester), 1);
      await a.moveBy(const Offset(-60, 0));
      await b.moveBy(const Offset(60, 0));
      await tester.pump(frame);
      expect(zoom(tester), 1);
      await a.up();
      await b.up();
      await tester.pump(frame);
      expect(zoom(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(scroll.position.pixels, 0);
      final physics = tester
          .widget<SingleChildScrollView>(inPhoto(SingleChildScrollView))
          .physics;
      expect(physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('encender con la vuelta del zoom en marcha la corta', (
      tester,
    ) async {
      await pumpPhoto(tester, await photo());
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 91,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 92,
      );
      await tester.pump(frame);
      await a.moveBy(const Offset(-60, 0));
      await b.moveBy(const Offset(60, 0));
      await tester.pump(frame);
      await a.up();
      await b.up();
      await tester.pump(frame);
      await tester.pump(const Duration(milliseconds: 40));
      expect(zoom(tester), greaterThan(1));
      expect(zoom(tester), lessThan(8));

      await setLock(tester, true);
      expect(zoom(tester), 1);
      await tester.pump(frame);
      expect(zoom(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('la forma del árbol no depende del ajuste', (tester) async {
      await pumpPhoto(tester, await photo());
      String shape() => [
        for (final t in [Listener, LayoutBuilder, SingleChildScrollView])
          inPhoto(t).evaluate().length,
      ].join(',');
      final off = shape();
      await setLock(tester, true);
      expect(shape(), off);
    });
  });
}
