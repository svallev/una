import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

const _plusLabel = 'Añadir foto, imagen o archivo';
final _plus = find.bySemanticsLabel(_plusLabel);
final _remove = find.bySemanticsLabel('Quitar adjunto');
final _stack = find.byType(PhotoStack);

/// No puede guardar (CA-016-07: el editor conserva el grupo).
class _FailingInsertRepo extends InMemoryTaskRepository {
  Object? error;

  @override
  Future<void> insert(Task task) async {
    if (error case final e?) throw e;
    return super.insert(task);
  }
}

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late _FailingInsertRepo repo;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = _FailingInsertRepo();
  });

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    EditorMode mode = EditorMode.first,
    Task? task,
    bool reduced = false,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    Locale locale = const Locale('es'),
  }) async {
    listen(tester);
    await pumpWithApp(
      tester,
      TaskEditorScreen(mode: mode, task: task),
      repo: repo,
      locale: locale,
      disableAnimations: reduced,
      textScale: textScale,
      size: size,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(
    WidgetTester tester, [
    String row = 'Subir imágenes',
  ]) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    // El anuncio de las fotos añadidas sale tras el foco (CA-016-21).
    await tester.pump(UnaMotion.announceAfterFocus);
  }

  AttachmentImportState importState(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TaskEditorScreen)))
          .read(attachmentImportProvider);

  /// Tarea guardada con un grupo de [n] fotos ya en el almacén.
  Future<Task> taskWithGroup({int n = 3, String text = 'Horario'}) async {
    final at = DateTime.utc(2026, 9, 20);
    final photos = [
      for (var i = 0; i < n; i++)
        await store.commit(
          stageImage(store, 'g$i', origin: AttachmentOrigin.gallery),
          at,
        ),
    ];
    final base = sampleTask(text: text, colorKey: 3, rank: 'M');
    final task = base.withContent(
      text,
      null,
      base.updatedAt,
      attachments: photos,
    );
    await repo.insert(task);
    return task;
  }

  group('CA-016-01: la hoja', () {
    testWidgets('"Subir imágenes" con su subtítulo, en español y en inglés', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(find.text('Subir imágenes'), findsOneWidget);
      expect(find.text('Una o varias · van arriba del todo'), findsOneWidget);
    });

    testWidgets('en inglés', (tester) async {
      await pumpEditor(tester, locale: const Locale('en'));
      await tester.tap(find.bySemanticsLabel('Add a photo, image or file'));
      await tester.pumpAndSettle();
      expect(find.text('Upload images'), findsOneWidget);
      expect(find.text('One or more · go on top'), findsOneWidget);
    });
  });

  group('CA-016-02 y 06: un grupo en el editor', () {
    testWidgets('CA-016-06: 3 fotos → pila, etiqueta "3 fotos", un solo nodo '
        'y "Quitar adjunto"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEditor(tester);
      await pick(tester);

      expect(importState(tester).staged, hasLength(3));
      expect(_stack, findsOneWidget);
      expect(find.text('3 fotos'), findsOneWidget);
      expect(
        tester.getSemantics(_stack).getSemanticsData().label,
        'Vista previa: 3 fotos',
      );
      expect(find.bySemanticsLabel('Vista previa: 3 fotos'), findsOneWidget);
      // Las tres tarjetas, con la primera arriba.
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(PhotoStack.cardKey(i)), findsOneWidget);
      }
      final removeSize = tester.getSize(_remove);
      expect(removeSize.width, greaterThanOrEqualTo(48));
      expect(removeSize.height, greaterThanOrEqualTo(48));
      expect(find.text('Añade un texto (opcional)'), findsOneWidget);
      // El teclado no se abre solo.
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      semantics.dispose();
    });

    testWidgets('CA-016-21: al volver, "3 fotos añadidas" y foco en la '
        'pila', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      expect(announcements, ['3 fotos añadidas']);
      expect(Focus.of(tester.element(_stack)).hasFocus, isTrue);
    });

    testWidgets('CA-016-02: más de 10 → se usan las 10 primeras en su orden', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.manyTotal = 12;
      await pick(tester);
      expect(importer.pickManyMax, [10]);
      final staged = importState(tester).staged;
      expect(staged, hasLength(10));
      expect(staged.map((s) => s.id), importer.copiedIds);
      expect(find.text('10 fotos'), findsOneWidget);
    });

    testWidgets('CA-016-03: una sola imagen = la 007 (sin pila ni etiqueta)', (
      tester,
    ) async {
      await pumpEditor(tester);
      importer.manyTotal = 1;
      await pick(tester);

      expect(_stack, findsNothing);
      expect(find.text('1 foto'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AttachmentPreview),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(announcements, ['Imagen añadida']);
    });

    testWidgets('CA-016-05: fallan 2 de 3 → queda una (la 007) y "1 foto '
        'añadida"', (tester) async {
      await pumpEditor(tester);
      importer.copyErrorsByToken
        ..['content://many-0'] = const ImageImportFailure(
          ImageImportError.unsupportedType,
        )
        ..['content://many-2'] = const ImageImportFailure(
          ImageImportError.unreadable,
        );
      await pick(tester);

      expect(importState(tester).staged, hasLength(1));
      expect(_stack, findsNothing);
      expect(announcements, ['1 foto añadida. No se pudieron añadir 2 fotos.']);
    });

    testWidgets('CA-016-05: fallan todas → el editor como estaba y el error '
        'de la primera', (tester) async {
      await pumpEditor(tester);
      importer.copyError = const ImageImportFailure(
        ImageImportError.unsupportedType,
      );
      await pick(tester);

      expect(_stack, findsNothing);
      expect(find.byType(AttachmentPreview), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(importState(tester).staged, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CA-016-06: "Quitar adjunto" quita el grupo entero, foco en '
        '(+) y "Adjunto quitado"', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      announcements.clear();
      await tester.tap(_remove);
      await tester.pumpAndSettle();

      expect(_stack, findsNothing);
      expect(await store.stagingIds(), isEmpty);
      expect(announcements, ['Adjunto quitado']);
      expect(
        tester
            .widget<BrutalButton>(
              find.byWidgetPredicate(
                (w) => w is BrutalButton && w.label == _plusLabel,
              ),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('CA-016-06: (+) con un grupo lo reemplaza entero y nunca se '
        'suman', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      final first = [for (final s in importState(tester).staged) s.id];
      importer.manyTotal = 2;
      await pick(tester);

      final now = [for (final s in importState(tester).staged) s.id];
      expect(now, hasLength(2));
      expect(now.toSet().intersection(first.toSet()), isEmpty);
      expect(await store.stagingIds(), now.toSet());
      expect(find.text('2 fotos'), findsOneWidget);
    });

    testWidgets('CA-016-06: cancelar el selector conserva el grupo', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester);
      final before = importState(tester).staged;
      importer.userCancelsPicker = true;
      await pick(tester);
      expect(importState(tester).staged, before);
      expect(_stack, findsOneWidget);
    });
  });

  group('CA-016-07: guardar el grupo', () {
    testWidgets('"Guardar" (primera tarea): una tarea con las 3 fotos en su '
        'orden y nada en la preparación', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      final ids = [for (final s in importState(tester).staged) s.id];
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.text, isNull);
      expect(saved.attachments.map((a) => a.id), ids);
      expect(await store.storedIds(), ids.toSet());
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-8: "Continuar" dos veces crea una sola tarea, arriba '
        'y sin preguntar', (tester) async {
      await repo.insert(sampleTask(text: 'Otra', rank: 'M'));
      await pumpEditor(tester, mode: EditorMode.create);
      await pick(tester);
      await tester.tap(find.text('Continuar'));
      await tester.tap(find.text('Continuar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final tasks = await repo.pendingTasks();
      expect(tasks, hasLength(2));
      expect(tasks.first.attachments, hasLength(3));
      expect(find.text('¿Dónde la pones?'), findsNothing);
      expect(await store.storedIds(), hasLength(3));
    });

    testWidgets('fallo al guardar: aviso con Reintentar y el editor conserva '
        'el grupo', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      final ids = [for (final s in importState(tester).staged) s.id];
      repo.error = StateError('disk I/O error');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      expect(_stack, findsOneWidget);
      expect(importState(tester).staged.map((s) => s.id), ids);
      expect(await store.stagingIds(), ids.toSet());
      expect(await store.storedIds(), isEmpty);

      // Reintentar con el disco ya bien guarda el mismo grupo.
      repo.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect((await repo.currentTask())!.attachments.map((a) => a.id), ids);
    });

    testWidgets('sin espacio al guardar: el aviso de siempre y el grupo '
        'sigue en el editor', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      repo.error = StateError('No space left on device');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Tu teléfono no tiene espacio libre'), findsOneWidget);
      expect(importState(tester).staged, hasLength(3));
      expect(await store.stagingIds(), hasLength(3));
    });

    testWidgets('CL-016-6b: el sistema vació una preparación → no guarda, '
        'quita la perdida y avisa', (tester) async {
      await pumpEditor(tester);
      await pick(tester);
      final ids = [for (final s in importState(tester).staged) s.id];
      await store.deleteStaging(ids[1]);
      announcements.clear();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(await repo.currentTask(), isNull);
      expect(importState(tester).staged.map((s) => s.id), [ids[0], ids[2]]);
      expect(find.text('2 fotos'), findsOneWidget);
      expect(announcements, ['No se pudo añadir 1 foto.']);
      expect(find.text('Reintentar'), findsNothing);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await repo.currentTask())!.attachments.map((a) => a.id), [
        ids[0],
        ids[2],
      ]);
    });

    testWidgets('CL-016-6b: se pierden todas → el editor sin imagen', (
      tester,
    ) async {
      await pumpEditor(tester);
      await pick(tester);
      for (final s in importState(tester).staged) {
        await store.deleteStaging(s.id);
      }
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(await repo.currentTask(), isNull);
      expect(_stack, findsNothing);
      expect(find.byType(AttachmentPreview), findsNothing);
      expect(importState(tester).staged, isEmpty);
    });
  });

  group('CA-016-06 y 07: editar una tarea con grupo', () {
    testWidgets('se ve la pila con las fotos guardadas y "Guardar cambios"', (
      tester,
    ) async {
      final task = await taskWithGroup();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);

      expect(_stack, findsOneWidget);
      expect(find.text('3 fotos'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
    });

    testWidgets('CL-016-13: cambiar solo el texto no toca ningún archivo', (
      tester,
    ) async {
      final task = await taskWithGroup();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await tester.enterText(find.byType(TextField), 'Menú');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.text, 'Menú');
      expect(saved.attachments, task.attachments);
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
      expect(importer.copiedIds, isEmpty);
    });

    testWidgets('quitar el grupo y guardar: sin fotos, posición y color '
        'iguales, sus archivos fuera', (tester) async {
      final task = await taskWithGroup();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      expect(_stack, findsNothing);
      // Aún no se guardó nada.
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachments, isEmpty);
      expect(saved.text, 'Horario');
      expect(saved.rank, task.rank);
      expect(saved.colorKey, task.colorKey);
      expect(await store.storedIds(), isEmpty);
    });

    testWidgets('sustituir el grupo por otro conserva posición y color y '
        'borra el anterior al guardar', (tester) async {
      final task = await taskWithGroup();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      importer.manyTotal = 2;
      await pick(tester);
      // Hasta guardar, los dos conviven.
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
      final ids = [for (final s in importState(tester).staged) s.id];
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachments.map((a) => a.id), ids);
      expect(saved.rank, task.rank);
      expect(saved.colorKey, task.colorKey);
      expect(await store.storedIds(), ids.toSet());
    });

    testWidgets('"Cancelar" tras quitar el grupo lo recupera', (tester) async {
      final task = await taskWithGroup();
      await pumpWithApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    TaskEditorScreen(mode: EditorMode.edit, task: task),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
        repo: repo,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          imageImporterProvider.overrideWithValue(importer),
        ],
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(_remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsNothing);
      expect((await repo.currentTask())!.attachments, task.attachments);
      expect(await store.storedIds(), {'g0', 'g1', 'g2'});
    });

    testWidgets('el grupo nuevo, sin espacio para sumar el guardado: '
        'CA-016-04', (tester) async {
      final task = await taskWithGroup();
      await pumpEditor(tester, mode: EditorMode.edit, task: task);
      // Cabe el grupo nuevo, pero no sumando el guardado.
      importer.freeSpaceBytes =
          ImageLimits.maxBytes + 10 * ImageLimits.storedPhotoEstimate;
      await pick(tester);

      expect(importState(tester).staged, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(_stack, findsOneWidget);
      expect(await store.stagingIds(), isEmpty);
    });
  });

  group('CA-016-04: "Preparando foto {i} de {n}…"', () {
    testWidgets('aparece a los 400 ms, avanza por foto y se anuncia una '
        'vez', (tester) async {
      await pumpEditor(tester);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.textContaining('Preparando'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Preparando foto 1 de 3…'), findsOneWidget);
      expect(find.widgetWithText(UnaLinkButton, 'Cancelar'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparando foto 2 de 3…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparando foto 3 de 3…'), findsOneWidget);
      expect(announcements, ['Preparando foto 1 de 3…']);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump(UnaMotion.announceAfterFocus);
      expect(find.text('3 fotos'), findsOneWidget);
      expect(announcements, ['Preparando foto 1 de 3…', '3 fotos añadidas']);
    });

    testWidgets('"+" y "Continuar" no hacen nada y se anuncian como no '
        'disponibles', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEditor(tester, mode: EditorMode.create);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Preparando foto 1 de 3…'), findsOneWidget);

      void expectUnavailable(String label) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse, reason: label);
        expect(data.hasAction(SemanticsAction.tap), isFalse, reason: label);
      }

      // La hoja termina de irse del árbol del lector.
      await tester.pump(const Duration(milliseconds: 400));
      expectUnavailable(_plusLabel);
      expectUnavailable('Continuar');
      // Sin verse desactivados (DEV-17).
      for (final b in tester.widgetList<BrutalButton>(
        find.byType(BrutalButton),
      )) {
        expect(b.onPressed, isNotNull);
      }
      await tester.tap(_plus, warnIfMissed: false);
      await tester.pump();
      expect(find.text('Subir imágenes'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Texto');
      await tester.tap(find.text('Continuar'), warnIfMissed: false);
      await tester.pump();
      expect(await repo.currentTask(), isNull);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      // Terminada, vuelven a estar disponibles.
      final data = tester.getSemantics(_plus).getSemanticsData();
      expect(data.flagsCollection.isEnabled, isNot(Tristate.isFalse));
      semantics.dispose();
    });

    testWidgets('"Cancelar" descarta todo el grupo y deja el editor como '
        'estaba', (tester) async {
      await pumpEditor(tester);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparando foto 2 de 3…'), findsOneWidget);
      await tester.tap(find.widgetWithText(UnaLinkButton, 'Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Preparando'), findsNothing);
      expect(find.byType(AttachmentPreview), findsNothing);
      expect(await store.stagingIds(), isEmpty);
      expect(importState(tester).staged, isEmpty);
    });

    testWidgets('CA-016-22: con reducir movimiento, sin barra animada', (
      tester,
    ) async {
      await pumpEditor(tester, reduced: true);
      importer.sanitizeDelay = const Duration(seconds: 2);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imágenes'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Preparando foto 1 de 3…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('CA-016-22: texto grande, movimiento y tamaño de toque', () {
    testWidgets('al 200 % a 360 dp: nada se corta y los botones miden ≥ 48', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        mode: EditorMode.edit,
        task: await taskWithGroup(),
        textScale: 2.0,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      final screen = tester.getRect(find.byType(TaskEditorScreen));
      expect(
        screen.contains(tester.getRect(find.text('3 fotos')).center),
        isTrue,
      );
      expect(
        tester.getRect(find.text('Guardar cambios')).bottom,
        lessThanOrEqualTo(screen.bottom),
      );
      expect(tester.getSize(_remove).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSize(
              find.byWidgetPredicate(
                (w) => w is BrutalButton && w.label == _plusLabel,
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('con reducir movimiento la pila está fija', (tester) async {
      await pumpEditor(tester, reduced: true);
      await pick(tester);
      Matrix4 card(int i) =>
          tester.widget<Transform>(find.byKey(PhotoStack.cardKey(i))).transform;
      final before = [for (var i = 0; i < 3; i++) card(i).clone()];
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        expect(card(i), before[i]);
      }
      expect(
        math.atan2(card(0).storage[1], card(0).storage[0]).abs(),
        greaterThan(0),
      );
    });

    for (final preparing in [false, true]) {
      testWidgets(
        'guías de tamaño de toque y de etiquetas (${preparing ? 'con '
                  '"Preparando"' : 'con grupo'})',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpEditor(tester);
          if (preparing) {
            importer.sanitizeDelay = const Duration(seconds: 2);
            await tester.tap(_plus);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Subir imágenes'));
            await tester.pump(const Duration(milliseconds: 500));
          } else {
            await pick(tester);
          }
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (preparing) {
            await tester.pump(const Duration(seconds: 6));
            await tester.pumpAndSettle();
          }
          semantics.dispose();
        },
      );
    }
  });

  testWidgets('CL-016-21: al cambiar el idioma con la pila visible, el grupo '
      'se mantiene', (tester) async {
    await pumpUnaApp(
      tester,
      repo: repo,
      tasks: ['Primera', 'Segunda'],
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    await pick(tester);
    final ids = [for (final s in importState(tester).staged) s.id];
    expect(find.text('3 fotos'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    await tester.pumpAndSettle();

    expect(find.text('3 photos'), findsOneWidget);
    expect(find.bySemanticsLabel('Preview: 3 photos'), findsOneWidget);
    expect(importState(tester).staged.map((s) => s.id), ids);
    expect(await store.stagingIds(), ids.toSet());
  });
}
