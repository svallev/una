import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  }) async {
    final attachment = await store.commit(
      stageImage(store, 'a1', origin: origin),
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

  Finder imageOf() =>
      find.descendant(of: find.byType(TaskImage), matching: find.byType(Image));

  group('CA-007-08: la imagen llena la pantalla', () {
    testWidgets('a sangre y recortada, detrás del logotipo, el menú y el '
        'botón', (tester) async {
      await pumpScreen(tester, await imageTask());

      final image = tester.widget<Image>(imageOf());
      expect(image.fit, BoxFit.cover);
      expect(tester.getRect(imageOf()), const Rect.fromLTWH(0, 0, 390, 844));
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
}
