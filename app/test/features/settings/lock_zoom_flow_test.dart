import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../task_list/list_harness.dart' show FakeClock, background;
import 'settings_harness.dart';

/// Bloquear zoom desde Ajustes con la app entera (T-017-06; CA-017-03, 05, 07,
/// 09, 11 y 12; CL-017-2, 3 y 4): encender o apagar el ajuste en Ajustes y
/// volver a la tarea no mueve la foto (la misma, con los mismos píxeles y el
/// mismo `State`), no recarga la tarea y deja los gestos sin efecto (o de
/// nuevo con él). Es caracterización: "Ajustes encima cuenta como a la vista"
/// ya se cumple sin código nuevo.
///
/// Las dos "tareas" son la imagen suelta y un grupo de 3 fotos (la 3 a la
/// vista), las dos más altas que la pantalla. Dos arranques son dos montajes
/// de la app sobre el **mismo** repositorio (el disco): la persistencia de
/// los valores crudos la cubre `repository_contract_test`.

const _frame = Duration(milliseconds: 16);
const _text = 'Horario del festival';
const _lockRow = 'Bloquear zoom';
const _lockLabel = '$_lockRow, Solo imágenes: sin zoom ni scroll';
const _lockLabelEn = 'Lock zoom, Images only: no zoom or scroll';
const _saveError = 'No se pudo guardar el ajuste.';

/// Repositorio de Ajustes (`SettingsRepo`: escrituras y fallos controlables)
/// que cuenta las lecturas de la tarea actual.
class _Repo extends SettingsRepo {
  int currentReads = 0;
  int findReads = 0;
  int watches = 0;

  /// Todo lo que sea volver a leer la tarea.
  int get taskReads => currentReads + findReads + watches;

  @override
  Future<Task?> currentTask() {
    currentReads++;
    return super.currentTask();
  }

  @override
  Future<Task?> findById(String id) {
    findReads++;
    return super.findById(id);
  }

