import 'dart:convert';
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
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
import 'package:app/features/complete/hold_to_complete_button.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../features/task_list/list_harness.dart';
import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_pdf_importer.dart';
import '../support/fake_pdf_view.dart';
import '../support/fake_web_page_driver.dart';
import '../support/l10n_leaks.dart';
import '../support/pdfrx.dart';
import '../support/pump_app.dart';

/// Fugas de idioma en lo que expone la app al lector de pantalla (spec 010).
///
/// 1.ª parte (T-010-05): bienvenida, editor, tarea actual (solo texto e
/// imagen), menú, "Todo hecho." y error de almacenamiento, con los anuncios
/// de completar y eliminar (CA-010-07), y la marca de idioma del contenido
/// del usuario (CA-010-10).
/// 2.ª parte (T-010-06): PDF, web, hojas y listado (se añade al final de
/// [main], con los mismos ayudantes).
///
/// CA-010-10, límite de estos tests: solo se comprueba que **ningún nodo lleva
/// un idioma ajeno** (negativo). La comprobación positiva (que el nodo de la
/// tarea, el de una fila o el del campo del editor lleven `SemanticsData.locale`
/// = idioma de la app) no es posible aquí: con Flutter 3.47 el framework no
/// marca ningún nodo con `locale` (probado: todos salen `null` en la tarea
/// actual, el menú y el editor; solo lo pone quien use
/// `Semantics(localeForSubtree: …)` y la app no lo usa). Un test positivo
/// fallaría; uno que aceptara `null` pasaría en vacío. Por eso la voz del
/// contenido del usuario solo se verifica a mano (T-010-10 b; el detector de
/// abajo se prueba con una marca `ca` puesta a mano).

const _frame = Duration(milliseconds: 16);

/// Textos de tarea neutros (ni ES ni EN): el texto del usuario queda fuera de
/// CA-010-07 y no debe provocar falsos positivos.
const _neutral = ['Zxq 1', 'Zxq 2', 'Zxq 3'];

/// Una tarea en catalán (CA-010-10): no es ninguno de los idiomas de la app.
const _catalan = 'Trucar a la Marta demà per parlar de la reunió';

AppLocalizations _l10n(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

/// Mantiene pulsado el botón de completar y lo suelta.
Future<void> _hold(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(HoldToCompleteButton)),
  );
  await tester.pump();
  await tester.pump(UnaMotion.holdToComplete);
  await tester.pump(_frame);
  await gesture.up();
  await tester.pump(_frame);
}

/// Deja terminar la pausa, la rotura, la enhorabuena y el fundido.
Future<void> _celebrate(WidgetTester tester) async {
  await tester.pump(UnaMotion.holdDonePause);
  await tester.pump(_frame);
  await tester.pump(UnaMotion.successHold);
  await tester.pump(UnaMotion.successFade);
  await tester.pump(_frame);
  await tester.pump(UnaMotion.introFade);
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await tester.pumpAndSettle();
  expect(find.byType(MenuSheet), findsOneWidget);
}

/// Menú → Eliminar → Eliminar, hasta que termina el arrugado.
Future<void> _delete(WidgetTester tester, AppLocalizations l10n) async {
  await _openMenu(tester, l10n);
  await tester.tap(find.text(l10n.menuDelete));
  await tester.pumpAndSettle();
  expect(find.byType(DeleteConfirmSheet), findsOneWidget);
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
    ),
  );
  await tester.pump(_frame);
  await tester.pump(_frame);
  await tester.pump(UnaMotion.sheetOut);
  await tester.pump(UnaMotion.crumple);
  await tester.pumpAndSettle();
}

/// Mensajes de los anuncios capturados (para comprobar que sí se anunció).
List<String> _messages(List<CapturedAccessibilityAnnouncement> said) => [
  for (final a in said) a.message,
];

