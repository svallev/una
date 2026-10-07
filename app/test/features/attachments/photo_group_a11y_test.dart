// Accesibilidad transversal de la tarea con varias fotos (T-016-22; CA-016-06,
// 09, 11, 14, 18a y 22): las guías de Flutter (tamaño de toque, etiquetas y
// contraste) con **las pantallas enteras** en cada estado del grupo —el editor
// con la pila, "Preparando foto {i} de {n}…", el aviso compuesto, "Foto no
// disponible" y el carrusel con los puntos— a texto ×1,0 y ×2,0, y "reducir
// movimiento" de punta a punta (sin transición al cambiar de foto, sin barra
// animada y con la pila fija). Cada pieza ya tiene su test propio; este
// comprueba que juntas, en la pantalla real, no se pisan.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/import_notice_banner.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _plusLabel = 'Añadir foto, imagen o archivo';
const _failing = ImageImportFailure(ImageImportError.unsupportedType);

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  var seq = 0;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
  ];

  /// Tarea guardada con [n] fotos (cada una con su pantalla, en el almacén).
  Future<Task> groupTask(int n) async {
    final all = <Attachment>[];
    final base = seq;
    seq += n;
    for (var i = 0; i < n; i++) {
      final id = 'a${base + i}';
      all.add(
        await store.commit(
          stageImage(store, id, width: 3000, height: 4000),
          DateTime.utc(2026, 9, 20),
        ),
      );
      store.putStored(id, 'screen.jpg', Uint8List.fromList(tinyImage));
    }
    final task = sampleTask(text: 'Horario del festival', colorKey: 3);
    return task.withContent(
      'Horario del festival',
      null,
      task.updatedAt,
      attachments: all,
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    Task? task,
    double textScale = 1.0,
    bool reduced = false,
  }) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(
        mode: task == null ? EditorMode.first : EditorMode.edit,
        task: task,
      ),
      repo: repo,
      textScale: textScale,
      disableAnimations: reduced,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickGroup(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(_plusLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir imágenes'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpCarousel(
    WidgetTester tester,
    Task task, {
    double textScale = 1.0,
    bool reduced = false,
  }) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: task),
      textScale: textScale,
      disableAnimations: reduced,
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Las cuatro guías de la tarea (CA-016-22), con el lector de pantalla a la
  /// vista para que haya árbol semántico.
  Future<void> expectGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets(
    'CA-016-04: "Preparando foto {i} de {n}…" lo leen solo el texto y '
    '"Cancelar": la barra de progreso no es un nodo',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEditor(tester);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(find.bySemanticsLabel(_plusLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      // La entrada de "Preparando" (a los 400 ms) y el cierre de la hoja.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Preparando foto'), findsOneWidget);
      // La barra se ve (sin reducir movimiento) y aun así no se lee.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final heard = <String>[];
      final roles = <SemanticsRole>[];
      void visit(SemanticsNode node) {
        if (!node.isInvisible) {
          final data = node.getSemanticsData();
          if (data.label.isNotEmpty || data.value.isNotEmpty) {
            heard.add(data.label.isNotEmpty ? data.label : data.value);
          }
          roles.add(data.role);
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
      expect(roles, isNot(contains(SemanticsRole.loadingSpinner)));
      expect(roles, isNot(contains(SemanticsRole.progressBar)));
      // El área de "Preparando" aporta solo esos dos nodos; después vienen los
      // del editor (campo, (+) y Guardar), que no son suyos.
      expect(heard.take(2), ['Preparando foto 1 de 3…', 'Cancelar']);
      expect(heard.skip(2), isNot(contains(startsWith('Preparando'))));

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );

  for (final scale in [1.0, 2.0]) {
    group('CA-016-22: guías de accesibilidad con el texto ×$scale', () {
      testWidgets('CA-016-06: el editor con el grupo (pila y "3 fotos")', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpEditor(tester, textScale: scale);
        await pickGroup(tester);
        expect(find.byType(PhotoStack), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('CA-016-04: "Preparando foto {i} de {n}…"', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpEditor(tester, textScale: scale);
        importer.sanitizeDelay = const Duration(seconds: 2);
        await tester.tap(find.bySemanticsLabel(_plusLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Subir imágenes'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Preparando foto'), findsOneWidget);
        await expectGuidelines(tester);
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        semantics.dispose();
      });

      testWidgets('CA-016-21: el aviso compuesto (más de 10 y fallidas)', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpEditor(tester, textScale: scale);
        importer.manyTotal = 12;
        importer.copyErrorsByToken['content://many-0'] = _failing;
        importer.copyErrorsByToken['content://many-3'] = _failing;
        await pickGroup(tester);
        expect(find.byType(ImportNoticeBanner), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('CA-016-18a: "Foto no disponible" en la pila del editor', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final task = await groupTask(3);
        store.removeFile(task.attachments.first.id, 'full-0-0.jpg');
        await pumpEditor(tester, task: task, textScale: scale);
        expect(find.byType(PhotoMissingBox), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('CA-016-09/11: el carrusel con los puntos bajo el pie', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpCarousel(tester, await groupTask(3), textScale: scale);
        expect(find.byType(PhotoDots), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('CA-016-18a: "Foto no disponible" en el carrusel', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final task = await groupTask(3);
        store.removeFile(task.attachments[1].id, 'full-0-0.jpg');
        await pumpCarousel(tester, task, textScale: scale);
        await tester.timedDragFrom(
          const Offset(330, 400),
          const Offset(-250, 0),
          const Duration(milliseconds: 320),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Foto no disponible'), findsOneWidget);
        await expectGuidelines(tester);
        semantics.dispose();
      });
    });
  }

  group('CA-016-22: con reducir movimiento, de punta a punta', () {
    testWidgets('el carrusel cambia de foto sin ninguna transición', (
      tester,
    ) async {
      final task = await groupTask(3);
      await pumpCarousel(tester, task, reduced: true);
      final ids = [for (final a in task.attachments) a.id];
      String? shown() {
        final c = tester.widget<PhotoDots>(find.byType(PhotoDots));
        return ids[c.index];
      }

      expect(shown(), ids[0]);
      await tester.timedDragFrom(
        const Offset(330, 400),
        const Offset(-250, 0),
        const Duration(milliseconds: 320),
      );
      // Un solo fotograma tras soltar: ya está en la foto siguiente y no
      // queda nada animándose (ni la foto ni los puntos).
      await tester.pump();
      expect(shown(), ids[1]);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(PhotoCarousel), findsOneWidget);
    });

    testWidgets('"Preparando foto {i} de {n}…" sin barra animada', (
      tester,
    ) async {
      await pumpEditor(tester, reduced: true);
      importer.sanitizeDelay = const Duration(seconds: 10);
      await tester.tap(find.bySemanticsLabel(_plusLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      // La entrada de "Preparando" (a los 400 ms) y el cierre de la hoja.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Preparando foto'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Pasada la entrada de "Preparando", nada se anima mientras dura.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.hasRunningAnimations, isFalse, reason: 'paso $i');
      }
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();
    });

    testWidgets('la pila del editor se queda fija con las fotos giradas', (
      tester,
    ) async {
      await pumpEditor(tester, reduced: true);
      await pickGroup(tester);
      Matrix4 card(int i) =>
          tester.widget<Transform>(find.byKey(PhotoStack.cardKey(i))).transform;
      final before = [for (var i = 0; i < 3; i++) card(i).clone()];
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      for (var i = 0; i < 3; i++) {
        expect(card(i), before[i]);
      }
      // Giradas (no es que la pila esté recta por no animarse).
      expect(
        math.atan2(card(0).storage[1], card(0).storage[0]).abs(),
        greaterThan(0),
      );
    });
  });
}
