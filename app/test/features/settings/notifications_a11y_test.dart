import 'dart:ui' show CheckedState, Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/features/settings/notifications_block.dart';
import 'package:app/features/settings/notifications_state.dart';
import 'package:app/ui/live_region_announcer.dart';
import 'package:app/ui/una_icons.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/fonts.dart';
import '../../support/semantics_stops.dart';
import 'settings_harness.dart';

/// Accesibilidad del bloque de Notificaciones (spec 019, T-019-10; CA-019-26,
/// 29 y 03): orden de lectura, paradas de foco, teclado, texto al 200 % con las
/// fuentes reales, objetivos táctiles y contraste. Todo en español y en inglés.

class _Lang {
  const _Lang(
    this.code, {
    required this.row,
    required this.group,
    required this.heading,
    required this.options,
    required this.privacy,
    required this.help3,
    required this.next,
    required this.saveError,
    required this.blocked,
    required this.openSystem,
  });

  final String code;
  final String row;
  final String group;
  final String heading;
  final List<String> options;
  final String privacy;
  final String help3;

  /// La fila que sigue al bloque.
  final String next;

  /// Los avisos: error de guardado, bloqueo y el botón que abre el sistema.
  final String saveError;
  final String blocked;
  final String openSystem;

  Locale get locale => Locale(code);
}

const _es = _Lang(
  'es',
  row: 'Notificaciones',
  group: 'Notificaciones al día',
  heading: 'NOTIFICACIONES AL DÍA',
  options: [
    '1 notificación al día',
    '2 notificaciones al día',
    '3 notificaciones al día',
  ],
  privacy:
      'La notificación muestra tu tarea actual. Con el móvil bloqueado también '
      'se ve, salvo que ocultes el contenido sensible en los ajustes de tu '
      'móvil.',
  help3: 'Las notificaciones serán a las 08:55, a las 13:55 y a las 18:55.',
  next: 'Pantalla siempre activa',
  saveError: 'No se pudo guardar el ajuste.',
  blocked: 'Las notificaciones están bloqueadas en los Ajustes del sistema.',
  openSystem: 'Abrir los ajustes de notificaciones',
);

const _en = _Lang(
  'en',
  row: 'Notifications',
  group: 'Notifications per day',
  heading: 'NOTIFICATIONS PER DAY',
  options: [
    '1 notification per day',
    '2 notifications per day',
    '3 notifications per day',
  ],
  privacy:
      'The notification shows your current task. It also shows when your phone '
      "is locked, unless you hide sensitive content in your phone's settings.",
  help3: 'The notifications will be at 08:55, 13:55 and 18:55.',
  next: 'Keep screen on',
  saveError: "Couldn't save the setting.",
  blocked: 'Notifications are blocked in your system settings.',
  openSystem: 'Open notification settings',
);

const _langs = [_es, _en];

final _block = find.byType(NotificationsBlock);

Finder _inBlock(Finder f) => find.descendant(of: _block, matching: f);

