// Gestos del carrusel de fotos (T-016-14; CA-016-09, 10, CL-016-10): el reparto
// por dirección, el umbral de 18 % y el de velocidad, dos dedos y el borde del
// sistema. Se prueba **solo** con `TestGesture` sobre un anfitrión de test con
// un `Scrollable` vertical dentro y el pie y los puntos encima (en
// `IgnorePointer`), como irán en la pantalla principal.
import 'dart:math' as math;
import 'dart:ui' show GestureSettings;

import 'package:app/features/attachments/photo_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que el anfitrión ve del reconocedor.
class _Log {
  final starts = <int>[];
  final updates = <double>[];
  final ends = <(PhotoSwipeChange?, double)>[];
  int cancels = 0;
  int get starting => starts.length;
  PhotoSwipeChange? get lastChange => ends.isEmpty ? null : ends.last.$1;
}

/// Un dedo con su propio reloj: cada paso avanza el tiempo, que es lo que lee
/// el cálculo de la velocidad.
class _Finger {
  _Finger(this.gesture);
  final TestGesture gesture;
  Duration clock = Duration.zero;

  /// Recorre [total] en [steps] pasos iguales repartidos en [ms] milisegundos.
  Future<void> move(Offset total, {int steps = 20, int ms = 320}) async {
    final step = total / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      clock += Duration(microseconds: ms * 1000 ~/ steps);
      await gesture.moveBy(step, timeStamp: clock);
    }
  }

  Future<void> up() => gesture.up(timeStamp: clock);
}

const _pieHeight = 60.0;

class _Host {
  _Host(this.tester);
  final WidgetTester tester;
  final log = _Log();
  final scroll = ScrollController();

  /// Zona del pie (y de los puntos, justo debajo) del anfitrión.
  Rect pieRect = Rect.zero;
  Rect dotsRect = Rect.zero;

  Future<_Finger> down(Offset p, {int? pointer}) async =>
      _Finger(await tester.startGesture(p, pointer: pointer));

