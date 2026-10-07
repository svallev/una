import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/attachments/import_notice_banner.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _plusLabel = 'Añadir foto, imagen o archivo';
final _plus = find.bySemanticsLabel(_plusLabel);
final _stack = find.byType(PhotoStack);
final _banner = find.byType(ImportNoticeBanner);

/// Un anuncio recogido: su texto, si fue asertivo y si la pila tenía el foco en
/// ese momento.
typedef _Announcement = ({String message, bool assertive, bool stackFocused});

const _failing = ImageImportFailure(ImageImportError.unsupportedType);

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late List<_Announcement> events;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
  });

  List<String> messages() => [for (final e in events) e.message];

  Future<void> pumpEditor(
    WidgetTester tester, {
    EditorMode mode = EditorMode.first,
    Locale locale = const Locale('es'),
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    events = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          events.add((
            message: data['message']! as String,
            assertive: data['assertiveness'] == Assertiveness.assertive.index,
            stackFocused:
                _stack.evaluate().isNotEmpty &&
                Focus.of(tester.element(_stack)).hasFocus,
          ));
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
    await pumpWithApp(
      tester,
      TaskEditorScreen(mode: mode),
      repo: InMemoryTaskRepository(),
      locale: locale,
      textScale: textScale,
      size: size,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Elige con "Subir imágenes" y deja pasar el anuncio retrasado.
  Future<void> pick(
    WidgetTester tester, {
    bool settle = true,
    bool english = false,
  }) async {
    await tester.tap(
      english ? find.bySemanticsLabel('Add a photo, image or file') : _plus,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(english ? 'Upload images' : 'Subir imágenes'));
    await tester.pumpAndSettle();
    if (settle) await tester.pump(const Duration(milliseconds: 400));
  }

  AttachmentImportState importState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TaskEditorScreen)))
          .read(attachmentImportProvider);

  /// Fallan las fotos de esos números (0 a 9) de lo que devuelve el selector.
  void failPhotos(List<int> indexes) {
    for (final i in indexes) {
      importer.copyErrorsByToken['content://many-$i'] = _failing;
    }
  }

  const composedEs =
      'Solo se usarán las 10 primeras. 8 fotos añadidas. '
      'No se pudieron añadir 2 fotos.';

  group('CA-016-21: un solo aviso y un solo anuncio con el texto exacto', () {
    testWidgets('más de 10 y fallidas (ES): un aviso y un anuncio con el mismo '
        'texto, sin eco', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEditor(tester);
      importer.manyTotal = 12;
      failPhotos([0, 3]);
      await pick(tester);

      expect(_banner, findsOneWidget);
      expect(find.text(composedEs), findsOneWidget);
      expect(messages(), [composedEs]);
      // Ni el aviso ni la pila lo repiten por su cuenta: no es una región
      // viva (haría eco con el anuncio) ni un SnackBar (caduca).
      expect(find.byType(SnackBar), findsNothing);
      final node = tester.getSemantics(find.text(composedEs));
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      expect(node.getSemanticsData().label, composedEs);
      semantics.dispose();
    });

    testWidgets('más de 10 y fallidas (EN)', (tester) async {
      await pumpEditor(tester, locale: const Locale('en'));
      importer.manyTotal = 12;
      failPhotos([0, 3]);
      await pick(tester, english: true);

      const text =
          'Only the first 10 will be used. 8 photos added. '
          "2 photos couldn't be added.";
      expect(find.text(text), findsOneWidget);
      expect(messages(), [text]);
    });

    testWidgets('solo más de 10: el límite y las añadidas, con punto', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);

      const text = 'Solo se usarán las 10 primeras. 10 fotos añadidas.';
      expect(find.text(text), findsOneWidget);
      expect(messages(), [text]);
    });

    testWidgets('solo fallidas: las añadidas y las omitidas (queda una: la '
        '007 con aviso)', (tester) async {
      await pumpEditor(tester);
      failPhotos([0, 2]);
      await pick(tester);

      const text = '1 foto añadida. No se pudieron añadir 2 fotos.';
      expect(_stack, findsNothing);
      expect(find.text(text), findsOneWidget);
      expect(messages(), [text]);
    });

    testWidgets('una fallida de tres: singular en ES y EN', (tester) async {
      await pumpEditor(tester);
      failPhotos([1]);
      await pick(tester);
      const es = '2 fotos añadidas. No se pudo añadir 1 foto.';
      expect(find.text(es), findsOneWidget);
      expect(messages(), [es]);
    });

    testWidgets('sin avisos: ningún aviso y el anuncio de siempre', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester);

      expect(_banner, findsNothing);
      expect(messages(), ['3 fotos añadidas']);
    });

    testWidgets('fallan todas: el SnackBar de hoy y ningún aviso', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.copyError = _failing;
      await pick(tester);

      expect(_banner, findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(messages(), isEmpty);
    });
  });

  group('CA-016-21: el aviso no caduca y se quita al cambiar el grupo', () {
    testWidgets('no caduca solo', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      failPhotos([0, 3]);
      await pick(tester);
      await tester.pump(const Duration(minutes: 2));
      expect(_banner, findsOneWidget);
      expect(find.text(composedEs), findsOneWidget);
    });

    testWidgets('"Quitar adjunto" lo quita', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      expect(_banner, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Quitar adjunto'));
      await tester.pumpAndSettle();
      expect(_banner, findsNothing);
      expect(importState(tester).notice, isNull);
    });

    testWidgets('cambiar el grupo lo sustituye por el del nuevo (o lo quita)', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      expect(find.textContaining('Solo se usarán'), findsOneWidget);

      // El nuevo grupo no trae avisos.
      importer.manyTotal = 3;
      await pick(tester);
      expect(_banner, findsNothing);
      expect(find.text('3 fotos'), findsOneWidget);
    });

    testWidgets('una imagen suelta nueva lo quita', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      importer.manyTotal = 1;
      await pick(tester);
      expect(_banner, findsNothing);
    });

    testWidgets('cancelar el selector lo conserva (el grupo no cambia)', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      importer.userCancelsPicker = true;
      await pick(tester);
      expect(_banner, findsOneWidget);
    });

    testWidgets('al guardar se quita', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(_banner, findsNothing);
      expect(importState(tester).notice, isNull);
    });

    testWidgets('al salir del editor se quita (el estado se descarta)', (
      tester,
    ) async {
      await pumpEditor(tester, mode: EditorMode.create);
      importer.manyTotal = 12;
      await pick(tester);
      expect(_banner, findsOneWidget);
      await tester.tap(find.text('Cancelar').first);
      await tester.pumpAndSettle();
      // El estado es autoDispose: el aviso no sobrevive al editor.
      expect(_banner, findsNothing);
    });
  });

  group('CA-016-22: texto grande', () {
    testWidgets('al 200 % a 360 dp se ve entero y crece con el texto', (
      tester,
    ) async {
      await pumpEditor(tester, textScale: 2.0, size: const Size(360, 640));
      importer.manyTotal = 12;
      failPhotos([0, 3]);
      await pick(tester);

      expect(tester.takeException(), isNull);
      final screen = tester.getRect(find.byType(TaskEditorScreen));
      final text = find.text(composedEs);
      expect(text, findsOneWidget);
      final rect = tester.getRect(text);
      expect(rect.left, greaterThanOrEqualTo(screen.left));
      expect(rect.right, lessThanOrEqualTo(screen.right));
      // Con 2 líneas o más a 200 %: el aviso mide más que una línea.
      expect(rect.height, greaterThan(40));
      // Encima de los botones, sin taparlos.
      final buttons = tester.getRect(find.text('Guardar'));
      expect(rect.bottom, lessThanOrEqualTo(buttons.top));
      expect(buttons.bottom, lessThanOrEqualTo(screen.bottom));
    });
  });

  group('CA-016-21: foco y anuncio, uno solo y tras el foco', () {
    testWidgets('el anuncio es asertivo y sale con el foco ya en la pila, '
        'no antes', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester, settle: false);
      // El selector ha vuelto y la pila tiene el foco; el anuncio espera.
      expect(Focus.of(tester.element(_stack)).hasFocus, isTrue);
      expect(events, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));
      expect(events, hasLength(1));
      expect(events.single.assertive, isTrue);
      expect(events.single.stackFocused, isTrue);
    });

    testWidgets('"Preparando" no queda leyéndose: el compuesto va después, '
        'asertivo', (tester) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(messages(), [
        'Preparando foto 1 de 10…',
        'Solo se usarán las 10 primeras. 10 fotos añadidas.',
      ]);
      expect(events.last.assertive, isTrue);
      expect(events.last.stackFocused, isTrue);
    });

    testWidgets('si se quita el grupo antes de que salga, no se anuncia', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester, settle: false);
      await tester.tap(find.bySemanticsLabel('Quitar adjunto'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(messages(), ['Adjunto quitado']);
    });

    testWidgets('todas fallan: foco en (+), sin anuncio propio (el error es el '
        'SnackBar)', (tester) async {
      await pumpEditor(tester);
      importer.copyError = _failing;
      await pick(tester);
      expect(_plusFocused(tester), isTrue);
      expect(messages(), isEmpty);
    });

    testWidgets('cancela el selector: foco en (+) y ningún anuncio', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.userCancelsPicker = true;
      await pick(tester);
      expect(_plusFocused(tester), isTrue);
      expect(messages(), isEmpty);
    });

    testWidgets('sin espacio: foco en (+) y el error de siempre', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.freeSpaceBytes = 1;
      await pick(tester);
      expect(find.text('Tu teléfono no tiene espacio libre'), findsOneWidget);
      expect(_banner, findsNothing);
      expect(_plusFocused(tester), isTrue);
      expect(messages(), isEmpty);
    });

    testWidgets('cancela "Preparando": foco en (+) y ningún anuncio nuevo', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(UnaLinkButton, 'Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(messages(), ['Preparando foto 1 de 3…']);
      expect(_banner, findsNothing);
    });

    testWidgets('quitar adjunto: foco en (+) y "Adjunto quitado"', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester);
      events.clear();
      await tester.tap(find.bySemanticsLabel('Quitar adjunto'));
      await tester.pumpAndSettle();
      expect(messages(), ['Adjunto quitado']);
      expect(_plusFocused(tester), isTrue);
    });

    testWidgets('CL-016-6b: el sistema vació la preparación: aviso y anuncio '
        'iguales, una vez', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      events.clear();
      final ids = [for (final s in importState(tester).staged) s.id];
      await store.deleteStaging(ids[1]);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      const text = 'No se pudo añadir 1 foto.';
      expect(messages(), [text]);
      expect(find.text(text), findsOneWidget);
    });
  });
}

bool _plusFocused(WidgetTester tester) => tester
    .widget<BrutalButton>(
      find.byWidgetPredicate((w) => w is BrutalButton && w.label == _plusLabel),
    )
    .focusNode!
    .hasFocus;
