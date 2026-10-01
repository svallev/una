import 'dart:async';

import 'package:app/app/locale_resolution.dart';
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
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';

/// Un paquete con los textos dados (cada texto, una lista de párrafos).
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

/// Fuente de licencias controlada por el test.
class _Source implements LicenseSource {
  _Source(this.result);

  /// Si es null, [load] espera a [complete] o [fail].
  factory _Source.slow() => _Source(null);

  List<LicensePackage>? result;
  Object? error;
  final _pending = <Completer<List<LicensePackage>>>[];
  int loads = 0;

  @override
  Future<List<LicensePackage>> load() {
    loads++;
    if (error != null) return Future.error(error!);
    final r = result;
    if (r != null) return Future.value(r);
    final c = Completer<List<LicensePackage>>();
    _pending.add(c);
    return c.future;
  }

  void complete(List<LicensePackage> packages) {
    for (final c in _pending) {
      c.complete(packages);
    }
    _pending.clear();
  }
}

class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

/// Etiquetas de todos los nodos, en el orden en que los recorre el lector.
List<String> _readingOrder(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) out.add(node.label);
    for (final c in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(c);
    }
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// Qué tiene el foco de teclado: el botón cuadrado, o el primer texto del nodo
/// enfocado; para la lista del nivel 3, su nombre de depuración.
String? _focused(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus;
  final ctx = node?.context;
  if (ctx == null) return null;
  if (node!.debugLabel == 'license text') return 'license text';
  final icon = ctx.findAncestorWidgetOfExactType<SquareIconButton>();
  if (icon != null) return icon.label;
  final button = ctx.findAncestorWidgetOfExactType<BrutalButton>();
  if (button != null) return button.label;
  final texts = find.descendant(
    of: find.byElementPredicate((e) => identical(e, ctx)),
    matching: find.byType(Text),
  );
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}

