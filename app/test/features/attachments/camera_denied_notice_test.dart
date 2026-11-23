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
import 'package:app/ui/ios_back_gesture.dart';
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

    // A-M1 (revisores de la 028): con lector el aviso no caduca; uno posterior
    // no puede quedarse en cola detrás de él, sin verse ni anunciarse.
    testWidgets('CA-028-10 / CA-007-22: con lector, otro error con el aviso '
        'de la cámara a la vista lo sustituye: se ve y está en región viva', (
      tester,
    ) async {
      const noCamera = 'No hay ninguna app de cámara disponible.';
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, screenReader: true);
      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);

      importer.pickError = const ImageImportFailure(ImageImportError.noCamera);
      await takePhoto(tester);
      expect(find.text(noCamera), findsOneWidget);
      expect(find.text(_message), findsNothing);
      SemanticsNode? node = tester.getSemantics(find.text(noCamera));
      var live = false;
      while (node != null && !live) {
        live = node.getSemanticsData().flagsCollection.isLiveRegion;
        node = node.parent;
      }
      expect(live, isTrue, reason: 'dentro de una región viva');

      // Y el de la cámara no vuelve al irse este.
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
      handle.dispose();
    });

    testWidgets('CL-028-2: con lector, volver a tocar "Hacer foto" con el '
        'aviso a la vista da un aviso nuevo, que toma el foco; no quedan dos', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, screenReader: true);
      await takePhoto(tester);
      expect(buttonFocused(tester), isTrue);
      final firstEvents = focusEvents.length;

      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);
      expect(buttonFocused(tester), isTrue, reason: 'el aviso nuevo');
      expect(focusEvents.length, greaterThan(firstEvents));
      expect(focusEvents.last, noticeNode(tester).id);

      // Al cerrarlo no sale otro que esperaba en cola.
      await tester.tap(find.text(_open));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
      expect(plusFocused(tester), isTrue);
      handle.dispose();
    });

    // A-M2: con teclado el aviso no caduca; Escape lo cierra (sin un botón
    // "Cerrar" visible: sigue siendo un solo nodo).
    testWidgets('CA-028-10: con teclado, Escape cierra el aviso y el foco '
        'vuelve a (+), sin abrir los Ajustes', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      try {
        await pumpEditor(tester);
        await takePhoto(tester);
        expect(buttonFocused(tester), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(_message), findsNothing);
        expect(find.byType(CameraDeniedNotice), findsNothing);
        expect(plusFocused(tester), isTrue);
        expect(opened, 0);
        expect(find.byType(TaskEditorScreen), findsOneWidget);
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

  // Decisión del propietario (2026-11-20): el aviso es del editor; al salir de
  // él, por la vía que sea, se cierra, también si no caduca (lector o teclado).
  group('CA-028-10: al salir del editor el aviso se cierra', () {
    Future<void> openEditor(
      WidgetTester tester, {
      bool screenReader = true,
      Widget? home,
    }) async {
      listen(tester);
      await pumpWithApp(
        tester,
        home ?? const _Host(),
        repo: repo,
        accessibleNavigation: screenReader,
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
      if (home == null) {
        await tester.tap(find.text(_Host.open));
        await tester.pumpAndSettle();
      }
      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);
    }

    /// Se cierra al salir, no cuando la ruta termina de irse: mientras la
    /// pantalla de debajo vuelve, el aviso ya está bajando (con lector,
    /// `ScaffoldMessenger` lo quita sin animación: ya no está).
    Future<void> expectClosingNow(WidgetTester tester) async {
      await tester.pump();
      final bars = tester.widgetList<SnackBar>(
        find.byType(SnackBar, skipOffstage: false),
      );
      for (final bar in bars) {
        expect(bar.animation!.status, AnimationStatus.reverse);
      }
    }

    void expectGone(WidgetTester tester) {
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(find.text(_message, skipOffstage: false), findsNothing);
      expect(
        find.byType(CameraDeniedNotice, skipOffstage: false),
        findsNothing,
      );
      expect(opened, 0);
    }

    testWidgets('con lector, atrás del sistema', (tester) async {
      await openEditor(tester);
      await tester.binding.handlePopRoute();
      await expectClosingNow(tester);
      await tester.pumpAndSettle();
      expectGone(tester);
      // Y no vuelve más tarde (no caducaba).
      await tester.pump(const Duration(seconds: 30));
      expectGone(tester);
      expect(find.text(_Host.open), findsOneWidget);
    });

    testWidgets('CL-028-2: con lector, tras un segundo aviso de la cámara, '
        'atrás también lo cierra', (tester) async {
      await openEditor(tester);
      await takePhoto(tester);
      expect(find.text(_message), findsOneWidget);
      await tester.binding.handlePopRoute();
      await expectClosingNow(tester);
      await tester.pumpAndSettle();
      expectGone(tester);
      await tester.pump(const Duration(seconds: 30));
      expectGone(tester);
    });

    testWidgets('con lector, gesto atrás de iOS', (tester) async {
      await openEditor(tester);
      await tester.timedDragFrom(
        const Offset(5, 300),
        const Offset(380, 0),
        const Duration(milliseconds: 600),
      );
      await expectClosingNow(tester);
      await tester.pumpAndSettle();
      expectGone(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('con lector, al guardar', (tester) async {
      await openEditor(tester);
      await tester.enterText(find.byType(TextField), 'Llamar');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await expectClosingNow(tester);
      await tester.pumpAndSettle();
      expectGone(tester);
      expect(await repo.currentTask(), isNotNull);
    });

    testWidgets('con teclado, la ruta se cierra desde el código', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      try {
        await openEditor(tester, screenReader: false);
        expect(buttonFocused(tester), isTrue);
        Navigator.of(tester.element(find.byType(TaskEditorScreen))).pop();
        await expectClosingNow(tester);
        await tester.pumpAndSettle();
        expectGone(tester);
      } finally {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      }
    });

    testWidgets('con lector, el editor se quita sin cerrar ninguna ruta '
        '(primera tarea: la pantalla cambia debajo)', (tester) async {
      final showEditor = ValueNotifier(true);
      addTearDown(showEditor.dispose);
      await openEditor(
        tester,
        home: ValueListenableBuilder<bool>(
          valueListenable: showEditor,
          builder: (_, show, _) => show
              ? const TaskEditorScreen(mode: EditorMode.first)
              : const Scaffold(body: Text(_Host.open)),
        ),
      );
      showEditor.value = false;
      await tester.pumpAndSettle();
      expectGone(tester);
    });
  });
}

/// Una pantalla de debajo con un botón que abre el editor en su ruta, como
/// "Todo hecho." o el menú de la tarea.
class _Host extends StatelessWidget {
  const _Host();

  static const open = 'Abrir editor';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          UnaMaterialPageRoute<void>(builder: (_) => const TaskEditorScreen()),
        ),
        child: const Text(open),
      ),
    ),
  );
}