  @override
  Stream<Task?> watchCurrentTask() {
    watches++;
    return super.watchCurrentTask();
  }
}

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late _Repo repo;
  var seq = 0;

  setUp(() {
    store = MemoryAttachmentStore();
    repo = _Repo();
  });

  /// [n] fotos altas (1080 × 6000) guardadas con su pantalla en el almacén.
  Future<List<Attachment>> photos(int n) async {
    final all = <Attachment>[];
    for (var i = 0; i < n; i++) {
      final id = 'f${seq++}';
      all.add(
        await store.commit(
          stageImage(store, id, width: 1080, height: 6000),
          DateTime.utc(2026, 10, 7),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  /// La tarea actual: una imagen suelta o un grupo de 3 fotos. El resto del
  /// estado (el ajuste, el primer uso) lo pone cada test.
  Future<void> seed({required bool group}) async {
    final all = await photos(group ? 3 : 1);
    final base = sampleTask(text: _text, colorKey: 3, rank: 'M');
    await repo.insert(
      group
          ? base.withContent(_text, null, base.updatedAt, attachments: all)
          : base.withContent(_text, all.single, base.updatedAt),
    );
  }

  /// Monta la app sobre [repo]. Un segundo arranque desmonta el anterior antes.
  Future<void> start(
    WidgetTester tester, {
    FakeClock? clock,
    bool reduced = false,
    bool firstFrameOnly = false,
    List<String> more = const [],
  }) async {
    await pumpUnaApp(
      tester,
      repo: repo,
      tasks: more,
      clock: clock,
      reduced: reduced,
      firstFrameOnly: firstFrameOnly,
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    if (!firstFrameOnly) await tester.pumpAndSettle();
  }

  /// Muere el proceso: se desmonta la app (la base de datos queda en [repo]).
  Future<void> kill(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  // --- Lo que se ve de la tarea ---------------------------------------------

  Finder photo() => find.byType(ZoomablePhoto).first;

  double pixels(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: photo(), matching: find.byType(Scrollable)).first,
      )
      .position
      .pixels;

  int dots(WidgetTester tester) {
    final f = find.byType(PhotoDots);
    return f.evaluate().isEmpty ? -1 : tester.widget<PhotoDots>(f).index;
  }

  String ids(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ].join(',');

  Matrix4 zoomMatrix(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(of: photo(), matching: find.byType(Transform)).first,
      )
      .transform;

  /// Todo lo que se ve de la foto: cuál es, cuál es el punto activo, dónde
  /// está, su desplazamiento y su zoom.
  String look(WidgetTester tester) =>
      '${ids(tester)}|${dots(tester)}|${tester.getRect(photo())}|'
      '${pixels(tester)}|${zoomMatrix(tester).storage}';

  /// Pellizco con dos dedos y arrastre vertical con uno, muestreados en cada
  /// fotograma.
  Future<void> pinchAndDrag(
    WidgetTester tester, {
    Future<void> Function()? each,
  }) async {
    final center = tester.getCenter(photo());
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
      await tester.pump(_frame);
      if (each != null) await each();
    }
    await a.up();
    await b.up();
    await tester.pump(_frame);
    final drag = await tester.startGesture(center, pointer: 33);
    for (var i = 1; i <= 8; i++) {
      await drag.moveBy(const Offset(0, -30));
      await tester.pump(_frame);
      if (each != null) await each();
    }
    await drag.up();
    await tester.pump(_frame);
  }

  /// Con el bloqueo, ni el pellizco ni el arrastre cambian nada, ni un
  /// fotograma ni después.
  Future<void> expectLocked(WidgetTester tester) async {
    final before = look(tester);
    await pinchAndDrag(tester, each: () async => expect(look(tester), before));
    await tester.pumpAndSettle();
    expect(look(tester), before);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }

  /// Sin el bloqueo, el arrastre desplaza la foto desde donde estaba.
  Future<void> expectUnlocked(WidgetTester tester) async {
    final from = pixels(tester);
    await tester.drag(photo(), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(pixels(tester), greaterThan(from));
  }

  // --- Navegación -----------------------------------------------------------

  /// Foto 3 del grupo, con una orden del teclado por foto (el bucle cuenta
  /// con la transición de 280 ms) y la foto desplazada con Av Pág.
  Future<void> goToThirdAndScroll(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      for (var t = 0; t < 400; t += 16) {
        await tester.pump(_frame);
      }
    }
    for (var t = 0; t < 3200; t += 16) {
      await tester.pump(_frame);
    }
  }

  Future<void> scrollPhoto(WidgetTester tester, {int pages = 1}) async {
    for (var i = 0; i < pages; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
    }
    expect(pixels(tester), greaterThan(300));
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await settleSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(MenuSheet), findsNothing);
  }

  Future<void> closeSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Cerrar ajustes'));
    await settleSettings(tester);
    expect(find.byType(SettingsScreen), findsNothing);
  }

  Future<void> tapLockRow(WidgetTester tester) async {
    await tester.tap(inSettings(find.text(_lockRow)));
    await tester.pumpAndSettle();
  }

  /// Un viaje: la tarea desplazada, Ajustes, el interruptor y
  /// Cerrar. Devuelve cómo estaba antes de abrir Ajustes.
  Future<String> toggleInSettings(WidgetTester tester) async {
    final before = look(tester);
    await openSettings(tester);
    await tapLockRow(tester);
    await closeSettings(tester);
    return before;
  }

  // --- Acciones del nodo de la tarea ----------------------------------------

  SemanticsNode taskNode(WidgetTester tester) => tester.getSemantics(
    find.bySemanticsLabel(RegExp('^(Tarea actual|Current task): ')),
  );

  /// Las acciones del nodo de la tarea en el orden del lector: las estándar y
  /// las propias.
  String actionsOf(WidgetTester tester) {
    final data = taskNode(tester).getSemanticsData();
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

  Tristate toggled(WidgetTester tester, String label) => tester
      .getSemantics(find.bySemanticsLabel(label))
      .getSemanticsData()
      .flagsCollection
      .isToggled;

  for (final grouped in [false, true]) {
    final kind = grouped ? 'grupo (foto 3)' : 'imagen suelta';

    // --- CA-017-05, 07 y 12: encender y apagar desde Ajustes -----------------

    group('CA-017-05, 07 y 12, CL-017-2: $kind desplazada', () {
      Future<void> pumpScrolled(WidgetTester tester) async {
        await seed(group: grouped);
        await start(tester);
        if (grouped) await goToThirdAndScroll(tester);
        await scrollPhoto(tester);
      }

      testWidgets('encender en Ajustes y cerrar: la misma foto, los mismos '
          'píxeles, el mismo State, sin recargar la tarea; los gestos ya no '
          'hacen nada', (tester) async {
        await pumpScrolled(tester);
        if (grouped) {
          expect(dots(tester), 2, reason: 'la foto 3');
        }
        final photoState = tester.state(photo());
        final screenState = tester.state(find.byType(CurrentTaskScreen));
        final controller = tester.widget<ZoomablePhoto>(photo()).scroll;
        final reads = repo.taskReads;
        final before = look(tester);
        expect(await repo.lockZoom(), isFalse);

        await openSettings(tester);
        await tapLockRow(tester);
        expect(repo.lockWrites, [true]);
        expect(await repo.lockZoom(), isTrue);
        await closeSettings(tester);

        expect(look(tester), before);
        expect(tester.state(photo()), same(photoState));
        expect(tester.state(find.byType(CurrentTaskScreen)), same(screenState));
        expect(tester.widget<ZoomablePhoto>(photo()).scroll, same(controller));
        expect(
          repo.taskReads,
          reads,
          reason: 'la tarea no se vuelve a leer del repositorio',
        );
        if (grouped) {
          expect(
            tester.state(find.byType(PhotoCarousel)),
            isNotNull,
            reason: 'el carrusel sigue montado',
          );
        }
        await expectLocked(tester);
      });

      testWidgets('apagar en Ajustes y cerrar: la foto se desplaza desde '
          'donde estaba y el zoom vuelve al 100 %', (tester) async {
        await repo.setLockZoom(true);
        repo.lockWrites.clear();
        await seed(group: grouped);
        await start(tester);
        if (grouped) await goToThirdAndScroll(tester);
        await scrollPhoto(tester);
        final photoState = tester.state(photo());
        final controller = tester.widget<ZoomablePhoto>(photo()).scroll;
        final reads = repo.taskReads;
        final moved = pixels(tester);

        final before = await toggleInSettings(tester);
        expect(repo.lockWrites, [false]);
        expect(look(tester), before);
        expect(pixels(tester), moved);
        expect(tester.state(photo()), same(photoState));
        expect(tester.widget<ZoomablePhoto>(photo()).scroll, same(controller));
        expect(repo.taskReads, reads);

        // El pellizco vuelve al soltar y el arrastre desplaza desde ahí.
        final center = tester.getCenter(photo());
        final a = await tester.startGesture(
          center - const Offset(20, 0),
          pointer: 41,
        );
        final b = await tester.startGesture(
          center + const Offset(20, 0),
          pointer: 42,
        );
        await tester.pump(_frame);
        await a.moveBy(const Offset(-50, 0));
        await b.moveBy(const Offset(50, 0));
        await tester.pump(_frame);
        expect(zoomMatrix(tester).getMaxScaleOnAxis(), greaterThan(1));
        await a.up();
        await b.up();
        await tester.pumpAndSettle();
        expect(zoomMatrix(tester).getMaxScaleOnAxis(), 1);
        expect(pixels(tester), moved);
        await expectUnlocked(tester);
      });

      testWidgets('encender y apagar seguidos: la foto no se mueve en ninguno '
          'de los dos viajes a Ajustes', (tester) async {
        await pumpScrolled(tester);
        final photoState = tester.state(photo());
        final before = look(tester);
        await toggleInSettings(tester);
        expect(look(tester), before);
        await toggleInSettings(tester);
        expect(look(tester), before);
        expect(tester.state(photo()), same(photoState));
        expect(repo.lockWrites, [true, false]);
        await expectUnlocked(tester);
      });
    });

    // --- CA-017-09: las acciones del nodo de la tarea ------------------------

    group('CA-017-09: las acciones del nodo de la tarea ($kind)', () {
      testWidgets('el mismo conjunto y orden antes de encender, tras volver de '
          'Ajustes y tras apagar, antes de desplazar nada', (tester) async {
        final handle = tester.ensureSemantics();
        await seed(group: grouped);
        await start(tester);
        if (grouped) await goToThirdAndScroll(tester);
        final off = actionsOf(tester);
        expect(
          off,
          grouped
              ? 'scrollUp,scrollLeft,scrollRight,focus|'
                    'Foto siguiente,Foto anterior,Completar tarea,Eliminar tarea'
              : 'scrollUp,focus|Completar tarea,Eliminar tarea',
        );

        await toggleInSettings(tester);
        expect(await repo.lockZoom(), isTrue);
        expect(actionsOf(tester), off, reason: 'tras encender');

        await toggleInSettings(tester);
        expect(await repo.lockZoom(), isFalse);
        expect(actionsOf(tester), off, reason: 'tras apagar');
        handle.dispose();
      });

      testWidgets('con la foto desplazada también son las mismas, y con el '
          'bloqueo "desplazar atrás" sigue disponible', (tester) async {
        final handle = tester.ensureSemantics();
        await seed(group: grouped);
        await start(tester);
        if (grouped) await goToThirdAndScroll(tester);
        await scrollPhoto(tester);
        final off = actionsOf(tester);
        expect(off, contains('scrollDown'));

        await toggleInSettings(tester);
        expect(actionsOf(tester), off, reason: 'tras encender');
        await toggleInSettings(tester);
        expect(actionsOf(tester), off, reason: 'tras apagar');
        handle.dispose();
      });
    });
  }

  // --- CA-017-03 y 11: persistencia y primer fotograma ---------------------

  group('CA-017-03 y 11: el valor se conserva entre arranques', () {
    for (final grouped in [false, true]) {
      testWidgets(
        '${grouped ? 'grupo' : 'imagen suelta'}: encendido en Ajustes, '
        'tras morir el proceso la foto ya está bloqueada en el primer '
        'fotograma y Ajustes lo dice',
        (tester) async {
          final handle = tester.ensureSemantics();
          await seed(group: grouped);
          await start(tester);
          await openSettings(tester);
          await tapLockRow(tester);
          await closeSettings(tester);
          await kill(tester);

          // Otro arranque: el valor sale del disco (el repositorio).
          await start(tester, firstFrameOnly: true);
          expect(find.byType(ZoomablePhoto), findsOneWidget);
          final physics = tester
              .widget<SingleChildScrollView>(
                find
                    .descendant(
                      of: find.byType(ZoomablePhoto),
                      matching: find.byType(SingleChildScrollView),
                    )
                    .first,
              )
              .physics;
          expect(physics, isA<NeverScrollableScrollPhysics>());
          await expectLocked(tester);

          await openSettings(tester);
          expect(toggled(tester, _lockLabel), Tristate.isTrue);
          expect(
            tester.widget<UnaSwitchRow>(find.byType(UnaSwitchRow).last).value,
            isTrue,
          );
          await closeSettings(tester);
          await expectLocked(tester);

          // Y apagado, el siguiente arranque ya no está bloqueado.
          await openSettings(tester);
          await tapLockRow(tester);
          await closeSettings(tester);
          await kill(tester);
          await start(tester);
          await expectUnlocked(tester);
          await openSettings(tester);
          expect(toggled(tester, _lockLabel), Tristate.isFalse);
          handle.dispose();
        },
      );
    }

    testWidgets('si el guardado de encender falla, sigue apagado: el aviso '
        'sale bajo la fila, la foto se mueve como siempre y el siguiente '
        'arranque también', (tester) async {
      await seed(group: false);
      await start(tester);
      repo.lockError = Exception('texto-secreto');
      await openSettings(tester);
      await tapLockRow(tester);
      expect(find.text(_saveError), findsOneWidget);
      expect(find.textContaining('texto-secreto'), findsNothing);
      await closeSettings(tester);
      expect(repo.lockWrites, [true]);
      await expectUnlocked(tester);

      await kill(tester);
      repo.lockError = null;
      await start(tester);
      expect(await repo.lockZoom(), isFalse);
      await expectUnlocked(tester);
    });

    testWidgets('si el guardado de apagar falla, sigue encendido: la foto '
        'sigue bloqueada y el siguiente arranque también', (tester) async {
      await repo.setLockZoom(true);
      repo.lockWrites.clear();
      await seed(group: false);
      await start(tester);
      repo.lockError = StateError('texto-secreto');
      await openSettings(tester);
      await tapLockRow(tester);
      expect(find.text(_saveError), findsOneWidget);
      await closeSettings(tester);
      expect(repo.lockWrites, [false]);
      await expectLocked(tester);

      await kill(tester);
      repo.lockError = null;
      await start(tester, firstFrameOnly: true);
      await expectLocked(tester);
      expect(await repo.lockZoom(), isTrue);
    });
  });

  // --- CA-017-05 y CA-001-12: 9:59 y 10:00 en segundo plano --------------

  group('CA-017-05, CL-017-2: la app en segundo plano estando en Ajustes', () {
    testWidgets('9:59: Ajustes sigue abierto y, al cerrarlo, la misma foto y '
        'el mismo desplazamiento, ya bloqueada', (tester) async {
      final clock = FakeClock();
      await seed(group: true);
      await start(tester, clock: clock);
      await goToThirdAndScroll(tester);
      await scrollPhoto(tester);
      final before = look(tester);
      final photoState = tester.state(photo());

      await openSettings(tester);
      await tapLockRow(tester);
      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await closeSettings(tester);

      expect(look(tester), before);
      expect(tester.state(photo()), same(photoState));
      await expectLocked(tester);
    });

    testWidgets('10:00 encendiendo: la tarea vuelve desde su primera foto y '
        'arriba, ya con el valor nuevo', (tester) async {
      final clock = FakeClock();
      await seed(group: true);
      await start(tester, clock: clock);
      await goToThirdAndScroll(tester);
      await scrollPhoto(tester);
      expect(dots(tester), 2);

      await openSettings(tester);
      await tapLockRow(tester);
      background(tester, clock, UnaApp.resetAfter);
      await settleSettings(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(dots(tester), 0, reason: 'la primera foto');
      expect(pixels(tester), 0, reason: 'arriba');
      await expectLocked(tester);
    });

    testWidgets('10:00 apagando: la primera foto, arriba y ya sin bloqueo', (
      tester,
    ) async {
      final clock = FakeClock();
      await repo.setLockZoom(true);
      await seed(group: true);
      await start(tester, clock: clock);
      await goToThirdAndScroll(tester);
      await scrollPhoto(tester);

      await openSettings(tester);
      await tapLockRow(tester);
      background(tester, clock, UnaApp.resetAfter);
      await settleSettings(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(dots(tester), 0);
      expect(pixels(tester), 0);
      await expectUnlocked(tester);
    });

    testWidgets('10:00 con la imagen suelta: arriba y con el valor nuevo', (
      tester,
    ) async {
      final clock = FakeClock();
      await seed(group: false);
      await start(tester, clock: clock);
      await scrollPhoto(tester);

      await openSettings(tester);
      await tapLockRow(tester);
      background(tester, clock, UnaApp.resetAfter);
      await settleSettings(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(pixels(tester), 0);
      await expectLocked(tester);
    });
  });

  // --- CL-017-4 y CL-017-3 ----------------------------------------------------

  testWidgets('CL-017-4: cambiar el idioma con el ajuste encendido lo '
      'conserva: la fila cambia de idioma y la foto sigue bloqueada', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await repo.setLockZoom(true);
    repo.lockWrites.clear();
    await seed(group: true);
    await start(tester);
    await goToThirdAndScroll(tester);
    await scrollPhoto(tester);
    final before = look(tester);

    await openSettings(tester);
    await tester.tap(inSettings(find.text('Idioma')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePage), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await settleSettings(tester);
    if (find.byType(LanguagePage).evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
    }

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(toggled(tester, _lockLabelEn), Tristate.isTrue);
    expect(repo.lockWrites, isEmpty, reason: 'el idioma no escribe el ajuste');
    await tester.tap(find.bySemanticsLabel('Close settings'));
    await settleSettings(tester);

    expect(find.byType(SettingsScreen), findsNothing);
    expect(look(tester), before);
    await expectLocked(tester);
    expect(await repo.lockZoom(), isTrue);
    handle.dispose();
  });

  testWidgets('CL-017-3: con la card de deshacer a la vista y el bloqueo '
      'encendido, abrir Ajustes hace definitiva la eliminación', (
    tester,
  ) async {
    await repo.setLockZoom(true);
    await seed(group: false);
    await start(tester, more: ['Segunda']);
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pump(_frame);
    await tester.pump(UnaMotion.crumple);
    await tester.pump(_frame);
    await tester.pump(_frame);
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.read(undoProvider).phase, UndoPhase.visible);

    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ajustes'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(container.read(undoProvider).phase, UndoPhase.none);
    await tester.pump(const Duration(milliseconds: 500));
    expect(await repo.findById('t1'), isNull, reason: 'definitiva');
    expect(await repo.findById('t0'), isNotNull);
    expect(await repo.lockZoom(), isTrue);
  });
}
