import 'package:app/app/theme/tokens.g.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/ui/radio_row.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import 'settings_harness.dart';

/// Texto grande y movimiento en Ajustes y en la página de Idioma (spec 015,
/// CA-015-22; T-015-13): el texto del sistema al 200 % en un móvil de 360 dp,
/// en español y en inglés, con "reducir movimiento" activo o no. Ni cortes, ni
/// solapes, ni desbordamientos; el valor de "Idioma" y la línea de "Como el
/// sistema" pasan a una segunda línea; los avisos de error quedan a la vista.

/// Un repositorio cuyo guardado del idioma falla (texto que no debe verse).
class _LocaleFailingRepo extends SettingsRepo {
  @override
  Future<void> setLocale(LocaleChoice choice) async =>
      throw StateError('texto-secreto');
}

/// Lo que cambia con el idioma de la app.
class _Lang {
  const _Lang(
    this.code, {
    required this.title,
    required this.language,
    required this.languageValue,
    required this.resulting,
    required this.keepAwake,
    required this.hint,
    required this.lockZoom,
    required this.lockHint,
    required this.help,
    required this.saveError,
    required this.noApp,
    required this.back,
    required this.other,
  });

  final String code;
  final String title;
  final String language;
  final String languageValue;

  /// El idioma que resulta de "Como el sistema" (la línea de debajo).
  final String resulting;
  final String keepAwake;
  final String hint;
  final String lockZoom;
  final String lockHint;
  final String help;
  final String saveError;
  final String noApp;
  final String back;

  /// Una opción de idioma distinta de la vigente (para provocar el fallo).
  final String other;

  Locale get locale => Locale(code);
}

const _langs = [
  _Lang(
    'es',
    title: 'Ajustes',
    language: 'Idioma',
    languageValue: 'Como el sistema',
    resulting: 'Español',
    keepAwake: 'Pantalla siempre activa',
    hint: 'Imágenes, documentos y web',
    lockZoom: 'Bloquear zoom',
    lockHint: 'Solo imágenes: sin zoom ni scroll',
    help: 'Ayuda',
    saveError: 'No se pudo guardar el ajuste.',
    noApp: 'No hay ninguna app para abrir este enlace.',
    back: 'Volver',
    other: 'English',
  ),
  _Lang(
    'en',
    title: 'Settings',
    language: 'Language',
    languageValue: 'Same as system',
    resulting: 'English',
    keepAwake: 'Keep screen on',
    hint: 'Images, documents and web',
    lockZoom: 'Lock zoom',
    lockHint: 'Images only: no zoom or scroll',
    help: 'Help',
    saveError: "Couldn't save the setting.",
    noApp: "There's no app to open this link.",
    back: 'Back',
    other: 'Español',
  ),
];

/// 360 dp de ancho: el móvil más estrecho de CA-015-22.
const _size = Size(360, 640);

