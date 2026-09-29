import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/l10n_leaks.dart';
import '../support/pump_app.dart';

/// Fugas de idioma en lo que expone la app al lector de pantalla (spec 010).
///
/// 1.ª parte (T-010-05): bienvenida, editor, tarea actual (solo texto e
/// imagen), menú, "Todo hecho." y error de almacenamiento, con los anuncios
/// de completar y eliminar (CA-010-07), y la marca de idioma del contenido
/// del usuario (CA-010-10).
/// 2.ª parte (T-010-06): PDF, web, hojas y listado (se añade al final de
/// [main], con los mismos ayudantes).

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
}
