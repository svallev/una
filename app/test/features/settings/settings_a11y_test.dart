import 'dart:ui' show Tristate;

import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import 'settings_harness.dart';

/// Accesibilidad transversal de Ajustes y de la página de Idioma (spec 015,
/// CA-015-20 y CA-015-21; T-015-13): orden del lector con los dos avisos a la
/// vez, encabezados, modalidad, Tab y Mayús+Tab que circulan, Escape que sube,
/// `ensureVisible` y las guías de `meetsGuideline`. Los enlaces se abren sin
/// confirmación (T-015-07b).

/// Lo que cambia con el idioma de la app en estas pruebas.
class _Texts {
  const _Texts({
    required this.code,
    required this.title,
    required this.language,
    required this.languageValue,
    required this.keepAwake,
    required this.keepAwakeHint,
    required this.info,
    required this.privacy,
    required this.licenses,
    required this.help,
    required this.web,
    required this.close,
    required this.back,
    required this.saveError,
    required this.noApp,
  });

  final String code;
  final String title;
  final String language;
  final String languageValue;
  final String keepAwake;
  final String keepAwakeHint;
  final String info;
  final String privacy;
  final String licenses;
  final String help;
  final String web;
  final String close;
  final String back;
  final String saveError;
  final String noApp;

  Locale get locale => Locale(code);
}

const _es = _Texts(
  code: 'es',
  title: 'Ajustes',
  language: 'Idioma',
  languageValue: 'Como el sistema',
  keepAwake: 'Pantalla siempre activa',
  keepAwakeHint: 'Imágenes, documentos y web',
  info: 'Información',
  privacy: 'Política de privacidad',
  licenses: 'Licencias de terceros',
  help: 'Ayuda',
  web: 'Abre una página web en el navegador',
  close: 'Cerrar ajustes',
  back: 'Volver',
  saveError: 'No se pudo guardar el ajuste.',
  noApp: 'No hay ninguna app para abrir este enlace.',
);

const _en = _Texts(
  code: 'en',
  title: 'Settings',
  language: 'Language',
  languageValue: 'Same as system',
  keepAwake: 'Keep screen on',
  keepAwakeHint: 'Images, documents and web',
  info: 'Information',
  privacy: 'Privacy policy',
  licenses: 'Third-party licenses',
  help: 'Help',
  web: 'Opens a web page in the browser',
  close: 'Close settings',
  back: 'Back',
  saveError: "Couldn't save the setting.",
  noApp: "There's no app to open this link.",
);

const _texts = [_es, _en];

