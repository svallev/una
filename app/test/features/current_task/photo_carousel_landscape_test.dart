// El carrusel de fotos al girar el móvil (T-016-18a; CA-016-12, CL-016-11 y
// CL-016-22): con la app entera y el giro real de la superficie, la foto que se
// veía sigue a la vista (con su desplazamiento, sin zoom), en horizontal solo
// quedan la foto y el logotipo, el swipe, el pellizco y las acciones siguen,
// la app respeta el bloqueo de rotación del sistema (solo avisa de que la
// tarea puede girar) y la card de deshacer se ve también apaisada.
import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/photo_announcer.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _text = 'Horario del festival';
const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late List<List<String>> orientations;
  late List<String> calls;
  var seq = 0;

  setUp(() {
    store = MemoryAttachmentStore();
  });

  /// Lo último que se ha pedido al sistema: girar con el adjunto o no.
  bool? rotating() {
    for (final c in calls.reversed) {
      if (c.startsWith('rotateWithAttachment:')) return c.endsWith('true');
    }
    return null;
  }

  Future<List<Attachment>> photos(
    int n, {
    int width = 4000,
    int height = 3000,
  }) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'g${base + i}';
      all.add(
        await store.commit(
          stageImage(store, id, width: width, height: height),
          DateTime.utc(2026, 9, 20),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    return all;
  }

  Task groupTask(
    List<Attachment> attachments, {
    String id = 't1',
    String rank = 'MB',
    String? text = _text,
  }) {
    final base = sampleTask(id: id, text: text ?? 'x', rank: rank, colorKey: 3);
    return base.withContent(
      text,
      null,
      base.updatedAt,
      attachments: attachments,
    );
  }

  Future<void> pumpApp(
    WidgetTester tester,
    List<Task> tasks, {
    bool rotates = true,
    bool screenReader = false,
  }) async {
    orientations = [];
    calls = [];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add([
            for (final o in call.arguments as List<Object?>) o! as String,
          ]);
        }
        return null;
      })
      ..setMockMethodCallHandler(const MethodChannel('una/screen'), (
        call,
      ) async {
        if (call.method != 'keepOn') {
          calls.add('${call.method}:${call.arguments}');
        }
        return null;
      });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('una/screen'), null);
    });
    final repo = InMemoryTaskRepository();
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      screenReader: screenReader,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
        attachmentRotatesProvider.overrideWithValue(rotates),
        photoAnnouncerModeProvider.overrideWithValue(
          PhotoAnnouncerMode.liveRegion,
        ),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(tester.view.reset);
  }

  Future<void> turn(WidgetTester tester, {required bool landscape}) async {
    tester.view.physicalSize = landscape ? _landscape : _portrait;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  PhotoCarouselController controllerOf(WidgetTester tester) =>
      tester.widget<PhotoCarousel>(find.byType(PhotoCarousel)).controller!;

  List<String> mounted(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ];

  double zoom(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(ZoomablePhoto),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getMaxScaleOnAxis();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
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

  Future<void> swipe(WidgetTester tester, Offset from, double dx) async {
    await tester.timedDragFrom(
      from,
      Offset(dx, 0),
      const Duration(milliseconds: 320),
    );
    await settle(tester);
  }

  group('CA-016-12, CL-016-11: el giro con la foto 3 a la vista', () {
    testWidgets('gira y sigue la foto 3, con su desplazamiento y sin zoom', (
      tester,
    ) async {
      // Fotos más altas que la pantalla: hay desplazamiento vertical.
      final all = await photos(4, width: 2000, height: 6000);
      await pumpApp(tester, [groupTask(all)]);
      final controller = controllerOf(tester);
      controller
        ..next()
        ..next();
      await settle(tester);
      expect(controller.index, 2);

      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -300));
      await settle(tester);
      final scrolled = controller.scroll.position.pixels;
      expect(scrolled, greaterThan(200));

      await turn(tester, landscape: true);
      expect(find.byType(PhotoCarousel), findsOneWidget);
      expect(controllerOf(tester), same(controller));
      expect(controller.index, 2);
      expect(mounted(tester), [all[2].id]);
      expect(controller.scroll.position.pixels, scrolled);
      expect(zoom(tester), 1);
      expect(tester.getSize(find.byType(PhotoCarousel)).width, 844);

      // Y al volver a vertical, la misma foto, con su desplazamiento.
      await turn(tester, landscape: false);
      expect(controller.index, 2);
      expect(mounted(tester), [all[2].id]);
      expect(controller.scroll.position.pixels, scrolled);
      expect(find.byType(PhotoDots), findsOneWidget);
      expect(tester.widget<PhotoDots>(find.byType(PhotoDots)).index, 2);
    });

    testWidgets('un zoom en curso no pasa al otro lado del giro', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)]);
      final center = tester.getCenter(find.byType(ZoomablePhoto));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 11,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 12,
      );
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(zoom(tester), greaterThan(2));
      await a.up();
      await b.up();
      await turn(tester, landscape: true);
      await settle(tester);
      expect(zoom(tester), 1);
    });
  });

  group('CA-016-12: en horizontal, solo la foto y el logotipo', () {
    testWidgets('sin menú, botón, pie ni puntos', (tester) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)]);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.byType(PhotoDots), findsOneWidget);
      expect(find.byType(ImageCaption), findsOneWidget);

      await turn(tester, landscape: true);
      expect(find.byType(Wordmark), findsOneWidget);
      expect(find.byType(BrutalButton), findsNothing);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      expect(find.byType(ImageCaption), findsNothing);
      expect(find.byType(PhotoDots), findsNothing);
      expect(find.byType(TaskImage), findsNothing);
      expect(find.byType(PhotoCarousel), findsOneWidget);
    });

    testWidgets('el swipe, el pellizco y las acciones siguen', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)], screenReader: true);
      await turn(tester, landscape: true);
      final controller = controllerOf(tester);

      await swipe(tester, const Offset(600, 200), -300);
      expect(controller.index, 1);
      await swipe(tester, const Offset(300, 200), 300);
      expect(controller.index, 0);

      performCustom(tester, 'Foto siguiente');
      await settle(tester);
      expect(controller.index, 1);
      performCustom(tester, 'Foto anterior');
      await settle(tester);
      expect(controller.index, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(controller.index, 1);

      final center = tester.getCenter(find.byType(ZoomablePhoto));
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 21,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 22,
      );
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-6, 0));
        await b.moveBy(const Offset(6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(zoom(tester), greaterThan(2));
      expect(controller.index, 1, reason: 'dos dedos no cambian de foto');
      await a.up();
      await b.up();
      await settle(tester);
      handle.dispose();
    });

    testWidgets('el desplazamiento vertical de la foto sigue en horizontal', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)]);
      await turn(tester, landscape: true);
      final controller = controllerOf(tester);
      // 4000 × 3000 a 844 de ancho mide 633,0 de alto en 390: sin el margen del
      // pie y los puntos de vertical (que en horizontal no existen).
      expect(controller.scroll.position.maxScrollExtent, closeTo(243, 1));
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -150));
      await settle(tester);
      expect(controller.scroll.position.pixels, greaterThan(100));
      expect(controller.index, 0);
    });

    testWidgets('la lectura dice "Tarea actual: {texto}. Foto {i} de {n}" y '
        'el nodo de la región viva sigue dentro de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)], screenReader: true);
      await turn(tester, landscape: true);
      expect(
        find.bySemanticsLabel('Tarea actual: $_text. Foto 1 de 3'),
        findsOneWidget,
      );
      performCustom(tester, 'Foto siguiente');
      await settle(tester);
      expect(
        find.bySemanticsLabel('Tarea actual: $_text. Foto 2 de 3'),
        findsOneWidget,
      );
      final live = tester.getRect(find.byType(PhotoAnnouncements));
      expect(live.isEmpty, isFalse);
      expect(const Rect.fromLTWH(0, 0, 844, 390).contains(live.center), isTrue);
      handle.dispose();
    });
  });

  group('CA-016-12: bloqueo de rotación del sistema', () {
    testWidgets('la app solo avisa de que la tarea puede girar: no fuerza la '
        'orientación y deja de pedirlo al pasar a una tarea sin adjunto', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpApp(tester, [
        groupTask(all),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'MC'),
      ], screenReader: true);
      expect(rotating(), isTrue);
      // Permite girar (vertical y las dos horizontales); el sistema decide si
      // lo hace (con el bloqueo puesto, no gira).
      expect(
        orientations.last,
        containsAll([
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]),
      );
      await turn(tester, landscape: true);
      expect(
        calls.where((c) => !c.startsWith('rotateWithAttachment:')),
        isEmpty,
        reason: 'no pide ninguna orientación fija',
      );
      handle.dispose();
    });

    testWidgets('con "Adjunto no disponible" no gira, ni un momento', (
      tester,
    ) async {
      final all = await photos(2);
      // Faltan las dos: tarjeta.
      for (final a in all) {
        store.removeFile(a.id, 'full-0-0.jpg');
      }
      await pumpApp(tester, [groupTask(all)]);
      await turn(tester, landscape: true);
      expect(rotating(), isNot(true));
    });

    testWidgets('donde no gira (web de pruebas), la ventana apaisada se ve '
        'como en vertical', (tester) async {
      final all = await photos(3);
      await pumpApp(tester, [groupTask(all)], rotates: false);
      await turn(tester, landscape: true);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      expect(find.byType(PhotoDots), findsOneWidget);
      expect(find.byType(ImageCaption), findsOneWidget);
    });
  });

  group('CL-016-22: la card de deshacer en horizontal', () {
    testWidgets('eliminar en horizontal con otra tarea con grupo detrás: la '
        'card se ve junto a la foto y el logotipo', (tester) async {
      final handle = tester.ensureSemantics();
      final a = await photos(3);
      final b = await photos(2);
      await pumpApp(tester, [
        groupTask(a, rank: 'MB'),
        groupTask(b, id: 't2', rank: 'MC', text: 'Segunda'),
      ], screenReader: true);
      await turn(tester, landscape: true);
      performCustom(tester, 'Eliminar tarea');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(UnaMotion.crumple);
      // El ancho completo se pide tras montar la tarea que sigue.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(UndoCard), findsOneWidget);
      final card = tester.getRect(find.byType(UndoCard));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(844));
      expect(card.bottom, lessThanOrEqualTo(390));
      // Sigue la siguiente tarea, en horizontal, con su primera foto.
      expect(controllerOf(tester).index, 0);
      expect(mounted(tester), [b[0].id]);
      expect(find.byType(HoldToCompleteButton), findsNothing);
      expect(find.byType(Wordmark), findsOneWidget);
      expect(tester.getSize(find.byType(PhotoCarousel)).width, 844);
      expect(rotating(), isTrue);
      handle.dispose();
    });

    testWidgets('sin más tareas con adjunto vuelve a vertical y la card '
        'sigue', (tester) async {
      final handle = tester.ensureSemantics();
      final a = await photos(3);
      await pumpApp(tester, [
        groupTask(a, rank: 'MB'),
        sampleTask(id: 't2', text: 'Sin adjunto', rank: 'MC'),
      ], screenReader: true);
      await turn(tester, landscape: true);
      performCustom(tester, 'Eliminar tarea');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(UnaMotion.crumple);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sin adjunto'), findsOneWidget);
      expect(rotating(), isFalse);
      expect(find.byType(UndoCard), findsOneWidget);
      handle.dispose();
    });
  });
}
