import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/platform/screen_awake.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/image_viewer_screen.dart';
import 'package:app/features/attachments/keep_screen_on_controller.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/pump_app.dart';

class _FakeAwake implements ScreenAwake {
  final calls = <bool>[];
  bool get on => calls.isNotEmpty && calls.last;

  @override
  Future<void> keepOn(bool on) async => calls.add(on);
}

void main() {
  late MemoryAttachmentStore store;
  late _FakeAwake awake;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    awake = _FakeAwake();
    repo = InMemoryTaskRepository();
  });

  Future<Task> imageTask({String id = 't-img', String rank = 'M'}) async {
    final attachment = await store.commit(
      stageImage(store, 'a-$id'),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(id: id, text: 'Horario', rank: rank);
    return base.withContent('Horario', attachment, base.updatedAt);
  }

  Future<void> pump(WidgetTester tester, {List<String> tasks = const []}) =>
      pumpUnaApp(
        tester,
        repo: repo,
        tasks: tasks,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          screenAwakeProvider.overrideWithValue(awake),
        ],
      ).then((_) => tester.pump());

  void setLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
    for (final s in states) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  testWidgets('CA-007-12: con la tarea actual con imagen, la pantalla no se '
      'apaga; tras 10 minutos sin tocarla, sí', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    expect(awake.calls, [true]);

    await tester.pump(const Duration(minutes: 9, seconds: 59));
    expect(awake.on, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(awake.calls, [true, false]);
  });

  testWidgets('CA-007-12: cada toque reinicia los 10 minutos', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    await tester.pump(const Duration(minutes: 9));
    // Un toque en cualquier parte (aquí, el logotipo).
    await tester.tapAt(const Offset(40, 40));
    await tester.pump(const Duration(minutes: 9));
    expect(awake.on, isTrue);
    await tester.pump(const Duration(minutes: 1));
    expect(awake.on, isFalse);

    // Pasados los 10 minutos, tocar la vuelve a mantener encendida.
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(awake.on, isTrue);
    await tester.pump(const Duration(minutes: 10));
  });

  testWidgets('CA-007-12: en el visor también', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    await tester.tap(find.byType(TaskImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    expect(awake.on, isTrue);
    await tester.pump(const Duration(minutes: 10));
    expect(awake.on, isFalse);
  });

  testWidgets('CA-007-12: al abrir el menú, el editor o el listado vuelve el '
      'apagado normal; al volver, no', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester, tasks: ['Otra']);
    expect(awake.on, isTrue);

    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    expect(awake.on, isFalse);
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    expect(awake.on, isFalse);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(awake.on, isTrue);

    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(awake.on, isFalse);
  });

  testWidgets('CA-007-12: en segundo plano, apagado normal; al volver, '
      'encendida de nuevo', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    setLifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();
    expect(awake.on, isFalse);
    setLifecycle(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(awake.on, isTrue);
    await tester.pump(const Duration(minutes: 10));
  });

  testWidgets('CA-007-12: con una tarea sin imagen, nunca', (tester) async {
    await pump(tester, tasks: ['Llamar']);
    await tester.pump(const Duration(seconds: 1));
    expect(awake.calls, isEmpty);
  });

  testWidgets('CA-007-12: al completar y pasar a una tarea sin imagen, vuelve '
      'el apagado normal', (tester) async {
    await repo.insert(await imageTask(rank: 'A'));
    await pump(tester, tasks: ['Siguiente']);
    expect(awake.on, isTrue);
    final container = tester.element(find.byType(TaskImage));
    await repo.complete(
      (await repo.currentTask())!.id,
      DateTime.utc(2026, 9, 26),
    );
    await tester.pumpAndSettle();
    expect(container.mounted, isFalse);
    expect(awake.on, isFalse);
  });

  testWidgets('CA-007-12: con el ajuste desactivado, nunca', (tester) async {
    await repo.insert(await imageTask());
    await repo.setKeepScreenOn(false);
    await pump(tester);
    await tester.pump();
    expect(awake.calls, isEmpty);
  });

  test('el ajuste está activo por defecto y se guarda', () async {
    final r = InMemoryTaskRepository();
    expect(await r.keepScreenOn(), isTrue);
    await r.setKeepScreenOn(false);
    expect(await r.keepScreenOn(), isFalse);
  });
}
