import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attach_sheet.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/image_viewer_screen.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Móvil pequeño de CA-007-23.
const _phone = Size(360, 780);
const _long =
    'Llevar el horario del festival de verano impreso y las entradas de todos';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

/// Pautas de accesibilidad de Flutter: objetivos de 48 dp (Android),
/// etiquetados, y contraste del texto.
Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// [finder] se puede ver entero: dentro de la pantalla y, si está en una zona
/// desplazable, dentro de ella tras desplazarse hasta él (nada se corta).
/// Con [settle] a false no avanza el reloj (una importación en curso).
Future<void> _reachable(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  settle ? await tester.pumpAndSettle() : await tester.pump();
  final r = tester.getRect(finder);
  final scrollable = find.ancestor(
    of: finder,
    matching: find.byType(Scrollable),
  );
  final Rect area = scrollable.evaluate().isEmpty
      ? Offset.zero & _phone
      : tester.getRect(scrollable.first);
  expect(
    area.inflate(0.5).contains(r.topLeft),
    isTrue,
    reason: '$finder $r en $area',
  );
  expect(
    area.inflate(0.5).contains(r.bottomRight),
    isTrue,
    reason: '$finder $r en $area',
  );
}

void main() {
  // Con la fuente de pruebas cada letra mide 1 em: los anchos a 200 % solo
  // son fieles con Archivo y Space Mono.
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
  ];

  Future<Task> imageTask(
    String id, {
    String? text = _long,
    String rank = 'M',
    AttachmentOrigin origin = AttachmentOrigin.camera,
  }) async {
    final attachment = await store.commit(
      stageImage(store, 'a-$id', origin: origin),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(id: id, text: text ?? 'x', rank: rank);
    return base.withContent(text, attachment, base.updatedAt);
  }

  /// La app completa con el texto al 200 % en 360 dp.
  Future<void> pumpBig(WidgetTester tester) async {
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    tester.view.physicalSize = _phone;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditorBig(
    WidgetTester tester, {
    Task? task,
    EdgeInsets keyboard = EdgeInsets.zero,
  }) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(
        mode: task == null ? EditorMode.first : EditorMode.edit,
        task: task,
      ),
      repo: repo,
      size: _phone,
      textScale: 2,
      viewInsets: keyboard,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  group('CA-007-23: texto al 200 % en 360 dp, en cada pantalla con imagen', () {
    testWidgets('hoja "Añadir a la tarea": filas enteras y ≥ 48 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditorBig(tester);
      await tester.ensureVisible(_plus);
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AttachSheet), findsOneWidget);
      for (final row in [
        'Hacer foto',
        'Subir imagen',
        'Subir archivo',
        'Cargar URL',
      ]) {
        await _reachable(tester, find.text(row));
      }
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('editor con imagen: cabe; con el teclado abierto se desplaza '
        'hasta el final sin cortarse', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditorBig(tester, task: await imageTask('t1'));
      expect(tester.takeException(), isNull);
      await _meetsGuidelines(tester);
      await tester.pumpWidget(const SizedBox());
      await pumpEditorBig(
        tester,
        task: await imageTask('t2'),
        keyboard: const EdgeInsets.only(bottom: 300),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AttachmentPreview), findsOneWidget);
      await _meetsGuidelines(tester);

      final scrollable = find
          .descendant(
            of: find.byType(TaskEditorScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(position.pixels, position.maxScrollExtent);
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('"Preparando imagen…" se ve entero, con "Cancelar" ≥ 48 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditorBig(tester);
      importer.sanitizeDelay = const Duration(seconds: 5);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imagen'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await _reachable(tester, find.text('Preparando imagen…'), settle: false);
      await _reachable(tester, find.text('Cancelar').last, settle: false);
      await _meetsGuidelines(tester);
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    });

    testWidgets('pantalla principal con imagen y pie largo', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask('t1'));
      await pumpBig(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TaskImage), findsOneWidget);
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    testWidgets('visor', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask('t1'));
      await pumpBig(tester);
      await tester.tap(find.byType(TaskImage));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _reachable(tester, find.bySemanticsLabel('Cerrar'));
      await _meetsGuidelines(tester);
      handle.dispose();
    });

    for (final text in [_long, null]) {
      testWidgets('"Adjunto no disponible" ${text == null ? 'sin' : 'con'} '
          'texto: tarjeta y acción enteras', (tester) async {
        final handle = tester.ensureSemantics();
        await repo.insert(await imageTask('t1', text: text));
        store.removeFile('a-t1', 'full-0-0.jpg');
        await pumpBig(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(MissingAttachmentCard), findsOneWidget);
        // El texto no se recorta: se lee entero desplazándose.
        if (text != null) {
          final caption = tester.widget<Text>(find.text(text));
          expect(caption.maxLines, isNull);
          expect(caption.overflow, isNot(TextOverflow.ellipsis));
        }
        await _reachable(
          tester,
          find.text(text == null ? 'Eliminar tarea' : 'Quitar adjunto'),
        );
        // La acción no queda debajo de "Pulsa para completar".
        final action = tester.getRect(
          find.text(text == null ? 'Eliminar tarea' : 'Quitar adjunto'),
        );
        expect(
          action.overlaps(tester.getRect(find.byType(HoldToCompleteButton))),
          isFalse,
        );
        await _meetsGuidelines(tester);
        handle.dispose();
      });
    }

    testWidgets('listado con miniaturas e insignias', (tester) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask('t1', rank: 'A'));
      await repo.insert(
        await imageTask(
          't2',
          text: null,
          rank: 'B',
          origin: AttachmentOrigin.gallery,
        ),
      );
      await repo.insert(await imageTask('t3', text: 'Mapa', rank: 'C'));
      store.removeFile('a-t3', 'full-0-0.jpg');
      await pumpBig(tester);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(TaskThumbnail), findsWidgets);
      await _meetsGuidelines(tester);
      handle.dispose();
    });
  });

  group('Revisión de accesibilidad (T-007-25)', () {
    /// ¿Se ve el anillo de foco de [of] (por encima o por debajo)?
    bool ringVisible(WidgetTester tester, Finder of) => [
      ...tester.widgetList<FocusRing>(
        find.ancestor(of: of, matching: find.byType(FocusRing)),
      ),
      ...tester.widgetList<FocusRing>(
        find.descendant(of: of, matching: find.byType(FocusRing)),
      ),
    ].any((r) => r.visible);

    testWidgets('CA-007-21 / WCAG 2.1.1: con teclado, Tab llega a la imagen, '
        'se ve el anillo e Intro abre el visor', (tester) async {
      await repo.insert(await imageTask('t1', text: 'Horario'));
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringVisible(tester, find.byType(TaskImage)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsOneWidget);
    });

    testWidgets('visor: el anillo se ve en la imagen con teclado; tras pasar '
        'a "Cerrar" con Tab, + sigue ampliando; Esc cierra', (tester) async {
      await repo.insert(await imageTask('t1', text: 'Horario'));
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TaskImage));
      await tester.pumpAndSettle();
      // Modo teclado.
      await tester.sendKeyEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FocusRing>(
              find.descendant(
                of: find.byType(ImageViewerScreen),
                matching: find.byType(FocusRing),
              ),
            )
            .first
            .visible,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ringVisible(tester, find.byType(UnaIcon).last), isTrue);
      final viewer = find.byType(InteractiveViewer);
      double scale() => tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      expect(scale(), greaterThan(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerScreen), findsNothing);
    });

    testWidgets('visor: el lector lee la imagen antes que "Cerrar"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await repo.insert(await imageTask('t1', text: 'Horario'));
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TaskImage));
      await tester.pumpAndSettle();
      expect(
        tester.semantics.simulatedAccessibilityTraversal(
          startNode: find.semantics.byLabel('Foto'),
          endNode: find.semantics.byLabel('Cerrar'),
        ),
        isNotEmpty,
      );
      handle.dispose();
    });

    testWidgets('"Quitar adjunto" recibe el foco con Tab y muestra el anillo', (
      tester,
    ) async {
      await pumpWithApp(
        tester,
        TaskEditorScreen(
          mode: EditorMode.edit,
          task: await imageTask('t1', text: 'Horario'),
        ),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      final remove = find.bySemanticsLabel('Quitar adjunto');
      for (var i = 0; i < 6 && !ringVisible(tester, remove); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(ringVisible(tester, remove), isTrue);
    });

    testWidgets('CA-007-22: cerrar la hoja sin elegir devuelve el foco a (+)', (
      tester,
    ) async {
      await pumpWithApp(
        tester,
        const TaskEditorScreen(mode: EditorMode.first),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AttachSheet), findsNothing);
      final plus = tester.widget<BrutalButton>(
        find.byWidgetPredicate(
          (w) =>
              w is BrutalButton && w.label == 'Añadir foto, imagen o archivo',
        ),
      );
      expect(plus.focusNode!.hasFocus, isTrue);
    });

    testWidgets('WCAG 2.4.11: al 200 %, el aviso de error no tapa el (+)', (
      tester,
    ) async {
      importer.copyError = const ImageImportFailure(
        ImageImportError.unsupportedType,
      );
      await pumpEditorBig(tester);
      await tester.ensureVisible(_plus);
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imagen'));
      await tester.pumpAndSettle();
      // La tarjeta visible (el SnackBar incluye su margen transparente).
      final snack = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(snack.overlaps(tester.getRect(_plus)), isFalse);
      expect(snack.top, greaterThanOrEqualTo(0));
    });

    testWidgets('mientras se prepara otra, el lector no lee la imagen tapada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditorBig(tester, task: await imageTask('t1', text: 'Horario'));
      importer.sanitizeDelay = const Duration(seconds: 5);
      await tester.ensureVisible(_plus);
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imagen'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Preparando imagen…'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    });
  });

  group('CA-007-22: foco y anuncios', () {
    // El resto de filas de la tabla tienen su test junto a su pantalla:
    // editor_image_test (vuelta, cancelar, quitar, preparando, error),
    // image_viewer_test (abrir, zoom, cerrar) y missing_attachment_test.
    testWidgets('abrir la hoja "Añadir": la hoja se anuncia por su nombre y '
        'empieza por el título como encabezado', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(
        tester,
        const TaskEditorScreen(mode: EditorMode.first),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();

      // Android y iOS anuncian el nombre de la ruta nueva: un único anuncio,
      // sin `announce` aparte.
      final route = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Hacer foto'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    (w.properties.namesRoute ?? false) &&
                    (w.properties.scopesRoute ?? false),
              ),
            )
            .first,
      );
      expect(route.label, 'Añadir a la tarea');
      expect(route.flagsCollection.namesRoute, isTrue);
      expect(route.flagsCollection.scopesRoute, isTrue);

      // El primer elemento que recorre el lector es el título, encabezado.
      final heading = tester.getSemantics(
        find.bySemanticsLabel('Añadir a la tarea').last,
      );
      expect(heading.flagsCollection.isHeader, isTrue);
      final order = <String>[];
      route.visitChildren((node) {
        void walk(SemanticsNode n) {
          if (n.label.isNotEmpty) order.add(n.label);
          n.visitChildren((c) {
            walk(c);
            return true;
          });
        }

        walk(node);
        return true;
      });
      expect(order.first, 'Añadir a la tarea');
      handle.dispose();
    });
  });
}
