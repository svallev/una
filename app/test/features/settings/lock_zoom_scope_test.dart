import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/platform/screen_awake.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/keep_screen_on_controller.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pdfrx.dart';
import '../../support/pump_app.dart';
import '../../support/screen_fingerprint.dart';

/// Alcance de Bloquear zoom (T-017-07; CA-017-06, 07 y 12, CL-017-1 y 5): con
/// el ajuste **encendido** solo cambia cómo responde la foto de la imagen
/// suelta y del grupo. El texto, el PDF, la web, "Adjunto no disponible", el
/// editor, la pila de preselección, el listado y su miniatura, el menú, la card
/// de deshacer, la rotura y el arrugado se ven y se leen **igual** con y sin el
/// ajuste (mismos píxeles y mismo árbol semántico), y "Pantalla siempre
/// activa" no cambia. Es caracterización: el bloqueo solo vive en
/// `ZoomablePhoto`.
///
/// Cada escenario se monta dos veces (apagado y encendido) con un mundo nuevo
/// (repositorio, almacén y web) y se comparan.

const _frame = Duration(milliseconds: 16);
const _text = 'Horario del festival';
const _address = 'https://www.congreso.ejemplo.com/programa';

class _FakeAwake implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> keepOn(bool on) async => calls.add(on);
}

/// Todo lo de un montaje: su repositorio, su almacén y sus falsos.
class _World {
  _World() {
    importer = FakeImageImporter(store);
    pdfImporter = FakePdfImporter(store);
  }

  final store = MemoryAttachmentStore();
  final repo = InMemoryTaskRepository();
  final web = FakeWebPages();
  final awake = _FakeAwake();
  late final FakeImageImporter importer;
  late final FakePdfImporter pdfImporter;
  var _seq = 0;

