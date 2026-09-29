import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Giro de la tarea actual con imagen o con PDF (CA-008-11). Sin botón
/// "Volver a vertical" (propietario, 2026-09-28): se vuelve girando el móvil.
/// La parte nativa (sensor) se prueba a mano en el emulador y el móvil; aquí,
/// lo que la app pide y lo que se ve.
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late List<List<String>> orientations;
  late List<String> calls;
  late FakeWebPages web;

  setUp(() {
    store = MemoryAttachmentStore();
    web = FakeWebPages();
    // Un test que acaba con la confirmación de un enlace abierta la deja
    // marcada (se desmonta sin cerrarse).
    linkConfirmOpen.value = false;
    taskPdfCalls.clear();
  });

  /// Lo último que se ha pedido al sistema: girar con el adjunto o no.
  bool? rotating() {
    for (final c in calls.reversed) {
      if (c.startsWith('rotateWithAttachment:')) {
        return c.endsWith('true');
      }
    }
    return null;
  }

  Future<Task> imageTask({String id = 't1', String rank = 'V'}) async {
    final attachment = await store.commit(
      stageImage(store, 'a-$id'),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(id: id, text: 'Horario del festival', rank: rank);
    return base.withContent(base.text, attachment, base.updatedAt);
  }

  Future<Task> pdfTask({
    String id = 't1',
    String rank = 'V',
    String? text = 'Programa',
  }) async {
    final aid = 'p-$id';
    store
      ..putStaging(
        aid,
        'document.pdf',
        Uint8List.fromList('%PDF-1.7'.codeUnits),
      )
      ..putStaging(aid, 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: aid,
        byteSize: 2400000,
        pageCount: 12,
        width: 595,
        height: 842,
        originalName: 'Programa.pdf',
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(id: id, text: text ?? 'x', rank: rank, colorKey: 2);
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<InMemoryTaskRepository> pumpApp(
    WidgetTester tester,
    List<Task> tasks, {
    bool screenReader = false,
    bool rotates = true,
  }) async {
    orientations = [];
    calls = [];
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
        if (call.method != 'keepOn') {
          calls.add('${call.method}:${call.arguments}');
        }
        return null;
      });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
    });
    final repo = InMemoryTaskRepository();
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      screenReader: screenReader,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
        attachmentRotatesProvider.overrideWithValue(rotates),
        ...fakePdfViews,
        ...web.overrides,
      ],
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> turn(WidgetTester tester, {required bool landscape}) async {
    tester.view.physicalSize = landscape
        ? const Size(844, 390)
        : const Size(390, 844);
    await tester.pumpAndSettle();
  }

  final pdfViewer = find.byKey(const Key('fake-task-pdf'));

  group('CA-008-11: gira con PDF igual que con imagen', () {
    testWidgets('con la tarea a la vista gira; con el menú abierto, solo en '
        'vertical', (tester) async {
      await pumpApp(tester, [await pdfTask()]);
      expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));
      expect(rotating(), isTrue);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      expect(rotating(), isFalse);

      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pumpAndSettle();
      expect(rotating(), isTrue);
    });

    testWidgets('en horizontal: el PDF a todo el ancho y el logotipo; sin '
        'menú, botón, franja ni texto', (tester) async {
      await pumpApp(tester, [await pdfTask()]);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);

      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(find.byType(BrutalButton), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      expect(find.byType(PdfStrip), findsNothing);
      // Sin la banda del texto.
      expect(taskPdfCalls.last.caption, isNull);
      // El PDF ocupa toda la pantalla, detrás del logotipo.
      expect(tester.getRect(pdfViewer), const Rect.fromLTWH(0, 0, 844, 390));

      await turn(tester, landscape: false);
      expect(find.byType(PdfStrip), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(taskPdfCalls.last.caption, 'Programa');
    });

    testWidgets('al girar y volver, el visor es el mismo (se conservan la '
        'posición y el zoom)', (tester) async {
      await pumpApp(tester, [await pdfTask()]);
      addTearDown(tester.view.reset);
      final before = tester.element(pdfViewer);
      await turn(tester, landscape: true);
      expect(tester.element(pdfViewer), same(before));
      await turn(tester, landscape: false);
      expect(tester.element(pdfViewer), same(before));
    });

    testWidgets('CA-008-20: el PDF lleva Completar y Eliminar en las dos '
        'orientaciones; en horizontal, la página se lee con "Tarea actual"', (
      tester,
    ) async {
      await pumpApp(tester, [await pdfTask()]);
      addTearDown(tester.view.reset);
      List<String> actions() => [
        for (final a in taskPdfCalls.last.actions.keys) a.label ?? '',
      ];
      expect(actions(), ['Completar tarea', 'Eliminar tarea']);
      expect(taskPdfCalls.last.taskLabel, isNull);

      await turn(tester, landscape: true);
      expect(actions(), ['Completar tarea', 'Eliminar tarea']);
      expect(taskPdfCalls.last.taskLabel, 'Tarea actual: Programa');
    });

    testWidgets('sin texto, el prefijo lleva el nombre del PDF', (
      tester,
    ) async {
      await pumpApp(tester, [await pdfTask(text: null)]);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      expect(taskPdfCalls.last.taskLabel, 'Tarea actual: Programa.pdf');
    });

    testWidgets('con la confirmación de un enlace abierta sigue girando y la '
        'confirmación sigue abierta en la nueva orientación', (tester) async {
      await pumpApp(tester, [await pdfTask()]);
      addTearDown(tester.view.reset);
      taskPdfCalls.last.onLink!(
        WebLink(Uri.parse('https://example.com/'), 'example.com'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinkConfirmSheet), findsOneWidget);
      expect(rotating(), isTrue);
      expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));

      await turn(tester, landscape: true);
      expect(find.byType(LinkConfirmSheet), findsOneWidget);
      expect(rotating(), isTrue);
    });

    testWidgets('CA-008-18: con "Adjunto no disponible" no gira', (
      tester,
    ) async {
      final task = await pdfTask();
      store.removeFile('p-t1', 'document.pdf');
      await pumpApp(tester, [task]);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(rotating(), isNot(isTrue));
      expect(
        orientations.where(
          (o) => o.contains('DeviceOrientation.landscapeLeft'),
        ),
        isEmpty,
      );
    });
  });

  group('CA-008-11: sin "Volver a vertical" (propietario, 2026-09-28)', () {
    testWidgets('con imagen, en horizontal: la imagen a todo el ancho y el '
        'logotipo, sin menú ni botones', (tester) async {
      await pumpApp(tester, [await imageTask()]);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(find.byType(BrutalButton), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      expect(tester.getSize(find.byType(TaskImage)).width, 844);
      // Se vuelve a vertical girando el móvil: la app no pide nada más.
      expect(
        calls.where((c) => !c.startsWith('rotateWithAttachment:')),
        isEmpty,
      );
      await turn(tester, landscape: false);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
    });

    testWidgets('CA-008-22: con PDF en horizontal y el texto al 200 %, nada '
        'se corta', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [await pdfTask()]);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await turn(tester, landscape: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.byType(BrutalButton), findsNothing);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('CA-008-11: completar o eliminar en horizontal', () {
    Future<void> completeInLandscape(WidgetTester tester, String label) async {
      tester.semantics.customAction(
        find.semantics.byLabel(label),
        const CustomSemanticsAction(label: 'Completar tarea'),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    testWidgets('si la siguiente no tiene adjunto, vuelve a vertical', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [
        await imageTask(rank: 'B'),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'C'),
      ], screenReader: true);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      expect(rotating(), isTrue);
      await completeInLandscape(
        tester,
        'Tarea actual: Horario del festival. Con foto',
      );
      expect(find.text('Sin adjunto'), findsOneWidget);
      expect(rotating(), isFalse);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      handle.dispose();
    });

    testWidgets('si la siguiente tiene PDF, sigue girando', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [
        await imageTask(rank: 'B'),
        await pdfTask(id: 't2', rank: 'C'),
      ], screenReader: true);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      await completeInLandscape(
        tester,
        'Tarea actual: Horario del festival. Con foto',
      );
      expect(find.byType(PdfStrip), findsNothing); // Sigue en horizontal.
      expect(pdfViewer, findsOneWidget);
      expect(rotating(), isTrue);
      expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));
      handle.dispose();
    });

    testWidgets('eliminar con PDF en horizontal: sale la confirmación y, sin '
        'más tareas con adjunto, vuelve a vertical', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [
        await pdfTask(rank: 'B'),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'C'),
      ], screenReader: true);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      taskPdfCalls.last.actions.entries
          .firstWhere((e) => e.key.label == 'Eliminar tarea')
          .value();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Sin adjunto'), findsOneWidget);
      expect(rotating(), isFalse);
      handle.dispose();
    });
  });

  group('CA-009-15: la tarea web gira como la imagen y el PDF', () {
    const address = 'https://www.congreso.ejemplo.com/programa';
    const nodeLabel = 'Tarea actual: Página web de congreso.ejemplo.com';
    // Mientras carga, la vista está montada pero fuera del escenario.
    final view = find.byKey(const ValueKey('web-view-0'), skipOffstage: false);

    Task webTask({String id = 'w', String rank = 'MA'}) {
      final at = DateTime.utc(2026, 9, 29, 9);
      return Task(
        id: id,
        text: null,
        status: TaskStatus.pending,
        rank: rank,
        colorKey: 3,
        createdAt: at,
        updatedAt: at,
        attachment: attachmentFrom(StagedWeb(id: 'a-$id', url: address), at),
      );
    }

    /// La página se ve: ha empezado y terminado de cargar.
    Future<void> shown(WidgetTester tester) async {
      web.last
        ..started(address)
        ..finished(address);
      await tester.pumpAndSettle();
    }

    void performOnNode(WidgetTester tester, String action) {
      final node = tester.getSemantics(find.bySemanticsLabel(nodeLabel));
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == action,
      );
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
    }

    testWidgets('con la tarea a la vista gira; con el menú abierto, solo en '
        'vertical', (tester) async {
      await pumpApp(tester, [webTask()]);
      expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));
      expect(rotating(), isTrue);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(rotating(), isFalse);
      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pumpAndSettle();
      expect(rotating(), isTrue);
    });

    testWidgets('en horizontal: la página a todo el ancho y el logotipo; sin '
        'barra, menú ni botón', (tester) async {
      await pumpApp(tester, [webTask()]);
      addTearDown(tester.view.reset);
      await shown(tester);
      await turn(tester, landscape: true);

      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.byType(WebBar), findsNothing);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      // La página ocupa toda la pantalla, detrás del logotipo.
      expect(tester.getRect(view), const Rect.fromLTWH(0, 0, 844, 390));
      expect(
        tester.getRect(find.byType(Wordmark)).top,
        greaterThanOrEqualTo(0),
      );

      await turn(tester, landscape: false);
      expect(find.byType(WebBar), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(tester.getRect(view).width, 390);
    });

    testWidgets('al girar y volver, la WebView es la misma y la página no se '
        'recarga', (tester) async {
      await pumpApp(tester, [webTask()]);
      addTearDown(tester.view.reset);
      await shown(tester);
      final before = tester.element(view);
      await turn(tester, landscape: true);
      expect(tester.element(view), same(before));
      await turn(tester, landscape: false);
      expect(tester.element(view), same(before));
      expect(web.drivers, hasLength(1));
      expect(web.last.loads, [Uri.parse(address)]);
      expect(web.last.stops, 0);
      expect(web.janitor.cleared, isEmpty);
    });

    testWidgets('CA-009-18: en horizontal, el logotipo es el nodo de la tarea, '
        'con Completar y Eliminar', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [webTask()]);
      addTearDown(tester.view.reset);
      await shown(tester);
      await turn(tester, landscape: true);
      expect(find.bySemanticsLabel(nodeLabel), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(nodeLabel)),
        isSemantics(
          label: nodeLabel,
          customActions: const [
            CustomSemanticsAction(label: 'Completar tarea'),
            CustomSemanticsAction(label: 'Eliminar tarea'),
          ],
        ),
      );
      // Es el logotipo.
      final node = tester.getRect(find.bySemanticsLabel(nodeLabel));
      final logo = tester.getRect(find.byType(Wordmark));
      expect(node.overlaps(logo), isTrue);
      expect(node.height, lessThan(390 / 2));
      handle.dispose();
    });

    testWidgets('no gira con un aviso; tras "Reintentar", sí', (tester) async {
      await pumpApp(tester, [webTask()]);
      web.last
        ..started(address)
        ..error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(rotating(), isFalse);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(rotating(), isTrue);
    });

    for (final (name, fail) in <(String, void Function(FakeWebPageDriver))>[
      ('sin conexión', (d) => d.error(WebLoadError.hostLookup)),
      ('certificado', (d) => d.certificate()),
      ('no es una página', (d) => d.download()),
      // [Suposición] También el de CA-009-11 (enmienda posterior a CA-009-15).
      (
        'intenta abrir otra página',
        (d) => d
          ..started(address)
          ..started('https://formularios.otro.org/enviar')
          ..started(address)
          ..started('https://formularios.otro.org/enviar'),
      ),
    ]) {
      testWidgets('con el aviso ($name) en horizontal, vuelve a vertical '
          'con la barra, el aviso y el botón; la WebView es la misma', (
        tester,
      ) async {
        await pumpApp(tester, [webTask()]);
        addTearDown(tester.view.reset);
        // Mientras carga, gira.
        await turn(tester, landscape: true);
        expect(rotating(), isTrue);
        expect(find.byType(WebBar), findsNothing);
        final before = tester.element(view);

        fail(web.last);
        await tester.pumpAndSettle();
        expect(rotating(), isFalse);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);
        // Aunque la ventana siga apaisada, se ve como en vertical.
        expect(find.byType(WebBar), findsOneWidget);
        expect(find.byType(HoldToCompleteButton), findsOneWidget);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
        // Bajo el aviso, fuera del escenario.
        expect(
          tester.element(
            find.byKey(const ValueKey('web-view-0'), skipOffstage: false),
          ),
          same(before),
        );
      });
    }

    testWidgets('completar en horizontal con la acción del lector: si la '
        'siguiente no tiene adjunto, vuelve a vertical', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [
        webTask(rank: 'B'),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'C'),
      ], screenReader: true);
      addTearDown(tester.view.reset);
      await shown(tester);
      await turn(tester, landscape: true);
      expect(rotating(), isTrue);
      performOnNode(tester, 'Completar tarea');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Sin adjunto'), findsOneWidget);
      expect(rotating(), isFalse);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
      handle.dispose();
    });

    testWidgets('eliminar en horizontal: sale la confirmación y, sin más '
        'tareas con adjunto, vuelve a vertical', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [
        webTask(rank: 'B'),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'C'),
      ], screenReader: true);
      addTearDown(tester.view.reset);
      await shown(tester);
      await turn(tester, landscape: true);
      performOnNode(tester, 'Eliminar tarea');
      await tester.pumpAndSettle();
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Sin adjunto'), findsOneWidget);
      expect(rotating(), isFalse);
      handle.dispose();
    });

    testWidgets('CA-009-20: en horizontal y con el texto al 200 %, nada se '
        'corta', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, [webTask()]);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await shown(tester);
      await turn(tester, landscape: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(Wordmark), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('CL-009-5: donde no gira (web de pruebas), la ventana '
        'apaisada se ve como en vertical', (tester) async {
      await pumpApp(tester, [webTask()], rotates: false);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      expect(find.byType(WebBar), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
    });
  });

  group('CL-008-12: la web de pruebas no gira', () {
    testWidgets('con PDF y la ventana apaisada, se ve como en vertical', (
      tester,
    ) async {
      await pumpApp(tester, [await pdfTask()], rotates: false);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);

      expect(find.byType(PdfStrip), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
      expect(taskPdfCalls.last.caption, 'Programa');
    });

    testWidgets('con imagen, igual', (tester) async {
      await pumpApp(tester, [await imageTask()], rotates: false);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);

      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
      expect(
        tester.widget<TaskImage>(find.byType(TaskImage)).caption,
        'Horario del festival',
      );
    });
  });
}
