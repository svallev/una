import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/pdfrx.dart';
import '../../support/pump_app.dart' show sampleTask;
import '../task_list/list_harness.dart' show FakeClock, background;
import 'settings_harness.dart' show focusedLabel;

/// Ajustes (spec 015) abierto sobre una tarea con web, PDF o imagen: la tarea
/// de debajo no cambia (CA-015-15), no pide girar (CL-015-2) y se abre desde el
/// menú de cualquier tarea (CA-015-01a). El menú se cierra al abrirlo y al
/// cerrar Ajustes se vuelve a la tarea (CA-015-02), con el foco en el botón de
/// menú.
///
/// Texto de las tareas neutro (ni ES ni EN).

const _menuLabel = 'Ajustes';
const _webAddress = 'https://www.zxq.example/qz';

class _Opener implements LinkOpener {
  final opened = <LinkTarget>[];

  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return true;
  }
}

Task _webTask() {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: 'web',
    text: null,
    status: TaskStatus.pending,
    rank: 'MA',
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-web', url: _webAddress), at),
  );
}

Future<Task> _imageTask(MemoryAttachmentStore store) async {
  final attachment = await store.commit(
    stageImage(store, 'img'),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: 'img', text: 'Zxq imagen', rank: 'MA');
  return base.withContent(base.text, attachment, base.updatedAt);
}

/// Tarea con PDF; con [real], el documento de 20 páginas de verdad (para el
/// visor real); si no, una cabecera (con el visor falso).
Future<Task> _pdfTask(MemoryAttachmentStore store, {bool real = false}) async {
  store
    ..putStaging(
      'p-pdf',
      'document.pdf',
      real
          ? base64Decode(pdfFixtures['pages_20.pdf']!)
          : Uint8List.fromList(pdfHead),
    )
    ..putStaging('p-pdf', 'screen.jpg', tinyImage);
  final attachment = await store.commit(
    const StagedPdf(
      id: 'p-pdf',
      byteSize: 2400000,
      pageCount: 20,
      width: 595,
      height: 842,
      originalName: 'Zxq.pdf',
    ),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: 'pdf', text: 'Zxq pdf', rank: 'MA');
  return base.withContent(base.text, attachment, base.updatedAt);
}

