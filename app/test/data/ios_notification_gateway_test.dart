import 'dart:async';
import 'dart:ui' show Locale;

import 'package:app/data/platform/ios_notification_gateway.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/domain/services/notification_content.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart' show sampleTask;

/// El programador de notificaciones de iOS en Dart (spec 028, T-028-18,
/// CA-028-15 y 16, ADR-0030, `channel-contract.md` §4): qué se manda a
/// `configure`, cuándo se reprograma, la agrupación de cambios seguidos y que
/// se cancela todo al apagar o sin tareas. El reloj es el falso de
/// `testWidgets` (los `Timer` avanzan con `tester.pump`).

const _channel = MethodChannel('una/notifications');
const _delay = IosNotificationGateway.defaultSettleDelay;
const _offArgs = {'on': false, 'slots': <Object?>[]};

NotificationTexts _texts(LocaleChoice choice) {
  final l10n = lookupAppLocalizations(
    Locale(choice == LocaleChoice.en ? 'en' : 'es'),
  );
  return NotificationTexts(
    title: l10n.notificationTitle,
    publicBody: l10n.notificationPublic,
    photo: l10n.attachmentPhoto,
    image: l10n.attachmentImage,
    pdf: l10n.attachmentPdf,
  );
}

/// La tarea actual de mentira y sus cambios.
class _Tasks {
  Task? current = sampleTask(text: 'Llamar a Marta');
  int reads = 0;
  Object? readFailure;
  final changes = StreamController<Task?>.broadcast();

  Future<Task?> read() async {
    reads++;
    final failure = readFailure;
    if (failure != null) throw failure;
    return current;
  }