Future<void> _tab(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// Abre Ajustes y deja a la vista los dos avisos de error: el de guardado
/// (bajo "Pantalla siempre activa") y el de enlace (tras "Ayuda").
Future<void> _showBothNotices(WidgetTester tester, _Texts t) async {
  await tester.tap(inSettings(find.text(t.keepAwake)));
  await settleSettings(tester);
  final help = inSettings(find.text(t.help));
  await tester.ensureVisible(help);
  await tester.pumpAndSettle();
  await tester.tap(help);
  await settleSettings(tester);
  expect(inSettings(find.text(t.saveError)), findsOneWidget);
  expect(inSettings(find.text(t.noApp)), findsOneWidget);
}

/// Abre la página de Idioma desde el nivel 1.
Future<void> _openLanguage(WidgetTester tester, _Texts t) async {
  await tester.tap(inSettings(find.text(t.language)));
  await settleSettings(tester);
  expect(find.byType(LanguagePage), findsOneWidget);
}

void main() {
  setUpAll(loadAppFonts);

  for (final t in _texts) {
    final lang = t.code.toUpperCase();

    group('Lector de pantalla, $lang (CA-015-20)', () {
      testWidgets(
        'CA-015-20g: con los dos avisos a la vez, título → filas → cada aviso donde se ve → Cerrar, lo último',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: t.locale,
            screenReader: true,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()..error = Exception('x'),
          );
          await _showBothNotices(tester, t);
          final order = readingOrder(tester);
          expect(order.sublist(order.length - 10), [
            t.title,
            '${t.language}, ${t.languageValue}',
            '${t.keepAwake}, ${t.keepAwakeHint}',
            t.saveError,
            t.info,
            '${t.privacy}, ${t.web}',
            '${t.licenses}, ${t.web}',
            '${t.help}, ${t.web}',
            t.noApp,
            t.close,
          ]);
          handle.dispose();
        },
      );

      testWidgets(
        'CA-015-20a/20e: el título y "Información" son encabezados; el título es lo primero que se lee y Cerrar es un botón',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: t.locale,
            screenReader: true,
          );
          bool isHeader(String text) => tester
              .getSemantics(inSettings(find.text(text)))
              .getSemanticsData()
              .flagsCollection
              .isHeader;
          expect(isHeader(t.title), isTrue);
          expect(isHeader(t.info), isTrue);
          expect(isHeader(t.language), isFalse);
          final order = readingOrder(tester);
          expect(
            order.indexOf(t.title),
            lessThan(order.indexOf('${t.language}, ${t.languageValue}')),
          );
          final close = tester
              .getSemantics(find.bySemanticsLabel(t.close))
              .getSemanticsData();
          expect(close.flagsCollection.isButton, isTrue);
          handle.dispose();
        },
      );

      testWidgets(
        'CA-015-20b/20f: en la página de Idioma el título es un encabezado, Volver es un botón y no queda nada de Ajustes alcanzable (modal)',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: t.locale,
            screenReader: true,
          );
          await _openLanguage(tester, t);
          final order = readingOrder(tester);
          // Título, tres opciones y Volver; ni el nivel 1 ni la tarea.
          expect(order.first, t.language);
          expect(order.last, t.back);
          for (final hidden in [
            t.title,
            t.info,
            t.keepAwake,
            t.privacy,
            t.help,
            t.close,
          ]) {
            expect(
              order.where((l) => l.contains(hidden)),
              isEmpty,
              reason: '"$hidden" no debe ser alcanzable bajo el nivel 2',
            );
          }
          final title = tester
              .getSemantics(
                find.descendant(
                  of: find.byType(LanguagePage),
                  matching: find.text(t.language),
                ),
              )
              .getSemanticsData();
          expect(title.flagsCollection.isHeader, isTrue);
          final back = tester
              .getSemantics(find.bySemanticsLabel(t.back))
              .getSemanticsData();
          expect(back.flagsCollection.isButton, isTrue);
          handle.dispose();
        },
      );

      testWidgets(
        'CA-015-20i: Ajustes es modal también con los avisos a la vista: ningún nodo de la tarea ni del menú es alcanzable',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: t.locale,
            screenReader: true,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()..error = Exception('x'),
          );
          await _showBothNotices(tester, t);
          final labels = readingOrder(tester);
          for (final hidden
              in t.code == 'en'
                  ? ['Task menu', 'Edit', 'Delete', 'All my tasks', 'New task']
                  : [
                      'Menú de la tarea',
                      'Editar',
                      'Eliminar',
                      'Todas mis tareas',
                      'Nueva tarea',
                    ]) {
            expect(labels, isNot(contains(hidden)), reason: hidden);
          }
          handle.dispose();
        },
      );

      testWidgets(
        'CA-015-20, CA-015-22: las guías de accesibilidad se cumplen en el nivel 1 (sin avisos y con ellos) y en el nivel 2',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: t.locale,
            screenReader: true,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()..error = Exception('x'),
          );
          Future<void> guidelines() async {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }

          await guidelines();
          await _showBothNotices(tester, t);
          await guidelines();
          await _openLanguage(tester, t);
          await guidelines();
          handle.dispose();
        },
      );
    });

    group('Teclado, $lang (CA-015-21)', () {
      testWidgets(
        'CA-015-21g: Tab y Mayús+Tab circulan dentro de Ajustes, con los avisos a la vista, sin pasar por el título ni salir a la tarea',
        (tester) async {
          await openSettingsScreen(
            tester,
            locale: t.locale,
            keyboard: true,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()..error = Exception('x'),
          );
          await _showBothNotices(tester, t);
          // Con el foco ya dentro de Ajustes, una vuelta entera de Tab.
          final seen = <String?>{};
          for (var i = 0; i < 14; i++) {
            await _tab(tester);
            seen.add(focusedLabel(tester));
          }
          expect(seen, containsAll([t.close, t.language, t.keepAwake, t.help]));
          expect(seen, isNot(contains(t.title)));
          expect(seen, isNot(contains(null)));
          // Desde Cerrar, Mayús+Tab va a la última fila; desde esta, Tab vuelve.
          while (focusedLabel(tester) != t.close) {
            await _tab(tester);
          }
          await _tab(tester, shift: true);
          expect(focusedLabel(tester), t.help);
          await _tab(tester);
          expect(focusedLabel(tester), t.close);
          // Y desde la primera fila, Mayús+Tab va a Cerrar.
          await _tab(tester);
          expect(focusedLabel(tester), t.language);
          await _tab(tester, shift: true);
          expect(focusedLabel(tester), t.close);
        },
      );

      testWidgets(
        'CA-015-21e/21g: en la página de Idioma Tab y Mayús+Tab circulan entre Volver y las tres opciones, y el foco no sale a Ajustes',
        (tester) async {
          await openSettingsScreen(tester, locale: t.locale, keyboard: true);
          await _openLanguage(tester, t);
          final seen = <String?>[];
          for (var i = 0; i < 8; i++) {
            await _tab(tester);
            seen.add(focusedLabel(tester));
          }
          expect(seen.toSet(), contains(t.back));
          for (final outside in [
            t.title,
            t.keepAwake,
            t.privacy,
            t.licenses,
            t.help,
            t.close,
          ]) {
            expect(seen, isNot(contains(outside)), reason: outside);
          }
          // Hay una vuelta: Tab y Mayús+Tab terminan en el mismo sitio.
          final before = focusedLabel(tester);
          await _tab(tester);
          await _tab(tester, shift: true);
          expect(focusedLabel(tester), before);
        },
      );

      testWidgets(
        'CA-015-21c: Escape sube un nivel (de la página de Idioma a Ajustes, y de Ajustes a la tarea)',
        (tester) async {
          await openSettingsScreen(tester, locale: t.locale, keyboard: true);
          await _openLanguage(tester, t);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settleSettings(tester);
          expect(find.byType(LanguagePage), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settleSettings(tester);
          expect(find.byType(SettingsScreen), findsNothing);
        },
      );

      testWidgets(
        'CA-015-21f: al 200 % a 360x480 el foco lleva cada fila a la vista (ensureVisible), también la última y los avisos',
        (tester) async {
          final opener = FakeOpener()..available = false;
          await openSettingsScreen(
            tester,
            locale: t.locale,
            keyboard: true,
            textScale: 2,
            size: const Size(360, 640),
            opener: opener,
            repo: SettingsRepo()..error = Exception('x'),
          );
          // Una pantalla corta: el contenido se desplaza.
          tester.view.physicalSize = const Size(360, 480);
          await tester.pumpAndSettle();
          final scroll = inSettings(find.byType(SingleChildScrollView)).first;
          final viewport = tester.getRect(scroll);
          Rect focusedRect() {
            final ctx = FocusManager.instance.primaryFocus!.context!;
            final box = ctx.findRenderObject()! as RenderBox;
            return box.localToGlobal(Offset.zero) & box.size;
          }

          // Una vuelta entera hacia delante: Idioma, Pantalla, Política,
          // Licencias, Ayuda, Cerrar (la vuelta) e Idioma otra vez, ya de
          // nuevo arriba (el foco la lleva a la vista hacia atrás también).
          final seen = <String?>[];
          void expectRowInView() {
            final label = focusedLabel(tester);
            seen.add(label);
            final rect = focusedRect();
            if (label == t.close) return;
            expect(
              rect.top,
              greaterThanOrEqualTo(viewport.top - 0.5),
              reason: 'la fila "$label" no se pierde por arriba',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(480 + 0.5),
              reason: 'la fila "$label" no se pierde por abajo',
            );
          }

          for (var i = 0; i < 7; i++) {
            await _tab(tester);
            await tester.pumpAndSettle();
            expectRowInView();
          }
          expect(seen, [
            t.language,
            t.keepAwake,
            t.privacy,
            t.licenses,
            t.help,
            t.close,
            t.language,
          ]);
          // Y hacia atrás: Cerrar y la última fila, que vuelve a bajar.
          await _tab(tester, shift: true);
          await tester.pumpAndSettle();
          expectRowInView();
          await _tab(tester, shift: true);
          await tester.pumpAndSettle();
          expectRowInView();
          expect(seen.sublist(seen.length - 2), [t.close, t.help]);
          // Tras llegar a Ayuda y abrirla (sin app), su aviso se ve.
          while (focusedLabel(tester) != t.help) {
            await _tab(tester);
            await tester.pumpAndSettle();
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await settleSettings(tester);
          final notice = tester.getRect(inSettings(find.text(t.noApp)));
          expect(notice.bottom, lessThanOrEqualTo(480));
          expect(notice.top, greaterThanOrEqualTo(0));
          expect(opener.opened, isEmpty, reason: 'sin app: no se abre nada');
        },
      );
    });
  }

  testWidgets(
    'CA-015-20d: el interruptor es un nodo con su estado y el subtítulo; con un guardado fallido el estado no cambia en el árbol',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openSettingsScreen(
        tester,
        screenReader: true,
        repo: SettingsRepo()..error = Exception('x'),
      );
      Tristate toggled() => tester
          .getSemantics(
            find.bySemanticsLabel('${_es.keepAwake}, ${_es.keepAwakeHint}'),
          )
          .getSemanticsData()
          .flagsCollection
          .isToggled;
      expect(toggled(), Tristate.isFalse);
      await tester.tap(inSettings(find.text(_es.keepAwake)));
      await settleSettings(tester);
      expect(
        toggled(),
        Tristate.isFalse,
        reason: 'el guardado falla: nunca pasa a activado ni "parpadea"',
      );
      handle.dispose();
    },
  );
}
