import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_leaks.dart';

/// Tests del propio helper de fugas de idioma (spec 010, CA-010-07): que
/// detecte un texto del otro idioma y que no salte con los textos iguales en
/// los dos idiomas ni con los del idioma propio.
void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));
  final leaks = L10nLeaks.load();

  group('CA-010-07: fragmentos literales de un mensaje ARB', () {
    test('CA-010-07: separa por placeholders', () {
      expect(arbLiteralFragments('Current task: {text}'), ['Current task:']);
      expect(arbLiteralFragments('{position} of {total}: {text}'), ['of', ':']);
    });

    test('CA-010-07: separa por la sintaxis ICU (plural)', () {
      expect(
        arbLiteralFragments(
          '{count, plural, =1{1 character left} '
          'other{{count} characters left}}',
        ),
        ['1 character left', 'characters left'],
      );
    });
  });

  group('CA-010-07: fragmentos del otro idioma', () {
    test('CA-010-07: incluye los textos propios del otro idioma', () {
      expect(leaks.foreignFragments('es'), contains('Task menu'));
      expect(leaks.foreignFragments('en'), contains('Menú de la tarea'));
    });

    test('CA-010-07: descarta los cortos y los que existen en el idioma '
        'propio ("PDF", "MB", textos iguales)', () {
      for (final lang in ['es', 'en']) {
        final fragments = leaks.foreignFragments(lang);
        expect(fragments, isNot(contains('PDF')));
        expect(fragments, isNot(contains('MB')));
        expect(fragments, isNot(contains('WEB')));
        expect(fragments, isNot(contains('https://')));
        expect(fragments.where((f) => f.length < 4), isEmpty);
      }
    });

    test('CA-010-07: ningún mensaje del idioma propio cuenta como fuga', () {
      for (final lang in ['es', 'en']) {
        final own = leaks.messages(lang).values.expand(arbLiteralFragments);
        expect(leaks.leaksIn(own, languageCode: lang), isEmpty, reason: lang);
      }
    });

    test('CA-010-07: un fragmento solo cuenta como palabra completa', () {
      // "Cancel" (EN) dentro de "Cancelar" (ES) no es una fuga.
      expect(leaks.leaksIn(['Cancelar'], languageCode: 'es'), isEmpty);
      expect(leaks.leaksIn(['Pulsa Cancel'], languageCode: 'es'), isNotEmpty);
    });
  });

  group('CA-010-07: recorrido del árbol semántico y de los anuncios', () {
    testWidgets('CA-010-07: detecta una etiqueta en EN dentro de la app en '
        'ES', (tester) async {
      await tester.pumpWidget(
        _app(
          const Locale('es'),
          Semantics(
            label: en.menuButton,
            button: true,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      final found = findL10nLeaks(tester, languageCode: 'es');
      expect(found, hasLength(1));
      expect(found.single, contains('Task menu'));
    });

    testWidgets('CA-010-07: detecta fugas en pista, valor, tooltip y nombre '
        'de acción personalizada', (tester) async {
      await tester.pumpWidget(
        _app(
          const Locale('en'),
          Column(
            children: [
              Semantics(
                hint: es.completeA11yHint,
                child: const SizedBox(width: 10, height: 10),
              ),
              Semantics(
                value: es.storageErrorTitle,
                child: const SizedBox(width: 10, height: 10),
              ),
              Semantics(
                tooltip: es.retry,
                child: const SizedBox(width: 10, height: 10),
              ),
              Semantics(
                customSemanticsActions: {
                  CustomSemanticsAction(label: es.completeA11yAction): () {},
                },
                child: const SizedBox(width: 10, height: 10),
              ),
            ],
          ),
        ),
      );
      final found = findL10nLeaks(tester, languageCode: 'en');
      expect(found, hasLength(4));
      expect(found.join('\n'), contains(es.completeA11yAction));
    });

    testWidgets('CA-010-07: detecta un anuncio en el otro idioma', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Locale('es'), const SizedBox()));
      final view = tester.view;
      await SemanticsService.sendAnnouncement(
        view,
        en.a11yCompletedAllDone,
        TextDirection.ltr,
      );
      final found = findL10nLeaks(tester, languageCode: 'es');
      expect(found, hasLength(1));
      expect(found.single, contains('Task completed'));
    });

    testWidgets('CA-010-07: no salta con textos del idioma propio ni con los '
        'iguales en los dos idiomas', (tester) async {
      for (final (locale, l10n) in [
        (const Locale('es'), es),
        (const Locale('en'), en),
      ]) {
        await tester.pumpWidget(
          _app(
            locale,
            Column(
              children: [
                Semantics(
                  label: l10n.a11yPdfOnly('Factura', '2 MB'),
                  hint: l10n.completeA11yHint,
                  child: const SizedBox(width: 10, height: 10),
                ),
                Semantics(
                  label: l10n.attachmentPdf,
                  value: l10n.urlPlaceholder,
                  customSemanticsActions: {
                    CustomSemanticsAction(label: l10n.completeA11yAction):
                        () {},
                  },
                  child: const SizedBox(width: 10, height: 10),
                ),
                Text(l10n.menuAllTasksCount(3)),
                Text(l10n.placementQuoted('Llamar')),
              ],
            ),
          ),
        );
        await SemanticsService.sendAnnouncement(
          tester.view,
          l10n.a11yDeletedFromList(2),
          TextDirection.ltr,
        );
        expectNoL10nLeaks(tester, languageCode: locale.languageCode);
      }
    });

    testWidgets('CA-010-07: la lista blanca explícita deja pasar un '
        'fragmento', (tester) async {
      await tester.pumpWidget(
        _app(const Locale('es'), Semantics(label: en.menuButton)),
      );
      expect(
        findL10nLeaks(tester, languageCode: 'es', allowed: {'Task menu'}),
        isEmpty,
      );
    });
  });
}

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