  /// [window] es la ventana; [frame] el ancho del marco del carrusel
  /// (centrado, como `appFrame` en una tablet); [photoHeight] el alto de la
  /// foto dentro del desplazamiento.
  Future<void> pump({
    Size window = const Size(360, 700),
    double? frame,
    double photoHeight = 4000,
    double? touchSlop,
    EdgeInsets insets = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    tester.view.systemGestureInsets = FakeViewPadding(
      left: insets.left,
      top: insets.top,
      right: insets.right,
      bottom: insets.bottom,
    );
    if (touchSlop != null) {
      tester.view.gestureSettings = GestureSettings(
        physicalTouchSlop: touchSlop,
      );
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetSystemGestureInsets();
      tester.view.resetGestureSettings();
      scroll.dispose();
    });
    final width = frame ?? window.width;
    pieRect = Rect.fromLTWH(
      (window.width - width) / 2 + 16,
      window.height - 160,
      width - 32,
      _pieHeight,
    );
    dotsRect = Rect.fromLTWH(pieRect.left, pieRect.bottom + 8, width - 32, 12);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: SizedBox(
            width: width,
            height: window.height,
            child: Stack(
              children: [
                PhotoSwipeDetector(
                  onStart: () => log.starts.add(log.updates.length),
                  onUpdate: log.updates.add,
                  onEnd: (change, velocity) => log.ends.add((change, velocity)),
                  onCancel: () => log.cancels++,
                  child: SingleChildScrollView(
                    controller: scroll,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: width,
                      // Como `TaskImage`: nunca más bajo que la pantalla (un
                      // `SingleChildScrollView` se encoge a su contenido).
                      height: math.max(photoHeight, window.height),
                      child: const ColoredBox(color: Color(0xFF888888)),
                    ),
                  ),
                ),
                // Pie y puntos encima, transparentes a los toques.
                Positioned.fromRect(
                  rect: pieRect.shift(Offset(-(window.width - width) / 2, 0)),
                  child: const IgnorePointer(
                    child: ColoredBox(color: Color(0xFF111111)),
                  ),
                ),
                Positioned.fromRect(
                  rect: dotsRect.shift(Offset(-(window.width - width) / 2, 0)),
                  child: const IgnorePointer(
                    child: ColoredBox(color: Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('PhotoSwipe (reglas)', () {
    test('CA-016-10: el eje se decide tras min(16 dp, touchSlop)', () {
      expect(PhotoSwipe.decisionSlop(18), 16);
      expect(PhotoSwipe.decisionSlop(8), 8);
      expect(PhotoSwipe.decisionSlop(100), 16);
    });

    test('CA-016-10: horizontal solo si |dx| supera 1,5 veces |dy|', () {
      expect(PhotoSwipe.axisFor(15, 10), Axis.vertical); // exactamente 1,5
      expect(PhotoSwipe.axisFor(15.1, 10), Axis.horizontal);
      expect(PhotoSwipe.axisFor(-20, 10), Axis.horizontal);
      expect(PhotoSwipe.axisFor(5, -20), Axis.vertical);
    });

    test('CA-016-09: 18 % del ancho, o 700 dp/s en el sentido del gesto', () {
      PhotoSwipeChange? o(double dx, [double v = 0]) =>
          PhotoSwipe.outcome(dx: dx, velocity: v, width: 600);
      expect(o(-107), isNull);
      expect(o(-109), PhotoSwipeChange.next);
      expect(o(109), PhotoSwipeChange.previous);
      expect(o(-40, -700), PhotoSwipeChange.next);
      expect(o(-40, -699), isNull);
      expect(o(40, 900), PhotoSwipeChange.previous);
      // El tirón va en contra del recorrido: no cuenta.
      expect(o(-40, 900), isNull);
      // Rápido, pero casi sin recorrido: tampoco.
      expect(o(-10, -3000), isNull);
    });
  });

  // Todo el reparto, con el `touchSlop` por defecto de Flutter (18) y con el de
  // un Android real (8): el `Scrollable` acepta con el suyo y la decisión
  // nunca puede llegar después.
  for (final slop in <double?>[null, 8]) {
    final tag = slop == null ? 'touchSlop 18' : 'touchSlop 8';

    group('PhotoSwipeRecognizer ($tag)', () {
      testWidgets(
        'CA-016-09: horizontal limpio a la izquierda es la siguiente',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(250, 300));
          await f.move(const Offset(-150, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
          expect(h.log.starting, 1);
          expect(h.scroll.offset, 0);
          // La foto sigue al dedo desde que se aceptó.
          expect(h.log.updates.first, 0);
          expect(h.log.updates.last, lessThan(-100));
        },
      );

      testWidgets('CA-016-09: horizontal a la derecha es la anterior', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final f = await h.down(const Offset(100, 300));
        await f.move(const Offset(150, 0));
        await f.up();
        expect(h.log.lastChange, PhotoSwipeChange.previous);
      });

      testWidgets('CA-016-10: vertical limpio desplaza y no cambia de foto', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final f = await h.down(const Offset(180, 500));
        await f.move(const Offset(0, -200));
        await f.up();
        await tester.pumpAndSettle();
        expect(h.scroll.offset, greaterThan(100));
        expect(h.log.starts, isEmpty);
        expect(h.log.ends, isEmpty);
      });

      testWidgets('CA-016-10: diagonal por debajo de 1,5 desplaza', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final f = await h.down(const Offset(250, 500));
        // dx/dy = 1,4: sigue siendo vertical.
        await f.move(const Offset(-140, -100));
        await f.up();
        await tester.pumpAndSettle();
        expect(h.scroll.offset, greaterThan(0));
        expect(h.log.starts, isEmpty);
        expect(h.log.ends, isEmpty);
      });

      testWidgets('CA-016-10: diagonal por encima de 1,5 cambia de foto', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final f = await h.down(const Offset(250, 500));
        // dx/dy = 1,6.
        await f.move(const Offset(-160, -100));
        await f.up();
        await tester.pumpAndSettle();
        expect(h.log.lastChange, PhotoSwipeChange.next);
        expect(h.scroll.offset, 0);
      });

      testWidgets(
        'CA-016-10: un trazo que empezó vertical no pasa de desplazar a '
        'cambiar de foto',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(300, 500));
          await f.move(const Offset(0, -60));
          // Ahora sí, mucho más horizontal que vertical: el eje no cambia.
          await f.move(const Offset(-250, -10));
          await f.up();
          await tester.pumpAndSettle();
          expect(h.log.starts, isEmpty);
          expect(h.log.ends, isEmpty);
          expect(h.scroll.offset, greaterThan(0));
        },
      );

      testWidgets(
        'CA-016-10: un trazo que empezó horizontal no pasa a desplazar',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(300, 500));
          await f.move(const Offset(-60, 0));
          // Después deriva mucho en vertical: sigue siendo un swipe.
          await f.move(const Offset(-30, -300));
          await f.up();
          await tester.pumpAndSettle();
          expect(h.log.starting, 1);
          expect(h.scroll.offset, 0);
          expect(h.log.lastChange, PhotoSwipeChange.next);
        },
      );

      testWidgets('CA-016-09: el 18 % del ancho (360 dp) es el umbral', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        // 360 · 0,18 = 64,8.
        var f = await h.down(const Offset(300, 300));
        await f.move(const Offset(-60, 0));
        await f.up();
        expect(h.log.starting, 1);
        expect(h.log.lastChange, isNull, reason: '60 dp no llegan');
        expect(h.log.ends, hasLength(1));

        f = await h.down(const Offset(300, 300));
        await f.move(const Offset(-70, 0));
        await f.up();
        expect(h.log.ends, hasLength(2));
        expect(h.log.lastChange, PhotoSwipeChange.next);
      });

