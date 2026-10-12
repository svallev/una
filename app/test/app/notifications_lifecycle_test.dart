import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/ports/notification_gateway.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_harness.dart' show notificationsOverrides;
import '../features/task_list/list_harness.dart' show openList;
import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';
import '../support/fonts.dart';

/// Ciclo de vida de las notificaciones en `UnaApp` (spec 019, T-019-12):
/// indicador «a la vista», quitar la notificación de la bandeja al volver,
/// reconciliar lo programado y la orden de abrir la tarea actual.

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final s in states) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// Segundo plano de verdad: `inactive` → `hidden` → `paused`.
void _goBackground(WidgetTester tester) => _lifecycle(tester, const [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
]);

/// Vuelta a primer plano: `hidden` → `inactive` → `resumed`.
void _comeBack(WidgetTester tester) => _lifecycle(tester, const [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
]);

Future<InMemoryTaskRepository> _pump(
  WidgetTester tester,
  FakeNotificationGateway gateway, {
  List<String> tasks = const ['Llamar a Marta'],
  bool on = false,
  NotificationsPerDay perDay = NotificationsPerDay.one,
  LocaleChoice language = LocaleChoice.system,
  bool flag = true,
  bool platform = true,
  bool firstFrameOnly = false,
}) async {
  final repo = InMemoryTaskRepository();
  await repo.setNotificationsOn(on);
  await repo.setNotificationsPerDay(perDay);
  await repo.setLocale(language);
  await pumpUnaApp(
    tester,
    repo: repo,
    tasks: tasks,
    overrides: notificationsOverrides(
      gateway: gateway,
      flag: flag,
      platform: platform,
    ),
    firstFrameOnly: firstFrameOnly,
  );
  return repo;
}