/// Ninguna palabra de [text] se parte (como CA-001-07) y el texto cabe
/// dentro de la pantalla.
void _expectWhole(WidgetTester tester, Finder finder, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(finder.first);
  expect(
    paragraph.getMinIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(paragraph.size.width + 0.5),
    reason: 'se parte una palabra de "$text"',
  );
  final rect = tester.getRect(finder.first);
  final screen = tester.view.physicalSize;
  expect(rect.left, greaterThanOrEqualTo(0), reason: 'a la izquierda: $text');
  expect(
    rect.right,
    lessThanOrEqualTo(screen.width),
    reason: 'a la derecha: $text',
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in _langs) {
    for (final reduced in [false, true]) {
      final name =
          '${lang.code.toUpperCase()}, ${reduced ? 'con' : 'sin'} reducir movimiento';

      testWidgets(
        'CA-015-22 ($name): Ajustes al 200 % a 360 dp con los dos avisos: sin desbordes, el valor de "Idioma" en segunda línea y los avisos a la vista',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: lang.locale,
            textScale: 2,
            size: _size,
            reduced: reduced,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()..error = Exception('texto-secreto'),
          );
          await tester.tap(inSettings(find.text(lang.keepAwake)));
          await settleSettings(tester);
          final help = inSettings(find.text(lang.help));
          await tester.ensureVisible(help);
          await tester.pumpAndSettle();
          await tester.tap(help);
          await settleSettings(tester);
          expect(tester.takeException(), isNull);

          // El valor de "Idioma" baja bajo el nombre sin recortarse.
          await tester.drag(
            inSettings(find.byType(SingleChildScrollView)),
            const Offset(0, 3000),
          );
          await tester.pumpAndSettle();
          final nameRect = tester.getRect(
            inSettings(find.text(lang.language)).first,
          );
          final valueRect = tester.getRect(
            inSettings(find.text(lang.languageValue)).first,
          );
          expect(
            valueRect.top,
            greaterThanOrEqualTo(nameRect.bottom - 1),
            reason: 'el valor pasa a una segunda línea',
          );
          for (final text in [
            lang.title,
            lang.language,
            lang.languageValue,
            lang.keepAwake,
            lang.hint,
          ]) {
            _expectWhole(tester, inSettings(find.text(text)), text);
          }

          // El interruptor entero cabe en su fila: el pomo y la pista dentro
          // (en las dos filas de interruptor).
          expect(find.byType(UnaSwitchRow), findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            final row = tester.getRect(find.byType(UnaSwitchRow).at(i));
            expect(
              row.contains(
                tester.getCenter(find.byKey(UnaSwitchRow.knobKey).at(i)),
              ),
              isTrue,
            );
            expect(
              tester.getRect(find.byKey(UnaSwitchRow.trackKey).at(i)).right,
              lessThanOrEqualTo(_size.width),
            );
          }

          // Los avisos, enteros y dentro de la pantalla tras desplazar al
          // final.
          await tester.drag(
            inSettings(find.byType(SingleChildScrollView)),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          for (final notice in [lang.saveError, lang.noApp]) {
            _expectWhole(tester, inSettings(find.text(notice)), notice);
          }
          final end = tester.getRect(inSettings(find.text(lang.noApp)));
          expect(end.bottom, lessThanOrEqualTo(_size.height));
          expect(tester.takeException(), isNull);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets(
        'CA-017-15 ($name): Ajustes al 200 % a 360 dp con "Bloquear zoom" y los tres avisos: nombre y subtítulo enteros, la fila crece, nada se solapa ni se corta',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: lang.locale,
            textScale: 2,
            size: _size,
            reduced: reduced,
            opener: FakeOpener()..available = false,
            repo: SettingsRepo()
              ..error = Exception('texto-secreto')
              ..lockError = Exception('texto-secreto'),
          );
          for (final label in [lang.keepAwake, lang.lockZoom, lang.help]) {
            final row = inSettings(find.text(label));
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            await tester.tap(row);
            await settleSettings(tester);
          }
          expect(tester.takeException(), isNull);
          expect(inSettings(find.text(lang.saveError)), findsNWidgets(2));

          // El nombre y el subtítulo, enteros, dentro de la fila y uno bajo el
          // otro; la fila es más alta que a tamaño normal (76).
          final row = tester.getRect(
            find.byWidgetPredicate(
              (w) => w is UnaSwitchRow && w.label == lang.lockZoom,
            ),
          );
          expect(row.height, greaterThan(UnaSizes.settingsRowSwitchHint));
          final name = tester.getRect(inSettings(find.text(lang.lockZoom)));
          final hint = tester.getRect(inSettings(find.text(lang.lockHint)));
          expect(name.top, greaterThanOrEqualTo(row.top));
          expect(hint.bottom, lessThanOrEqualTo(row.bottom + 0.5));
          expect(hint.top, greaterThanOrEqualTo(name.bottom - 1));
          for (final text in [lang.lockZoom, lang.lockHint]) {
            _expectWhole(tester, inSettings(find.text(text)), text);
          }
          // El subtítulo pasa a más de una línea (no se recorta a una).
          final hintLines = tester
              .renderObject<RenderParagraph>(
                inSettings(find.text(lang.lockHint)),
              )
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: lang.lockHint.length,
                ),
              )
              .map((b) => b.top.round())
              .toSet();
          expect(hintLines.length, greaterThan(1), reason: 'más de una línea');

          // El interruptor entero cabe en la fila: pomo y pista, sin tocar el
          // texto.
          final knob = tester.getRect(find.byKey(UnaSwitchRow.knobKey).at(1));
          final track = tester.getRect(find.byKey(UnaSwitchRow.trackKey).at(1));
          expect(row.contains(knob.center), isTrue);
          expect(track.right, lessThanOrEqualTo(_size.width));
          expect(name.right, lessThanOrEqualTo(track.left + 0.5));
          expect(hint.right, lessThanOrEqualTo(track.left + 0.5));

          // De arriba abajo, cada fila y su aviso no se pisan.
          final stack = [
            for (final f in [
              inSettings(find.text(lang.keepAwake)),
              inSettings(find.text(lang.saveError)).first,
              inSettings(find.text(lang.lockZoom)),
              inSettings(find.text(lang.saveError)).last,
              inSettings(find.text(lang.help)),
              inSettings(find.text(lang.noApp)),
            ])
              tester.getRect(f),
          ];
          for (var i = 1; i < stack.length; i++) {
            expect(
              stack[i].top,
              greaterThanOrEqualTo(stack[i - 1].bottom - 1),
              reason: 'el elemento $i está sobre el anterior',
            );
          }
          for (final notice in [lang.saveError, lang.noApp]) {
            _expectWhole(tester, inSettings(find.text(notice)), notice);
          }
          // Los dos de guardado se ven enteros tras llevarlos a la vista.
          final viewport = tester.getRect(
            inSettings(find.byType(SingleChildScrollView)).first,
          );
          await tester.ensureVisible(
            inSettings(find.text(lang.saveError)).last,
          );
          await tester.pumpAndSettle();
          expect(
            viewport.contains(
              tester.getCenter(inSettings(find.text(lang.saveError)).last),
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets(
        'CA-017-15 / CA-015-01d ($name): el pomo de "Bloquear zoom" ${reduced ? 'cambia de sitio en el mismo fotograma, sin animar' : 'se anima hasta su sitio'}',
        (tester) async {
          final repo = SettingsRepo();
          await openSettingsScreen(
            tester,
            locale: lang.locale,
            textScale: 2,
            size: _size,
            reduced: reduced,
            repo: repo,
          );
          final row = inSettings(find.text(lang.lockZoom));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          double knobX() =>
              tester.getTopLeft(find.byKey(UnaSwitchRow.knobKey).at(1)).dx;
          final off = knobX();
          await tester.tap(row);
          // Lo justo para que se guarde y llegue el valor nuevo.
          await tester.pump();
          await tester.pump();
          final first = knobX();
          await tester.pumpAndSettle();
          final on = knobX();
          expect(on, isNot(off), reason: 'el pomo cambia de lado');
          expect(await repo.lockZoom(), isTrue);
          if (reduced) {
            expect(first, on, reason: 'sin animación: ya está en su sitio');
            expect(tester.hasRunningAnimations, isFalse);
          } else {
            expect(first, isNot(on), reason: 'se anima: aún va de camino');
          }
        },
      );

      testWidgets(
        'CA-015-22 ($name): la página de Idioma al 200 % a 360 dp, con "Como el sistema", su línea de debajo y el aviso de error: sin desbordes',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(
            tester,
            locale: lang.locale,
            textScale: 2,
            size: _size,
            reduced: reduced,
            repo: _LocaleFailingRepo(),
          );
          await tester.tap(inSettings(find.text(lang.language)));
          await settleSettings(tester);
          expect(find.byType(LanguagePage), findsOneWidget);
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is UnaRadioRow && w.label == lang.other,
            ),
          );
          await settleSettings(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanguagePage), findsOneWidget);

          final page = find.byType(LanguagePage);
          Finder inPage(Finder f) => find.descendant(of: page, matching: f);
          // "Como el sistema" y, debajo, el idioma que resulta.
          final label = tester.getRect(
            inPage(find.text(lang.languageValue)).first,
          );
          final line = tester.getRect(inPage(find.text(lang.resulting)).first);
          expect(
            line.top,
            greaterThanOrEqualTo(label.bottom - 1),
            reason: 'la línea de debajo va en otra línea',
          );
          for (final text in [
            lang.language,
            lang.languageValue,
            lang.resulting,
            'Español',
            'English',
            lang.saveError,
          ]) {
            _expectWhole(tester, inPage(find.text(text)), text);
          }
          // Cada opción mide ≥ 44 y ninguna se solapa con la siguiente.
          final rows = tester
              .widgetList<UnaRadioRow>(find.byType(UnaRadioRow))
              .length;
          expect(rows, 3);
          Rect? previous;
          for (final r in find.byType(UnaRadioRow).evaluate()) {
            final rect = tester.getRect(find.byWidget(r.widget));
            expect(rect.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
            if (previous != null) {
              expect(rect.top, greaterThanOrEqualTo(previous.bottom - 1));
            }
            previous = rect;
          }
          // El aviso queda dentro de la pantalla.
          final notice = tester.getRect(inPage(find.text(lang.saveError)));
          expect(notice.bottom, lessThanOrEqualTo(_size.height));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );

      testWidgets(
        'CA-015-22 / CA-015-01d ($name): abrir Ajustes y la página de Idioma ${reduced ? 'es instantáneo' : 'dura lo previsto (200 ms la subida, 160 ms el fundido)'}',
        (tester) async {
          await _expectRouteMotion(tester, lang, reduced);
        },
      );
    }
  }
}