      testWidgets(
        'CA-016-09: un gesto rápido cambia aunque no llegue al 18 %',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          // 40 dp en 40 ms = 1000 dp/s.
          var f = await h.down(const Offset(300, 300));
          await f.move(const Offset(-40, 0), steps: 4, ms: 40);
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
          expect(h.log.ends.last.$2, lessThan(-700));

          // 40 dp en 120 ms = 333 dp/s: vuelve.
          f = await h.down(const Offset(300, 300));
          await f.move(const Offset(-40, 0), steps: 4, ms: 120);
          await f.up();
          expect(h.log.lastChange, isNull);
        },
      );

      testWidgets(
        'CA-016-09: el tirón rápido solo cuenta en el sentido del gesto',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(300, 300));
          await f.move(const Offset(-100, 0));
          // Se echa atrás deprisa: el recorrido sigue a la izquierda (-60) pero
          // la velocidad es hacia la derecha.
          await f.move(const Offset(40, 0), steps: 4, ms: 40);
          await f.up();
          expect(h.log.ends.last.$2, greaterThan(700));
          expect(h.log.lastChange, isNull);
        },
      );

      testWidgets('CA-016-10: con dos dedos no se cambia de foto', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final a = await h.down(const Offset(200, 300), pointer: 1);
        final b = await h.down(const Offset(260, 300), pointer: 2);
        // Los dos se mueven en horizontal, mucho.
        for (var i = 0; i < 20; i++) {
          await a.gesture.moveBy(const Offset(-10, 0));
          await b.gesture.moveBy(const Offset(-10, 0));
        }
        await a.up();
        await b.up();
        await tester.pumpAndSettle();
        expect(h.log.starts, isEmpty);
        expect(h.log.ends, isEmpty);
        expect(h.log.cancels, 0);
      });

      testWidgets(
        'CL-016-10: un segundo dedo durante el swipe lo cancela y la foto '
        'vuelve a su sitio',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final a = await h.down(const Offset(300, 300), pointer: 1);
          await a.move(const Offset(-100, 0));
          expect(h.log.starting, 1);
          expect(h.log.cancels, 0);
          final b = await h.down(const Offset(100, 300), pointer: 2);
          expect(h.log.cancels, 1);
          // Siguen moviéndose: ya no es un swipe.
          await a.move(const Offset(-150, 0));
          await b.move(const Offset(100, 0));
          final updates = h.log.updates.length;
          await a.up();
          await b.up();
          expect(h.log.ends, isEmpty, reason: 'nunca cambia de foto');
          expect(h.log.updates.length, updates);
          expect(h.log.cancels, 1);
        },
      );

      testWidgets(
        'CA-016-10: el dedo que queda tras un pellizco no inicia nada',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final a = await h.down(const Offset(200, 300), pointer: 1);
          final b = await h.down(const Offset(260, 300), pointer: 2);
          await b.move(const Offset(60, 0));
          await b.up();
          // Queda `a` solo: aunque ahora haga un swipe limpio, no cuenta.
          await a.move(const Offset(-250, 0));
          await a.up();
          await tester.pumpAndSettle();
          expect(h.log.starts, isEmpty);
          expect(h.log.ends, isEmpty);

          // Sin ningún dedo, el siguiente gesto vuelve a funcionar.
          final c = await h.down(const Offset(300, 300));
          await c.move(const Offset(-150, 0));
          await c.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
        },
      );

      testWidgets(
        'CA-016-10: un swipe cancelado por el sistema vuelve a su sitio',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(300, 300));
          await f.move(const Offset(-200, 0));
          await f.gesture.cancel();
          expect(h.log.cancels, 1);
          expect(h.log.ends, isEmpty);
        },
      );

      testWidgets('CA-016-10: un toque no hace nada', (tester) async {
        final h = _Host(tester);
        await h.pump(touchSlop: slop);
        final f = await h.down(const Offset(180, 300));
        await f.up();
        expect(h.log.starts, isEmpty);
        expect(h.log.ends, isEmpty);
      });

      testWidgets(
        'CA-016-10: una foto más baja que la pantalla no se desplaza y el '
        'swipe funciona',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop, photoHeight: 200);
          var f = await h.down(const Offset(180, 500));
          await f.move(const Offset(0, -300));
          await f.up();
          await tester.pumpAndSettle();
          expect(h.scroll.offset, 0);
          expect(h.log.starts, isEmpty);

          f = await h.down(const Offset(300, 500));
          await f.move(const Offset(-150, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
        },
      );

      testWidgets(
        'CA-016-09: un swipe que empieza sobre el pie o sobre los puntos '
        'funciona',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          for (final rect in [h.pieRect, h.dotsRect]) {
            final before = h.log.ends.length;
            final f = await h.down(Offset(rect.right - 20, rect.center.dy));
            await f.move(const Offset(-150, 0));
            await f.up();
            expect(h.log.ends.length, before + 1);
            expect(h.log.lastChange, PhotoSwipeChange.next);
          }
          expect(h.scroll.offset, 0);
        },
      );

      testWidgets('CA-016-10: el borde del sistema es del sistema', (
        tester,
      ) async {
        final h = _Host(tester);
        await h.pump(
          touchSlop: slop,
          insets: const EdgeInsets.symmetric(horizontal: 40),
        );
        // Desde el borde izquierdo y desde el derecho: no es nuestro.
        var f = await h.down(const Offset(20, 300));
        await f.move(const Offset(200, 0));
        await f.up();
        f = await h.down(const Offset(340, 300));
        await f.move(const Offset(-200, 0));
        await f.up();
        expect(h.log.starts, isEmpty);
        expect(h.log.ends, isEmpty);

        // Justo fuera de la zona sí.
        f = await h.down(const Offset(300, 300));
        await f.move(const Offset(-200, 0));
        await f.up();
        expect(h.log.lastChange, PhotoSwipeChange.next);
      });

      testWidgets(
        'CA-016-10: sin márgenes de gestos, el borde es del carrusel',
        (tester) async {
          final h = _Host(tester);
          await h.pump(touchSlop: slop);
          final f = await h.down(const Offset(20, 300));
          await f.move(const Offset(200, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.previous);
        },
      );

      testWidgets(
        'CA-016-10: un swipe que empieza en el borde no cambia de foto ni '
        'aunque el sistema lo cancele ni aunque llegue otro dedo',
        (tester) async {
          final h = _Host(tester);
          await h.pump(
            touchSlop: slop,
            insets: const EdgeInsets.only(left: 40),
          );
          final f = await h.down(const Offset(10, 300));
          await f.move(const Offset(250, 0));
          await f.gesture.cancel();
          expect(h.log.starts, isEmpty);
          expect(h.log.ends, isEmpty);
          expect(h.log.cancels, 0);
        },
      );

      testWidgets(
        'CA-016-10: en horizontal y con recorte, el borde se mide en la '
        'ventana',
        (tester) async {
          final h = _Host(tester);
          // Móvil girado con un recorte a la izquierda: el sistema reserva 48 a
          // la izquierda y 24 a la derecha.
          await h.pump(
            touchSlop: slop,
            window: const Size(780, 360),
            insets: const EdgeInsets.only(left: 48, right: 24),
          );
          var f = await h.down(const Offset(40, 200));
          await f.move(const Offset(300, 0));
          await f.up();
          f = await h.down(const Offset(765, 200));
          await f.move(const Offset(-300, 0));
          await f.up();
          expect(h.log.starts, isEmpty);

          // 50 dp desde el borde izquierdo y 30 desde el derecho: del carrusel.
          f = await h.down(const Offset(50, 200));
          await f.move(const Offset(300, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.previous);
          f = await h.down(const Offset(750, 200));
          await f.move(const Offset(-300, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
          expect(h.log.ends, hasLength(2));
        },
      );

      testWidgets(
        'CA-016-10: con el marco de 600 dp centrado, el borde se mide con '
        'la posición global y no con la del carrusel',
        (tester) async {
          final h = _Host(tester);
          // Ventana de 800 dp: el marco va de 100 a 700.
          await h.pump(
            touchSlop: slop,
            window: const Size(800, 600),
            frame: 600,
            insets: const EdgeInsets.symmetric(horizontal: 40),
          );
          // A 20 dp del borde del carrusel (global 120): lejos del de la
          // ventana, así que es nuestro.
          var f = await h.down(const Offset(120, 300));
          await f.move(const Offset(300, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.previous);
          f = await h.down(const Offset(680, 300));
          await f.move(const Offset(-300, 0));
          await f.up();
          expect(h.log.lastChange, PhotoSwipeChange.next);
          expect(h.log.ends, hasLength(2));
          // El 18 % es del ancho del carrusel (600), no de la ventana.
          f = await h.down(const Offset(500, 300));
          await f.move(const Offset(-100, 0)); // 100 < 108
          await f.up();
          expect(h.log.lastChange, isNull);
        },
      );
    });
  }
}
