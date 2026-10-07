// El carrusel en la pantalla principal (T-016-16b; CA-016-08, 09, 11 y 22):
// puntos, pie fijo y margen inferior desde las cajas reales, el carrusel en
// lugar de la imagen con 2 o más fotos y la vuelta a la primera foto tras 10
// minutos en segundo plano.
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/undo.dart';
import '../task_list/list_harness.dart' show FakeClock, background;

const _text = 'Horario del festival';

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  var seq = 0;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
  ];

  /// [n] fotos guardadas, cada una con bytes distintos en su pantalla.
  Future<List<Attachment>> photos(
    int n, {
    int width = 4000,
    int height = 3000,
  }) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 's${base + i}';
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

  Task taskOf(
    List<Attachment> attachments, {
    String? text = _text,
    String rank = 'M',
    String id = 't1',
  }) {
    final base = sampleTask(text: text ?? 'x', colorKey: 3, rank: rank, id: id);
    return base.withContent(
      text,
      null,
      base.updatedAt,
      attachments: attachments,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Task task, {
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: task),
      textScale: textScale,
      size: size,
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  final caption = find.byType(ImageCaption);
  final dots = find.byType(PhotoDots);
  final button = find.byType(HoldToCompleteButton);

  int shown(WidgetTester tester) => tester.widget<PhotoDots>(dots).index;

  List<String> mounted(WidgetTester tester) => [
    for (final z in tester.widgetList<ZoomablePhoto>(
      find.byType(ZoomablePhoto),
    ))
      z.attachment.id,
  ];

  /// Un swipe horizontal de [dx] dp en 320 ms, empezando en [from].
  Future<void> swipeFrom(WidgetTester tester, Offset from, double dx) async {
    await tester.timedDragFrom(
      from,
      Offset(dx, 0),
      const Duration(milliseconds: 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('CA-016-09: el carrusel en la pantalla principal', () {
    testWidgets('con 2 o más fotos, el carrusel en lugar de la imagen suelta; '
        'se abre en la primera', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      expect(find.byType(PhotoCarousel), findsOneWidget);
      expect(find.byType(TaskImage), findsNothing);
      expect(mounted(tester), [all[0].id]);
      expect(shown(tester), 0);
    });

    testWidgets('con una sola foto sigue la imagen de la 007: sin carrusel ni '
        'puntos y con su pie', (tester) async {
      final all = await photos(1);
      await pumpScreen(tester, taskOf(all));
      expect(find.byType(PhotoCarousel), findsNothing);
      expect(find.byType(TaskImage), findsOneWidget);
      expect(dots, findsNothing);
      expect(caption, findsOneWidget);
    });

    testWidgets('un punto por foto, lleno el de la foto que se ve', (
      tester,
    ) async {
      final all = await photos(4);
      await pumpScreen(tester, taskOf(all));
      expect(tester.widget<PhotoDots>(dots).count, 4);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(PhotoDots.dotKey(i)), findsOneWidget);
      }
      expect(shown(tester), 0);

      await swipeFrom(tester, const Offset(330, 300), -200);
      expect(shown(tester), 1);
      await swipeFrom(tester, const Offset(330, 300), -200);
      expect(shown(tester), 2);
      // Hacia atrás, y dando la vuelta por la primera (infinito).
      await swipeFrom(tester, const Offset(60, 300), 200);
      await swipeFrom(tester, const Offset(60, 300), 200);
      await swipeFrom(tester, const Offset(60, 300), 200);
      expect(shown(tester), 3);
    });
  });

  group('CA-016-08: cada tarea empieza en su primera foto', () {
    testWidgets('al pasar a otra tarea con fotos, la primera foto; con la '
        'misma tarea editada, la que se veía', (tester) async {
      final a = await photos(3);
      final b = await photos(3);
      final current = ValueNotifier<Task>(taskOf(a, id: 'a'));
      addTearDown(current.dispose);
      await pumpWithApp(
        tester,
        ValueListenableBuilder<Task>(
          valueListenable: current,
          builder: (_, task, _) => CurrentTaskScreen(task: task),
        ),
        overrides: overrides(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await swipeFrom(tester, const Offset(330, 300), -200);
      expect(shown(tester), 1);

      // Se edita el texto de la misma tarea: sigue en la misma foto.
      current.value = taskOf(a, id: 'a', text: 'Otro texto');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(tester), 1);
      expect(mounted(tester), [a[1].id]);

      // Otra tarea con fotos: empieza en la primera.
      current.value = taskOf(b, id: 'b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(tester), 0);
      expect(mounted(tester), [b[0].id]);
    });
  });

  group('CA-016-11: pie y puntos fijos, bajo el pie y sobre el botón', () {
    testWidgets('el pie y los puntos no se mueven al cambiar de foto', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final before = (tester.getRect(caption), tester.getRect(dots));
      final button0 = tester.getRect(button);

      // A mitad del arrastre y ya cambiada.
      final finger = await tester.startGesture(const Offset(330, 300));
      await finger.moveBy(const Offset(-120, 0));
      await tester.pump();
      expect((tester.getRect(caption), tester.getRect(dots)), before);
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(shown(tester), 1);
      expect((tester.getRect(caption), tester.getRect(dots)), before);
      expect(tester.getRect(button), button0);
    });

    testWidgets('los puntos van bajo el pie y encima del botón, centrados', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final c = tester.getRect(caption);
      final d = tester.getRect(dots);
      final b = tester.getRect(button);
      expect(c.bottom, lessThanOrEqualTo(d.top));
      expect(d.bottom, lessThanOrEqualTo(b.top));
      expect(d.center.dx, closeTo(195, 0.5));
      // El pie, como el de la imagen suelta: ancho completo menos 24 a cada
      // lado, y los puntos a unos 12 sobre el botón (prototipo).
      expect(c.left, UnaSpace.l);
      expect(c.right, 390 - UnaSpace.l);
      expect(b.top - d.bottom, closeTo(UnaSpace.sm, 1));
    });

    testWidgets('sin pie (tarea solo con fotos) los puntos van igual, sobre el '
        'botón', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all, text: null));
      expect(caption, findsNothing);
      final d = tester.getRect(dots);
      final b = tester.getRect(button);
      expect(d.bottom, lessThanOrEqualTo(b.top));
      expect(b.top - d.bottom, closeTo(UnaSpace.sm, 1));
    });

    for (final (name, scale, size) in [
      ('texto al 200 % a 360 dp', 2.0, const Size(360, 740)),
      ('texto al 130 % a 390 dp', 1.3, const Size(390, 844)),
    ]) {
      testWidgets('$name, con un pie de 3 líneas: sin solapes entre el pie, '
          'los puntos y el botón de completar', (tester) async {
        final all = await photos(10);
        await pumpScreen(
          tester,
          taskOf(
            all,
            text:
                'Llevar al festival las entradas impresas, el cargador, el '
                'agua y la chaqueta por si refresca al caer la tarde y no '
                'perder ningún concierto',
          ),
          textScale: scale,
          size: size,
        );
        final c = tester.getRect(caption);
        final d = tester.getRect(dots);
        final b = tester.getRect(button);
        // El pie crece (3 líneas) y todo cabe en el ancho.
        expect(c.height, greaterThan(70));
        expect(c.bottom, lessThanOrEqualTo(d.top));
        expect(d.bottom, lessThanOrEqualTo(b.top));
        expect(d.left, greaterThanOrEqualTo(0));
        expect(d.right, lessThanOrEqualTo(size.width));
        expect(c.top, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el pie y los puntos no se leen: la tarea es un solo nodo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final labels = <String>[];
      void visit(SemanticsNode n) {
        final label = n.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      // El texto solo va dentro de la etiqueta de la tarea, no suelto.
      expect(labels.where((l) => l == _text), isEmpty);
      expect(labels.where((l) => l.contains(_text)), hasLength(1));
      handle.dispose();
    });

    testWidgets('androidTapTargetGuideline y labeledTapTargetGuideline con el '
        'carrusel', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('CA-016-09: swipe sobre el pie y los puntos', () {
    testWidgets('un swipe que empieza sobre el pie cambia de foto', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      // A la derecha del texto, dentro del recuadro del pie.
      final c = tester.getRect(caption);
      await swipeFrom(tester, Offset(c.right - 20, c.center.dy), -200);
      expect(shown(tester), 1);
    });

    testWidgets('un swipe que empieza sobre los puntos cambia de foto: son '
        'transparentes a los toques', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      await swipeFrom(tester, tester.getCenter(dots), -200);
      expect(shown(tester), 1);
      await swipeFrom(tester, tester.getCenter(dots), 200);
      expect(shown(tester), 0);
    });

    testWidgets('los puntos no reciben ningún toque (IgnorePointer, fuera de '
        'la lectura)', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final ignore = tester.widget<IgnorePointer>(
        find.descendant(of: dots, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
      expect(
        find.descendant(of: dots, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });
  });

  group('CA-016-11: margen inferior desde las cajas reales', () {
    /// Lleva la foto actual al final de su desplazamiento.
    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -6000));
      await tester.pumpAndSettle();
    }

    /// El final de la foto que se ve.
    Rect photoRect(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(ZoomablePhoto),
            matching: find.byType(Image),
          )
          .first,
    );

    testWidgets('el final de una foto alta se ve encima del pie', (
      tester,
    ) async {
      final all = await photos(3, width: 1080, height: 6000);
      await pumpScreen(tester, taskOf(all));
      await scrollToEnd(tester);
      expect(
        photoRect(tester).bottom,
        lessThanOrEqualTo(tester.getRect(caption).top + 0.5),
      );
    });

    testWidgets('también sin pie (encima de los puntos) y con el texto al '
        '200 % a 360 dp', (tester) async {
      final all = await photos(3, width: 1080, height: 6000);
      await pumpScreen(tester, taskOf(all, text: null));
      await scrollToEnd(tester);
      expect(
        photoRect(tester).bottom,
        lessThanOrEqualTo(tester.getRect(dots).top + 0.5),
      );

      await pumpScreen(
        tester,
        taskOf(
          all,
          text:
              'Llevar al festival las entradas impresas, el cargador, el '
              'agua y la chaqueta por si refresca al caer la tarde',
        ),
        textScale: 2.0,
        size: const Size(360, 740),
      );
      await scrollToEnd(tester);
      expect(
        photoRect(tester).bottom,
        lessThanOrEqualTo(tester.getRect(caption).top + 0.5),
      );
    });

    testWidgets('la imagen suelta sigue sin margen (la 007 no cambia)', (
      tester,
    ) async {
      final all = await photos(1, width: 1080, height: 6000);
      await pumpScreen(tester, taskOf(all));
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(photoRect(tester).bottom, closeTo(844, 0.5));
    });
  });

  group('con la app entera', () {
    Future<InMemoryTaskRepository> pumpApp(
      WidgetTester tester, {
      required List<Task> tasks,
      List<String> plain = const [],
      FakeClock? clock,
    }) async {
      final repo = InMemoryTaskRepository();
      for (final t in tasks) {
        await repo.insert(t);
      }
      await pumpUnaApp(
        tester,
        repo: repo,
        tasks: plain,
        clock: clock ?? TesterClock(tester),
        overrides: [
          ...overrides(),
          accessibilityTimeoutsProvider.overrideWithValue(
            FakeAccessibilityTimeouts(),
          ),
        ],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('CA-016-08: con 10 minutos o más en segundo plano vuelve a la '
        'primera foto; con 9:59, la misma', (tester) async {
      final all = await photos(3);
      final clock = FakeClock();
      await pumpApp(tester, tasks: [taskOf(all)], clock: clock);
      expect(shown(tester), 0);

      await swipeFrom(tester, const Offset(330, 300), -200);
      await swipeFrom(tester, const Offset(330, 300), -200);
      expect(shown(tester), 2);

      background(tester, clock, const Duration(minutes: 9, seconds: 59));
      await tester.pumpAndSettle();
      expect(shown(tester), 2, reason: 'con menos de 10 minutos, la misma');
      expect(mounted(tester), [all[2].id]);

      background(tester, clock, UnaApp.resetAfter);
      await tester.pumpAndSettle();
      expect(shown(tester), 0, reason: 'con 10 minutos o más, la primera');
      expect(mounted(tester), [all[0].id]);
    });

    testWidgets('con la card de deshacer a la vista, el pie y los puntos '
        'quedan sobre ella y siguen en su sitio', (tester) async {
      final all = await photos(3);
      await pumpApp(
        tester,
        plain: ['Primera'],
        tasks: [taskOf(all, rank: 'MZ')],
      );
      // Elimina la primera (sin foto): la tarea con fotos pasa a ser la actual.
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(UnaMotion.crumple);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(UndoCard), findsOneWidget);
      expect(dots, findsOneWidget);

      final card = tester.getRect(find.byType(UndoCard));
      final d = tester.getRect(dots);
      final c = tester.getRect(caption);
      expect(d.bottom, lessThanOrEqualTo(card.top));
      expect(c.bottom, lessThanOrEqualTo(d.top));
      // Y se puede cambiar de foto con ella a la vista.
      await tester.timedDragFrom(
        const Offset(330, 300),
        const Offset(-200, 0),
        const Duration(milliseconds: 320),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(shown(tester), 1);
      expect(tester.getRect(dots), d);
    });
  });

  group('PhotoDots', () {
    testWidgets('lleno el actual y blancos los demás; borde de tinta y halo', (
      tester,
    ) async {
      await pumpWithApp(
        tester,
        const Material(
          color: UnaColors.paper,
          child: Center(child: PhotoDots(count: 3, index: 1)),
        ),
      );
      Color fillOf(int i) {
        final box = find.descendant(
          of: find.byKey(PhotoDots.dotKey(i)),
          matching: find.byType(DecoratedBox),
        );
        // El primero es el halo; el último, el punto.
        final inner = tester.widget<DecoratedBox>(box.last).decoration;
        return (inner as BoxDecoration).color!;
      }

      expect(fillOf(0), UnaColors.photoDotLight);
      expect(fillOf(1), UnaColors.photoDotInk);
      expect(fillOf(2), UnaColors.photoDotLight);
      // Cada punto (con el halo) mide 9 + 2 × 1,5.
      expect(
        tester.getSize(find.byKey(PhotoDots.dotKey(0))),
        const Size(
          UnaSizes.photoDot + 2 * UnaBorders.photoDotHaloWidth,
          UnaSizes.photoDot + 2 * UnaBorders.photoDotHaloWidth,
        ),
      );
      // Entre los bordes de tinta, la separación del prototipo (6).
      final gap =
          tester.getTopLeft(find.byKey(PhotoDots.dotKey(1))).dx -
          tester.getTopRight(find.byKey(PhotoDots.dotKey(0))).dx +
          2 * UnaBorders.photoDotHaloWidth;
      expect(gap, UnaSizes.photoDotGap);
    });

    testWidgets('con una sola foto no se dibuja nada', (tester) async {
      await pumpWithApp(
        tester,
        const Center(child: PhotoDots(count: 1, index: 0)),
      );
      expect(find.byType(DecoratedBox), findsNothing);
    });
  });
}
