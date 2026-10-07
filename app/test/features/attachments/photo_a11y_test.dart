// Lectura, teclado y anuncios del carrusel de fotos (T-016-17; CA-016-20 y 21,
// CA-016-12 en horizontal): el nodo de la tarea (etiqueta al día y siempre el
// mismo), sus acciones y su orden, las de desplazamiento (vertical de la foto
// que se ve y horizontal), el foco de teclado con anillo y flechas, y el
// anuncio único "Foto {i} de {n}" con sus dos mecanismos (región viva y
// `sendAnnouncement`).
import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/photo_announcer.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/focus_on_signal.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/semantics_stops.dart';

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

  List<Override> overrides(PhotoAnnouncerMode mode) => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
    photoAnnouncerModeProvider.overrideWithValue(mode),
  ];

  Future<List<Attachment>> photos(
    int n, {
    int width = 4000,
    int height = 3000,
  }) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'a${base + i}';
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

  Task taskOf(List<Attachment> attachments, {String? text = _text}) {
    final base = sampleTask(text: text ?? 'x', colorKey: 3, rank: 'M');
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
    PhotoAnnouncerMode mode = PhotoAnnouncerMode.liveRegion,
    Locale locale = const Locale('es'),
    Size size = const Size(390, 844),
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await pumpWithApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: CurrentTaskScreen(task: task),
        ),
      ),
      locale: locale,
      size: size,
      overrides: overrides(mode),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// El nodo de la tarea (el único cuya etiqueta empieza por "Tarea actual").
  SemanticsNode taskNode(WidgetTester tester) => tester.getSemantics(
    find.bySemanticsLabel(RegExp('^(Tarea actual|Current task): ')),
  );

  String labelOf(WidgetTester tester) =>
      taskNode(tester).getSemanticsData().label;

  /// Las etiquetas de las acciones personalizadas del nodo de la tarea, en el
  /// orden en que el lector las ofrece.
  List<String> customActionsOf(WidgetTester tester) => [
    for (final id
        in taskNode(tester).getSemanticsData().customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void perform(WidgetTester tester, SemanticsAction action, [Object? args]) {
    final node = taskNode(tester);
    node.owner!.performAction(node.id, action, args);
  }

  void performCustom(WidgetTester tester, String label) {
    final node = taskNode(tester);
    final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == label,
    );
    node.owner!.performAction(node.id, SemanticsAction.customAction, id);
  }

  bool has(WidgetTester tester, SemanticsAction action) =>
      taskNode(tester).getSemanticsData().hasAction(action);

  /// Los nodos de región viva del árbol.
  List<SemanticsNode> liveNodes(WidgetTester tester) {
    final found = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().flagsCollection.isLiveRegion) {
        found.add(node);
      }
      node.visitChildren((child) {
        visit(child);
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
    return found;
  }

  /// Lo que se ha anunciado (cada anuncio, una vez), sea cual sea el
  /// mecanismo: los de `sendAnnouncement` o cada texto no vacío que tomó la
  /// región viva.
  List<String> Function() recordAnnouncements(
    WidgetTester tester,
    PhotoAnnouncerMode mode,
  ) {
    final said = <String>[];
    if (mode == PhotoAnnouncerMode.announcement) {
      return () {
        said.addAll([for (final a in tester.takeAnnouncements()) a.message]);
        final out = [...said];
        said.clear();
        return out;
      };
    }
    String? last;
    final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
    owner.addListener(() {
      final nodes = liveNodes(tester);
      final label = nodes.isEmpty ? '' : nodes.single.getSemanticsData().label;
      if (label == last) return;
      last = label;
      if (label.isNotEmpty) said.add(label);
    });
    return () {
      final out = [...said];
      said.clear();
      return out;
    };
  }

  /// Avanza el reloj en fotogramas de 16 ms (la transición y el antirrebote
  /// cuentan con el reloj de los fotogramas).
  Future<void> advance(WidgetTester tester, Duration total) async {
    for (var t = 0; t < total.inMilliseconds; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Deja pasar la transición, el antirrebote y el vaciado de la región viva.
  Future<void> settle(WidgetTester tester) async {
    await advance(tester, const Duration(milliseconds: 800));
    await advance(tester, const Duration(seconds: 3));
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.timedDragFrom(
      Offset(dx < 0 ? 330 : 60, 300),
      Offset(dx, 0),
      const Duration(milliseconds: 320),
    );
    await tester.pump();
  }

  const modes = PhotoAnnouncerMode.values;

  group('CA-016-20: un solo nodo con la etiqueta de la foto', () {
    for (final (lang, expected, withoutText) in [
      (
        'es',
        'Tarea actual: Horario del festival. 3 fotos. Foto 1 de 3',
        'Tarea actual: 3 fotos. Foto 1 de 3',
      ),
      (
        'en',
        'Current task: Horario del festival. 3 photos. Photo 1 of 3',
        'Current task: 3 photos. Photo 1 of 3',
      ),
    ]) {
      testWidgets('($lang) la etiqueta dice texto, número de fotos y foto '
          'actual; sin texto, sin el texto', (tester) async {
        final handle = tester.ensureSemantics();
        final all = await photos(3);
        await pumpScreen(tester, taskOf(all), locale: Locale(lang));
        expect(labelOf(tester), expected);
        await pumpScreen(tester, taskOf(all, text: null), locale: Locale(lang));
        expect(labelOf(tester), withoutText);
        handle.dispose();
      });
    }

    testWidgets('las fotos y el pie no se leen aparte ni como "imagen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final data = taskNode(tester).getSemanticsData();
      expect(data.flagsCollection.isImage, isFalse);
      expect(data.label, isNot(contains('imagen')));
      expect(find.bySemanticsLabel(_text), findsNothing);
      handle.dispose();
    });

    for (final mode in modes) {
      testWidgets('(${mode.name}) la etiqueta se mantiene al día y el nodo es '
          'el mismo (no se recrea)', (tester) async {
        final handle = tester.ensureSemantics();
        final all = await photos(3);
        await pumpScreen(tester, taskOf(all), mode: mode);
        final id = taskNode(tester).id;
        expect(labelOf(tester), endsWith('Foto 1 de 3'));

        perform(tester, SemanticsAction.scrollLeft);
        await settle(tester);
        expect(labelOf(tester), endsWith('Foto 2 de 3'));
        expect(taskNode(tester).id, id);

        await swipe(tester, -200);
        await settle(tester);
        expect(labelOf(tester), endsWith('Foto 3 de 3'));
        expect(taskNode(tester).id, id);

        // Infinito: tras la última, la primera.
        perform(tester, SemanticsAction.scrollLeft);
        await settle(tester);
        expect(labelOf(tester), endsWith('Foto 1 de 3'));
        expect(taskNode(tester).id, id);
        handle.dispose();
      });
    }

    testWidgets('una foto que falta: "Foto 2 de 3. Foto no disponible" en la '
        'etiqueta', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      store.removeFile(all[1].id, 'full-0-0.jpg');
      await pumpScreen(tester, taskOf(all));
      expect(labelOf(tester), endsWith('Foto 1 de 3'));
      perform(tester, SemanticsAction.scrollLeft);
      await settle(tester);
      expect(labelOf(tester), endsWith('Foto 2 de 3. Foto no disponible'));
      expect(labelOf(tester), isNot(contains('Foto 1')));
      handle.dispose();
    });
  });

  group('CA-016-20: acciones y su orden', () {
    testWidgets('Foto siguiente, Foto anterior, Completar tarea y Eliminar '
        'tarea, en ese orden, más las de desplazar a izquierda y derecha', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      final repo = InMemoryTaskRepository();
      await repo.insert(taskOf(all));
      await pumpUnaApp(tester, repo: repo, overrides: overrides(modes.first));
      await tester.pumpAndSettle();
      expect(customActionsOf(tester), [
        'Foto siguiente',
        'Foto anterior',
        'Completar tarea',
        'Eliminar tarea',
      ]);
      expect(has(tester, SemanticsAction.scrollLeft), isTrue);
      expect(has(tester, SemanticsAction.scrollRight), isTrue);
      handle.dispose();
    });

    testWidgets('en inglés, con las mismas acciones y el mismo orden', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      final repo = InMemoryTaskRepository();
      await repo.insert(taskOf(all));
      await pumpUnaApp(
        tester,
        repo: repo,
        locale: const Locale('en'),
        overrides: overrides(modes.first),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CurrentTaskScreen)),
      );
      expect(customActionsOf(tester), [
        l10n.a11yPhotoNext,
        l10n.a11yPhotoPrevious,
        l10n.completeA11yAction,
        l10n.deleteA11yAction,
      ]);
      handle.dispose();
    });

    testWidgets('con una sola foto no hay ninguna de las nuevas ni se manejan '
        'las flechas', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(1);
      await pumpScreen(tester, taskOf(all));
      expect(customActionsOf(tester), ['Completar tarea', 'Eliminar tarea']);
      expect(has(tester, SemanticsAction.scrollLeft), isFalse);
      expect(has(tester, SemanticsAction.scrollRight), isFalse);
      expect(liveNodes(tester), isEmpty);
      handle.dispose();
    });

    for (final mode in modes) {
      testWidgets('(${mode.name}) "Foto siguiente" y scrollLeft van a la '
          'siguiente; "Foto anterior" y scrollRight, a la anterior (con la '
          'vuelta por la última)', (tester) async {
        final handle = tester.ensureSemantics();
        final all = await photos(3);
        await pumpScreen(tester, taskOf(all), mode: mode);
        final controller = tester
            .widget<PhotoCarousel>(find.byType(PhotoCarousel))
            .controller!;
        expect(controller.index, 0);

        performCustom(tester, 'Foto siguiente');
        await settle(tester);
        expect(controller.index, 1);
        perform(tester, SemanticsAction.scrollLeft);
        await settle(tester);
        expect(controller.index, 2);
        perform(tester, SemanticsAction.scrollRight);
        await settle(tester);
        expect(controller.index, 1);
        performCustom(tester, 'Foto anterior');
        await settle(tester);
        performCustom(tester, 'Foto anterior');
        await settle(tester);
        expect(controller.index, 2, reason: 'antes de la primera, la última');
        handle.dispose();
      });
    }
  });

  group('CA-016-20: desplazamiento vertical de la foto que se ve', () {
    testWidgets('las acciones de desplazar siguen a la foto que se ve y la '
        'mueven a ella', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3, width: 1080, height: 6000);
      await pumpScreen(tester, taskOf(all));
      await tester.pump(const Duration(milliseconds: 100));

      // Foto 1, arriba del todo: solo hacia delante.
      expect(has(tester, SemanticsAction.scrollUp), isTrue);
      expect(has(tester, SemanticsAction.scrollDown), isFalse);
      // La acción la desplaza (y a ninguna otra).
      perform(tester, SemanticsAction.scrollUp);
      await tester.pumpAndSettle();
      expect(has(tester, SemanticsAction.scrollDown), isTrue);

      // Se lleva hasta el final.
      await tester.drag(find.byType(ZoomablePhoto), const Offset(0, -9000));
      await tester.pumpAndSettle();
      expect(has(tester, SemanticsAction.scrollUp), isFalse);
      expect(has(tester, SemanticsAction.scrollDown), isTrue);

      // La foto 2 no se ha visto: empieza arriba (solo hacia delante).
      perform(tester, SemanticsAction.scrollLeft);
      await settle(tester);
      expect(has(tester, SemanticsAction.scrollUp), isTrue);
      expect(has(tester, SemanticsAction.scrollDown), isFalse);

      // Y al volver a la 1, conserva su sitio: al final.
      perform(tester, SemanticsAction.scrollRight);
      await settle(tester);
      expect(has(tester, SemanticsAction.scrollUp), isFalse);
      expect(has(tester, SemanticsAction.scrollDown), isTrue);
      handle.dispose();
    });

    testWidgets('Av Pág y Re Pág desplazan la foto que se ve', (tester) async {
      final all = await photos(3, width: 1080, height: 6000);
      await pumpScreen(tester, taskOf(all));
      double pixels() => tester
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
      expect(pixels(), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(pixels(), greaterThan(300));

      // En otra foto, la que se mueve es esa.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(pixels(), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(pixels(), greaterThan(300));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(pixels(), 0);
    });
  });

  group('CA-016-20 y 21: un anuncio "Foto {i} de {n}" por cualquier vía', () {
    for (final mode in modes) {
      group(mode.name, () {
        testWidgets('una acción: un solo anuncio y tras el antirrebote', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          final all = await photos(3);
          await pumpScreen(tester, taskOf(all), mode: mode);
          final said = recordAnnouncements(tester, mode);
          expect(said(), isEmpty, reason: 'nada al abrir');

          performCustom(tester, 'Foto siguiente');
          // Aún dentro del antirrebote (la transición dura 280 ms).
          await advance(tester, const Duration(milliseconds: 100));
          expect(said(), isEmpty);
          await settle(tester);
          expect(said(), ['Foto 2 de 3']);
          handle.dispose();
        });

        testWidgets('desplazar con el lector, una tecla y un swipe real: un '
            'anuncio cada uno', (tester) async {
          final handle = tester.ensureSemantics();
          final all = await photos(3);
          await pumpScreen(tester, taskOf(all), mode: mode);
          final said = recordAnnouncements(tester, mode);

          perform(tester, SemanticsAction.scrollLeft);
          await settle(tester);
          expect(said(), ['Foto 2 de 3']);

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await settle(tester);
          expect(said(), ['Foto 3 de 3']);

          await swipe(tester, -200);
          await settle(tester);
          expect(said(), ['Foto 1 de 3']);

          await swipe(tester, 200);
          await settle(tester);
          expect(said(), ['Foto 3 de 3']);
          handle.dispose();
        });

        testWidgets('cinco cambios seguidos por acción: una frase por cambio '
            '(con la pausa del antirrebote entre ellos)', (tester) async {
          final handle = tester.ensureSemantics();
          final all = await photos(5);
          await pumpScreen(tester, taskOf(all), mode: mode);
          final said = recordAnnouncements(tester, mode);
          for (var i = 0; i < 5; i++) {
            performCustom(tester, 'Foto siguiente');
            await settle(tester);
          }
          expect(said(), [
            'Foto 2 de 5',
            'Foto 3 de 5',
            'Foto 4 de 5',
            'Foto 5 de 5',
            'Foto 1 de 5',
          ]);
          handle.dispose();
        });

        testWidgets('con tres cambios seguidos, solo se anuncia el último', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          final all = await photos(5);
          await pumpScreen(tester, taskOf(all), mode: mode);
          final said = recordAnnouncements(tester, mode);
          for (var i = 0; i < 3; i++) {
            performCustom(tester, 'Foto siguiente');
            // Rápido: cada cambio llega antes de que pase el antirrebote
            // (300 ms) del anterior.
            await advance(tester, const Duration(milliseconds: 150));
          }
          await settle(tester);
          expect(said(), ['Foto 4 de 5']);
          handle.dispose();
        });

        testWidgets('una foto que falta se anuncia "Foto 2 de 3. Foto no '
            'disponible"', (tester) async {
          final handle = tester.ensureSemantics();
          final all = await photos(3);
          store.removeFile(all[1].id, 'full-0-0.jpg');
          await pumpScreen(tester, taskOf(all), mode: mode);
          final said = recordAnnouncements(tester, mode);
          performCustom(tester, 'Foto siguiente');
          await settle(tester);
          expect(said(), ['Foto 2 de 3. Foto no disponible']);
          handle.dispose();
        });

        testWidgets('en inglés, en inglés', (tester) async {
          final handle = tester.ensureSemantics();
          final all = await photos(3);
          await pumpScreen(
            tester,
            taskOf(all),
            mode: mode,
            locale: const Locale('en'),
          );
          final said = recordAnnouncements(tester, mode);
          performCustom(tester, 'Next photo');
          await settle(tester);
          expect(said(), ['Photo 2 of 3']);
          handle.dispose();
        });
      });
    }
  });

  group('CA-016-20: la región viva (B)', () {
    testWidgets('nace vacía, no es parada de foco y tiene un rectángulo no '
        'vacío dentro de la pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final nodes = liveNodes(tester);
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.label, isEmpty, reason: 'nace vacía');
      expect(data.flagsCollection.isFocused, Tristate.none);
      expect(data.hasAction(SemanticsAction.focus), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      // TalkBack no debe poder pararse en él (emulador API 37, T-016-17: sin el
      // bloqueo, el nodo con texto salía como enfocable).
      expect(data.flagsCollection.isAccessibilityFocusBlocked, isTrue);
      // Rectángulo no vacío y dentro de la pantalla.
      expect(nodes.single.rect.isEmpty, isFalse);
      expect(
        const Rect.fromLTWH(
          0,
          0,
          390,
          844,
        ).contains(tester.getRect(find.byType(PhotoAnnouncements)).center),
        isTrue,
      );
      // Y no añade paradas sin nombre al recorrido del lector.
      expectNoUnnamedSemanticsStops(tester);
      handle.dispose();
    });

    testWidgets('también en horizontal: dentro de pantalla y sin anunciar al '
        'girar', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final said = recordAnnouncements(tester, PhotoAnnouncerMode.liveRegion);

      performCustom(tester, 'Foto siguiente');
      await settle(tester);
      expect(said(), ['Foto 2 de 3']);

      // Gira con la foto 2 a la vista: ni se vuelve a anunciar ni nace con
      // texto.
      await pumpScreen(tester, taskOf(all), size: const Size(844, 390));
      expect(said(), isEmpty);
      final nodes = liveNodes(tester);
      expect(nodes, hasLength(1));
      expect(nodes.single.getSemanticsData().label, isEmpty);
      expect(nodes.single.rect.isEmpty, isFalse);
      expect(
        const Rect.fromLTWH(
          0,
          0,
          844,
          390,
        ).contains(tester.getRect(find.byType(PhotoAnnouncements)).center),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('con el anuncio del sistema (A) no hay región viva', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(
        tester,
        taskOf(all),
        mode: PhotoAnnouncerMode.announcement,
      );
      expect(liveNodes(tester), isEmpty);
      handle.dispose();
    });
  });

  group('CA-016-12: horizontal', () {
    for (final mode in modes) {
      testWidgets('(${mode.name}) la lectura dice "Tarea actual: {texto}. Foto '
          '{i} de {n}"; acciones, flechas y anuncio siguen', (tester) async {
        final handle = tester.ensureSemantics();
        final all = await photos(3);
        await pumpScreen(
          tester,
          taskOf(all),
          mode: mode,
          size: const Size(844, 390),
        );
        expect(labelOf(tester), 'Tarea actual: $_text. Foto 1 de 3');
        expect(customActionsOf(tester), [
          'Foto siguiente',
          'Foto anterior',
          'Completar tarea',
          'Eliminar tarea',
        ]);
        final said = recordAnnouncements(tester, mode);
        performCustom(tester, 'Foto siguiente');
        await settle(tester);
        expect(labelOf(tester), 'Tarea actual: $_text. Foto 2 de 3');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await settle(tester);
        expect(labelOf(tester), 'Tarea actual: $_text. Foto 3 de 3');
        expect(said(), ['Foto 2 de 3', 'Foto 3 de 3']);
        handle.dispose();
      });
    }

    testWidgets('sin texto, "Tarea actual: Foto 1 de 3"', (tester) async {
      final handle = tester.ensureSemantics();
      final all = await photos(3);
      await pumpScreen(
        tester,
        taskOf(all, text: null),
        size: const Size(844, 390),
      );
      expect(labelOf(tester), 'Tarea actual: Foto 1 de 3');
      handle.dispose();
    });
  });

  group('CA-016-20: teclado', () {
    FocusNode? taskFocus(WidgetTester tester) => tester
        .widgetList<Focus>(find.byType(Focus))
        .map((f) => f.focusNode)
        .whereType<FocusNode>()
        .where((n) => n.debugLabel == 'task')
        .firstOrNull;

    int index(WidgetTester tester) => tester
        .widget<PhotoCarousel>(find.byType(PhotoCarousel))
        .controller!
        .index;

    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets('el elemento de la tarea recibe el foco al abrir en frío y '
        'está en el recorrido', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      final node = taskFocus(tester)!;
      expect(node.hasPrimaryFocus, isTrue);
      expect(node.skipTraversal, isFalse);
      expect(node.canRequestFocus, isTrue);
    });

    testWidgets('con una sola foto sigue fuera del recorrido y sin el foco '
        'inicial (como la 007)', (tester) async {
      final all = await photos(1);
      await pumpScreen(tester, taskOf(all));
      final node = taskFocus(tester)!;
      expect(node.hasPrimaryFocus, isFalse);
      expect(node.skipTraversal, isTrue);
    });

    testWidgets('con el foco, flecha derecha = siguiente e izquierda = '
        'anterior', (tester) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(index(tester), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(index(tester), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(index(tester), 2, reason: 'infinito');
      // El foco no se movió a otro control.
      expect(taskFocus(tester)!.hasPrimaryFocus, isTrue);
    });

    testWidgets('sin el foco en el elemento, las flechas no cambian de foto', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpScreen(tester, taskOf(all));
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(taskFocus(tester)!.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(index(tester), 0);
    });

    testWidgets('una tecla mantenida cambia una sola vez y no pasa el foco a '
        'otro control', (tester) async {
      final all = await photos(4);
      await pumpScreen(tester, taskOf(all));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(index(tester), 1);
      expect(taskFocus(tester)!.hasPrimaryFocus, isTrue);
    });

    for (final modifier in [
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      testWidgets('con ${modifier.keyLabel} la flecha no cambia de foto', (
        tester,
      ) async {
        final all = await photos(3);
        await pumpScreen(tester, taskOf(all));
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(modifier);
        await settle(tester);
        expect(index(tester), 0);
      });
    }

    testWidgets('el anillo de foco (blanco y negro) se ve solo con el foco '
        'del teclado y dentro de los márgenes del sistema', (tester) async {
      final all = await photos(3);
      await pumpScreen(
        tester,
        taskOf(all),
        padding: const EdgeInsets.only(top: 40, bottom: 30, left: 20),
      );
      final ring = find.descendant(
        of: find.byType(FocusOnSignal),
        matching: find.byType(FocusRing),
      );
      expect(ring, findsNothing, reason: 'con el tacto no se ve');

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(ring, findsOneWidget);
      expect(tester.widget<FocusRing>(ring).inside, isTrue);
      expect(tester.getRect(ring), const Rect.fromLTRB(20, 40, 390, 844 - 30));
    });

    testWidgets('en horizontal, el anillo y las flechas también', (
      tester,
    ) async {
      final all = await photos(3);
      await pumpScreen(
        tester,
        taskOf(all),
        size: const Size(844, 390),
        padding: const EdgeInsets.only(left: 44, right: 44),
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      final ring = find.descendant(
        of: find.byType(FocusOnSignal),
        matching: find.byType(FocusRing),
      );
      expect(ring, findsOneWidget);
      expect(tester.getRect(ring), const Rect.fromLTRB(44, 0, 844 - 44, 390));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(index(tester), 1);
    });
  });
}
