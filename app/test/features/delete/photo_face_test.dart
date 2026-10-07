// La rotura (completar) y el arrugado (eliminar) con un grupo de fotos
// (T-016-18b; CA-016-19, CA-016-16, CL-016-12): la cara es una imagen en
// memoria de la foto que se veía, tomada antes de descartar los archivos;
// sin captura es estática y no lee nada del disco; la copia no instala la
// salud de los adjuntos ni regenera; la captura se libera al terminar; y
// deshacer devuelve la tarea en la primera foto.
import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/photo_face_snapshot.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/ui/full_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _frame = Duration(milliseconds: 16);
const _text = 'Horario del festival';

/// Cuenta las comprobaciones de archivos (la salud de los adjuntos).
class _CountingStore extends MemoryAttachmentStore {
  int checks = 0;

  @override
  Future<AttachmentFiles> check(Attachment attachment) {
    checks++;
    return super.check(attachment);
  }
}

/// Cuenta las veces que se pide un archivo guardado para dibujarlo.
class _SpyImages extends MemoryAttachmentImages {
  _SpyImages(super.store);

  int reads = 0;

  @override
  ImageProvider stored(String relPath) {
    reads++;
    return super.stored(relPath);
  }
}

/// Un controlador que no captura nada: la cara sin imagen.
class _NoCapture extends PhotoFaceSnapshotController {
  @override
  void capture(PhotoFaceSnapshot snapshot) {
    snapshot.image.dispose();
  }
}

