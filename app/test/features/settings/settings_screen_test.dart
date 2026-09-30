import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/focus.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

class _Opener implements LinkOpener {
  bool available = true;
  bool openResult = true;
  int canOpenCalls = 0;
  final opened = <LinkTarget>[];

  @override
  Future<bool> canOpen(LinkTarget target) async {
    canOpenCalls++;
    return available;
  }

  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return openResult;
  }
}

const _menuLabel = 'Configuración y perfil';
const _noApp = 'No hay ninguna app para abrir este enlace.';

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

/// Qué tiene el foco de teclado: la etiqueta del botón cuadrado, o el primer
/// texto que hay dentro del nodo enfocado.
String? _focusedLabel(WidgetTester tester) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  final icon = ctx.findAncestorWidgetOfExactType<SquareIconButton>();
  if (icon != null) return icon.label;
  final texts = find.descendant(
    of: find.byElementPredicate((e) => identical(e, ctx)),
    matching: find.byType(Text),
  );
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}

bool _focusIsInMenu() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<MenuSheet>() !=
    null;

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

/// Abre el menú de la tarea actual y, desde él, "Configuración y perfil".
Future<_Opener> _openSettings(
  WidgetTester tester, {
  Locale locale = const Locale('es'),
  bool screenReader = false,
  bool reduced = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  _Opener? opener,
}) async {
  final o = opener ?? _Opener();
  await pumpUnaApp(
    tester,
    repo: InMemoryTaskRepository(),
    tasks: ['Primera', 'Segunda'],
    locale: locale,
    screenReader: screenReader,
    reduced: reduced,
    textScale: textScale,
    size: size,
    overrides: [linkOpenerProvider.overrideWithValue(o)],
  );
  await tester.tap(
    find.bySemanticsLabel(
      locale.languageCode == 'en' ? 'Task menu' : 'Menú de la tarea',
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(
      locale.languageCode == 'en' ? 'Settings and profile' : _menuLabel,
    ),
  );
  await _settle(tester);
  expect(find.byType(SettingsScreen), findsOneWidget);
  return o;
}

Finder _inSettings(Finder f) =>
    find.descendant(of: find.byType(SettingsScreen), matching: f);

void main() {
  setUpAll(loadAppFonts);

  group('Abrir y cerrar (CA-012-01, CA-012-02)', () {
    testWidgets(
      'CA-012-01: "Configuración y perfil" es un botón de ≥ 44 que abre el nivel 1 a pantalla completa, con título, Cerrar y dos opciones',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.text(_menuLabel));
        expect(node.label, _menuLabel);
        expect(node.flagsCollection.isButton, isTrue);
        await tester.tap(find.text(_menuLabel));
        await _settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(
          tester.getSize(find.byType(SettingsScreen)),
          tester.view.physicalSize,
          reason: 'a pantalla completa',
        );
        expect(_inSettings(find.text(_menuLabel)), findsOneWidget);
        expect(find.bySemanticsLabel('Cerrar'), findsOneWidget);
        expect(
          _inSettings(find.text('Licencias de código abierto')),
          findsOneWidget,
        );
        expect(
          _inSettings(find.text('Política de privacidad')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-01: el botón del menú mide al menos 44 de alto y de ancho',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        final button = find.ancestor(
          of: find.text(_menuLabel),
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
      },
    );

    testWidgets(
      'CA-012-12: el botón "Configuración y perfil" del menú muestra su anillo con el teclado y se activa con Intro',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
          overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        expect(await tabUntilRing(tester, _menuLabel), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CA-012-02: Cerrar, el atrás del sistema y Escape vuelven al menú tal como estaba, con el foco en "Configuración y perfil"',
      (tester) async {
        await _openSettings(tester);
        for (final close in <Future<void> Function()>[
          () => tester.tap(find.bySemanticsLabel('Cerrar')),
          () => tester.binding.handlePopRoute(),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          expect(find.byType(SettingsScreen), findsOneWidget);
          await close();
          await _settle(tester);
          expect(find.byType(SettingsScreen), findsNothing);
          expect(find.byType(MenuSheet), findsOneWidget);
          expect(find.text('Todas mis tareas'), findsOneWidget);
          expect(_focusIsInMenu(), isTrue);
          expect(_focusedLabel(tester), _menuLabel);
          // Vuelve a abrir para la siguiente forma de cerrar.
          await tester.tap(find.text(_menuLabel));
          await _settle(tester);
        }
      },
    );

    testWidgets('CA-012-02: al llegar, el foco está en el título', (
      tester,
    ) async {
      await _openSettings(tester);
      expect(_focusedLabel(tester), _menuLabel);
      expect(_focusIsInMenu(), isFalse);
    });

    testWidgets(
      'CA-012-02: del nivel 2 se sube al 1 (Volver, atrás y Escape) y el foco vuelve a "Licencias de código abierto"',
      (tester) async {
        await _openSettings(tester);
        for (final back in <Future<void> Function()>[
          () => tester.tap(find.bySemanticsLabel('Volver')),
          () => tester.binding.handlePopRoute(),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          await tester.tap(
            _inSettings(find.text('Licencias de código abierto')),
          );
          await _settle(tester);
          expect(find.byType(LicensesScreen), findsOneWidget);
          await back();
          await _settle(tester);
          expect(find.byType(LicensesScreen), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(_focusedLabel(tester), 'Licencias de código abierto');
        }
      },
    );

    testWidgets(
      'CA-012-12: Escape sube un nivel también después de tocar con el dedo',
      (tester) async {
        await _openSettings(tester);
        await tester.tap(_inSettings(find.text('Licencias de código abierto')));
        await _settle(tester);
        await tester.tap(find.bySemanticsLabel('Volver'));
        await _settle(tester);
        await tester.tapAt(const Offset(200, 500));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MenuSheet), findsOneWidget);
      },
    );

    testWidgets('CL-012-2: un doble toque en el menú abre una sola pantalla', (
      tester,
    ) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
        overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
      );
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_menuLabel));
      await tester.tap(find.text(_menuLabel), warnIfMissed: false);
      await _settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await _settle(tester);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsOneWidget);
    });

    testWidgets(
      'CL-012-2: un doble toque en "Licencias de código abierto" abre una sola lista',
      (tester) async {
        await _openSettings(tester);
        final option = _inSettings(find.text('Licencias de código abierto'));
        await tester.tap(option);
        await tester.tap(option, warnIfMissed: false);
        await _settle(tester);
        expect(find.byType(LicensesScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.byType(LicensesScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CL-012-9: con la pantalla abierta no se puede completar ni eliminar la tarea, y nada cambia al volver',
      (tester) async {
        final repo = InMemoryTaskRepository();
        await pumpUnaApp(
          tester,
          repo: repo,
          tasks: ['Primera', 'Segunda'],
          overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_menuLabel));
        await _settle(tester);
        expect(find.text('Eliminar'), findsNothing);
        expect(find.text('Editar'), findsNothing);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);
        expect(await repo.countPending(), 2);
        expect(find.text('Eliminar'), findsOneWidget);
      },
    );
  });

  group('Política de privacidad (CA-012-04, CA-012-05)', () {
    testWidgets(
      'CA-012-04: comprueba que hay app, pregunta con el dominio y abre solo con "Abrir"',
      (tester) async {
        final opener = await _openSettings(tester);
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        expect(opener.canOpenCalls, 1);
        expect(
          find.text('¿Abrir example.com en el navegador?'),
          findsOneWidget,
        );
        expect(opener.opened, isEmpty, reason: 'antes de confirmar, nada');
        await tester.tap(find.text('Abrir'));
        await _settle(tester);
        expect(opener.opened, hasLength(1));
        expect(
          opener.opened.single,
          isA<WebLink>().having(
            (w) => w.uri.toString(),
            'dirección',
            'https://example.com/privacy',
          ),
        );
        expect(find.text(_noApp), findsNothing);
      },
    );

    testWidgets(
      'CA-012-04: "Cancelar" no abre nada y el foco vuelve a "Política de privacidad"',
      (tester) async {
        final opener = await _openSettings(tester);
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        await tester.tap(find.text('Cancelar'));
        await _settle(tester);
        expect(opener.opened, isEmpty);
        expect(find.byType(LinkConfirmSheet), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(_focusedLabel(tester), 'Política de privacidad');
      },
    );

    testWidgets(
      'CA-012-04 / CL-012-3: la confirmación desde la Configuración no pide girar la tarea de debajo',
      (tester) async {
        await _openSettings(tester);
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await tester.pumpAndSettle();
        expect(find.byType(LinkConfirmSheet), findsOneWidget);
        expect(linkConfirmOpen.value, isFalse);
      },
    );

    testWidgets(
      'CA-012-04: sin app para abrirla no hay confirmación: el aviso, bajo las opciones, se anuncia por intento y el foco no se mueve',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = _Opener()..available = false;
        await _openSettings(tester, opener: opener, screenReader: true);
        tester.takeAnnouncements();
        final focusBefore = FocusManager.instance.primaryFocus;
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        expect(find.byType(LinkConfirmSheet), findsNothing);
        expect(opener.opened, isEmpty);
        expect(_inSettings(find.text(_noApp)), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(_noApp)).dy,
          greaterThan(
            tester
                .getBottomLeft(_inSettings(find.text('Política de privacidad')))
                .dy,
          ),
          reason: 'bajo las opciones',
        );
        expect(tester.takeAnnouncements().map((a) => a.message), [_noApp]);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        // Otro intento fallido: se anuncia otra vez, una sola.
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        expect(tester.takeAnnouncements().map((a) => a.message), [_noApp]);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-04: con app pero que falla al abrir (canOpen true, open false) sale el mismo aviso y el foco no se mueve',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = _Opener()..openResult = false;
        await _openSettings(tester, opener: opener, screenReader: true);
        tester.takeAnnouncements();
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        await tester.tap(find.text('Abrir'));
        await _settle(tester);
        expect(opener.opened, hasLength(1));
        expect(_inSettings(find.text(_noApp)), findsOneWidget);
        expect(tester.takeAnnouncements().map((a) => a.message), [_noApp]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-04: el aviso se oculta cuando después se abre con éxito, y canOpen se consulta en cada toque',
      (tester) async {
        final opener = _Opener()..available = false;
        await _openSettings(tester, opener: opener);
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        expect(find.text(_noApp), findsOneWidget);
        opener.available = true;
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        await tester.tap(find.text('Abrir'));
        await _settle(tester);
        expect(opener.canOpenCalls, 2);
        expect(opener.opened, hasLength(1));
        expect(find.text(_noApp), findsNothing);
      },
    );

    for (final url in [
      'http://example.com/privacy',
      'ftp://example.com/privacy',
      'https://usuario@example.com/privacy',
      '',
    ]) {
      testWidgets(
        'CL-012-8: "$url" no se abre: no se consulta nada y sale el aviso',
        (tester) async {
          final opener = _Opener();
          await pumpWithApp(
            tester,
            SettingsScreen(privacyUrl: url),
            overrides: [linkOpenerProvider.overrideWithValue(opener)],
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Política de privacidad'));
          await tester.pumpAndSettle();
          expect(opener.canOpenCalls, 0);
          expect(opener.opened, isEmpty);
          expect(find.byType(LinkConfirmSheet), findsNothing);
          expect(find.text(_noApp), findsOneWidget);
        },
      );
    }

    testWidgets(
      'CA-012-05: la dirección por defecto es la del marcador de la identidad (https)',
      (tester) async {
        final opener = _Opener();
        await pumpWithApp(
          tester,
          const SettingsScreen(),
          overrides: [linkOpenerProvider.overrideWithValue(opener)],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Política de privacidad'));
        await tester.pumpAndSettle();
        expect(
          find.text('¿Abrir example.com en el navegador?'),
          findsOneWidget,
        );
      },
    );
  });

  group('Lector de pantalla y teclado (CA-012-11, CA-012-12)', () {
    testWidgets(
      'CA-012-11: título (encabezado) → opciones (botones) → Cerrar; la política añade su pista',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openSettings(tester, screenReader: true);
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 4), [
          _menuLabel,
          'Licencias de código abierto',
          'Política de privacidad',
          'Cerrar',
        ]);
        final title = tester.getSemantics(
          _inSettings(find.text(_menuLabel)).first,
        );
        expect(title.flagsCollection.isHeader, isTrue);
        final licenses = tester.getSemantics(
          _inSettings(find.text('Licencias de código abierto')),
        );
        expect(licenses.flagsCollection.isButton, isTrue);
        expect(licenses.hint, isEmpty);
        final privacy = tester.getSemantics(
          _inSettings(find.text('Política de privacidad')),
        );
        expect(privacy.flagsCollection.isButton, isTrue);
        expect(privacy.hint, 'Abre una página web en el navegador');
        final close = tester.getSemantics(find.bySemanticsLabel('Cerrar'));
        expect(close.flagsCollection.isButton, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-11: con el aviso visible se lee tras el título y antes de las opciones',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = _Opener()..available = false;
        await _openSettings(tester, screenReader: true, opener: opener);
        await tester.tap(_inSettings(find.text('Política de privacidad')));
        await _settle(tester);
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 5), [
          _menuLabel,
          _noApp,
          'Licencias de código abierto',
          'Política de privacidad',
          'Cerrar',
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-11: en inglés todo sale en inglés (título, opciones, pista)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _openSettings(
          tester,
          locale: const Locale('en'),
          screenReader: true,
        );
        final order = _readingOrder(tester);
        expect(order.sublist(order.length - 4), [
          'Settings and profile',
          'Open-source licenses',
          'Privacy policy',
          'Close',
        ]);
        expect(
          tester.getSemantics(_inSettings(find.text('Privacy policy'))).hint,
          'Opens a web page in the browser',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'CA-012-12: el orden del teclado es Cerrar → título → opciones, con Intro para activar',
      (tester) async {
        await _openSettings(tester);
        expect(_focusedLabel(tester), _menuLabel);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(_focusedLabel(tester), 'Cerrar');
        final order = <String?>[];
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          order.add(_focusedLabel(tester));
        }
        expect(order, [
          _menuLabel,
          'Licencias de código abierto',
          'Política de privacidad',
        ]);
        // Intro activa la opción enfocada.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(find.byType(LinkConfirmSheet), findsOneWidget);
      },
    );

    testWidgets('CA-012-12: Cerrar, título y opciones muestran su anillo', (
      tester,
    ) async {
      await _openSettings(tester);
      for (final label in [
        'Cerrar',
        'Licencias de código abierto',
        'Política de privacidad',
      ]) {
        expect(
          await tabUntilRing(tester, label),
          isTrue,
          reason: 'anillo en "$label"',
        );
      }
    });

    testWidgets('CA-012-12: con el tacto no se ve ningún anillo', (
      tester,
    ) async {
      await _openSettings(tester);
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      for (final label in [
        'Cerrar',
        'Licencias de código abierto',
        'Política de privacidad',
      ]) {
        final ring = focusRingOf(label);
        expect(ring, findsOneWidget, reason: label);
        expect(tester.widget<FocusRing>(ring).visible, isFalse, reason: label);
      }
    });
  });

  group('Texto grande y movimiento (CA-012-13)', () {
    for (final (code, title, licenses, privacy, noApp) in [
      (
        'es',
        _menuLabel,
        'Licencias de código abierto',
        'Política de privacidad',
        _noApp,
      ),
      (
        'en',
        'Settings and profile',
        'Open-source licenses',
        'Privacy policy',
        "There's no app to open this link.",
      ),
    ]) {
      testWidgets(
        'CA-012-13 ($code): al 200 % a 360 dp no hay desbordamientos, y los objetivos miden ≥ 44 (también con el aviso)',
        (tester) async {
          final handle = tester.ensureSemantics();
          final opener = _Opener()..available = false;
          await _openSettings(
            tester,
            locale: Locale(code),
            textScale: 2,
            size: const Size(360, 640),
            opener: opener,
          );
          await tester.tap(_inSettings(find.text(privacy)));
          await _settle(tester);
          expect(tester.takeException(), isNull);
          expect(_inSettings(find.text(title)), findsOneWidget);
          expect(_inSettings(find.text(licenses)), findsOneWidget);
          expect(_inSettings(find.text(noApp)), findsOneWidget);
          for (final text in [licenses, privacy]) {
            final size = tester.getSize(
              find.ancestor(
                of: _inSettings(find.text(text)),
                matching: find.byType(InkWell),
              ),
            );
            expect(size.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          }
          final close = tester.getSize(find.byType(SquareIconButton));
          expect(close.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          expect(close.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          // Ninguna palabra se parte (como CA-001-07): la más larga cabe.
          for (final text in [title, licenses, privacy, noApp]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              _inSettings(find.text(text)).first,
            );
            expect(
              paragraph.getMinIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason: 'se parte una palabra de "$text"',
            );
          }
          // Todo dentro de la pantalla.
          final screen = tester.getRect(find.byType(SettingsScreen));
          for (final text in [title, licenses, privacy]) {
            final rect = tester.getRect(_inSettings(find.text(text)).first);
            expect(rect.left, greaterThanOrEqualTo(screen.left));
            expect(rect.right, lessThanOrEqualTo(screen.right));
            expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );
    }

    testWidgets('CA-012-13: la apertura es un fundido de 160 ms', (
      tester,
    ) async {
      await _openSettings(tester);
      final route = ModalRoute.of(tester.element(find.byType(SettingsScreen)))!;
      expect(route.transitionDuration, UnaMotion.sheetOut);
      expect(route.reverseTransitionDuration, UnaMotion.sheetOut);
      expect(route.opaque, isTrue);
    });

    testWidgets('CA-012-13: con reducir movimiento no hay animación', (
      tester,
    ) async {
      await _openSettings(tester, reduced: true);
      final route = ModalRoute.of(tester.element(find.byType(SettingsScreen)))!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    });

    testWidgets(
      'CA-012-13: sin reducir movimiento, a mitad del fundido la pantalla aún no es opaca del todo',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
          overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_menuLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(SettingsScreen),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
      },
    );
  });
}
