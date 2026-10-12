import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/features/settings/notifications_block.dart';
import 'package:app/features/settings/notifications_state.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/live_notice.dart';
import 'package:app/ui/live_region_announcer.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';
import '../../support/fonts.dart';
import 'settings_harness.dart';

/// Los avisos del bloque de Notificaciones (spec 019, T-019-11): el de
/// **bloqueo** con su botón (CA-019-08), el reflejo de lo que permite el
/// sistema (CA-019-09), el permiso al encender (CA-019-07) y el aviso de
/// **error** de guardado como una fila de la cola (CA-019-06); su semántica,
/// anuncios y foco (CA-019-26).

const _blocked =
    'Las notificaciones están bloqueadas en los Ajustes del sistema.';
const _openSystem = 'Abrir los ajustes de notificaciones';
const _openError = 'No se pudieron abrir los Ajustes del sistema.';
const _enabled = 'Notificaciones activadas.';
const _allowed = 'Notificaciones permitidas.';
const _allowedOn = 'Notificaciones permitidas y activadas.';
const _saveError = 'No se pudo guardar el ajuste.';
const _privacyEs =
    'La notificación muestra tu tarea actual. Con el móvil bloqueado también '
    'se ve, salvo que ocultes el contenido sensible en los ajustes de tu móvil.';

final _block = find.byType(NotificationsBlock);

Finder _inBlock(Finder f) => find.descendant(of: _block, matching: f);

Finder get _switchRow => _inBlock(find.byType(UnaSwitchRow));
Finder get _blockedText => _inBlock(find.text(_blocked));
Finder get _button => _inBlock(find.byType(UnaLinkButton));
Finder _option(NotificationsPerDay v) =>
    find.byKey(NotificationsBlock.optionKey(v));

/// Los avisos de error del bloque y de Pantalla siempre activa son
/// `LiveNotice` con este texto.
Finder get _saveNotices =>
    inSettings(find.widgetWithText(LiveNotice, _saveError));

/// Deja correr el guardado (microtareas) y el despliegue o repliegue del
/// acordeón (240 ms).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pasa el tiempo en pasos cortos (el aviso y su vaciado van en un
/// fotograma cada uno).
Future<void> _wait(WidgetTester tester, Duration total) async {
  var left = total;
  const step = Duration(milliseconds: 16);
  while (left > Duration.zero) {
    await tester.pump(step);
    left -= step;
  }
}

/// Manda la app a segundo plano y la trae de vuelta (lo que pasa al ir a los
/// Ajustes del sistema y volver): cada paso es una transición válida.
Future<void> _backgroundAndBack(WidgetTester tester) async {
  final binding = tester.binding;
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(s);
  }
  // Fotograma a fotograma: el foco y el anuncio dependen de su orden.
  await _wait(tester, const Duration(milliseconds: 500));
}