/// Si algún nodo accesible ofrece la acción de desplazar hacia delante (la que
/// usan el lector y Switch Access).
bool _canScrollForward(WidgetTester tester) {
  var found = false;
  void visit(SemanticsNode node) {
    if (node.getSemanticsData().hasAction(SemanticsAction.scrollUp)) {
      found = true;
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return found;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

/// Abre el menú, "Configuración y perfil" y "Licencias de código abierto".
/// Con [settle] false, solo deja pasar la transición (la fuente puede estar
/// pendiente).
Future<void> _openLicenses(
  WidgetTester tester,
  LicenseSource source, {
  Locale locale = const Locale('es'),
  bool screenReader = false,
  bool reduced = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  double bottomInset = 0,
  bool settle = true,
}) async {
  await pumpUnaApp(
    tester,
    repo: InMemoryTaskRepository(),
    tasks: ['Primera', 'Segunda'],
    locale: locale,
    screenReader: screenReader,
    reduced: reduced,
    textScale: textScale,
    size: size,
    bottomInset: bottomInset,
    overrides: [
      linkOpenerProvider.overrideWithValue(_Opener()),
      licenseSourceProvider.overrideWithValue(source),
    ],
  );
  // Con `ca` la app está en español y con `gl` o `eu`, en inglés (CA-010-01).
  final en = resolveAppLocale([locale]).languageCode == 'en';
  await tester.tap(
    find.bySemanticsLabel(en ? 'Task menu' : 'Menú de la tarea'),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(en ? 'Settings and profile' : 'Configuración y perfil'),
  );
  await _settle(tester);
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
    // La ruta se construye y la fuente sigue pendiente.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byType(LicensesScreen), findsOneWidget);
}

Finder _inLicenses(Finder f) =>
    find.descendant(of: find.byType(LicensesScreen), matching: f);

Finder _inDetail(Finder f) =>
    find.descendant(of: find.byType(LicenseDetailScreen), matching: f);

const _title = 'Licencias de código abierto';
const _loading = 'Cargando licencias…';
const _error = 'No se pudieron cargar las licencias.';

/// Abre el nivel 3 de [name] desde el nivel 2.
Future<void> _openDetail(WidgetTester tester, String name) async {
  await tester.tap(_inLicenses(find.textContaining(name)).first);
  await _settle(tester);
  expect(find.byType(LicenseDetailScreen), findsOneWidget);
}

void main() {
  setUpAll(loadAppFonts);

  group('Nivel 2: carga, error y vacío (CA-012-15)', () {
    testWidgets(
      'CA-012-15: con una fuente lenta el nivel aparece ya con "Cargando licencias…"; el anuncio, solo pasado el umbral y una vez; luego la lista',
      (tester) async {
        final handle = tester.ensureSemantics();
        final source = _Source.slow();
        await _openLicenses(tester, source, screenReader: true, settle: false);
        tester.takeAnnouncements();
        expect(_inLicenses(find.text(_loading)), findsOneWidget);
        expect(_inLicenses(find.text(_title)), findsOneWidget);
        // Antes del umbral, ningún anuncio.
        await tester.pump(licensesLoadingAnnounceDelay ~/ 2);
        expect(tester.takeAnnouncements(), isEmpty);
        // Pasado el umbral, uno, y no se repite.
        await tester.pump(licensesLoadingAnnounceDelay);
        expect(tester.takeAnnouncements().map((a) => a.message), [_loading]);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeAnnouncements(), isEmpty);
        // Llega la lista en cuanto se lee.
        source.complete([_pkg('pdfrx')]);
        await _settle(tester);
        expect(_inLicenses(find.text(_loading)), findsNothing);
        expect(_inLicenses(find.text('pdfrx')), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-15: si la lista ya está antes del umbral no se anuncia nada',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          _Source([_pkg('pdfrx')]),
          screenReader: true,
        );
        await tester.pump(licensesLoadingAnnounceDelay * 3);
        expect(
          tester.takeAnnouncements().map((a) => a.message),
          isNot(contains(_loading)),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-15: si se sale antes del umbral no se anuncia una carga que ya no se ve',
      (tester) async {
        final handle = tester.ensureSemantics();
        final source = _Source.slow();
        await _openLicenses(tester, source, screenReader: true, settle: false);
        tester.takeAnnouncements();
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.pump(licensesLoadingAnnounceDelay * 3);
        expect(tester.takeAnnouncements(), isEmpty);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-15: si falla la lectura sale el error con "Reintentar", que recibe el foco con el error como pista; al pulsarlo el foco va al título',
      (tester) async {
        final handle = tester.ensureSemantics();
        final source = _Source(null)..error = StateError('boom');
        await _openLicenses(tester, source, screenReader: true);
        expect(_inLicenses(find.text(_error)), findsOneWidget);
        final retry = find.byType(BrutalButton);
        expect(retry, findsOneWidget);
        expect(_focused(tester), 'Reintentar');
        final node = tester.getSemantics(find.bySemanticsLabel('Reintentar'));
        expect(node.label, 'Reintentar');
        expect(node.hint, _error);
        expect(node.flagsCollection.isButton, isTrue);
        // Tras pulsarlo, carga y el foco vuelve al título.
        source
          ..error = null
          ..result = [_pkg('pdfrx')];
        await tester.tap(retry);
        await _settle(tester);
        expect(source.loads, 2);
        expect(_inLicenses(find.text(_error)), findsNothing);
        expect(_inLicenses(find.text('pdfrx')), findsOneWidget);
        expect(_focused(tester), _title);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-15: si vuelve a fallar, el foco vuelve a "Reintentar"',
      (tester) async {
        final source = _Source(null)..error = StateError('boom');
        await _openLicenses(tester, source);
        await tester.tap(find.byType(BrutalButton));
        await _settle(tester);
        expect(source.loads, 2);
        expect(_inLicenses(find.text(_error)), findsOneWidget);
        expect(_focused(tester), 'Reintentar');
      },
    );

    testWidgets(
      'CA-012-15 / spec §5: una fuente vacía se trata como el error',
      (tester) async {
        await _openLicenses(tester, _Source(<LicensePackage>[]));
        expect(_inLicenses(find.text(_error)), findsOneWidget);
        expect(find.byType(BrutalButton), findsOneWidget);
      },
    );

    testWidgets(
      'CL-012-6: con el error, Volver y el resto de la pantalla siguen funcionando',
      (tester) async {
        await _openLicenses(tester, _Source(null)..error = StateError('boom'));
        await tester.tap(find.bySemanticsLabel('Volver'));
        await _settle(tester);
        expect(find.byType(LicensesScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('CA-012-11: el error se lee tras el título y antes de Volver', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _openLicenses(
        tester,
        _Source(null)..error = StateError('boom'),
        screenReader: true,
      );
      final order = _readingOrder(tester);
      expect(order.sublist(order.length - 4), [
        _title,
        _error,
        'Reintentar',
        'Volver',
      ]);
      handle.dispose();
    });

    testWidgets(
      'CA-012-16: no se lee ninguna licencia hasta abrir el nivel 2',
      (tester) async {
        final source = _Source([_pkg('pdfrx')]);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
          overrides: [
            linkOpenerProvider.overrideWithValue(_Opener()),
            licenseSourceProvider.overrideWithValue(source),
          ],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Configuración y perfil'));
        await _settle(tester);
        expect(source.loads, 0);
        await tester.tap(find.text(_title));
        await _settle(tester);
        expect(source.loads, 1);
      },
    );
  });

  group('Nivel 2: la lista (CA-012-03, CA-012-11)', () {
    final packages = [
      _pkg('Archivo'),
      _pkg('pdfrx', [
        ['A'],
        ['B'],
      ]),
      _pkg('Space Mono'),
    ];

    testWidgets(
      'CA-012-11: cada fila es un botón "nombre, N licencias" (singular y plural), tras el título y antes de Volver',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(tester, _Source(packages), screenReader: true);
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 5), [
          _title,
          'Archivo, 1 licencia',
          'pdfrx, 2 licencias',
          'Space Mono, 1 licencia',
          'Volver',
        ]);
        final node = tester.getSemantics(_inLicenses(find.text('pdfrx')));
        expect(node.flagsCollection.isButton, isTrue);
        final title = tester.getSemantics(_inLicenses(find.text(_title)).first);
        expect(title.flagsCollection.isHeader, isTrue);
        handle.dispose();
      },
    );

    testWidgets('CA-012-11: en inglés, todo en inglés', (tester) async {
      final handle = tester.ensureSemantics();
      await _openLicenses(
        tester,
        _Source(packages),
        locale: const Locale('en'),
        screenReader: true,
      );
      final order = _readingOrder(tester);
      expect(order.sublist(order.length - 5), [
        'Open-source licenses',
        'Archivo, 1 license',
        'pdfrx, 2 licenses',
        'Space Mono, 1 license',
        'Back',
      ]);
      handle.dispose();
    });

    testWidgets(
      'CA-012-03: cada fila enseña el nombre y, debajo, cuántas licencias',
      (tester) async {
        await _openLicenses(tester, _Source(packages));
        final name = tester.getBottomLeft(_inLicenses(find.text('pdfrx')));
        final count = tester.getTopLeft(_inLicenses(find.text('2 licencias')));
        expect(count.dy, greaterThanOrEqualTo(name.dy));
        expect(_inLicenses(find.text('1 licencia')), findsNWidgets(2));
      },
    );

    testWidgets(
      'CA-012-02: tocar una fila abre el nivel 3, y al volver (Volver, atrás y Escape) el foco está en esa fila',
      (tester) async {
        await _openLicenses(tester, _Source(packages));
        for (final back in <Future<void> Function()>[
          () => tester.tap(find.bySemanticsLabel('Volver')),
          () => tester.binding.handlePopRoute(),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          await _openDetail(tester, 'pdfrx');
          await back();
          await _settle(tester);
          expect(find.byType(LicenseDetailScreen), findsNothing);
          expect(find.byType(LicensesScreen), findsOneWidget);
          expect(_focused(tester), 'pdfrx');
        }
      },
    );

    testWidgets('CL-012-2: un doble toque en una fila abre un solo nivel 3', (
      tester,
    ) async {
      await _openLicenses(tester, _Source(packages));
      final row = _inLicenses(find.text('Archivo'));
      await tester.tap(row);
      await tester.tap(row, warnIfMissed: false);
      await _settle(tester);
      expect(find.byType(LicenseDetailScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(LicenseDetailScreen), findsNothing);
      expect(find.byType(LicensesScreen), findsOneWidget);
    });

    testWidgets(
      'CA-012-12: el orden del teclado es Volver → título → filas, con anillo e Intro',
      (tester) async {
        await _openLicenses(tester, _Source(packages));
        expect(_focused(tester), _title);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(_focused(tester), 'Volver');
        final order = <String?>[];
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          order.add(_focused(tester));
        }
        expect(order, [_title, 'Archivo', 'pdfrx']);
        // El anillo se ve en la fila enfocada con el teclado.
        final ring = find.ancestor(
          of: _inLicenses(find.text('pdfrx')),
          matching: find.byType(FocusRing),
        );
        expect(tester.widget<FocusRing>(ring.first).visible, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(find.byType(LicenseDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CL-012-5: con cientos de elementos la lista es perezosa y se llega al último desplazando',
      (tester) async {
        final many = [
          for (var i = 0; i < 400; i++)
            _pkg('pkg${i.toString().padLeft(3, '0')}'),
        ];
        await _openLicenses(tester, _Source(many));
        expect(_inLicenses(find.text('pkg000')), findsOneWidget);
        expect(
          _inLicenses(find.textContaining('licencia')).evaluate().length,
          lessThan(40),
          reason: 'solo se construyen las filas visibles',
        );
        await tester.drag(find.byType(ListView), const Offset(0, -300000));
        await tester.pumpAndSettle();
        expect(_inLicenses(find.text('pkg399')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CA-012-11: la lista se puede desplazar con el lector (acción de desplazar)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final many = [for (var i = 0; i < 100; i++) _pkg('pkg$i')];
        await _openLicenses(tester, _Source(many), screenReader: true);
        expect(_canScrollForward(tester), isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-02: bajar y subir por una lista larga con el lector activo, a 200 %, no falla (las filas se destruyen y vuelven)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final many = [
          for (var i = 0; i < 100; i++)
            _pkg('pkg${i.toString().padLeft(3, '0')}'),
        ];
        await _openLicenses(
          tester,
          _Source(many),
          screenReader: true,
          textScale: 2,
          size: const Size(360, 640),
        );
        for (final dy in [-3000.0, 3000.0, -3000.0, 3000.0]) {
          await tester.drag(find.byType(ListView), Offset(0, dy));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(_inLicenses(find.text('pkg000')), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-02: al volver del nivel 3 la lista sigue donde estaba',
      (tester) async {
        final many = [
          for (var i = 0; i < 100; i++)
            _pkg('pkg${i.toString().padLeft(3, '0')}'),
        ];
        await _openLicenses(tester, _Source(many));
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        final visible = _inLicenses(find.textContaining('pkg'))
            .hitTestable()
            .first;
        final name = tester.widget<Text>(visible).data!;
        await tester.tap(visible);
        await _settle(tester);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_inLicenses(find.text(name)), findsOneWidget);
        expect(_inLicenses(find.text('pkg000')), findsNothing);
        expect(_focused(tester), name);
      },
    );
  });

  group('Nivel 3: el texto de una licencia (CA-012-03, CA-012-11)', () {
    testWidgets(
      'CA-012-02 / CA-012-11: el título es el nombre del elemento, encabezado y con el foco al llegar; con una sola licencia no hay más encabezado',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [
              ['Primer párrafo.', 'Segundo párrafo.'],
            ]),
          ]),
          screenReader: true,
        );
        await _openDetail(tester, 'pdfrx');
        expect(_focused(tester), 'pdfrx');
        final title = tester.getSemantics(_inDetail(find.text('pdfrx')).first);
        expect(title.flagsCollection.isHeader, isTrue);
        final headers = <String>[];
        void visit(SemanticsNode n) {
          if (n.flagsCollection.isHeader) headers.add(n.label);
          n.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        visit(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        expect(headers, ['pdfrx']);
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 4), [
          'pdfrx',
          'Primer párrafo.',
          'Segundo párrafo.',
          'Volver',
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-03 / CA-012-11: con varias licencias, un encabezado "Licencia n de total" por texto, todas seguidas',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [
              ['Uno A.', 'Uno B.'],
              ['Dos A.'],
              ['Tres A.'],
            ]),
          ]),
          screenReader: true,
        );
        await _openDetail(tester, 'pdfrx');
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 9), [
          'pdfrx',
          'Licencia 1 de 3',
          'Uno A.',
          'Uno B.',
          'Licencia 2 de 3',
          'Dos A.',
          'Licencia 3 de 3',
          'Tres A.',
          'Volver',
        ]);
        final headers = [
          for (final h in [
            'Licencia 1 de 3',
            'Licencia 2 de 3',
            'Licencia 3 de 3',
          ])
            tester
                .getSemantics(_inDetail(find.text(h)))
                .flagsCollection
                .isHeader,
        ];
        expect(headers, [true, true, true]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-11: en inglés los encabezados de varias licencias salen "License n of total"',
      (tester) async {
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [
              ['One.'],
              ['Two.'],
            ]),
          ]),
          locale: const Locale('en'),
        );
        await _openDetail(tester, 'pdfrx');
        expect(_inDetail(find.text('License 1 of 2')), findsOneWidget);
        expect(_inDetail(find.text('License 2 of 2')), findsOneWidget);
      },
    );

    testWidgets(
      'CA-012-07: solo los párrafos de licencia llevan la marca de inglés; el título, los encabezados y el resto, no',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [
              ['Permission is hereby granted.'],
              ['Redistribution and use.'],
            ]),
          ]),
          screenReader: true,
        );
        await _openDetail(tester, 'pdfrx');
        Locale? localeOf(Finder f) =>
            tester.getSemantics(f).getSemanticsData().locale;
        expect(
          localeOf(_inDetail(find.text('Permission is hereby granted.'))),
          const Locale('en'),
        );
        expect(
          localeOf(_inDetail(find.text('Redistribution and use.'))),
          const Locale('en'),
        );
        for (final other in ['pdfrx', 'Licencia 1 de 2', 'Licencia 2 de 2']) {
          expect(
            localeOf(_inDetail(find.text(other)).first),
            const Locale('es'),
            reason: other,
          );
        }
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Volver'))
              .getSemanticsData()
              .locale,
          const Locale('es'),
        );
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-07: el texto de la licencia no cambia con el idioma de la app',
      (tester) async {
        final source = _Source([
          _pkg('pdfrx', [
            ['Permission is hereby granted.'],
          ]),
        ]);
        await _openLicenses(tester, source, locale: const Locale('en'));
        await _openDetail(tester, 'pdfrx');
        expect(
          _inDetail(find.text('Permission is hereby granted.')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CL-012-10: un elemento sin texto legible sale con "1 licencia" y un texto de error en su nivel 3',
      (tester) async {
        await _openLicenses(
          tester,
          _Source([
            const LicensePackage(name: 'vacio', texts: []),
            _pkg('otro'),
          ]),
        );
        expect(_inLicenses(find.text('1 licencia')), findsNWidgets(2));
        await _openDetail(tester, 'vacio');
        expect(_focused(tester), 'vacio');
        expect(_inDetail(find.text(_error)), findsOneWidget);
      },
    );

    testWidgets(
      'CL-012-10: un texto sin párrafos también cuenta como no legible',
      (tester) async {
        await _openLicenses(
          tester,
          _Source([
            _pkg('vacio', [<String>[]]),
          ]),
        );
        await _openDetail(tester, 'vacio');
        expect(_inDetail(find.text(_error)), findsOneWidget);
      },
    );

    testWidgets(
      'CL-012-12 / CA-012-03: las direcciones del texto son texto plano: ni enlace ni acción de toque',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [
              ['See https://www.apache.org/licenses/LICENSE-2.0 for details.'],
            ]),
          ]),
          screenReader: true,
        );
        await _openDetail(tester, 'pdfrx');
        final text = _inDetail(find.textContaining('https://www.apache.org'));
        expect(text, findsOneWidget);
        final node = tester.getSemantics(text);
        expect(node.flagsCollection.isLink, isFalse);
        final data = node.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(data.hasAction(SemanticsAction.longPress), isFalse);
        expect(
          _inDetail(find.byType(SelectableText)),
          findsNothing,
          reason: 'sin selección: nada que abra un menú de "abrir enlace"',
        );
        // Tocar el texto no abre nada.
        await tester.tap(text);
        await tester.pumpAndSettle();
        expect(find.byType(LicenseDetailScreen), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-03: la sangría de cada párrafo se respeta, con un límite, y -1 va centrado',
      (tester) async {
        final source = _Source([
          const LicensePackage(
            name: 'pdfrx',
            texts: [
              LicenseText([
                (text: 'Plano', indent: 0),
                (text: 'Sangría uno', indent: 1),
                (text: 'Sangría dos', indent: 2),
                (text: 'Sangría diez', indent: 10),
                (text: 'Centrado', indent: -1),
              ]),
            ],
          ),
        ]);
        await _openLicenses(tester, source);
        await _openDetail(tester, 'pdfrx');
        double left(String t) => tester.getTopLeft(_inDetail(find.text(t))).dx;
        final base = left('Plano');
        expect(left('Sangría uno'), greaterThan(base));
        expect(left('Sangría dos'), greaterThan(left('Sangría uno')));
        expect(
          left('Sangría diez'),
          left('Sangría dos'),
          reason: 'la sangría tiene un límite para que quepa al 200 %',
        );
        final centered = tester.getCenter(_inDetail(find.text('Centrado'))).dx;
        expect(centered, closeTo(tester.view.physicalSize.width / 2, 2));
      },
    );

    testWidgets(
      'CL-012-4: un texto muy largo se lee entero desplazando con el dedo',
      (tester) async {
        final paragraphs = [
          for (var i = 0; i < 300; i++) 'Párrafo número $i de la licencia.',
        ];
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [paragraphs]),
          ]),
        );
        await _openDetail(tester, 'pdfrx');
        expect(
          _inDetail(find.text('Párrafo número 0 de la licencia.')),
          findsOneWidget,
        );
        expect(
          _inDetail(find.text('Párrafo número 299 de la licencia.')),
          findsNothing,
        );
        await tester.drag(
          _inDetail(find.byType(ListView)),
          const Offset(0, -300000),
        );
        await tester.pumpAndSettle();
        expect(
          _inDetail(find.text('Párrafo número 299 de la licencia.')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CA-012-12: con el teclado, la lista es enfocable con su anillo y se llega al último párrafo con flechas, AvPág y Fin',
      (tester) async {
        final paragraphs = [
          for (var i = 0; i < 300; i++) 'Párrafo número $i de la licencia.',
        ];
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [paragraphs]),
          ]),
        );
        await _openDetail(tester, 'pdfrx');
        // Volver → título → lista.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(tester), 'license text');
        final ring = find.ancestor(
          of: find.byType(ListView),
          matching: find.byType(FocusRing),
        );
        expect(tester.widget<FocusRing>(ring.first).visible, isTrue);
        final first = _inDetail(find.text('Párrafo número 0 de la licencia.'));
        double pixels() => tester
            .state<ScrollableState>(_inDetail(find.byType(Scrollable)).first)
            .position
            .pixels;
        expect(pixels(), 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(pixels(), greaterThan(0), reason: 'flecha abajo');
        final afterArrow = pixels();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(pixels(), lessThan(afterArrow), reason: 'flecha arriba');
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(
          pixels(),
          greaterThan(400),
          reason: 'AvPág avanza casi una pantalla',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.pumpAndSettle();
        expect(pixels(), 0);
        // Avanzar por páginas hasta el último.
        final last = _inDetail(find.text('Párrafo número 299 de la licencia.'));
        for (var i = 0; i < 400 && last.evaluate().isEmpty; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();
        }
        expect(last, findsOneWidget);
        final screen = tester.view.physicalSize;
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(screen.height));
        expect(tester.getRect(last).top, greaterThanOrEqualTo(0));
        // Fin y Inicio.
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        expect(first, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        expect(last, findsOneWidget);
      },
    );

    testWidgets(
      'CA-012-12: Escape sube un nivel también con el foco en la lista',
      (tester) async {
        await _openLicenses(tester, _Source([_pkg('pdfrx')]));
        await _openDetail(tester, 'pdfrx');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(tester), 'license text');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);
        expect(find.byType(LicenseDetailScreen), findsNothing);
        expect(find.byType(LicensesScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CA-012-11: la lista del nivel 3 expone la acción de desplazar (Switch Access y lector)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final paragraphs = [for (var i = 0; i < 100; i++) 'Párrafo $i.'];
        await _openLicenses(
          tester,
          _Source([
            _pkg('pdfrx', [paragraphs]),
          ]),
          screenReader: true,
        );
        await _openDetail(tester, 'pdfrx');
        expect(_canScrollForward(tester), isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-02: Volver del nivel 3 al 2 sin haber tocado nada más deja el nivel 2 con la fila enfocada (con reducir movimiento también)',
      (tester) async {
        await _openLicenses(tester, _Source([_pkg('pdfrx')]), reduced: true);
        await _openDetail(tester, 'pdfrx');
        await tester.tap(find.bySemanticsLabel('Volver'));
        await _settle(tester);
        expect(_focused(tester), 'pdfrx');
      },
    );
  });

  group('splitLicenseParagraph (CL-012-4)', () {
    test('CL-012-4: un párrafo corto se queda entero', () {
      expect(splitLicenseParagraph('Hola mundo', maxLength: 50), [
        'Hola mundo',
      ]);
    });

    test('CL-012-4: uno largo se trocea sin perder nada, en saltos de línea si los hay', () {
      final text = [for (var i = 0; i < 40; i++) 'línea $i con texto']
          .join('\n');
      final chunks = splitLicenseParagraph(text, maxLength: 100);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 100), isTrue);
      expect(chunks.join('\n'), text);
    });

    test('CL-012-4: sin saltos de línea, en espacios; una palabra enorme se corta al final', () {
      final words = [for (var i = 0; i < 100; i++) 'palabra$i'].join(' ');
      final chunks = splitLicenseParagraph(words, maxLength: 60);
      expect(chunks.every((c) => c.length <= 60), isTrue);
      expect(chunks.join(' '), words);
      final blob = 'x' * 250;
      final blobChunks = splitLicenseParagraph(blob, maxLength: 100);
      expect(blobChunks.length, 3);
      expect(blobChunks.join(), blob);
    });
  });

  group('Nombre traducido de las bibliotecas de Android (CA-013-01)', () {
    const es = 'Bibliotecas de Android (AndroidX, Kotlin)';
    const en = 'Android libraries (AndroidX, Kotlin)';
    final packages = [
      _pkg('drift'),
      _pkg(androidLibrariesLicenseKey),
      _pkg('Archivo'),
      _pkg('Zeta'),
    ];

    /// Los nombres de las filas, de arriba abajo.
    List<String> rowOrder(WidgetTester tester) {
      final rows = [
        for (final e in _inLicenses(find.byType(InkWell)).evaluate())
          (
            tester.getTopLeft(find.byElementPredicate((x) => x == e)).dy,
            tester
                .widget<Text>(
                  find
                      .descendant(
                        of: find.byElementPredicate((x) => x == e),
                        matching: find.byType(Text),
                      )
                      .first,
                )
                .data!,
          ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final r in rows) r.$2];
    }

    testWidgets(
      'CA-013-01, CL-013-1: en español la entrada va en la B ("Bibliotecas…"), entre Archivo y drift',
      (tester) async {
        await _openLicenses(tester, _Source(packages));
        expect(rowOrder(tester), ['Archivo', es, 'drift', 'Zeta']);
        expect(
          _inLicenses(find.text(androidLibrariesLicenseKey)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'CA-013-01, CL-013-1: en inglés la entrada va en la A ("Android libraries…"), antes de Archivo',
      (tester) async {
        await _openLicenses(
          tester,
          _Source(packages),
          locale: const Locale('en'),
        );
        expect(rowOrder(tester), [en, 'Archivo', 'drift', 'Zeta']);
        expect(
          _inLicenses(find.text(androidLibrariesLicenseKey)),
          findsNothing,
        );
      },
    );

    for (final (code, name, label) in [
      ('es', es, '$es, 1 licencia'),
      ('en', en, '$en, 1 license'),
    ]) {
      testWidgets(
        'CA-013-01 ($code): la fila dice "nombre, N licencias", el nivel 3 lleva el nombre como título y el texto de la licencia no cambia',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            _Source(packages),
            locale: Locale(code),
            screenReader: true,
          );
          expect(find.bySemanticsLabel(label), findsOneWidget);
          await _openDetail(tester, name);
          expect(_inDetail(find.text(name)), findsOneWidget);
          expect(
            tester
                .getSemantics(_inDetail(find.text(name)))
                .flagsCollection
                .isHeader,
            isTrue,
          );
          expect(
            _inDetail(find.text(androidLibrariesLicenseKey)),
            findsNothing,
          );
          expect(
            _inDetail(
              find.text('MIT License. Text of $androidLibrariesLicenseKey.'),
            ),
            findsOneWidget,
          );
          handle.dispose();
        },
      );

      testWidgets(
        'CA-013-01 ($code): el nodo de la entrada (fila y título) lleva el idioma de la app, no la marca de inglés de los párrafos',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            _Source(packages),
            locale: Locale(code),
            screenReader: true,
          );
          Locale? localeOf(Finder f) =>
              tester.getSemantics(f).getSemanticsData().locale;
          expect(localeOf(find.bySemanticsLabel(label)), Locale(code));
          await _openDetail(tester, name);
          expect(localeOf(_inDetail(find.text(name))), Locale(code));
          // Los párrafos de la licencia siguen con la marca de inglés.
          expect(
            localeOf(_inDetail(find.textContaining('MIT License. Text of'))),
            const Locale('en'),
          );
          handle.dispose();
        },
      );
    }

    for (final (system, name) in [
      (const Locale('ca'), es),
      (const Locale('ca', 'ES'), es),
      (const Locale('gl'), en),
      (const Locale('eu'), en),
      (const Locale('fr', 'FR'), en),
    ]) {
      testWidgets(
        'CL-013-2: con el sistema en $system el nombre sale en el idioma de la app ($name)',
        (tester) async {
          await _openLicenses(tester, _Source(packages), locale: system);
          expect(_inLicenses(find.text(name)), findsOneWidget);
          await _openDetail(tester, name);
          expect(_inDetail(find.text(name)), findsOneWidget);
        },
      );
    }

    for (final code in ['es', 'en']) {
      testWidgets(
        'CL-013-3 ($code): al 200 % a 360 dp el nombre cabe o pasa a otra línea, en la fila y en el título del nivel 3, sin desbordes',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            _Source(packages),
            locale: Locale(code),
            textScale: 2,
            size: const Size(360, 640),
          );
          final name = code == 'es' ? es : en;
          expect(tester.takeException(), isNull);
          void inside(Finder screen, Finder text) {
            final box = tester.getRect(screen);
            final r = tester.getRect(text);
            expect(r.left, greaterThanOrEqualTo(box.left));
            expect(r.right, lessThanOrEqualTo(box.right));
          }

          inside(find.byType(LicensesScreen), _inLicenses(find.text(name)));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await _openDetail(tester, name);
          expect(tester.takeException(), isNull);
          inside(find.byType(LicenseDetailScreen), _inDetail(find.text(name)));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );
    }
  });

  group('Texto grande y movimiento (CA-012-13)', () {
    final packages = [
      _pkg('pdfrx', [
        ['Permission is hereby granted, free of charge, to any person.'],
        [
          'Copyright (c) https://github.com/very/long/address/that/does/not/break/at/all',
        ],
      ]),
      _pkg(androidLibrariesLicenseKey),
      _pkg('flutter_local_notifications_platform_interface'),
    ];

    for (final (code, title, back, close) in [
      ('es', 'Licencias de código abierto', 'Volver', 'Cerrar'),
      ('en', 'Open-source licenses', 'Back', 'Close'),
    ]) {
      testWidgets(
        'CA-012-13 ($code): los niveles 2 y 3 al 200 % a 360 dp no se desbordan y los objetivos miden ≥ 44',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _openLicenses(
            tester,
            _Source(packages),
            locale: Locale(code),
            textScale: 2,
            size: const Size(360, 640),
          );
          expect(tester.takeException(), isNull);
          final screen = tester.getRect(find.byType(LicensesScreen));
          for (final row in _inLicenses(find.byType(InkWell)).evaluate()) {
            final rect = tester.getRect(
              find.byElementPredicate((e) => e == row),
            );
            expect(rect.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
            expect(rect.left, greaterThanOrEqualTo(screen.left));
            expect(rect.right, lessThanOrEqualTo(screen.right));
          }
          final backSize = tester.getSize(find.byType(SquareIconButton));
          expect(backSize.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          expect(
            backSize.height,
            greaterThanOrEqualTo(UnaSizes.minTouchTarget),
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(title, isNotEmpty);
          expect(back, isNotEmpty);
          expect(close, isNotEmpty);
          // Nivel 3, con dos licencias y una dirección larga. La lista se
          // ordena por el nombre que se ve: pdfrx queda al final, fuera de la vista.
          await tester.scrollUntilVisible(
            _inLicenses(find.text('pdfrx')),
            200,
            scrollable: _inLicenses(find.byType(Scrollable)).first,
          );
          await _openDetail(tester, 'pdfrx');
          expect(tester.takeException(), isNull);
          final detail = tester.getRect(find.byType(LicenseDetailScreen));
          for (final t
              in find
                  .descendant(
                    of: find.byType(LicenseDetailScreen),
                    matching: find.byType(Text),
                  )
                  .evaluate()) {
            final rect = tester.getRect(find.byElementPredicate((e) => e == t));
            expect(rect.left, greaterThanOrEqualTo(detail.left));
            expect(rect.right, lessThanOrEqualTo(detail.right));
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );

      for (final height in [640.0, 400.0]) {
        // 400: pantalla corta, en la que el error se desplaza y el final debe
        // librar la barra.
        testWidgets(
          'CA-012-13 ($code): con la barra del sistema (48 dp abajo) al 200 % a 360x${height.toInt()}, "Reintentar" queda por encima de ella',
          (tester) async {
            const inset = 48.0;
            await _openLicenses(
              tester,
              _Source(null)..error = StateError('boom'),
              locale: Locale(code),
              textScale: 2,
              size: const Size(360, 640),
              bottomInset: inset,
            );
            // Se abre en 640 (el menú debe caber) y luego la pantalla se acorta.
            tester.view.physicalSize = Size(360, height);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.descendant(
                of: find.byType(LicensesScreen),
                matching: find.byType(SingleChildScrollView),
              ),
              const Offset(0, -2000),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byType(BrutalButton)).bottom,
              lessThanOrEqualTo(height - inset),
              reason: 'el último elemento queda por encima de la barra',
            );
          },
        );
      }

      testWidgets(
        'CA-012-13 ($code): el error de las licencias al 200 % a 360 dp cabe y el botón mide ≥ 44',
        (tester) async {
          await _openLicenses(
            tester,
            _Source(null)..error = StateError('boom'),
            locale: Locale(code),
            textScale: 2,
            size: const Size(360, 640),
          );
          expect(tester.takeException(), isNull);
          final button = tester.getSize(find.byType(BrutalButton));
          expect(button.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          final screen = tester.getRect(find.byType(LicensesScreen));
          expect(
            tester.getRect(find.byType(BrutalButton)).right,
            lessThanOrEqualTo(screen.right),
          );
          expect(
            tester.getRect(find.byType(BrutalButton)).left,
            greaterThanOrEqualTo(screen.left),
          );
        },
      );
    }

    testWidgets(
      'CA-012-13: un nombre largo sin espacios al 200 % no se desborda (se parte por caracteres, sin encoger por debajo del tamaño normal)',
      (tester) async {
        await _openLicenses(
          tester,
          _Source([
            _pkg('flutter_local_notifications_platform_interface'),
            ...packages,
          ]),
          textScale: 2,
          size: const Size(360, 640),
        );
        await _openDetail(
          tester,
          'flutter_local_notifications_platform_interface',
        );
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(
          _inDetail(find.text('flutter_local_notifications_platform_interface'))
              .first,
        );
        expect(title.style!.fontSize, greaterThanOrEqualTo(UnaFontSizes.title));
      },
    );

    testWidgets(
      'CA-012-13: con reducir movimiento los niveles 2 y 3 se abren sin animación',
      (tester) async {
        await _openLicenses(tester, _Source(packages), reduced: true);
        final r2 = ModalRoute.of(tester.element(find.byType(LicensesScreen)))!;
        expect(r2.transitionDuration, Duration.zero);
        await _openDetail(tester, 'pdfrx');
        final r3 = ModalRoute.of(
          tester.element(find.byType(LicenseDetailScreen)),
        )!;
        expect(r3.transitionDuration, Duration.zero);
        expect(r3.reverseTransitionDuration, Duration.zero);
      },
    );

    testWidgets('CA-012-13: sin reducir movimiento son un fundido de 160 ms', (
      tester,
    ) async {
      await _openLicenses(tester, _Source(packages));
      final r2 = ModalRoute.of(tester.element(find.byType(LicensesScreen)))!;
      expect(r2.transitionDuration, UnaMotion.sheetOut);
      await _openDetail(tester, 'pdfrx');
      final r3 = ModalRoute.of(
        tester.element(find.byType(LicenseDetailScreen)),
      )!;
      expect(r3.transitionDuration, UnaMotion.sheetOut);
      expect(r3.opaque, isTrue);
    });
  });
}
