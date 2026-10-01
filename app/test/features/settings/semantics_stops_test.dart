import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/settings/license_detail_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';
import '../../support/semantics_stops.dart';

/// Fuente de licencias controlada por el test.
class _Source implements LicenseSource {
  _Source(this.result, {this.error});

  /// Una fuente que no termina hasta [complete].
  _Source.slow() : result = null, error = null;

  final List<LicensePackage>? result;
  final Object? error;
  final _pending = <Completer<List<LicensePackage>>>[];

  @override
  Future<List<LicensePackage>> load() {
    if (error != null) return Future.error(error!);
    final r = result;
    if (r != null) return Future.value(r);
    final c = Completer<List<LicensePackage>>();
    _pending.add(c);
    return c.future;
  }
}

class _Opener implements LinkOpener {
  _Opener({this.available = true});

  final bool available;

  @override
  Future<bool> canOpen(LinkTarget target) async => available;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

LicensePackage _pkg(String name, [List<List<String>>? texts]) => LicensePackage(
  name: name,
  texts: [
    for (final paragraphs
        in texts ??
            [
              <String>['MIT License. Text of $name.'],
            ])
      LicenseText([for (final p in paragraphs) (text: p, indent: 0)]),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

/// Abre el menú y "Configuración y perfil" (nivel 1).
Future<void> _openSettings(
  WidgetTester tester, {
  required Locale locale,
  LinkOpener? opener,
  LicenseSource? source,
}) async {
  await pumpUnaApp(
    tester,
    repo: InMemoryTaskRepository(),
    tasks: ['Primera', 'Segunda'],
    locale: locale,
    screenReader: true,
    overrides: [
      linkOpenerProvider.overrideWithValue(opener ?? _Opener()),
      if (source != null) licenseSourceProvider.overrideWithValue(source),
    ],
  );
  final en = locale.languageCode == 'en';
  await tester.tap(
    find.bySemanticsLabel(en ? 'Task menu' : 'Menú de la tarea'),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(en ? 'Settings and profile' : 'Configuración y perfil'),
  );
  await _settle(tester);
  expect(find.byType(SettingsScreen), findsOneWidget);
}

/// Abre el nivel 2 desde el nivel 1; con [settle] false, la fuente puede seguir
/// pendiente.
Future<void> _openLicenses(
  WidgetTester tester, {
  required Locale locale,
  required LicenseSource source,
  bool settle = true,
}) async {
  await _openSettings(tester, locale: locale, source: source);
  final en = locale.languageCode == 'en';
  await tester.tap(
    find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.text(
        en ? 'Open-source licenses' : 'Licencias de código abierto',
      ),
    ),
  );
  if (settle) {
    await _settle(tester);
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byType(LicensesScreen), findsOneWidget);
}

Future<void> _openDetail(WidgetTester tester, String name) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(LicensesScreen),
          matching: find.textContaining(name),
        )
        .first,
  );
  await _settle(tester);
  expect(find.byType(LicenseDetailScreen), findsOneWidget);
}

/// Un texto largo: bastantes párrafos como para que haya que desplazar.
List<String> _longText() => [
  for (var i = 0; i < 80; i++) 'Párrafo $i. ${'Texto de la licencia. ' * 20}',
];

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

    group('Ninguna parada sin nombre, $lang (CA-013-04)', () {
      testWidgets('CA-013-04: nivel 1 sin aviso', (tester) async {
        final handle = tester.ensureSemantics();
        await _openSettings(tester, locale: locale);
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('CA-013-04: nivel 1 con el aviso "No hay ninguna app…"', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _openSettings(
          tester,
          locale: locale,
          opener: _Opener(available: false),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text(
              en ? 'Privacy policy' : 'Política de privacidad',
            ),
          ),
        );
        await _settle(tester);
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

      testWidgets('CA-013-04: nivel 2 cargando', (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          locale: locale,
          source: _Source.slow(),
          settle: false,
        );
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        // La fuente lenta no termina nunca: se sale antes de que acabe el test.
        await tester.binding.handlePopRoute();
        await _settle(tester);
      });

      testWidgets(
        'CA-013-04: nivel 2 con error: "Reintentar" es un solo nodo con nombre',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            locale: locale,
            source: _Source(null, error: StateError('boom')),
          );
          expectNoUnnamedSemanticsStops(tester);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets(
        'CA-013-04: nivel 2 con la lista, que conserva su desplazamiento',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            locale: locale,
            source: _Source([for (var i = 0; i < 60; i++) _pkg('paquete$i')]),
          );
          expectNoUnnamedSemanticsStops(tester);
          expect(hasScrollOnlyContainer(tester), isTrue);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets('CA-013-04: nivel 3 corto', (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          locale: locale,
          source: _Source([_pkg('pdfrx')]),
        );
        await _openDetail(tester, 'pdfrx');
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets(
        'CA-013-04: nivel 3 largo, con el contenedor de desplazamiento y sin la parada sin nombre del área de texto',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            locale: locale,
            source: _Source([
              _pkg('pdfrx', [_longText()]),
            ]),
          );
          await _openDetail(tester, 'pdfrx');
          expectNoUnnamedSemanticsStops(tester);
          expect(hasScrollOnlyContainer(tester), isTrue);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      testWidgets('CA-013-04: nivel 3 con varias licencias', (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          locale: locale,
          source: _Source([
            _pkg('pdfrx', [
              ['Primera.'],
              ['Segunda.'],
              ['Tercera.'],
            ]),
          ]),
        );
        await _openDetail(tester, 'pdfrx');
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('CA-013-04: nivel 3 sin texto legible', (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          locale: locale,
          source: _Source([
            _pkg('vacio', [
              ['  ', ''],
            ]),
          ]),
        );
        await _openDetail(tester, 'vacio');
        expectNoUnnamedSemanticsStops(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  }

  group('El área de texto del nivel 3 con teclado (CA-013-04, CA-012-12)', () {
    testWidgets(
      'CA-013-04: con teclado, el área de texto se sigue enfocando con su anillo y las flechas la desplazan',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          locale: const Locale('es'),
          source: _Source([
            _pkg('pdfrx', [_longText()]),
          ]),
        );
        await _openDetail(tester, 'pdfrx');
        // Tab desde "Volver" (el primero) → título → área de texto.
        FocusNode? area;
        for (var i = 0; i < 6 && area?.debugLabel != 'license text'; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          area = FocusManager.instance.primaryFocus;
        }
        expect(area?.debugLabel, 'license text');
        final ring = find.ancestor(
          of: find.descendant(
            of: find.byType(LicenseDetailScreen),
            matching: find.byType(ListView),
          ),
          matching: find.byType(FocusRing),
        );
        expect(tester.widget<FocusRing>(ring.first).visible, isTrue);
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(LicenseDetailScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.pixels, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(scrollable.position.pixels, greaterThan(0));
        handle.dispose();
      },
    );
  });
}
