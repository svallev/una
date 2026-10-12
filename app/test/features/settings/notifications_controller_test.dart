import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/features/settings/notifications_state.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';

/// Repositorio de ajustes que anota las escrituras de las notificaciones y
/// puede fallar (con un texto que no debe escaparse) o esperar.
class _Repo extends InMemoryTaskRepository {
  final onWrites = <bool>[];
  final perDayWrites = <NotificationsPerDay>[];
  final log = <String>[];

  /// Falla la escritura número N (1 = la primera) de cada ajuste.
  final failOn = <int>{};
  final failPerDay = <int>{};

  /// Compuerta de "Bloquear zoom": ocupa la cola de guardados.
  Completer<void>? lockZoomGate;

  /// Compuerta de la primera escritura de la cantidad.
  Completer<void>? firstPerDayGate;

  @override
  Future<void> setLockZoom(bool value) async {
    await lockZoomGate?.future;
    await super.setLockZoom(value);
  }

  @override
  Future<void> setNotificationsOn(bool value) async {
    onWrites.add(value);
    log.add('on:$value');
    if (failOn.contains(onWrites.length)) throw Exception('texto-secreto');
    await super.setNotificationsOn(value);
  }

  @override
  Future<void> setNotificationsPerDay(NotificationsPerDay value) async {
    perDayWrites.add(value);
    log.add('perDay:${value.count}');
    if (perDayWrites.length == 1) await firstPerDayGate?.future;
    if (failPerDay.contains(perDayWrites.length)) {
      throw Exception('texto-secreto');
    }
    await super.setNotificationsPerDay(value);
  }
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  late _Repo repo;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;

