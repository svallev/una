import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;

  setUp(() => store = MemoryAttachmentStore());

  Future<Task> imageTask({
    String? text = 'Horario del festival',
    AttachmentOrigin origin = AttachmentOrigin.camera,
    int width = 4000,
    int height = 3000,
  }) async {
    final attachment = await store.commit(
      stageImage(store, 'a1', origin: origin, width: width, height: height),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(text: text ?? 'x');
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Task task, {
    double textScale = 1.0,
  }) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: task),
      textScale: textScale,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    await tester.pump();
  }

  /// La versión de pantalla (la primera imagen; encima, las teselas).
  Finder imageOf() => find
      .descendant(of: find.byType(TaskImage), matching: find.byType(Image))
      .first;

  group('CA-007-08: la imagen llena la pantalla', () {
    testWidgets('a todo el ancho, sin perder los lados (DEV-41), detrás del '
        'logotipo, el menú y el botón', (tester) async {
      await pumpScreen(tester, await imageTask());

      final image = tester.widget<Image>(imageOf());
      expect(image.fit, BoxFit.fitWidth);
      // 4000 × 3000 a 390 de ancho: 292,5 de alto, centrada en vertical.
      expect(
        tester.getRect(imageOf()),
        Rect.fromLTWH(0, (844 - 292.5) / 2, 390, 292.5),
      );
      // La capa de la imagen está detrás de todo, a pantalla completa.
      expect(
        tester.getRect(find.byType(TaskImage)),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
      // Detrás: el logotipo, el menú y el botón se pintan encima.
      final stack = tester.widget<Stack>(
        find
            .ancestor(of: find.byType(TaskImage), matching: find.byType(Stack))
            .last,
      );
      expect(stack.children.last, isNot(isA<TaskImage>()));
    });

    testWidgets('logotipo y menú con fondo blanco', (tester) async {
      await pumpScreen(tester, await imageTask());
      final logoBox = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.byType(Wordmark),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(logoBox.color, UnaColors.surface);
      // El logotipo no se mueve: el fondo sobresale 8 px por la izquierda.
      expect(tester.getTopLeft(find.byType(Wordmark)).dx, UnaSpace.l);
      expect(
        tester
            .getTopLeft(
              find
                  .ancestor(
                    of: find.byType(Wordmark),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .dx,
        UnaSpace.l - UnaSpace.s,
      );
      expect(
        tester.widget<SquareIconButton>(find.byType(SquareIconButton)).fill,
        UnaColors.surface,
      );
    });

    testWidgets('sin imagen, el menú sigue con el color de la nota', (
      tester,
    ) async {
      await pumpScreen(tester, sampleTask(colorKey: 2));
      expect(
        tester.widget<SquareIconButton>(find.byType(SquareIconButton)).fill,
        UnaPalettes.classic[2],
      );
    });

    testWidgets('el texto es un pie: recuadro negro, texto blanco de 22 px y '
        '800, a 146 px del borde inferior', (tester) async {
      await pumpScreen(tester, await imageTask());
      final text = tester.widget<Text>(find.text('Horario del festival'));
      expect(text.style!.fontSize, UnaFontSizes.imageCaption);
      expect(text.style!.fontWeight, UnaFontWeights.extrabold);
      expect(text.style!.color, UnaColors.onInk);
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
      final box = find
          .ancestor(
            of: find.text('Horario del festival'),
            matching: find.byType(ColoredBox),
          )
          .first;
      expect(tester.widget<ColoredBox>(box).color, UnaColors.ink);
      final rect = tester.getRect(box);
      expect(rect.bottom, 844 - UnaSizes.imageCaptionBottom);
      expect(rect.left, UnaSpace.l);
      expect(rect.right, 390 - UnaSpace.l);
    });

    testWidgets('sin texto no hay pie', (tester) async {
      await pumpScreen(tester, await imageTask(text: null));
      expect(
        find.descendant(
          of: find.byType(TaskImage),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('un texto largo se corta en 3 líneas y con el texto al 200 % '
        'no desborda (escala del pie hasta ×1,6)', (tester) async {
      final long = 'Horario del festival de verano ' * 12;
      await pumpScreen(tester, await imageTask(text: long), textScale: 2.0);
      expect(tester.takeException(), isNull);
      final p = tester.renderObject<RenderParagraph>(find.text(long));
      expect(p.didExceedMaxLines, isTrue);
      expect(
        p.textScaler.scale(10),
        closeTo(10 * UnaSizes.imageCaptionMaxTextScale, 0.001),
      );
    });

    testWidgets('se ve al abrir la app, sin ningún toque', (tester) async {
      final repo = InMemoryTaskRepository();
      await repo.insert(await imageTask());
      await pumpUnaApp(
        tester,
        repo: repo,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      expect(find.byType(TaskImage), findsOneWidget);
      expect(find.text('Horario del festival'), findsOneWidget);
    });
  });

  group('CA-007-21: lectura', () {
    Future<List<SemanticsNode>> traversal(WidgetTester tester, Task t) async {
      await pumpScreen(tester, t);
      return tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => n.label.isNotEmpty)
          .toList();
    }

    testWidgets('foto con texto: un único elemento, con papel de imagen, '
        'antes del menú y de completar', (tester) async {
      final handle = tester.ensureSemantics();
      final nodes = await traversal(tester, await imageTask());
      expect(nodes.map((n) => n.label), [
        'Tarea actual: Horario del festival. Con foto',
        'Menú de la tarea',
        'Pulsa para completar',
      ]);
      expect(
        nodes.first,
        isSemantics(
          label: 'Tarea actual: Horario del festival. Con foto',
          isImage: true,
          customActions: [
            const CustomSemanticsAction(label: 'Completar tarea'),
            const CustomSemanticsAction(label: 'Eliminar tarea'),
          ],
        ),
      );
      handle.dispose();
    });

    testWidgets('imagen de la galería: "Con imagen" sin decir "imagen" dos '
        'veces', (tester) async {
      final handle = tester.ensureSemantics();
      final nodes = await traversal(
        tester,
        await imageTask(origin: AttachmentOrigin.gallery),
      );
      expect(
        nodes.first.label,
        'Tarea actual: Horario del festival. Con imagen',
      );
      expect(nodes.first.flagsCollection.isImage, isFalse);
      handle.dispose();
    });

    testWidgets('sin texto: "Tarea actual: Foto" / "Tarea actual: Imagen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var nodes = await traversal(tester, await imageTask(text: null));
      expect(nodes.first.label, 'Tarea actual: Foto');
      store = MemoryAttachmentStore();
      nodes = await traversal(
        tester,
        await imageTask(text: null, origin: AttachmentOrigin.gallery),
      );
      expect(nodes.first.label, 'Tarea actual: Imagen');
      handle.dispose();
    });

    testWidgets('el lector lee el texto completo aunque el pie se corte', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final long = 'Horario del festival de verano ' * 12;
      final nodes = await traversal(tester, await imageTask(text: long));
      expect(nodes.first.label, 'Tarea actual: $long. Con foto');
      handle.dispose();
    });

    testWidgets('objetivos táctiles y contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, await imageTask());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('sin visor (propietario, 2026-09-27)', () {
    late List<List<String>> orientations;
    late List<bool> rotating;

    /// La app completa con la tarea con imagen como actual.
    Future<void> pumpApp(
      WidgetTester tester, {
      Task? task,
      bool reduced = false,
    }) async {
      orientations = [];
      rotating = [];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add([
              for (final o in call.arguments as List<Object?>) o! as String,
            ]);
          }
          return null;
        })
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), (
          call,
        ) async {
          if (call.method == 'rotateWithImage') {
            rotating.add(call.arguments as bool);
          }
          return null;
        });
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(SystemChannels.platform, null)
          ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
      });
      final repo = InMemoryTaskRepository();
      await repo.insert(task ?? await imageTask());
      await pumpUnaApp(
        tester,
        repo: repo,
        reduced: reduced,
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      await tester.pumpAndSettle();
    }

    double zoom(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(TaskImage),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getMaxScaleOnAxis();

    /// Separa dos dedos sobre la imagen; devuelve los gestos sin soltar.
    Future<(TestGesture, TestGesture)> pinch(WidgetTester tester) async {
      final center = tester.getCenter(find.byType(TaskImage));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 21,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 22,
      );
      for (var i = 1; i <= 10; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return (a, b);
    }

    testWidgets('CA-007-10: pellizcar amplía ahí mismo y al soltar vuelve al '
        '100 %', (tester) async {
      await pumpApp(tester);
      final (a, b) = await pinch(tester);
      expect(zoom(tester), greaterThan(2));
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(zoom(tester), greaterThan(1)); // Vuelve con animación.
      await tester.pumpAndSettle();
      expect(zoom(tester), 1);
    });

    testWidgets('CA-007-23: con reducir movimiento vuelve al instante', (
      tester,
    ) async {
      await pumpApp(tester, reduced: true);
      final (a, b) = await pinch(tester);
      expect(zoom(tester), greaterThan(2));
      await a.up();
      await b.up();
      await tester.pump();
      expect(zoom(tester), 1);
    });

    testWidgets('tocar la imagen no abre nada', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byType(TaskImage));
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(find.byType(TaskImage)))!.isCurrent,
        isTrue,
      );
    });

    testWidgets('CA-007-09 / CL-007-2: una captura alta se desplaza en '
        'vertical', (tester) async {
      await pumpApp(tester, task: await imageTask(width: 1080, height: 20000));
      final scroll = find.descendant(
        of: find.byType(TaskImage),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        greaterThan(1000),
      );
    });

    testWidgets('CA-007-11: con la tarea a la vista gira; con el menú '
        'abierto, solo en vertical', (tester) async {
      await pumpApp(tester);
      expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));
      expect(rotating.last, isTrue);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      expect(rotating.last, isFalse);

      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pumpAndSettle();
      expect(rotating.last, isTrue);
    });

    testWidgets('CA-007-11: en horizontal, solo la imagen y el logotipo', (
      tester,
    ) async {
      await pumpApp(tester);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      expect(find.text('Horario del festival'), findsNothing);
      // A todo el ancho de la pantalla.
      expect(tester.getSize(find.byType(TaskImage)).width, 844);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.text('Horario del festival'), findsOneWidget);
    });
  });
}
