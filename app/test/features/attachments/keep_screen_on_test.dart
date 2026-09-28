import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/platform/screen_awake.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/keep_screen_on_controller.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
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

  Future<Task> pdfTask({String id = 't-pdf', String rank = 'M'}) async {
    final aid = 'p-$id';
    store
      ..putStaging(
        aid,
        'document.pdf',
        Uint8List.fromList('%PDF-1.7'.codeUnits),
      )
      ..putStaging(aid, 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: aid,
        byteSize: 2400000,
        pageCount: 12,
        width: 595,
        height: 842,
        originalName: 'Programa.pdf',
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(id: id, text: 'Programa', rank: rank);
    return base.withContent('Programa', attachment, base.updatedAt);
  }

  Future<void> pump(WidgetTester tester, {List<String> tasks = const []}) =>
      pumpUnaApp(
        tester,
        repo: repo,
        tasks: tasks,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          screenAwakeProvider.overrideWithValue(awake),
          pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
          ...fakePdfViews,
        ],
      ).then((_) => tester.pump());

  /// Gira la superficie del test (el giro nativo se prueba en el emulador).
  Future<void> turn(WidgetTester tester, {required bool landscape}) async {
    tester.view.physicalSize = landscape
        ? const Size(844, 390)
        : const Size(390, 844);
    await tester.pump();
    await tester.pump();
  }

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

  testWidgets('CA-007-12: con TalkBack, explorar tocando (hover táctil) '
      'reinicia los 10 minutos; un ratón, no', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    await tester.pump(const Duration(minutes: 9));
    final touch = TestPointer(1, PointerDeviceKind.touch);
    tester.binding.handlePointerEvent(touch.hover(const Offset(200, 400)));
    await tester.pump(const Duration(minutes: 9));
    expect(awake.on, isTrue);
    final mouse = TestPointer(2, PointerDeviceKind.mouse);
    tester.binding.handlePointerEvent(mouse.hover(const Offset(200, 400)));
    await tester.pump(const Duration(minutes: 1));
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
    await repo.remove((await repo.currentTask())!.id);
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

  group('CA-008-13: pantalla encendida con PDF', () {
    final pdfViewer = find.byKey(const Key('fake-task-pdf'));

    testWidgets('en vertical, la pantalla no se apaga; tras 10 minutos sin '
        'tocarla, sí', (tester) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      expect(pdfViewer, findsOneWidget);
      expect(awake.calls, [true]);

      await tester.pump(const Duration(minutes: 9, seconds: 59));
      expect(awake.on, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(awake.calls, [true, false]);
    });

    testWidgets('en horizontal, igual; girar no cuenta como tocar ni la '
        'apaga un momento', (tester) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      addTearDown(tester.view.reset);
      await tester.pump(const Duration(minutes: 5));

      await turn(tester, landscape: true);
      expect(pdfViewer, findsOneWidget);
      // Es el horizontal: sin menú (CA-008-11).
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(awake.calls, [true]);
      await tester.pump(const Duration(minutes: 4));
      await turn(tester, landscape: false);
      await turn(tester, landscape: true);
      expect(awake.calls, [true]);

      // Solo los toques reinician los 10 minutos (CA-007-12).
      await tester.pump(const Duration(minutes: 1));
      expect(awake.calls, [true, false]);
    });

    testWidgets('en horizontal, un toque en el PDF reinicia los 10 minutos', (
      tester,
    ) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      await tester.pump(const Duration(minutes: 9));
      await tester.tapAt(tester.getCenter(pdfViewer));
      await tester.pump(const Duration(minutes: 9));
      expect(awake.on, isTrue);
      await tester.pump(const Duration(minutes: 1));
      expect(awake.on, isFalse);

      // Pasados los 10 minutos, tocar la vuelve a mantener encendida.
      await tester.tapAt(tester.getCenter(pdfViewer));
      await tester.pump();
      expect(awake.on, isTrue);
      await tester.pump(const Duration(minutes: 10));
    });

    testWidgets('al abrir el menú, apagado normal; al cerrarlo, encendida', (
      tester,
    ) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      expect(awake.on, isTrue);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(awake.on, isFalse);
      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pumpAndSettle();
      expect(awake.on, isTrue);
      await tester.pump(const Duration(minutes: 10));
    });

    testWidgets('en horizontal y en segundo plano, apagado normal; al volver, '
        'encendida de nuevo', (tester) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
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

    testWidgets('al completar y pasar a una tarea sin adjunto, vuelve el '
        'apagado normal', (tester) async {
      await repo.insert(await pdfTask(rank: 'A'));
      await pump(tester, tasks: ['Siguiente']);
      expect(awake.on, isTrue);
      await repo.remove((await repo.currentTask())!.id);
      await tester.pumpAndSettle();
      expect(pdfViewer, findsNothing);
      expect(awake.on, isFalse);
    });

    testWidgets('con el ajuste desactivado, nunca, tampoco en horizontal', (
      tester,
    ) async {
      await repo.insert(await pdfTask());
      await repo.setKeepScreenOn(false);
      await pump(tester);
      addTearDown(tester.view.reset);
      await turn(tester, landscape: true);
      await tester.pump();
      expect(awake.calls, isEmpty);
    });
  });

  testWidgets('CA-008-18: con "Adjunto no disponible" (falta el PDF), apagado '
      'normal', (tester) async {
    await repo.insert(await pdfTask());
    store.removeFile('p-t-pdf', 'document.pdf');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Adjunto no disponible'), findsOneWidget);
    expect(find.byKey(const Key('fake-task-pdf')), findsNothing);
    expect(awake.on, isFalse);
    // Tampoco al tocar la pantalla.
    await tester.tapAt(const Offset(40, 40));
    await tester.pump();
    expect(awake.on, isFalse);
  });

  test('el ajuste está activo por defecto y se guarda', () async {
    final r = InMemoryTaskRepository();
    expect(await r.keepScreenOn(), isTrue);
    await r.setKeepScreenOn(false);
    expect(await r.keepScreenOn(), isFalse);
  });
}
