import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/attachments/attach_sheet.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/task_list/move_sheet.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../features/task_list/list_harness.dart';
import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_pdf_importer.dart';
import '../support/fake_pdf_view.dart';
import '../support/fake_web_page_driver.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

/// Texto al 200 % en inglés (CA-010-12, T-010-09): las mismas pantallas y
/// hojas que recorre CA-010-07, a 360 × 640, sin cortes, solapes ni
/// desbordamientos. Con las fuentes reales (`loadAppFonts`): con la fuente de
/// pruebas cada letra mide 1 em y saldrían desbordamientos que no existen.

const _phone = Size(360, 640);
const _frame = Duration(milliseconds: 16);

/// Textos de tarea realistas y largos, para que envuelvan varias líneas.
const _long = [
  'Call Marta tomorrow morning to talk about the quarterly meeting agenda '
      'and the documents she has to bring',
  'Buy oat milk, wholegrain bread and some fresh tomatoes',
  'Renew the passport before the trip in November',
];

const _pdfName = 'Quarterly meeting agenda and budget review 2026.pdf';
const _webAddress = 'https://www.example.com/a/very/long/path/to/an/article';

final _en = lookupAppLocalizations(const Locale('en'));

/// Mantiene el nivel de exigencia de CA-010-12 tras cada paso: ninguna
/// excepción de desbordamiento (ni de otro tipo) pendiente.
void _noOverflow(WidgetTester tester, [String? where]) {
  expect(
    tester.takeException(),
    isNull,
    reason:
        'Desbordamiento al 200 % en inglés${where == null ? '' : ' ($where)'}',
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(_en.menuButton));
  await tester.pumpAndSettle();
  expect(find.byType(MenuSheet), findsOneWidget);
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(_en.menuClose).last);
  await tester.pumpAndSettle();
  expect(find.byType(MenuSheet), findsNothing);
}

/// Menú → Eliminar (deja la hoja de eliminar abierta).
Future<void> _openDeleteSheet(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text(_en.menuDelete));
  await tester.pumpAndSettle();
  expect(find.byType(DeleteConfirmSheet), findsOneWidget);
}

/// Tarea con un PDF ya guardado en [store].
Future<Task> _pdfTask(
  MemoryAttachmentStore store,
  String id, {
  String? text,
  required String rank,
  List<int>? bytes,
}) async {
  final attachmentId = 'p-$id';
  store
    ..putStaging(
      attachmentId,
      'document.pdf',
      Uint8List.fromList(bytes ?? pdfHead),
    )
    ..putStaging(attachmentId, 'screen.jpg', tinyImage);
  final attachment = await store.commit(
    StagedPdf(
      id: attachmentId,
      byteSize: 2400000,
      pageCount: 20,
      width: 595,
      height: 842,
      originalName: _pdfName,
    ),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: id, text: text ?? 'x', rank: rank);
  return base.withContent(text, attachment, base.updatedAt);
}

/// Tarea web (sin texto) con la dirección [url].
Task _webTask(String id, {required String rank, String url = _webAddress}) {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: id,
    text: null,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-$id', url: url), at),
  );
}

