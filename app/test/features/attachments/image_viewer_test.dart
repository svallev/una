import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/image_viewer_screen.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/pump_app.dart';

final _viewerImage = find.bySemanticsLabel('Foto');

void main() {
  late MemoryAttachmentStore store;
  late List<String> announcements;
  late List<List<String>> orientations;

  setUp(() => store = MemoryAttachmentStore());

  void listen(WidgetTester tester) {
    announcements = [];
    orientations = [];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add([
          for (final o in call.arguments as List<Object?>) o! as String,
        ]);
      }
      return null;
    });
    addTearDown(() {
      messenger
        ..setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        )
        ..setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  Future<Task> imageTask({int width = 4000, int height = 3000}) async {
    final attachment = await store.commit(
      stageImage(store, 'a1', width: width, height: height),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(text: 'Horario');
    return base.withContent('Horario', attachment, base.updatedAt);
  }

  /// La app con la tarea con imagen como actual, y el visor abierto.
  Future<void> openViewer(
    WidgetTester tester, {
    int width = 4000,
    int height = 3000,
    bool reduced = false,
    bool screenReader = false,
  }) async {
    listen(tester);
    final repo = InMemoryTaskRepository();
    await repo.insert(await imageTask(width: width, height: height));
    await pumpUnaApp(
      tester,
      repo: repo,
      reduced: reduced,
      screenReader: screenReader,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    await tester.tap(find.byType(TaskImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
  }

  TransformationController controller(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!;

  double scale(WidgetTester tester) =>
      controller(tester).value.getMaxScaleOnAxis();

  Offset translation(WidgetTester tester) {
    final t = controller(tester).value.getTranslation();
    return Offset(t.x, t.y);
  }

  Future<void> doubleTap(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
  }

  group('CA-007-09: visor a pantalla completa', () {
    testWidgets('tocar la imagen lo abre: al ancho, sobre papel, con '
        '"Cerrar" de 48 dp arriba a la izquierda', (tester) async {
      await openViewer(tester);
      final tiles = find.descendant(
        of: find.byType(ImageViewerScreen),
        matching: find.byType(Image),
      );
      expect(tiles, findsOneWidget);
      final rect = tester.getRect(tiles);
      expect(rect.width, 390);
      expect(rect.height, closeTo(390 * 3000 / 4000, 0.01));
      expect(
        tester
            .widget<Scaffold>(
              find.descendant(
                of: find.byType(ImageViewerScreen),
                matching: find.byType(Scaffold),
              ),
            )
            .backgroundColor,
        UnaColors.paper,
      );
      final close = tester.getRect(find.bySemanticsLabel('Cerrar'));
      expect(close.size, const Size(48, 48));
      expect(close.left, lessThan(20));
      expect(close.top, lessThan(20));
    });

    testWidgets('una captura larga se desplaza solo en vertical', (
      tester,
    ) async {
      await openViewer(tester, width: 1080, height: 20000);
      await tester.drag(
        find.byType(InteractiveViewer),
        const Offset(-200, -400),
      );
      await tester.pumpAndSettle();
      expect(translation(tester).dx, 0);
      expect(translation(tester).dy, lessThan(0));
      expect(scale(tester), 1);
    });

    testWidgets('las teselas de 4096 px se colocan y se decodifican al '
        'ancho de la pantalla', (tester) async {
      await openViewer(tester, width: 5000, height: 3000);
      final images = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(ImageViewerScreen),
              matching: find.byType(Image),
            ),
          )
          .toList();
      expect(images, hasLength(2));
      final widths = [for (final i in images) (i.image as ResizeImage).width];
      // 390 px lógicos (×1 en la prueba) repartidos entre 4096 y 904 px.
      expect(widths, [(4096 * 390 / 5000).ceil(), (904 * 390 / 5000).ceil()]);
    });

    testWidgets('"Cerrar" vuelve a la tarea actual con el foco en ella', (
      tester,
    ) async {
      await openViewer(tester);
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsNothing);
      // El foco principal está en la tarea (un antecesor de la imagen).
      final primary = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(
          of: find.byWidget(primary.widget),
          matching: find.byType(TaskImage),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el gesto atrás también cierra', (tester) async {
      await openViewer(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsNothing);
      expect(find.byType(TaskImage), findsOneWidget);
    });
  });

  group('CA-007-10: zoom', () {
    testWidgets('el doble toque va por pasos ×1 → ×2,5 → ×8 → ×1', (
      tester,
    ) async {
      await openViewer(tester);
      final center = tester.getCenter(find.byType(InteractiveViewer));
      for (final expected in [2.5, 8.0, 1.0]) {
        await doubleTap(tester, center);
        expect(scale(tester), closeTo(expected, 0.001));
      }
      expect(translation(tester).dx, 0);
    });

    testWidgets('centra la ampliación en el punto tocado', (tester) async {
      await openViewer(tester);
      final viewer = tester.getRect(find.byType(InteractiveViewer));
      // Arriba a la izquierda de la imagen (que está centrada en vertical).
      final imageTop = (viewer.height - 390 * 3000 / 4000) / 2;
      final tap = Offset(100, imageTop + 80);
      await doubleTap(tester, tap);
      final scene = controller(tester).toScene(viewer.center);
      expect(scene.dx, closeTo(100, 0.5));
      expect(scene.dy, closeTo(imageTop + 80, 0.5));
    });

    testWidgets('ampliada, se desplaza en las dos direcciones', (tester) async {
      await openViewer(tester);
      final center = tester.getCenter(find.byType(InteractiveViewer));
      await doubleTap(tester, center);
      final before = translation(tester);
      await tester.drag(find.byType(InteractiveViewer), const Offset(60, 40));
      await tester.pumpAndSettle();
      final after = translation(tester);
      expect(after.dx, greaterThan(before.dx));
      expect(after.dy, greaterThan(before.dy));
    });

    testWidgets('el pellizco amplía hasta ×8 como máximo', (tester) async {
      await openViewer(tester);
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final a = await tester.startGesture(center - const Offset(20, 0));
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var i = 1; i <= 20; i++) {
        await a.moveTo(center - Offset(20.0 + i * 20, 0));
        await b.moveTo(center + Offset(20.0 + i * 20, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(scale(tester), greaterThan(2));
      expect(scale(tester), lessThanOrEqualTo(UnaMotion.viewerZoomMax));
    });

    testWidgets('CA-007-23: con reducir movimiento el zoom salta', (
      tester,
    ) async {
      await openViewer(tester, reduced: true);
      final center = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(center);
      await tester.pump();
      expect(scale(tester), closeTo(2.5, 0.001));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('CA-007-11: el visor gira y al girar vuelve a ×1; al volver a '
      'vertical se cierra solo', (tester) async {
    await openViewer(tester);
    expect(orientations.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    await doubleTap(tester, tester.getCenter(find.byType(InteractiveViewer)));
    expect(scale(tester), closeTo(2.5, 0.001));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
    final image = find.descendant(
      of: find.byType(ImageViewerScreen),
      matching: find.byType(Image),
    );
    expect(tester.getRect(image).width, 844);

    // Sin pulsar "Cerrar": de vuelta en la tarea actual, solo en vertical.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(find.byType(TaskImage), findsOneWidget);
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('CA-007-11: "Cerrar" en horizontal vuelve a la tarea, en '
      'vertical', (tester) async {
    await openViewer(tester);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
  });

  group('CA-007-21/22: lector y teclado', () {
    testWidgets('al abrir, "Imagen de la tarea" da nombre a la pantalla y la '
        'imagen tiene el nivel como valor y solo las acciones aplicables', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openViewer(tester, screenReader: true);
      expect(find.bySemanticsLabel('Imagen de la tarea'), findsWidgets);
      expect(
        tester.getSemantics(_viewerImage),
        isSemantics(
          label: 'Foto',
          value: 'Ampliación por 1',
          isImage: true,
          customActions: [const CustomSemanticsAction(label: 'Ampliar')],
        ),
      );
      handle.dispose();
    });

    testWidgets('las acciones amplían, reducen y ajustan; se anuncia el '
        'nivel y el foco no se mueve', (tester) async {
      final handle = tester.ensureSemantics();
      await openViewer(tester, screenReader: true);
      void act(String label) => tester.semantics.customAction(
        find.semantics.byLabel('Foto'),
        CustomSemanticsAction(label: label),
      );

      act('Ampliar');
      await tester.pumpAndSettle();
      expect(scale(tester), closeTo(2.5, 0.001));
      expect(announcements.last, 'Ampliación por 2,5');
      expect(
        tester.getSemantics(_viewerImage),
        isSemantics(
          label: 'Foto',
          value: 'Ampliación por 2,5',
          isImage: true,
          customActions: [
            const CustomSemanticsAction(label: 'Ampliar'),
            const CustomSemanticsAction(label: 'Reducir'),
            const CustomSemanticsAction(label: 'Ajustar al ancho'),
          ],
        ),
      );
      act('Ampliar');
      await tester.pumpAndSettle();
      expect(scale(tester), closeTo(8, 0.001));
      expect(
        tester.getSemantics(_viewerImage),
        isSemantics(
          label: 'Foto',
          value: 'Ampliación por 8',
          isImage: true,
          customActions: [
            const CustomSemanticsAction(label: 'Reducir'),
            const CustomSemanticsAction(label: 'Ajustar al ancho'),
          ],
        ),
      );
      act('Reducir');
      await tester.pumpAndSettle();
      expect(scale(tester), closeTo(2.5, 0.001));
      act('Ajustar al ancho');
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      expect(announcements, [
        'Ampliación por 2,5',
        'Ampliación por 8',
        'Ampliación por 2,5',
        'Ampliación por 1',
      ]);
      handle.dispose();
    });

    testWidgets('una imagen alta tiene las acciones de desplazamiento', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openViewer(tester, width: 1080, height: 20000, screenReader: true);
      final node = tester.getSemantics(_viewerImage);
      expect(node.getSemanticsData().hasAction(SemanticsAction.scrollUp), true);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.scrollDown),
        isFalse,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.scrollLeft),
        isFalse,
      );
      tester.semantics.scrollUp(scrollable: find.semantics.byLabel('Foto'));
      await tester.pumpAndSettle();
      expect(translation(tester).dy, lessThan(0));
      expect(
        tester
            .getSemantics(_viewerImage)
            .getSemanticsData()
            .hasAction(SemanticsAction.scrollDown),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('teclado: + amplía, − reduce, 0 ajusta y las flechas '
        'desplazan', (tester) async {
      await openViewer(tester, width: 1080, height: 20000);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      expect(scale(tester), closeTo(2.5, 0.001));
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(translation(tester).dy, lessThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      final x = translation(tester).dx;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(translation(tester).dx, lessThan(x));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
    });

    testWidgets('la tarea actual tiene la pista "ver la imagen entera" y al '
        'activarla abre el visor', (tester) async {
      final handle = tester.ensureSemantics();
      listen(tester);
      final repo = InMemoryTaskRepository();
      await repo.insert(await imageTask());
      await pumpUnaApp(
        tester,
        repo: repo,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Tarea actual: Horario. Con foto'),
      );
      expect(node.hint, 'ver la imagen entera');
      tester.semantics.tap(
        find.semantics.byLabel('Tarea actual: Horario. Con foto'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsOneWidget);
      handle.dispose();
    });
  });
}