/// Mide cuánto tarda en asentarse cada ruta: con reducir movimiento, ningún
/// fotograma de transición; sin él, la subida de Ajustes y el fundido del nivel
/// 2 siguen sus duraciones (`UnaMotion`).
Future<void> _expectRouteMotion(
  WidgetTester tester,
  _Lang lang,
  bool reduced,
) async {
  await openSettingsScreen(
    tester,
    locale: lang.locale,
    textScale: 2,
    size: _size,
    reduced: reduced,
  );
  // Ajustes ya está arriba. El nivel 2: un fundido de 160 ms (0 con reducir
  // movimiento).
  await tester.tap(inSettings(find.text(lang.language)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  final fading = find.byType(LanguagePage).evaluate().isNotEmpty;
  expect(fading, isTrue);
  final route = ModalRoute.of(tester.element(find.byType(LanguagePage)))!;
  if (reduced) {
    expect(
      route.animation!.status,
      AnimationStatus.completed,
      reason: 'con reducir movimiento el nivel 2 aparece de golpe',
    );
  } else {
    expect(
      route.animation!.status,
      AnimationStatus.forward,
      reason: 'sin reducir movimiento, el nivel 2 se funde',
    );
    await tester.pump(UnaMotion.sheetOut);
    expect(route.animation!.status, AnimationStatus.completed);
  }
  await tester.pumpAndSettle();
}