  Future<void> start({
    FakePermission permission = FakePermission.granted,
    bool on = false,
    NotificationsPerDay perDay = NotificationsPerDay.one,
  }) async {
    repo = _Repo();
    if (on) await repo.setNotificationsOn(true);
    await repo.setNotificationsPerDay(perDay);
    repo.onWrites.clear();
    repo.perDayWrites.clear();
    repo.log.clear();
    gateway = FakeNotificationGateway(permission);
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        notificationGatewayProvider.overrideWithValue(gateway),
        bootStateProvider.overrideWithValue(await readBootState(repo, repo)),
      ],
    );
    addTearDown(container.dispose);
  }

  SettingsController controller() => container.read(settingsProvider.notifier);
  AppSettings state() => container.read(settingsProvider);
  bool? systemAllows() => container.read(systemAllowsNotificationsProvider);
  SystemAllowsNotifications system() =>
      container.read(systemAllowsNotificationsProvider.notifier);

  group(
    'CA-019-08b: qué pasa al encender, según lo que el sistema responda',
    () {
      test(
        'CA-019-08b: permitidas (o Android 12 sin bloqueo): ni una petición, '
        'se guarda y se programa',
        () async {
          await start();
          final (result, :dialogShown) = await controller().setNotificationsOn(
            true,
          );
          expect(result, SaveResult.saved);
          expect(dialogShown, isFalse);
          expect(gateway.canNotifyCalls, 1);
          expect(gateway.requestPermissionCalls, 0);
          expect(repo.onWrites, [true]);
          expect(gateway.configureCalls, [
            (
              on: true,
              perDay: NotificationsPerDay.one,
              language: LocaleChoice.system,
            ),
          ]);
          expect(state().notificationsOn, isTrue);
          expect(await repo.notificationsOn(), isTrue);
          expect(systemAllows(), isTrue);
        },
      );

      test('CA-019-07: hay que pedir el permiso, sale el diálogo y se concede: '
          'se guarda, se programa y dice que hubo diálogo', () async {
        await start(permission: FakePermission.dialogGranted);
        // `dialogGranted` arranca bloqueado: el sistema aún no deja notificar.
        gateway.allowed = false;
        final (result, :dialogShown) = await controller().setNotificationsOn(
          true,
        );
        expect(result, SaveResult.saved);
        expect(dialogShown, isTrue);
        expect(gateway.requestPermissionCalls, 1);
        expect(gateway.configureCalls.single.on, isTrue);
        expect(state().notificationsOn, isTrue);
        expect(systemAllows(), isTrue);
      });

      test('CA-019-08: hay que pedir el permiso, sale el diálogo y se rechaza: '
          'bloqueada, no se guarda ni se programa nada', () async {
        await start(permission: FakePermission.dialogDenied);
        final (result, :dialogShown) = await controller().setNotificationsOn(
          true,
        );
        expect(result, SaveResult.blocked);
        expect(dialogShown, isTrue);
        expect(gateway.requestPermissionCalls, 1);
        expect(repo.onWrites, isEmpty);
        expect(gateway.configureCalls, isEmpty);
        expect(state().notificationsOn, isFalse);
        expect(await repo.notificationsOn(), isFalse);
        expect(systemAllows(), isFalse);
      });

      test('CA-019-08b: rechazo inmediato (sin diálogo, p. ej. Android 12 con '
          'las notificaciones apagadas o canal apagado): bloqueada', () async {
        await start(permission: FakePermission.deniedImmediately);
        final (result, :dialogShown) = await controller().setNotificationsOn(
          true,
        );
        expect(result, SaveResult.blocked);
        expect(dialogShown, isFalse);
        expect(repo.onWrites, isEmpty);
        expect(gateway.configureCalls, isEmpty);
        expect(state().notificationsOn, isFalse);
        expect(systemAllows(), isFalse);
      });

      test(
        'CA-019-08: un segundo intento tras un rechazo vuelve a pedir (la app '
        'no recuerda si ya preguntó) y la guardia queda libre',
        () async {
          await start(permission: FakePermission.dialogDenied);
          expect(
            (await controller().setNotificationsOn(true)).$1,
            SaveResult.blocked,
          );
          expect(
            (await controller().setNotificationsOn(true)).$1,
            SaveResult.blocked,
          );
          expect(gateway.requestPermissionCalls, 2);
        },
      );

      test(
        'CA-019-07: sin tocar el interruptor no se pide nada (ni al crear el '
        'controlador ni al leer el estado del sistema)',
        () async {
          await start(permission: FakePermission.dialogDenied);
          state();
          controller();
          await system().refresh();
          expect(gateway.requestPermissionCalls, 0);
          expect(gateway.configureCalls, isEmpty);
        },
      );
    },
  );

  group('CA-019-02: encender y apagar, todo o nada', () {
    test('CA-019-02: el estado no cambia hasta que termina el paso (sin '
        'cambio optimista)', () async {
      await start();
      gateway.configureGate = Completer<void>();
      final seen = <AppSettings>[];
      container.listen(settingsProvider, (_, next) => seen.add(next));
      final pending = controller().setNotificationsOn(true);
      await _turn();
      expect(repo.onWrites, [true]);
      expect(gateway.configureCalls, hasLength(1));
      expect(state().notificationsOn, isFalse);
      expect(seen, isEmpty);
      gateway.configureGate!.complete();
      expect((await pending).$1, SaveResult.saved);
      expect(state().notificationsOn, isTrue);
      expect(seen, hasLength(1));
    });

    test('CA-019-02: si falla el guardado, no se programa nada y nada '
        'cambia', () async {
      await start();
      repo.failOn.add(1);
      final (result, :dialogShown) = await controller().setNotificationsOn(
        true,
      );
      expect(result, SaveResult.failed);
      expect(dialogShown, isFalse);
      expect(gateway.configureCalls, isEmpty);
      expect(state().notificationsOn, isFalse);
      expect(await repo.notificationsOn(), isFalse);
      // Un fallo no deja el ajuste "en curso".
      repo.failOn.clear();
      expect(
        (await controller().setNotificationsOn(true)).$1,
        SaveResult.saved,
      );
      expect(state().notificationsOn, isTrue);
    });

    test(
      'CA-019-02: si falla `configure`, el valor guardado también se '
      'deshace (marcha atrás) y el interruptor se queda como estaba',
      () async {
        await start();
        gateway.configureFailure = const NotificationGatewayException();
        final (result, :dialogShown) = await controller().setNotificationsOn(
          true,
        );
        expect(result, SaveResult.failed);
        expect(dialogShown, isFalse);
        expect(repo.log, ['on:true', 'on:false']);
        expect(await repo.notificationsOn(), isFalse);
        expect(state().notificationsOn, isFalse);
      },
    );

    test(
      'CA-019-02: si falla `configure` tras un diálogo concedido, sigue '
      'siendo fallo y dice que hubo diálogo (el permiso ya está dado)',
      () async {
        await start(permission: FakePermission.dialogGranted);
        gateway.allowed = false;
        gateway.configureFailure = const NotificationGatewayException();
        final (result, :dialogShown) = await controller().setNotificationsOn(
          true,
        );
        expect(result, SaveResult.failed);
        expect(dialogShown, isTrue);
        expect(state().notificationsOn, isFalse);
        // Lo concedido no se pierde: el sistema ya permite notificar.
        expect(systemAllows(), isTrue);
      },
    );

    test('CA-019-02: apagar guarda, cancela (configure off) y solo entonces '
        'cambia el estado', () async {
      await start(on: true, perDay: NotificationsPerDay.three);
      expect(state().notificationsOn, isTrue);
      final (result, :dialogShown) = await controller().setNotificationsOn(
        false,
      );
      expect(result, SaveResult.saved);
      expect(dialogShown, isFalse);
      expect(
        gateway.canNotifyCalls,
        0,
        reason: 'apagar no pregunta al sistema',
      );
      expect(gateway.requestPermissionCalls, 0);
      expect(repo.onWrites, [false]);
      expect(gateway.configureCalls, [
        (
          on: false,
          perDay: NotificationsPerDay.three,
          language: LocaleChoice.system,
        ),
      ]);
      expect(state().notificationsOn, isFalse);
      expect(
        state().notificationsPerDay,
        NotificationsPerDay.three,
        reason: 'la cantidad se conserva',
      );
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
    });

    test('CA-019-02: apagar: si falla el guardado o la cancelación, sigue '
        'encendido y el valor guardado vuelve a `true`', () async {
      await start(on: true);
      repo.failOn.add(1);
      expect(
        (await controller().setNotificationsOn(false)).$1,
        SaveResult.failed,
      );
      expect(state().notificationsOn, isTrue);
      expect(await repo.notificationsOn(), isTrue);
      expect(gateway.configureCalls, isEmpty);

      repo.failOn.clear();
      repo.onWrites.clear();
      repo.log.clear();
      gateway.configureFailure = const NotificationGatewayException();
      expect(
        (await controller().setNotificationsOn(false)).$1,
        SaveResult.failed,
      );
      expect(repo.log, ['on:false', 'on:true']);
      expect(await repo.notificationsOn(), isTrue);
      expect(state().notificationsOn, isTrue);
    });

    test('CA-019-11: apagar con el ajuste ya apagado no hace nada', () async {
      await start();
      final result = (await controller().setNotificationsOn(false)).$1;
      expect(result, SaveResult.unchanged);
      expect(repo.onWrites, isEmpty);
      expect(gateway.configureCalls, isEmpty);
    });

    test('CA-019-02 / CL-019-11: un segundo toque mientras la fila trabaja se '
        'ignora, también con el diálogo del sistema abierto', () async {
      await start(permission: FakePermission.dialogGranted);
      gateway.allowed = false;
      gateway.permissionGate = Completer<void>();
      final first = controller().setNotificationsOn(true);
      await _turn();
      expect(gateway.requestPermissionCalls, 1);
      final second = await controller().setNotificationsOn(true);
      expect(second.$1, SaveResult.unchanged);
      final third = await controller().setNotificationsOn(false);
      expect(third.$1, SaveResult.unchanged);
      expect(gateway.requestPermissionCalls, 1);
      gateway.permissionGate!.complete();
      expect((await first).$1, SaveResult.saved);
      expect(repo.onWrites, [true]);
      expect(gateway.configureCalls, hasLength(1));
      // Terminado, el siguiente toque ya cuenta.
      expect(
        (await controller().setNotificationsOn(false)).$1,
        SaveResult.saved,
      );
    });

    test('CA-019-02 / plan §4: el permiso va fuera de la cola: con el '
        'diálogo abierto, otro ajuste se guarda sin esperarlo', () async {
      await start(permission: FakePermission.dialogGranted);
      gateway.allowed = false;
      gateway.permissionGate = Completer<void>();
      final first = controller().setNotificationsOn(true);
      await _turn();
      expect(await controller().setLockZoom(true), SaveResult.saved);
      expect(await controller().setKeepScreenOn(true), SaveResult.saved);
      expect(state().lockZoom, isTrue);
      expect(state().notificationsOn, isFalse);
      gateway.permissionGate!.complete();
      expect((await first).$1, SaveResult.saved);
    });

    test('CA-017-02: el guardado y la programación van dentro de la cola: '
        'esperan al guardado anterior de otro ajuste', () async {
      await start();
      repo.lockZoomGate = Completer<void>();
      // Un guardado de otra fila que se queda esperando ocupa la cola.
      final blocker = controller().setLockZoom(true);
      await _turn();
      final pending = controller().setNotificationsOn(true);
      await _turn();
      expect(repo.onWrites, isEmpty, reason: 'espera su turno');
      repo.lockZoomGate!.complete();
      expect(await blocker, SaveResult.saved);
      expect((await pending).$1, SaveResult.saved);
      expect(repo.onWrites, [true]);
    });

    test(
      'CA-019-02: usa el idioma y la cantidad vigentes al llegar su turno',
      () async {
        await start(perDay: NotificationsPerDay.two);
        await controller().saveLocale(LocaleChoice.en);
        controller().applyLocale(LocaleChoice.en);
        await controller().setNotificationsOn(true);
        expect(gateway.configureCalls.single, (
          on: true,
          perDay: NotificationsPerDay.two,
          language: LocaleChoice.en,
        ));
      },
    );
  });

  group('CA-019-03 / CA-019-12: la cantidad al día', () {
    test('CA-019-12: cambiar la cantidad guarda, reprograma y solo entonces '
        'cambia la marca', () async {
      await start(on: true);
      gateway.configureGate = Completer<void>();
      final pending = controller().setNotificationsPerDay(
        NotificationsPerDay.three,
      );
      await _turn();
      expect(repo.perDayWrites, [NotificationsPerDay.three]);
      expect(state().notificationsPerDay, NotificationsPerDay.one);
      gateway.configureGate!.complete();
      expect(await pending, SaveResult.saved);
      expect(state().notificationsPerDay, NotificationsPerDay.three);
      expect(gateway.configureCalls.single, (
        on: true,
        perDay: NotificationsPerDay.three,
        language: LocaleChoice.system,
      ));
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
    });

    test('CA-019-03: un toque en la ya marcada no hace nada', () async {
      await start(on: true, perDay: NotificationsPerDay.two);
      expect(
        await controller().setNotificationsPerDay(NotificationsPerDay.two),
        SaveResult.unchanged,
      );
      expect(repo.perDayWrites, isEmpty);
      expect(gateway.configureCalls, isEmpty);
    });

    test('CA-019-03: 3 y enseguida 2 se aplican una tras otra y gana la '
        'última (2)', () async {
      await start(on: true);
      gateway.configureGate = Completer<void>();
      final first = controller().setNotificationsPerDay(
        NotificationsPerDay.three,
      );
      await _turn();
      final second = controller().setNotificationsPerDay(
        NotificationsPerDay.two,
      );
      expect(
        await second,
        SaveResult.unchanged,
        reason: 'la última la aplica el primero',
      );
      expect(state().notificationsPerDay, NotificationsPerDay.one);
      gateway.configureGate!.complete();
      expect(await first, SaveResult.saved);
      expect(state().notificationsPerDay, NotificationsPerDay.two);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
      expect(repo.perDayWrites, [
        NotificationsPerDay.three,
        NotificationsPerDay.two,
      ]);
      expect(gateway.configureCalls.map((c) => c.perDay).toList(), [
        NotificationsPerDay.three,
        NotificationsPerDay.two,
      ]);
    });

    test('CA-019-03: volver a la opción de partida mientras otra se aplica '
        'también se aplica (gana la última, no el estado visible)', () async {
      await start(on: true);
      gateway.configureGate = Completer<void>();
      final first = controller().setNotificationsPerDay(
        NotificationsPerDay.three,
      );
      await _turn();
      final back = controller().setNotificationsPerDay(NotificationsPerDay.one);
      expect(await back, SaveResult.unchanged);
      gateway.configureGate!.complete();
      expect(await first, SaveResult.saved);
      expect(state().notificationsPerDay, NotificationsPerDay.one);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.one);
      expect(repo.perDayWrites.last, NotificationsPerDay.one);
    });

    test('CA-019-03: tres toques seguidos (3, 2, 3): se aplica el último y '
        'el segundo no se aplica', () async {
      await start(on: true);
      gateway.configureGate = Completer<void>();
      final first = controller().setNotificationsPerDay(
        NotificationsPerDay.three,
      );
      await _turn();
      final a = controller().setNotificationsPerDay(NotificationsPerDay.two);
      final b = controller().setNotificationsPerDay(NotificationsPerDay.three);
      expect(await a, SaveResult.unchanged);
      expect(await b, SaveResult.unchanged);
      gateway.configureGate!.complete();
      expect(await first, SaveResult.saved);
      expect(state().notificationsPerDay, NotificationsPerDay.three);
      expect(repo.perDayWrites, [NotificationsPerDay.three]);
    });

    test(
      'CA-019-06: si falla el guardado, la marca se queda como estaba',
      () async {
        await start(on: true, perDay: NotificationsPerDay.two);
        repo.failPerDay.add(1);
        expect(
          await controller().setNotificationsPerDay(NotificationsPerDay.three),
          SaveResult.failed,
        );
        expect(state().notificationsPerDay, NotificationsPerDay.two);
        expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
        expect(gateway.configureCalls, isEmpty);
      },
    );

    test('CA-019-06: si falla `configure`, el valor guardado vuelve al '
        'anterior y la marca no cambia', () async {
      await start(on: true, perDay: NotificationsPerDay.two);
      gateway.configureFailure = const NotificationGatewayException();
      expect(
        await controller().setNotificationsPerDay(NotificationsPerDay.three),
        SaveResult.failed,
      );
      expect(repo.perDayWrites, [
        NotificationsPerDay.three,
        NotificationsPerDay.two,
      ]);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
      expect(state().notificationsPerDay, NotificationsPerDay.two);
    });

    test('CA-019-03: tras un fallo, un toque posterior se aplica (la vía no '
        'queda ocupada)', () async {
      await start(on: true);
      repo.failPerDay.add(1);
      expect(
        await controller().setNotificationsPerDay(NotificationsPerDay.three),
        SaveResult.failed,
      );
      expect(
        await controller().setNotificationsPerDay(NotificationsPerDay.three),
        SaveResult.saved,
      );
      expect(state().notificationsPerDay, NotificationsPerDay.three);
    });

    test('CA-019-03: 3 falla y enseguida 2 se aplica: el resultado es el de '
        'la última (guardado)', () async {
      await start(on: true);
      repo.failPerDay.add(1);
      repo.firstPerDayGate = Completer<void>();
      final first = controller().setNotificationsPerDay(
        NotificationsPerDay.three,
      );
      await _turn();
      final second = controller().setNotificationsPerDay(
        NotificationsPerDay.two,
      );
      expect(await second, SaveResult.unchanged);
      repo.firstPerDayGate!.complete();
      expect(await first, SaveResult.saved);
      expect(state().notificationsPerDay, NotificationsPerDay.two);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.two);
    });

    test('CA-019-05: con el ajuste apagado, la cantidad se guarda y se '
        'conserva sin programar nada', () async {
      await start();
      expect(
        await controller().setNotificationsPerDay(NotificationsPerDay.three),
        SaveResult.saved,
      );
      expect(gateway.configureCalls, isEmpty);
      expect(state().notificationsPerDay, NotificationsPerDay.three);
      expect(await repo.notificationsPerDay(), NotificationsPerDay.three);
    });
  });

  group('CA-019-09: el ajuste guardado frente a lo que permite el sistema', () {
    test('CA-019-09: el ajuste guardado no cambia mientras el sistema bloquea '
        'ni al volver a permitir', () async {
      await start(on: true, perDay: NotificationsPerDay.three);
      gateway.allowed = false;
      await system().refresh();
      expect(systemAllows(), isFalse);
      expect(state().notificationsOn, isTrue);
      expect(state().notificationsPerDay, NotificationsPerDay.three);
      gateway.allowed = true;
      await system().refresh();
      expect(systemAllows(), isTrue);
      expect(state().notificationsOn, isTrue);
      expect(state().notificationsPerDay, NotificationsPerDay.three);
      expect(repo.onWrites, isEmpty);
      expect(repo.perDayWrites, isEmpty);
      expect(await repo.notificationsOn(), isTrue);
    });

    test('CA-019-09: con el ajuste guardado encendido y el sistema '
        'bloqueando, tocar el interruptor sigue el flujo de encender y, al '
        'conceder, lo guarda y reprograma', () async {
      await start(permission: FakePermission.dialogGranted, on: true);
      gateway.allowed = false;
      await system().refresh();
      final (result, :dialogShown) = await controller().setNotificationsOn(
        true,
      );
      expect(result, SaveResult.saved);
      expect(dialogShown, isTrue);
      expect(gateway.configureCalls.single.on, isTrue);
      expect(state().notificationsOn, isTrue);
      expect(systemAllows(), isTrue);
    });

    test('CA-019-09: con el ajuste guardado encendido y el sistema '
        'bloqueando, un rechazo no cambia lo guardado', () async {
      await start(permission: FakePermission.deniedImmediately, on: true);
      gateway.allowed = false;
      await system().refresh();
      final result = (await controller().setNotificationsOn(true)).$1;
      expect(result, SaveResult.blocked);
      expect(state().notificationsOn, isTrue);
      expect(await repo.notificationsOn(), isTrue);
      expect(repo.onWrites, isEmpty);
    });

    test('CA-019-09: la primera lectura no es una transición (nada que '
        'anunciar) y el estado empieza sin leer', () async {
      await start(on: true);
      expect(systemAllows(), isNull);
      gateway.allowed = true;
      expect(await system().refresh(), isFalse);
      expect(systemAllows(), isTrue);
    });

    test('CA-019-08: solo la transición bloqueada → permitida se anuncia; '
        'permitida → bloqueada y repetir, no', () async {
      await start(on: true);
      gateway.allowed = false;
      expect(await system().refresh(), isFalse);
      expect(systemAllows(), isFalse);
      expect(await system().refresh(), isFalse, reason: 'sigue bloqueada');
      gateway.allowed = true;
      expect(await system().refresh(), isTrue, reason: 'permitida de nuevo');
      expect(await system().refresh(), isFalse, reason: 'ya lo sabía');
      gateway.allowed = false;
      expect(await system().refresh(), isFalse);
      expect(systemAllows(), isFalse);
    });

    test(
      'CA-019-08 / CA-019-09: mientras hay una petición en curso, la '
      'relectura actualiza el estado pero no anuncia (un solo dueño)',
      () async {
        await start(permission: FakePermission.dialogGranted);
        gateway.allowed = false;
        await system().refresh();
        expect(systemAllows(), isFalse);
        gateway.permissionGate = Completer<void>();
        final toggle = controller().setNotificationsOn(true);
        await _turn();
        expect(system().requestInFlight, isTrue);
        // El diálogo se cierra: la app vuelve (`resumed`) y relee.
        gateway.allowed = true;
        expect(
          await system().refresh(),
          isFalse,
          reason: 'no anuncia en curso',
        );
        expect(systemAllows(), isTrue);
        gateway.permissionGate!.complete();
        final (result, :dialogShown) = await toggle;
        expect(result, SaveResult.saved);
        expect(dialogShown, isTrue);
        expect(system().requestInFlight, isFalse);
        expect(systemAllows(), isTrue);
      },
    );

    test('CA-019-08: una lectura que empezó antes de la petición y termina '
        'después no pisa lo que dijo la petición ni anuncia', () async {
      await start(permission: FakePermission.deniedImmediately);
      gateway.allowed = false;
      await system().refresh();
      gateway.allowed = true;
      final staleGate = Completer<void>();
      gateway.canNotifyGate = staleGate;
      final stale = system().refresh();
      await _turn();
      // Mientras esa lectura (que verá `true`) espera, el usuario enciende y
      // el sistema rechaza.
      gateway.allowed = false;
      final other = Completer<void>();
      gateway.canNotifyGate = other;
      final toggle = controller().setNotificationsOn(true);
      await _turn();
      expect(gateway.canNotifyCalls, 3);
      other.complete();
      final result = (await toggle).$1;
      expect(result, SaveResult.blocked);
      expect(systemAllows(), isFalse);
      staleGate.complete();
      expect(await stale, isFalse);
      expect(systemAllows(), isFalse, reason: 'la lectura vieja se descarta');
    });

    test('CA-019-09: un fallo al leer el estado del sistema vale como '
        'bloqueado (nunca lanza)', () async {
      await start(on: true);
      final throwing = _ThrowingCanNotify();
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(throwing),
          bootStateProvider.overrideWithValue(await readBootState(repo, repo)),
        ],
      );
      addTearDown(c.dispose);
      final notifier = c.read(systemAllowsNotificationsProvider.notifier);
      expect(await notifier.refresh(), isFalse);
      expect(c.read(systemAllowsNotificationsProvider), isFalse);
    });
  });

  group('CA-019-21: el idioma al guardarlo', () {
    test('CA-019-21: con las notificaciones encendidas, guardar el idioma '
        'avisa a lo nativo con el nuevo', () async {
      await start(on: true, perDay: NotificationsPerDay.two);
      expect(await controller().saveLocale(LocaleChoice.en), SaveResult.saved);
      expect(gateway.configureCalls.single, (
        on: true,
        perDay: NotificationsPerDay.two,
        language: LocaleChoice.en,
      ));
    });

    test('CA-019-21: con las notificaciones apagadas, guardar el idioma no '
        'toca lo nativo', () async {
      await start();
      expect(await controller().saveLocale(LocaleChoice.es), SaveResult.saved);
      expect(gateway.configureCalls, isEmpty);
    });

    test('CA-019-21: es mejor esfuerzo: si `configure` falla, el idioma se '
        'guarda igual (el arranque lo corrige)', () async {
      await start(on: true);
      gateway.configureFailure = const NotificationGatewayException();
      expect(await controller().saveLocale(LocaleChoice.en), SaveResult.saved);
      expect(await repo.locale(), LocaleChoice.en);
      expect(gateway.configureCalls, hasLength(1));
    });

    test('CA-019-21: si el guardado del idioma falla, no se avisa a lo '
        'nativo', () async {
      await start(on: true);
      final failing = _FailingLocaleRepo();
      await failing.setNotificationsOn(true);
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(failing),
          notificationGatewayProvider.overrideWithValue(gateway),
          bootStateProvider.overrideWithValue(
            await readBootState(failing, failing),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(
        await c.read(settingsProvider.notifier).saveLocale(LocaleChoice.en),
        SaveResult.failed,
      );
      expect(gateway.configureCalls, isEmpty);
    });
  });

  group('CA-019-06: sin rastro del error', () {
    test('CA-019-06: el error de un guardado o de la programación no se '
        'escapa (ni `FlutterError`, `debugPrint`, `print` ni zona) ni se '
        'muestra', () async {
      await start(on: true);
      final seen = <String>[];
      final flutterErrors = <FlutterErrorDetails>[];
      final zoneErrors = <Object>[];
      final oldOnError = FlutterError.onError;
      final oldDebugPrint = debugPrint;
      FlutterError.onError = flutterErrors.add;
      debugPrint = (String? message, {int? wrapWidth}) => seen.add('$message');
      repo.failOn.addAll({1, 2, 3});
      repo.failPerDay.addAll({1, 2, 3});

      final results = <Object>[];
      await runZonedGuarded(
        () async {
          results.add((await controller().setNotificationsOn(false)).$1);
          results.add(
            await controller().setNotificationsPerDay(
              NotificationsPerDay.three,
            ),
          );
          repo.failOn.clear();
          repo.failPerDay.clear();
          gateway.configureFailure = const NotificationGatewayException();
          results.add((await controller().setNotificationsOn(false)).$1);
          results.add(
            await controller().setNotificationsPerDay(NotificationsPerDay.two),
          );
          await _turn();
        },
        (e, _) => zoneErrors.add(e),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => seen.add(line),
        ),
      );

      FlutterError.onError = oldOnError;
      debugPrint = oldDebugPrint;
      expect(results, everyElement(SaveResult.failed));
      expect(flutterErrors, isEmpty);
      expect(zoneErrors, isEmpty);
      expect(seen, isEmpty);
      expect(
        gateway.configureCalls.map((c) => '$c').join(),
        isNot(contains('texto-secreto')),
      );
    });

    test('CA-019-06: si el sistema lanza al preguntar o al pedir, es un '
        'fallo sin texto (no bloqueada) y la guardia queda libre', () async {
      await start();
      final throwing = _ThrowingCanNotify();
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(throwing),
          bootStateProvider.overrideWithValue(await readBootState(repo, repo)),
        ],
      );
      addTearDown(c.dispose);
      final ctrl = c.read(settingsProvider.notifier);
      expect((await ctrl.setNotificationsOn(true)).$1, SaveResult.failed);
      expect((await ctrl.setNotificationsOn(true)).$1, SaveResult.failed);
      expect(repo.onWrites, isEmpty);
    });
  });
}

class _ThrowingCanNotify extends FakeNotificationGateway {
  @override
  Future<bool> canNotify() async => throw StateError('texto-secreto');

  @override
  Future<PermissionResult> requestPermission() async =>
      throw StateError('texto-secreto');
}

class _FailingLocaleRepo extends InMemoryTaskRepository {
  @override
  Future<void> setLocale(LocaleChoice choice) async =>
      throw Exception('texto-secreto');
}