/// Deja pasar el reloj y el trabajo del motor de PDF, que corre fuera del reloj
/// falso de los tests.
Future<void> _settlePdf(WidgetTester tester, [int rounds = 40]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(initPdfrxForTests);

  late MemoryAttachmentStore store;
  late FakeWebPages web;
  late _Opener opener;
  late List<List<String>> orientations;
  late List<String> screenCalls;

  setUp(() {
    store = MemoryAttachmentStore();
    web = FakeWebPages();
    opener = _Opener();
    taskPdfCalls.clear();
    linkConfirmOpen.value = false;
  });

  /// Lo último que se ha pedido al sistema: girar con el adjunto o no.
  bool? rotating() {
    for (final c in screenCalls.reversed) {
      if (c.startsWith('rotateWithAttachment:')) return c.endsWith('true');
    }
    return null;
  }

  Future<FakeClock> pumpWith(
    WidgetTester tester,
    Task task, {
    bool realPdf = false,
  }) async {
    orientations = [];
    screenCalls = [];
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
          screenCalls.add('${call.method}:${call.arguments}');
        }
        return null;
      });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
    });
    final repo = InMemoryTaskRepository();
    await repo.insert(task);
    final clock = FakeClock();
    final List<Override> overrides = [
      attachmentStoreProvider.overrideWithValue(store),
      imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
      pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
      attachmentRotatesProvider.overrideWithValue(true),
      if (!realPdf) ...fakePdfViews,
      ...web.overrides,
      linkOpenerProvider.overrideWithValue(opener),
    ];
    await pumpUnaApp(tester, repo: repo, clock: clock, overrides: overrides);
    if (realPdf) {
      await _settlePdf(tester, 200);
    } else {
      await tester.pumpAndSettle();
    }
    return clock;
  }

  Future<void> settle(WidgetTester tester, {bool pdf = false}) async {
    if (pdf) {
      await _settlePdf(tester);
    } else {
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.sheetOut);
      await tester.pumpAndSettle();
    }
  }

  Future<void> openMenu(WidgetTester tester, {bool pdf = false}) async {
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await settle(tester, pdf: pdf);
    expect(find.byType(MenuSheet), findsOneWidget);
  }

  Future<void> openSettings(WidgetTester tester, {bool pdf = false}) async {
    await openMenu(tester, pdf: pdf);
    await tester.tap(find.text(_menuLabel));
    await settle(tester, pdf: pdf);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(MenuSheet), findsNothing, reason: 'el menú se cerró');
  }

  Future<void> closeSettings(WidgetTester tester, {bool pdf = false}) async {
    await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
    await settle(tester, pdf: pdf);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(MenuSheet), findsNothing);
  }

  /// Abre la política, confirma y comprueba que se pidió al navegador.
  Future<void> openPolicyInBrowser(
    WidgetTester tester, {
    bool pdf = false,
  }) async {
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Política de privacidad'),
      ),
    );
    await settle(tester, pdf: pdf);
    expect(find.byType(LinkConfirmSheet), findsOneWidget);
    await tester.tap(find.text('Abrir'));
    await settle(tester, pdf: pdf);
    expect(opener.opened, hasLength(1));
  }

  group('CA-015-01a, CL-015-1: se abre desde el menú de cualquier tarea', () {
    final kinds = <(String, Future<Task> Function())>[
      ('solo texto', () async => sampleTask(text: 'Zxq texto')),
      ('con imagen', () => _imageTask(store)),
      ('con PDF', () => _pdfTask(store)),
      ('con web', () async => _webTask()),
    ];
    for (final (name, build) in kinds) {
      testWidgets('$name: abre el nivel 1 y al cerrar vuelve a la tarea', (
        tester,
      ) async {
        await pumpWith(tester, await build());
        await openSettings(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        await closeSettings(tester);
        expect(find.text(_menuLabel), findsNothing);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
      });
    }
  });

  group('CA-015-15: la tarea de debajo no cambia', () {
    testWidgets('web: se vuelve a cargar al volver, con la misma WebView '
        '(la ruta a pantalla completa cuenta como salir de la página)', (
      tester,
    ) async {
      await pumpWith(tester, _webTask());
      final page = web.last;
      page
        ..started(_webAddress)
        ..finished(_webAddress);
      await tester.pumpAndSettle();
      expect(page.loads, hasLength(1));

      await openSettings(tester);
      // Tapada: se deja de cargar y se borra lo de la página.
      expect(page.stops, greaterThan(0));
      expect(web.janitor.cleared, [page.nativeId]);
      expect(page.disposed, isFalse);

      await closeSettings(tester);
      // De vuelta: la misma WebView, cargada de nuevo.
      expect(web.drivers, [same(page)]);
      expect(page.loads, hasLength(2));
      expect(page.loads.last, Uri.parse(_webAddress));
      expect(page.disposed, isFalse);
      expect(find.byType(WebBar), findsOneWidget);
    });

    testWidgets('web: abrir la política en el navegador y volver en menos de '
        '10 minutos deja Ajustes abierto; la página se carga al '
        'cerrarla', (tester) async {
      final clock = await pumpWith(tester, _webTask());
      final page = web.last;
      page
        ..started(_webAddress)
        ..finished(_webAddress);
      await tester.pumpAndSettle();
      await openSettings(tester);
      await openPolicyInBrowser(tester);
      final loads = page.loads.length;

      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await settle(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(page.loads, hasLength(loads), reason: 'sigue tapada');
      await closeSettings(tester);
      expect(page.loads, hasLength(loads + 1));
      expect(web.drivers, [same(page)]);
    });

    testWidgets('web: tras 10 minutos, la página se ve cargada desde cero', (
      tester,
    ) async {
      final clock = await pumpWith(tester, _webTask());
      final page = web.last;
      page
        ..started(_webAddress)
        ..finished(_webAddress);
      await tester.pumpAndSettle();
      await openSettings(tester);
      background(tester, clock, UnaApp.resetAfter);
      await settle(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsNothing);
      expect(find.byType(WebBar), findsOneWidget);
      // Tras 10 minutos se borra todo y se carga desde cero.
      expect(web.janitor.cleared, contains(page.nativeId));
      expect(web.last.loads, isNotEmpty);
      expect(web.last.loads.last, Uri.parse(_webAddress));
      expect(web.drivers, hasLength(2), reason: 'una WebView nueva');
      expect(web.last, isNot(same(page)));
      // CA-015-16: la tarea, con el foco en el botón de menú.
      expect(focusedLabel(tester), 'Menú de la tarea');
    });

    testWidgets('CA-015-16: volver del navegador a 9:59 deja Ajustes y sin '
        'petición de foco; a 10:00 la tarea tiene el foco de teclado y del '
        'lector en el botón de menú (un solo aviso)', (tester) async {
      final handle = tester.ensureSemantics();
      final focusEvents = <int>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message! as Map<Object?, Object?>;
            if (map['type'] == 'focus') focusEvents.add(map['nodeId']! as int);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final clock = await pumpWith(tester, sampleTask(text: 'Zxq texto'));
      await openSettings(tester);
      await openPolicyInBrowser(tester);
      focusEvents.clear();

      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(focusedLabel(tester), isNot('Menú de la tarea'));
      expect(focusEvents, isEmpty);

      background(tester, clock, UnaApp.resetAfter);
      await settle(tester);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsNothing);
      expect(focusedLabel(tester), 'Menú de la tarea');
      final node = tester.getSemantics(
        find.bySemanticsLabel('Menú de la tarea'),
      );
      expect(focusEvents, [node.id]);
      handle.dispose();
    });

    testWidgets('PDF: conserva su página y su zoom (mismo visor, mismo '
        'controlador) tras abrir los dos niveles y la política', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final clock = await pumpWith(
        tester,
        await _pdfTask(store, real: true),
        realPdf: true,
      );
      final page1 = RegExp('^Página 1 de 20');
      expect(find.bySemanticsLabel(page1), findsOneWidget);
      // Página 2 y zoom ×1,5, con las acciones del lector.
      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Página siguiente'),
      );
      await _settlePdf(tester);
      final page2 = RegExp('^Página 2 de 20');
      tester.semantics.customAction(
        find.semantics.byLabel(page2),
        const CustomSemanticsAction(label: 'Ampliar'),
      );
      await _settlePdf(tester);
      expect(find.bySemanticsLabel(page2), findsOneWidget);
      final controller = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      final zoom = controller.currentZoom;
      final top = controller.visibleRect.top;
      final state = tester.state(find.byType(TaskPdfView));
      expect(zoom / controller.minScale, closeTo(1.5, 0.01));

      await openSettings(tester, pdf: true);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text('Idioma'),
        ),
      );
      await settle(tester, pdf: true);
      expect(find.byType(LanguagePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, pdf: true);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await openPolicyInBrowser(tester, pdf: true);
      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await settle(tester, pdf: true);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await closeSettings(tester, pdf: true);

      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(TaskPdfView)), same(state));
      expect(
        tester.widget<PdfViewer>(find.byType(PdfViewer)).controller,
        same(controller),
      );
      expect(controller.currentZoom, closeTo(zoom, 0.0001));
      expect(controller.visibleRect.top, closeTo(top, 0.5));
      // Con el menú ya cerrado, el lector vuelve a leer la misma página.
      expect(find.byType(MenuSheet), findsNothing);
      expect(find.bySemanticsLabel(page2), findsOneWidget);
      // pdfrx deja temporizadores propios: se desmonta y se dejan correr.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      semantics.dispose();
    });

    testWidgets('imagen: es la misma (mismo estado, sin volver a cargarse) '
        'tras abrir y cerrar Ajustes', (tester) async {
      await pumpWith(tester, await _imageTask(store));
      expect(find.byType(TaskImage), findsOneWidget);
      final image = tester.state(find.byType(TaskImage));

      await openSettings(tester);
      expect(
        tester.state(find.byType(TaskImage, skipOffstage: false)),
        same(image),
        reason: 'la tarea sigue montada debajo',
      );
      await closeSettings(tester);

      expect(find.byType(TaskImage), findsOneWidget);
      expect(tester.state(find.byType(TaskImage)), same(image));
      expect(tester.takeException(), isNull);
    });
  });

  group('CL-015-2: Ajustes no pide girar', () {
    final kinds = <(String, Future<Task> Function())>[
      ('imagen', () => _imageTask(store)),
      ('PDF', () => _pdfTask(store)),
      ('web', () async => _webTask()),
    ];
    for (final (name, build) in kinds) {
      testWidgets('$name: gira con la tarea a la vista; con el menú, los dos '
          'niveles y la confirmación de la política, no', (tester) async {
        await pumpWith(tester, await build());
        expect(rotating(), isTrue);
        expect(orientations.last, contains('DeviceOrientation.landscapeLeft'));

        await openMenu(tester);
        expect(rotating(), isFalse);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);

        await tester.tap(find.text(_menuLabel));
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(rotating(), isFalse);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);

        // Nivel 2.
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text('Idioma'),
          ),
        );
        await settle(tester);
        expect(find.byType(LanguagePage), findsOneWidget);
        expect(rotating(), isFalse);
        await tester.binding.handlePopRoute();
        await settle(tester);

        // La confirmación de la política: solo aquí la app dejaría girar la
        // tarea de debajo si no se hubiera pedido lo contrario.
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text('Política de privacidad'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LinkConfirmSheet), findsOneWidget);
        expect(linkConfirmOpen.value, isFalse);
        expect(rotating(), isFalse);
        expect(orientations.last, ['DeviceOrientation.portraitUp']);
        await tester.tap(find.text('Cancelar'));
        await settle(tester);

        // De vuelta: cerrado todo, gira otra vez.
        await closeSettings(tester);
        expect(find.byType(MenuSheet), findsNothing);
        expect(rotating(), isTrue);
      });
    }

    testWidgets('solo texto: no gira nunca', (tester) async {
      await pumpWith(tester, sampleTask(text: 'Zxq texto'));
      await openSettings(tester);
      expect(rotating(), isNot(isTrue));
      expect(
        orientations.where(
          (o) => o.contains('DeviceOrientation.landscapeLeft'),
        ),
        isEmpty,
      );
    });

    testWidgets('si se vuelve en horizontal (p. ej. del navegador) vale lo que '
        'ya hace la app: con menos de 10 minutos, Ajustes; con 10 o '
        'más, la tarea sin menú (CA-015-16)', (tester) async {
      final clock = await pumpWith(tester, await _imageTask(store));
      addTearDown(tester.view.reset);
      await openSettings(tester);

      tester.view.physicalSize = const Size(844, 390);
      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await tester.pump();
      await tester.pump(UnaMotion.sheetOut);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(rotating(), isFalse);

      background(tester, clock, UnaApp.resetAfter);
      await settle(tester);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsNothing);
      // En horizontal, la tarea sin menú: la imagen y el logotipo.
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(rotating(), isTrue);

      // Sin botón no queda nada pendiente: al volver a vertical, el botón
      // nuevo no se lleva el foco.
      tester.view.physicalSize = const Size(390, 844);
      await settle(tester);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsOneWidget);
      expect(focusedLabel(tester), isNot('Menú de la tarea'));
    });
  });
}
