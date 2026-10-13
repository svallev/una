import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/data/platform/notification_gateway.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_gateway.dart';

/// API de Dart del canal `una/notifications` (`NotificationsChannel.kt`, spec
/// 019). Lo nativo se comprueba con JUnit (validación, permiso, "a la vista",
/// `nonce`) y en el emulador (T-019-14); aquí, el contrato del canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('una/notifications');

  late List<MethodCall> calls;
  late ChannelNotificationGateway gateway;

  void answer(Future<Object?> Function(MethodCall call) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(() {
    calls = [];
    gateway = ChannelNotificationGateway();
  });

  tearDown(() {
    gateway.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('CA-019-07: canNotify y requestPermission', () {
    test('canNotify llama a "canNotify" sin argumentos y devuelve el '
        'booleano', () async {
      answer((_) async => true);
      expect(await gateway.canNotify(), isTrue);
      expect(calls.single.method, 'canNotify');
      expect(calls.single.arguments, isNull);
      answer((_) async => false);
      expect(await gateway.canNotify(), isFalse);
    });

    test('una respuesta que no es un booleano es "no puede"', () async {
      for (final reply in <Object?>[
        null,
        'true',
        1,
        {'a': 1},
      ]) {
        answer((_) async => reply);
        expect(await gateway.canNotify(), isFalse, reason: '$reply');
      }
    });

    test('requestPermission lee {granted, dialogShown} y llama una vez, sin '
        'argumentos', () async {
      answer((_) async => {'granted': true, 'dialogShown': true});
      final result = await gateway.requestPermission();
      expect(result.granted, isTrue);
      expect(result.dialogShown, isTrue);
      expect(calls.single.method, 'requestPermission');
      expect(calls.single.arguments, isNull);
    });

    test(
      'CA-019-08b: las cuatro respuestas del sistema llegan tal cual',
      () async {
        for (final (granted, dialog) in [
          (true, false), // permitidas, sin diálogo
          (true, true), // diálogo con concesión
          (false, true), // diálogo con rechazo
          (false, false), // rechazo inmediato
        ]) {
          answer((_) async => {'granted': granted, 'dialogShown': dialog});
          final result = await gateway.requestPermission();
          expect((result.granted, result.dialogShown), (granted, dialog));
        }
      },
    );

    test('una respuesta rara es "no concedido" y sin diálogo', () async {
      for (final reply in <Object?>[
        null,
        true,
        'granted',
        <Object?, Object?>{},
        {'granted': 'true', 'dialogShown': true},
        {'granted': 1},
      ]) {
        answer((_) async => reply);
        final result = await gateway.requestPermission();
        expect(result.granted, isFalse, reason: '$reply');
        expect(result.dialogShown, isFalse, reason: '$reply');
      }
    });

    test('un dialogShown ausente es falso', () async {
      answer((_) async => {'granted': true});
      final result = await gateway.requestPermission();
      expect((result.granted, result.dialogShown), (true, false));
    });
  });

  group('CA-019-02: configure', () {
    test(
      'manda {on, perDay, lang} con el número y el código del idioma',
      () async {
        answer((_) async => null);
        await gateway.configure(
          on: true,
          perDay: NotificationsPerDay.three,
          language: LocaleChoice.es,
        );
        expect(calls.single.method, 'configure');
        expect(calls.single.arguments, {'on': true, 'perDay': 3, 'lang': 'es'});
        await gateway.configure(
          on: false,
          perDay: NotificationsPerDay.one,
          language: LocaleChoice.system,
        );
        expect(calls.last.arguments, {
          'on': false,
          'perDay': 1,
          'lang': 'system',
        });
        await gateway.configure(
          on: true,
          perDay: NotificationsPerDay.two,
          language: LocaleChoice.en,
        );
        expect(calls.last.arguments, {'on': true, 'perDay': 2, 'lang': 'en'});
      },
    );

    test('CA-019-23: un error de plataforma es un fallo sin el texto del '
        'error', () async {
      answer(
        (_) async => throw PlatformException(
          code: 'failed',
          message: 'texto-secreto',
          details: 'texto-secreto',
        ),
      );
      Object? caught;
      try {
        await gateway.configure(
          on: true,
          perDay: NotificationsPerDay.one,
          language: LocaleChoice.system,
        );
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<NotificationGatewayException>());
      expect((caught! as NotificationGatewayException).unsupported, isFalse);
      expect('$caught', isNot(contains('texto-secreto')));
    });

    test('un canal sin lado nativo (MissingPluginException) es "no '
        'soportado"', () async {
      // Sin manejador: el mensajero simulado contesta con MissingPluginException.
      Object? caught;
      try {
        await gateway.configure(
          on: true,
          perDay: NotificationsPerDay.one,
          language: LocaleChoice.system,
        );
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<NotificationGatewayException>());
      expect((caught! as NotificationGatewayException).unsupported, isTrue);
    });
  });

  group('CA-019-19b: cancelDelivered y setForeground', () {
    test('cancelDelivered llama a "cancelDelivered" sin argumentos', () async {
      answer((_) async => null);
      await gateway.cancelDelivered();
      expect(calls.single.method, 'cancelDelivered');
      expect(calls.single.arguments, isNull);
    });

    test('setForeground manda el booleano', () async {
      answer((_) async => null);
      await gateway.setForeground(true);
      await gateway.setForeground(false);
      expect(calls.map((c) => c.method), ['setForeground', 'setForeground']);
      expect(calls.map((c) => c.arguments), [true, false]);
    });

    test('son de mejor esfuerzo: un error de plataforma o la falta del canal '
        'no se propagan', () async {
      answer((_) async => throw PlatformException(code: 'failed'));
      await gateway.cancelDelivered();
      await gateway.setForeground(true);
      messenger.setMockMethodCallHandler(channel, null);
      await gateway.cancelDelivered();
      await gateway.setForeground(false);
    });
  });

  group('CA-019-08: openSystemSettings', () {
    test('devuelve si había a dónde ir', () async {
      answer((_) async => true);
      expect(await gateway.openSystemSettings(), isTrue);
      expect(calls.single.method, 'openSystemSettings');
      expect(calls.single.arguments, isNull);
      answer((_) async => false);
      expect(await gateway.openSystemSettings(), isFalse);
    });

    test('un error, la falta del canal o una respuesta rara es "no hay '
        'dónde ir"', () async {
      answer((_) async => throw PlatformException(code: 'failed'));
      expect(await gateway.openSystemSettings(), isFalse);
      answer((_) async => 'sí');
      expect(await gateway.openSystemSettings(), isFalse);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await gateway.openSystemSettings(), isFalse);
    });
  });

  group('CA-019-20: la orden openCurrentTask llega a un Stream', () {
    Future<void> deliver(String method, [Object? arguments]) async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
    }

    test(
      'cada orden de lo nativo es un evento y sin oyentes no pasa nada',
      () async {
        await deliver('openCurrentTask'); // nadie escucha todavía
        final events = <void>[];
        final sub = gateway.openCurrentTaskRequests.listen(events.add);
        await deliver('openCurrentTask');
        await deliver('openCurrentTask');
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(2));
        await sub.cancel();
      },
    );

    test('el Stream admite más de un oyente', () async {
      var a = 0;
      var b = 0;
      final subA = gateway.openCurrentTaskRequests.listen((_) => a++);
      final subB = gateway.openCurrentTaskRequests.listen((_) => b++);
      await deliver('openCurrentTask');
      await Future<void>.delayed(Duration.zero);
      expect((a, b), (1, 1));
      await subA.cancel();
      await subB.cancel();
    });

    test('cualquier otro método de lo nativo se ignora', () async {
      var events = 0;
      final sub = gateway.openCurrentTaskRequests.listen((_) => events++);
      await deliver('otraCosa');
      await deliver('openCurrentTask', {'tarea': 'texto-secreto'});
      await Future<void>.delayed(Duration.zero);
      // Con argumentos de más sigue siendo la misma orden: no lleva datos.
      expect(events, 1);
      await sub.cancel();
    });

    test('tras dispose ya no llegan órdenes', () async {
      var events = 0;
      final sub = gateway.openCurrentTaskRequests.listen((_) => events++);
      gateway.dispose();
      await deliver('openCurrentTask');
      await Future<void>.delayed(Duration.zero);
      expect(events, 0);
      await sub.cancel();
    });
  });

  group('CA-019-28: web e iOS', () {
    test('UnsupportedNotificationGateway: nada permitido, nada que '
        'programar, sin eventos', () async {
      const unsupported = UnsupportedNotificationGateway();
      expect(await unsupported.canNotify(), isFalse);
      final permission = await unsupported.requestPermission();
      expect((permission.granted, permission.dialogShown), (false, false));
      expect(await unsupported.openSystemSettings(), isFalse);
      await unsupported.cancelDelivered();
      await unsupported.setForeground(true);
      expect(await unsupported.openCurrentTaskRequests.isEmpty, isTrue);
      Object? caught;
      try {
        await unsupported.configure(
          on: true,
          perDay: NotificationsPerDay.one,
          language: LocaleChoice.system,
        );
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<NotificationGatewayException>());
      expect((caught! as NotificationGatewayException).unsupported, isTrue);
    });

    test('el proveedor da el canal en Android y el no soportado fuera', () {
      final android = ProviderContainer(
        overrides: [notificationsPlatformProvider.overrideWithValue(true)],
      );
      addTearDown(android.dispose);
      expect(
        android.read(notificationGatewayProvider),
        isA<ChannelNotificationGateway>(),
      );
      final other = ProviderContainer(
        overrides: [notificationsPlatformProvider.overrideWithValue(false)],
      );
      addTearDown(other.dispose);
      expect(
        other.read(notificationGatewayProvider),
        isA<UnsupportedNotificationGateway>(),
      );
    });
  });

  group('CA-019-08b: FakeNotificationGateway (los cuatro casos)', () {
    test('concedido: canNotify ya es verdadero y no se pide', () async {
      final fake = FakeNotificationGateway(FakePermission.granted);
      expect(await fake.canNotify(), isTrue);
      final r = await fake.requestPermission();
      expect((r.granted, r.dialogShown), (true, false));
    });

    test('diálogo con concesión: pide, sale el diálogo y desde entonces se '
        'puede', () async {
      final fake = FakeNotificationGateway(FakePermission.dialogGranted);
      expect(await fake.canNotify(), isFalse);
      final r = await fake.requestPermission();
      expect((r.granted, r.dialogShown), (true, true));
      expect(await fake.canNotify(), isTrue);
    });

    test(
      'diálogo con rechazo: pide, sale el diálogo y se sigue sin poder',
      () async {
        final fake = FakeNotificationGateway(FakePermission.dialogDenied);
        final r = await fake.requestPermission();
        expect((r.granted, r.dialogShown), (false, true));
        expect(await fake.canNotify(), isFalse);
      },
    );

    test('rechazo inmediato: sin diálogo y sin poder', () async {
      final fake = FakeNotificationGateway(FakePermission.deniedImmediately);
      final r = await fake.requestPermission();
      expect((r.granted, r.dialogShown), (false, false));
      expect(await fake.canNotify(), isFalse);
    });

    test('anota las llamadas y emite la orden de abrir', () async {
      final fake = FakeNotificationGateway(FakePermission.granted);
      await fake.configure(
        on: true,
        perDay: NotificationsPerDay.two,
        language: LocaleChoice.en,
      );
      await fake.setForeground(true);
      await fake.cancelDelivered();
      expect(fake.openSystemSettings(), completion(isTrue));
      expect(fake.configureCalls.single, (
        on: true,
        perDay: NotificationsPerDay.two,
        language: LocaleChoice.en,
      ));
      expect(fake.foregroundCalls, [true]);
      expect(fake.cancelDeliveredCalls, 1);
      final events = <void>[];
      final sub = fake.openCurrentTaskRequests.listen(events.add);
      fake.emitOpenCurrentTask();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });

    test('configure falla a demanda y puede quedarse esperando', () async {
      final fake = FakeNotificationGateway(FakePermission.granted)
        ..configureFailure = const NotificationGatewayException();
      await expectLater(
        fake.configure(
          on: true,
          perDay: NotificationsPerDay.one,
          language: LocaleChoice.system,
        ),
        throwsA(isA<NotificationGatewayException>()),
      );
      fake.configureFailure = null;
      final gate = fake.configureGate = Completer<void>();
      var done = false;
      unawaited(
        fake
            .configure(
              on: true,
              perDay: NotificationsPerDay.one,
              language: LocaleChoice.system,
            )
            .then((_) => done = true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });
}
