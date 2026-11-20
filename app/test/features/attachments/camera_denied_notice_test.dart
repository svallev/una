// Aviso de la cámara sin permiso (solo iOS; spec 028, CA-028-10 y CL-028-2):
// el aviso `errCameraDenied` con el botón "Abrir Ajustes", accesible como los
// demás avisos de error (CA-007-22). Android nunca lo da (abre la cámara sin
// permisos): su aviso de "sin cámara" sigue igual.
import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/camera_denied_notice.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _message =
    'La cámara no tiene permiso. Puedes darlo en los Ajustes del iPhone.';
const _open = 'Abrir Ajustes';
final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

void main() {
  // Se mide el aviso con el texto al 200 %: hacen falta las fuentes reales.
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  late List<String> announcements;
  late List<int> focusEvents;
  late int opened;
  late bool openResult;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store)
      ..pickError = const ImageImportFailure(ImageImportError.cameraDenied);
    repo = InMemoryTaskRepository();
    opened = 0;
    openResult = true;
  });

  void listen(WidgetTester tester) {
    announcements = [];
    focusEvents = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        if (map['type'] == 'focus') focusEvents.add(map['nodeId']! as int);
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
    bool screenReader = false,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    listen(tester);
    await pumpWithApp(
      tester,
      const TaskEditorScreen(mode: EditorMode.first),
      repo: repo,
      accessibleNavigation: screenReader,
      textScale: textScale,
      size: size,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
        appSettingsOpenerProvider.overrideWithValue(() async {
          opened++;
          return openResult;
        }),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    await tester.ensureVisible(_plus);
    await tester.pumpAndSettle();
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hacer foto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool plusFocused(WidgetTester tester) => tester
      .widget<BrutalButton>(
        find.byWidgetPredicate(
          (w) =>
              w is BrutalButton && w.label == 'Añadir foto, imagen o archivo',
        ),
      )
      .focusNode!
      .hasFocus;

  bool buttonFocused(WidgetTester tester) =>
      Focus.of(tester.element(find.text(_open))).hasFocus;

  AttachmentImportState importState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TaskEditorScreen)))
          .read(attachmentImportProvider);

  /// El nodo del aviso: uno solo, con el texto y el botón.
  SemanticsNode noticeNode(WidgetTester tester) =>
      tester.getSemantics(find.bySemanticsLabel(RegExp('^La cámara')));

  group('CA-028-10: cámara sin permiso', () {
    testWidgets('aviso con "Abrir Ajustes"; el editor queda como estaba', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.enterText(find.byType(TextField), 'Llamar');
      await takePhoto(tester);

      expect(find.text(_message), findsOneWidget);
      expect(find.text(_open), findsOneWidget);
      expect(find.byType(AttachmentPreview), findsNothing);
      expect(importState(tester).error, isNull);
      expect(importState(tester).staged, isEmpty);
      expect(find.text('Llamar'), findsOneWidget);
      expect(opened, 0, reason: 'no abre nada solo');
    });

    testWidgets('"Abrir Ajustes" abre los Ajustes de la app una vez, cierra '
        'el aviso y el foco vuelve a (+)', (tester) async {
      await pumpEditor(tester);
      await takePhoto(tester);
      await tester.tap(find.text(_open));
      await tester.tap(find.text(_open), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text(_message), findsNothing);
      expect(plusFocused(tester), isTrue);
    });

    testWidgets('si los Ajustes no se abren, no pasa nada más (sin error)', (
      tester,
    ) async {
      openResult = false;
      await pumpEditor(tester);
      await takePhoto(tester);
      await tester.tap(find.text(_open));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(AttachmentPreview), findsNothing);
    });

    testWidgets('CL-028-2: volver a tocar "Hacer foto" da el mismo aviso', (
      tester,
    ) async {
      await pumpEditor(tester);
      await takePhoto(tester);
      await tester.tap(find.text(_open));
      await tester.pumpAndSettle();
      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);
      expect(find.text(_open), findsOneWidget);
    });

    testWidgets('los demás errores no llevan el botón (Android sin cambios)', (
      tester,
    ) async {
      importer.pickError = const ImageImportFailure(ImageImportError.noCamera);
      await pumpEditor(tester);
      await takePhoto(tester);
      expect(find.text('No hay ninguna app de cámara disponible.'), findsOne);
      expect(find.text(_open), findsNothing);
      expect(find.byType(CameraDeniedNotice), findsNothing);
    });

    testWidgets('sin lector ni teclado caduca como los demás avisos y el foco '
        'vuelve a (+)', (tester) async {
      await pumpEditor(tester);
      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
      expect(plusFocused(tester), isTrue);
    });
  });

  group('CA-028-10 / CA-007-22: accesible como los demás avisos', () {
    testWidgets('anuncio: el aviso es una región viva y se anuncia solo '
        '(un único anuncio, sin otro explícito)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, screenReader: true);
      await takePhoto(tester);

      SemanticsNode? node = noticeNode(tester);
      var live = false;
      while (node != null && !live) {
        live = node.getSemanticsData().flagsCollection.isLiveRegion;
        node = node.parent;
      }
      expect(live, isTrue, reason: 'dentro de una región viva');
      expect(announcements, isEmpty);
      handle.dispose();
    });

    testWidgets('foco: con lector, el aviso de foco del lector y el foco de '
        'entrada van al aviso, que es un solo nodo con su botón', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, screenReader: true);
      await takePhoto(tester);

      final node = noticeNode(tester);
      final data = node.getSemanticsData();
      expect(data.label, contains(_message));
      expect(data.label, contains(_open));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(focusEvents, isNotEmpty);
      expect(focusEvents.last, node.id);
      expect(buttonFocused(tester), isTrue);
      expect(plusFocused(tester), isFalse);

      // Con lector no caduca: hay tiempo de llegar al botón (WCAG 2.2.1).
      await tester.pump(const Duration(seconds: 30));
      expect(find.text(_message), findsOneWidget);

      // Activarlo con el lector abre los Ajustes.
      tester.semantics.tap(find.semantics.byLabel(RegExp('^La cámara')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(plusFocused(tester), isTrue);
      handle.dispose();
    });

    testWidgets('foco: con teclado, el foco de entrada va al botón y no '
        'caduca', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      try {
        await pumpEditor(tester);
        await takePhoto(tester);
        expect(buttonFocused(tester), isTrue);
        await tester.pump(const Duration(seconds: 30));
        expect(find.text(_message), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, 1);
      } finally {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      }
    });

    testWidgets('el botón mide ≥ 44 en los dos lados', (tester) async {
      await pumpEditor(tester);
      await takePhoto(tester);
      final size = tester.getSize(find.byType(TextButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('al 200 % a ${width.toInt()} dp: el aviso cabe entero, sin '
          'cortar el texto ni el botón, y no tapa (+)', (tester) async {
        await pumpEditor(tester, textScale: 2, size: Size(width, 780));
        await takePhoto(tester);
        expect(tester.takeException(), isNull);

        final card = tester.getRect(
          find
              .descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Material),
              )
              .first,
        );
        final screen = Offset.zero & Size(width, 780);
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(screen.bottom));
        expect(card.overlaps(tester.getRect(_plus)), isFalse);

        for (final text in [_message, _open]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(text),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
          final r = tester.getRect(find.text(text));
          expect(
            card.inflate(0.5).contains(r.topLeft) &&
                card.inflate(0.5).contains(r.bottomRight),
            isTrue,
            reason: '$text $r en $card',
          );
        }
        // El botón no parte su texto: una sola línea.
        final open = tester.renderObject<RenderParagraph>(find.text(_open));
        expect(
          open.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(open.size.width + 0.5),
        );
        final button = tester.getSize(find.byType(TextButton));
        expect(button.height, greaterThanOrEqualTo(44));
      });
    }
  });
}