Future<FakeOpener> _open(
  WidgetTester tester, {
  FakeNotificationGateway? gateway,
  SettingsRepo? repo,
  Locale locale = const Locale('es'),
  bool screenReader = false,
  bool keyboard = false,
  double textScale = 1.0,
}) => openSettingsScreen(
  tester,
  locale: locale,
  repo: repo,
  screenReader: screenReader,
  keyboard: keyboard,
  textScale: textScale,
  overrides: notificationsOverrides(gateway: gateway),
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

/// Un repositorio cuyo guardado de Notificaciones falla con un texto que nadie
/// debe ver.
class _FailingRepo extends SettingsRepo {
  bool failing = true;

  @override
  Future<void> setNotificationsOn(bool value) async {
    if (failing) throw Exception('texto-secreto');
    await super.setNotificationsOn(value);
  }

  @override
  Future<void> setNotificationsPerDay(NotificationsPerDay value) async {
    if (failing) throw Exception('texto-secreto');
    await super.setNotificationsPerDay(value);
  }
}

Tristate _toggled(WidgetTester tester, [String label = 'Notificaciones']) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .getSemanticsData()
        .flagsCollection
        .isToggled;

/// Cada frase que dice la región viva del bloque (se llama tras abrir).
List<String> _recordAnnouncements(WidgetTester tester) {
  final said = <String>[];
  final announcer = tester
      .widget<LiveRegionNode>(find.byType(LiveRegionNode))
      .announcer;
  announcer.message.addListener(() {
    if (announcer.message.value.isNotEmpty) said.add(announcer.message.value);
  });
  return said;
}

bool _switchHasFocus(WidgetTester tester) =>
    tester.widget<UnaSwitchRow>(_switchRow).focusNode!.hasPrimaryFocus;

/// Da el foco de teclado al control que contiene el texto [text].
Future<void> _focus(WidgetTester tester, Finder text) async {
  Focus.of(tester.element(text)).requestFocus();
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('CA-019-08: bloqueadas al encender', () {
    testWidgets('CA-019-08: el diálogo se rechaza: el interruptor se queda '
        'apagado, no se guarda ni se programa nada, sale el aviso con su '
        'botón y se anuncia una vez sin mover el foco', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo, keyboard: true);
      final said = _recordAnnouncements(tester);
      expect(_blockedText, findsNothing);
      await _focus(tester, _inBlock(find.text('Notificaciones')));
      final focused = FocusManager.instance.primaryFocus;

      await tester.tap(_switchRow);
      await _settle(tester);
      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.configureCalls, isEmpty);
      expect(await repo.notificationsOn(), isFalse);
      expect(_toggled(tester), Tristate.isFalse);
      expect(_blockedText, findsOneWidget);
      expect(_button, findsOneWidget);
      expect(find.bySemanticsLabel(_openSystem), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focused));

      await _wait(tester, const Duration(seconds: 1));
      expect(said, [_blocked]);
      handle.dispose();
    });

    testWidgets('CA-019-08: el sistema rechaza sin mostrar el diálogo (o las '
        'notificaciones de la app están apagadas): mismo aviso', (
      tester,
    ) async {
      for (final permission in [
        FakePermission.deniedImmediately,
        // Android 12: no hay diálogo y el canal está apagado.
        FakePermission.granted,
      ]) {
        final gateway = FakeNotificationGateway(permission)..allowed = false;
        final repo = await _repoWith();
        await _open(tester, gateway: gateway, repo: repo);
        await tester.tap(_switchRow);
        await _settle(tester);
        expect(_blockedText, findsOneWidget, reason: '$permission');
        expect(_button, findsOneWidget, reason: '$permission');
        expect(gateway.configureCalls, isEmpty, reason: '$permission');
        expect(await repo.notificationsOn(), isFalse, reason: '$permission');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('CA-019-08: el aviso no es un LiveNotice ni una región viva, '
        'va tras la línea de privacidad y se anuncia por el anunciador', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_inBlock(find.byType(LiveNotice)), findsNothing);
      final data = tester.getSemantics(_blockedText).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isFalse);
      expect(data.label, _blocked);
      final privacy = tester.getRect(_inBlock(find.text(_privacyEs)));
      expect(tester.getRect(_blockedText).top, greaterThan(privacy.bottom));
      expect(
        tester.getRect(_button).top,
        greaterThan(tester.getRect(_blockedText).bottom - 1),
      );
      handle.dispose();
    });

    testWidgets(
      'CA-019-08: cada intento rechazado vuelve a anunciar el aviso',
      (tester) async {
        final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
        await _open(tester, gateway: gateway);
        final said = _recordAnnouncements(tester);
        await tester.tap(_switchRow);
        await _settle(tester);
        await _wait(tester, const Duration(seconds: 3));
        await tester.tap(_switchRow);
        await _settle(tester);
        await _wait(tester, const Duration(seconds: 3));
        expect(gateway.requestPermissionCalls, 2);
        expect(said, [_blocked, _blocked]);
        expect(_blockedText, findsOneWidget);
      },
    );

    testWidgets('CA-019-08: el botón pide abrir los ajustes del sistema una '
        'vez por toque, con su nombre, ≥ 44 y alcanzable con el teclado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway, keyboard: true);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(gateway.openSystemSettingsCalls, 0);

      final size = tester.getSize(_button);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
      final node = tester.getSemantics(find.bySemanticsLabel(_openSystem));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);

      await tester.tap(_button);
      await _settle(tester);
      expect(gateway.openSystemSettingsCalls, 1);
      await tester.tap(_button);
      await _settle(tester);
      expect(gateway.openSystemSettingsCalls, 2);

      // Con el teclado: se le da el foco (Tab llega: es una parada) y Intro lo
      // activa.
      await _focus(tester, _inBlock(find.text(_openSystem)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(gateway.openSystemSettingsCalls, 3);
      handle.dispose();
    });

    testWidgets('CA-019-08: varios toques seguidos mientras se abre piden una '
        'sola vez', (tester) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied)
        ..openSettingsGate = gate;
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      await tester.tap(_button);
      await tester.pump();
      await tester.tap(_button);
      await tester.pump();
      expect(gateway.openSystemSettingsCalls, 1);
      gate.complete();
      await _settle(tester);
      await tester.tap(_button);
      await _settle(tester);
      expect(gateway.openSystemSettingsCalls, 2);
    });

    testWidgets('CA-019-08: si no hay a dónde ir, sale «No se pudieron abrir '
        'los Ajustes del sistema.» tras el botón, como región viva, y se '
        'repite en cada intento', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied)
        ..openSettingsResult = false;
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(inSettings(find.text(_openError)), findsNothing);

      await tester.tap(_button);
      await _settle(tester);
      final first = inSettings(find.widgetWithText(LiveNotice, _openError));
      expect(first, findsOneWidget);
      expect(
        tester.getRect(first).top,
        greaterThan(tester.getRect(_button).bottom - 1),
      );
      final data = tester
          .getSemantics(
            find.descendant(
              of: first,
              matching: find.bySemanticsLabel(_openError),
            ),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      final key1 = tester.widget<LiveNotice>(first).attempt;

      await tester.tap(_button);
      await _settle(tester);
      expect(
        tester
            .widget<LiveNotice>(
              inSettings(find.widgetWithText(LiveNotice, _openError)),
            )
            .attempt,
        isNot(key1),
      );

      // Si ahora sí hay a dónde ir, el aviso se quita.
      gateway.openSettingsResult = true;
      await tester.tap(_button);
      await _settle(tester);
      expect(inSettings(find.text(_openError)), findsNothing);
      handle.dispose();
    });

    testWidgets('CA-019-08: el aviso se quita al encender con éxito, sin '
        'anuncio (no hubo diálogo)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(_blockedText, findsOneWidget);
      said.clear();

      gateway.allowed = true; // El usuario las permitió en el sistema.
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_blockedText, findsNothing);
      expect(_button, findsNothing);
      expect(await repo.notificationsOn(), isTrue);
      expect(_option(NotificationsPerDay.one), findsOneWidget);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty);
    });

    testWidgets('CA-019-08: el aviso se quita al salir de Ajustes (y su '
        'error de abrir)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied)
        ..openSettingsResult = false;
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      await tester.tap(_button);
      await _settle(tester);
      expect(inSettings(find.text(_openError)), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsNothing);

      // Al volver a abrir no queda nada del intento anterior.
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await settleSettings(tester);
      expect(_blockedText, findsNothing);
      expect(inSettings(find.text(_openError)), findsNothing);
    });

    testWidgets('CA-019-08: al volver del sistema con las notificaciones '
        'permitidas el aviso se quita, el interruptor sigue apagado y se '
        'anuncia «Notificaciones permitidas.» una vez', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      said.clear();

      gateway.allowed = true;
      await _backgroundAndBack(tester);
      expect(_blockedText, findsNothing);
      expect(_button, findsNothing);
      expect(_toggled(tester), Tristate.isFalse);
      expect(await repo.notificationsOn(), isFalse);
      expect(gateway.configureCalls, isEmpty);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, [_allowed]);
      handle.dispose();
    });

    testWidgets('CA-019-08: si el botón tenía el foco, el foco pasa al '
        'interruptor y el anuncio llega después de moverlo', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway, keyboard: true);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      said.clear();
      await _focus(tester, _inBlock(find.text(_openSystem)));
      await tester.pump();
      expect(_switchHasFocus(tester), isFalse);

      gateway.allowed = true;
      var movedBeforeSaid = false;
      final switchNode = tester.widget<UnaSwitchRow>(_switchRow).focusNode!;
      final announcer = tester
          .widget<LiveRegionNode>(find.byType(LiveRegionNode))
          .announcer;
      announcer.message.addListener(() {
        if (announcer.message.value.isNotEmpty) {
          movedBeforeSaid = switchNode.hasPrimaryFocus;
        }
      });
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(_switchHasFocus(tester), isTrue);
      expect(said, [_allowed]);
      expect(movedBeforeSaid, isTrue);
      handle.dispose();
    });

    testWidgets('CA-019-08: si el foco estaba en otra parte, no se mueve al '
        'quitarse el aviso', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway, keyboard: true);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _focus(tester, inSettings(find.text('Idioma')));
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;

      gateway.allowed = true;
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 1));
      expect(FocusManager.instance.primaryFocus, same(focused));
    });

    testWidgets('CA-019-08: el aviso y el botón están en el orden de lectura '
        'entre la línea de privacidad y la fila siguiente, y el botón es la '
        'única parada nueva', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      final order = readingOrder(tester);
      final i = order.indexOf('Notificaciones');
      expect(order.sublist(i, i + 4), [
        'Notificaciones',
        _privacyEs,
        _blocked,
        _openSystem,
      ]);
      expect(
        order.indexOf('Pantalla siempre activa, Imágenes, documentos y web'),
        greaterThan(i + 3),
      );
      handle.dispose();
    });

    testWidgets('CA-019-08: el aviso se lee en inglés', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway, locale: const Locale('en'));
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 1));
      expect(
        _inBlock(
          find.text(
            'Notifications are blocked in your system '
            'settings.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Open notification settings'),
        findsOneWidget,
      );
      expect(said, ['Notifications are blocked in your system settings.']);
      handle.dispose();
    });
  });

  group('CA-019-07: el permiso al encender', () {
    testWidgets('CA-019-07: sin pedir nada al abrir Ajustes', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogGranted);
      await _open(tester, gateway: gateway);
      await _backgroundAndBack(tester);
      expect(gateway.requestPermissionCalls, 0);
      expect(_blockedText, findsNothing);
    });

    testWidgets('CA-019-07: el diálogo concede: se enciende, el foco sigue en '
        'el interruptor y «Notificaciones activadas.» se anuncia una vez', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.dialogGranted);
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo, keyboard: true);
      final said = _recordAnnouncements(tester);
      await _focus(tester, _inBlock(find.text('Notificaciones')));
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(gateway.requestPermissionCalls, 1);
      expect(await repo.notificationsOn(), isTrue);
      expect(_toggled(tester), Tristate.isTrue);
      expect(_blockedText, findsNothing);
      expect(said, [_enabled]);
      expect(_switchHasFocus(tester), isTrue);
      handle.dispose();
    });

    testWidgets('CA-019-07: sin diálogo (ya concedido o Android 12) no se '
        'anuncia nada propio', (tester) async {
      final gateway = FakeNotificationGateway();
      await _open(tester, gateway: gateway);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(gateway.requestPermissionCalls, 0);
      expect(said, isEmpty);
    });

    testWidgets('CA-019-07: el anuncio de éxito va en el idioma de la app '
        '(inglés)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogGranted);
      await _open(tester, gateway: gateway, locale: const Locale('en'));
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, ['Notifications on.']);
    });

    testWidgets('CA-019-07: si el guardado falla tras el diálogo, no se '
        'anuncia el éxito sino el error', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogGranted)
        ..configureFailure = const NotificationGatewayException();
      await _open(tester, gateway: gateway);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty);
      expect(_saveNotices, findsOneWidget);
    });

    testWidgets('CA-019-07, CA-019-09: con la petición en curso, volver a '
        'primer plano no anuncia «permitidas» y el éxito se anuncia una '
        'sola vez', (tester) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway(FakePermission.dialogGranted)
        ..permissionGate = gate;
      await _open(tester, gateway: gateway);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(gateway.requestPermissionCalls, 1);

      gateway.allowed = true; // El usuario ya concedió, el diálogo se cierra.
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'la petición en curso es la dueña');

      gate.complete();
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, [_enabled]);
    });

    testWidgets('CA-019-07, CA-019-08: con la petición en curso y rechazada, '
        'volver a primer plano no duplica y el aviso se anuncia una vez', (
      tester,
    ) async {
      final gate = Completer<void>();
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied)
        ..permissionGate = gate;
      await _open(tester, gateway: gateway);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _backgroundAndBack(tester);
      gate.complete();
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, [_blocked]);
    });
  });

  group('CA-019-09: el interruptor refleja lo que permite el sistema', () {
    testWidgets('CA-019-09: con el ajuste guardado encendido y el sistema '
        'bloqueando, al abrir Ajustes se ve apagado, sin opciones, con el '
        'aviso y el botón, el valor guardado intacto y SIN anuncio', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.three);
      await _open(tester, gateway: gateway, repo: repo);
      final said = _recordAnnouncements(tester);
      await _wait(tester, const Duration(seconds: 3));

      expect(_toggled(tester), Tristate.isFalse);
      expect(_option(NotificationsPerDay.three), findsNothing);
      expect(_blockedText, findsOneWidget);
      expect(_button, findsOneWidget);
      expect(await repo.notificationsOn(), isTrue);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
      expect(gateway.configureCalls, isEmpty);
      expect(said, isEmpty, reason: 'no compite con el foco inicial');
      // Pero está en el orden de lectura.
      expect(readingOrder(tester), containsAllInOrder([_blocked, _openSystem]));
      handle.dispose();
    });

    testWidgets('CA-019-09: permitidas → vuelve a verse encendido con su '
        'cantidad, el aviso se quita y se anuncia «permitidas y activadas»; '
        'bloqueadas otra vez → apagado; nada guardado cambia', (tester) async {
      final handle = tester.ensureSemantics();
      final gateway = FakeNotificationGateway();
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.three);
      await _open(tester, gateway: gateway, repo: repo);
      final said = _recordAnnouncements(tester);
      expect(_toggled(tester), Tristate.isTrue);

      gateway.allowed = false;
      await _backgroundAndBack(tester);
      expect(_toggled(tester), Tristate.isFalse);
      expect(_blockedText, findsOneWidget);
      expect(_option(NotificationsPerDay.three), findsNothing);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'bloquear no anuncia');

      gateway.allowed = true;
      await _backgroundAndBack(tester);
      expect(_toggled(tester), Tristate.isTrue);
      expect(_blockedText, findsNothing);
      expect(_option(NotificationsPerDay.three), findsOneWidget);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, [_allowedOn]);

      gateway.allowed = false;
      await _backgroundAndBack(tester);
      expect(_toggled(tester), Tristate.isFalse);
      expect(_blockedText, findsOneWidget);

      expect(await repo.notificationsOn(), isTrue);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
      expect(gateway.configureCalls, isEmpty);
      handle.dispose();
    });

    testWidgets('CA-019-09: volver a primer plano sin cambio en el sistema no '
        'anuncia nada: ni con el ajuste encendido y permitido ni con el aviso '
        'de bloqueo a la vista', (tester) async {
      final allowedGateway = FakeNotificationGateway();
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: allowedGateway, repo: repo);
      var said = _recordAnnouncements(tester);
      await _backgroundAndBack(tester);
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'permitidas y sin cambio');
      await tester.pumpWidget(const SizedBox());

      final blockedGateway = FakeNotificationGateway(
        FakePermission.dialogDenied,
      );
      await _open(tester, gateway: blockedGateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      said = _recordAnnouncements(tester);
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'bloqueadas y sin cambio');
      expect(_blockedText, findsOneWidget);
    });

    testWidgets('CA-019-09: al salir de Ajustes se olvida lo leído: la '
        'siguiente apertura empieza sin leer (su primera lectura nunca '
        'anuncia)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(systemAllowsNotificationsProvider), isFalse);

      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      expect(container.read(systemAllowsNotificationsProvider), isNull);
    });

    testWidgets('CA-019-09: sin aviso visible no se anuncia «permitidas» '
        '(ajuste guardado apagado y sin intento)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      await _open(tester, gateway: gateway);
      final said = _recordAnnouncements(tester);
      gateway.allowed = true;
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty);
      expect(_blockedText, findsNothing);
    });

    testWidgets('CA-019-09: tocar el interruptor que se ve apagado por el '
        'bloqueo intenta encender y, si sigue bloqueado, vuelve a anunciar', (
      tester,
    ) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      final said = _recordAnnouncements(tester);
      await tester.tap(_switchRow);
      await _settle(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(gateway.requestPermissionCalls, 1);
      expect(await repo.notificationsOn(), isTrue);
      expect(_blockedText, findsOneWidget);
      expect(said, [_blocked]);
    });

    testWidgets('CA-019-09: el aviso por bloqueo (ajuste guardado encendido) '
        'se quita al salir de Ajustes y, al volver a abrir con el sistema ya '
        'permitido, no se anuncia nada', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      expect(_blockedText, findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      gateway.allowed = true;
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await settleSettings(tester);

      final said = _recordAnnouncements(tester);
      await _wait(tester, const Duration(seconds: 3));
      expect(said, isEmpty, reason: 'la primera lectura nunca anuncia');
      expect(_blockedText, findsNothing);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Notificaciones'))
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
    });

    testWidgets('CA-019-09: si la opción enfocada se pliega por el bloqueo, '
        'el foco pasa al interruptor', (tester) async {
      final gateway = FakeNotificationGateway();
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.two);
      await _open(tester, gateway: gateway, repo: repo, keyboard: true);
      await _focus(
        tester,
        find.descendant(
          of: _option(NotificationsPerDay.two),
          matching: find.text('2'),
        ),
      );
      await tester.pump();
      expect(_switchHasFocus(tester), isFalse);

      gateway.allowed = false;
      await _backgroundAndBack(tester);
      await _wait(tester, const Duration(seconds: 1));
      expect(_option(NotificationsPerDay.two), findsNothing);
      expect(_switchHasFocus(tester), isTrue);
    });

    testWidgets('CA-019-09: el reflejo del sistema se lee al abrir y al volver '
        'a primer plano, no antes (P2: nada sin Ajustes abierto)', (
      tester,
    ) async {
      final gateway = FakeNotificationGateway();
      await _open(tester, gateway: gateway);
      final calls = gateway.canNotifyCalls;
      expect(calls, greaterThanOrEqualTo(1));
      await _backgroundAndBack(tester);
      expect(gateway.canNotifyCalls, calls + 1);
      expect(
        appContainer(tester).read(systemAllowsNotificationsProvider),
        isTrue,
      );
    });
  });

  group('CA-019-06: el aviso de error del bloque', () {
    testWidgets('CA-019-06: si falla guardar al encender, el interruptor se '
        'queda apagado y bajo el bloque sale «No se pudo guardar el ajuste.» '
        'como región viva, sin mover el foco', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = _FailingRepo();
      await _open(tester, repo: repo, keyboard: true);
      await _focus(tester, _inBlock(find.text('Notificaciones')));
      final focused = FocusManager.instance.primaryFocus;
      await tester.tap(_switchRow);
      await _settle(tester);

      expect(_toggled(tester), Tristate.isFalse);
      expect(_saveNotices, findsOneWidget);
      expect(find.bySemanticsLabel(_saveError), findsOneWidget);
      final data = tester
          .getSemantics(find.bySemanticsLabel(_saveError))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(FocusManager.instance.primaryFocus, same(focused));
      // Dentro de la columna del bloque, tras la línea de privacidad.
      final privacy = tester.getRect(_inBlock(find.text(_privacyEs)));
      expect(
        tester.getRect(_inBlock(find.text(_saveError))).top,
        greaterThan(privacy.bottom),
      );
      handle.dispose();
    });

    testWidgets('CA-019-06: si falla la programación, lo mismo y lo guardado '
        'se deshace', (tester) async {
      final gateway = FakeNotificationGateway()
        ..configureFailure = const NotificationGatewayException();
      final repo = await _repoWith();
      await _open(tester, gateway: gateway, repo: repo);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      expect(await repo.notificationsOn(), isFalse);
      expect(_inBlock(find.text(_blocked)), findsNothing);
    });

    testWidgets('CA-019-06, CA-019-08: si tras un rechazo el sistema ya deja '
        'notificar y el guardado falla, sale el aviso de error y el de '
        'bloqueo se quita (ya no es verdad)', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.deniedImmediately);
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_blockedText, findsOneWidget);

      gateway
        ..allowed = true
        ..configureFailure = const NotificationGatewayException();
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_blockedText, findsNothing);
      expect(_saveNotices, findsOneWidget);
    });

    testWidgets('CA-019-06: un fallo al cambiar la cantidad y luego un éxito '
        'quitan el aviso', (tester) async {
      final gateway = FakeNotificationGateway()
        ..configureFailure = const NotificationGatewayException();
      final repo = await _repoWith(on: true);
      await _open(tester, gateway: gateway, repo: repo);
      await tester.tap(_option(NotificationsPerDay.three));
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);

      gateway.configureFailure = null;
      await tester.tap(_option(NotificationsPerDay.three));
      await _settle(tester);
      expect(_saveNotices, findsNothing);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
    });

    testWidgets('CA-019-06: abrir una web con éxito también quita el aviso '
        'del bloque (CA-015-12)', (tester) async {
      final repo = _FailingRepo();
      final opener = await _open(tester, repo: repo);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      final help = inSettings(find.text('Ayuda'));
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      await tester.tap(help);
      await settleSettings(tester);
      expect(opener.opened, hasLength(1));
      expect(_saveNotices, findsNothing);
    });

    testWidgets('CA-019-06: si falla cambiar la cantidad, la marca no cambia '
        'y sale el aviso', (tester) async {
      final gateway = FakeNotificationGateway()
        ..configureFailure = const NotificationGatewayException();
      final repo = await _repoWith(on: true, perDay: NotificationsPerDay.one);
      await _open(tester, gateway: gateway, repo: repo);
      await tester.tap(_option(NotificationsPerDay.three));
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      expect(
        find.descendant(
          of: _option(NotificationsPerDay.one),
          matching: find.byKey(NotificationsBlock.markKey),
        ),
        findsOneWidget,
      );
      expect(await repo.notificationsPerDay(), NotificationsPerDay.one);
    });

    testWidgets('CA-019-06: el texto del error no sale por ningún canal', (
      tester,
    ) async {
      final printed = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      FlutterErrorDetails? reported;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) => reported = details;
      try {
        final repo = _FailingRepo();
        await _open(tester, repo: repo);
        await tester.tap(_switchRow);
        await _settle(tester);
        expect(_saveNotices, findsOneWidget);
        expect(find.textContaining('texto-secreto'), findsNothing);
        expect(printed.join(), isNot(contains('texto-secreto')));
        expect(reported, isNull);
      } finally {
        FlutterError.onError = oldOnError;
        debugPrint = oldDebugPrint;
      }
    });

    testWidgets('CA-019-06: cada fallo vuelve a anunciar (clave nueva) y el '
        'aviso se quita cuando un cambio posterior del bloque sale bien', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = _FailingRepo();
      await _open(tester, repo: repo);
      await tester.tap(_switchRow);
      await _settle(tester);
      final first = tester.widget<LiveNotice>(_saveNotices).attempt;
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(find.bySemanticsLabel(_saveError), findsOneWidget);
      expect(tester.widget<LiveNotice>(_saveNotices).attempt, isNot(first));

      repo.failing = false;
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsNothing);
      expect(_toggled(tester), Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('CA-019-06: el aviso se quita al salir de Ajustes', (
      tester,
    ) async {
      final repo = _FailingRepo();
      await _open(tester, repo: repo);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
      await settleSettings(tester);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await settleSettings(tester);
      expect(_saveNotices, findsNothing);
    });

    testWidgets('CA-019-06: dos avisos a la vez (este y el de Pantalla '
        'siempre activa): claves distintas, cada uno donde se ve y ninguno '
        'quita al otro', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = _FailingRepo();
      await _open(tester, repo: repo, screenReader: true);
      await tester.tap(_switchRow);
      await _settle(tester);
      repo.error = Exception('x');
      await tester.tap(inSettings(find.text('Pantalla siempre activa')));
      await _settle(tester);

      final notices = tester.widgetList<LiveNotice>(_saveNotices).toList();
      expect(notices, hasLength(2));
      expect(notices[0].attempt, isNot(notices[1].attempt));
      final tops = [
        for (var i = 0; i < 2; i++) tester.getTopLeft(_saveNotices.at(i)).dy,
      ]..sort();
      final keepAwake = tester.getTopLeft(
        inSettings(find.text('Pantalla siempre activa')),
      );
      // El del bloque, sobre la fila siguiente; el otro, bajo ella.
      expect(tops.first, lessThan(keepAwake.dy));
      expect(tops.last, greaterThan(keepAwake.dy));
      final order = readingOrder(tester);
      expect(order.where((l) => l == _saveError), hasLength(2));
      tester.takeAnnouncements();
      await _wait(tester, const Duration(seconds: 1));
      expect(tester.takeAnnouncements(), isEmpty);

      // El guardado de la otra fila bien no quita el del bloque (P-017-1).
      repo.error = null;
      await tester.tap(inSettings(find.text('Pantalla siempre activa')));
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      expect(
        tester.getRect(_saveNotices).top,
        lessThan(
          tester
              .getTopLeft(inSettings(find.text('Pantalla siempre activa')))
              .dy,
        ),
      );
      handle.dispose();
    });

    testWidgets('CA-019-06: poner y quitar el aviso del bloque no recrea las '
        'filas de debajo: el foco de Bloquear zoom se conserva', (
      tester,
    ) async {
      final repo = _FailingRepo();
      await _open(tester, repo: repo, keyboard: true);
      final lockZoom = inSettings(find.text('Bloquear zoom'));
      await _focus(tester, lockZoom);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);

      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsOneWidget);
      await _focus(tester, lockZoom);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(focused));

      repo.failing = false;
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(_saveNotices, findsNothing);
      expect(FocusManager.instance.primaryFocus, same(focused));
      expect(focused!.hasPrimaryFocus, isTrue);
    });

    testWidgets('CA-019-06: el aviso de error también se lee en inglés', (
      tester,
    ) async {
      final repo = _FailingRepo();
      await _open(tester, repo: repo, locale: const Locale('en'));
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(
        inSettings(
          find.widgetWithText(LiveNotice, "Couldn't save the setting."),
        ),
        findsOneWidget,
      );
    });
  });

  group('CA-019-26: accesibilidad de los avisos', () {
    testWidgets('CA-019-26: el aviso de bloqueo y su botón caben al 200 % a '
        '360 dp sin desbordar y el botón mide ≥ 44', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await openSettingsScreen(
        tester,
        textScale: 2.0,
        size: const Size(360, 800),
        overrides: notificationsOverrides(gateway: gateway),
      );
      await tester.tap(_switchRow);
      await _settle(tester);
      await tester.ensureVisible(_button);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_button).height, greaterThanOrEqualTo(44));
      final bounds = tester.getRect(find.byType(SettingsScreen));
      expect(
        tester.getRect(_blockedText).right,
        lessThanOrEqualTo(bounds.right),
      );
      expect(
        tester.getRect(_blockedText).left,
        greaterThanOrEqualTo(bounds.left),
      );
    });

    testWidgets('CA-019-26: el texto del aviso es textMuted (≥ 4,5:1 sobre el '
        'papel) y el del error es el de error', (tester) async {
      final gateway = FakeNotificationGateway(FakePermission.dialogDenied);
      await _open(tester, gateway: gateway);
      await tester.tap(_switchRow);
      await _settle(tester);
      expect(
        tester.widget<Text>(_blockedText).style?.color,
        UnaColors.textMuted,
      );
    });
  });
}
