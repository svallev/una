import 'dart:ui' show GestureSettings;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/screen_fingerprint.dart';

const _text = 'Horario del festival';
const _frame = Duration(milliseconds: 16);

/// Un dedo con su propio reloj: cada paso avanza el tiempo del gesto (lo que
/// lee el cálculo de la velocidad) y el de los fotogramas.
class _Finger {
  _Finger(this.tester, this.gesture);
  final WidgetTester tester;
  final TestGesture gesture;
  Duration clock = Duration.zero;

  Future<void> move(
    Offset total, {
    int steps = 20,
    int ms = 320,
    Future<void> Function()? each,
  }) async {
    final step = total / steps.toDouble();
    final dt = Duration(microseconds: ms * 1000 ~/ steps);
    for (var i = 0; i < steps; i++) {
      clock += dt;
      await gesture.moveBy(step, timeStamp: clock);
      await tester.pump(dt);
      if (each != null) await each();
    }
  }

  Future<void> up() => gesture.up(timeStamp: clock);
}

/// Bloquear zoom con un grupo de fotos (T-017-04c; CA-017-07, 08, 09 y 14,
/// CL-017-11 y 12): el bloqueo quita el pellizco y el desplazamiento por
/// contacto, **no** el swipe del carrusel (con cualquier puntero) ni las órdenes
/// deliberadas, y cada foto conserva su desplazamiento. Es caracterización: la
/// pantalla ya se comporta así (sin cambios de código), con la app entera.
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  var seq = 0;

  setUp(() => store = MemoryAttachmentStore());

  /// [n] fotos guardadas (cada una con su pantalla en el almacén).
  Future<List<Attachment>> photos(
    int n, {
    int width = 1080,
    int height = 6000,
  }) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'k${base + i}';
      all.add(
        await store.commit(
          stageImage(store, id, width: width, height: height),
          DateTime.utc(2026, 10, 7),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  /// La app entera con la tarea de [n] fotos como actual. Con [lock], el
  /// ajuste ya está guardado antes de arrancar. Con [touchSlop], el de un
  /// Android real (8) en lugar del de Flutter (18).
  Future<InMemoryTaskRepository> pumpGroup(
    WidgetTester tester, {
    bool lock = true,
    bool reduced = false,
    int n = 3,
    int height = 6000,
    double? touchSlop,
    double textScale = 1.0,
  }) async {
    final all = await photos(n, height: height);
    final repo = InMemoryTaskRepository();
    final base = sampleTask(text: _text, colorKey: 3, rank: 'M');
    await repo.insert(
      base.withContent(_text, null, base.updatedAt, attachments: all),
    );
    if (lock) await repo.setLockZoom(true);
    if (touchSlop != null) {
      tester.view.gestureSettings = GestureSettings(
        physicalTouchSlop: touchSlop,
      );
      addTearDown(tester.view.resetGestureSettings);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      reduced: reduced,
      textScale: textScale,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> setLock(WidgetTester tester, bool value) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhotoCarousel)),
    );
    await container.read(settingsProvider.notifier).setLockZoom(value);
    await tester.pumpAndSettle();
  }

  PhotoCarouselController carousel(WidgetTester tester) =>
      tester.widget<PhotoCarousel>(find.byType(PhotoCarousel)).controller!;

  int index(WidgetTester tester) => carousel(tester).index;
  double pixels(WidgetTester tester) => carousel(tester).scroll.position.pixels;
  int dots(WidgetTester tester) =>
      tester.widget<PhotoDots>(find.byType(PhotoDots)).index;

  List<String> mounted(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ];

  /// Posición horizontal de la foto actual (la primera montada): 0 en reposo.
  double left(WidgetTester tester) =>
      tester.getTopLeft(find.byType(ZoomablePhoto).first).dx;

  Matrix4 zoomMatrix(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ZoomablePhoto).first,
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;

  /// Todo lo que se ve de la foto actual: cuáles hay, cuál es, dónde está, su
  /// desplazamiento y su zoom.
  String look(WidgetTester tester) =>
      '${mounted(tester)}|${index(tester)}|${left(tester)}|${pixels(tester)}|'
      '${zoomMatrix(tester).storage}';

  Future<_Finger> down(
    WidgetTester tester,
    Offset at, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int? pointer,
  }) async => _Finger(
    tester,
    await tester.startGesture(at, kind: kind, pointer: pointer),
  );

  /// Una ráfaga de fotogramas de [ms] ms (la transición, el antirrebote y la
  /// región viva cuentan con el reloj de los fotogramas).
  Future<void> advance(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 16) {
      await tester.pump(_frame);
    }
  }

  /// Termina la transición (280 ms), el antirrebote y el vaciado del anuncio.
  Future<void> settle(WidgetTester tester) async {
    await advance(tester, 800);
    await advance(tester, 3000);
  }

  /// Swipe de [dx] (negativo = a la izquierda) y [dy] dp en [ms] ms.
  Future<void> swipe(
    WidgetTester tester,
    double dx, {
    double dy = 0,
    int ms = 320,
    int steps = 20,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    Future<void> Function()? each,
  }) async {
    final f = await down(
      tester,
      Offset(dx < 0 ? 330 : 60, 300),
      kind: kind,
      pointer: 7,
    );
    await f.move(Offset(dx, dy), ms: ms, steps: steps, each: each);
    await f.up();
    await tester.pump();
  }

  /// Varios dedos a la vez, cada uno con su recorrido; [each] corre en cada
  /// fotograma (ni un instante, CA-017-08).
  Future<void> together(
    WidgetTester tester,
    List<Offset> starts,
    List<Offset> totals, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
    Future<void> Function()? each,
  }) async {
    final fingers = <_Finger>[
      for (final (i, s) in starts.indexed)
        await down(tester, s, kind: kind, pointer: 20 + i),
    ];
    await tester.pump(_frame);
    if (each != null) await each();
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      for (final (j, f) in fingers.indexed) {
        f.clock += _frame;
        await f.gesture.moveBy(
          totals[j] / steps.toDouble(),
          timeStamp: f.clock,
        );
      }
      await tester.pump(_frame);
      if (each != null) await each();
    }
    for (final f in fingers) {
      await f.up();
    }
    await tester.pump(_frame);
    if (each != null) await each();
  }

  // --- CA-017-09: el swipe sigue con el bloqueo ------------------------------

  group(
    'CA-017-09: con el bloqueo, el swipe cambia de foto (cualquier puntero)',
    () {
      for (final kind in [
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.mouse,
      ]) {
        testWidgets('(${kind.name}) izquierda = siguiente, derecha = anterior, '
            'infinito, y los puntos informan', (tester) async {
          await pumpGroup(tester);
          expect(index(tester), 0);
          expect(dots(tester), 0);

          await swipe(tester, 200, kind: kind);
          await settle(tester);
          expect(index(tester), 2, reason: 'antes de la primera, la última');
          expect(dots(tester), 2);
          expect(mounted(tester), hasLength(1));
          expect(left(tester), 0);

          await swipe(tester, -200, kind: kind);
          await settle(tester);
          expect(index(tester), 0, reason: 'tras la última, la primera');
          expect(dots(tester), 0);

          await swipe(tester, -200, kind: kind);
          await settle(tester);
          expect(index(tester), 1);
          expect(dots(tester), 1);
          // Y con el bloqueo, la foto sigue sin desplazarse por contacto.
          expect(pixels(tester), 0);
        });
      }

      testWidgets('el 18 % del ancho cambia aunque sea lento; menos, no: la '
          'foto vuelve a su sitio', (tester) async {
        await pumpGroup(tester);
        // 60 dp y a 100 dp/s: ni llega al 18 % (70 dp) ni es un tirón.
        await swipe(tester, -60, ms: 600);
        await settle(tester);
        expect(index(tester), 0);
        expect(left(tester), 0);
        expect(mounted(tester), hasLength(1));

        // 80 dp lentos: más del 18 %.
        await swipe(tester, -80, ms: 640);
        await settle(tester);
        expect(index(tester), 1);
      });

      testWidgets('un tirón rápido (≥ 700 dp/s) cambia aunque recorra poco', (
        tester,
      ) async {
        await pumpGroup(tester);
        await swipe(tester, -60, ms: 60, steps: 4);
        await settle(tester);
        expect(index(tester), 1);
        expect(dots(tester), 1);
      });

      testWidgets('la transición dura 280 ms', (tester) async {
        await pumpGroup(tester);
        await swipe(tester, -200);
        // Recién soltada: sigue en marcha, con las dos fotos montadas.
        await advance(tester, 160);
        expect(index(tester), 0);
        expect(mounted(tester), hasLength(2));
        await advance(tester, 200);
        expect(index(tester), 1);
        expect(mounted(tester), hasLength(1));
        expect(left(tester), 0);
        await settle(tester);
      });

      testWidgets('con reducir movimiento, el cambio es instantáneo', (
        tester,
      ) async {
        await pumpGroup(tester, reduced: true);
        await swipe(tester, -200);
        expect(index(tester), 1);
        expect(mounted(tester), hasLength(1));
        expect(left(tester), 0);
        expect(dots(tester), 1);
        await settle(tester);
      });
    },
  );

  // --- CA-017-08: el reparto por dirección es el de la 016 -------------------

  for (final slop in <double?>[null, 8]) {
    final tag = slop == null ? 'touchSlop 18' : 'touchSlop 8';

    group('CA-017-08: el reparto por dirección de la 016 ($tag)', () {
      testWidgets('diagonal por encima de 1,5 es horizontal: cambia de foto '
          'y no desplaza la foto', (tester) async {
        await pumpGroup(tester, touchSlop: slop);
        // 150 a la izquierda y 60 hacia abajo: 2,5 veces.
        await swipe(tester, -150, dy: 60);
        await settle(tester);
        expect(index(tester), 1);
        expect(pixels(tester), 0);
      });

      testWidgets('diagonal por debajo de 1,5 es vertical: no mueve la foto '
          'ni cambia de ninguna manera, ni un fotograma', (tester) async {
        await pumpGroup(tester, touchSlop: slop);
        final before = look(tester);
        // 150 a la izquierda y 120 hacia abajo: 1,25 veces.
        await swipe(
          tester,
          -150,
          dy: 120,
          each: () async => expect(look(tester), before),
        );
        expect(look(tester), before);
        await tester.pumpAndSettle();
        expect(look(tester), before);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('vertical con dedo, lápiz y ratón: nada, ni un fotograma', (
        tester,
      ) async {
        await pumpGroup(tester, touchSlop: slop);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        final before = look(tester);
        expect(pixels(tester), greaterThan(100));
        for (final kind in [
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.mouse,
        ]) {
          for (final dy in [-300.0, 300.0]) {
            final f = await down(tester, const Offset(200, 420), kind: kind);
            await f.move(
              Offset(0, dy),
              each: () async => expect(look(tester), before),
            );
            await f.up();
            await tester.pump(_frame);
            expect(look(tester), before);
          }
        }
        await tester.pumpAndSettle();
        expect(look(tester), before);
      });
    });
  }

  testWidgets('control positivo: sin el bloqueo la diagonal por debajo de '
      '1,5 desplaza la foto (y no cambia de foto)', (tester) async {
    await pumpGroup(tester, lock: false);
    await swipe(tester, -150, dy: -120);
    await tester.pumpAndSettle();
    expect(index(tester), 0);
    expect(pixels(tester), greaterThan(50));
    await settle(tester);
  });

  group('CA-017-08: pellizco y dos dedos', () {
    for (final fingers in [2, 3]) {
      testWidgets('pellizco con $fingers dedos: ni zoom, ni desplazamiento, '
          'ni cambio de foto', (tester) async {
        await pumpGroup(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        final before = look(tester);
        await together(
          tester,
          [
            const Offset(170, 400),
            const Offset(230, 400),
            const Offset(200, 440),
          ].take(fingers).toList(),
          [
            const Offset(-90, 0),
            const Offset(90, 0),
            const Offset(0, 60),
          ].take(fingers).toList(),
          each: () async => expect(look(tester), before),
        );
        await tester.pumpAndSettle();
        expect(look(tester), before);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('con $fingers dedos que van a la izquierda nunca se cambia '
          'de foto', (tester) async {
        await pumpGroup(tester);
        final before = look(tester);
        await together(
          tester,
          [
            const Offset(300, 400),
            const Offset(340, 400),
            const Offset(320, 440),
          ].take(fingers).toList(),
          List.filled(fingers, const Offset(-220, 0)),
          each: () async => expect(look(tester), before),
        );
        await settle(tester);
        expect(index(tester), 0);
        expect(look(tester), before);
      });
    }

    testWidgets('el segundo dedo durante un swipe lo cancela: la foto vuelve '
        'y no cambia, aunque el primero siga', (tester) async {
      await pumpGroup(tester);
      final a = await down(tester, const Offset(330, 400), pointer: 31);
      await a.move(const Offset(-100, 0), steps: 10, ms: 160);
      expect(left(tester), lessThan(-50), reason: 'la foto sigue al dedo');
      expect(mounted(tester), hasLength(2));

      final b = await down(tester, const Offset(100, 500), pointer: 32);
      await tester.pump(_frame);
      await advance(tester, 400);
      expect(left(tester), 0);
      expect(mounted(tester), hasLength(1));
      expect(index(tester), 0);

      // El primero sigue y suelta: ya no hay swipe.
      await a.move(const Offset(-120, 0), steps: 6, ms: 100);
      await a.up();
      await b.up();
      await settle(tester);
      expect(index(tester), 0);
      expect(left(tester), 0);

      // Con todos los dedos arriba, el siguiente gesto vale otra vez.
      await swipe(tester, -200);
      await settle(tester);
      expect(index(tester), 1);
    });
  });

  // --- CA-017-07 y CL-017-11: cada foto conserva su desplazamiento -----------

  // --- CA-017-08 y CL-017-9: rueda y trackpad sobre el grupo -----------------

  Future<void> wheelOver(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(PhotoCarousel));
    final mouse = TestPointer(81, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump(_frame);
    }
  }

  Future<void> trackpadOver(
    WidgetTester tester, {
    Offset? pan,
    double? scale,
  }) async {
    final center = tester.getCenter(find.byType(PhotoCarousel));
    final pad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pad.panZoomStart(center);
    await tester.pump(_frame);
    for (var i = 1; i <= 10; i++) {
      await pad.panZoomUpdate(
        center,
        pan: pan == null ? Offset.zero : pan * i.toDouble(),
        scale: scale == null ? 1 : 1 + scale * i,
      );
      await tester.pump(_frame);
    }
    await pad.panZoomEnd();
    await tester.pump(_frame);
  }

  group('CA-017-08 y CL-017-9: rueda y trackpad sobre el grupo', () {
    final gestures = <String, Future<void> Function(WidgetTester)>{
      'la rueda del ratón': wheelOver,
      'el desplazamiento vertical del trackpad': (t) =>
          trackpadOver(t, pan: const Offset(0, -24)),
      'el pellizco del trackpad': (t) => trackpadOver(t, scale: 0.3),
    };
    for (final entry in gestures.entries) {
      testWidgets('${entry.key} no mueve, no amplía ni cambia de foto con el '
          'bloqueo', (tester) async {
        await pumpGroup(tester);
        final before = look(tester);
        await entry.value(tester);
        expect(look(tester), before);
        expect(pixels(tester), 0);
        expect(index(tester), 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    for (final name in [
      'la rueda del ratón',
      'el desplazamiento vertical del trackpad',
    ]) {
      testWidgets('control positivo: sin el bloqueo, $name desplaza la foto', (
        tester,
      ) async {
        await pumpGroup(tester, lock: false);
        await gestures[name]!(tester);
        await tester.pumpAndSettle();
        expect(pixels(tester), greaterThan(50));
        expect(index(tester), 0);
      });
    }
  });

  group('CA-017-07 y CL-017-11: la foto se queda donde estaba', () {
    testWidgets('cada foto conserva su desplazamiento; la no vista, arriba', (
      tester,
    ) async {
      await pumpGroup(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final first = pixels(tester);
      expect(first, greaterThan(300));

      await swipe(tester, -200);
      await settle(tester);
      expect(index(tester), 1);
      expect(pixels(tester), 0, reason: 'una foto que no se ha visto, arriba');
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final second = pixels(tester);
      expect(second, greaterThan(first));

      await swipe(tester, 200);
      await settle(tester);
      expect(index(tester), 0);
      expect(pixels(tester), first, reason: 'la primera conserva el suyo');

      await swipe(tester, -200);
      await settle(tester);
      expect(pixels(tester), second, reason: 'y la segunda, el suyo');
      // Cada foto tiene su propio controlador.
      expect(
        carousel(tester).scrollOf('k${seq - 3}'),
        isNot(same(carousel(tester).scrollOf('k${seq - 2}'))),
      );
    });

    testWidgets('las fotos con distinto desplazamiento no se mezclan al '
        'cambiar durante la transición', (tester) async {
      await pumpGroup(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final first = pixels(tester);
      await swipe(tester, -200);
      await advance(tester, 100);
      // A mitad de la transición, las dos montadas con su propio desplazamiento.
      final states = tester.widgetList<ZoomablePhoto>(
        find.byType(ZoomablePhoto),
      );
      expect(states, hasLength(2));
      expect(states.first.scroll!.position.pixels, first);
      expect(states.last.scroll!.position.pixels, 0);
      await settle(tester);
    });

    testWidgets('CL-017-11: encender y apagar con la foto desplazada no la '
        'mueve; con el bloqueo, el contacto no la mueve', (tester) async {
      await pumpGroup(tester, lock: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final before = look(tester);
      await setLock(tester, true);
      expect(look(tester), before);
      await swipe(tester, 0, dy: -300);
      expect(look(tester), before);
      await tester.drag(find.byType(PhotoCarousel), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(look(tester), before);
      await setLock(tester, false);
      expect(look(tester), before);
      // Apagado, el contacto vuelve a desplazar desde donde estaba.
      await tester.drag(find.byType(PhotoCarousel), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(pixels(tester), greaterThan(pixelsOf(before)));
    });
  });

  // --- CA-017-09 y 14: el nodo de la tarea -----------------------------------

  group('CA-017-09: las acciones del nodo de la tarea', () {
    SemanticsNode taskNode(WidgetTester tester) => tester.getSemantics(
      find.bySemanticsLabel(RegExp('^(Tarea actual|Current task): ')),
    );

    /// Las acciones, en el orden del lector: las estándar y las propias.
    String actionsOf(WidgetTester tester) {
      final data = taskNode(tester).getSemanticsData();
      final custom = [
        for (final id in data.customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      final standard = [
        for (final a in [
          SemanticsAction.scrollUp,
          SemanticsAction.scrollDown,
          SemanticsAction.scrollLeft,
          SemanticsAction.scrollRight,
          SemanticsAction.focus,
        ])
          if (data.hasAction(a)) a.name,
      ];
      return '${standard.join(',')}|${custom.join(',')}';
    }

    bool has(WidgetTester tester, SemanticsAction action) =>
        taskNode(tester).getSemanticsData().hasAction(action);

    void perform(WidgetTester tester, SemanticsAction action) {
      final node = taskNode(tester);
      node.owner!.performAction(node.id, action);
    }

    const expectedActions =
        'scrollUp,scrollLeft,scrollRight,focus|'
        'Foto siguiente,Foto anterior,Completar tarea,Eliminar tarea';

    for (final lock in [false, true]) {
      testWidgets('las mismas acciones y en el mismo orden, antes de '
          'desplazar (bloqueo: $lock)', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpGroup(tester, lock: lock);
        expect(actionsOf(tester), expectedActions);
        // Tras desplazar la foto, además, hacia atrás; el resto igual.
        perform(tester, SemanticsAction.scrollUp);
        await tester.pumpAndSettle();
        expect(
          actionsOf(tester),
          'scrollUp,scrollDown,scrollLeft,scrollRight,focus|'
          'Foto siguiente,Foto anterior,Completar tarea,Eliminar tarea',
        );
        handle.dispose();
      });
    }

    testWidgets('«desplazar adelante» recorre la foto y luego pasa a la '
        'siguiente, igual con y sin el bloqueo', (tester) async {
      final handle = tester.ensureSemantics();

      Future<List<String>> forward({required bool lock}) async {
        await pumpGroup(tester, lock: lock);
        final log = <String>[];
        var guard = 0;
        while (has(tester, SemanticsAction.scrollUp) && guard++ < 10) {
          perform(tester, SemanticsAction.scrollUp);
          await tester.pumpAndSettle();
          log.add(pixels(tester).toStringAsFixed(1));
        }
        perform(tester, SemanticsAction.scrollLeft);
        await settle(tester);
        log.add('foto ${index(tester)}|${pixels(tester)}');
        // Y «desplazar atrás» (scrollRight) vuelve a la primera, donde la dejó.
        perform(tester, SemanticsAction.scrollRight);
        await settle(tester);
        log.add('foto ${index(tester)}|${pixels(tester).toStringAsFixed(1)}');
        return log;
      }

      final off = await forward(lock: false);
      await tester.pumpWidget(const SizedBox.shrink());
      final on = await forward(lock: true);
      expect(on, off);
      // Varios pasos de la foto, luego la siguiente (arriba) y la vuelta.
      expect(on.length, greaterThan(3));
      expect(on[on.length - 2], 'foto 1|0.0');
      expect(on.last, 'foto 0|${on[on.length - 3]}');
      handle.dispose();
    });

    testWidgets('Foto siguiente y Foto anterior y las acciones de '
        'desplazar a los lados cambian de foto con el bloqueo', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGroup(tester);
      void custom(String label) {
        final node = taskNode(tester);
        final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
          (id) => CustomSemanticsAction.getAction(id)!.label == label,
        );
        node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      }

      custom('Foto siguiente');
      await settle(tester);
      expect(index(tester), 1);
      perform(tester, SemanticsAction.scrollLeft);
      await settle(tester);
      expect(index(tester), 2);
      perform(tester, SemanticsAction.scrollRight);
      await settle(tester);
      expect(index(tester), 1);
      custom('Foto anterior');
      await settle(tester);
      custom('Foto anterior');
      await settle(tester);
      expect(index(tester), 2, reason: 'infinito');
      handle.dispose();
    });
  });

  group('CA-017-09: el teclado sigue con el bloqueo', () {
    testWidgets('las flechas cambian de foto y Av Pág y Re Pág desplazan la '
        'que se ve', (tester) async {
      await pumpGroup(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(index(tester), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(index(tester), 2, reason: 'infinito');

      expect(pixels(tester), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(pixels(tester), closeTo(844 * 0.8, 0.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(pixels(tester), 0);
    });

    testWidgets('con reducir movimiento, Av Pág salta sin animar', (
      tester,
    ) async {
      await pumpGroup(tester, reduced: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(pixels(tester), closeTo(844 * 0.8, 0.5));
    });
  });

  // --- CA-017-14 y CA-017-15: guías y texto grande ---------------------------

  group('CA-017-14, CA-017-15: la tarea con grupo y bloqueo al 200 %', () {
    // Proporciones normales (3:4 y 1:2, Q-017-7).
    for (final (name, height) in [('3:4', 1440), ('1:2', 2160)]) {
      testWidgets(
        'con fotos $name el bloqueo no cambia nada (píxeles y lectura) y se cumplen las cuatro guías, con el logotipo, el menú y completar enteros',
        (tester) async {
          final handle = tester.ensureSemantics();
          Future<Fingerprint> shot(bool lock) async {
            await pumpGroup(tester, lock: lock, height: height, textScale: 2);
            if (lock) {
              // Con el bloqueo: los controles caben y se pueden tocar.
              for (final finder in [
                find.byType(Wordmark),
                find.bySemanticsLabel('Menú de la tarea'),
                find.byType(HoldToCompleteButton),
              ]) {
                expect(finder, findsOneWidget);
                final size = tester.getSize(finder);
                expect(
                  size.shortestSide,
                  greaterThanOrEqualTo(UnaSizes.minTouchTarget),
                  reason: '$finder',
                );
                final r = tester.getRect(finder);
                expect(r.left, greaterThanOrEqualTo(0));
                expect(r.right, lessThanOrEqualTo(390));
                expect(r.bottom, lessThanOrEqualTo(844));
              }
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }
            expect(tester.takeException(), isNull);
            return fingerprintOf(tester);
          }

          final off = await shot(false);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          final on = await shot(true);
          expect(on.pixels.toSet().length, greaterThan(8));
          expectSameFingerprint(off, on);
          handle.dispose();
        },
      );
    }

    testWidgets(
      'con reducir movimiento y el texto al 200 %, el swipe cambia de foto sin animar y las guías se cumplen',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpGroup(tester, reduced: true, height: 1440, textScale: 2);
        expect(index(tester), 0);
        await tester.timedDragFrom(
          const Offset(330, 400),
          const Offset(-250, 0),
          const Duration(milliseconds: 320),
        );
        await tester.pump();
        expect(index(tester), 1);
        expect(tester.hasRunningAnimations, isFalse);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await advance(tester, 4000);
        handle.dispose();
      },
    );
  });

  // --- CL-017-12: los controles siguen --------------------------------------

  group('CL-017-12: el logotipo, el menú y Mantener pulsado siguen', () {
    testWidgets('el menú se abre; el logotipo no hace nada', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGroup(tester);
      final before = look(tester);
      await tester.tap(find.byType(Wordmark));
      await tester.pumpAndSettle();
      expect(find.byType(MenuSheet), findsNothing);
      expect(look(tester), before);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuSheet), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mantener pulsado completa a los 1,2 s; soltar antes, no', (
      tester,
    ) async {
      final repo = await pumpGroup(tester);
      var gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete ~/ 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(await repo.findById('t1'), isNotNull);

      gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(_frame);
      await gesture.up();
      await tester.pump(_frame);
      expect(await repo.findById('t1'), isNull);
      await tester.pump(const Duration(seconds: 10));
    });
  });
}

/// El desplazamiento que dice un [look] (el cuarto campo).
double pixelsOf(String look) => double.parse(look.split('|')[3]);
