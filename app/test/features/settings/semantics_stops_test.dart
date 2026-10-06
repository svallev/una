import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';
import '../../support/semantics_stops.dart';

class _Opener implements LinkOpener {
  _Opener({this.available = true});

  final bool available;

  @override
  Future<bool> canOpen(LinkTarget target) async => available;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

/// Un repositorio cuyo guardado de "Pantalla siempre activa" falla.
class _FailingRepo extends InMemoryTaskRepository {
  @override
  Future<void> setKeepScreenOn(bool value) async => throw StateError('boom');
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

/// Abre el menú y "Ajustes" (nivel 1), con el lector de pantalla activo.
Future<void> _openSettings(
  WidgetTester tester, {
  required Locale locale,
  LinkOpener? opener,
  InMemoryTaskRepository? repo,
}) async {
  await pumpUnaApp(
    tester,
    repo: repo ?? InMemoryTaskRepository(),
    tasks: ['Primera', 'Segunda'],
    locale: locale,
    screenReader: true,
    overrides: [linkOpenerProvider.overrideWithValue(opener ?? _Opener())],
  );
  final en = locale.languageCode == 'en';
  await tester.tap(
    find.bySemanticsLabel(en ? 'Task menu' : 'Menú de la tarea'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(en ? 'Settings' : 'Ajustes'));
  await _settle(tester);
  expect(find.byType(SettingsScreen), findsOneWidget);
}

void main() {
  setUpAll(loadAppFonts);

  const locales = [Locale('es'), Locale('en')];

  group('Auxiliar semantics_stops (CA-013-04)', () {
    testWidgets(
      'CA-013-04: el auxiliar detecta un nodo enfocable sin etiqueta, uno con tap sin etiqueta y uno con focus sin etiqueta',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Semantics(
                  focusable: true,
                  container: true,
                  child: const SizedBox(width: 50, height: 50),
                ),
                Semantics(
                  container: true,
                  onTap: () {},
                  child: const SizedBox(width: 50, height: 50),
                ),
                Semantics(
                  container: true,
                  onFocus: () {},
                  child: const SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        );
        expect(unnamedSemanticsStops(tester), hasLength(3));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04: el auxiliar deja pasar un contenedor de solo desplazar y no un nodo que además se toca o se enfoca',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Semantics(
                  container: true,
                  onScrollUp: () {},
                  onScrollDown: () {},
                  child: const SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        );
        expect(unnamedSemanticsStops(tester), isEmpty);
        expect(hasScrollOnlyContainer(tester), isTrue);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Semantics(
                  container: true,
                  onScrollUp: () {},
                  onTap: () {},
                  child: const SizedBox(width: 50, height: 50),
                ),
                Semantics(
                  container: true,
                  onScrollUp: () {},
                  focusable: true,
                  child: const SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        );
        expect(unnamedSemanticsStops(tester), hasLength(2));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04: un nodo con etiqueta o con valor no cuenta, aunque se enfoque',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Semantics(
                  label: 'a',
                  button: true,
                  onTap: () {},
                  onFocus: () {},
                  child: const SizedBox(width: 50, height: 50),
                ),
                Semantics(
                  value: 'v',
                  focusable: true,
                  child: const SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        );
        expect(unnamedSemanticsStops(tester), isEmpty);
        handle.dispose();
      },
    );
  });

  for (final locale in locales) {
    final en = locale.languageCode == 'en';
    final lang = en ? 'EN' : 'ES';

    group('Ninguna parada sin nombre, $lang (CA-013-04, CA-015-20)', () {
      testWidgets('CA-013-04: nivel 1 sin avisos', (tester) async {
        final handle = tester.ensureSemantics();
        await _openSettings(tester, locale: locale);
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('CA-013-04: nivel 1 con los dos avisos a la vez', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _openSettings(
          tester,
          locale: locale,
          opener: _Opener(available: false),
          repo: _FailingRepo(),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text(
              en ? 'Keep screen on' : 'Pantalla siempre activa',
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text(en ? 'Help' : 'Ayuda'),
          ),
        );
        await _settle(tester);
        expect(
          find.text(
            en ? "Couldn't save the setting." : 'No se pudo guardar el ajuste.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            en
                ? "There's no app to open this link."
                : 'No hay ninguna app para abrir este enlace.',
          ),
          findsOneWidget,
        );
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('CA-013-04: nivel 2 (página de Idioma)', (tester) async {
        final handle = tester.ensureSemantics();
        await _openSettings(tester, locale: locale);
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text(en ? 'Language' : 'Idioma'),
          ),
        );
        await _settle(tester);
        expect(find.byType(LanguagePage), findsOneWidget);
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  }
}
