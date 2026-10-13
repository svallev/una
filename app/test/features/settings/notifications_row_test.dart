import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/features/settings/notifications_block.dart';
import 'package:app/features/settings/notifications_state.dart';
import 'package:app/ui/live_region_announcer.dart';
import 'package:app/ui/una_icons.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import 'settings_harness.dart';

/// La fila de Notificaciones y sus opciones en Ajustes (spec 019, T-019-10):
/// orden y separadores (CA-019-01), interruptor sin cambio optimista
/// (CA-019-02), acordeón 1·2·3 (CA-019-03), ayuda con las horas (CA-019-04) y
/// plataformas (CA-019-28).

const _privacyEs =
    'La notificación muestra tu tarea actual. Con el móvil bloqueado también '
    'se ve, salvo que ocultes el contenido sensible en los ajustes de tu móvil.';

final _block = find.byType(NotificationsBlock);

Finder _inBlock(Finder f) => find.descendant(of: _block, matching: f);

Finder _option(NotificationsPerDay v) =>
    find.byKey(NotificationsBlock.optionKey(v));

Finder get _switchRow => _inBlock(find.byType(UnaSwitchRow));

/// Deja correr el guardado (microtareas) y el despliegue o repliegue del
/// acordeón (240 ms).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _open(
  WidgetTester tester, {
  FakeNotificationGateway? gateway,
  SettingsRepo? repo,
  bool flag = true,
  bool platform = true,
  Locale locale = const Locale('es'),
  bool reduced = false,
  bool keyboard = false,
}) => openSettingsScreen(
  tester,
  locale: locale,
  repo: repo,
  reduced: reduced,
  keyboard: keyboard,
  overrides: notificationsOverrides(
    gateway: gateway,
    flag: flag,
    platform: platform,
  ),
);

Future<SettingsRepo> _repoWith({
  bool on = false,
  NotificationsPerDay perDay = NotificationsPerDay.one,
}) async {
  final repo = SettingsRepo();
  if (on) await repo.setNotificationsOn(true);
  await repo.setNotificationsPerDay(perDay);
  return repo;
}

Tristate _toggled(WidgetTester tester, [String label = 'Notificaciones']) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .getSemanticsData()
        .flagsCollection
        .isToggled;

double _knobX(WidgetTester tester) =>
    tester.getTopLeft(_inBlock(find.byKey(UnaSwitchRow.knobKey))).dx;

