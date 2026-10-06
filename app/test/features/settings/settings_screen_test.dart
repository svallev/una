import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/external_page.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/semantics_locales.dart';
import 'settings_harness.dart';

/// Las tres direcciones, distintas entre sí, para ver que cada fila abre la
/// suya.
const _links = SettingsLinks(
  privacy: 'https://privacy.zxq-uno.com/p',
  licenses: 'https://licenses.zxq-dos.com/l',
  help: 'https://help.zxq-tres.com/h',
);

String _addressOf(LinkTarget target) => (target as WebLink).uri.toString();

bool _focusIsInMenu() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<MenuSheet>() !=
    null;

Future<void> _tab(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

double _knobLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(UnaSwitchRow.knobKey)).dx;

Tristate _toggled(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(label))
    .getSemanticsData()
    .flagsCollection
    .isToggled;

const _keepAwake = 'Pantalla siempre activa';
const _keepAwakeLabel = '$_keepAwake, Imágenes, documentos y web';

void main() {
  setUpAll(loadAppFonts);

  group('Abrir y cerrar (CA-015-01a, CA-015-02)', () {
    testWidgets(
      'CA-015-01a: "Ajustes" es un botón de ≥ 44 que abre el nivel 1 a pantalla completa, con título y Cerrar ajustes',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.text('Ajustes'));
        expect(node.label, 'Ajustes');
        expect(node.flagsCollection.isButton, isTrue);
        final button = find.ancestor(
          of: find.text('Ajustes'),
          matching: find.byType(InkWell),
        );
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
        await tester.tap(find.text('Ajustes'));
        await settleSettings(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(
          tester.getSize(find.byType(SettingsScreen)),
          tester.view.physicalSize,
          reason: 'a pantalla completa',
        );
        expect(inSettings(find.text('Ajustes')), findsOneWidget);
        expect(find.bySemanticsLabel('Cerrar ajustes'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-02: Cerrar ajustes, el atrás del sistema y Escape vuelven a la tarea (con el menú ya cerrado y el foco en el botón de menú)',
      (tester) async {
        await openSettingsScreen(tester);
        for (final close in <Future<void> Function()>[
          () => tester.tap(find.bySemanticsLabel('Cerrar ajustes')),
          () => tester.binding.handlePopRoute(),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          expect(find.byType(SettingsScreen), findsOneWidget);
          await close();
          await settleSettings(tester);
          expect(find.byType(SettingsScreen), findsNothing);
          expect(find.byType(MenuSheet), findsNothing);
          expect(_focusIsInMenu(), isFalse);
          expect(focusedLabel(tester), 'Menú de la tarea');
          // Vuelve a abrir para la siguiente forma de cerrar.
          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ajustes'));
          await settleSettings(tester);
        }
      },
    );

    testWidgets(
      'CA-015-02: del nivel 2 se sube al 1 (Volver, atrás y Escape) y el foco vuelve a "Idioma"',
      (tester) async {
        await openSettingsScreen(tester);
        for (final back in <Future<void> Function()>[
          () => tester.tap(find.bySemanticsLabel('Volver')),
          () => tester.binding.handlePopRoute(),
          () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        ]) {
          await tester.tap(inSettings(find.text('Idioma')));
          await settleSettings(tester);
          expect(find.byType(LanguagePage), findsOneWidget);
          await back();
          await settleSettings(tester);
          expect(find.byType(LanguagePage), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(focusedLabel(tester), 'Idioma');
        }
      },
    );

    testWidgets(
      'CA-015-21c: Escape sube un nivel también después de tocar con el dedo',
      (tester) async {
        await openSettingsScreen(tester);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        await tester.tap(find.bySemanticsLabel('Volver'));
        await settleSettings(tester);
        await tester.tapAt(const Offset(300, 40));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleSettings(tester);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MenuSheet), findsNothing);
      },
    );

    testWidgets('CL-015-1: un doble toque en el menú abre una sola pantalla', (
      tester,
    ) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.tap(find.text('Ajustes'), warnIfMissed: false);
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MenuSheet), findsNothing);
    });

    testWidgets('CL-015-1: un doble toque en "Idioma" abre una sola página', (
      tester,
    ) async {
      await openSettingsScreen(tester);
      final row = inSettings(find.text('Idioma'));
      await tester.tap(row);
      await tester.tap(row, warnIfMissed: false);
      await settleSettings(tester);
      expect(find.byType(LanguagePage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(find.byType(LanguagePage), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets(
      'CL-015-3: con Ajustes abierto no se puede completar ni eliminar la tarea, y nada cambia al volver',
      (tester) async {
        final repo = InMemoryTaskRepository();
        await pumpUnaApp(tester, repo: repo, tasks: ['Primera', 'Segunda']);
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await settleSettings(tester);
        expect(find.text('Eliminar'), findsNothing);
        expect(find.text('Editar'), findsNothing);
        expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleSettings(tester);
        expect(await repo.countPending(), 2);
        expect(find.byType(MenuSheet), findsNothing);
        expect(find.text('Primera'), findsOneWidget);
      },
    );

    testWidgets(
      'CA-015-02: al llegar con el tacto, el foco está en el título (no en Cerrar ajustes)',
      (tester) async {
        await openSettingsScreen(tester);
        expect(focusedLabel(tester), 'Ajustes');
        expect(_focusIsInMenu(), isFalse);
      },
    );

    testWidgets(
      'CA-015-21a: con teclado físico, el foco de teclado llega a Cerrar ajustes',
      (tester) async {
        await openSettingsScreen(tester, keyboard: true);
        expect(focusedLabel(tester), 'Cerrar ajustes');
        // Y la página de Idioma, a Volver.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter); // Cierra.
        await settleSettings(tester);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );
  });

  group('Estructura (CA-015-01b, CA-015-01c)', () {
    testWidgets(
      'CA-015-01b: de arriba abajo, Idioma, Pantalla siempre activa, Información (encabezado), Política, Licencias y Ayuda',
      (tester) async {
        await openSettingsScreen(tester);
        final tops = <String, double>{};
        for (final text in [
          'Ajustes',
          'Idioma',
          _keepAwake,
          'Imágenes, documentos y web',
          'Información',
          'Política de privacidad',
          'Licencias de terceros',
          'Ayuda',
        ]) {
          tops[text] = tester.getTopLeft(inSettings(find.text(text))).dy;
        }
        final order = tops.keys.toList();
        for (var i = 1; i < order.length; i++) {
          expect(
            tops[order[i]],
            greaterThan(tops[order[i - 1]]!),
            reason: '"${order[i]}" va después de "${order[i - 1]}"',
          );
        }
      },
    );

    testWidgets(
      'CA-015-01c: no hay Notificaciones ni Bloquear zoom en esta versión',
      (tester) async {
        for (final (locale, texts) in [
          (const Locale('es'), ['Notificaciones', 'Bloquear zoom']),
          (const Locale('en'), ['Notifications', 'Lock zoom']),
        ]) {
          await openSettingsScreen(tester, locale: locale);
          for (final text in texts) {
            expect(find.textContaining(text), findsNothing, reason: text);
          }
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'CA-015-01b: dos separadores de 4 px de borde a borde y filas con una línea de 1 px entre las de un bloque',
      (tester) async {
        await openSettingsScreen(tester);
        final width = tester.view.physicalSize.width;
        final separators = find.byWidgetPredicate(
          (w) =>
              w is SizedBox &&
              w.height == UnaSizes.separatorBlock &&
              w.child is ColoredBox,
        );
        expect(separators, findsNWidgets(2));
        for (final f in separators.evaluate()) {
          final rect = tester.getRect(find.byElementPredicate((e) => e == f));
          expect(rect.width, width, reason: 'a sangre');
          expect(
            (f.widget as SizedBox).child,
            isA<ColoredBox>().having(
              (c) => c.color,
              'color',
              UnaColors.disabled,
            ),
          );
        }
        // Línea de 1 px sobre las tres filas de web (tres filas con borde).
        final dividers = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border is Border &&
                ((w.decoration! as BoxDecoration).border! as Border)
                        .top
                        .width ==
                    UnaSizes.separatorRow,
          ),
        );
        expect(dividers, findsNWidgets(3));
      },
    );

    testWidgets(
      'CA-015-01b: medidas del prototipo (Idioma 60, interruptor con subtítulo 76, Política y Licencias 52, Ayuda 60)',
      (tester) async {
        await openSettingsScreen(tester);
        double height(String text) => tester
            .getSize(
              find
                  .ancestor(
                    of: inSettings(find.text(text)),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height;
        expect(height('Idioma'), UnaSizes.settingsRow);
        expect(height(_keepAwake), UnaSizes.settingsRowSwitchHint);
        // Las filas de web miden su alto más la línea de 1 px de arriba.
        expect(height('Política de privacidad'), UnaSizes.settingsRowSub);
        expect(height('Licencias de terceros'), UnaSizes.settingsRowSub);
        expect(height('Ayuda'), UnaSizes.settingsRow);
      },
    );

    testWidgets(
      'CA-015-01b: "Información" es un encabezado que no se pulsa y todos los iconos son decorativos',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(tester, screenReader: true);
        final info = tester
            .getSemantics(inSettings(find.text('Información')))
            .getSemanticsData();
        expect(info.flagsCollection.isHeader, isTrue);
        expect(info.hasAction(SemanticsAction.tap), isFalse);
        expect(info.label, 'Información');
        // Ningún nodo lleva el nombre de un icono: solo hay etiquetas de texto.
        final labels = readingOrder(tester);
        expect(labels, isNot(contains('')));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-01b: con 600 dp o más, la pantalla va centrada a 600 como el resto de la app',
      (tester) async {
        await openSettingsScreen(tester, size: const Size(900, 900));
        final rect = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        expect(rect.width, lessThanOrEqualTo(UnaSizes.contentMaxWidth));
        expect(rect.center.dx, closeTo(450, 0.5));
      },
    );
  });

  group('Idioma (CA-015-06)', () {
    testWidgets(
      'CA-015-06: la fila muestra "Como el sistema" por defecto, con chevron, y abre el nivel 2',
      (tester) async {
        await openSettingsScreen(tester);
        expect(inSettings(find.text('Como el sistema')), findsOneWidget);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        expect(find.byType(LanguagePage), findsOneWidget);
      },
    );

    for (final (choice, value) in [
      (LocaleChoice.es, 'Español'),
      (LocaleChoice.en, 'English'),
    ]) {
      testWidgets(
        'CA-015-06 / CA-015-11: con ${choice.code} el valor es "$value" y su nombre lleva su propio idioma ("Idioma, $value")',
        (tester) async {
          final handle = tester.ensureSemantics();
          final repo = InMemoryTaskRepository();
          await repo.setLocale(choice);
          await openSettingsScreen(
            tester,
            repo: repo,
            screenReader: true,
            locale: const Locale('fr'),
            appLanguage: choice.code,
          );
          // El valor guardado manda sobre el sistema.
          final name = choice == LocaleChoice.es ? 'Idioma' : 'Language';
          final label = '$name, $value';
          final row = semanticsLabelled(tester, label);
          expect(localeOfName(row, value)?.languageCode, choice.code);
          expect(
            localeOfName(row, name)?.languageCode,
            choice.code,
            reason: 'el nombre de la fila va en el idioma de la app',
          );
          handle.dispose();
        },
      );
    }

    testWidgets(
      'CA-015-08 / CA-015-20h: elegir English vuelve a Ajustes ya en inglés, con el valor nuevo y el foco en la fila, una sola vez',
      (tester) async {
        final repo = InMemoryTaskRepository();
        await openSettingsScreen(tester, repo: repo);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        await tester.tap(find.text('English'));
        await settleSettings(tester);
        expect(find.byType(LanguagePage), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(inSettings(find.text('Settings')), findsOneWidget);
        expect(inSettings(find.text('Language')), findsOneWidget);
        expect(inSettings(find.text('English')), findsOneWidget);
        expect(await repo.locale(), LocaleChoice.en);
        expect(focusedLabel(tester), 'Language');
      },
    );

    testWidgets(
      'CA-015-08: si no se puede guardar, la página se queda abierta con el aviso y Ajustes no cambia',
      (tester) async {
        final repo = _LocaleFailingRepo();
        await openSettingsScreen(tester, repo: repo);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        await tester.tap(find.text('English'));
        await settleSettings(tester);
        expect(find.byType(LanguagePage), findsOneWidget);
        expect(find.text('No se pudo guardar el ajuste.'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await settleSettings(tester);
        expect(inSettings(find.text('Idioma')), findsOneWidget);
        expect(inSettings(find.text('Como el sistema')), findsOneWidget);
      },
    );
  });

  group('Pantalla siempre activa (CA-015-03, CA-015-05, CA-015-25)', () {
    testWidgets(
      'CA-015-03: es un interruptor apagado por defecto, con el nombre y el subtítulo juntos y un solo nodo',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(tester, screenReader: true);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isFalse);
        expect(find.byType(UnaSwitchRow), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(_keepAwakeLabel))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-03 / CA-015-05: tocar la fila guarda y mueve el pomo; vuelve a apagarlo; lo guardado sobrevive',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo();
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        final off = _knobLeft(tester);
        await tester.tap(inSettings(find.text(_keepAwake)));
        await settleSettings(tester);
        expect(repo.keepWrites, [true]);
        expect(await repo.keepScreenOn(), isTrue);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isTrue);
        expect(_knobLeft(tester), greaterThan(off));
        await tester.tap(inSettings(find.text(_keepAwake)));
        await settleSettings(tester);
        expect(repo.keepWrites, [true, false]);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isFalse);
        expect(_knobLeft(tester), off);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-03: el interruptor no se mueve hasta que el guardado se confirma',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()..gate = Completer<void>();
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        final off = _knobLeft(tester);
        await tester.tap(inSettings(find.text(_keepAwake)));
        await tester.pump(const Duration(seconds: 1));
        expect(repo.keepWrites, [true]);
        expect(_knobLeft(tester), off, reason: 'sin cambio optimista');
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isFalse);
        repo.gate!.complete();
        await settleSettings(tester);
        expect(_knobLeft(tester), greaterThan(off));
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-25: si no se puede guardar, el pomo se queda, sale el aviso bajo la fila y el foco no se mueve',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()..error = Exception('texto-secreto');
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        final off = _knobLeft(tester);
        final focusBefore = FocusManager.instance.primaryFocus;
        await tester.tap(inSettings(find.text(_keepAwake)));
        await settleSettings(tester);
        expect(_knobLeft(tester), off);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isFalse);
        expect(
          inSettings(find.text('No se pudo guardar el ajuste.')),
          findsOneWidget,
        );
        expect(find.textContaining('texto-secreto'), findsNothing);
        expect(
          tester.getTopLeft(find.text('No se pudo guardar el ajuste.')).dy,
          greaterThan(tester.getBottomLeft(find.text(_keepAwake)).dy),
          reason: 'bajo su fila',
        );
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-21b: Intro y la barra espaciadora activan el interruptor',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(tester, keyboard: true, screenReader: true);
        // Cerrar ajustes → Idioma → Pantalla siempre activa.
        await _tab(tester);
        await _tab(tester);
        expect(focusedLabel(tester), _keepAwake);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settleSettings(tester);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await settleSettings(tester);
        expect(_toggled(tester, _keepAwakeLabel), Tristate.isFalse);
        handle.dispose();
      },
    );
  });

  group('Información y ayuda (CA-015-12a, CA-015-13a, CA-015-20e)', () {
    for (final (name, kind, address, host) in [
      (
        'Política de privacidad',
        ExternalLink.privacy,
        'https://privacy.zxq-uno.com/p',
        'privacy.zxq-uno.com',
      ),
      (
        'Licencias de terceros',
        ExternalLink.licenses,
        'https://licenses.zxq-dos.com/l',
        'licenses.zxq-dos.com',
      ),
      (
        'Ayuda',
        ExternalLink.help,
        'https://help.zxq-tres.com/h',
        'help.zxq-tres.com',
      ),
    ]) {
      testWidgets(
        'CA-015-12a ($name): canOpen y open directamente, con su dirección y sin confirmación',
        (tester) async {
          final opener = FakeOpener();
          await pumpWithApp(
            tester,
            const SettingsScreen(links: _links),
            overrides: [linkOpenerProvider.overrideWithValue(opener)],
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
          expect(opener.canOpenCalls, 1);
          expect(find.byType(LinkConfirmSheet), findsNothing);
          expect(find.textContaining(host), findsNothing);
          expect(opener.opened.map(_addressOf), [address]);
          expect(kind, isNotNull);
        },
      );

      testWidgets(
        'CA-015-12a ($name): abre directamente, sin hoja, y el foco no se mueve',
        (tester) async {
          final opener = await openSettingsScreen(tester, keyboard: true);
          final before = focusedLabel(tester);
          await tester.tap(inSettings(find.text(name)));
          await settleSettings(tester);
          expect(find.byType(LinkConfirmSheet), findsNothing);
          expect(opener.opened, hasLength(1));
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(focusedLabel(tester), before);
        },
      );

      testWidgets(
        'CA-015-20e ($name): es un botón cuyo nombre incluye que abre una página web en el navegador',
        (tester) async {
          final handle = tester.ensureSemantics();
          await openSettingsScreen(tester, screenReader: true);
          final node = tester.getSemantics(
            find.bySemanticsLabel('$name, Abre una página web en el navegador'),
          );
          expect(node.flagsCollection.isButton, isTrue);
          expect(node.getSemanticsData().hint, isEmpty);
          handle.dispose();
        },
      );
    }

    testWidgets(
      'CA-015-13a: sin direcciones propias, las tres filas usan las marcadores de la identidad (https)',
      (tester) async {
        final opener = FakeOpener();
        await pumpWithApp(
          tester,
          const SettingsScreen(),
          overrides: [linkOpenerProvider.overrideWithValue(opener)],
        );
        await tester.pumpAndSettle();
        for (final name in [
          'Política de privacidad',
          'Licencias de terceros',
          'Ayuda',
        ]) {
          await tester.tap(find.text(name));
          await tester.pumpAndSettle();
        }
        expect(opener.opened.map((t) => Uri.parse(_addressOf(t)).scheme), [
          'https',
          'https',
          'https',
        ]);
        expect(opener.opened.map((t) => Uri.parse(_addressOf(t)).host), [
          'example.com',
          'example.com',
          'example.com',
        ]);
        expect(
          opener.opened.map(_addressOf).toSet(),
          hasLength(3),
          reason: 'las tres direcciones son distintas',
        );
      },
    );
  });

  group('Lector de pantalla y teclado (CA-015-20, CA-015-21)', () {
    testWidgets(
      'CA-015-20g: título → filas en su orden visual → Cerrar ajustes (es)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(tester, screenReader: true);
        const web = 'Abre una página web en el navegador';
        final order = readingOrder(tester);
        expect(order.sublist(order.length - 8), [
          'Ajustes',
          'Idioma, Como el sistema',
          _keepAwakeLabel,
          'Información',
          'Política de privacidad, $web',
          'Licencias de terceros, $web',
          'Ayuda, $web',
          'Cerrar ajustes',
        ]);
        final title = tester.getSemantics(inSettings(find.text('Ajustes')));
        expect(title.flagsCollection.isHeader, isTrue);
        final close = tester.getSemantics(
          find.bySemanticsLabel('Cerrar ajustes'),
        );
        expect(close.flagsCollection.isButton, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-20g: en inglés todo sale en inglés (título, filas, nombre de las filas de web)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(
          tester,
          locale: const Locale('en'),
          screenReader: true,
        );
        const web = 'Opens a web page in the browser';
        final order = readingOrder(tester);
        expect(order.sublist(order.length - 8), [
          'Settings',
          'Language, Same as system',
          'Keep screen on, Images, documents and web',
          'Information',
          'Privacy policy, $web',
          'Third-party licenses, $web',
          'Help, $web',
          'Close settings',
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-20i: Ajustes es modal: ningún nodo de la tarea ni del menú de debajo es alcanzable',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openSettingsScreen(tester, screenReader: true);
        final labels = readingOrder(tester);
        for (final hidden in [
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
      'CA-015-21a/21g: el teclado empieza en Cerrar ajustes, sigue por las filas sin pasar por el título y da la vuelta con Tab y Mayús+Tab',
      (tester) async {
        await openSettingsScreen(tester, keyboard: true);
        expect(focusedLabel(tester), 'Cerrar ajustes');
        final order = <String?>[];
        for (var i = 0; i < 6; i++) {
          await _tab(tester);
          order.add(focusedLabel(tester));
        }
        expect(order, [
          'Idioma',
          _keepAwake,
          'Política de privacidad',
          'Licencias de terceros',
          'Ayuda',
          'Cerrar ajustes', // Da la vuelta dentro de Ajustes (CA-015-21g).
        ]);
        // Mayús+Tab desde Cerrar: a la última fila; y vuelve a Cerrar.
        await _tab(tester, shift: true);
        expect(focusedLabel(tester), 'Ayuda');
        await _tab(tester);
        expect(focusedLabel(tester), 'Cerrar ajustes');
        // El título nunca recibe el foco con Tab.
        for (var i = 0; i < 8; i++) {
          await _tab(tester, shift: true);
          expect(focusedLabel(tester), isNot('Ajustes'));
        }
      },
    );

    testWidgets(
      'CA-015-21b: Intro activa la fila enfocada (abre la web directamente) y el foco se queda en ella',
      (tester) async {
        final opener = await openSettingsScreen(tester, keyboard: true);
        for (var i = 0; i < 5; i++) {
          await _tab(tester);
        }
        expect(focusedLabel(tester), 'Ayuda');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settleSettings(tester);
        expect(opener.opened, hasLength(1));
        expect(find.byType(LinkConfirmSheet), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(focusedLabel(tester), 'Ayuda');
      },
    );

    testWidgets('CA-015-21b: Cerrar y las filas muestran su anillo', (
      tester,
    ) async {
      await openSettingsScreen(tester);
      for (final label in [
        'Cerrar ajustes',
        'Idioma',
        _keepAwake,
        'Política de privacidad',
        'Licencias de terceros',
        'Ayuda',
      ]) {
        expect(
          await _tabUntilRing(tester, label),
          isTrue,
          reason: 'anillo en "$label"',
        );
      }
    });

    testWidgets('CA-015-21b: con el tacto no se ve ningún anillo', (
      tester,
    ) async {
      await openSettingsScreen(tester);
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      for (final ring
          in find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(FocusRing),
              )
              .evaluate()) {
        expect((ring.widget as FocusRing).visible, isFalse);
      }
    });
  });

  group('Texto grande y movimiento (CA-015-22, CA-015-01d)', () {
    for (final (code, title, value, noApp, saveError) in [
      (
        'es',
        'Ajustes',
        'Como el sistema',
        'No hay ninguna app para abrir este enlace.',
        'No se pudo guardar el ajuste.',
      ),
      (
        'en',
        'Settings',
        'Same as system',
        "There's no app to open this link.",
        "Couldn't save the setting.",
      ),
    ]) {
      testWidgets(
        'CA-015-22 ($code): al 200 % a 360 dp no hay desbordamientos, el valor de "Idioma" pasa a una segunda línea y los objetivos miden ≥ 44 (también con los dos avisos)',
        (tester) async {
          final handle = tester.ensureSemantics();
          final opener = FakeOpener()..available = false;
          final repo = SettingsRepo()..error = Exception('x');
          await openSettingsScreen(
            tester,
            locale: Locale(code),
            textScale: 2,
            size: const Size(360, 640),
            opener: opener,
            repo: repo,
          );
          final en = code == 'en';
          await tester.tap(
            inSettings(find.text(en ? 'Keep screen on' : _keepAwake)),
          );
          await settleSettings(tester);
          final help = inSettings(find.text(en ? 'Help' : 'Ayuda'));
          await tester.ensureVisible(help);
          await tester.pumpAndSettle();
          await tester.tap(help);
          await settleSettings(tester);
          expect(tester.takeException(), isNull);
          expect(inSettings(find.text(title)), findsOneWidget);
          expect(inSettings(find.text(noApp)), findsOneWidget);
          expect(inSettings(find.text(saveError)), findsOneWidget);
          // El valor de "Idioma" baja bajo el nombre sin recortarse.
          final name = en ? 'Language' : 'Idioma';
          expect(
            tester.getTopLeft(inSettings(find.text(value))).dy,
            greaterThanOrEqualTo(
              tester.getBottomLeft(inSettings(find.text(name))).dy - 1,
            ),
            reason: 'segunda línea',
          );
          final close = tester.getSize(find.byType(SquareIconButton));
          expect(close.width, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          expect(close.height, greaterThanOrEqualTo(UnaSizes.minTouchTarget));
          // Ninguna palabra se parte (como CA-001-07): la más larga cabe.
          final screen = tester.getRect(find.byType(SettingsScreen));
          for (final text in [title, name, value, noApp, saveError]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              inSettings(find.text(text)).first,
            );
            expect(
              paragraph.getMinIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason: 'se parte una palabra de "$text"',
            );
            final rect = tester.getRect(inSettings(find.text(text)).first);
            expect(rect.left, greaterThanOrEqualTo(screen.left));
            expect(rect.right, lessThanOrEqualTo(screen.right));
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        },
      );
    }

    // 640 es el caso normal; 480, una pantalla corta en la que el contenido se
    // desplaza y el final debe librar la barra del sistema.
    for (final height in [640.0, 480.0]) {
      testWidgets(
        'CA-015-22: con la barra del sistema (48 dp abajo) al 200 % a 360x${height.toInt()}, el aviso del final queda por encima de ella',
        (tester) async {
          const inset = 48.0;
          final opener = FakeOpener()..available = false;
          await openSettingsScreen(
            tester,
            textScale: 2,
            size: const Size(360, 640),
            bottomInset: inset,
            opener: opener,
          );
          // Se abre en 640 (el menú debe caber) y luego se acorta.
          tester.view.physicalSize = Size(360, height);
          await tester.pumpAndSettle();
          await tester.ensureVisible(inSettings(find.text('Ayuda')));
          await tester.pumpAndSettle();
          await tester.tap(inSettings(find.text('Ayuda')));
          await settleSettings(tester);
          await tester.drag(
            find.descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(SingleChildScrollView),
            ),
            const Offset(0, -3000),
          );
          await settleSettings(tester);
          expect(
            tester
                .getRect(
                  inSettings(
                    find.text('No hay ninguna app para abrir este enlace.'),
                  ),
                )
                .bottom,
            lessThanOrEqualTo(height - inset),
            reason: 'el último elemento queda por encima de la barra',
          );
        },
      );
    }

    for (final height in [640.0, 480.0]) {
      testWidgets(
        'CA-015-12b/21f: con la barra del sistema (48 dp abajo) al 200 % a 360x${height.toInt()}, el aviso que aparece se desplaza a la vista por encima de ella (sin arrastrar)',
        (tester) async {
          const inset = 48.0;
          final opener = FakeOpener()..available = false;
          await openSettingsScreen(
            tester,
            textScale: 2,
            size: const Size(360, 640),
            bottomInset: inset,
            opener: opener,
          );
          tester.view.physicalSize = Size(360, height);
          await tester.pumpAndSettle();
          await tester.ensureVisible(inSettings(find.text('Ayuda')));
          await tester.pumpAndSettle();
          await tester.tap(inSettings(find.text('Ayuda')));
          await settleSettings(tester);
          expect(
            tester
                .getRect(
                  inSettings(
                    find.text('No hay ninguna app para abrir este enlace.'),
                  ),
                )
                .bottom,
            lessThanOrEqualTo(height - inset),
            reason: 'el aviso no queda bajo la barra de navegación',
          );
        },
      );
    }

    testWidgets(
      'CA-015-01d: Ajustes sube en 200 ms y baja en 160 ms; el nivel 2 es un fundido de 160 ms',
      (tester) async {
        await openSettingsScreen(tester);
        final route = ModalRoute.of(
          tester.element(find.byType(SettingsScreen)),
        )!;
        expect(route.transitionDuration, UnaMotion.sheetIn);
        expect(route.reverseTransitionDuration, UnaMotion.sheetOut);
        expect(route.opaque, isTrue);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        final page = ModalRoute.of(tester.element(find.byType(LanguagePage)))!;
        expect(page.transitionDuration, UnaMotion.sheetOut);
        expect(page.reverseTransitionDuration, UnaMotion.sheetOut);
      },
    );

    testWidgets('CA-015-01d: con reducir movimiento no hay animación', (
      tester,
    ) async {
      await openSettingsScreen(tester, reduced: true);
      final route = ModalRoute.of(tester.element(find.byType(SettingsScreen)))!;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      await tester.tap(inSettings(find.text('Idioma')));
      await settleSettings(tester);
      final page = ModalRoute.of(tester.element(find.byType(LanguagePage)))!;
      expect(page.transitionDuration, Duration.zero);
      expect(page.reverseTransitionDuration, Duration.zero);
    });

    testWidgets(
      'CA-015-01a: sin reducir movimiento, a mitad de la subida la pantalla aún está desplazada hacia abajo',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final top = tester.getTopLeft(find.byType(SettingsScreen)).dy;
        expect(top, greaterThan(0));
        expect(top, lessThan(tester.view.physicalSize.height));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(SettingsScreen)).dy, 0);
      },
    );
  });

  group('Cambia el ajuste, cambia la app (CA-015-04, CA-015-08)', () {
    testWidgets(
      'CA-015-03: el interruptor lee el controlador: lo que cambia el controlador se ve en la pantalla',
      (tester) async {
        await openSettingsScreen(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        final off = _knobLeft(tester);
        await container.read(settingsProvider.notifier).setKeepScreenOn(true);
        await tester.pumpAndSettle();
        expect(_knobLeft(tester), greaterThan(off));
      },
    );
  });
}

class _LocaleFailingRepo extends InMemoryTaskRepository {
  @override
  Future<void> setLocale(LocaleChoice choice) async =>
      throw StateError('texto-secreto');
}

/// Pulsa Tab hasta que el control [label] muestra su anillo.
Future<bool> _tabUntilRing(
  WidgetTester tester,
  String label, {
  int maxTabs = 20,
}) async {
  final ring = find.descendant(
    of: find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label == label ||
              (w.properties.label?.startsWith('$label,') ?? false)),
    ),
    matching: find.byType(FocusRing),
  );
  for (var i = 0; i < maxTabs; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (ring.evaluate().isNotEmpty &&
        tester.widget<FocusRing>(ring.first).visible) {
      return true;
    }
  }
  return false;
}
