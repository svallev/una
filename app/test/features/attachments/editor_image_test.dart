import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/pump_app.dart';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');
final _remove = find.bySemanticsLabel('Quitar adjunto');

void main() {
  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store)
      // "Subir imágenes" con una sola elegida es la 007 (CA-016-03).
      ..manyTotal = 1;
    repo = InMemoryTaskRepository();
  });

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    EditorMode mode = EditorMode.first,
    Task? task,
    bool reduced = false,
  }) async {
    listen(tester);
    await pumpWithApp(
      tester,
      TaskEditorScreen(mode: mode, task: task),
      repo: repo,
      disableAnimations: reduced,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String row) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  AttachmentImportState importState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TaskEditorScreen)))
          .read(attachmentImportProvider);

  bool plusFocused(WidgetTester tester) => tester
      .widget<BrutalButton>(
        find.byWidgetPredicate(
          (w) =>
              w is BrutalButton && w.label == 'Añadir foto, imagen o archivo',
        ),
      )
      .focusNode!
      .hasFocus;

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  /// Tarea guardada con una imagen ya en el almacén.
  Future<Task> taskWithImage({String? text = 'Horario'}) async {
    final attachment = await store.commit(
      stageImage(store, 'old', origin: AttachmentOrigin.gallery),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(text: text ?? 'x', colorKey: 3, rank: 'M');
    final task = base.withContent(text, attachment, base.updatedAt);
    await repo.insert(task);
    return task;
  }

  group('CA-007-04: editor con imagen', () {
    for (final (mode, label) in [
      (EditorMode.first, 'Guardar'),
      (EditorMode.create, 'Continuar'),
    ]) {
      testWidgets('vista previa, "Quitar adjunto", texto opcional y "$label" '
          '(${mode.name})', (tester) async {
        await pumpEditor(tester, mode: mode);
        await pick(tester, 'Subir imágenes');

        expect(find.byType(AttachmentPreview), findsOneWidget);
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(AttachmentPreview),
            matching: find.byType(Image),
          ),
        );
        expect(image.fit, BoxFit.cover);
        final removeSize = tester.getSize(_remove);
        expect(removeSize.width, greaterThanOrEqualTo(48));
        expect(removeSize.height, greaterThanOrEqualTo(48));
        expect(find.text('Añade un texto (opcional)'), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        // El teclado no se abre solo.
        expect(field(tester).focusNode.hasFocus, isFalse);
      });
    }

    testWidgets('en inglés', (tester) async {
      listen(tester);
      await pumpWithApp(
        tester,
        const TaskEditorScreen(),
        repo: repo,
        locale: const Locale('en'),
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          imageImporterProvider.overrideWithValue(importer),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Add a photo, image or file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload images'));
      await tester.pumpAndSettle();
      expect(find.text('Add some text (optional)'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove attachment'), findsOneWidget);
    });

    testWidgets('la vista previa llena el hueco sin crecer con la imagen: '
        '"Guardar" sigue en pantalla', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Hacer foto');
      // Decodificada de verdad: solo así cuenta su proporción (1 × 1).
      final image = find.descendant(
        of: find.byType(AttachmentPreview),
        matching: find.byType(Image),
      );
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(image).image,
          tester.element(image),
        ),
      );
      await tester.pumpAndSettle();

      // SliverFillRemaining mide la columna por su altura intrínseca: si la
      // imagen contara, una foto vertical empujaría los botones fuera.
      final preview = tester.renderObject<RenderBox>(
        find.byType(AttachmentPreview),
      );
      expect(
        preview.getMaxIntrinsicHeight(preview.size.width),
        UnaSizes.removeAttachment + 2 * (UnaSpace.s - UnaSpace.xxs),
      );
      final screen = tester.getRect(find.byType(TaskEditorScreen));
      final save = tester.getRect(find.text('Guardar'));
      expect(save.bottom, lessThanOrEqualTo(screen.bottom));
    });

    testWidgets('con imagen se guarda sin texto', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Hacer foto');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.text, isNull);
      expect(saved.attachment!.id, importer.picks.last);
      expect(saved.attachment!.origin, AttachmentOrigin.camera);
      expect(await store.storedIds(), {importer.picks.last});
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('(+) con una imagen elegida la sustituye', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Subir imágenes');
      await pick(tester, 'Hacer foto');

      expect(importState(tester).image!.id, importer.picks.last);
      expect(await store.stagingIds(), {importer.picks.last});
      await tester.enterText(find.byType(TextField), 'Menú');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final saved = (await repo.currentTask())!;
      expect(saved.text, 'Menú');
      expect(saved.attachment!.id, importer.picks.last);
    });

    testWidgets('CA-007-06: "Quitar adjunto" vuelve al editor sin imagen y sin '
        'texto no guarda', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Subir imágenes');
      await tester.tap(_remove);
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentPreview), findsNothing);
      expect(await store.stagingIds(), isEmpty);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(await repo.currentTask(), isNull);
      expect(field(tester).focusNode.hasFocus, isTrue);
    });
  });

  group('CA-007-06: editar la imagen', () {
    testWidgets('se ve la imagen guardada y el teclado no se abre solo', (
      tester,
    ) async {
      final task = await taskWithImage();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      expect(find.byType(AttachmentPreview), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(field(tester).focusNode.hasFocus, isFalse);
    });

    testWidgets('quitar la imagen conserva la posición y el color', (
      tester,
    ) async {
      final task = await taskWithImage();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachment, isNull);
      expect(saved.text, 'Horario');
      expect(saved.rank, task.rank);
      expect(saved.colorKey, task.colorKey);
      expect(await store.storedIds(), isEmpty);
    });

    testWidgets('sustituir la imagen conserva la posición y el color', (
      tester,
    ) async {
      final task = await taskWithImage();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await pick(tester, 'Hacer foto');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachment!.id, importer.picks.last);
      expect(saved.rank, task.rank);
      expect(saved.colorKey, task.colorKey);
      expect(await store.storedIds(), {importer.picks.last});
    });

    testWidgets('añadir una imagen a una tarea de solo texto', (tester) async {
      final task = sampleTask(text: 'Llamar', rank: 'M');
      await repo.insert(task);
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await pick(tester, 'Subir imágenes');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final saved = (await repo.currentTask())!;
      expect(saved.attachment!.id, importer.copiedIds.last);
      expect(saved.rank, task.rank);
    });

    testWidgets('sin texto ni imagen, "Guardar cambios" no guarda', (
      tester,
    ) async {
      final task = await taskWithImage(text: null);
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachment, isNotNull);
      expect(field(tester).focusNode.hasFocus, isTrue);
    });

    testWidgets('"Cancelar" deja la tarea como estaba y borra la nueva', (
      tester,
    ) async {
      final task = await taskWithImage();
      await pumpWithApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    TaskEditorScreen(mode: EditorMode.edit, task: task),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
        repo: repo,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          imageImporterProvider.overrideWithValue(importer),
        ],
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await pick(tester, 'Hacer foto');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsNothing);
      final saved = (await repo.currentTask())!;
      expect(saved.attachment!.id, 'old');
      expect(await store.storedIds(), {'old'});
      expect(await store.stagingIds(), isEmpty);
    });
  });

  group('CA-007-15: "Preparando imagen…"', () {
    testWidgets('aparece a los 400 ms con "Cancelar" (≥ 48 dp), que deja el '
        'editor como estaba', (tester) async {
      await pumpEditor(tester);
      importer.sanitizeDelay = const Duration(seconds: 5);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Preparando imagen…'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Preparando imagen…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final cancel = find.widgetWithText(UnaLinkButton, 'Cancelar');
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));

      await tester.tap(cancel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Preparando imagen…'), findsNothing);
      expect(find.byType(AttachmentPreview), findsNothing);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CA-007-23: con reducir movimiento no se anima', (
      tester,
    ) async {
      await pumpEditor(tester, reduced: true);
      importer.sanitizeDelay = const Duration(seconds: 5);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Preparando imagen…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CA-007-13 / §5: errores', () {
    for (final (error, text) in [
      (
        ImageImportError.unsupportedType,
        'Este tipo de imagen no se admite. Prueba con una foto JPEG, PNG o '
            'HEIC.',
      ),
      (
        ImageImportError.tooLarge,
        'La imagen es demasiado grande (máx. 30 MB).',
      ),
      (
        ImageImportError.tooManyPixels,
        'La imagen tiene demasiada resolución (máx. 64 megapíxeles).',
      ),
      (
        ImageImportError.unreadable,
        'No hemos podido leer esta imagen. Prueba con otra.',
      ),
      (ImageImportError.noSpace, 'Tu teléfono no tiene espacio libre'),
    ]) {
      testWidgets('${error.name}: aviso y el editor queda como estaba', (
        tester,
      ) async {
        await pumpEditor(tester);
        await pick(tester, 'Subir imágenes');
        final before = importState(tester).image;
        importer.copyError = ImageImportFailure(error);
        await pick(tester, 'Subir imágenes');

        expect(find.text(text), findsOneWidget);
        expect(importState(tester).image, before);
        expect(find.byType(AttachmentPreview), findsOneWidget);
      });
    }

    testWidgets('CL-007-1: sin app de cámara', (tester) async {
      await pumpEditor(tester);
      importer.pickError = const ImageImportFailure(ImageImportError.noCamera);
      await pick(tester, 'Hacer foto');
      expect(find.text('No hay ninguna app de cámara disponible.'), findsOne);
      expect(find.byType(AttachmentPreview), findsNothing);
    });
  });

  group('CA-007-22: foco y anuncios', () {
    testWidgets('al volver con una foto: foco en la vista previa y "Foto '
        'añadida"', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Hacer foto');
      expect(announcements, ['Foto añadida']);
      final image = find.descendant(
        of: find.byType(AttachmentPreview),
        matching: find.byType(Image),
      );
      expect(Focus.of(tester.element(image)).hasFocus, isTrue);
    });

    testWidgets('desde la galería: "Imagen añadida"', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Subir imágenes');
      expect(announcements, ['Imagen añadida']);
    });

    testWidgets('al cancelar el selector: foco en (+) y sin anuncio', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.userCancelsPicker = true;
      await pick(tester, 'Subir imágenes');
      expect(announcements, isEmpty);
      expect(plusFocused(tester), isTrue);
    });

    testWidgets('quitar: foco en (+) y "Adjunto quitado"', (tester) async {
      await pumpEditor(tester);
      await pick(tester, 'Subir imágenes');
      announcements.clear();
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(announcements, ['Adjunto quitado']);
      expect(plusFocused(tester), isTrue);
    });

    testWidgets('"Preparando imagen…": foco en "Cancelar" y un anuncio', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpEditor(tester);
      importer
        ..pickDelay = const Duration(seconds: 1)
        ..sanitizeDelay = const Duration(seconds: 5);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(announcements, ['Preparando imagen…']);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cancelar')),
        isSemantics(label: 'Cancelar', isButton: true, hasTapAction: true),
      );
      expect(
        Focus.of(tester.element(find.widgetWithText(UnaLinkButton, 'Cancelar')))
            .hasFocus,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(announcements, ['Preparando imagen…', 'Imagen añadida']);
      semantics.dispose();
    });

    testWidgets('error: foco en (+); el aviso se anuncia solo', (tester) async {
      await pumpEditor(tester);
      importer.copyError = const ImageImportFailure(
        ImageImportError.unreadable,
      );
      await pick(tester, 'Subir imágenes');
      expect(announcements, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(plusFocused(tester), isTrue);
    });
  });

  testWidgets('las medidas del prototipo (tokens)', (tester) async {
    await pumpEditor(tester);
    await pick(tester, 'Subir imágenes');
    final field = tester.getSize(find.byType(TextField));
    expect(field.height, greaterThanOrEqualTo(UnaSizes.attachTextField));
    final preview = tester.getTopLeft(find.byType(AttachmentPreview));
    expect(preview.dx, UnaSpace.ml);
  });
}