  void change(String? text) {
    current = text == null ? null : sampleTask(text: text);
    changes.add(current);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late _Tasks tasks;
  late IosNotificationGateway gateway;

  /// Las llamadas a `configure` (las de `setForeground`, aparte).
  List<Map<Object?, Object?>> configures() => [
    for (final c in calls)
      if (c.method == 'configure') c.arguments as Map<Object?, Object?>,
  ];

  List<String?> bodies(Map<Object?, Object?> args) => [
    for (final s in args['slots']! as List<Object?>)
      (s! as Map<Object?, Object?>)['body'] as String?,
  ];

  void answer(Future<Object?> Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call);
      return reply(call);
    });
  }

  void setUpGateway() {
    calls = [];
    tasks = _Tasks();
    answer((_) async => null);
    gateway = IosNotificationGateway(
      readCurrentTask: tasks.read,
      currentTaskChanges: tasks.changes.stream,
      textsFor: _texts,
    );
  }

  void tearDownGateway() {
    gateway.dispose();
    unawaited(tasks.changes.close());
    messenger.setMockMethodCallHandler(_channel, null);
  }

  Future<void> configure({
    bool on = true,
    NotificationsPerDay perDay = NotificationsPerDay.one,
    LocaleChoice language = LocaleChoice.es,
  }) => gateway.configure(on: on, perDay: perDay, language: language);

  /// Todo se crea **dentro** del test: un `Future` o un `Stream` creados en
  /// `setUp` (fuera de la zona de tiempo falso) no avanzan con `pump`.
  void gatewayTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    setUpGateway();
    try {
      await body(tester);
    } finally {
      tearDownGateway();
    }
  });

  /// Deja correr las microtareas (el `Stream`, la cola y el canal).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  group('CA-028-16: lo que se programa', () {
    gatewayTest('encendido: un aviso por hora con el título, la tarea y la '
        'versión genérica para la pantalla de bloqueo', (tester) async {
      await configure(perDay: NotificationsPerDay.three);
      expect(configures(), [
        {
          'on': true,
          'slots': [
            for (final (h, m) in [(8, 55), (13, 55), (18, 55)])
              {
                'hour': h,
                'minute': m,
                'title': 'Tarea actual',
                'body': 'Llamar a Marta',
                'publicBody': 'Tienes una tarea pendiente.',
              },
          ],
        },
      ]);
    });

    gatewayTest('CA-019-21: en el idioma pedido', (tester) async {
      tasks.current = Task(
        id: 'p',
        text: null,
        status: TaskStatus.pending,
        rank: 'V',
        colorKey: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await configure(language: LocaleChoice.en);
      final slot =
          (configures().single['slots']! as List<Object?>).single!
              as Map<Object?, Object?>;
      expect(slot['title'], 'Current task');
      expect(slot['publicBody'], 'You have a task waiting.');
      // Sin texto ni adjunto: el cuerpo es el genérico.
      expect(slot['body'], 'You have a task waiting.');
    });

    gatewayTest('CA-019-15: sin tarea actual, encendido pero sin avisos '
        '(lo nativo cancela todo y quita lo entregado)', (tester) async {
      tasks.current = null;
      await configure(perDay: NotificationsPerDay.three);
      expect(configures(), [
        {'on': true, 'slots': <Object?>[]},
      ]);
    });

    gatewayTest('CA-019-02: apagado no lee la tarea y manda la lista '
        'vacía', (tester) async {
      await configure(on: false, perDay: NotificationsPerDay.three);
      expect(configures(), [
        {'on': false, 'slots': <Object?>[]},
      ]);
      expect(tasks.reads, 0);
    });

    gatewayTest('cada configure se manda aunque no cambie nada (Ajustes y el '
        'arranque esperan su respuesta)', (tester) async {
      await configure();
      await configure();
      expect(configures(), hasLength(2));
    });

    gatewayTest('los demás métodos son los del canal de Android', (
      tester,
    ) async {
      answer((call) async => call.method == 'canNotify' ? true : null);
      expect(await gateway.canNotify(), isTrue);
      await gateway.cancelDelivered();
      await gateway.setForeground(true);
      expect(calls.map((c) => c.method), [
        'canNotify',
        'cancelDelivered',
        'setForeground',
      ]);
      expect(calls.last.arguments, true);
    });
  });

  group('CA-028-16: se reprograma al cambiar la tarea actual', () {
    gatewayTest('un cambio sale tras la espera, con el texto nuevo', (
      tester,
    ) async {
      await configure();
      calls.clear();
      tasks.change('Comprar pan');
      await settle(tester);
      expect(configures(), isEmpty, reason: 'aún dentro de la espera');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures().map(bodies), [
        ['Comprar pan'],
      ]);
    });

    gatewayTest('los cambios seguidos se agrupan en una sola llamada', (
      tester,
    ) async {
      await configure(perDay: NotificationsPerDay.two);
      calls.clear();
      // Eliminar, deshacer y reordenar seguidos.
      tasks.change(null);
      await tester.pump(const Duration(milliseconds: 50));
      tasks.change('Llamar a Marta');
      await tester.pump(const Duration(milliseconds: 50));
      tasks.change('Regar las plantas');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures().map(bodies), [
        ['Regar las plantas', 'Regar las plantas'],
      ]);
      // Un cambio después de la llamada abre otra espera.
      tasks.change('Otra');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), hasLength(2));
    });

    gatewayTest('completar la última tarea quita su texto de la '
        'programación', (tester) async {
      await configure(perDay: NotificationsPerDay.three);
      calls.clear();
      tasks.change(null);
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), [
        {'on': true, 'slots': <Object?>[]},
      ]);
    });

    gatewayTest('si lo que hay que programar no cambió, no se llama', (
      tester,
    ) async {
      await configure();
      calls.clear();
      tasks.change('Llamar a Marta');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), isEmpty);
    });

    gatewayTest('antes del primer configure (arranque) no se reprograma', (
      tester,
    ) async {
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(calls, isEmpty);
    });

    gatewayTest('con el ajuste apagado no se reprograma', (tester) async {
      await configure(on: false);
      calls.clear();
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(calls, isEmpty);
    });

    gatewayTest('apagar durante la espera: no sale nada más', (tester) async {
      await configure();
      calls.clear();
      tasks.change('Comprar pan');
      await settle(tester);
      await configure(on: false);
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), [_offArgs]);
    });

    gatewayTest('en segundo plano sale sin esperar, y lo pendiente sale al '
        'irse', (tester) async {
      await configure();
      calls.clear();
      tasks.change('Comprar pan');
      await settle(tester);
      expect(configures(), isEmpty);
      await gateway.setForeground(false);
      await settle(tester);
      expect(configures().map(bodies), [
        ['Comprar pan'],
      ]);
      tasks.change('Regar');
      await settle(tester);
      expect(configures().map(bodies).last, ['Regar']);
      expect(configures(), hasLength(2));
      // De vuelta a la vista, vuelve a esperar.
      await gateway.setForeground(true);
      tasks.change('Leer');
      await settle(tester);
      expect(configures(), hasLength(2));
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), hasLength(3));
    });

    gatewayTest('un fallo al reprogramar no lanza y el cambio siguiente lo '
        'reintenta', (tester) async {
      await configure();
      calls.clear();
      answer((_) async => throw PlatformException(code: 'failed'));
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(tester.takeException(), isNull);
      answer((_) async => null);
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures().map(bodies), [
        ['Comprar pan'],
        ['Comprar pan'],
      ]);
    });

    gatewayTest('tras dispose ya no se reprograma', (tester) async {
      await configure();
      calls.clear();
      tasks.change('Comprar pan');
      gateway.dispose();
      await tester.pump(_delay);
      await settle(tester);
      expect(calls, isEmpty);
    });

    gatewayTest('las llamadas van una tras otra y la última manda', (
      tester,
    ) async {
      await configure();
      calls.clear();
      final gate = Completer<void>();
      answer((_) => gate.future.then((_) => null));
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(configures(), hasLength(1));
      // Ajustes apaga mientras la reprogramación sigue en el canal.
      final off = configure(on: false);
      await settle(tester);
      expect(configures(), hasLength(1), reason: 'espera a la anterior');
      gate.complete();
      await off;
      expect(configures().last, _offArgs);
    });
  });

  group('CA-019-23: los fallos no llevan texto', () {
    gatewayTest('un error del canal es NotificationGatewayException sin '
        'mensaje', (tester) async {
      answer(
        (_) async => throw PlatformException(
          code: 'failed',
          message: 'Llamar a Marta',
          details: 'Llamar a Marta',
        ),
      );
      Object? caught;
      try {
        await configure();
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<NotificationGatewayException>());
      expect((caught! as NotificationGatewayException).unsupported, isFalse);
      expect(caught.toString().contains('Marta'), isFalse);
    });

    gatewayTest('sin el canal nativo: unsupported', (tester) async {
      answer((_) async => throw MissingPluginException());
      await expectLater(
        configure(),
        throwsA(
          isA<NotificationGatewayException>().having(
            (e) => e.unsupported,
            'unsupported',
            isTrue,
          ),
        ),
      );
    });

    gatewayTest('si no se puede leer la tarea, falla sin el error de la BD y '
        'sin llamar al canal', (tester) async {
      tasks.readFailure = StateError('SELECT … Llamar a Marta');
      Object? caught;
      try {
        await configure();
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<NotificationGatewayException>());
      expect(caught.toString().contains('Marta'), isFalse);
      expect(configures(), isEmpty);
    });

    gatewayTest('un configure que falla no cambia los ajustes con los que se '
        'reprograma', (tester) async {
      answer((_) async => throw PlatformException(code: 'failed'));
      await expectLater(
        configure(),
        throwsA(isA<NotificationGatewayException>()),
      );
      answer((_) async => null);
      calls.clear();
      tasks.change('Comprar pan');
      await tester.pump(_delay);
      await settle(tester);
      expect(calls, isEmpty, reason: 'no hubo ningún encendido que saliera');
    });
  });
}
