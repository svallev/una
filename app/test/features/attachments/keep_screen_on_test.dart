import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/platform/screen_awake.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/keep_screen_on_controller.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
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
  late FakeWebPages web;

  setUp(() async {
    web = FakeWebPages();
    store = MemoryAttachmentStore();
    awake = _FakeAwake();
    // "Pantalla siempre activa" está apagada por defecto (CA-015-05); casi
    // todos estos tests parten de ella encendida en Ajustes.
    repo = InMemoryTaskRepository();
    await repo.setKeepScreenOn(true);
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
          ...web.overrides,
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

  testWidgets('CA-015-04a: con la tarea actual con imagen, la pantalla no se '
      'apaga, ni tras 60 minutos sin tocarla', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    expect(awake.calls, [true]);

    await tester.pump(const Duration(minutes: 9, seconds: 59));
    expect(awake.on, isTrue);
    await tester.pump(const Duration(minutes: 50, seconds: 1));
    // Sin límite: ni se retira ni se vuelve a pedir.
    expect(awake.calls, [true]);
  });

  testWidgets('CA-015-04a: los toques ya no cuentan: no hay temporizador que '
      'reiniciar', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    await tester.pump(const Duration(minutes: 9));
    await tester.tapAt(const Offset(40, 40));
    final touch = TestPointer(1, PointerDeviceKind.touch);
    tester.binding.handlePointerEvent(touch.hover(const Offset(200, 400)));
    await tester.pump(const Duration(minutes: 30));
    expect(awake.calls, [true]);
    // Ningún temporizador pendiente del controlador (el test lo comprueba al
    // terminar): no hace falta avanzar el reloj más.
  });

  testWidgets('CA-015-04b: con el ajuste apagado (por defecto) nunca, ni con '
      'una imagen', (tester) async {
    repo = InMemoryTaskRepository();
    expect(await repo.keepScreenOn(), isFalse);
    await repo.insert(await imageTask());
    await pump(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(awake.calls, isEmpty);
  });

  testWidgets('CA-015-04c: cambiar el ajuste se nota al volver a la tarea, '
      'sin reiniciar la app', (tester) async {
    await repo.setKeepScreenOn(false);
    await repo.insert(await imageTask());
    await pump(tester, tasks: ['Otra']);
    expect(awake.calls, isEmpty);

    // Como en Ajustes: se enciende con la tarea debajo (la ruta de Ajustes la
    // dejaría fuera de la vista) y se ve al volver.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskImage)),
    );
    expect(
      await container.read(settingsProvider.notifier).setKeepScreenOn(true),
      SaveResult.saved,
    );
    await tester.pump();
    expect(awake.on, isTrue);

    // Y al apagarlo se suelta.
    await container.read(settingsProvider.notifier).setKeepScreenOn(false);
    await tester.pump();
    expect(awake.calls, [true, false]);
  });

  testWidgets('CA-015-04c: con un ajuste encendido y una tarea solo de texto, '
      'nunca', (tester) async {
    await pump(tester, tasks: ['Llamar']);
    await tester.pump(const Duration(minutes: 30));
    expect(awake.calls, isEmpty);
  });

  testWidgets('CA-015-04d: con inactive, hidden y paused se retira la '
      'petición, y resumed la restablece', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    expect(awake.on, isTrue);
    // Las transiciones válidas de Flutter: cada paso, por separado.
    for (final (state, expected) in [
      (AppLifecycleState.inactive, false),
      (AppLifecycleState.hidden, false),
      (AppLifecycleState.paused, false),
      (AppLifecycleState.hidden, false),
      (AppLifecycleState.inactive, false),
      (AppLifecycleState.resumed, true),
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      expect(awake.on, expected, reason: '$state');
    }
  });

  testWidgets('CA-015-04d: el dispose del controlador libera la petición', (
    tester,
  ) async {
    await repo.insert(await imageTask());
    await pump(tester);
    expect(awake.on, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(awake.on, isFalse);
  });

  testWidgets('CA-015-04c: al abrir el menú, el editor o el listado vuelve el '
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

  testWidgets('CA-015-04c: al abrir Ajustes vuelve el apagado normal; al '
      'cerrarlos, la pantalla se mantiene encendida', (tester) async {
    await repo.insert(await imageTask());
    await pump(tester);
    expect(awake.on, isTrue);

    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cerrar ajustes'), findsOneWidget);
    expect(awake.on, isFalse);

    await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
    await tester.pumpAndSettle();
    expect(awake.on, isTrue);
  });

  testWidgets('CA-015-04d: en segundo plano, apagado normal; al volver, '
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
  });

  testWidgets('CA-015-04c: con una tarea sin imagen, nunca', (tester) async {
    await pump(tester, tasks: ['Llamar']);
    await tester.pump(const Duration(seconds: 1));
    expect(awake.calls, isEmpty);
  });

  testWidgets('CA-015-04c: al completar y pasar a una tarea sin imagen, vuelve '
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

  testWidgets('CA-015-04b: con el ajuste desactivado, nunca', (tester) async {
    await repo.insert(await imageTask());
    await repo.setKeepScreenOn(false);
    await pump(tester);
    await tester.pump();
    expect(awake.calls, isEmpty);
  });

  group('CA-015-04a: pantalla encendida con PDF', () {
    final pdfViewer = find.byKey(const Key('fake-task-pdf'));

    testWidgets('CA-015-04a: en vertical, la pantalla no se apaga, ni tras 60 '
        'minutos sin tocarla', (tester) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      expect(pdfViewer, findsOneWidget);
      expect(awake.calls, [true]);

      await tester.pump(const Duration(minutes: 60));
      expect(awake.calls, [true]);
    });

    testWidgets('CA-015-04a: en horizontal, igual; girar no la apaga un '
        'momento', (tester) async {
      await repo.insert(await pdfTask());
      await pump(tester);
      addTearDown(tester.view.reset);
      await tester.pump(const Duration(minutes: 5));

      await turn(tester, landscape: true);
      expect(pdfViewer, findsOneWidget);
      // Es el horizontal: sin menú (CA-008-11).
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(awake.calls, [true]);
      await turn(tester, landscape: false);
      await turn(tester, landscape: true);
      await tester.pump(const Duration(minutes: 60));
      expect(awake.calls, [true]);
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

  group('CA-015-04a: pantalla encendida con la web', () {
    const address = 'https://www.congreso.ejemplo.com/programa';
    // Mientras carga, la vista está montada pero fuera del escenario.
    final view = find.byKey(const ValueKey('web-view-0'), skipOffstage: false);

    Task webTask({String rank = 'M'}) {
      final at = DateTime.utc(2026, 9, 29, 9);
      return Task(
        id: 'w',
        text: null,
        status: TaskStatus.pending,
        rank: rank,
        colorKey: 3,
        createdAt: at,
        updatedAt: at,
        attachment: attachmentFrom(StagedWeb(id: 'a-w', url: address), at),
      );
    }

    testWidgets('CA-015-04a: en vertical, la pantalla no se apaga, ni tras 60 '
        'minutos sin tocarla', (tester) async {
      await repo.insert(webTask());
      await pump(tester);
      await tester.pump();
      expect(view, findsOneWidget);
      expect(awake.calls, [true]);

      await tester.pump(const Duration(minutes: 60));
      expect(awake.calls, [true]);
    });

    testWidgets('CA-015-04a: en horizontal, igual; girar no la apaga un '
        'momento', (tester) async {
      await repo.insert(webTask());
      await pump(tester);
      addTearDown(tester.view.reset);
      await tester.pump();
      web.last
        ..started(address)
        ..finished(address);
      await tester.pump(const Duration(minutes: 5));

      await turn(tester, landscape: true);
      expect(view, findsOneWidget);
      expect(find.bySemanticsLabel('Menú de la tarea'), findsNothing);
      expect(awake.calls, [true]);
      await tester.pump(const Duration(minutes: 60));
      expect(awake.calls, [true]);
    });

    testWidgets('al abrir el menú, apagado normal; al cerrarlo, encendida', (
      tester,
    ) async {
      await repo.insert(webTask());
      await pump(tester);
      expect(awake.on, isTrue);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(awake.on, isFalse);
      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await tester.pumpAndSettle();
      expect(awake.on, isTrue);
    });

    testWidgets('en segundo plano, apagado normal; al volver, encendida', (
      tester,
    ) async {
      await repo.insert(webTask());
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
    });

    testWidgets('con un aviso en lugar de la página, sigue encendida (se ve '
        'la tarea web)', (tester) async {
      await repo.insert(webTask());
      await pump(tester);
      await tester.pump();
      web.last
        ..started(address)
        ..error(WebLoadError.hostLookup);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(awake.on, isTrue);
    });

    testWidgets('al completar y pasar a una tarea sin adjunto, vuelve el '
        'apagado normal', (tester) async {
      await repo.insert(webTask(rank: 'A'));
      await pump(tester, tasks: ['Siguiente']);
      expect(awake.on, isTrue);
      await repo.remove('w');
      await tester.pumpAndSettle();
      expect(view, findsNothing);
      expect(awake.on, isFalse);
    });

    testWidgets('con el ajuste desactivado, nunca, tampoco en horizontal', (
      tester,
    ) async {
      await repo.insert(webTask());
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

  test('CA-015-05: el ajuste está apagado por defecto y se guarda', () async {
    final r = InMemoryTaskRepository();
    expect(await r.keepScreenOn(), isFalse);
    await r.setKeepScreenOn(true);
    expect(await r.keepScreenOn(), isTrue);
  });
}
