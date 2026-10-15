import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart' show sampleTask;
import '../support/screen_fingerprint.dart';
import '../support/undo.dart';

/// Spec 021, CA-021-07: el sistema pasa de claro a oscuro (o al revés) con la app delante y no
/// cambia nada de lo que se ve ni se pierde lo que había. Primero, la parte de fuente: la
/// actividad no se recrea porque `configChanges` incluye `uiMode`. Después, los tests de
/// widgets: texto sin guardar en el editor, una hoja abierta, la card de deshacer a mitad de su
/// tiempo y una foto del carrusel desplazada.
void main() {
  setUpAll(loadAppFonts);

  test('CA-021-07: configChanges del manifiesto contiene uiMode (no se recrea la actividad)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final value = RegExp(r'android:configChanges="([^"]*)"')
        .firstMatch(manifest)
        ?.group(1);
    expect(value, isNotNull);
    expect(value!.split('|'), contains('uiMode'));
  });

  /// Decodifica de verdad las imágenes en pantalla (fuera del reloj falso): sin esto la foto
  /// aparece entre dos capturas y parece un cambio.
  Future<void> decode(WidgetTester tester) async {
    for (var round = 0; round < 3; round++) {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// El sistema pasa a [brightness] con la app delante, sin avanzar el reloj: se ve el
  /// fotograma justo después del cambio, antes de que ocurra nada más.
  Future<void> switchTo(WidgetTester tester, Brightness brightness) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pump();
    await tester.pump();
    expect(tester.platformDispatcher.platformBrightness, brightness);
  }

  /// Aserción doble: lo que se ve (píxeles) y se lee (semántica) no cambia con el cambio de modo.
  Future<void> expectUnchanged(
    WidgetTester tester,
    Fingerprint before,
    Future<void> Function() change,
  ) async {
    await change();
    expectSameFingerprint(
      before,
      await fingerprintOf(tester),
      reason: 'después del cambio de modo',
    );
  }

  for (final (first, second) in [
    (Brightness.light, Brightness.dark),
    (Brightness.dark, Brightness.light),
  ]) {
    final change = '${first.name} -> ${second.name}';

    group('el sistema pasa de $change', () {
      testWidgets(
        'CA-021-07: el editor conserva el texto sin guardar, la selección y el foco ($change)',
        (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = first;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(tester, repo: repo, tasks: ['Primera']);
          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Nueva tarea'));
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Llamar a Marta');
          await tester.pump();

          TextField field() => tester.widget<TextField>(find.byType(TextField));
          final state = tester.state(find.byType(TaskEditorScreen));
          final focus = FocusManager.instance.primaryFocus;
          final selection = field().controller!.selection;
          expect(focus, isNotNull);
          expect(field().controller!.text, 'Llamar a Marta');
          final before = await fingerprintOf(tester);

          await expectUnchanged(tester, before, () => switchTo(tester, second));

          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(
            identical(tester.state(find.byType(TaskEditorScreen)), state),
            isTrue,
            reason: 'la pantalla no se recrea',
          );
          expect(field().controller!.text, 'Llamar a Marta');
          expect(field().controller!.selection, selection);
          expect(FocusManager.instance.primaryFocus, same(focus));
          // Nada se ha guardado ni se ha vuelto a la tarea actual.
          expect((await repo.currentTask())?.text, 'Primera');
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(field().controller!.text, 'Llamar a Marta');
          handle.dispose();
        },
      );

      testWidgets(
        'CA-021-07: una hoja abierta sigue abierta, igual y utilizable ($change)',
        (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = first;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            tasks: ['Primera', 'Segunda'],
          );
          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          expect(find.text('Nueva tarea'), findsOneWidget);
          final sheetItem = tester.element(find.text('Nueva tarea'));
          final before = await fingerprintOf(tester);

          await expectUnchanged(tester, before, () => switchTo(tester, second));

          expect(find.text('Nueva tarea'), findsOneWidget);
          expect(
            identical(tester.element(find.text('Nueva tarea')), sheetItem),
            isTrue,
            reason: 'la hoja no se recrea',
          );
          // La hoja sigue viva: su opción abre el editor.
          await tester.tap(find.text('Nueva tarea'));
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          handle.dispose();
        },
      );

      testWidgets(
        'CA-021-07: la card de deshacer sigue con el tiempo que le quedaba ($change)',
        (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = first;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(
            tester,
            repo: repo,
            tasks: ['Primera', 'Segunda'],
            clock: TesterClock(tester),
            overrides: [
              accessibilityTimeoutsProvider.overrideWithValue(
                FakeAccessibilityTimeouts(),
              ),
            ],
          );
          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Eliminar'));
          // Arrugado y entrada de la card.
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(UnaMotion.crumple);
          await tester.pump(const Duration(milliseconds: 500));
          final card = find.byType(UndoCard);
          expect(card, findsOneWidget);

          // A mitad de su tiempo.
          await tester.pump(const Duration(seconds: 2));
          double remaining() => tester.widget<UndoCard>(card).fraction();
          final left = remaining();
          expect(left, inExclusiveRange(0.2, 0.8));
          final before = await fingerprintOf(tester);

          await expectUnchanged(tester, before, () => switchTo(tester, second));

          expect(card, findsOneWidget);
          expect(
            remaining(),
            left,
            reason: 'la cuenta no se reinicia ni se para',
          );
          // Sigue contando: con 1,2 s más aún está (le quedaban unos 1,5 s)...
          await tester.pump(const Duration(milliseconds: 1200));
          expect(card, findsOneWidget);
          expect(remaining(), lessThan(left));
          // ... y caduca a su hora, sin haberse alargado por el cambio de modo.
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 500));
          expect(card, findsNothing);
          expect((await repo.currentTask())?.text, 'Segunda');
          handle.dispose();
        },
      );

      testWidgets(
        'CA-021-07: la foto del carrusel que se estaba viendo sigue siendo la misma ($change)',
        (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = first;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final store = MemoryAttachmentStore();
          final importer = FakeImageImporter(store);
          final all = <Attachment>[];
          for (var i = 0; i < 3; i++) {
            all.add(
              await store.commit(
                stageImage(store, 's$i', width: 1080, height: 20000),
                DateTime.utc(2026, 9, 20),
              ),
            );
            store.putStored('s$i', 'screen.jpg', Uint8List.fromList(tinyImage));
          }
          final base = sampleTask(text: 'Horario del festival', colorKey: 3);
          final task = base.withContent(
            'Horario del festival',
            null,
            base.updatedAt,
            attachments: all,
          );
          final repo = InMemoryTaskRepository();
          await repo.insert(task);
          await pumpUnaApp(
            tester,
            repo: repo,
            overrides: [
              attachmentStoreProvider.overrideWithValue(store),
              imageImporterProvider.overrideWithValue(importer),
            ],
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          int shown() => tester.widget<PhotoDots>(find.byType(PhotoDots)).index;
          List<String> mounted() => [
            for (final z in tester.widgetList<ZoomablePhoto>(
              find.byType(ZoomablePhoto),
            ))
              z.attachment.id,
          ];

          // A la segunda foto.
          await tester.timedDragFrom(
            const Offset(330, 400),
            const Offset(-250, 0),
            const Duration(milliseconds: 320),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          // Y desplazada hacia abajo dentro de la foto (alta).
          double offset() => tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ZoomablePhoto),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .pixels;
          await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -500));
          await tester.pumpAndSettle();
          final scrolled = offset();
          expect(scrolled, greaterThan(300));
          await decode(tester);
          expect(shown(), 1);
          final inView = mounted();
          expect(inView, contains('s1'));
          final before = await fingerprintOf(tester);

          await expectUnchanged(tester, before, () => switchTo(tester, second));

          expect(shown(), 1);
          expect(offset(), scrolled);
          expect(mounted(), inView);
          expect(find.byType(CurrentTaskScreen), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          expect(shown(), 1);
          expect(offset(), scrolled);
          handle.dispose();
        },
      );
    });
  }

  testWidgets(
    'CA-021-07: el modo del sistema cambia varias veces seguidas y la app no se recrea',
    (tester) async {
      final repo = InMemoryTaskRepository();
      await pumpUnaApp(tester, repo: repo, tasks: ['Primera']);
      final current = tester.state(find.byType(CurrentTaskScreen));
      final app = tester.state(find.byType(MaterialApp));
      for (final brightness in [
        Brightness.dark,
        Brightness.light,
        Brightness.dark,
      ]) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          identical(tester.state(find.byType(CurrentTaskScreen)), current),
          isTrue,
        );
        expect(identical(tester.state(find.byType(MaterialApp)), app), isTrue);
      }
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      await tester.pump();
    },
  );
}
