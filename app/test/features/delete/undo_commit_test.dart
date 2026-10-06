import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart' show attachmentFrom;
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/undo.dart';

/// Lo que hace definitiva una eliminación desde la pantalla principal
/// (CA-014-11) y lo que no (CA-014-12): cada causa quita la card **antes** de
/// cambiar la cola y de abrir la otra pantalla, y nada se puede recuperar
/// después. Las causas de navegación y de segundo plano ya se prueban con la
/// app entera en `undo_controller_test.dart`; aquí, con una eliminación real
/// y los controles reales.
const _frame = Duration(milliseconds: 16);

final _card = find.byType(UndoCard);
final _menuButton = find.bySemanticsLabel('Menú de la tarea');

late MemoryAttachmentStore _store;
late FakeWebPages _web;

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

UndoPhase _phase(WidgetTester tester) =>
    _container(tester).read(undoProvider).phase;

/// No puede volver a insertar (CA-014-23).
class _FailingInsertRepo extends InMemoryTaskRepository {
  bool failInsert = false;

  @override
  Future<void> insert(Task task) async {
    if (failInsert) throw StateError('disk I/O error: ${task.text}');
    return super.insert(task);
  }
}

Future<InMemoryTaskRepository> _pump(
  WidgetTester tester, {
  List<String> tasks = const ['Primera', 'Segunda', 'Tercera'],
  List<Task> extra = const [],
  InMemoryTaskRepository? repo0,
}) async {
  final repo = repo0 ?? InMemoryTaskRepository();
  for (final t in extra) {
    await repo.insert(t);
  }
  await pumpUnaApp(
    tester,
    repo: repo,
    tasks: tasks,
    clock: TesterClock(tester),
    overrides: [
      accessibilityTimeoutsProvider.overrideWithValue(
        FakeAccessibilityTimeouts(),
      ),
      attachmentStoreProvider.overrideWithValue(_store),
      ..._web.overrides,
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Menú → Eliminar y el arrugado entero: queda la card.
Future<void> _deleteFromMenu(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pump(_frame);
  await tester.pump(UnaMotion.crumple);
  await tester.pump(_frame);
  await tester.pump(_frame);
  await tester.pump(const Duration(milliseconds: 300));
  expect(_card, findsOneWidget);
  expect(_phase(tester), UndoPhase.visible);
}

/// Con la card a la vista, `pumpAndSettle` no se asienta (la barra repinta en
/// cada fotograma) y avanzaría el reloj hasta que caduque.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Abre el menú con la card a la vista y elige [entry].
Future<void> _menu(WidgetTester tester, String entry) async {
  await tester.tap(_menuButton);
  await _settle(tester);
  await tester.tap(find.text(entry));
  await _settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    _store = MemoryAttachmentStore();
    _web = FakeWebPages();
  });

  testWidgets('CA-014-11, CA-014-07: "Todas mis tareas" la hace definitiva '
      'antes de abrir el listado y no se puede recuperar al volver', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _deleteFromMenu(tester);
    await _menu(tester, 'Todas mis tareas');
    expect(_phase(tester), UndoPhase.none);
    expect(_card, findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    expect(await repo.findById('t0'), isNull);
  });

  testWidgets('CA-014-11: abrir el editor para crear, aunque luego se '
      'cancele, la hace definitiva', (tester) async {
    await _pump(tester);
    await _deleteFromMenu(tester);
    await _menu(tester, 'Nueva tarea');
    expect(_phase(tester), UndoPhase.none);
    expect(_card, findsNothing);
  });

  testWidgets('CA-014-11: abrir el editor para editar, aunque luego se '
      'cancele, la hace definitiva', (tester) async {
    await _pump(tester);
    await _deleteFromMenu(tester);
    await _menu(tester, 'Editar');
    expect(_phase(tester), UndoPhase.none);
    expect(_card, findsNothing);
  });

  testWidgets('CA-014-11, CL-014-13, CA-015-24: "Ajustes" la hace '
      'definitiva', (tester) async {
    await _pump(tester);
    await _deleteFromMenu(tester);
    await _menu(tester, 'Ajustes');
    expect(_phase(tester), UndoPhase.none);
    expect(_card, findsNothing);
  });

  testWidgets('CA-014-11, CA-015-24, DEV-51: con el aviso de error de la '
      'recuperación a la vista, "Ajustes" lo quita y lo hace definitivo', (
    tester,
  ) async {
    final repo = _FailingInsertRepo();
    await _pump(tester, repo0: repo);
    await _deleteFromMenu(tester);
    repo.failInsert = true;
    // Pasada la guarda de 350 ms del botón (CL-014-2).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.descendant(of: _card, matching: find.byKey(UndoCard.buttonKey)),
    );
    await tester.pump(_frame);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_phase(tester), UndoPhase.failed);
    expect(find.text('No hemos podido recuperar la tarea'), findsOneWidget);

    await _menu(tester, 'Ajustes');
    expect(_phase(tester), UndoPhase.none);
    expect(find.text('No hemos podido recuperar la tarea'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(await repo.findById('t0'), isNull);
  });

  testWidgets('CA-014-12: abrir y cerrar el menú sin elegir nada no la hace '
      'definitiva', (tester) async {
    await _pump(tester);
    await _deleteFromMenu(tester);
    await tester.tap(_menuButton);
    await _settle(tester);
    expect(_phase(tester), UndoPhase.visible);
    await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
    await _settle(tester);
    expect(_phase(tester), UndoPhase.visible);
    expect(_card, findsOneWidget);
  });

  testWidgets('CA-014-11: completar con la acción del lector la hace '
      'definitiva antes de cambiar la cola', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = await _pump(tester);
    await _deleteFromMenu(tester);
    // Con la card, el botón no se ve: solo se completa con la acción.
    expect(find.bySemanticsLabel('Pulsa para completar'), findsNothing);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Tarea actual: Segunda'),
    );
    final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == 'Completar tarea',
    );
    node.owner!.performAction(node.id, SemanticsAction.customAction, id);
    expect(_phase(tester), UndoPhase.none);
    await tester.pump();
    expect(_card, findsNothing);
    await tester.pumpAndSettle();
    expect(await repo.findById('t1'), isNull);
    handle.dispose();
  });

  testWidgets('CA-014-11: "Quitar adjunto" en "Adjunto no disponible" la hace '
      'definitiva', (tester) async {
    final attachment = await _store.commit(
      stageImage(_store, 'a1'),
      DateTime.utc(2026, 9, 20),
    );
    final base = sampleTask(id: 'img', text: 'Horario', rank: 'MZ');
    final missing = base.withContent(base.text, attachment, base.updatedAt);
    _store.removeFile('a1', 'full-0-0.jpg');
    await _pump(tester, tasks: ['Primera'], extra: [missing]);
    await _deleteFromMenu(tester);
    // Ahora se ve la tarea sin la imagen, con la card encima.
    expect(find.text('Adjunto no disponible'), findsOneWidget);
    await tester.tap(find.text('Quitar adjunto'));
    await tester.pump();
    expect(_phase(tester), UndoPhase.none);
    await _settle(tester);
    expect(_card, findsNothing);
  });

  group('CA-014-11, CA-014-12: "Cargar URL"', () {
    const address = 'https://www.congreso.ejemplo.com/programa';

    Future<Task> webTask() async {
      final at = DateTime.utc(2026, 9, 29, 9);
      return Task(
        id: 'web',
        text: null,
        status: TaskStatus.pending,
        rank: 'MZ',
        colorKey: 3,
        createdAt: at,
        updatedAt: at,
        attachment: attachmentFrom(StagedWeb(id: 'w1', url: address), at),
      );
    }

    testWidgets('abrir la hoja y cerrarla sin guardar no la hace '
        'definitiva; guardar, sí', (tester) async {
      await _pump(tester, tasks: ['Primera'], extra: [await webTask()]);
      await _deleteFromMenu(tester);
      expect(_web.drivers, isNotEmpty);

      // Abrir y cerrar sin guardar.
      await _menu(tester, 'Editar');
      expect(find.text('CARGAR URL'), findsOneWidget);
      expect(_phase(tester), UndoPhase.visible);
      await tester.tapAt(const Offset(20, 60)); // Fuera de la hoja.
      await _settle(tester);
      expect(find.text('CARGAR URL'), findsNothing);
      expect(_phase(tester), UndoPhase.visible);
      expect(_card, findsOneWidget);

      // Guardar otra dirección.
      await _menu(tester, 'Editar');
      await tester.enterText(
        find.byType(TextField),
        'https://www.otra.ejemplo.com/',
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      expect(_phase(tester), UndoPhase.none);
      await _settle(tester);
      expect(_card, findsNothing);
    });
  });
}
