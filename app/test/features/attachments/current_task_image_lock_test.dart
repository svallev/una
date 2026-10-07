import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Bloquear zoom en la pantalla principal con una imagen suelta (T-017-04b,
/// CA-017-07, 09, 11 y 12; CL-017-11 y 12): el bloqueo quita el contacto, no
/// las órdenes deliberadas, y encender o apagar no mueve la foto.
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    repo = InMemoryTaskRepository();
  });

  Future<Task> imageTask({int width = 1080, int height = 20000}) async {
    final attachment = await store.commit(
      stageImage(store, 'a1', width: width, height: height),
      DateTime.utc(2026, 10, 7),
    );
    final base = sampleTask(text: 'Horario del festival');
    return base.withContent('Horario del festival', attachment, base.updatedAt);
  }

  /// La app entera con la imagen como tarea actual. Con [lock], el ajuste ya
  /// está guardado antes de arrancar (el arranque en frío, CA-017-11).
  Future<void> pumpApp(
    WidgetTester tester, {
    bool lock = false,
    bool reduced = false,
    bool firstFrameOnly = false,
    Task? task,
  }) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, (_) async => null)
      ..setMockMethodCallHandler(const MethodChannel('una/screen'), (_) async {
        return null;
      });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
    });
    await repo.insert(task ?? await imageTask());
    if (lock) await repo.setLockZoom(true);
    await pumpUnaApp(
      tester,
      repo: repo,
      reduced: reduced,
      firstFrameOnly: firstFrameOnly,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
  }

  Finder scrollable() => find.descendant(
    of: find.byType(TaskImage),
    matching: find.byType(Scrollable),
  );
  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(scrollable()).position.pixels;

  Matrix4 zoomMatrix(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ZoomablePhoto),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;

  /// Lo que se ve: zoom, desplazamiento y posición de la foto.
  String look(WidgetTester tester) =>
      '${zoomMatrix(tester).storage}|${offset(tester)}|'
      '${tester.getRect(find.descendant(of: find.byType(ZoomablePhoto), matching: find.byType(Image)).first)}';

  Future<void> setLock(WidgetTester tester, bool value) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskImage)),
    );
    await container.read(settingsProvider.notifier).setLockZoom(value);
    await tester.pumpAndSettle();
  }

  /// Las acciones del nodo de la tarea, en el orden del lector.
  String actionsOf(WidgetTester tester) {
    final data = tester.getSemantics(find.byType(TaskImage)).getSemanticsData();
    final custom = [
      for (final id in data.customSemanticsActionIds ?? <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    final standard = [
      for (final a in [
        SemanticsAction.scrollUp,
        SemanticsAction.scrollDown,
        SemanticsAction.scrollLeft,
        SemanticsAction.scrollRight,
        SemanticsAction.focus,
      ])
        if (data.hasAction(a)) a.name,
    ];
    return '${standard.join(',')}|${custom.join(',')}';
  }

  Future<void> pinchAndDrag(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(TaskImage));
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 31,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 32,
    );
    for (var i = 1; i <= 8; i++) {
      await a.moveBy(const Offset(-6, 0));
      await b.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 16));
    final drag = await tester.startGesture(center, pointer: 33);
    for (var i = 1; i <= 8; i++) {
      await drag.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pump(const Duration(milliseconds: 16));
  }

  group('CA-017-09: con el bloqueo, las órdenes deliberadas siguen', () {
    testWidgets('el nodo de la tarea desplaza con scrollUp y scrollDown', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, lock: true);
      await tester.pumpAndSettle();
      expect(actionsOf(tester), startsWith('scrollUp,'));
      tester.semantics.scrollUp(
        scrollable: find.semantics.byLabel(RegExp('Tarea actual')),
      );
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(844 * 0.8, 0.5));
      expect(actionsOf(tester), startsWith('scrollUp,scrollDown'));
      tester.semantics.scrollDown(
        scrollable: find.semantics.byLabel(RegExp('Tarea actual')),
      );
      await tester.pumpAndSettle();
      expect(offset(tester), 0);
      handle.dispose();
    });

    for (final lock in [false, true]) {
      testWidgets('las mismas acciones y en el mismo orden (bloqueo: $lock)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester, lock: lock);
        await tester.pumpAndSettle();
        // Siempre las mismas (Completar y Eliminar, en este orden) y, con la
        // foto alta, desplazar adelante; sin el bloqueo es igual.
        expect(
          actionsOf(tester),
          'scrollUp,focus|Completar tarea,Eliminar tarea',
        );
        tester.semantics.scrollUp(
          scrollable: find.semantics.byLabel(RegExp('Tarea actual')),
        );
        await tester.pumpAndSettle();
        expect(
          actionsOf(tester),
          'scrollUp,scrollDown,focus|Completar tarea,Eliminar tarea',
        );
        handle.dispose();
      });
    }

    testWidgets('Av Pág y Re Pág siguen', (tester) async {
      await pumpApp(tester, lock: true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(844 * 0.8, 0.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(offset(tester), 0);
    });

    testWidgets('con reducir movimiento, Av Pág salta sin animar (jumpTo)', (
      tester,
    ) async {
      await pumpApp(tester, lock: true, reduced: true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(offset(tester), closeTo(844 * 0.8, 0.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(offset(tester), 0);
    });

    testWidgets('con reducir movimiento, scrollUp salta sin animar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, lock: true, reduced: true);
      await tester.pumpAndSettle();
      tester.semantics.scrollUp(
        scrollable: find.semantics.byLabel(RegExp('Tarea actual')),
      );
      await tester.pump();
      expect(offset(tester), closeTo(844 * 0.8, 0.5));
      handle.dispose();
    });

    testWidgets('CA-017-08 y CL-017-11: una foto alta con el bloqueo se queda '
        'donde estaba, sin pellizco ni arrastre', (tester) async {
      await pumpApp(tester, lock: true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final before = look(tester);
      expect(offset(tester), greaterThan(100));
      await pinchAndDrag(tester);
      expect(look(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('CL-017-12: mantener pulsado completa igual que siempre '
        '(1,2 s) con el bloqueo', (tester) async {
      await pumpApp(tester, lock: true);
      await tester.pumpAndSettle();
      expect(await repo.findById('t1'), isNotNull);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(await repo.findById('t1'), isNull);
      // Y soltar antes no completa.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('CL-017-12: soltar antes de 1,2 s no completa con el bloqueo', (
      tester,
    ) async {
      await pumpApp(tester, lock: true);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete ~/ 2);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();
      expect(await repo.findById('t1'), isNotNull);
    });
  });

  group('CA-017-07 y 12: encender y apagar con la tarea a la vista', () {
    testWidgets('encender con la foto desplazada: mismos píxeles, mismo '
        'State y mismo ScrollController; apagar desplaza desde ahí', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TaskImage), const Offset(0, -300));
      await tester.pumpAndSettle();
      final moved = offset(tester);
      expect(moved, greaterThan(100));
      final photoState = tester.state(find.byType(ZoomablePhoto));
      final screenState = tester.state(find.byType(CurrentTaskScreen));
      final controller = tester
          .widget<ZoomablePhoto>(find.byType(ZoomablePhoto))
          .scroll;
      final before = look(tester);

      await setLock(tester, true);
      expect(look(tester), before);
      expect(tester.state(find.byType(ZoomablePhoto)), same(photoState));
      expect(tester.state(find.byType(CurrentTaskScreen)), same(screenState));
      expect(
        tester.widget<ZoomablePhoto>(find.byType(ZoomablePhoto)).scroll,
        same(controller),
      );
      // Con el bloqueo, el arrastre ya no mueve.
      await tester.drag(find.byType(TaskImage), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(look(tester), before);

      await setLock(tester, false);
      expect(look(tester), before);
      expect(tester.state(find.byType(ZoomablePhoto)), same(photoState));
      expect(
        tester.widget<ZoomablePhoto>(find.byType(ZoomablePhoto)).scroll,
        same(controller),
      );
      await tester.drag(find.byType(TaskImage), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(offset(tester), greaterThan(moved));
    });

    testWidgets('el zoom no se conserva al encender ni al apagar', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(TaskImage));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 41,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 42,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await a.moveBy(const Offset(-50, 0));
      await b.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(zoomMatrix(tester).getMaxScaleOnAxis(), greaterThan(1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskImage)),
      );
      await container.read(settingsProvider.notifier).setLockZoom(true);
      await tester.pump();
      expect(zoomMatrix(tester).getMaxScaleOnAxis(), 1);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(zoomMatrix(tester).getMaxScaleOnAxis(), 1);
      await setLock(tester, false);
      expect(zoomMatrix(tester).getMaxScaleOnAxis(), 1);
    });

    testWidgets('CL-017-11: una foto más baja que la pantalla no se mueve al '
        'encender ni al apagar', (tester) async {
      await pumpApp(tester, task: await imageTask(width: 4000, height: 3000));
      await tester.pumpAndSettle();
      final before = look(tester);
      await setLock(tester, true);
      expect(look(tester), before);
      await setLock(tester, false);
      expect(look(tester), before);
    });
  });

  group('CA-017-11: con el valor guardado, desde el primer fotograma', () {
    testWidgets('el arrastre y el pellizco no hacen nada en cuanto la foto es '
        'tocable', (tester) async {
      await pumpApp(tester, lock: true, firstFrameOnly: true);
      // Sin esperar a nada más: el primer fotograma con la foto montada.
      expect(find.byType(ZoomablePhoto), findsOneWidget);
      expect(scrollable(), findsOneWidget);
      expect(
        tester
            .widget<SingleChildScrollView>(
              find.descendant(
                of: find.byType(ZoomablePhoto),
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      final before = look(tester);
      await pinchAndDrag(tester);
      expect(look(tester), before);
      expect(offset(tester), 0);
      await tester.pumpAndSettle();
      expect(look(tester), before);
    });

    testWidgets('control positivo: sin el valor guardado, los mismos gestos '
        'hacen algo', (tester) async {
      await pumpApp(tester, firstFrameOnly: true);
      final before = look(tester);
      await pinchAndDrag(tester);
      expect(look(tester), isNot(before));
    });
  });
}
