import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/photo_announcer.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/focus_on_signal.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Bloquear zoom con el móvil girado (T-017-07; CA-017-10, 08 y 09): con el
/// ajuste encendido la tarea con imagen o con grupo **sigue girando** como en
/// la 007 y la 016. En horizontal (800 × 360 dp) solo se ven la foto, al 100 %
/// del ancho, y el logotipo; no hay pellizco ni desplazamiento por contacto; el
/// swipe, las acciones del lector y las flechas siguen; se mantiene la foto al
/// girar y volver, y al volver a vertical se ve todo. Girar con la foto al
/// final del recorrido no deja un hueco en blanco (el desplazamiento queda
/// dentro de su rango, sin que haga falta tocar la foto).

const _text = 'Horario del festival';
const _frame = Duration(milliseconds: 16);
const _portrait = Size(390, 844);
const _landscape = Size(800, 360);

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  var seq = 0;

  setUp(() => store = MemoryAttachmentStore());

  /// [n] fotos 3:4 (normales) con su pantalla en el almacén.
  Future<List<Attachment>> photos(int n) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'l${base + i}';
      all.add(
        await store.commit(
          stageImage(store, id, width: 1080, height: 1440),
          DateTime.utc(2026, 10, 7),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  /// La app con una imagen suelta (n = 1) o un grupo (n ≥ 2) como actual.
  Future<InMemoryTaskRepository> pumpApp(
    WidgetTester tester, {
    required int n,
    bool lock = true,
    bool screenReader = false,
    bool reduced = false,
    List<String> more = const [],
  }) async {
    final all = await photos(n);
    final repo = InMemoryTaskRepository();
    final base = sampleTask(text: _text, colorKey: 3, rank: 'MA');
    await repo.insert(
      n == 1
          ? base.withContent(_text, all.single, base.updatedAt)
          : base.withContent(_text, null, base.updatedAt, attachments: all),
    );
    if (lock) await repo.setLockZoom(true);
    await pumpUnaApp(
      tester,
      repo: repo,
      tasks: more,
      screenReader: screenReader,
      reduced: reduced,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        photoAnnouncerModeProvider.overrideWithValue(
          PhotoAnnouncerMode.liveRegion,
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(tester.view.reset);
    return repo;
  }

  Future<void> turn(WidgetTester tester, {required bool landscape}) async {
    tester.view.physicalSize = landscape ? _landscape : _portrait;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(_frame);
    }
  }

  PhotoCarouselController controllerOf(WidgetTester tester) =>
      tester.widget<PhotoCarousel>(find.byType(PhotoCarousel)).controller!;

  Finder photo() => find.byType(ZoomablePhoto).first;

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: photo(), matching: find.byType(Scrollable)).first,
      )
      .position;

  double pixels(WidgetTester tester) => position(tester).pixels;

  Matrix4 zoomMatrix(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(of: photo(), matching: find.byType(Transform)).first,
      )
      .transform;

  List<String> mounted(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ];

  /// Todo lo que se ve de la foto: cuál es, dónde está, su desplazamiento y su
  /// zoom.
  String look(WidgetTester tester) =>
      '${mounted(tester)}|${tester.getRect(photo())}|${pixels(tester)}|'
      '${zoomMatrix(tester).storage}';

  Future<void> pinch(WidgetTester tester, {void Function()? each}) async {
    final center = tester.getCenter(photo());
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 51,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 52,
    );
    for (var i = 0; i < 8; i++) {
      await a.moveBy(const Offset(-6, 0));
      await b.moveBy(const Offset(6, 0));
      await tester.pump(_frame);
      each?.call();
    }
    await a.up();
    await b.up();
    await tester.pump(_frame);
    each?.call();
  }

  Future<void> dragVertical(
    WidgetTester tester, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
    void Function()? each,
  }) async {
    final g = await tester.startGesture(
      tester.getCenter(photo()),
      pointer: 53,
      kind: kind,
    );
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, -30));
      await tester.pump(_frame);
      each?.call();
    }
    await g.up();
    await tester.pump(_frame);
    each?.call();
  }

  SemanticsNode taskNode(WidgetTester tester) => tester.getSemantics(
    find.bySemanticsLabel(RegExp('^Tarea actual: ')).first,
  );

  List<String> customActions(WidgetTester tester) => [
    for (final id
        in taskNode(tester).getSemanticsData().customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performCustom(WidgetTester tester, String label) {
    final node = taskNode(tester);
    final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == label,
    );
    node.owner!.performAction(node.id, SemanticsAction.customAction, id);
  }

  Future<void> swipe(
    WidgetTester tester,
    Offset from,
    double dx, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final g = await tester.startGesture(from, kind: kind, pointer: 61);
    var clock = Duration.zero;
    const steps = 20;
    const dt = Duration(milliseconds: 16);
    for (var i = 0; i < steps; i++) {
      clock += dt;
      await g.moveBy(Offset(dx / steps, 0), timeStamp: clock);
      await tester.pump(dt);
    }
    await g.up(timeStamp: clock);
    await settle(tester);
  }

  for (final (name, n) in [('imagen suelta', 1), ('grupo de 3 fotos', 3)]) {
    group('CA-017-10 con el bloqueo, $name', () {
      testWidgets('en horizontal, solo la foto (al 100 % del ancho) y el '
          'logotipo', (tester) async {
        await pumpApp(tester, n: n);
        expect(find.byType(HoldToCompleteButton), findsOneWidget);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);

        await turn(tester, landscape: true);
        expect(find.byType(Wordmark), findsOneWidget);
        expect(find.byType(BrutalButton), findsNothing, reason: 'sin menú');
        expect(find.byType(HoldToCompleteButton), findsNothing);
        expect(find.byType(ImageCaption), findsNothing);
        expect(find.byType(PhotoDots), findsNothing);
        expect(find.byType(n == 1 ? TaskImage : PhotoCarousel), findsOneWidget);
        expect(tester.getSize(photo()).width, 800);
        expect(tester.getTopLeft(photo()).dx, 0);
        expect(zoomMatrix(tester).isIdentity(), isTrue);
      });

      testWidgets('sin pellizco ni desplazamiento por contacto, ni un '
          'fotograma', (tester) async {
        await pumpApp(tester, n: n);
        await turn(tester, landscape: true);
        final before = look(tester);
        // La foto es más alta que la pantalla: sin el bloqueo se desplazaría.
        expect(position(tester).maxScrollExtent, greaterThan(300));

        await pinch(tester, each: () => expect(look(tester), before));
        await dragVertical(tester, each: () => expect(look(tester), before));
        await dragVertical(
          tester,
          kind: PointerDeviceKind.stylus,
          each: () => expect(look(tester), before),
        );
        await tester.pumpAndSettle();
        expect(look(tester), before);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('el desplazamiento por orden sigue: Av Pág y Re Pág '
          'mueven la foto', (tester) async {
        await pumpApp(tester, n: n);
        await turn(tester, landscape: true);
        expect(pixels(tester), 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await settle(tester);
        final moved = pixels(tester);
        expect(moved, greaterThan(200), reason: '80 % de la ventana');
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await settle(tester);
        expect(pixels(tester), lessThan(moved));
      });

      testWidgets('las acciones del lector siguen: completar, eliminar y, con '
          'grupo, cambiar de foto', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester, n: n, screenReader: true);
        await turn(tester, landscape: true);
        final actions = customActions(tester);
        expect(actions, containsAll(['Completar tarea', 'Eliminar tarea']));
        if (n > 1) {
          expect(actions, containsAll(['Foto siguiente', 'Foto anterior']));
        }
        handle.dispose();
      });

      testWidgets('"Completar tarea" como acción empieza la rotura', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          n: n,
          screenReader: true,
          more: const ['Siguiente'],
        );
        await turn(tester, landscape: true);
        performCustom(tester, 'Completar tarea');
        await tester.pump(_frame);
        await tester.pump(UnaMotion.holdDonePause);
        await tester.pump(_frame);
        await tester.pump(_frame);
        expect(find.byType(CelebrationOverlay), findsOneWidget);
        // Termina y sigue la tarea de texto.
        await tester.pump(CelebrationOverlay.screenReaderHold);
        await tester.pump(UnaMotion.successFade);
        await tester.pump(UnaMotion.introFade);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CelebrationOverlay), findsNothing);
        expect(find.text('Siguiente'), findsWidgets);
        handle.dispose();
      });

      testWidgets('"Eliminar tarea" como acción empieza el arrugado', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          n: n,
          screenReader: true,
          more: const ['Siguiente'],
        );
        await turn(tester, landscape: true);
        performCustom(tester, 'Eliminar tarea');
        await tester.pump(_frame);
        await tester.pump(_frame);
        await tester.pump(UnaMotion.crumple * 0.3);
        expect(find.byType(CrumpleOverlay), findsOneWidget);
        await tester.pump(UnaMotion.crumple);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(CrumpleOverlay), findsNothing);
        expect(find.text('Siguiente'), findsWidgets);
        handle.dispose();
      });

      testWidgets('se mantiene la foto al girar y volver, y en vertical se '
          've todo', (tester) async {
        await pumpApp(tester, n: n);
        if (n > 1) {
          controllerOf(tester)
            ..next()
            ..next();
          await settle(tester);
          expect(controllerOf(tester).index, 2);
        }
        final shown = mounted(tester);

        await turn(tester, landscape: true);
        expect(mounted(tester), shown);
        if (n > 1) expect(controllerOf(tester).index, 2);

        await turn(tester, landscape: false);
        expect(mounted(tester), shown);
        if (n > 1) {
          expect(controllerOf(tester).index, 2);
          expect(find.byType(PhotoDots), findsOneWidget);
          expect(tester.widget<PhotoDots>(find.byType(PhotoDots)).index, 2);
        }
        expect(find.byType(HoldToCompleteButton), findsOneWidget);
        expect(find.byType(ImageCaption), findsOneWidget);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
        // Otra vez bloqueada: ni pellizco ni desplazamiento.
        final before = look(tester);
        await pinch(tester, each: () => expect(look(tester), before));
        await dragVertical(tester, each: () => expect(look(tester), before));
      });
    });
  }

  group('CA-017-09, CA-017-10: el grupo en horizontal con el bloqueo', () {
    testWidgets('el swipe cambia de foto con dedo y con lápiz, y dos dedos '
        'nunca', (tester) async {
      await pumpApp(tester, n: 3);
      await turn(tester, landscape: true);
      final controller = controllerOf(tester);

      await swipe(tester, const Offset(600, 180), -300);
      expect(controller.index, 1);
      await swipe(tester, const Offset(300, 180), 300);
      expect(controller.index, 0);
      await swipe(
        tester,
        const Offset(600, 180),
        -300,
        kind: PointerDeviceKind.stylus,
      );
      expect(controller.index, 1);

      await pinch(tester);
      await settle(tester);
      expect(controller.index, 1, reason: 'dos dedos no cambian de foto');
      expect(zoomMatrix(tester).isIdentity(), isTrue);
    });

    testWidgets('las acciones y las flechas siguen y anuncian una vez', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, n: 3, screenReader: true);
      await turn(tester, landscape: true);
      final controller = controllerOf(tester);
      performCustom(tester, 'Foto siguiente');
      await settle(tester);
      expect(controller.index, 1);
      performCustom(tester, 'Foto anterior');
      await settle(tester);
      expect(controller.index, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(controller.index, 1);
      expect(
        find.bySemanticsLabel('Tarea actual: $_text. Foto 2 de 3'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('el foco de teclado se ve (anillo) y las flechas cambian '
        'de foto', (tester) async {
      await pumpApp(tester, n: 3);
      await turn(tester, landscape: true);
      final ring = find.descendant(
        of: find.byType(FocusOnSignal),
        matching: find.byType(FocusRing),
      );
      expect(ring, findsNothing, reason: 'con el tacto no se ve');
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pump();
      expect(ring, findsOneWidget);
      expect(tester.getRect(ring).width, greaterThan(700));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(controllerOf(tester).index, 1);
      expect(ring, findsOneWidget);
    });

    testWidgets('cada foto conserva su desplazamiento al cambiar de foto en '
        'horizontal', (tester) async {
      await pumpApp(tester, n: 3);
      await turn(tester, landscape: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      final moved = controllerOf(tester).scroll.position.pixels;
      expect(moved, greaterThan(200));
      controllerOf(tester).next();
      await settle(tester);
      expect(controllerOf(tester).scroll.position.pixels, 0);
      controllerOf(tester).previous();
      await settle(tester);
      expect(controllerOf(tester).scroll.position.pixels, moved);
    });
  });

  for (final (name, n) in [('imagen suelta', 1), ('grupo de 3 fotos', 3)]) {
    for (final lock in [true, false]) {
      group(
        'CA-017-10, plan §3.4: al girar a vertical con ${lock ? "el "
                  "bloqueo" : "el ajuste apagado"}, $name',
        () {
          testWidgets('desplazada hasta el final en horizontal, el '
              'desplazamiento queda dentro de su rango (sin hueco en blanco)', (
            tester,
          ) async {
            await pumpApp(tester, n: n, lock: lock);
            await turn(tester, landscape: true);
            // Por orden (Av Pág) hasta el final.
            for (var i = 0; i < 10 && position(tester).pixels < 1; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
              await settle(tester);
            }
            for (var i = 0; i < 10; i++) {
              final p = position(tester);
              if (p.pixels >= p.maxScrollExtent - 0.5) break;
              await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
              await settle(tester);
            }
            final end = position(tester);
            final atEnd = end.pixels;
            expect(end.maxScrollExtent, greaterThan(300));
            expect(atEnd, closeTo(end.maxScrollExtent, 0.5));

            await turn(tester, landscape: false);
            await settle(tester);
            final p = position(tester);
            expect(p.hasContentDimensions, isTrue);
            expect(
              p.pixels,
              inInclusiveRange(p.minScrollExtent, p.maxScrollExtent),
              reason:
                  'pixels ${p.pixels} (en horizontal, $atEnd) fuera de '
                  '[${p.minScrollExtent}, ${p.maxScrollExtent}]: hueco en '
                  'blanco',
            );
            // Y la foto sigue siendo la misma, a la vista.
            expect(find.byType(ZoomablePhoto), findsWidgets);
            expect(tester.takeException(), isNull);
          });
        },
      );
    }
  }
}
