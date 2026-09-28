import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/import_error_text.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_labels.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fonts.dart';
import '../../support/pdfrx.dart';
import '../../support/pump_app.dart';

/// Móvil pequeño de CA-008-22.
const _phone = Size(360, 780);

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

/// Pautas de accesibilidad de Flutter: objetivos de 48 dp (Android) y
/// etiquetados. El contraste lo garantiza `validate-tokens` (CLAUDE.md: con
/// las fuentes reales, `textContrastGuideline` falla en falso en texto
/// pequeño).
Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// [finder] se ve entero dentro de la pantalla (nada se corta).
void _inside(WidgetTester tester, Finder finder) {
  final r = tester.getRect(finder);
  final area = (Offset.zero & _phone).inflate(0.5);
  expect(
    area.contains(r.topLeft) && area.contains(r.bottomRight),
    isTrue,
    reason: '$finder $r',
  );
}

/// [text] se dibuja entero: sin recortar líneas ni "…".
void _whole(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse, reason: text);
  _inside(tester, finder);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initPdfrxForTests();
  });

  late List<String> announcements;

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

  group('Con el visor de verdad (PDFium)', () {
    /// pdfrx deja temporizadores propios: se desmonta y se dejan correr.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }

    /// El motor trabaja fuera del reloj falso de los tests.
    Future<void> settle(WidgetTester tester, [int rounds = 60]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<List<LinkTarget>> pumpPdf(
      WidgetTester tester,
      String name, {
      String? taskLabel,
      Map<CustomSemanticsAction, VoidCallback> actions = const {},
      GlobalKey<NavigatorState>? navigator,
      String? caption,
      Size size = const Size(390, 700),
      double textScale = 1,
    }) async {
      final links = <LinkTarget>[];
      listen(tester);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TaskPdfView(
            args: TaskPdfArgs(
              source: (
                path: null,
                bytes: base64Decode(pdfFixtures[name]!),
                key: name,
              ),
              screen: MemoryImage(tinyImage),
              caption: caption,
              captionColor: const Color(0xFFFFE55C),
              initialPosition: PdfPosition.start,
              onPosition: (_) {},
              onLink: (target) {
                links.add(target);
                final context = navigator?.currentContext;
                if (context != null) showLinkConfirmSheet(context, target);
              },
              taskLabel: taskLabel,
              actions: actions,
            ),
          ),
        ),
      );
      // El motor carga el documento, el texto y los enlaces fuera del reloj
      // falso de los tests.
      await settle(tester, 200);
      return links;
    }

    /// Etiquetas de las acciones propias del nodo con [label].
    List<String> actionsOf(WidgetTester tester, Pattern label) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      final data = node.getSemanticsData();
      return [
        for (final id in data.customSemanticsActionIds ?? const <int>[])
          CustomSemanticsAction.getAction(id)!.label ?? '',
      ];
    }

    /// La etiqueta del lector del widget con el foco del teclado.
    String? focusedLabel() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return null;
      String? label;
      void visit(Element e) {
        if (label != null) return;
        final w = e.widget;
        if (w is Semantics && w.properties.label != null) {
          label = w.properties.label;
          return;
        }
        e.visitChildren(visit);
      }

      (context as Element).visitChildren(visit);
      return label;
    }

    testWidgets(
      'CA-008-20: cada página se lee "Página n de total" y su texto',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpPdf(tester, 'pages_20.pdf');
        expect(
          find.bySemanticsLabel(RegExp(r'^Página 1 de 20\. Pagina 1 de 20')),
          findsOneWidget,
        );
        // No queda la etiqueta inglesa del visor.
        expect(find.bySemanticsLabel(RegExp(r'^Page \d')), findsNothing);
        await unmount(tester);
        handle.dispose();
      },
    );

    // Fallo visto en el golden `current_task_pdf_es_x2.0` (T-008-24): el alto
    // de la banda se medía con la escala limitada y el texto se dibujaba con
    // la del sistema, así que las páginas tapaban la última línea. Los tests
    // de T-008-23 usaban el visor sustituido, que no dibuja la banda.
    for (final (width, scale, text) in [
      (390.0, 1.0, 'Programa del congreso'),
      (390.0, 2.0, 'Programa del congreso'),
      (360.0, 2.0, 'Programa del congreso'),
      (
        360.0,
        2.0,
        'Revisar el programa del congreso de otoño en Valencia y '
            'confirmar la sala',
      ),
      (
        390.0,
        1.0,
        'Revisar el programa del congreso de otoño en Valencia y '
            'confirmar la sala',
      ),
    ]) {
      testWidgets('CA-008-08 / CA-008-22: con el texto al '
          '${(scale * 100).round()} % en $width dp, la banda muestra "$text" '
          'entero, por encima de la primera página', (tester) async {
        await pumpPdf(
          tester,
          'pages_20.pdf',
          caption: text,
          size: Size(width, 780),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final band = tester.getRect(find.byType(PdfCaptionBand));
        final finder = find.text(text);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        // Alto que necesita el texto con la escala con la que se dibuja.
        final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
        final top = tester.getRect(finder).top;
        expect(
          top + needed,
          lessThanOrEqualTo(band.bottom - UnaBorders.strongWidth + 0.5),
          reason: 'texto $top + $needed, banda $band',
        );
        expect(paragraph.size.height, greaterThanOrEqualTo(needed - 0.5));
        // La primera versión de pantalla (primer fotograma) mide lo mismo:
        // la banda no salta al quitarla.
        final face = PdfCaptionBand.heightFor(
          text,
          width,
          PdfCaptionBand.scalerOf(tester.element(finder)),
          TextDirection.ltr,
        );
        expect(band.height, moreOrLessEquals(face, epsilon: 0.5));
        await unmount(tester);
      });
    }

    testWidgets('CA-008-08 / CA-008-22: con el texto al 200 % en 360 dp, la '
        'banda del primer fotograma mide lo mismo que la del visor', (
      tester,
    ) async {
      const text = 'Programa del congreso';
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: TaskPdfFace(
            args: TaskPdfArgs(
              source: (path: null, bytes: null, key: 'face'),
              screen: MemoryImage(tinyImage),
              caption: text,
              captionColor: const Color(0xFFFFE55C),
              initialPosition: PdfPosition.start,
              onPosition: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final finder = find.text(text);
      final viewerBand = PdfCaptionBand.heightFor(
        text,
        360,
        PdfCaptionBand.scalerOf(tester.element(finder)),
        TextDirection.ltr,
      );
      expect(
        tester.getSize(find.byType(PdfCaptionBand)).height,
        moreOrLessEquals(viewerBand, epsilon: 0.5),
      );
    });

    testWidgets('CA-008-20 / CA-008-11: en horizontal, la página visible se '
        'lee con el prefijo "Tarea actual"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPdf(
        tester,
        'pages_20.pdf',
        taskLabel: 'Tarea actual: Programa',
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Tarea actual: Programa\. Página 1 de 20\. Pagina 1'),
        ),
        findsOneWidget,
      );
      // Solo la primera página visible.
      expect(find.bySemanticsLabel(RegExp('Tarea actual')), findsOneWidget);
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-20: si el texto acaba en punto, el prefijo no dice '
        '"..", sino "Programa del congreso. Página 1"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPdf(
        tester,
        'pages_20.pdf',
        taskLabel: 'Tarea actual: Programa del congreso.',
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Tarea actual: Programa del congreso\. Página 1 de 20'),
        ),
        findsOneWidget,
      );
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-20: la página que enfoca el lector lleva las acciones '
        'en su orden (TalkBack solo ofrece las del nodo enfocado)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final done = <String>[];
      await pumpPdf(
        tester,
        'pages_20.pdf',
        actions: {
          const CustomSemanticsAction(label: 'Completar tarea'): () =>
              done.add('completar'),
          const CustomSemanticsAction(label: 'Eliminar tarea'): () =>
              done.add('eliminar'),
        },
      );
      final page1 = RegExp(r'^Página 1 de 20');
      // A ×1 y en la primera página: sin "Página anterior", "Reducir" ni
      // "Ajustar al ancho".
      expect(actionsOf(tester, page1), [
        'Completar tarea',
        'Eliminar tarea',
        'Página siguiente',
        'Ampliar',
      ]);
      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Completar tarea'),
      );
      expect(done, ['completar']);
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-21: "Ampliar", "Reducir" y "Ajustar al ancho" anuncian '
        '"Zoom n %" y dejan el foco donde estaba', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPdf(tester, 'pages_20.pdf');
      final page1 = RegExp(r'^Página 1 de 20');
      final before = tester.getSemantics(find.bySemanticsLabel(page1)).id;
      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Ampliar'),
      );
      await settle(tester);
      expect(announcements, ['Zoom 150 %']);
      // El mismo nodo sigue a la vista (el foco no se mueve).
      expect(tester.getSemantics(find.bySemanticsLabel(page1)).id, before);
      expect(actionsOf(tester, page1), [
        'Página siguiente',
        'Ampliar',
        'Reducir',
        'Ajustar al ancho',
      ]);
      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Ajustar al ancho'),
      );
      await settle(tester);
      expect(announcements, ['Zoom 150 %', 'Zoom 100 %']);
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-21: "Página siguiente" lleva a la página 2 y la '
        'anuncia', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPdf(tester, 'pages_20.pdf');
      tester.semantics.customAction(
        find.semantics.byLabel(RegExp(r'^Página 1 de 20')),
        const CustomSemanticsAction(label: 'Página siguiente'),
      );
      await settle(tester);
      expect(announcements, ['Página 2 de 20']);
      expect(
        find.bySemanticsLabel(RegExp(r'^Página 2 de 20\. Pagina 2')),
        findsOneWidget,
      );
      expect(actionsOf(tester, RegExp(r'^Página 2 de 20')), [
        'Página siguiente',
        'Página anterior',
        'Ampliar',
      ]);
      // Otra vez: a la 3 (no se queda en la 2 por un redondeo).
      tester.semantics.customAction(
        find.semantics.byLabel(RegExp(r'^Página 2 de 20')),
        const CustomSemanticsAction(label: 'Página siguiente'),
      );
      await settle(tester);
      expect(announcements, ['Página 2 de 20', 'Página 3 de 20']);
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-22: con teclado, "+", "-" y "0" hacen zoom y Av Pág '
        'pasa de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPdf(tester, 'pages_20.pdf');
      for (var i = 0; i < 5; i++) {
        if (FocusManager.instance.primaryFocus?.debugLabel == 'pdf') break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'pdf');
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await settle(tester);
      expect(announcements, [
        'Zoom 150 %',
        'Zoom 250 %',
        'Zoom 150 %',
        'Zoom 100 %',
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      // Dos pantallas (0,8 del alto cada una): la página 1 ya no se ve.
      expect(find.bySemanticsLabel(RegExp(r'^Página 1 de 20')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Página 3 de 20')), findsOneWidget);
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-12/20: los enlaces que hacen algo se leen y se '
        'activan; los peligrosos no aparecen', (tester) async {
      final handle = tester.ensureSemantics();
      final links = await pumpPdf(tester, 'links.pdf');
      // Exactamente estos: ni los peligrosos (javascript:, file:, intent:,
      // data:, lanzar) ni el de usuario:contraseña (T-5). example.com sale dos
      // veces: el normal y el que lleva un carácter de dirección en el camino.
      final linkLabels = find.semantics
          .byPredicate((n) => n.label.startsWith('Enlace a '))
          .evaluate()
          .map((n) => n.label)
          .toList();
      expect(linkLabels, [
        'Enlace a example.com',
        'Enlace a example.org',
        'Enlace a info@example.com',
        'Enlace a +34600000000',
        'Enlace a example.com',
        'Enlace a xn--pple-43d.com',
        'Enlace a la página 2',
      ]);

      tester.semantics.tap(
        find.semantics.byLabel('Enlace a example.com').first,
      );
      await tester.pump();
      expect(links.single, isA<WebLink>());
      expect((links.single as WebLink).host, 'example.com');
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-12/20: las URL escritas en el texto (sin enlace en el '
        'PDF) son enlaces con el dedo y también para el lector', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final links = await pumpPdf(tester, 'text_url.pdf');
      expect(
        find.semantics
            .byPredicate((n) => n.label.startsWith('Enlace a '))
            .evaluate()
            .map((n) => n.label),
        ['Enlace a example.net'],
      );
      final c = tester.getCenter(find.bySemanticsLabel('Enlace a example.net'));
      await tester.tapAt(c);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect((links.single as WebLink).host, 'example.net');
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-12: los enlaces no se marcan sobre la página '
        '(decisión del propietario, 2026-09-28)', (tester) async {
      await pumpPdf(tester, 'links.pdf');
      final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
      expect(viewer.params.linkHandlerParams?.linkColor, Colors.transparent);
      await unmount(tester);
    });

    testWidgets('CA-008-12: un enlace tocado con el dedo llega a la app (la '
        'capa de lectura no se queda los toques)', (tester) async {
      final handle = tester.ensureSemantics();
      final links = await pumpPdf(tester, 'links.pdf');
      final c = tester.getCenter(find.bySemanticsLabel('Enlace a example.org'));
      await tester.tapAt(c);
      // El visor espera por si es un doble toque.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect(links.single, isA<WebLink>());
      expect((links.single as WebLink).host, 'example.org');
      await unmount(tester);
      handle.dispose();
    });

    testWidgets('CA-008-21/22: Tab llega al enlace, Enter abre la '
        'confirmación con el foco en "Cancelar" y al cerrarla el foco vuelve '
        'al enlace', (tester) async {
      final handle = tester.ensureSemantics();
      final navigator = GlobalKey<NavigatorState>();
      await pumpPdf(tester, 'links.pdf', navigator: navigator);
      for (var i = 0; i < 6; i++) {
        if (focusedLabel() == 'Enlace a example.org') break;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusedLabel(), 'Enlace a example.org');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsOneWidget);
      expect(focusedLabel(), 'Cancelar');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsNothing);
      expect(focusedLabel(), 'Enlace a example.org');
      await unmount(tester);
      handle.dispose();
    });
  });

  test('CA-008-20: si el texto acaba en punto, las lecturas no dicen ".."', () {
    final l10n = lookupAppLocalizations(const Locale('es'));
    expect(readingText('Programa del congreso.'), 'Programa del congreso');
    expect(readingText('Espera...'), 'Espera');
    expect(readingText('¿Vienes?'), '¿Vienes?');
    expect(readingText('...'), '...');
    final base = sampleTask(text: 'Programa del congreso.');
    final pdf = base.withContent(
      base.text,
      Attachment(
        id: 'p1',
        kind: AttachmentKind.pdf,
        origin: AttachmentOrigin.file,
        mime: 'application/pdf',
        byteSize: 1000,
        width: 595,
        height: 842,
        createdAt: DateTime.utc(2026),
        originalName: 'Programa.pdf',
        pageCount: 1,
      ),
      base.updatedAt,
    );
    expect(taskReading(l10n, pdf), 'Programa del congreso. Con PDF');
  });

  group('Con el visor sustituido', () {
    late MemoryAttachmentStore store;
    late FakePdfImporter pdfs;
    late InMemoryTaskRepository repo;

    setUp(() {
      store = MemoryAttachmentStore();
      pdfs = FakePdfImporter(store);
      repo = InMemoryTaskRepository();
      taskPdfCalls.clear();
    });

    List<Override> overrides() => [
      attachmentStoreProvider.overrideWithValue(store),
      imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
      pdfImporterProvider.overrideWithValue(pdfs),
      ...fakePdfViews,
    ];

    Future<Task> pdfTask({
      String? text = 'Programa del congreso de otoño en Valencia.',
      String name =
          'Programa completo del congreso internacional de otoño 2026.pdf',
    }) async {
      store
        ..putStaging(
          'p1',
          'document.pdf',
          Uint8List.fromList('%PDF-1.7'.codeUnits),
        )
        ..putStaging('p1', 'screen.jpg', tinyImage);
      final attachment = await store.commit(
        StagedPdf(
          id: 'p1',
          byteSize: 9800000,
          pageCount: 20,
          width: 595,
          height: 842,
          originalName: name,
        ),
        DateTime.utc(2026, 9, 27),
      );
      final base = sampleTask(id: 't1', text: text ?? 'x');
      return base.withContent(text, attachment, base.updatedAt);
    }

    Future<void> pumpEditorBig(WidgetTester tester, {Task? task}) async {
      listen(tester);
      await pumpWithApp(
        tester,
        TaskEditorScreen(
          mode: task == null ? EditorMode.first : EditorMode.edit,
          task: task,
        ),
        repo: repo,
        size: _phone,
        textScale: 2,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickFile(WidgetTester tester) async {
      await tester.ensureVisible(_plus);
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir archivo'));
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

    group('CA-008-22: texto al 200 % en 360 dp', () {
      testWidgets('editor con PDF: la franja con el nombre en una línea con '
          '"…", "Quitar adjunto" ≥ 48 dp', (tester) async {
        final handle = tester.ensureSemantics();
        pdfs.pickedName =
            'Programa completo del congreso internacional de otoño 2026.pdf';
        await pumpEditorBig(tester);
        await pickFile(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final name = find.text(pdfs.pickedName!);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(paragraph.maxLines, 1);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        _inside(tester, find.byType(PdfStrip));
        final remove = tester.getSize(find.bySemanticsLabel('Quitar adjunto'));
        expect(remove.shortestSide, greaterThanOrEqualTo(48));
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('"Preparando PDF…" se ve entero, con "Cancelar" ≥ 48 dp', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpEditorBig(tester);
        pdfs.inspectDelay = const Duration(seconds: 5);
        await pickFile(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        _whole(tester, 'Preparando PDF…');
        final cancel = find.bySemanticsLabel('Cancelar');
        _inside(tester, cancel);
        expect(tester.getSize(cancel).shortestSide, greaterThanOrEqualTo(48));
        await _meetsGuidelines(tester);
        await tester.pump(const Duration(seconds: 5));
        handle.dispose();
      });

      for (final error in PdfImportError.values) {
        testWidgets('el error "${error.name}" se ve entero y no tapa el (+)', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          pdfs.inspectError = PdfImportFailure(error);
          await pumpEditorBig(tester);
          await pickFile(tester);
          await tester.pumpAndSettle();
          final l10n = lookupAppLocalizations(const Locale('es'));
          _whole(tester, importErrorText(l10n, error));
          final snack = tester.getRect(
            find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(snack.overlaps(tester.getRect(_plus)), isFalse);
          await _meetsGuidelines(tester);
          handle.dispose();
        });
      }

      testWidgets('tarea actual con PDF: la franja cabe con "…" y los botones '
          'miden ≥ 48 dp', (tester) async {
        final handle = tester.ensureSemantics();
        await repo.insert(await pdfTask());
        await pumpUnaApp(tester, repo: repo, overrides: overrides());
        tester.view.physicalSize = _phone;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _inside(tester, find.byType(PdfStrip));
        final name = tester.renderObject<RenderParagraph>(
          find.text(
            'Programa completo del congreso internacional de otoño 2026.pdf',
          ),
        );
        expect(name.overflow, TextOverflow.ellipsis);
        _inside(tester, find.byType(HoldToCompleteButton));
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('confirmación de un enlace largo: la pregunta entera, con '
          'saltos de línea, y los dos botones ≥ 48 dp', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithApp(
          tester,
          CurrentTaskScreen(task: await pdfTask()),
          repo: repo,
          size: _phone,
          textScale: 2,
          overrides: overrides(),
        );
        await tester.pumpAndSettle();
        const host =
            'servicio-de-inscripciones.congreso-internacional.example.com';
        taskPdfCalls.last.onLink!(WebLink(Uri.parse('https://$host/a'), host));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final question = '¿Abrir $host en el navegador?';
        await tester.ensureVisible(find.text(question));
        await tester.pumpAndSettle();
        _whole(tester, question);
        for (final label in ['Abrir', 'Cancelar']) {
          final button = find.bySemanticsLabel(label);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          _inside(tester, button);
          expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
        }
        await _meetsGuidelines(tester);
        handle.dispose();
      });

      testWidgets('"Adjunto no disponible" con PDF: tarjeta y acción enteras', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await repo.insert(await pdfTask());
        store.removeFile('p1', 'document.pdf');
        await pumpUnaApp(tester, repo: repo, overrides: overrides());
        tester.view.physicalSize = _phone;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MissingAttachmentCard), findsOneWidget);
        await tester.ensureVisible(find.text('Quitar adjunto'));
        await tester.pumpAndSettle();
        final action = tester.getRect(find.text('Quitar adjunto'));
        expect(
          action.overlaps(tester.getRect(find.byType(HoldToCompleteButton))),
          isFalse,
        );
        await _meetsGuidelines(tester);
        handle.dispose();
      });
    });

    group('CA-008-21: foco y anuncios en el editor', () {
      Future<void> pumpEditor(WidgetTester tester) async {
        listen(tester);
        await pumpWithApp(
          tester,
          const TaskEditorScreen(mode: EditorMode.first),
          repo: repo,
          overrides: overrides(),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('vuelve del selector con un PDF: foco en la vista previa y '
          '"PDF añadido"', (tester) async {
        await pumpEditor(tester);
        await pickFile(tester);
        await tester.pumpAndSettle();
        expect(announcements, ['PDF añadido']);
        final preview = find.descendant(
          of: find.byType(AttachmentPreview),
          matching: find.byType(PdfStrip),
        );
        expect(Focus.of(tester.element(preview)).hasFocus, isTrue);
      });

      testWidgets('cancela el selector: foco en (+) y sin anuncio', (
        tester,
      ) async {
        await pumpEditor(tester);
        pdfs.userCancelsPicker = true;
        await pickFile(tester);
        await tester.pumpAndSettle();
        expect(announcements, isEmpty);
        expect(plusFocused(tester), isTrue);
      });

      testWidgets('"Preparando PDF…": foco en "Cancelar" y un anuncio', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpEditor(tester);
        pdfs.inspectDelay = const Duration(seconds: 5);
        await pickFile(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(announcements, ['Preparando PDF…']);
        expect(
          Focus.of(
            tester.element(find.widgetWithText(UnaLinkButton, 'Cancelar')),
          ).hasFocus,
          isTrue,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(announcements, ['Preparando PDF…', 'PDF añadido']);
        handle.dispose();
      });

      testWidgets('error al importar: foco en (+); el aviso se anuncia solo', (
        tester,
      ) async {
        await pumpEditor(tester);
        pdfs.inspectError = const PdfImportFailure(PdfImportError.protected);
        await pickFile(tester);
        await tester.pumpAndSettle();
        expect(announcements, isEmpty);
        expect(
          find.text('Este PDF está protegido con contraseña.'),
          findsOneWidget,
        );
        expect(plusFocused(tester), isTrue);
      });

      testWidgets('quitar adjunto: foco en (+) y "Adjunto quitado"', (
        tester,
      ) async {
        await pumpEditor(tester);
        await pickFile(tester);
        await tester.pumpAndSettle();
        announcements.clear();
        await tester.tap(find.bySemanticsLabel('Quitar adjunto'));
        await tester.pumpAndSettle();
        expect(announcements, ['Adjunto quitado']);
        expect(plusFocused(tester), isTrue);
      });
    });

    testWidgets('CA-008-21: la confirmación de un enlace se anuncia por su '
        'pregunta y empieza por "Cancelar"', (tester) async {
      final handle = tester.ensureSemantics();
      listen(tester);
      await pumpWithApp(
        tester,
        CurrentTaskScreen(task: await pdfTask()),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      taskPdfCalls.last.onLink!(
        WebLink(Uri.parse('https://example.com/'), 'example.com'),
      );
      await tester.pumpAndSettle();
      // La ruta nueva se nombra con la pregunta (Android la anuncia sola).
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('¿Abrir example.com en el navegador?').first,
        ),
        isSemantics(scopesRoute: true, namesRoute: true),
      );
      expect(announcements, isEmpty);
      // Orden de lectura dentro de la hoja: primero "Cancelar", la acción
      // segura (TalkBack enfoca el primer elemento que se puede pulsar).
      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .where((l) => l.isNotEmpty)
          .toList();
      final cancel = labels.indexOf('Cancelar');
      final open = labels.indexOf('Abrir');
      expect(cancel, greaterThanOrEqualTo(0), reason: '$labels');
      expect(cancel, lessThan(open), reason: '$labels');
      expect(labels.sublist(cancel, cancel + 3), [
        'Cancelar',
        '¿Abrir example.com en el navegador?',
        'Abrir',
      ]);
      expect(
        Focus.of(tester.element(find.widgetWithText(BrutalButton, 'Cancelar')))
            .hasFocus,
        isTrue,
      );
      handle.dispose();
    });
  });
}