Finder get _blockSeparators => inSettings(
  find.byWidgetPredicate(
    (w) =>
        w is SizedBox &&
        w.height == UnaSizes.separatorBlock &&
        w.child is ColoredBox,
  ),
);

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('CA-019-01 y CA-019-28: dónde está la fila', () {
    testWidgets(
      'CA-019-01: debajo de Idioma, en su bloque; luego Pantalla siempre '
      'activa, Bloquear zoom e Información, con dos separadores de bloque',
      (tester) async {
        await _open(tester);
        double top(Finder f) => tester.getTopLeft(f).dy;
        final language = top(inSettings(find.text('Idioma')));
        final notifications = top(_inBlock(find.text('Notificaciones')));
        final privacy = tester.getRect(_inBlock(find.text(_privacyEs)));
        final keepAwake = top(inSettings(find.text('Pantalla siempre activa')));
        final lockZoom = top(inSettings(find.text('Bloquear zoom')));
        final info = top(inSettings(find.text('Información')));
        expect(language, lessThan(notifications));
        expect(notifications, lessThan(privacy.top));
        expect(privacy.bottom, lessThan(keepAwake));
        expect(keepAwake, lessThan(lockZoom));
        expect(lockZoom, lessThan(info));

        // Exactamente dos separadores de bloque (la fila no añade uno): el
        // primero entre Notificaciones y Pantalla siempre activa.
        expect(_blockSeparators, findsNWidgets(2));
        final first = tester.getRect(_blockSeparators.at(0));
        final second = tester.getRect(_blockSeparators.at(1));
        expect(first.top, greaterThan(privacy.bottom));
        expect(first.bottom, lessThan(keepAwake));
        expect(second.top, greaterThan(lockZoom));
        expect(second.bottom, lessThan(info));
      },
    );

    testWidgets('CA-019-01: el separador de 1 px va sobre la fila, la campana es '
        'decorativa y toda la fila es zona táctil de ≥ 48', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      expect(tester.widget<UnaSwitchRow>(_switchRow).divider, isTrue);
      final bell = _inBlock(
        find.byWidgetPredicate((w) => w is UnaIcon && w.icon == UnaIcons.bell),
      );
      expect(bell, findsOneWidget);
      // La campana no pone nada en el árbol del lector: un solo nodo, el de la
      // fila, con el nombre «Notificaciones» y sin etiqueta de icono.
      expect(find.bySemanticsLabel('Notificaciones'), findsOneWidget);
      final rect = tester.getRect(_switchRow);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));
      // La fila ocupa el ancho del bloque, no solo el interruptor.
      expect(rect.width, greaterThan(300));
      handle.dispose();
    });

    testWidgets('CA-019-28: con el indicador apagado no hay fila ni línea de '
        'privacidad y Ajustes queda como en la 017', (tester) async {
      await _open(tester, flag: false);
      expect(_block, findsNothing);
      expect(inSettings(find.text('Notificaciones')), findsNothing);
      expect(find.text(_privacyEs), findsNothing);
      expect(_blockSeparators, findsNWidgets(2));
      // Idioma queda al final de su bloque: sin separador ni hueco de más
      // (respiro del bloque de 14 entre la fila y el separador).
      final language = tester.getRect(inSettings(find.text('Idioma')));
      final separator = tester.getRect(_blockSeparators.first);
      expect(
        separator.top - language.bottom,
        lessThan(UnaSizes.settingsRow),
        reason: 'ninguna fila entre Idioma y el separador',
      );
    });

    testWidgets('CA-019-28: en la web o en iOS (plataforma no admitida) no hay '
        'fila aunque el indicador esté encendido', (tester) async {
      await _open(tester, platform: false);
      expect(_block, findsNothing);
      expect(inSettings(find.text('Notificaciones')), findsNothing);
      expect(_blockSeparators, findsNWidgets(2));
    });

    testWidgets('CA-019-28: en Android con el indicador encendido sí está', (
      tester,
    ) async {
      await _open(tester);
      expect(_block, findsOneWidget);
    });
  });

  group('CA-019-02: el interruptor', () {
    testWidgets(
      'CA-019-02: apagado por defecto, con el nombre «Notificaciones» '
      'y la línea de privacidad a la vista',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester);
        expect(_toggled(tester), Tristate.isFalse);
        expect(_inBlock(find.text(_privacyEs)), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('CA-019-02: tocar enciende y el interruptor NO se mueve hasta '
        'terminar (sin cambio optimista); luego se guarda y se despliega', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway()..configureGate = gate;
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo);
      final off = _knobX(tester);

      await tester.tap(_switchRow);
      await _settle(tester);
      // `configure` está en vuelo: nada ha cambiado de cara al usuario.
      expect(gateway.configureCalls, hasLength(1));
      expect(gateway.configureCalls.single.on, isTrue);
      expect(_toggled(tester), Tristate.isFalse);
      expect(_knobX(tester), off);
      expect(_option(NotificationsPerDay.one), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(_toggled(tester), Tristate.isTrue);
      expect(_knobX(tester), isNot(off));
      expect(await repo.notificationsOn(), isTrue);
      expect(_option(NotificationsPerDay.one), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CA-019-02: un segundo toque mientras la fila trabaja se '
        'ignora', (tester) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway()..configureGate = gate;
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      gate.complete();
      await _settle(tester);
      expect(gateway.configureCalls, hasLength(1));
      expect(gateway.requestPermissionCalls, 0);
    });

    testWidgets('CA-019-02: apagar guarda, avisa a lo nativo y pliega las '
        'opciones', (tester) async {
      final gateway = FakeNotificationGateway();
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.two);
      await _open(tester, gateway: gateway, repo: repo);
      expect(_option(NotificationsPerDay.two), findsOneWidget);

      await tester.tap(_switchRow);
      await _settle(tester);
      expect(gateway.configureCalls.single.on, isFalse);
      expect(await repo.notificationsOn(), isFalse);
      expect(_option(NotificationsPerDay.two), findsNothing);
      // La cantidad elegida se conserva con el ajuste apagado (CA-019-05).
      expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
    });

    testWidgets('CA-019-02: todo o nada: si falla la programación, el '
        'interruptor se queda apagado y el valor guardado se deshace', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway()
        ..configureFailure = const NotificationGatewayException();
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_toggled(tester), Tristate.isFalse);
      expect(await repo.notificationsOn(), isFalse);
      expect(_option(NotificationsPerDay.one), findsNothing);
      handle.dispose();
    });

    testWidgets('CA-019-02, CA-019-09: con el ajuste guardado encendido y el '
        'sistema bloqueando, se ve apagado y sin opciones y lo guardado '
        'queda intacto; al permitirlo vuelve a verse encendido', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.three);
      await _open(tester, repo: repo);
      expect(_toggled(tester), Tristate.isTrue);

      final system = appContainer(tester)
          .read(systemAllowsNotificationsProvider.notifier);
      system.setAllowed(false);
      await _settle(tester);
      expect(_toggled(tester), Tristate.isFalse);
      expect(_option(NotificationsPerDay.three), findsNothing);
      expect(_inBlock(find.text(_privacyEs)), findsOneWidget);
      expect(await repo.notificationsOn(), isTrue);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);

      system.setAllowed(true);
      await _settle(tester);
      expect(_toggled(tester), Tristate.isTrue);
      expect(_option(NotificationsPerDay.three), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CA-019-02, CA-019-09: tocar el interruptor que se ve apagado '
        'por el bloqueo intenta encender (pide el permiso), no apaga lo '
        'guardado', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      appContainer(tester)
          .read(systemAllowsNotificationsProvider.notifier)
          .setAllowed(false);
      await _settle(tester);

      await tester.tap(_switchRow);
      await _settle(tester);
      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.configureCalls, isEmpty);
      expect(await repo.notificationsOn(), isTrue);
    });
  });

  group('CA-019-03: las opciones 1·2·3', () {
    testWidgets('CA-019-03: apagado, ni las opciones ni la ayuda están en el '
        'árbol ni en la semántica', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      for (final v in NotificationsPerDay.values) {
        expect(_option(v), findsNothing);
      }
      expect(find.text('NOTIFICACIONES AL DÍA'), findsNothing);
      expect(find.bySemanticsLabel('1 notificación al día'), findsNothing);
      expect(find.bySemanticsLabel('Notificaciones al día'), findsNothing);
      expect(_inBlock(find.textContaining('será a las')), findsNothing);
      expect(_inBlock(find.byType(ExcludeFocus)), findsNothing);
      handle.dispose();
    });

    testWidgets('CA-019-03: encendido, tres opciones de igual ancho; la 1, '
        'marcada, con la marca de selección y el relleno amarillo', (
      tester,
    ) async {
      final repo = await _repoWith(on: true);
      await _open(tester, repo: repo);
      expect(find.text('NOTIFICACIONES AL DÍA'), findsOneWidget);
      final one = tester.getRect(_option(NotificationsPerDay.one));
      final two = tester.getRect(_option(NotificationsPerDay.two));
      final three = tester.getRect(_option(NotificationsPerDay.three));
      expect(two.width, closeTo(one.width, 0.01));
      expect(three.width, closeTo(one.width, 0.01));
      expect(two.left, closeTo(one.right, 0.01));
      expect(three.left, closeTo(two.right, 0.01));

      // Una sola marca, en la marcada.
      expect(find.byKey(NotificationsBlock.markKey), findsOneWidget);
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.one),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      // Y el relleno amarillo del prototipo, solo bajo la marcada.
      final yellow =
          _inBlock(
                find.byWidgetPredicate(
                  (w) =>
                      w is DecoratedBox &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color ==
                          UnaColors.switchOn,
                ),
              )
              .evaluate()
              .map(
                (e) => tester.getRect(find.byElementPredicate((x) => x == e)),
              )
              .where((r) => r.width != UnaSizes.switchWidth)
              .toList();
      expect(yellow, hasLength(1));
      expect(yellow.single.center.dx, closeTo(one.center.dx, 2));
    });

    testWidgets('CA-019-03: el relleno solo se ve en la marcada y el número en '
        'negrita 900 frente a 600', (tester) async {
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.two);
      await _open(tester, repo: repo);
      FontWeight? weight(String n) => tester
          .widget<Text>(
            find.descendant(
              of: _option(NotificationsPerDay.values[int.parse(n) - 1]),
              matching: find.text(n),
            ),
          )
          .style
          ?.fontWeight;
      expect(weight('2'), FontWeight.w900);
      expect(weight('1'), FontWeight.w600);
      expect(weight('3'), FontWeight.w600);
    });

    testWidgets('CA-019-03: medidas: caja visible de ≥ 44 con borde de tinta '
        'de 3 y esquinas de 8; zona táctil de ≥ 48', (tester) async {
      final repo = await _repoWith(on: true);
      await _open(tester, repo: repo);
      for (final v in NotificationsPerDay.values) {
        final rect = tester.getRect(_option(v));
        expect(rect.height, greaterThanOrEqualTo(48), reason: '${v.count}');
        expect(rect.width, greaterThanOrEqualTo(48), reason: '${v.count}');
      }
      final frame = _inBlock(
        find.byWidgetPredicate(
          (w) => w is Container && w.clipBehavior == Clip.antiAlias,
        ),
      );
      expect(frame, findsOneWidget);
      expect(
        tester.getSize(frame).height,
        greaterThanOrEqualTo(UnaSizes.minTouchTarget),
      );
      final decoration =
          tester.widget<Container>(frame).decoration! as BoxDecoration;
      expect(
        decoration.border,
        const Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
        ),
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(UnaBorders.optionGroupRadius),
      );
    });

    testWidgets('CA-019-03: tocar una opción: la marca NO se mueve hasta '
        'terminar; luego se guarda y se avisa a lo nativo', (tester) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway()..configureGate = gate;
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);

      await tester.tap(_option(NotificationsPerDay.three));
      await _settle(tester);
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.one),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      expect(gateway.configureCalls.single.perDay, NotificationsPerDay.three);
      expect(gateway.configureCalls.single.on, isTrue);

      gate.complete();
      await _settle(tester);
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.three),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      expect(find.byKey(NotificationsBlock.markKey), findsOneWidget);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
    });

    testWidgets('CA-019-03: un toque en la ya marcada no hace nada', (
      tester,
    ) async {
      final gateway = FakeNotificationGateway();
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      await tester.tap(_option(NotificationsPerDay.one));
      await _settle(tester);
      expect(gateway.configureCalls, isEmpty);
    });

    testWidgets('CA-019-03: 3 y enseguida 2: se aplican una tras otra y gana '
        'la última', (tester) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway()..configureGate = gate;
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);

      await tester.tap(_option(NotificationsPerDay.three));
      await tester.pump();
      await tester.tap(_option(NotificationsPerDay.two));
      await tester.pump();
      gate.complete();
      await _settle(tester);
      await _settle(tester);

      expect(gateway.configureCalls.last.perDay, NotificationsPerDay.two);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.two),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      expect(find.byKey(NotificationsBlock.markKey), findsOneWidget);
    });

    testWidgets('CA-019-03: encender despliega sin mover el foco del '
        'interruptor', (tester) async {
      await _open(tester, keyboard: true);
      final node = tester.widget<UnaSwitchRow>(_switchRow).focusNode!;
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(_option(NotificationsPerDay.one), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, node);
    });

    testWidgets('CA-019-03: con «reducir movimiento» las opciones aparecen y '
        'desaparecen sin ningún fotograma de animación', (tester) async {
      final repo = await _repoWith();
      await _open(tester, reduced: true, repo: repo);

      await tester.tap(_switchRow);
      await tester.pump(); // El guardado.
      await tester.pump(); // El cambio de estado ya está dibujado.
      expect(_option(NotificationsPerDay.one), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      // A su tamaño final de golpe.
      expect(
        tester.getSize(_option(NotificationsPerDay.one)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(_switchRow);
      await tester.pump();
      await tester.pump();
      expect(_option(NotificationsPerDay.one), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('CA-019-03: sin «reducir movimiento» el despliegue sí se '
        'anima (la altura crece con los fotogramas)', (tester) async {
      await _open(tester);
      await tester.tap(_switchRow);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final partial = tester.getSize(_block).height;
      await tester.pump(const Duration(milliseconds: 400));
      final full = tester.getSize(_block).height;
      expect(partial, lessThan(full));
    });

    testWidgets('CA-019-03: mientras se pliega, las opciones ya no están para '
        'el lector ni para el teclado ni para el toque', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await _repoWith(on: true);
      await _open(tester, repo: repo);
      expect(find.bySemanticsLabel('1 notificación al día'), findsOneWidget);

      await tester.tap(_switchRow);
      await tester.pump(); // El guardado y el primer fotograma del repliegue.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // A medias: aún se construyen, pero no se ven para el lector…
      expect(_option(NotificationsPerDay.one), findsOneWidget);
      final labels = readingOrder(tester);
      expect(labels, isNot(contains('1 notificación al día')));
      expect(labels, isNot(contains('Notificaciones al día')));
      expect(labels, contains('Notificaciones'));
      // …ni se alcanzan con el teclado ni con el toque.
      expect(
        tester
            .widget<ExcludeFocus>(_inBlock(find.byType(ExcludeFocus)))
            .excluding,
        isTrue,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              _inBlock(
                find.ancestor(
                  of: _option(NotificationsPerDay.one),
                  matching: find.byType(IgnorePointer),
                ),
              ).first,
            )
            .ignoring,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(_option(NotificationsPerDay.one), findsNothing);
      handle.dispose();
    });
  });

  group('CA-019-04: la ayuda con las horas', () {
    const es = {
      NotificationsPerDay.one: 'La notificación será a las 08:55.',
      NotificationsPerDay.two:
          'Las notificaciones serán a las 08:55 y a las 13:55.',
      NotificationsPerDay.three:
          'Las notificaciones serán a las 08:55, a las 13:55 y a las 18:55.',
    };
    const en = {
      NotificationsPerDay.one: 'The notification will be at 08:55.',
      NotificationsPerDay.two: 'The notifications will be at 08:55 and 13:55.',
      NotificationsPerDay.three:
          'The notifications will be at 08:55, 13:55 and 18:55.',
    };

    for (final h24 in [false, true]) {
      for (final (locale, texts) in [
        (const Locale('es'), es),
        (const Locale('en'), en),
      ]) {
        for (final v in NotificationsPerDay.values) {
          testWidgets('CA-019-04: la ayuda de la opción ${v.count} en '
              '${locale.languageCode}, con el formato del sistema en '
              '${h24 ? 24 : 12} h (siempre en 24 h)', (tester) async {
            tester.platformDispatcher.alwaysUse24HourFormatTestValue = h24;
            addTearDown(
              tester.platformDispatcher.clearAlwaysUse24HourTestValue,
            );
            final repo = await _repoWith(on: true, perDay: v);
            await _open(tester, repo: repo, locale: locale);
            expect(_inBlock(find.text(texts[v]!)), findsOneWidget);
            // Nada de «a. m.», «p. m.» ni «am»/«pm».
            expect(
              find.textContaining(
                RegExp(r'\b[ap]\.? ?m\b', caseSensitive: false),
              ),
              findsNothing,
            );
          });
        }
      }
    }

    /// Cuenta cada frase que dice la región viva del bloque.
    List<String> recordAnnouncements(WidgetTester tester) {
      final said = <String>[];
      final announcer = tester
          .widget<LiveRegionNode>(find.byType(LiveRegionNode))
          .announcer;
      announcer.message.addListener(() {
        if (announcer.message.value.isNotEmpty) {
          said.add(announcer.message.value);
        }
      });
      return said;
    }

    testWidgets('CA-019-04: desplegar con el interruptor NO anuncia nada y '
        'cambiar de opción anuncia la ayuda una sola vez, con la última si '
        'hay varios cambios seguidos', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      final said = recordAnnouncements(tester);

      await tester.tap(_switchRow);
      await _settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'desplegar no anuncia');

      await tester.tap(_option(NotificationsPerDay.three));
      await _settle(tester);
      await tester.pump(DebouncedAnnouncer.debounce);
      expect(said, [es[NotificationsPerDay.three]]);
      // La región viva lo lleva como etiqueta y no es una parada de foco.
      final node = tester.getSemantics(
        find.descendant(
          of: find.byType(LiveRegionNode),
          matching: find.byType(SizedBox),
        ),
      );
      final data = node.getSemanticsData();
      expect(data.label, es[NotificationsPerDay.three]);
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.flagsCollection.isFocused, Tristate.none);
      expect(data.hasAction(SemanticsAction.tap), isFalse);

      // Se vacía solo, para poder repetir la frase.
      await tester.pump(LiveRegionAnnouncer.clearAfter);
      expect(
        tester
            .widget<LiveRegionNode>(find.byType(LiveRegionNode))
            .announcer
            .message
            .value,
        isEmpty,
      );

      // La línea de privacidad no se relee al cambiar de opción.
      await tester.tap(_option(NotificationsPerDay.two));
      await _settle(tester);
      await tester.pump(DebouncedAnnouncer.debounce);
      expect(said, [
        es[NotificationsPerDay.three],
        es[NotificationsPerDay.two],
      ]);
      expect(said.join(), isNot(contains('bloqueado')));
      handle.dispose();
    });

    testWidgets('CA-019-04: la región viva nace vacía: al abrir Ajustes con '
        'las opciones ya desplegadas no dice nada', (tester) async {
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.two);
      await _open(tester, repo: repo);
      final said = recordAnnouncements(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(said, isEmpty);
      expect(
        tester
            .widget<LiveRegionNode>(find.byType(LiveRegionNode))
            .announcer
            .message
            .value,
        isEmpty,
      );
    });
  });
}