/// Abre enlaces sin salir de la prueba.
class _Opener implements LinkOpener {
  @override
  Future<bool> open(LinkTarget target) async => true;
}

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakePdfImporter pdfs;
  late FakeWebPages web;

  setUp(() {
    store = MemoryAttachmentStore();
    pdfs = FakePdfImporter(store)..pickedName = _pdfName;
    web = FakeWebPages();
    taskPdfCalls.clear();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
    pdfImporterProvider.overrideWithValue(pdfs),
    ...fakePdfViews,
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(_Opener()),
  ];

  /// La app completa, en inglés, al 200 % y en un móvil pequeño.
  Future<InMemoryTaskRepository> pumpEn(
    WidgetTester tester, {
    List<Task> tasks = const [],
    bool firstRunDone = true,
  }) async {
    final repo = InMemoryTaskRepository();
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      locale: const Locale('en'),
      textScale: 2.0,
      size: _phone,
      firstRunDone: firstRunDone,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    // El texto va de verdad al 200 %, en inglés y en 360 x 640.
    final context = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
    expect(MediaQuery.sizeOf(context), _phone);
    expect(Localizations.localeOf(context).languageCode, 'en');
    _noOverflow(tester, 'arranque');
    return repo;
  }

  List<Task> textTasks() => [
    for (final (i, text) in _long.indexed)
      sampleTask(
        id: 't$i',
        text: text,
        rank: 'M${String.fromCharCode(65 + i)}',
      ),
  ];

  testWidgets('CA-010-12: bienvenida y editor de la primera tarea', (
    tester,
  ) async {
    await pumpEn(tester, firstRunDone: false);
    expect(find.byType(WelcomeIntro), findsOneWidget);
    expect(find.bySemanticsLabel(_en.welcomeTitle), findsOneWidget);
    _noOverflow(tester, 'bienvenida');

    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
    _noOverflow(tester, 'editor vacío');

    await tester.enterText(find.byType(EditableText), _long.first);
    await tester.pumpAndSettle();
    _noOverflow(tester, 'editor con texto');
  });

  testWidgets(
    'CA-010-12: editor con el contador de caracteres y con adjuntos',
    (tester) async {
      await pumpEn(tester, tasks: textTasks());
      await _openMenu(tester);
      await tester.tap(find.text(_en.menuNewTask));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      _noOverflow(tester, 'editor de tarea nueva');

      // El contador aparece con poco margen (CL-001-2).
      await tester.enterText(
        find.byType(EditableText),
        'a' * (Task.maxTextLength - 5),
      );
      await tester.pumpAndSettle();
      expect(find.text(_en.editorCharsLeft(5)), findsWidgets);
      _noOverflow(tester, 'contador de caracteres');

      await tester.enterText(find.byType(EditableText), _long.first);
      await tester.pumpAndSettle();
      _noOverflow(tester, 'editor con texto largo');

      // Con un PDF adjunto.
      await tester.tap(find.bySemanticsLabel(_en.attachButton));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      await tester.tap(find.text(_en.attachPickFile));
      await tester.pumpAndSettle();
      expect(find.byType(AttachmentPreview), findsOneWidget);
      expect(find.byType(PdfStrip), findsOneWidget);
      _noOverflow(tester, 'editor con PDF');
    },
  );

  testWidgets('CA-010-12: tarea actual solo texto, menú y editor de edición', (
    tester,
  ) async {
    await pumpEn(tester, tasks: textTasks());
    expect(find.byType(CurrentTaskScreen), findsOneWidget);
    expect(find.text(_long.first), findsOneWidget);
    _noOverflow(tester, 'tarea actual');

    await _openMenu(tester);
    _noOverflow(tester, 'menú con 3 tareas');
    await tester.tap(find.text(_en.menuEdit));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
    _noOverflow(tester, 'editor de edición');
  });

  testWidgets('CA-010-12: menú con una sola tarea', (tester) async {
    await pumpEn(tester, tasks: [textTasks().first]);
    await _openMenu(tester);
    _noOverflow(tester, 'menú con 1 tarea');
  });

  testWidgets('CA-010-12: hoja de eliminar de una tarea de texto', (
    tester,
  ) async {
    await pumpEn(
      tester,
      tasks: [
        textTasks().first,
        await _pdfTask(store, 'p', rank: 'MB'),
      ],
    );
    await _openDeleteSheet(tester);
    _noOverflow(tester, 'hoja de eliminar (texto)');
    // Los botones de la hoja se alcanzan aunque se desplace.
    await tester.ensureVisible(
      find.byWidgetPredicate(
        (w) => w is BrutalButton && w.label == _en.deleteConfirm,
      ),
    );
    await tester.pumpAndSettle();
    _noOverflow(tester, 'hoja de eliminar, botón de confirmar');
    final cancel = find.byWidgetPredicate(
      (w) => w is BrutalButton && w.label == _en.editorCancel,
    );
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    _noOverflow(tester, 'hoja de eliminar, botón de cancelar');
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(DeleteConfirmSheet), findsNothing);
  });

  testWidgets('CA-010-12: hoja de eliminar de una tarea con PDF', (
    tester,
  ) async {
    await pumpEn(
      tester,
      tasks: [await _pdfTask(store, 'p', text: _long.first, rank: 'MA')],
    );
    await _openDeleteSheet(tester);
    _noOverflow(tester, 'hoja de eliminar (PDF)');
  });

  testWidgets('CA-010-12: tarea actual con imagen (con y sin texto)', (
    tester,
  ) async {
    for (final text in [_long.first, null]) {
      final attachment = await store.commit(
        stageImage(store, 'a-${text == null ? 'n' : 't'}'),
        DateTime.utc(2026, 9, 20),
      );
      final base = sampleTask(id: 'img', text: text ?? 'x');
      final task = base.withContent(text, attachment, base.updatedAt);
      await pumpEn(tester, tasks: [task]);
      expect(find.byType(TaskImage), findsOneWidget);
      _noOverflow(tester, 'imagen ${text == null ? 'sin' : 'con'} texto');

      await _openMenu(tester);
      _noOverflow(tester, 'menú con imagen');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  for (final text in [_long.first, null]) {
    testWidgets(
      'CA-010-12: tarea actual con PDF (${text == null ? 'sin' : 'con'} '
      'texto), menú, enlaces y editor',
      (tester) async {
        await pumpEn(
          tester,
          tasks: [await _pdfTask(store, 'p', text: text, rank: 'MA')],
        );
        expect(find.byType(PdfStrip), findsOneWidget);
        _noOverflow(tester, 'tarea con PDF');

        await _openMenu(tester);
        _noOverflow(tester, 'menú con PDF');
        await _closeMenu(tester);

        // Hoja de confirmación de los enlaces del PDF (CA-008-12).
        for (final link in [
          WebLink(Uri.parse('https://www.example.com/'), 'www.example.com'),
          MailLink(
            Uri.parse('mailto:someone.with.a.long.name@example.com'),
            'someone.with.a.long.name@example.com',
          ),
          PhoneLink(Uri.parse('tel:+34600000000'), '+34600000000'),
        ]) {
          taskPdfCalls.last.onLink!(link);
          await tester.pumpAndSettle();
          expect(find.byType(LinkConfirmSheet), findsOneWidget);
          _noOverflow(tester, 'hoja de enlaces (${link.runtimeType})');
          await tester.tap(find.text(_en.linkConfirmCancel));
          await tester.pumpAndSettle();
        }

        await _openMenu(tester);
        await tester.tap(find.text(_en.menuEdit));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.byType(AttachmentPreview), findsOneWidget);
        _noOverflow(tester, 'editor con PDF');
      },
    );
  }

  testWidgets('CA-010-12: tarea actual web: cargando, cargada, avisos y menú', (
    tester,
  ) async {
    await pumpEn(tester, tasks: [_webTask('w', rank: 'MA')]);
    expect(find.byType(WebBar), findsOneWidget);
    _noOverflow(tester, 'web al abrir');
    web.last
      ..started(_webAddress)
      ..progress(40);
    await tester.pump();
    _noOverflow(tester, 'web cargando');

    web.last
      ..progress(100)
      ..finished(_webAddress);
    await tester.pumpAndSettle();
    _noOverflow(tester, 'web cargada');

    await _openMenu(tester);
    _noOverflow(tester, 'menú con web');
    // Editar una tarea web abre la hoja "Cargar URL" con su dirección.
    await tester.tap(find.text(_en.menuEdit));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsOneWidget);
    _noOverflow(tester, 'hoja de URL al editar');
  });

  // Los avisos de la tarea web (spec 009 §5).
  for (final (name, fail) in <(String, void Function(FakeWebPageDriver))>[
    ('sin conexión', (d) => d.error(WebLoadError.hostLookup)),
    ('sin https', (d) => d.error(WebLoadError.connect)),
    ('certificado', (d) => d.certificate()),
    ('no es una página', (d) => d.download()),
    ('proceso cerrado', (d) => d.processGone()),
    (
      'intenta abrir otra página',
      (d) => d
        ..started(_webAddress)
        ..started('https://zxq.other.example/q')
        ..started(_webAddress)
        ..started('https://zxq.other.example/q'),
    ),
  ]) {
    testWidgets('CA-010-12: tarea web con el aviso "$name"', (tester) async {
      await pumpEn(tester, tasks: [_webTask('w', rank: 'MA')]);
      fail(web.last);
      await tester.pumpAndSettle();
      expect(find.byType(WebBar), findsOneWidget);
      _noOverflow(tester, 'aviso "$name"');
    });
  }

  testWidgets('CA-010-12: hojas de adjuntar, de URL (con errores) y de '
      'colocación', (tester) async {
    await pumpEn(
      tester,
      tasks: [sampleTask(id: 't0', text: _long[0], rank: 'MA')],
    );
    await _openMenu(tester);
    await tester.tap(find.text(_en.menuNewTask));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(_en.attachButton));
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsOneWidget);
    _noOverflow(tester, 'hoja de adjuntar');

    await tester.tap(find.text(_en.attachUrl));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsOneWidget);
    _noOverflow(tester, 'hoja de URL');

    final field = find.descendant(
      of: find.byType(UrlSheet),
      matching: find.byType(TextField),
    );
    for (final (input, error) in [
      ('', _en.urlErrEmpty),
      ('ftp://example.com/', _en.urlErrScheme),
      ('1.2.3.4.5', _en.urlErrInvalid),
    ]) {
      await tester.enterText(field, input);
      await tester.tap(find.text(_en.urlOpen));
      await tester.pumpAndSettle();
      expect(find.text(error), findsOneWidget);
      _noOverflow(tester, 'hoja de URL con "$error"');
    }

    await tester.enterText(field, _webAddress);
    await tester.pumpAndSettle();
    _noOverflow(tester, 'hoja de URL con una dirección larga');
    await tester.tap(find.text(_en.urlOpen));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsNothing);
    expect(find.byType(WebBar), findsOneWidget);
    _noOverflow(tester, 'tarea web nueva');
  });

  testWidgets('CA-010-12: hoja de colocación (tarea nueva solo texto)', (
    tester,
  ) async {
    await pumpEn(
      tester,
      tasks: [sampleTask(id: 't0', text: _long[0], rank: 'MA')],
    );
    await _openMenu(tester);
    await tester.tap(find.text(_en.menuNewTask));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), _long[1]);
    await tester.tap(find.text(_en.editorContinue));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementSheet), findsOneWidget);
    _noOverflow(tester, 'hoja de colocación');
    await tester.ensureVisible(find.text(_en.placementEnd));
    await tester.pumpAndSettle();
    _noOverflow(tester, 'hoja de colocación, última opción');
  });

  testWidgets('CA-010-12: listado con filas de texto, PDF y web, hoja de '
      'mover y de eliminar', (tester) async {
    await pumpEn(
      tester,
      tasks: [
        sampleTask(id: 't0', text: _long[0], rank: 'MA'),
        await _pdfTask(store, 'p', rank: 'MB'),
        _webTask('w', rank: 'MC'),
        sampleTask(id: 't3', text: _long[1], rank: 'MD'),
      ],
    );
    await _openMenu(tester);
    await tester.tap(find.text(_en.menuAllTasks));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    _noOverflow(tester, 'listado');

    // Se recorre entero: las últimas filas también se dibujan.
    await tester.scrollUntilVisible(
      find.text(_long[1]),
      100,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    _noOverflow(tester, 'listado desplazado');

    // Hoja de mover.
    await tester.tap(handleOf(_long[1]));
    await tester.pumpAndSettle();
    expect(find.byType(MoveSheet), findsOneWidget);
    _noOverflow(tester, 'hoja de mover');
    await tester.tap(find.bySemanticsLabel(_en.menuClose).last);
    await tester.pumpAndSettle();
    expect(find.byType(MoveSheet), findsNothing);
  });

  testWidgets('CA-010-12: "Todo hecho."', (tester) async {
    await pumpEn(tester, tasks: [textTasks().first]);
    await _openDeleteSheet(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is BrutalButton && w.label == _en.deleteConfirm,
      ),
    );
    await tester.pump(_frame);
    await tester.pump(_frame);
    await tester.pump(UnaMotion.sheetOut);
    await tester.pump(UnaMotion.crumple);
    await tester.pumpAndSettle();
    expect(find.byType(AllDoneScreen), findsOneWidget);
    expect(find.text(_en.emptyDoneBody), findsWidgets);
    _noOverflow(tester, 'todo hecho');
  });

  for (final noSpace in [false, true]) {
    testWidgets(
      'CA-010-12: error de almacenamiento (${noSpace ? 'sin espacio' : 'genérico'})',
      (tester) async {
        tester.platformDispatcher.localesTestValue = [const Locale('en')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view
          ..physicalSize = _phone
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await bootstrap(
          openImages: () async {
            final store = MemoryAttachmentStore();
            return (
              store: store,
              images: MemoryAttachmentImages(store),
              importer: const UnavailableImageImporter(),
              pdfImporter: const UnavailablePdfImporter(),
            );
          },
          open: () async => throw StateError(
            noSpace
                ? 'SqliteException(13): database or disk is full'
                : 'SqliteException(26): not a db',
          ),
        );
        await tester.pump();
        expect(find.byType(StorageErrorScreen), findsOneWidget);
        expect(
          find.text(noSpace ? _en.storageErrorNoSpace : _en.storageErrorTitle),
          findsOneWidget,
        );
        _noOverflow(tester, 'error de almacenamiento');
        await tester.scrollUntilVisible(find.byType(BrutalButton), 100);
        _noOverflow(tester, 'error de almacenamiento, botón');
      },
    );
  }
}