/// Nodos del árbol semántico con una marca de idioma distinta de la app
/// (CA-010-10): `locale` o un `LocaleStringAttribute` en la etiqueta, el
/// valor, la pista o sus variantes.
List<String> _foreignLocaleMarks(WidgetTester tester, String languageCode) {
  final found = <String>[];
  bool foreign(Locale? locale) =>
      locale != null && locale.languageCode != languageCode;
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (foreign(data.locale)) found.add('locale ${data.locale}: ${data.label}');
    for (final attributed in [
      data.attributedLabel,
      data.attributedValue,
      data.attributedHint,
      data.attributedIncreasedValue,
      data.attributedDecreasedValue,
    ]) {
      for (final attribute in attributed.attributes) {
        if (attribute is LocaleStringAttribute && foreign(attribute.locale)) {
          found.add('${attribute.locale}: "${attributed.string}"');
        }
      }
    }
    node.visitChildren(visit);
    return true;
  }

  for (final RenderView view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return found;
}

void _expectNoForeignLocale(WidgetTester tester, String languageCode) {
  expect(
    _foreignLocaleMarks(tester, languageCode),
    isEmpty,
    reason: 'Marcas de idioma ajenas en la app en "$languageCode" (CA-010-10)',
  );
}

void main() {
  // El visor real de un test de la 2.ª parte (T-010-06).
  setUpAll(initPdfrxForTests);

  testWidgets('CA-010-10: el detector ve una marca de idioma ajena', (
    tester,
  ) async {
    await pumpWithApp(
      tester,
      Semantics(
        attributedLabel: AttributedString(
          _catalan,
          attributes: [
            LocaleStringAttribute(
              range: const TextRange(start: 0, end: 6),
              locale: const Locale('ca'),
            ),
          ],
        ),
        child: const SizedBox(width: 10, height: 10),
      ),
    );
    expect(_foreignLocaleMarks(tester, 'es'), hasLength(1));
    expect(_foreignLocaleMarks(tester, 'ca'), isEmpty);
  });

  for (final lang in L10nLeaks.languages) {
    final l10n = _l10n(lang);
    final locale = Locale(lang);

    group('CA-010-07 ($lang): sin textos del otro idioma', () {
      testWidgets('bienvenida y editor de la primera tarea', (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          firstRunDone: false,
        );
        expect(find.byType(WelcomeIntro), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.welcomeTitle), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        await tester.tap(find.byType(WelcomeIntro));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        // Con texto: aparecen "Guardar" activo y los caracteres restantes.
        await tester.enterText(find.byType(EditableText), _neutral.first);
        await tester.pumpAndSettle();
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      testWidgets('tarea actual solo texto, menú y editor de edición', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          tasks: _neutral,
        );
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.currentTaskSemantics(_neutral.first)),
          findsOneWidget,
        );
        expectNoL10nLeaks(tester, languageCode: lang);

        await _openMenu(tester, l10n);
        expect(find.text(l10n.menuSettings), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        await tester.tap(find.text(l10n.menuEdit));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      testWidgets('menú con una sola tarea', (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          tasks: [_neutral.first],
        );
        await _openMenu(tester, l10n);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      for (final (origin, text) in [
        (AttachmentOrigin.camera, _neutral.first),
        (AttachmentOrigin.gallery, null),
      ]) {
        testWidgets('tarea actual con imagen (${origin.name}, '
            '${text == null ? 'sin' : 'con'} texto)', (tester) async {
          final store = MemoryAttachmentStore();
          final attachment = await store.commit(
            stageImage(store, 'a1', origin: origin),
            DateTime.utc(2026, 9, 20),
          );
          final base = sampleTask(id: 'img', text: text ?? 'x');
          final repo = InMemoryTaskRepository();
          await repo.insert(base.withContent(text, attachment, base.updatedAt));
          await pumpUnaApp(
            tester,
            repo: repo,
            locale: locale,
            overrides: [attachmentStoreProvider.overrideWithValue(store)],
          );
          await tester.pumpAndSettle();
          expect(find.byType(TaskImage), findsOneWidget);
          expectNoL10nLeaks(tester, languageCode: lang);

          await _openMenu(tester, l10n);
          expectNoL10nLeaks(tester, languageCode: lang);
        });
      }

      testWidgets('anuncios de completar y eliminar, y "Todo hecho."', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          tasks: _neutral,
        );
        tester.takeAnnouncements();

        // Completar con siguiente: la enhorabuena y su anuncio.
        await _hold(tester);
        await tester.pump(UnaMotion.holdDonePause);
        await tester.pump(_frame);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: []);
        await _celebrate(tester);
        var said = tester.takeAnnouncements();
        expect(_messages(said), [l10n.a11yCompletedNext(_neutral[1])]);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);

        // Eliminar con siguiente.
        await _delete(tester, l10n);
        said = tester.takeAnnouncements();
        expect(_messages(said), [l10n.a11yDeletedNext(_neutral[2])]);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);

        // Completar la última: "Todo hecho.".
        await _hold(tester);
        await _celebrate(tester);
        said = tester.takeAnnouncements();
        expect(_messages(said), [l10n.a11yCompletedAllDone]);
        expect(find.byType(AllDoneScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);
      });

      testWidgets('anuncio de eliminar la última y "Todo hecho."', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          tasks: [_neutral.first],
        );
        tester.takeAnnouncements();
        await _delete(tester, l10n);
        final said = tester.takeAnnouncements();
        expect(_messages(said), [l10n.a11yDeletedAllDone]);
        expect(find.byType(AllDoneScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);
      });

      for (final noSpace in [false, true]) {
        testWidgets('error de almacenamiento '
            '(${noSpace ? 'sin espacio' : 'genérico'})', (tester) async {
          tester.platformDispatcher.localesTestValue = [locale];
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
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
            find.text(
              noSpace ? l10n.storageErrorNoSpace : l10n.storageErrorTitle,
            ),
            findsOneWidget,
          );
          expectNoL10nLeaks(tester, languageCode: lang);
        });
      }
    });

    group('CA-010-10 ($lang): el contenido del usuario, sin idioma ajeno', () {
      testWidgets('tarea en catalán: tarea actual, menú y editor', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: locale,
          tasks: [_catalan, _neutral.first],
        );
        expect(
          find.bySemanticsLabel(l10n.currentTaskSemantics(_catalan)),
          findsOneWidget,
        );
        _expectNoForeignLocale(tester, lang);

        await _openMenu(tester, l10n);
        _expectNoForeignLocale(tester, lang);

        await tester.tap(find.text(l10n.menuEdit));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text(_catalan), findsOneWidget);
        _expectNoForeignLocale(tester, lang);
      });

      testWidgets('tarea en catalán con imagen', (tester) async {
        final store = MemoryAttachmentStore();
        final attachment = await store.commit(
          stageImage(store, 'a1'),
          DateTime.utc(2026, 9, 20),
        );
        final base = sampleTask(id: 'img', text: _catalan);
        final repo = InMemoryTaskRepository();
        await repo.insert(
          base.withContent(_catalan, attachment, base.updatedAt),
        );
        await pumpUnaApp(
          tester,
          repo: repo,
          locale: locale,
          overrides: [attachmentStoreProvider.overrideWithValue(store)],
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskImage), findsOneWidget);
        _expectNoForeignLocale(tester, lang);
      });
    });
  }

  // 2.ª parte (T-010-06): PDF, web, hojas y listado.
  late MemoryAttachmentStore store;
  late FakePdfImporter pdfs;
  late FakeWebPages web;

  setUp(() {
    store = MemoryAttachmentStore();
    pdfs = FakePdfImporter(store)..pickedName = _pdfName;
    web = FakeWebPages();
    taskPdfCalls.clear();
  });

  /// Adjuntos sin disco, sin red y, salvo con [realPdf], con el visor de PDF
  /// sustituido.
  List<Override> overrides({bool realPdf = false}) => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
    pdfImporterProvider.overrideWithValue(pdfs),
    if (!realPdf) ...fakePdfViews,
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(_Opener()),
  ];

  for (final lang in L10nLeaks.languages) {
    final l10n = _l10n(lang);
    final locale = Locale(lang);

    Future<InMemoryTaskRepository> pumpWith(
      WidgetTester tester,
      List<Task> tasks, {
      bool realPdf = false,
    }) async {
      final repo = InMemoryTaskRepository();
      for (final t in tasks) {
        await repo.insert(t);
      }
      await pumpUnaApp(
        tester,
        repo: repo,
        locale: locale,
        overrides: overrides(realPdf: realPdf),
      );
      if (!realPdf) await tester.pumpAndSettle();
      return repo;
    }

    Future<void> closeMenu(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel(l10n.menuClose).last);
      await tester.pumpAndSettle();
      expect(find.byType(MenuSheet), findsNothing);
    }

    group('CA-010-07 ($lang): PDF, web, hojas y listado', () {
      for (final text in [_neutral.first, null]) {
        testWidgets('tarea actual con PDF (${text == null ? 'sin' : 'con'} '
            'texto), menú, confirmación de enlaces y editor', (tester) async {
          await pumpWith(tester, [
            await _pdfTask(store, 'p', text: text, rank: 'MA'),
          ]);
          expect(find.byType(PdfStrip), findsOneWidget);
          expectNoL10nLeaks(tester, languageCode: lang);

          await _openMenu(tester, l10n);
          expectNoL10nLeaks(tester, languageCode: lang);
          await closeMenu(tester);

          // Hoja de confirmación de los enlaces del PDF (CA-008-12).
          for (final link in [
            WebLink(Uri.parse('https://zxq.example/'), 'zxq.example'),
            MailLink(Uri.parse('mailto:zxq@zxq.example'), 'zxq@zxq.example'),
            PhoneLink(Uri.parse('tel:+34600000000'), '+34600000000'),
          ]) {
            taskPdfCalls.last.onLink!(link);
            await tester.pumpAndSettle();
            expect(find.byType(LinkConfirmSheet), findsOneWidget);
            expectNoL10nLeaks(tester, languageCode: lang);
            await tester.tap(find.text(l10n.linkConfirmCancel));
            await tester.pumpAndSettle();
          }

          await _openMenu(tester, l10n);
          await tester.tap(find.text(l10n.menuEdit));
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(find.byType(AttachmentPreview), findsOneWidget);
          expectNoL10nLeaks(tester, languageCode: lang);
        });
      }

      testWidgets('tarea actual con PDF, con el visor real (PDFium)', (
        tester,
      ) async {
        await pumpWith(tester, [
          await _pdfTask(
            store,
            'p',
            text: _neutral.first,
            rank: 'MA',
            bytes: base64Decode(pdfFixtures['pages_20.pdf']!),
          ),
        ], realPdf: true);
        // El motor carga el documento fuera del reloj falso de los tests.
        for (var i = 0; i < 200; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          find.bySemanticsLabel(RegExp('^${l10n.pdfPageA11y(1, 20)}')),
          findsOneWidget,
        );
        // El texto de las páginas es contenido del usuario (fuera de
        // CA-010-07) y el del PDF de prueba está en español ("Pagina 1 de
        // 20"): en inglés, "1 de" coincide con un fragmento del ARB español.
        expectNoL10nLeaks(tester, languageCode: lang, allowed: {'1 de'});
        // pdfrx deja temporizadores propios: se desmonta y se dejan correr.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('tarea actual web: cargando, cargada, menú y editor', (
        tester,
      ) async {
        await pumpWith(tester, [_webTask('w', rank: 'MA')]);
        expect(find.byType(WebBar), findsOneWidget);
        web.last
          ..started(_webAddress)
          ..progress(40);
        await tester.pump();
        expectNoL10nLeaks(tester, languageCode: lang);

        web.last
          ..progress(100)
          ..finished(_webAddress);
        await tester.pumpAndSettle();
        expectNoL10nLeaks(tester, languageCode: lang);

        await _openMenu(tester, l10n);
        expectNoL10nLeaks(tester, languageCode: lang);
        // Editar una tarea web abre la hoja "Cargar URL" con su dirección.
        await tester.tap(find.text(l10n.menuEdit));
        await tester.pumpAndSettle();
        expect(find.byType(UrlSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      // Los avisos de la tarea web (spec 009 §5), con sus anuncios.
      for (final (name, url, fail)
          in <(String, String, void Function(FakeWebPageDriver))>[
            (
              'sin conexión',
              _webAddress,
              (d) => d.error(WebLoadError.hostLookup),
            ),
            (
              'sin https',
              'http://www.zxq.example/qz',
              (d) => d.error(WebLoadError.connect),
            ),
            ('certificado', _webAddress, (d) => d.certificate()),
            ('no es una página', _webAddress, (d) => d.download()),
            ('proceso cerrado', _webAddress, (d) => d.processGone()),
            (
              'intenta abrir otra página',
              _webAddress,
              (d) => d
                ..started(_webAddress)
                ..started('https://zxq.other.example/q')
                ..started(_webAddress)
                ..started('https://zxq.other.example/q'),
            ),
          ]) {
        testWidgets('tarea web con el aviso "$name"', (tester) async {
          await pumpWith(tester, [_webTask('w', rank: 'MA', url: url)]);
          tester.takeAnnouncements();
          fail(web.last);
          await tester.pumpAndSettle();
          expect(find.byType(WebBar), findsOneWidget);
          expectNoL10nLeaks(tester, languageCode: lang);
        });
      }

      testWidgets('hojas de adjuntar y de URL (con sus errores) y de '
          'colocación', (tester) async {
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _neutral.first, rank: 'MA'),
        ]);
        await _openMenu(tester, l10n);
        await tester.tap(find.text(l10n.menuNewTask));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.attachButton));
        await tester.pumpAndSettle();
        expect(find.byType(AttachSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        await tester.tap(find.text(l10n.attachUrl));
        await tester.pumpAndSettle();
        expect(find.byType(UrlSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        final field = find.descendant(
          of: find.byType(UrlSheet),
          matching: find.byType(TextField),
        );
        for (final (input, error) in [
          ('', l10n.urlErrEmpty),
          ('ftp://zxq.example/', l10n.urlErrScheme),
          ('1.2.3.4.5', l10n.urlErrInvalid),
        ]) {
          await tester.enterText(field, input);
          tester.takeAnnouncements();
          await tester.tap(find.text(l10n.urlOpen));
          await tester.pumpAndSettle();
          expect(find.text(error), findsOneWidget);
          final said = tester.takeAnnouncements();
          expect(_messages(said), [error]);
          expectNoL10nLeaks(tester, languageCode: lang, announcements: said);
        }

        await tester.enterText(field, _webAddress);
        await tester.tap(find.text(l10n.urlOpen));
        await tester.pumpAndSettle();
        // "Abrir" crea la tarea web arriba, sin colocación (CA-009-03).
        expect(find.byType(UrlSheet), findsNothing);
        expect(find.byType(WebBar), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      testWidgets('"Subir archivo": el editor con el PDF', (tester) async {
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _neutral.first, rank: 'MA'),
        ]);
        await _openMenu(tester, l10n);
        await tester.tap(find.text(l10n.menuNewTask));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(l10n.attachButton));
        await tester.pumpAndSettle();
        tester.takeAnnouncements();
        await tester.tap(find.text(l10n.attachPickFile));
        await tester.pumpAndSettle();
        expect(find.byType(AttachmentPreview), findsOneWidget);
        expect(find.byType(PdfStrip), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        // Con PDF, "Continuar" la pone arriba sin preguntar (CA-008-05).
        await tester.tap(find.text(l10n.editorContinue));
        await tester.pumpAndSettle();
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.byType(PdfStrip), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      testWidgets('hoja de colocación (tarea nueva solo texto)', (
        tester,
      ) async {
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _neutral.first, rank: 'MA'),
        ]);
        await _openMenu(tester, l10n);
        await tester.tap(find.text(l10n.menuNewTask));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), _neutral[1]);
        await tester.tap(find.text(l10n.editorContinue));
        await tester.pumpAndSettle();
        expect(find.byType(PlacementSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        tester.takeAnnouncements();
        await tester.tap(find.text(l10n.placementEnd));
        await tester.pumpAndSettle();
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });

      testWidgets('hoja de eliminar (tarea con texto y con PDF)', (
        tester,
      ) async {
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _neutral.first, rank: 'MA'),
          await _pdfTask(store, 'p', rank: 'MB'),
        ]);
        for (var i = 0; i < 2; i++) {
          await _openMenu(tester, l10n);
          await tester.tap(find.text(l10n.menuDelete));
          await tester.pumpAndSettle();
          expect(find.byType(DeleteConfirmSheet), findsOneWidget);
          expectNoL10nLeaks(tester, languageCode: lang);
          if (i == 0) {
            // Se elimina la de texto; la siguiente es la del PDF.
            await tester.tap(
              find.byWidgetPredicate(
                (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
              ),
            );
            await tester.pump(_frame);
            await tester.pump(_frame);
            await tester.pump(UnaMotion.sheetOut);
            await tester.pump(UnaMotion.crumple);
            await tester.pumpAndSettle();
            final said = tester.takeAnnouncements();
            expect(said, hasLength(1));
            expectNoL10nLeaks(tester, languageCode: lang, announcements: said);
            expect(find.byType(PdfStrip), findsOneWidget);
          }
        }
      });

      testWidgets('listado: filas de texto, PDF y web, hoja de mover, hoja de '
          'eliminar y anuncios de eliminar desde la fila', (tester) async {
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _neutral[0], rank: 'MA'),
          await _pdfTask(store, 'p', rank: 'MB'),
          _webTask('w', rank: 'MC'),
          sampleTask(id: 't3', text: _neutral[1], rank: 'MD'),
        ]);
        await _openMenu(tester, l10n);
        await tester.tap(find.text(l10n.menuAllTasks));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);

        // Hoja de mover.
        await tester.tap(handleOf(_neutral[1]));
        await tester.pumpAndSettle();
        expect(find.byType(MoveSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
        await tester.tap(find.bySemanticsLabel(l10n.menuClose).last);
        await tester.pumpAndSettle();
        expect(find.byType(MoveSheet), findsNothing);

        // Eliminar la última desde su acción: "Quedan 3".
        tester.takeAnnouncements();
        await _rowAction(
          tester,
          l10n.a11yRowPosition(4, 4, _neutral[1]),
          l10n.deleteA11yAction,
        );
        await tester.pumpAndSettle();
        await tester.pump(UnaMotion.doubleTapWindow);
        expect(find.byType(DeleteConfirmSheet), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
        await _confirmListDelete(tester, l10n);
        var said = tester.takeAnnouncements();
        expect(_messages(said), [l10n.a11yDeletedFromList(3)]);
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);

        // Eliminar la actual desde su acción: "Siguiente: …" (la del PDF).
        await _rowAction(
          tester,
          l10n.a11yRowCurrent(3, _neutral[0]),
          l10n.deleteA11yAction,
        );
        await tester.pumpAndSettle();
        await tester.pump(UnaMotion.doubleTapWindow);
        await _confirmListDelete(tester, l10n);
        said = tester.takeAnnouncements();
        expect(said, hasLength(1));
        expectNoL10nLeaks(tester, languageCode: lang, announcements: said);
        expect(find.byType(TaskListScreen), findsOneWidget);
        expectNoL10nLeaks(tester, languageCode: lang);
      });
    });

    group('CA-010-10 ($lang): el contenido del usuario, sin idioma ajeno', () {
      testWidgets('PDF con nombre y texto en catalán, y listado', (
        tester,
      ) async {
        await pumpWith(tester, [
          await _pdfTask(
            store,
            'p',
            text: _catalan,
            rank: 'MA',
            name: 'Reunió de demà.pdf',
          ),
          _webTask('w', rank: 'MB'),
          sampleTask(id: 't2', text: _catalan, rank: 'MC'),
        ]);
        expect(find.byType(PdfStrip), findsOneWidget);
        _expectNoForeignLocale(tester, lang);

        await _openMenu(tester, l10n);
        await tester.tap(find.text(l10n.menuAllTasks));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        _expectNoForeignLocale(tester, lang);
      });
    });
  }
}

const _pdfName = 'Zxq.pdf';
const _webAddress = 'https://www.zxq.example/qz';

/// Tarea con un PDF ya guardado en [store]; con [bytes], un PDF de verdad.
Future<Task> _pdfTask(
  MemoryAttachmentStore store,
  String id, {
  String? text,
  required String rank,
  String name = _pdfName,
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
      originalName: name,
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

/// Ejecuta la acción [action] del nodo con la etiqueta [row] (lector).
Future<void> _rowAction(WidgetTester tester, String row, String action) async {
  final node = tester.getSemantics(find.bySemanticsLabel(row));
  final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)!.label == action,
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

/// Confirma la hoja de eliminar del listado y deja salir la hoja.
Future<void> _confirmListDelete(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}