Finder _option(NotificationsPerDay v) =>
    find.byKey(NotificationsBlock.optionKey(v));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _open(
  WidgetTester tester, {
  required _Lang lang,
  bool on = true,
  NotificationsPerDay perDay = NotificationsPerDay.three,
  FakeNotificationGateway? gateway,
  bool screenReader = false,
  bool keyboard = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  final repo = SettingsRepo();
  if (on) await repo.setNotificationsOn(true);
  await repo.setNotificationsPerDay(perDay);
  await openSettingsScreen(
    tester,
    locale: lang.locale,
    repo: repo,
    screenReader: screenReader,
    keyboard: keyboard,
    textScale: textScale,
    size: size,
    overrides: notificationsOverrides(gateway: gateway),
  );
}

/// El aviso de bloqueo: el diálogo se rechaza al encender.
Future<void> _rejectPermission(WidgetTester tester) async {
  await tester.tap(_inBlock(find.byType(UnaSwitchRow)));
  await _settle(tester);
}

/// El aviso de error: con el ajuste encendido, cambiar de opción falla al
/// programar (la cantidad guardada se queda).
Future<void> _failSave(
  WidgetTester tester,
  FakeNotificationGateway gateway,
) async {
  gateway.configureFailure = const NotificationGatewayException();
  // Con el texto al 200 % la opción puede estar bajo el borde.
  await tester.ensureVisible(_option(NotificationsPerDay.two));
  await tester.pumpAndSettle();
  await tester.tap(_option(NotificationsPerDay.two));
  await _settle(tester);
}

/// Cada parada de Tab hasta [label], con un tope (un `while` se colgaría si el
/// foco no llegara).
Future<void> _tabUntil(WidgetTester tester, String label) async {
  for (var i = 0; i < 12 && focusedLabel(tester) != label; i++) {
    await _tab(tester);
    await tester.pumpAndSettle();
  }
  expect(focusedLabel(tester), label);
}

/// El foco de teclado actual está entero dentro de la zona que se desplaza.
void _expectFocusInView(WidgetTester tester) {
  final viewport = tester.getRect(
    inSettings(find.byType(SingleChildScrollView)).first,
  );
  final focused = tester.getRect(
    find.byElementPredicate(
      (e) => identical(e, FocusManager.instance.primaryFocus!.context),
    ),
  );
  expect(focused.top, greaterThanOrEqualTo(viewport.top - 0.5));
  expect(focused.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
}

/// Todos los nodos del árbol de accesibilidad, en el orden del lector.
List<SemanticsNode> _nodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    out.add(node);
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

bool _focusable(SemanticsData d) =>
    d.flagsCollection.isFocused != Tristate.none;

/// Las líneas que ocupa un texto (por la altura de sus cajas).
int _lines(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final length = paragraph.text.toPlainText().length;
  return paragraph
      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length))
      .map((b) => b.top.round())
      .toSet()
      .length;
}