void main() {
  setUpAll(loadAppFonts);

  late _CountingStore store;
  late _SpyImages images;
  late FakeImageImporter importer;
  var seq = 0;

  setUp(() {
    store = _CountingStore();
    images = _SpyImages(store);
    importer = FakeImageImporter(store);
  });

  Future<List<Attachment>> photos(int n) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'f${base + i}';
      all.add(
        await store.commit(stageImage(store, id), DateTime.utc(2026, 10, 6)),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  Task groupTask(
    List<Attachment> attachments, {
    String id = 't1',
    String rank = 'MB',
  }) {
    final base = sampleTask(id: id, text: _text, rank: rank, colorKey: 3);
    return base.withContent(
      _text,
      null,
      base.updatedAt,
      attachments: attachments,
    );
  }

  Future<InMemoryTaskRepository> pumpApp(
    WidgetTester tester,
    List<Task> tasks, {
    bool reduced = false,
    bool screenReader = false,
    List<Override> overrides = const [],
  }) async {
    final repo = InMemoryTaskRepository();
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      reduced: reduced,
      screenReader: screenReader,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        attachmentImagesProvider.overrideWithValue(images),
        imageImporterProvider.overrideWithValue(importer),
        attachmentRotatesProvider.overrideWithValue(true),
        ...overrides,
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return repo;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  PhotoCarouselController carouselOf(WidgetTester tester) =>
      tester.widget<PhotoCarousel>(find.byType(PhotoCarousel)).controller!;

  Future<void> goTo(WidgetTester tester, int index) async {
    final carousel = carouselOf(tester);
    while (carousel.index != index) {
      carousel.next();
      for (var i = 0; i < 25; i++) {
        await tester.pump(_frame);
      }
    }
  }

  /// Mantiene pulsado Completar y lo suelta; la tarea queda guardada y a punto
  /// de empezar la rotura.
  Future<void> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump();
    await tester.pump(UnaMotion.holdToComplete);
    await tester.pump(_frame);
    await gesture.up();
    await tester.pump(_frame);
  }

  void performCustom(WidgetTester tester, String label) {
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Tarea actual: ')),
    );
    final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == label,
    );
    node.owner!.performAction(node.id, SemanticsAction.customAction, id);
  }

  Finder inOverlay(Type overlay, Type widget) =>
      find.descendant(of: find.byType(overlay), matching: find.byType(widget));

  /// Completa y deja la rotura a la vista; las lecturas del disco y las
  /// comprobaciones se miden justo antes de que se vea la cara.
  Future<({int reads, int checks, int regenerated})> completeUntilCelebration(
    WidgetTester tester,
  ) async {
    await hold(tester);
    final before = (
      reads: images.reads,
      checks: store.checks,
      regenerated: importer.regenerated.length,
    );
    await tester.pump(UnaMotion.holdDonePause);
    await tester.pump(_frame);
    expect(find.byType(CelebrationOverlay), findsOneWidget);
    return before;
  }

  Future<void> finishCelebration(WidgetTester tester, {Duration? hold}) async {
    await tester.pump(hold ?? UnaMotion.successHold);
    await tester.pump(UnaMotion.successFade);
    await tester.pump(_frame);
    await tester.pump(UnaMotion.introFade);
    await tester.pump(_frame);
  }

  group('CA-016-19, CL-016-12: completar viendo la foto 3', () {
    testWidgets('la captura se toma antes de descartar los archivos y la cara '
        'dibuja esa imagen, con la foto 3 en los puntos', (tester) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)]);
      await goTo(tester, 2);
      final container = containerOf(tester);

      // Lo que había en disco en el instante de la captura.
      final present = <bool>[];
      PhotoFaceSnapshot? taken;
      container.listen(photoFaceSnapshotProvider, (_, s) {
        if (s == null) return;
        taken = s;
        present.add(all.every((a) => store.bytes(a.screenPath) != null));
      });

      final before = await completeUntilCelebration(tester);

      expect(taken, isNotNull);
      expect(taken!.taskId, 't1');
      expect(taken!.index, 2);
      expect(taken!.landscape, isFalse);
      // 390 x 844 a 1 px por dp: la capa entera.
      expect(taken!.image.width, 390);
      expect(taken!.image.height, 844);
      expect(present, [
        true,
      ], reason: 'los archivos seguían en su sitio al tomar la captura');
      expect(
        all.any((a) => store.bytes(a.screenPath) != null),
        isFalse,
        reason: 'ya se han descartado cuando se ve la cara',
      );

      // La cara: la imagen capturada y los puntos con la foto 3 y el pie.
      final raw = tester
          .widgetList<RawImage>(
            find.descendant(
              of: find.byType(CelebrationOverlay),
              matching: find.byType(RawImage),
            ),
          )
          .where((r) => identical(r.image, taken!.image));
      expect(raw, isNotEmpty);
      final dots = tester.widgetList<PhotoDots>(
        inOverlay(CelebrationOverlay, PhotoDots),
      );
      expect(dots, isNotEmpty);
      for (final d in dots) {
        expect(d.index, 2);
        expect(d.count, 3);
      }
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.text(_text),
        ),
        findsWidgets,
      );

      // Sin carrusel, ni foto, ni lectura del disco, ni salud de adjuntos.
      expect(inOverlay(CelebrationOverlay, PhotoCarousel), findsNothing);
      expect(inOverlay(CelebrationOverlay, ZoomablePhoto), findsNothing);
      expect(inOverlay(CelebrationOverlay, TaskImage), findsNothing);
      expect(images.reads, before.reads);
      expect(store.checks, before.checks);
      expect(importer.regenerated.length, before.regenerated);
    });

    testWidgets('la captura se libera al terminar la rotura', (tester) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)]);
      final container = containerOf(tester);
      PhotoFaceSnapshot? taken;
      container.listen(photoFaceSnapshotProvider, (_, s) {
        if (s != null) taken = s;
      });

      await completeUntilCelebration(tester);
      expect(container.read(photoFaceSnapshotProvider), isNotNull);
      expect(taken!.image.debugDisposed, isFalse);

      await finishCelebration(tester);
      expect(find.byType(CelebrationOverlay), findsNothing);
      expect(container.read(photoFaceSnapshotProvider), isNull);
      await tester.pump(_frame);
      expect(taken!.image.debugDisposed, isTrue);
    });

    testWidgets('sin captura la cara es estática: el color de la nota y el '
        'pie, sin leer el disco ni regenerar nada', (tester) async {
      final all = await photos(3);
      await pumpApp(
        tester,
        [groupTask(all)],
        overrides: [photoFaceSnapshotProvider.overrideWith(_NoCapture.new)],
      );
      await goTo(tester, 1);
      final before = await completeUntilCelebration(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.byType(RawImage),
        ),
        findsNothing,
      );
      // El pie sí; los puntos no (no se sabe qué foto se veía), y nunca la
      // primera foto.
      expect(
        find.descendant(
          of: find.byType(CelebrationOverlay),
          matching: find.text(_text),
        ),
        findsWidgets,
      );
      expect(inOverlay(CelebrationOverlay, ZoomablePhoto), findsNothing);
      expect(inOverlay(CelebrationOverlay, PhotoCarousel), findsNothing);
      expect(images.reads, before.reads);
      expect(store.checks, before.checks);
      expect(importer.regenerated.length, before.regenerated);
      // No hay errores de dibujo.
      expect(tester.takeException(), isNull);
    });

    testWidgets('con reducir movimiento la cara es la misma imagen', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)], reduced: true);
      await goTo(tester, 1);
      final container = containerOf(tester);
      await completeUntilCelebration(tester);

      final snapshot = container.read(photoFaceSnapshotProvider);
      expect(snapshot, isNotNull);
      expect(snapshot!.index, 1);
      expect(
        tester
            .widgetList<RawImage>(
              find.descendant(
                of: find.byType(CelebrationOverlay),
                matching: find.byType(RawImage),
              ),
            )
            .where((r) => identical(r.image, snapshot.image)),
        isNotEmpty,
      );
      expect(inOverlay(CelebrationOverlay, ZoomablePhoto), findsNothing);
    });
  });

  group('CA-016-19, CL-016-12: eliminar viendo la foto 2', () {
    Future<void> deleteFromMenu(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      await tester.pump(_frame);
    }

    testWidgets('el arrugado dibuja la foto 2 capturada; se libera al acabar y '
        'deshacer devuelve la tarea en la primera foto', (tester) async {
      final all = await photos(3);
      final other = await photos(2);
      await pumpApp(tester, [
        groupTask(all),
        groupTask(other, id: 't2', rank: 'MC'),
      ]);
      await goTo(tester, 1);
      final container = containerOf(tester);
      PhotoFaceSnapshot? taken;
      final present = <bool>[];
      container.listen(photoFaceSnapshotProvider, (_, s) {
        if (s == null) return;
        taken = s;
        present.add(all.every((a) => store.bytes(a.screenPath) != null));
      });

      await deleteFromMenu(tester);
      await tester.pump(UnaMotion.crumple * 0.5);
      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(taken, isNotNull);
      expect(taken!.taskId, 't1');
      expect(taken!.index, 1);
      expect(present, [true]);
      expect(
        tester
            .widgetList<RawImage>(
              find.descendant(
                of: find.byType(CrumpleOverlay),
                matching: find.byType(RawImage),
              ),
            )
            .where((r) => identical(r.image, taken!.image)),
        isNotEmpty,
      );
      expect(inOverlay(CrumpleOverlay, ZoomablePhoto), findsNothing);
      expect(inOverlay(CrumpleOverlay, PhotoCarousel), findsNothing);
      expect(importer.regenerated, isEmpty);

      await tester.pump(UnaMotion.crumple);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(find.byType(CrumpleOverlay), findsNothing);
      expect(container.read(photoFaceSnapshotProvider), isNull);
      await tester.pump(_frame);
      expect(taken!.image.debugDisposed, isTrue);

      // Deshacer: la tarea vuelve con todo el grupo, en la primera foto.
      expect(find.byType(UndoCard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(UndoCard.buttonKey));
      await tester.pump(_frame);
      for (var i = 0; i < 40; i++) {
        await tester.pump(_frame);
      }
      expect(find.byType(UndoCard), findsNothing);
      expect(carouselOf(tester).index, 0);
      expect(
        tester
            .widgetList<PhotoDots>(find.byType(PhotoDots))
            .map((d) => (d.count, d.index)),
        [(3, 0)],
      );
    });

    testWidgets('con reducir movimiento, también la imagen capturada', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)], reduced: true);
      await goTo(tester, 2);
      final container = containerOf(tester);

      await deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 50));
      final snapshot = container.read(photoFaceSnapshotProvider);
      expect(snapshot, isNotNull);
      expect(snapshot!.index, 2);
      expect(inOverlay(CrumpleOverlay, ZoomablePhoto), findsNothing);
    });

    testWidgets('sin captura el arrugado no lee el disco', (tester) async {
      final all = await photos(3);
      await pumpApp(
        tester,
        [groupTask(all)],
        overrides: [photoFaceSnapshotProvider.overrideWith(_NoCapture.new)],
      );
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      final reads = images.reads;
      final checks = store.checks;
      await tester.pump(_frame);
      await tester.pump(UnaMotion.crumple * 0.5);

      expect(find.byType(CrumpleOverlay), findsOneWidget);
      expect(inOverlay(CrumpleOverlay, ZoomablePhoto), findsNothing);
      expect(images.reads, reads);
      expect(store.checks, checks);
      expect(importer.regenerated, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('CL-016-11, CL-016-12: en horizontal', () {
    testWidgets('eliminar: el arrugado dibuja la imagen a 844 dp, sin pie ni '
        'puntos', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpApp(tester, [
        groupTask(all),
        sampleTask(id: 't2', text: 'Siguiente', rank: 'MC'),
      ], screenReader: true);
      await goTo(tester, 2);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      performCustom(tester, 'Eliminar tarea');
      await tester.pump(_frame);
      await tester.pump(_frame);
      await tester.pump(UnaMotion.crumple * 0.3);
      expect(find.byType(CrumpleOverlay), findsOneWidget);
      final snapshot = containerOf(tester).read(photoFaceSnapshotProvider);
      expect(snapshot, isNotNull);
      expect(snapshot!.landscape, isTrue);
      expect(snapshot.index, 2);
      expect(inOverlay(CrumpleOverlay, PhotoDots), findsNothing);
      // Con la tarea de antes ya quitada, el ancho completo lo pide la cara.
      expect(fullWidthRequests.value, greaterThan(0));
      expect(
        tester.getSize(inOverlay(CrumpleOverlay, PhotoFaceLayer).first),
        const Size(844, 390),
      );
      handle.dispose();
    });

    // Completar, con la tarea de antes en su fundido.

    testWidgets('la cara es la imagen horizontal, sin pie ni puntos, y pide '
        'el ancho completo mientras se ve', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpApp(tester, [
        groupTask(all),
        sampleTask(id: 't2', text: 'Siguiente', rank: 'MC'),
      ], screenReader: true);
      await goTo(tester, 1);
      final container = containerOf(tester);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final baseline = fullWidthRequests.value;
      expect(baseline, greaterThan(0));

      performCustom(tester, 'Completar tarea');
      await tester.pump(_frame);
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(find.byType(CelebrationOverlay), findsOneWidget);

      final snapshot = container.read(photoFaceSnapshotProvider);
      expect(snapshot, isNotNull);
      expect(snapshot!.landscape, isTrue);
      expect(snapshot.index, 1);
      expect(snapshot.image.width, 844);
      expect(snapshot.image.height, 390);
      expect(inOverlay(CelebrationOverlay, PhotoDots), findsNothing);
      // Cuando la tarea de antes ya se ha ido (su fundido), el ancho completo
      // lo pide la cara (la de detrás no tiene adjunto): la imagen se ve a
      // 844 dp, sin deformarse.
      await tester.pump(UnaMotion.introFade + const Duration(milliseconds: 50));
      await tester.pump(_frame);
      expect(fullWidthRequests.value, greaterThan(0));
      for (final layer in tester.widgetList(
        inOverlay(CelebrationOverlay, PhotoFaceLayer),
      )) {
        expect(layer, isA<PhotoFaceLayer>());
      }
      expect(
        tester.getSize(inOverlay(CelebrationOverlay, PhotoFaceLayer).first),
        const Size(844, 390),
      );

      await finishCelebration(
        tester,
        hold: CelebrationOverlay.screenReaderHold,
      );
      expect(container.read(photoFaceSnapshotProvider), isNull);
      expect(fullWidthRequests.value, 0);
      handle.dispose();
    });
  });
}