  List<Override> overrides({bool realPdf = false}) => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
    pdfImporterProvider.overrideWithValue(pdfImporter),
    screenAwakeProvider.overrideWithValue(awake),
    if (!realPdf) ...fakePdfViews,
    ...web.overrides,
  ];

  /// [n] fotos de [width] × [height] con su pantalla en el almacén.
  Future<List<Attachment>> photos(
    int n, {
    int width = 1080,
    int height = 1440,
  }) async {
    final all = <Attachment>[];
    for (var i = 0; i < n; i++) {
      final id = 'f${_seq++}';
      all.add(
        await store.commit(
          stageImage(store, id, width: width, height: height),
          DateTime.utc(2026, 10, 7),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  Future<Task> imageTask({
    String id = 'img',
    String rank = 'MA',
    int height = 1440,
  }) async {
    final all = await photos(1, height: height);
    final base = sampleTask(id: id, text: _text, rank: rank, colorKey: 3);
    return base.withContent(_text, all.single, base.updatedAt);
  }

  Future<Task> groupTask({
    String id = 'grp',
    String rank = 'MA',
    int n = 3,
  }) async {
    final all = await photos(n);
    final base = sampleTask(id: id, text: _text, rank: rank, colorKey: 3);
    return base.withContent(_text, null, base.updatedAt, attachments: all);
  }

  Task webTask() {
    final at = DateTime.utc(2026, 9, 29, 9);
    return Task(
      id: 'web',
      text: null,
      status: TaskStatus.pending,
      rank: 'MA',
      colorKey: 3,
      createdAt: at,
      updatedAt: at,
      attachment: attachmentFrom(StagedWeb(id: 'a-web', url: _address), at),
    );
  }

  /// PDF; con [real], el documento de 20 páginas de verdad.
  Future<Task> pdfTask({bool real = false}) async {
    store
      ..putStaging(
        'p-pdf',
        'document.pdf',
        real
            ? base64Decode(pdfFixtures['pages_20.pdf']!)
            : Uint8List.fromList('%PDF-1.7'.codeUnits),
      )
      ..putStaging('p-pdf', 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      const StagedPdf(
        id: 'p-pdf',
        byteSize: 2400000,
        pageCount: 20,
        width: 595,
        height: 842,
        originalName: 'Programa.pdf',
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(id: 'pdf', text: 'Programa', rank: 'MA');
    return base.withContent(base.text, attachment, base.updatedAt);
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initPdfrxForTests();
  });

  setUp(taskPdfCalls.clear);

  /// Deja pasar el trabajo real (decodificar imágenes) y las animaciones.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  /// Monta la app con un mundo nuevo y la tarea [seed] como actual (más
  /// [more], de texto, detrás). Con [lock], el ajuste ya está guardado.
  Future<_World> mount(
    WidgetTester tester, {
    required bool lock,
    required Future<Task> Function(_World w) seed,
    List<String> more = const ['Segunda'],
    bool realPdf = false,
    bool keepOn = false,
  }) async {
    final w = _World();
    await w.repo.insert(await seed(w));
    if (lock) await w.repo.setLockZoom(true);
    if (keepOn) await w.repo.setKeepScreenOn(true);
    await pumpUnaApp(
      tester,
      repo: w.repo,
      tasks: more,
      overrides: w.overrides(realPdf: realPdf),
    );
    await settle(tester);
    return w;
  }

  /// Desmonta lo anterior para montar el siguiente escenario.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Corre [run] sin el ajuste y con él y devuelve las dos pantallas.
  Future<({Fingerprint off, Fingerprint on})> both(
    WidgetTester tester,
    Future<Fingerprint> Function(bool lock) run,
  ) async {
    final off = await run(false);
    await unmount(tester);
    final on = await run(true);
    return (off: off, on: on);
  }

  /// La pantalla tiene algo que ver (no es un fotograma en blanco).
  void expectNotBlank(Fingerprint f) {
    expect(f.pixels.toSet().length, greaterThan(8), reason: 'pantalla vacía');
    expect(f.reading.trim(), isNotEmpty);
  }

  group('CA-017-06, CL-017-1: el texto, el PDF, la web y "Adjunto no '
      'disponible" no cambian', () {
    Future<void> sameWithAndWithout(
      WidgetTester tester,
      Future<Task> Function(_World w) seed,
    ) async {
      final handle = tester.ensureSemantics();
      final photos = <bool, int>{};
      final shots = await both(tester, (lock) async {
        await mount(tester, lock: lock, seed: seed);
        photos[lock] = find.byType(ZoomablePhoto).evaluate().length;
        return fingerprintOf(tester);
      });
      expect(photos, {false: 0, true: 0}, reason: 'ninguna foto con zoom');
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    }

    testWidgets('tarea de solo texto', (tester) async {
      await sameWithAndWithout(
        tester,
        (w) async => sampleTask(text: _text, rank: 'MA', colorKey: 3),
      );
    });

    testWidgets('tarea web', (tester) async {
      await sameWithAndWithout(tester, (w) async => w.webTask());
      expect(find.byType(WebBar), findsOneWidget);
    });

    testWidgets('tarea con PDF (visor falso)', (tester) async {
      await sameWithAndWithout(tester, (w) => w.pdfTask());
      expect(find.byKey(const Key('fake-task-pdf')), findsOneWidget);
    });

    testWidgets('imagen suelta que falta: "Adjunto no disponible"', (
      tester,
    ) async {
      await sameWithAndWithout(tester, (w) async {
        final task = await w.imageTask();
        w.store.removeFile(task.attachment!.id, 'full-0-0.jpg');
        return task;
      });
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
    });

    testWidgets('grupo del que faltan todas las fotos: "Adjunto no '
        'disponible"', (tester) async {
      await sameWithAndWithout(tester, (w) async {
        final task = await w.groupTask();
        for (final a in task.attachments) {
          w.store.removeFile(a.id, 'full-0-0.jpg');
        }
        return task;
      });
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
    });

    testWidgets('el PDF de verdad conserva su zoom con el bloqueo '
        '(CA-008-10): "Ampliar" lo lleva a ×1,5 y "Reducir" a ×1', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await mount(
        tester,
        lock: true,
        seed: (w) => w.pdfTask(real: true),
        more: const [],
        realPdf: true,
      );
      for (var i = 0; i < 200; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(ZoomablePhoto), findsNothing);
      final page1 = RegExp('^Página 1 de 20');
      expect(find.bySemanticsLabel(page1), findsOneWidget);
      final controller = tester
          .widget<PdfViewer>(find.byType(PdfViewer))
          .controller!;
      expect(controller.currentZoom / controller.minScale, closeTo(1, 0.01));

      Future<void> pump() async {
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Ampliar'),
      );
      await pump();
      expect(controller.currentZoom / controller.minScale, closeTo(1.5, 0.01));
      tester.semantics.customAction(
        find.semantics.byLabel(page1),
        const CustomSemanticsAction(label: 'Reducir'),
      );
      await pump();
      expect(controller.currentZoom / controller.minScale, closeTo(1, 0.01));
      expect(tester.takeException(), isNull);
      // pdfrx deja temporizadores propios: se desmonta y se dejan correr.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      handle.dispose();
    });
  });

  group('CA-017-07, CA-017-12: la imagen y el grupo se ven como siempre', () {
    testWidgets('imagen suelta: mismos píxeles y misma lectura con el '
        'bloqueo, y la foto con zoom está a la vista', (tester) async {
      final handle = tester.ensureSemantics();
      final photos = <bool, int>{};
      final shots = await both(tester, (lock) async {
        await mount(tester, lock: lock, seed: (w) => w.imageTask());
        photos[lock] = find.byType(ZoomablePhoto).evaluate().length;
        return fingerprintOf(tester);
      });
      expect(photos, {false: 1, true: 1});
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    testWidgets('grupo de 3 fotos: mismos píxeles y misma lectura, con '
        'puntos y botón de completar', (tester) async {
      final handle = tester.ensureSemantics();
      final photos = <bool, int>{};
      final shots = await both(tester, (lock) async {
        await mount(tester, lock: lock, seed: (w) => w.groupTask());
        photos[lock] = find.byType(ZoomablePhoto).evaluate().length;
        expect(find.byType(PhotoCarousel), findsOneWidget);
        expect(find.byType(HoldToCompleteButton), findsOneWidget);
        return fingerprintOf(tester);
      });
      expect(photos, {false: 1, true: 1});
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });
  });

  group('CL-017-5: "Foto no disponible" con el bloqueo', () {
    testWidgets('se ve el recuadro en su sitio, el swipe sigue y no hay '
        'pellizco ni desplazamiento', (tester) async {
      final handle = tester.ensureSemantics();
      await mount(
        tester,
        lock: true,
        more: const [],
        seed: (w) async {
          final task = await w.groupTask();
          w.store.removeFile(task.attachments[0].id, 'full-0-0.jpg');
          return task;
        },
      );
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(find.byType(PhotoMissingBox), findsOneWidget);
      expect(find.byType(ZoomablePhoto), findsNothing, reason: 'sin foto');
      final controller = tester
          .widget<PhotoCarousel>(find.byType(PhotoCarousel))
          .controller!;
      expect(controller.index, 0);

      // Pellizco con dos dedos y arrastre vertical: nada cambia.
      final before = await fingerprintOf(tester);
      final center = tester.getCenter(find.byType(PhotoMissingBox));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 41,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 42,
      );
      for (var i = 0; i < 8; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(_frame);
        expect(tester.getRect(find.byType(PhotoMissingBox)), isNotNull);
      }
      await a.up();
      await b.up();
      await tester.pump(_frame);
      final drag = await tester.startGesture(center, pointer: 43);
      for (var i = 0; i < 8; i++) {
        await drag.moveBy(const Offset(0, -30));
        await tester.pump(_frame);
      }
      await drag.up();
      await settle(tester);
      expect(controller.index, 0, reason: 'ni pellizco ni vertical cambian');
      expectSameFingerprint(before, await fingerprintOf(tester));

      // El swipe horizontal lleva a la foto 2, que sí se ve.
      await tester.timedDragFrom(
        center,
        const Offset(-300, 0),
        const Duration(milliseconds: 320),
      );
      await settle(tester);
      expect(controller.index, 1);
      expect(find.byType(PhotoMissingBox), findsNothing);
      expect(find.byType(ZoomablePhoto), findsOneWidget);
      handle.dispose();
    });
  });

  group('CA-017-06: el editor, la pila, el listado, el menú y la card', () {
    /// El editor sobre la app (con o sin el ajuste) y lo que haga [then].
    Future<Fingerprint> editor(
      WidgetTester tester,
      bool lock, {
      required Future<Task?> Function(_World w) seed,
      EditorMode mode = EditorMode.edit,
      Future<void> Function(WidgetTester tester)? then,
    }) async {
      final w = _World();
      final task = await seed(w);
      if (task != null) await w.repo.insert(task);
      await pumpWithApp(
        tester,
        TaskEditorScreen(mode: mode, task: task),
        repo: w.repo,
        lockZoom: lock,
        overrides: w.overrides(),
      );
      await settle(tester);
      if (then != null) await then(tester);
      await settle(tester);
      return fingerprintOf(tester);
    }

    testWidgets('editor con una imagen suelta', (tester) async {
      final handle = tester.ensureSemantics();
      final shots = await both(
        tester,
        (lock) => editor(tester, lock, seed: (w) => w.imageTask()),
      );
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    testWidgets('editor con un grupo (pila de fotos)', (tester) async {
      final handle = tester.ensureSemantics();
      final shots = await both(tester, (lock) async {
        final f = await editor(tester, lock, seed: (w) => w.groupTask());
        expect(find.byType(PhotoStack), findsOneWidget);
        expect(find.byType(ZoomablePhoto), findsNothing);
        return f;
      });
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    testWidgets('editor: pila de preselección recién elegida (3 fotos)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final shots = await both(tester, (lock) async {
        final f = await editor(
          tester,
          lock,
          mode: EditorMode.first,
          seed: (w) async => null,
          then: (tester) async {
            await tester.tap(
              find.bySemanticsLabel('Añadir foto, imagen o archivo'),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Subir imágenes'));
            await tester.pumpAndSettle();
            await tester.pump(UnaMotion.announceAfterFocus);
          },
        );
        expect(find.byType(PhotoStack), findsOneWidget);
        expect(find.byType(ZoomablePhoto), findsNothing);
        return f;
      });
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    /// "Todas mis tareas" con una imagen, un grupo y un texto.
    Future<Fingerprint> list(WidgetTester tester, bool lock) async {
      await mount(
        tester,
        lock: lock,
        more: const ['Tercera'],
        seed: (w) async {
          // La actual es el grupo; la imagen suelta va detrás.
          await w.repo.insert(await w.imageTask(id: 'img', rank: 'MA2'));
          return w.groupTask(rank: 'MA');
        },
      );
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await settle(tester);
      await tester.tap(find.text('Todas mis tareas'));
      await settle(tester);
      expect(find.byType(TaskListScreen), findsOneWidget);
      return fingerprintOf(tester);
    }

    testWidgets('listado y sus miniaturas', (tester) async {
      final handle = tester.ensureSemantics();
      final shots = await both(tester, (lock) => list(tester, lock));
      expect(find.byType(TaskThumbnail), findsWidgets);
      expect(find.byType(ZoomablePhoto, skipOffstage: false), findsWidgets);
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    testWidgets('menú abierto sobre la tarea con un grupo', (tester) async {
      final handle = tester.ensureSemantics();
      final shots = await both(tester, (lock) async {
        await mount(tester, lock: lock, seed: (w) => w.groupTask());
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await settle(tester);
        expect(find.byType(MenuSheet), findsOneWidget);
        return fingerprintOf(tester);
      });
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });

    testWidgets('card de deshacer tras eliminar la imagen suelta', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final shots = await both(tester, (lock) async {
        await mount(tester, lock: lock, seed: (w) => w.imageTask());
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await settle(tester);
        await tester.tap(find.text('Eliminar'));
        await tester.pump(_frame);
        await tester.pump(_frame);
        await tester.pump(UnaMotion.crumple);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(UndoCard), findsOneWidget);
        return fingerprintOf(tester);
      });
      expectNotBlank(shots.on);
      expectSameFingerprint(shots.off, shots.on);
      handle.dispose();
    });
  });

  group('CA-017-06, CA-015-04: completar y eliminar con el bloqueo', () {
    Future<void> hold(WidgetTester tester) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(_frame);
      await gesture.up();
      await tester.pump(_frame);
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
    }

    Future<void> deleteFromMenu(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      await tester.pump(_frame);
    }

    Future<({Fingerprint mid, Fingerprint end, List<bool> awake})> run(
      WidgetTester tester,
      bool lock, {
      required Future<Task> Function(_World w) seed,
      required bool complete,
      required Type overlay,
    }) async {
      final w = await mount(tester, lock: lock, seed: seed, keepOn: true);
      if (complete) {
        await hold(tester);
      } else {
        await deleteFromMenu(tester);
      }
      expect(find.byType(overlay), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      final mid = await fingerprintOf(tester);
      await tester.pump(complete ? UnaMotion.successHold : UnaMotion.crumple);
      await tester.pump(UnaMotion.successFade);
      await tester.pump(UnaMotion.introFade);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final end = await fingerprintOf(tester);
      return (mid: mid, end: end, awake: [...w.awake.calls]);
    }

    for (final (name, seed) in <(String, Future<Task> Function(_World))>[
      ('imagen suelta', (w) => w.imageTask()),
      ('grupo de fotos', (w) => w.groupTask()),
    ]) {
      testWidgets('completar $name: la rotura es idéntica y la pantalla '
          'sigue encendida igual', (tester) async {
        final handle = tester.ensureSemantics();
        final off = await run(
          tester,
          false,
          seed: seed,
          complete: true,
          overlay: CelebrationOverlay,
        );
        await unmount(tester);
        final on = await run(
          tester,
          true,
          seed: seed,
          complete: true,
          overlay: CelebrationOverlay,
        );
        expectNotBlank(on.mid);
        expectSameFingerprint(off.mid, on.mid, reason: 'durante la rotura');
        expectSameFingerprint(off.end, on.end, reason: 'al terminar');
        expect(on.awake, off.awake, reason: 'KeepScreenOnWhileVisible');
        expect(on.awake, isNotEmpty);
        handle.dispose();
      });

      testWidgets('eliminar $name: el arrugado es idéntico y la pantalla '
          'sigue encendida igual', (tester) async {
        final handle = tester.ensureSemantics();
        final off = await run(
          tester,
          false,
          seed: seed,
          complete: false,
          overlay: CrumpleOverlay,
        );
        await unmount(tester);
        final on = await run(
          tester,
          true,
          seed: seed,
          complete: false,
          overlay: CrumpleOverlay,
        );
        expectNotBlank(on.mid);
        expectSameFingerprint(off.mid, on.mid, reason: 'durante el arrugado');
        expectSameFingerprint(off.end, on.end, reason: 'al terminar');
        expect(on.awake, off.awake, reason: 'KeepScreenOnWhileVisible');
        expect(on.awake, isNotEmpty);
        handle.dispose();
      });
    }
  });
}