/// Una pulsación de Tab y lo que pasa con el foco.
Future<void> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in _langs) {
    group('CA-019-26 y CA-019-29 (${lang.code})', () {
      testWidgets(
        'CA-019-26: el orden del lector es fila, línea de privacidad, '
        'grupo y opciones, ayuda y la fila siguiente; el encabezado visible '
        'no se lee aparte',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _open(tester, lang: lang, screenReader: true);
          final labels = readingOrder(tester);
          final from = labels.indexOf(lang.row);
          final to = labels.indexWhere((l) => l.startsWith(lang.next));
          expect(from, isNonNegative);
          expect(to, greaterThan(from));
          expect(labels.sublist(from, to), [
            lang.row,
            lang.privacy,
            lang.group,
            ...lang.options,
            lang.help3,
          ]);
          expect(labels, isNot(contains(lang.heading)));
          handle.dispose();
        },
      );

      testWidgets('CA-019-26, CA-019-29: la línea de privacidad está con el '
          'interruptor apagado, encendido y bloqueado, y no es ni encabezado '
          'ni parada de foco', (tester) async {
        final handle = tester.ensureSemantics();
        for (final state in ['apagado', 'encendido', 'bloqueado']) {
          await _open(
            tester,
            lang: lang,
            on: state != 'apagado',
            screenReader: true,
          );
          if (state == 'bloqueado') {
            appContainer(tester)
                .read(systemAllowsNotificationsProvider.notifier)
                .setAllowed(false);
            await _settle(tester);
          }
          expect(_inBlock(find.text(lang.privacy)), findsOneWidget);
          final data = tester
              .getSemantics(find.bySemanticsLabel(lang.privacy))
              .getSemanticsData();
          expect(data.flagsCollection.isHeader, isFalse, reason: state);
          expect(_focusable(data), isFalse, reason: state);
          expect(data.hasAction(SemanticsAction.tap), isFalse, reason: state);
          // Para la siguiente vuelta.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        }
        handle.dispose();
      });

      testWidgets('CA-019-26: las paradas enfocables del bloque son el '
          'interruptor y las tres opciones; ni el grupo, ni la privacidad, ni '
          'la ayuda, ni el anunciador lo son', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester, lang: lang, screenReader: true);
        final focusable = <String>[];
        for (final node in _nodes(tester)) {
          if (node.isInvisible) continue;
          final data = node.getSemanticsData();
          if (_focusable(data) &&
              (data.label == lang.row || lang.options.contains(data.label))) {
            focusable.add(data.label);
          }
        }
        expect(focusable, [lang.row, ...lang.options]);

        // El grupo tiene nombre pero no es enfocable ni activable.
        final group = tester
            .getSemantics(find.bySemanticsLabel(lang.group))
            .getSemanticsData();
        expect(group.role, SemanticsRole.radioGroup);
        expect(_focusable(group), isFalse);
        expect(group.hasAction(SemanticsAction.tap), isFalse);
        expect(group.hasAction(SemanticsAction.focus), isFalse);

        // El anunciador: 1 × 1, sin foco ni acciones.
        final box = find.descendant(
          of: find.byType(LiveRegionNode),
          matching: find.byType(SizedBox),
        );
        expect(tester.getSize(box), const Size(1, 1));
        final announcer = tester.getSemantics(box).getSemanticsData();
        expect(announcer.flagsCollection.isLiveRegion, isTrue);
        expect(_focusable(announcer), isFalse);
        expect(announcer.hasAction(SemanticsAction.tap), isFalse);

        // Ninguna parada sin nombre en toda la pantalla.
        expect(unnamedSemanticsStops(tester), isEmpty);
        handle.dispose();
      });

      testWidgets('CA-019-26: para el lector es un interruptor y tres botones '
          'de radio de un grupo de selección única, con el número visible en '
          'el nombre', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(
          tester,
          lang: lang,
          perDay: NotificationsPerDay.two,
          screenReader: true,
        );
        final row = tester
            .getSemantics(find.bySemanticsLabel(lang.row))
            .getSemanticsData();
        expect(row.flagsCollection.isToggled, Tristate.isTrue);
        for (final (i, label) in lang.options.indexed) {
          final data = tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData();
          expect(
            data.flagsCollection.isChecked,
            i == 1 ? CheckedState.isTrue : CheckedState.isFalse,
            reason: label,
          );
          expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          // WCAG 2.5.3: el número que se ve está en el nombre.
          expect(label, contains('${i + 1}'));
          expect(
            find.descendant(
              of: _option(NotificationsPerDay.values[i]),
              matching: find.text('${i + 1}'),
            ),
            findsOneWidget,
          );
        }
        handle.dispose();
      });

      testWidgets('CA-019-26: Tab recorre el interruptor y las tres opciones; '
          'las flechas solo mueven el foco; Intro y Espacio seleccionan', (
        tester,
      ) async {
        final gateway = FakeNotificationGateway();
        await _open(
          tester,
          lang: lang,
          perDay: NotificationsPerDay.one,
          gateway: gateway,
          keyboard: true,
        );
        tester
            .widget<UnaSwitchRow>(_inBlock(find.byType(UnaSwitchRow)))
            .focusNode!
            .requestFocus();
        await tester.pump();
        expect(focusedLabel(tester), lang.row);
        for (final n in ['1', '2', '3']) {
          await _tab(tester);
          expect(focusedLabel(tester), n);
        }
        await _tab(tester);
        expect(focusedLabel(tester), lang.next);

        // Vuelta a la primera opción y flechas: mueven el foco y no
        // seleccionan nada.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (var i = 0; i < 3; i++) {
          await _tab(tester);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        expect(focusedLabel(tester), '1');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(focusedLabel(tester), '2');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(focusedLabel(tester), '3');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(focusedLabel(tester), '2');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await _settle(tester);
        expect(gateway.configureCalls, isEmpty);
        expect(
          find.descendant(
            of: _option(NotificationsPerDay.one),
            matching: find.byKey(NotificationsBlock.markKey),
          ),
          findsOneWidget,
        );

        // Intro selecciona la opción con el foco…
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(gateway.configureCalls.single.perDay, NotificationsPerDay.three);
        // …y Espacio también.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _settle(tester);
        expect(gateway.configureCalls.last.perDay, NotificationsPerDay.two);
      });

      testWidgets('CA-019-26, CA-019-29: al 200 % a 360 dp nada se recorta ni '
          'se superpone y las tres opciones siguen a ≥ 44', (tester) async {
        await _open(
          tester,
          lang: lang,
          textScale: 2,
          size: const Size(360, 640),
        );
        expect(tester.takeException(), isNull);
        final scroll = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        // De arriba abajo, sin pisarse.
        final stack = [
          tester.getRect(_inBlock(find.byType(UnaSwitchRow))),
          tester.getRect(_inBlock(find.text(lang.privacy))),
          tester.getRect(_inBlock(find.text(lang.heading))),
          tester.getRect(_option(NotificationsPerDay.one)),
          tester.getRect(_inBlock(find.text(lang.help3))),
        ];
        for (var i = 1; i < stack.length; i++) {
          expect(
            stack[i].top,
            greaterThanOrEqualTo(stack[i - 1].bottom - 1),
            reason: 'el elemento $i está sobre el anterior',
          );
        }
        // Las tres opciones, a lo ancho de la columna y de ≥ 44 de alto.
        final one = tester.getRect(_option(NotificationsPerDay.one));
        final three = tester.getRect(_option(NotificationsPerDay.three));
        expect(three.right, lessThanOrEqualTo(scroll.right));
        for (final v in NotificationsPerDay.values) {
          final r = tester.getRect(_option(v));
          expect(r.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          expect(r.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          // El número, entero dentro de su opción.
          final n = tester.getRect(
            find.descendant(of: _option(v), matching: find.text('${v.count}')),
          );
          expect(r.contains(n.topLeft), isTrue, reason: '${v.count}');
          expect(r.contains(n.bottomRight), isTrue, reason: '${v.count}');
        }
        expect(one.left, lessThan(three.left));

        // Los textos de ayuda y de privacidad se parten en líneas sin
        // recortarse: caben a lo ancho de la columna.
        for (final text in [lang.privacy, lang.help3, lang.heading]) {
          final r = tester.getRect(_inBlock(find.text(text)));
          expect(r.left, greaterThanOrEqualTo(scroll.left), reason: text);
          expect(r.right, lessThanOrEqualTo(scroll.right), reason: text);
          expect(_lines(tester, _inBlock(find.text(text))), greaterThan(1));
        }
      });

      for (final width in [320.0, 360.0]) {
        testWidgets('CA-019-26: el nombre «${lang.row}» al 200 % a '
            '${width.toInt()} dp cabe en la fila (líneas contadas)', (
          tester,
        ) async {
          await _open(
            tester,
            lang: lang,
            on: false,
            textScale: 2,
            size: Size(width, 640),
          );
          expect(tester.takeException(), isNull);
          final name = _inBlock(find.text(lang.row));
          final rect = tester.getRect(name);
          final row = tester.getRect(_inBlock(find.byType(UnaSwitchRow)));
          expect(rect.left, greaterThanOrEqualTo(row.left));
          final track = tester.getRect(
            _inBlock(find.byKey(UnaSwitchRow.trackKey)),
          );
          expect(rect.right, lessThanOrEqualTo(track.left + 0.5));
          // La fila crece con el nombre: el pomo y la pista dentro de ella.
          expect(row.contains(track.center), isTrue);
          expect(_lines(tester, name), lessThanOrEqualTo(2));
        });
      }

      testWidgets('CA-019-26: con el foco de teclado en la opción 3 al 200 % '
          'queda a la vista', (tester) async {
        await _open(
          tester,
          lang: lang,
          textScale: 2,
          size: const Size(360, 640),
          keyboard: true,
        );
        tester
            .widget<UnaSwitchRow>(_inBlock(find.byType(UnaSwitchRow)))
            .focusNode!
            .requestFocus();
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await _tab(tester);
          await tester.pumpAndSettle();
        }
        expect(focusedLabel(tester), '3');
        final viewport = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        final option = tester.getRect(_option(NotificationsPerDay.three));
        expect(option.top, greaterThanOrEqualTo(viewport.top));
        expect(option.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(option.left, greaterThanOrEqualTo(viewport.left));
        expect(option.right, lessThanOrEqualTo(viewport.right));
      });

      testWidgets('CA-019-26: las guías de la 015 (Android, iOS, etiquetas y '
          'contraste) se cumplen con la fila, con el aviso de bloqueo y su '
          'botón, y con el aviso de error', (tester) async {
        final handle = tester.ensureSemantics();
        final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
        await _open(
          tester,
          lang: lang,
          on: false,
          gateway: gateway,
          screenReader: true,
        );
        Future<void> guidelines() async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await guidelines();
        await _rejectPermission(tester);
        expect(readingOrder(tester), contains(lang.blocked));
        expect(readingOrder(tester), contains(lang.openSystem));
        await guidelines();

        // El sistema vuelve a permitirlas y la cantidad no se guarda: sale el
        // aviso de error con las opciones a la vista.
        appContainer(tester)
            .read(systemAllowsNotificationsProvider.notifier)
            .setAllowed(true);
        gateway.allowed = true;
        await tester.tap(_inBlock(find.byType(UnaSwitchRow)));
        await _settle(tester);
        await _failSave(tester, gateway);
        expect(readingOrder(tester), contains(lang.saveError));
        await guidelines();
        handle.dispose();
      });

      testWidgets('CA-019-26: con el teclado y al 200 % a 360 dp, el bloque '
          'desplegado con la opción 3, la línea de privacidad y el aviso de '
          'error se recorre con Tab sin salir de la vista y sin pisarse', (
        tester,
      ) async {
        final gateway = FakeNotificationGateway();
        await _open(
          tester,
          lang: lang,
          gateway: gateway,
          textScale: 2,
          size: const Size(360, 640),
          keyboard: true,
        );
        await _failSave(tester, gateway);
        expect(tester.takeException(), isNull);
        // El aviso de error entra entre la ayuda y la fila siguiente.
        final stack = [
          tester.getRect(_inBlock(find.byType(UnaSwitchRow))),
          tester.getRect(_inBlock(find.text(lang.privacy))),
          tester.getRect(_inBlock(find.text(lang.heading))),
          tester.getRect(_option(NotificationsPerDay.one)),
          tester.getRect(_inBlock(find.text(lang.help3))),
          tester.getRect(_inBlock(find.text(lang.saveError))),
        ];
        for (var i = 1; i < stack.length; i++) {
          expect(
            stack[i].top,
            greaterThanOrEqualTo(stack[i - 1].bottom - 1),
            reason: 'el elemento $i está sobre el anterior',
          );
        }
        final scroll = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        for (final text in [lang.privacy, lang.help3, lang.saveError]) {
          final r = tester.getRect(_inBlock(find.text(text)));
          expect(r.left, greaterThanOrEqualTo(scroll.left), reason: text);
          expect(r.right, lessThanOrEqualTo(scroll.right), reason: text);
        }

        // Tab: interruptor, 1, 2, 3 y la fila siguiente; ni la privacidad, ni
        // la ayuda, ni el aviso son paradas; cada parada queda a la vista.
        tester
            .widget<UnaSwitchRow>(_inBlock(find.byType(UnaSwitchRow)))
            .focusNode!
            .requestFocus();
        await tester.pumpAndSettle();
        expect(focusedLabel(tester), lang.row);
        _expectFocusInView(tester);
        for (final stop in ['1', '2', '3', lang.next]) {
          await _tab(tester);
          await tester.pumpAndSettle();
          expect(focusedLabel(tester), stop);
          _expectFocusInView(tester);
        }
        // Mayús+Tab da la vuelta por las mismas paradas, también a la vista.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (final stop in ['3', '2', '1', lang.row]) {
          await _tab(tester);
          await tester.pumpAndSettle();
          expect(focusedLabel(tester), stop);
          _expectFocusInView(tester);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CA-019-26: con el teclado y al 200 % a 360 dp, el aviso de '
          'bloqueo tiene su botón como parada tras el interruptor, a la vista '
          'y sin recortar', (tester) async {
        final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
        await _open(
          tester,
          lang: lang,
          on: false,
          gateway: gateway,
          textScale: 2,
          size: const Size(360, 640),
          keyboard: true,
        );
        await _rejectPermission(tester);
        expect(tester.takeException(), isNull);
        final scroll = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        final privacy = tester.getRect(_inBlock(find.text(lang.privacy)));
        final blocked = tester.getRect(_inBlock(find.text(lang.blocked)));
        final button = tester.getRect(_inBlock(find.text(lang.openSystem)));
        expect(blocked.top, greaterThanOrEqualTo(privacy.bottom - 1));
        expect(button.top, greaterThanOrEqualTo(blocked.bottom - 1));
        for (final r in [privacy, blocked, button]) {
          expect(r.left, greaterThanOrEqualTo(scroll.left));
          expect(r.right, lessThanOrEqualTo(scroll.right));
        }
        expect(
          _lines(tester, _inBlock(find.text(lang.blocked))),
          greaterThan(1),
        );

        tester
            .widget<UnaSwitchRow>(_inBlock(find.byType(UnaSwitchRow)))
            .focusNode!
            .requestFocus();
        await tester.pumpAndSettle();
        expect(focusedLabel(tester), lang.row);
        // Con el sistema bloqueando no hay opciones: la siguiente parada es
        // el botón y después la fila siguiente.
        await _tab(tester);
        await tester.pumpAndSettle();
        expect(focusedLabel(tester), lang.openSystem);
        _expectFocusInView(tester);
        final focused = tester.getRect(
          find.byElementPredicate(
            (e) => identical(e, FocusManager.instance.primaryFocus!.context),
          ),
        );
        expect(focused.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
        await _tabUntil(tester, lang.next);
        _expectFocusInView(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CA-019-26: las guías de la plataforma se cumplen con el '
          'bloque desplegado y con el anunciador diciendo la ayuda', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _open(tester, lang: lang, screenReader: true);
        Future<void> guidelines() async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await guidelines();
        await tester.tap(_option(NotificationsPerDay.two));
        await _settle(tester);
        await tester.pump(DebouncedAnnouncer.debounce);
        expect(
          tester
              .widget<LiveRegionNode>(find.byType(LiveRegionNode))
              .announcer
              .message
              .value,
          isNotEmpty,
        );
        await guidelines();
        handle.dispose();
      });
    });
  }

  group('CA-019-03: la marca de selección', () {
    test('CA-019-03: la marca (tinta) contrasta ≥ 3:1 con el relleno amarillo '
        'de la marcada y con el papel de las demás, también en grises', () {
      expect(
        _contrast(UnaColors.ink, UnaColors.switchOn),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(UnaColors.ink, UnaColors.paper),
        greaterThanOrEqualTo(3),
      );
      // En escala de grises el contraste solo depende de la luminancia: es el
      // mismo cálculo (no del tono).
      Color gray(Color c) {
        final l = (c.computeLuminance() * 255).round();
        return Color.fromARGB(255, l, l, l);
      }

      expect(
        _contrast(gray(UnaColors.ink), gray(UnaColors.switchOn)),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('CA-019-03: la marca dibujada es de tinta, existe solo en la '
        'marcada y no depende del peso de la fuente', (tester) async {
      await _open(tester, lang: _es, perDay: NotificationsPerDay.three);
      expect(
        tester.widget<UnaIcon>(find.byKey(NotificationsBlock.markKey)).color,
        UnaColors.ink,
      );
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.three),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      for (final v in [NotificationsPerDay.one, NotificationsPerDay.two]) {
        expect(
          find.descendant(
            of: _option(v),
            matching: find.byKey(NotificationsBlock.markKey),
          ),
          findsNothing,
        );
      }
    });
  });
}
