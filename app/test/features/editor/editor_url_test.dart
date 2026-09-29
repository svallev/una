import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/attach_sheet.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sheet_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/pump_app.dart';
import '../task_list/list_harness.dart';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

/// Falla al insertar mientras [fail] esté activo (spec 001 §5).
class _FailingInsert extends InMemoryTaskRepository {
  bool fail = true;

  @override
  Future<void> insert(Task task) async {
    if (fail) throw StateError('disk I/O error');
    return super.insert(task);
  }
}

void main() {
  late MemoryAttachmentStore store;
  late FakeImageImporter images;
  late FakePdfImporter pdfs;
  late List<Override> overrides;

  setUp(() {
    store = MemoryAttachmentStore();
    images = FakeImageImporter(store);
    pdfs = FakePdfImporter(store);
    overrides = [
      attachmentStoreProvider.overrideWithValue(store),
      imageImporterProvider.overrideWithValue(images),
      pdfImporterProvider.overrideWithValue(pdfs),
      ...fakePdfViews,
    ];
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    InMemoryTaskRepository repo, {
    EditorMode mode = EditorMode.first,
  }) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(mode: mode),
      repo: repo,
      overrides: overrides,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openUrlSheet(WidgetTester tester) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar URL'));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsOneWidget);
  }

  Future<void> loadUrl(WidgetTester tester, String text) async {
    await openUrlSheet(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(UrlSheet),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> openNewTask(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva tarea'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorScreen), findsOneWidget);
  }

  Future<void> addPdf(WidgetTester tester) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir archivo'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPreview), findsOneWidget);
  }

  bool plusFocused(WidgetTester tester) => tester
      .widget<BrutalButton>(
        find.byWidgetPredicate(
          (w) =>
              w is BrutalButton && w.label == 'Añadir foto, imagen o archivo',
        ),
      )
      .focusNode!
      .hasFocus;

  void expectWeb(Task task, String url) {
    expect(task.text, isNull);
    expect(task.attachment!.kind, AttachmentKind.web);
    expect(task.attachment!.origin, AttachmentOrigin.url);
    expect(task.attachment!.url, url);
  }

  group('CA-009-03: "Abrir" crea la tarea web directamente', () {
    testWidgets('primera tarea: sin texto, con la dirección normalizada, y '
        'descarta lo escrito', (tester) async {
      final repo = InMemoryTaskRepository();
      await pumpEditor(tester, repo);
      await tester.enterText(find.byType(TextField), 'Texto que se descarta');
      await loadUrl(tester, 'congreso.ejemplo.com/programa');

      final tasks = await repo.pendingTasks();
      expect(tasks, hasLength(1));
      expectWeb(tasks.single, 'https://congreso.ejemplo.com/programa');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskEditorScreen)),
      );
      // Sin pendientes, ya no vuelve el editor de la primera (ADR-0012).
      expect(container.read(hasEverHadTasksProvider), isTrue);
    });

    testWidgets('desde la pantalla principal, con un PDF elegido y texto: va '
        'arriba sin preguntar, descarta el PDF sin dejar archivos y vuelve a '
        'la tarea sin anuncios', (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
        overrides: overrides,
      );
      await openNewTask(tester);
      await addPdf(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(TaskEditorScreen),
          matching: find.byType(TextField),
        ),
        'Programa',
      );
      expect(await store.stagingIds(), hasLength(1));
      final announcements = listenAnnouncements(tester);

      await loadUrl(tester, 'ejemplo.com');

      expect(find.byType(PlacementSheet), findsNothing);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final current = (await repo.currentTask())!;
      expectWeb(current, 'https://ejemplo.com');
      expect(await order(repo), ['', 'Primera', 'Segunda']);
      // Ni el PDF preparado ni sus archivos (CA-008-16). No se comprueba
      // `storedIds` vacío: hasta T-009-11 la pantalla principal trata la web
      // como una imagen y el importador falso le regenera una versión.
      expect(await store.stagingIds(), isEmpty);
      expect(await store.storedIds(), isNot(contains(pdfs.picks.single)));
      // CA-009-19: en la pantalla principal, "Abrir" no se anuncia.
      expect(announcements, isEmpty);
    });

    testWidgets('desde el listado: vuelve con la fila en la posición 1, '
        'resaltada, con el foco y "Ahora es la tarea actual", como imagen y '
        'PDF (CA-009-19)', (tester) async {
      final announcements = listenAnnouncements(tester);
      final repo = await openList(
        tester,
        tasks: ['Primera', 'Segunda'],
        overrides: overrides,
      );
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      await openUrlSheet(tester);
      announcements.clear();
      await tester.enterText(
        find.descendant(
          of: find.byType(UrlSheet),
          matching: find.byType(TextField),
        ),
        'ejemplo.com',
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      TaskListRow row() => tester
          .widgetList<TaskListRow>(find.byType(TaskListRow))
          .firstWhere((r) => r.task.attachment?.isWeb ?? false);
      expect(row().shadow, UnaShadows.listItemFlash);
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(find.byType(PlacementSheet), findsNothing);
      final tasks = await repo.pendingTasks();
      expectWeb(tasks.first, 'https://ejemplo.com');
      expect(shownOrder(tester), ['', 'Primera', 'Segunda']);
      // El foco se pide cuando el editor ya se ha cerrado.
      await tester.pump(UnaMotion.sheetOut);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TaskListRow>();
      expect(focused?.task.attachment?.isWeb, isTrue);
      expect(announcements, ['Ahora es la tarea actual']);
    });

    testWidgets('un doble toque rápido en "Abrir" crea una sola tarea', (
      tester,
    ) async {
      final repo = await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera'],
        overrides: overrides,
      );
      await openNewTask(tester);
      await openUrlSheet(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(UrlSheet),
          matching: find.byType(TextField),
        ),
        'ejemplo.com',
      );
      await tester.tap(find.text('Abrir'));
      await tester.tap(find.text('Abrir'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final tasks = await repo.pendingTasks();
      expect(tasks, hasLength(2));
      expectWeb(tasks.first, 'https://ejemplo.com');
      expect(find.byType(TaskEditorScreen), findsNothing);
    });

    testWidgets('si no se puede guardar, avisa y "Reintentar" crea la web', (
      tester,
    ) async {
      final repo = _FailingInsert();
      await pumpEditor(tester, repo, mode: EditorMode.create);
      await loadUrl(tester, 'ejemplo.com');

      expect(find.text('No hemos podido guardar la tarea'), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(await repo.pendingTasks(), isEmpty);

      repo.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      final tasks = await repo.pendingTasks();
      expect(tasks, hasLength(1));
      expectWeb(tasks.single, 'https://ejemplo.com');
    });
  });

  group('CA-009-02: validación desde el editor', () {
    testWidgets('una dirección no válida no crea nada y la hoja sigue', (
      tester,
    ) async {
      final repo = InMemoryTaskRepository();
      await pumpEditor(tester, repo, mode: EditorMode.create);
      await loadUrl(tester, 'localhost');

      expect(find.byType(UrlSheet), findsOneWidget);
      expect(find.text('Esa dirección no parece válida.'), findsOneWidget);
      expect(await repo.pendingTasks(), isEmpty);
    });
  });

  group('CA-009-01 / CA-009-19: cerrar "Cargar URL"', () {
    for (final (how, close) in <(String, Future<void> Function(WidgetTester))>[
      (
        'con la X',
        (tester) => tester.tap(
          find.descendant(
            of: find.byType(UrlSheet),
            matching: find.descendant(
              of: find.byType(SheetHeader),
              matching: find.byType(InkResponse),
            ),
          ),
        ),
      ),
      ('tocando fuera', (tester) => tester.tapAt(const Offset(195, 40))),
      ('con el gesto atrás', (tester) => tester.binding.handlePopRoute()),
    ]) {
      testWidgets('$how deja el editor como estaba, con el foco en (+) y sin '
          'anuncio', (tester) async {
        final repo = InMemoryTaskRepository();
        await pumpEditor(tester, repo, mode: EditorMode.create);
        await addPdf(tester);
        await tester.enterText(
          find.descendant(
            of: find.byType(TaskEditorScreen),
            matching: find.byType(TextField),
          ),
          'Programa',
        );
        await openUrlSheet(tester);
        final announcements = listenAnnouncements(tester);
        await close(tester);
        await tester.pumpAndSettle();

        expect(find.byType(UrlSheet), findsNothing);
        expect(find.byType(AttachSheet), findsNothing);
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('Programa'), findsOneWidget);
        expect(find.byType(AttachmentPreview), findsOneWidget);
        expect(await store.stagingIds(), hasLength(1));
        expect(await repo.pendingTasks(), isEmpty);
        expect(plusFocused(tester), isTrue);
        expect(announcements, isEmpty);
      });
    }
  });

  testWidgets(
    'CA-009-01: al editar una tarea que no es web no se puede convertir en web',
    (tester) async {
      final repo = InMemoryTaskRepository();
      final task = sampleTask();
      await repo.insert(task);
      await pumpWithApp(
        tester,
        TaskEditorScreen(mode: EditorMode.edit, task: task),
        repo: repo,
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(find.byType(SheetRow), findsNWidgets(3));
      expect(find.text('Cargar URL'), findsNothing);
    },
  );
}