void main() {
  setUpAll(loadAppFonts);

  group('arranque', () {
    testWidgets(
      'CA-019-24: antes del primer fotograma no se llama al canal; después, '
      'a la vista, quitar la notificación y reconciliar',
      (tester) async {
        final gateway = FakeNotificationGateway();
        var callsAtFirstPostFrame = -1;
        // Se registra antes de montar: corre antes que los de la app.
        tester.binding.addPostFrameCallback((_) {
          callsAtFirstPostFrame =
              gateway.foregroundCalls.length +
              gateway.cancelDeliveredCalls +
              gateway.configureCalls.length;
        });
        await _pump(tester, gateway, on: true, firstFrameOnly: true);
        await tester.pump();
        expect(callsAtFirstPostFrame, 0);
        expect(gateway.foregroundCalls, [true]);
        expect(gateway.cancelDeliveredCalls, 1);
        expect(gateway.configureCalls, hasLength(1));
      },
    );

    testWidgets(
      'CA-019-13: la reconciliación lleva los ajustes guardados (activo, '
      'cantidad e idioma)',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(
          tester,
          gateway,
          on: true,
          perDay: NotificationsPerDay.three,
          language: LocaleChoice.en,
        );
        expect(gateway.configureCalls, [
          (
            on: true,
            perDay: NotificationsPerDay.three,
            language: LocaleChoice.en,
          ),
        ]);
      },
    );

    testWidgets(
      'CA-019-13: con el ajuste apagado también se reconcilia (cancela lo '
      'que pudiera quedar programado)',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway);
        expect(gateway.configureCalls, [
          (
            on: false,
            perDay: NotificationsPerDay.one,
            language: LocaleChoice.system,
          ),
        ]);
      },
    );

    testWidgets(
      'CA-019-13: se reconcilia una sola vez por arranque, no en cada vuelta '
      'a primer plano',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        for (var i = 0; i < 3; i++) {
          _goBackground(tester);
          _comeBack(tester);
          await tester.pump();
        }
        expect(gateway.configureCalls, hasLength(1));
      },
    );

    testWidgets(
      'CA-019-13: si reconciliar falla, la pantalla sigue igual, sin error '
      'ni excepción',
      (tester) async {
        final gateway = FakeNotificationGateway()
          ..configureFailure = const NotificationGatewayException();
        await _pump(tester, gateway, on: true);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);
        // Los demás avisos al nativo no dependen de la reconciliación.
        expect(gateway.foregroundCalls, [true]);
        expect(gateway.cancelDeliveredCalls, 1);
      },
    );

    testWidgets(
      'CA-019-28: con el indicador apagado o fuera de Android no se llama '
      'al canal',
      (tester) async {
        for (final (flag, platform) in [(false, true), (true, false)]) {
          final gateway = FakeNotificationGateway();
          await _pump(
            tester,
            gateway,
            on: true,
            flag: flag,
            platform: platform,
          );
          _goBackground(tester);
          _comeBack(tester);
          await tester.pump();
          gateway.emitOpenCurrentTask();
          await tester.pump();
          expect(gateway.foregroundCalls, isEmpty);
          expect(gateway.cancelDeliveredCalls, 0);
          expect(gateway.configureCalls, isEmpty);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('a la vista y notificación en la bandeja', () {
    testWidgets(
      'CA-019-19a/19b: al volver a primer plano se avisa "a la vista" y se '
      'quita la notificación; al pasar a segundo plano, "no a la vista"',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        expect(gateway.foregroundCalls, [true]);
        expect(gateway.cancelDeliveredCalls, 1);

        _goBackground(tester);
        await tester.pump();
        expect(gateway.foregroundCalls, [true, false]);
        expect(gateway.cancelDeliveredCalls, 1);

        _comeBack(tester);
        await tester.pump();
        expect(gateway.foregroundCalls, [true, false, true]);
        expect(gateway.cancelDeliveredCalls, 2);

        _goBackground(tester);
        _comeBack(tester);
        await tester.pump();
        expect(gateway.foregroundCalls, [true, false, true, false, true]);
        expect(gateway.cancelDeliveredCalls, 3);
      },
    );

    testWidgets(
      'CA-019-19a: la cortina y los diálogos del sistema (inactive) no sacan '
      'la app de la vista ni quitan nada',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        _lifecycle(tester, const [AppLifecycleState.inactive]);
        await tester.pump();
        _lifecycle(tester, const [AppLifecycleState.resumed]);
        await tester.pump();
        expect(gateway.foregroundCalls, [true]);
        expect(gateway.cancelDeliveredCalls, 1);
      },
    );

    testWidgets(
      'CA-019-19b: con el interruptor apagado también se avisa y se quita '
      '(lo nativo ignora el indicador si está apagado)',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway);
        _goBackground(tester);
        _comeBack(tester);
        await tester.pump();
        expect(gateway.foregroundCalls, [true, false, true]);
        expect(gateway.cancelDeliveredCalls, 2);
      },
    );
  });

  group('tocar la notificación', () {
    testWidgets(
      'CA-019-20: con el listado abierto, la orden lleva a la tarea actual '
      'sin abrir ninguna ruta nueva',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await openList(
          tester,
          tasks: ['Llamar a Marta', 'Comprar pan'],
          overrides: notificationsOverrides(gateway: gateway),
        );
        expect(find.byType(TaskListScreen), findsOneWidget);
        final cancelled = gateway.cancelDeliveredCalls;

        gateway.emitOpenCurrentTask();
        await tester.pumpAndSettle();

        expect(find.byType(TaskListScreen), findsNothing);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(CurrentTaskScreen))).canPop(),
          isFalse,
        );
        // Sin importar los minutos: no hay ninguna espera de 10 min.
        expect(gateway.cancelDeliveredCalls, greaterThan(cancelled));
        // Deja correr los temporizadores de la app (barrido de adjuntos).
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'CA-019-20: con el editor de otra tarea abierto, se pierde el borrador '
      'y vuelve la tarea actual',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nueva tarea'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Borrador');
        await tester.pump();

        _goBackground(tester);
        await tester.pump(const Duration(minutes: 5));
        _comeBack(tester);
        gateway.emitOpenCurrentTask();
        await tester.pumpAndSettle();

        expect(find.text('Borrador'), findsNothing);
        expect(find.byType(TaskEditorScreen), findsNothing);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text('Llamar a Marta'), findsOneWidget);
      },
    );

    testWidgets(
      'CA-019-20: con Ajustes abierto, la orden lleva a la tarea actual',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        gateway.emitOpenCurrentTask();
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CA-019-20: sin tareas, la orden lleva al editor de la primera tarea '
      'y descarta lo escrito',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, tasks: const [], on: true);
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Borrador');
        await tester.pump();

        gateway.emitOpenCurrentTask();
        await tester.pumpAndSettle();

        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('Borrador'), findsNothing);
        expect(
          Navigator.of(tester.element(find.byType(TaskEditorScreen))).canPop(),
          isFalse,
        );
      },
    );

    testWidgets(
      'CA-019-20: la orden también quita la notificación (CA-019-19b)',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        final before = gateway.cancelDeliveredCalls;
        gateway.emitOpenCurrentTask();
        await tester.pumpAndSettle();
        expect(gateway.cancelDeliveredCalls, greaterThan(before));
      },
    );

    testWidgets(
      'CA-019-20: dos órdenes seguidas no dejan nada raro (la tarea actual '
      'sigue a la vista)',
      (tester) async {
        final gateway = FakeNotificationGateway();
        await _pump(tester, gateway, on: true);
        gateway
          ..emitOpenCurrentTask()
          ..emitOpenCurrentTask();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
      },
    );
  });
}
