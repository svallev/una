import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/attach_sheet.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/editor/placement_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sheet_row.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
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

/// Falla al actualizar mientras [fail] esté activo (spec 005 §5).
class _FailingUpdate extends InMemoryTaskRepository {
  bool fail = true;

  @override
  Future<bool> updateContent(
    String id,
    String? text,
    Attachment? attachment,
    DateTime at,
  ) async {
    if (fail) throw StateError('disk I/O error');
    return super.updateContent(id, text, attachment, at);
  }
}

const _oldUrl = 'https://congreso.ejemplo.com/programa';

/// Tarea web ya guardada, con el color 3 y la clave de orden [rank].
Task _webTask({String rank = 'MA'}) {
  final at = DateTime.utc(2026, 9, 28, 9);
  return Task(
    id: 'w',
    text: null,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(const StagedWeb(id: 'a-w', url: _oldUrl), at),
  );
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
      // La tarea web actual, con WebViews falsas (T-009-11).
      ...FakeWebPages().overrides,
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

  group('CA-009-05: editar una tarea web', () {
    Finder urlField() => find.descendant(
      of: find.byType(UrlSheet),
      matching: find.byType(TextField),
    );

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(urlField()).controller!.text;

    bool fieldFocused(WidgetTester tester) =>
        tester.widget<TextField>(urlField()).focusNode!.hasFocus;

    /// La app con la tarea web como actual y [others] detrás.
    Future<InMemoryTaskRepository> pumpWebCurrent(
      WidgetTester tester, {
      InMemoryTaskRepository? repo,
      List<String> others = const ['Segunda'],
    }) async {
      final r = repo ?? InMemoryTaskRepository();
      await r.insert(_webTask());
      await pumpUnaApp(tester, repo: r, tasks: others, overrides: overrides);
      await tester.pumpAndSettle();
      return r;
    }

    Future<void> editFromMenu(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
    }

    /// El listado con la web en la posición 2 de 3.
    Future<InMemoryTaskRepository> openListWithWeb(
      WidgetTester tester, {
      InMemoryTaskRepository? repo,
      bool screenReader = false,
    }) async {
      final r = repo ?? InMemoryTaskRepository();
      // Entre "Primera" (MB) y "Tercera" (MC).
      await r.insert(_webTask(rank: 'MBM'));
      await openList(
        tester,
        repo: r,
        tasks: ['Primera', 'Tercera'],
        screenReader: screenReader,
        overrides: overrides,
      );
      return r;
    }

    Finder webRow() =>
        find.byWidgetPredicate((w) => w is TaskListRow && w.task.id == 'w');

    Future<void> editFromList(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: webRow(),
          matching: find.byWidgetPredicate(
            (w) => w is UnaIcon && w.icon == UnaIcons.edit,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String text) async {
      await tester.enterText(urlField(), text);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    /// El foco se pide cuando la hoja ya se ha cerrado.
    Future<void> settleFocus(WidgetTester tester) async {
      await tester.pump(UnaMotion.sheetOut);
      await tester.pumpAndSettle();
    }

    String? focusedRowId() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<TaskListRow>()
        ?.task
        .id;

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

    testWidgets('desde el menú abre la hoja "Cargar URL" (no el editor) con la '
        'dirección actual en el campo y el foco en él', (tester) async {
      await pumpWebCurrent(tester);
      await editFromMenu(tester);

      expect(find.byType(UrlSheet), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(fieldText(tester), _oldUrl);
      expect(fieldFocused(tester), isTrue);
      // El cursor, al final (como en el editor, CA-005-04).
      expect(
        tester.widget<TextField>(urlField()).controller!.selection,
        const TextSelection.collapsed(offset: _oldUrl.length),
      );
    });

    testWidgets('desde el menú, "Abrir" con otra dirección la sustituye: '
        'sigue siendo la tarea actual, con su color, sin editor ni anuncios '
        'y con el foco de vuelta en la tarea', (tester) async {
      final repo = await pumpWebCurrent(tester);
      await editFromMenu(tester);
      final before = container(tester).read(screenFocusProvider);
      final announcements = listenAnnouncements(tester);
      await submit(tester, '  festival.ejemplo.org/agenda ');

      expect(find.byType(UrlSheet), findsNothing);
      expect(find.byType(TaskEditorScreen), findsNothing);
      final tasks = await repo.pendingTasks();
      expect(tasks, hasLength(2));
      final web = tasks.first;
      expect(web.id, 'w');
      expect(web.colorKey, 3);
      expectWeb(web, 'https://festival.ejemplo.org/agenda');
      expect(tasks.last.text, 'Segunda');
      // La pantalla principal ya tiene la dirección nueva.
      expect(
        container(tester).read(currentTaskProvider)?.attachment?.url,
        'https://festival.ejemplo.org/agenda',
      );
      // Como al guardar el editor (spec 005 §5b): el foco vuelve a la tarea.
      expect(container(tester).read(screenFocusProvider), greaterThan(before));
      expect(announcements, isEmpty);
    });

    testWidgets('con la misma dirección no cambia nada', (tester) async {
      final repo = await pumpWebCurrent(tester);
      final original = (await repo.findById('w'))!;
      await editFromMenu(tester);
      // Normalizada, es la misma que ya tenía.
      await submit(tester, 'congreso.ejemplo.com/programa');

      expect(find.byType(UrlSheet), findsNothing);
      final after = (await repo.findById('w'))!;
      expect(after.updatedAt, original.updatedAt);
      expect(after.attachment!.id, original.attachment!.id);
      expect(after.attachment!.url, _oldUrl);
    });

    testWidgets('la validación es la de CA-009-02: el error se queda en la '
        'hoja y la tarea no cambia', (tester) async {
      final repo = await pumpWebCurrent(tester);
      await editFromMenu(tester);
      final announcements = listenAnnouncements(tester);
      await submit(tester, 'javascript:alert(1)');

      expect(find.byType(UrlSheet), findsOneWidget);
      expect(
        find.text('Solo se admiten direcciones web (http o https).'),
        findsOneWidget,
      );
      expect(fieldFocused(tester), isTrue);
      expect(fieldText(tester), 'javascript:alert(1)');
      expect(announcements, [
        'Solo se admiten direcciones web (http o https).',
      ]);

      await submit(tester, '');
      expect(find.text('Escribe una dirección web.'), findsOneWidget);
      expect((await repo.findById('w'))!.attachment!.url, _oldUrl);
    });

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
      testWidgets('cerrar la hoja $how desde el menú la deja como estaba, '
          'sin anuncios', (tester) async {
        final repo = await pumpWebCurrent(tester);
        final original = (await repo.findById('w'))!;
        await editFromMenu(tester);
        await tester.enterText(urlField(), 'otra.ejemplo.org');
        final announcements = listenAnnouncements(tester);
        await close(tester);
        await tester.pumpAndSettle();

        expect(find.byType(UrlSheet), findsNothing);
        expect(find.byType(TaskEditorScreen), findsNothing);
        final after = (await repo.findById('w'))!;
        expect(after.updatedAt, original.updatedAt);
        expect(after.attachment!.url, _oldUrl);
        expect(announcements, isEmpty);
      });
    }

    testWidgets('desde el listado abre la hoja con la dirección; "Abrir" la '
        'sustituye conservando la posición y el color, y el foco vuelve a la '
        'fila sin anuncios (CA-006-13)', (tester) async {
      final repo = await openListWithWeb(tester);
      await editFromList(tester);

      expect(find.byType(UrlSheet), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(fieldText(tester), _oldUrl);
      expect(fieldFocused(tester), isTrue);

      final announcements = listenAnnouncements(tester);
      await submit(tester, 'https://festival.ejemplo.org/agenda');
      await settleFocus(tester);

      expect(find.byType(TaskListScreen), findsOneWidget);
      final tasks = await repo.pendingTasks();
      expect([for (final t in tasks) t.id], ['t0', 'w', 't1']);
      expect(tasks[1].colorKey, 3);
      expectWeb(tasks[1], 'https://festival.ejemplo.org/agenda');
      expect(focusedRowId(), 'w');
      expect(announcements, isEmpty);
    });

    testWidgets('desde el listado, cerrar la hoja la deja como estaba y el '
        'foco vuelve a la fila', (tester) async {
      final repo = await openListWithWeb(tester);
      final original = (await repo.findById('w'))!;
      await editFromList(tester);
      expect(find.byType(UrlSheet), findsOneWidget);
      final announcements = listenAnnouncements(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await settleFocus(tester);

      expect(find.byType(UrlSheet), findsNothing);
      expect(find.byType(TaskListScreen), findsOneWidget);
      final after = (await repo.findById('w'))!;
      expect(after.updatedAt, original.updatedAt);
      expect(after.attachment!.url, _oldUrl);
      expect(focusedRowId(), 'w');
      expect(announcements, isEmpty);
    });

    testWidgets('desde el listado con el lector ("Editar tarea" de la fila) '
        'también abre la hoja', (tester) async {
      final handle = tester.ensureSemantics();
      await openListWithWeb(tester, screenReader: true);
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^2 de 3: ')),
      );
      final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
        (id) => CustomSemanticsAction.getAction(id)!.label == 'Editar tarea',
      );
      node.owner!.performAction(node.id, SemanticsAction.customAction, id);
      await tester.pumpAndSettle();

      expect(find.byType(UrlSheet), findsOneWidget);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(fieldText(tester), _oldUrl);
      handle.dispose();
    });

    testWidgets('si no se puede guardar, avisa y "Reintentar" guarda la '
        'dirección nueva', (tester) async {
      final repo = _FailingUpdate();
      await pumpWebCurrent(tester, repo: repo);
      await editFromMenu(tester);
      await submit(tester, 'festival.ejemplo.org');

      expect(find.text('No hemos podido guardar la tarea'), findsOneWidget);
      expect((await repo.findById('w'))!.attachment!.url, _oldUrl);

      repo.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      final web = (await repo.findById('w'))!;
      expectWeb(web, 'https://festival.ejemplo.org');
      expect(web.colorKey, 3);
      expect((await repo.currentTask())!.id, 'w');
    });

    testWidgets('una tarea que no es web sigue abriendo el editor', (
      tester,
    ) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera'],
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await editFromMenu(tester);
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(find.byType(UrlSheet), findsNothing);
    });
  });
}
