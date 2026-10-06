import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/attachments/zoomable_photo.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../features/task_list/list_harness.dart' show FakeClock;
import '../support/app_harness.dart';
import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_pdf_importer.dart';
import '../support/fake_pdf_view.dart';
import '../support/fake_web_page_driver.dart';
import '../support/l10n_leaks.dart'
    show expectNoL10nLeaks, findL10nLeaks, semanticsTexts;
import '../support/pdfrx.dart';
import '../support/pump_app.dart' show sampleTask;
import '../support/undo.dart' show TesterClock;

/// Cambio de idioma del sistema con la app abierta, sin adjuntos (spec 010,
/// T-010-07). La actividad no se recrea (`configChanges` con `locale`): la app
/// recibe el cambio como un nuevo `platformDispatcher.locales`.
///
/// T-010-08: el mismo cambio con adjuntos (imagen, PDF y web) y el orden de
/// las acciones del lector antes y después (CA-010-11).
///
/// Textos de tarea neutros (ni ES ni EN) para que no se confundan con la
/// interfaz.
const _tasks = ['Zxq 1', 'Zxq 2', 'Zxq 3'];

AppLocalizations _l10n(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

/// Idioma con el que se ha construido la pantalla actual.
AppLocalizations _current(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Cambia el idioma del sistema (como al volver de Ajustes) y deja asentar.
Future<void> _switchTo(WidgetTester tester, List<Locale> locales) async {
  tester.platformDispatcher.localesTestValue = locales;
  await tester.pumpAndSettle();
}

/// Textos del fondo modal de una hoja abierta, en el idioma actual de Flutter
/// (`MaterialLocalizations`): "Sombreado", "Cerrar Hoja inferior"… No salen de
/// los ARB y la ruta de la hoja los fija al abrirse, así que con una hoja
/// abierta durante el cambio de idioma se quedan en el idioma anterior hasta
/// cerrarla. Excepción aceptada por el propietario (spec 010 §6, H-010-1).
Set<String> _modalBarrierTexts(WidgetTester tester) {
  final material = MaterialLocalizations.of(
    tester.element(find.byType(Scaffold).first),
  );
  return {
    material.scrimLabel,
    material.scrimOnTapHint(material.bottomSheetLabel),
    material.modalBarrierDismissLabel,
  };
}

/// CA-010-07 tras CA-010-06: ningún texto de los ARB en el otro idioma. Con
/// una hoja abierta al cambiar, [staleBarrier] son los textos del fondo modal
/// (ver [_modalBarrierTexts], calculados **antes** del cambio) y solo esos
/// se dan por buenos.
void _expectNoLeaksAfterSwitch(
  WidgetTester tester,
  String languageCode, {
  Set<String> staleBarrier = const {},
}) {
  final found = [
    for (final leak in findL10nLeaks(tester, languageCode: languageCode))
      if (!staleBarrier.any((text) => leak.contains('"$text"'))) leak,
  ];
  expect(
    found,
    isEmpty,
    reason: 'Fugas de idioma en la app en "$languageCode" (CA-010-07)',
  );
}

/// Sale de la app, cambia el idioma del sistema mientras está fuera y vuelve
/// tras [away] (Ajustes → volver, CA-010-06 / CA-001-12).
Future<void> _leaveAndReturn(
  WidgetTester tester,
  FakeClock clock, {
  required List<Locale> locales,
  required Duration away,
}) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  tester.platformDispatcher.localesTestValue = locales;
  clock.value = clock.value.add(away);
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

const _webAddress = 'https://www.zxq.example/qz';
const _pdfName = 'Zxq.pdf';

/// Lectura de la tarea de foto con texto (CA-007-21).
String _photoLabel(AppLocalizations l10n) =>
    l10n.currentTaskSemantics(l10n.a11yWithPhoto(_tasks.first));

/// Nombre de una acción del lector en un idioma.
typedef _ActionName = String Function(AppLocalizations l10n);

/// Acciones de la tarea actual, en el orden de las specs (CA-007-21,
/// CA-008-20, CA-009-18).
final List<_ActionName> _taskActions = [
  (l) => l.completeA11yAction,
  (l) => l.deleteA11yAction,
];

/// Acciones del PDF en la página 2 con zoom ×1,5 (CA-008-20): las de la tarea,
/// luego las de página y las de zoom.
final List<_ActionName> _pdfActions = [
  ..._taskActions,
  (l) => l.pdfNextPage,
  (l) => l.pdfPrevPage,
  (l) => l.pdfZoomIn,
  (l) => l.pdfZoomOut,
  (l) => l.pdfZoomFit,
];

/// Nombres de las acciones personalizadas de [node], en el orden en que las
/// entrega Flutter al sistema (el que recorre TalkBack). Sin las pistas de
/// toque, que no tienen nombre.
List<String> _actionNames(SemanticsNode node) => [
  for (final id in node.getSemanticsData().customSemanticsActionIds ?? <int>[])
    if (CustomSemanticsAction.getAction(id)?.label case final String label)
      label,
];

/// El primer nodo del árbol semántico con la acción [name], o null.
SemanticsNode? _nodeWithAction(WidgetTester tester, String name) {
  SemanticsNode? found;
  bool visit(SemanticsNode node) {
    if (found == null && _actionNames(node).contains(name)) found = node;
    if (found == null) node.visitChildren(visit);
    return found == null;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return found;
}

/// Las acciones de la tarea actual en el orden de [expected], en el idioma de
/// [l10n], tal cual las ve el lector (CA-010-11).
void _expectTaskActions(
  WidgetTester tester,
  AppLocalizations l10n,
  List<_ActionName> expected, {
  Finder? node,
}) {
  final target = node != null
      ? tester.getSemantics(node)
      : _nodeWithAction(tester, l10n.completeA11yAction);
  expect(target, isNotNull, reason: 'la tarea no lleva "Completar" en la app');
  expect(_actionNames(target!), [for (final name in expected) name(l10n)]);
}

/// Deja pasar el reloj y el trabajo del motor de PDF, que corre fuera del
/// reloj falso de los tests.
Future<void> _settlePdf(WidgetTester tester, [int rounds = 60]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Tarea con un PDF de 20 páginas ya guardado en [store].
Future<Task> _pdfTask(MemoryAttachmentStore store) async {
  store
    ..putStaging(
      'p-pdf',
      'document.pdf',
      base64Decode(pdfFixtures['pages_20.pdf']!),
    )
    ..putStaging('p-pdf', 'screen.jpg', tinyImage);
  final attachment = await store.commit(
    const StagedPdf(
      id: 'p-pdf',
      byteSize: 2400000,
      pageCount: 20,
      width: 595,
      height: 842,
      originalName: _pdfName,
    ),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: 'pdf', text: _tasks.first, rank: 'MA');
  return base.withContent(_tasks.first, attachment, base.updatedAt);
}

/// Tarea con una imagen ya guardada en [store].
Future<Task> _imageTask(MemoryAttachmentStore store) async {
  final attachment = await store.commit(
    stageImage(store, 'img'),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: 'img', text: _tasks.first, rank: 'MA');
  return base.withContent(_tasks.first, attachment, base.updatedAt);
}

/// Tarea web (sin texto) con la dirección [_webAddress].
Task _webTask() {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: 'web',
    text: null,
    status: TaskStatus.pending,
    rank: 'MA',
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-web', url: _webAddress), at),
  );
}

/// Abre enlaces sin salir de la prueba.
class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

void main() {
  // El visor de PDF de verdad (PDFium) de las pruebas con adjuntos.
  setUpAll(initPdfrxForTests);

  group('CA-015-09: idioma elegido en Ajustes', () {
    /// Idioma con el que se ha construido la pantalla actual.
    String shown(WidgetTester tester) =>
        Localizations.localeOf(tester.element(find.byType(Scaffold).first))
            .languageCode;

    SettingsController controller(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(UnaApp)))
            .read(settingsProvider.notifier);

    // La app no mira el sistema: ni al abrirse ni al cambiar.
    for (final (choice, system, expected) in [
      (LocaleChoice.es, const Locale('fr'), 'es'),
      (LocaleChoice.es, const Locale('en'), 'es'),
      (LocaleChoice.en, const Locale('fr'), 'en'),
      (LocaleChoice.en, const Locale('es'), 'en'),
      (LocaleChoice.en, const Locale('ca', 'ES'), 'en'),
    ]) {
      testWidgets(
        'CA-015-09: con "${choice.code}" y el sistema en '
        '"${system.toLanguageTag()}" se ve "$expected" y el sistema no cuenta',
        (tester) async {
          final repo = InMemoryTaskRepository();
          await repo.setLocale(choice);
          await pumpUnaApp(tester, repo: repo, locale: system, tasks: _tasks);
          expect(shown(tester), expected);
          expect(
            find.bySemanticsLabel(_l10n(expected).menuButton),
            findsOneWidget,
          );

          // El sistema cambia a otro idioma: la app se queda como estaba.
          final other = expected == 'es'
              ? const Locale('en')
              : const Locale('es');
          await _switchTo(tester, [other]);
          expect(shown(tester), expected);
          await _switchTo(tester, [const Locale('fr')]);
          expect(shown(tester), expected);
          expect(
            find.bySemanticsLabel(_l10n(expected).menuButton),
            findsOneWidget,
          );
        },
      );
    }

    // "Como el sistema": la regla de la 010 sin cambios.
    for (final (system, expected) in [
      (const Locale('ca', 'ES'), 'es'),
      (const Locale('es', 'MX'), 'es'),
      (const Locale('fr'), 'en'),
      (const Locale('gl', 'ES'), 'en'),
    ]) {
      testWidgets('CA-015-09: "Como el sistema" con el sistema en '
          '"${system.toLanguageTag()}" → "$expected" (regla de la 010)', (
        tester,
      ) async {
        final repo = InMemoryTaskRepository();
        await repo.setLocale(LocaleChoice.system);
        await pumpUnaApp(tester, repo: repo, locale: system, tasks: _tasks);
        expect(shown(tester), expected);
      });
    }

    testWidgets('CA-015-09: "Como el sistema" sigue los cambios del sistema '
        'en su sitio', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        locale: const Locale('es'),
        tasks: _tasks,
      );
      expect(shown(tester), 'es');
      await _switchTo(tester, [const Locale('fr'), const Locale('en')]);
      expect(shown(tester), 'en');
      expect(find.text(_tasks.first), findsOneWidget);
      await _switchTo(tester, [const Locale('ca', 'ES')]);
      expect(shown(tester), 'es');
    });

    testWidgets('CA-015-09: cambiar el idioma por el controlador cambia los '
        'textos en su sitio, sin tocar la tarea', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        locale: const Locale('fr'),
        tasks: _tasks,
      );
      expect(shown(tester), 'en');
      controller(tester).applyLocale(LocaleChoice.es);
      await tester.pumpAndSettle();
      expect(shown(tester), 'es');
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text(_tasks.first), findsOneWidget);
      expect(find.bySemanticsLabel(_l10n('es').menuButton), findsOneWidget);

      // Y de vuelta a "Como el sistema": vuelve a mandar el sistema.
      controller(tester).applyLocale(LocaleChoice.system);
      await tester.pumpAndSettle();
      expect(shown(tester), 'en');
      await _switchTo(tester, [const Locale('es')]);
      expect(shown(tester), 'es');
    });

    testWidgets('CA-015-10: con un idioma guardado, la primera pintura ya '
        'está en ese idioma', (tester) async {
      final repo = InMemoryTaskRepository();
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(repo),
            bootStateProvider.overrideWithValue(
              BootState(
                currentTask: sampleTask(text: _tasks.first),
                firstRunDone: true,
                locale: LocaleChoice.en,
              ),
            ),
            clockProvider.overrideWithValue(TesterClock(tester)),
          ],
          child: const UnaApp(),
        ),
      );
      // Solo el primer fotograma, sin asentar nada.
      final element = tester.element(find.byType(CurrentTaskScreen));
      expect(Localizations.localeOf(element).languageCode, 'en');
      expect(AppLocalizations.of(element).menuButton, _l10n('en').menuButton);
    });
  });

  // Los dos sentidos: ES → EN y EN → ES.
  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CA-010-06 ($from → $to): cambio de idioma en caliente', () {
      testWidgets('la tarea actual sigue y el resto de la app cambia', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text(_tasks.first), findsOneWidget);
        expect(find.bySemanticsLabel(before.menuButton), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        expect(find.text(_tasks.first), findsOneWidget);
        expect(find.text(_tasks[1]), findsNothing);
        expect(find.bySemanticsLabel(after.menuButton), findsOneWidget);
        expect(find.bySemanticsLabel(before.menuButton), findsNothing);
        expect(
          find.bySemanticsLabel(after.currentTaskSemantics(_tasks.first)),
          findsOneWidget,
        );
      });

      testWidgets('el editor conserva el texto que se estaba escribiendo', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
        );
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        await tester.enterText(find.byType(EditableText), 'Zxq borrador');
        await tester.pump();
        expect(find.text(before.editorSaveFirst), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expect(find.text('Zxq borrador'), findsOneWidget);
        expect(find.text(after.editorSaveFirst), findsOneWidget);
        expect(find.text(before.editorSaveFirst), findsNothing);
        // El campo sigue enfocado y sin perder el texto.
        final field = tester.widget<EditableText>(find.byType(EditableText));
        expect(field.controller.text, 'Zxq borrador');
        expect(field.focusNode.hasFocus, isTrue);
        expectNoL10nLeaks(tester, languageCode: to);
      });

      testWidgets(
        'el editor de una tarea existente conserva el texto editado',
        (tester) async {
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(
            tester,
            repo: repo,
            locale: Locale(from),
            tasks: _tasks,
          );
          await tester.tap(find.bySemanticsLabel(before.menuButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(before.menuEdit));
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditorScreen), findsOneWidget);
          await tester.enterText(find.byType(EditableText), 'Zxq editada');
          await tester.pump();

          await _switchTo(tester, [Locale(to)]);

          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(find.text('Zxq editada'), findsOneWidget);
          expect(find.text(after.editorSaveChanges), findsOneWidget);
          // Nada se ha guardado por el camino.
          expect((await repo.currentTask())!.text, _tasks.first);
          expectNoL10nLeaks(tester, languageCode: to);
        },
      );

      testWidgets('el menú abierto sigue abierto, en el idioma nuevo', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        final semantics = tester.ensureSemantics();
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        expect(find.byType(MenuSheet), findsOneWidget);
        expect(find.text(before.menuEdit), findsOneWidget);
        expect(find.text(before.menuAllTasks), findsOneWidget);

        final stale = _modalBarrierTexts(tester);
        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(MenuSheet), findsOneWidget);
        expect(find.text(after.menuEdit), findsOneWidget);
        expect(find.text(after.menuAllTasks), findsOneWidget);
        // El recuento solo se lee (semántica, junto a "Todas mis tareas"), con
        // el plural del idioma nuevo.
        final reads = semanticsTexts(tester).join('\n');
        expect(reads, contains(after.menuAllTasksCount(_tasks.length)));
        expect(reads, isNot(contains(before.menuAllTasksCount(_tasks.length))));
        // Sigue en la misma tarea.
        expect(find.text(_tasks.first), findsOneWidget);
        // CA-010-07: tampoco después del cambio. La etiqueta del fondo modal
        // (`scrimLabel`) no sale de los ARB y ya está aceptada (spec §6).
        _expectNoLeaksAfterSwitch(tester, to, staleBarrier: stale);
        semantics.dispose();
      });

      testWidgets('CA-014-03: la card de deshacer visible cambia de idioma y '
          'sigue la cuenta', (tester) async {
        final repo = InMemoryTaskRepository();
        await pumpUnaApp(
          tester,
          repo: repo,
          locale: Locale(from),
          tasks: _tasks,
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuDelete));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(UnaMotion.crumple);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(UndoCard), findsOneWidget);
        expect(find.text(before.undoDeletedTitle), findsOneWidget);
        expect(find.text(before.undoButton), findsOneWidget);

        // Sin `pumpAndSettle`: con la card a la vista nunca se asienta y
        // avanzaría el reloj hasta que caduque.
        tester.platformDispatcher.localesTestValue = [Locale(to)];
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // La cuenta no se reinicia: sigue la misma card, ya en el idioma
        // nuevo, y la tarea sigue eliminada.
        expect(find.byType(UndoCard), findsOneWidget);
        expect(find.text(after.undoDeletedTitle), findsOneWidget);
        expect(find.text(after.undoButton), findsOneWidget);
        expect(find.text(before.undoDeletedTitle), findsNothing);
        expect((await repo.pendingTasks()).length, _tasks.length - 1);
        await tester.pump(UnaMotion.undoWindow);
        await tester.pumpAndSettle();
        expect(find.byType(UndoCard), findsNothing);
      });

      testWidgets('el listado abierto sigue abierto, con sus filas', (
        tester,
      ) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuAllTasks));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(find.text(before.listTitle), findsOneWidget);

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(find.text(after.listTitle), findsOneWidget);
        expect(find.text(before.listTitle), findsNothing);
        for (final t in _tasks) {
          expect(find.text(t), findsOneWidget);
        }
        expectNoL10nLeaks(tester, languageCode: to);
      });

      testWidgets(
        'vuelta en menos de 10 minutos: se conserva lo que había, en el idioma nuevo',
        (tester) async {
          final clock = FakeClock();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            locale: Locale(from),
            clock: clock,
          );
          await tester.enterText(find.byType(EditableText), 'Zxq borrador');
          await tester.pump();

          await _leaveAndReturn(
            tester,
            clock,
            locales: [Locale(to)],
            away: UnaApp.resetAfter - const Duration(seconds: 1),
          );

          expect(find.byType(TaskEditorScreen), findsOneWidget);
          expect(find.text('Zxq borrador'), findsOneWidget);
          expect(find.text(after.editorSaveFirst), findsOneWidget);
        },
      );

      testWidgets(
        'CA-001-12: vuelta en 10 minutos o más, se descarta el editor y la app ya está en el idioma nuevo',
        (tester) async {
          final clock = FakeClock();
          await pumpUnaApp(
            tester,
            repo: InMemoryTaskRepository(),
            locale: Locale(from),
            clock: clock,
            tasks: _tasks,
          );
          // Editor con texto a medias, sobre la tarea actual.
          await tester.tap(find.bySemanticsLabel(before.menuButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(before.menuEdit));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(EditableText), 'Zxq borrador');
          await tester.pump();
          expect(find.byType(TaskEditorScreen), findsOneWidget);

          await _leaveAndReturn(
            tester,
            clock,
            locales: [Locale(to)],
            away: UnaApp.resetAfter,
          );

          expect(find.byType(TaskEditorScreen), findsNothing);
          expect(find.text('Zxq borrador'), findsNothing);
          expect(find.byType(CurrentTaskScreen), findsOneWidget);
          expect(find.text(_tasks.first), findsOneWidget);
          expect(find.bySemanticsLabel(after.menuButton), findsOneWidget);
          expect(find.bySemanticsLabel(before.menuButton), findsNothing);
          expect(_current(tester).localeName, to);
        },
      );
    });
  }

  group('CL-010-4: idioma de derecha a izquierda', () {
    for (final from in ['es', 'en']) {
      testWidgets(
        'CA-010-06: $from → ar: la app pasa a inglés, de izquierda a derecha, sin perder el estado',
        (tester) async {
          final en = _l10n('en');
          final repo = InMemoryTaskRepository();
          await pumpUnaApp(
            tester,
            repo: repo,
            locale: Locale(from),
            tasks: _tasks,
          );
          await tester.tap(find.bySemanticsLabel(_l10n(from).menuButton));
          await tester.pumpAndSettle();
          expect(find.byType(MenuSheet), findsOneWidget);

          await _switchTo(tester, const [Locale('ar')]);

          expect(_current(tester).localeName, 'en');
          expect(find.byType(MenuSheet), findsOneWidget);
          expect(find.text(en.menuEdit), findsOneWidget);
          expect(find.text(_tasks.first), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(MenuSheet))),
            TextDirection.ltr,
          );
          expect(
            Directionality.of(tester.element(find.byType(CurrentTaskScreen))),
            TextDirection.ltr,
          );
        },
      );
    }

    testWidgets(
      'CA-010-06: ar → es con el editor a medias: pasa a español y conserva el texto',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: const Locale('ar'),
        );
        expect(_current(tester).localeName, 'en');
        await tester.enterText(find.byType(EditableText), 'Zxq borrador');
        await tester.pump();

        await _switchTo(tester, const [Locale('es')]);

        expect(_current(tester).localeName, 'es');
        expect(find.text('Zxq borrador'), findsOneWidget);
        expect(find.text(_l10n('es').editorSaveFirst), findsOneWidget);
      },
    );

    testWidgets(
      'CA-010-06: he → [ca, es-ES]: se usa el primer idioma admitido de la lista',
      (tester) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: const Locale('he'),
          tasks: _tasks,
        );
        expect(_current(tester).localeName, 'en');

        await _switchTo(tester, const [Locale('ca'), Locale('es', 'ES')]);

        expect(_current(tester).localeName, 'es');
        expect(find.text(_tasks.first), findsOneWidget);
      },
    );
  });

  // Con adjuntos (T-010-08). Adjuntos sin disco ni red; el PDF, con el motor
  // de verdad para poder comprobar su página y su zoom. Primero todos los
  // ES → EN y luego los EN → ES: Flutter numera las acciones la primera vez
  // que las ve, así que el primer cambio de cada tipo es el que prueba el
  // orden de verdad (plan §7).
  late MemoryAttachmentStore store;
  late FakePdfImporter pdfs;
  late FakeWebPages web;

  setUp(() {
    store = MemoryAttachmentStore();
    pdfs = FakePdfImporter(store);
    web = FakeWebPages();
    taskPdfCalls.clear();
  });

  List<Override> overrides({bool realPdf = false}) => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
    pdfImporterProvider.overrideWithValue(pdfs),
    if (!realPdf) ...fakePdfViews,
    ...web.overrides,
    linkOpenerProvider.overrideWithValue(_Opener()),
  ];

  Future<void> pumpWith(
    WidgetTester tester,
    List<Task> tasks,
    String languageCode, {
    bool realPdf = false,
  }) async {
    final repo = InMemoryTaskRepository();
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      locale: Locale(languageCode),
      overrides: overrides(realPdf: realPdf),
    );
    if (!realPdf) await tester.pumpAndSettle();
  }

  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CA-010-06 y CA-010-11 con adjuntos ($from → $to)', () {
      testWidgets('tarea solo texto: acciones en el mismo orden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpWith(tester, [
          sampleTask(id: 't0', text: _tasks.first, rank: 'MA'),
        ], from);
        _expectTaskActions(tester, before, _taskActions);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(CurrentTaskScreen), findsOneWidget);
        _expectTaskActions(tester, after, _taskActions);
        expect(tester.takeAnnouncements(), isEmpty);
        semantics.dispose();
      });

      testWidgets('imagen: sigue en pantalla y sus acciones, en orden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpWith(tester, [await _imageTask(store)], from);
        await tester.pumpAndSettle();
        expect(find.byType(TaskImage), findsOneWidget);
        final image = tester.state(find.byType(ZoomablePhoto));
        _expectTaskActions(tester, before, _taskActions);
        expect(find.bySemanticsLabel(_photoLabel(before)), findsOneWidget);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskImage), findsOneWidget);
        // La misma pantalla, no una nueva: la imagen no se vuelve a cargar.
        expect(tester.state(find.byType(ZoomablePhoto)), same(image));
        expect(find.text(_tasks.first), findsOneWidget);
        expect(find.bySemanticsLabel(_photoLabel(after)), findsOneWidget);
        expect(find.bySemanticsLabel(_photoLabel(before)), findsNothing);
        _expectTaskActions(tester, after, _taskActions);
        expect(tester.takeAnnouncements(), isEmpty);
        semantics.dispose();
      });

      testWidgets('PDF: misma página y mismo zoom, y sus acciones, en orden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpWith(tester, [await _pdfTask(store)], from, realPdf: true);
        await _settlePdf(tester, 200);
        final page1 = RegExp('^${before.pdfPageA11y(1, 20)}');
        expect(find.bySemanticsLabel(page1), findsOneWidget);

        // Página 2 y zoom ×1,5, con las acciones del lector.
        tester.semantics.customAction(
          find.semantics.byLabel(page1),
          CustomSemanticsAction(label: before.pdfNextPage),
        );
        await _settlePdf(tester);
        tester.semantics.customAction(
          find.semantics.byLabel(RegExp('^${before.pdfPageA11y(2, 20)}')),
          CustomSemanticsAction(label: before.pdfZoomIn),
        );
        await _settlePdf(tester);
        expect(
          find.bySemanticsLabel(RegExp('^${before.pdfPageA11y(2, 20)}')),
          findsOneWidget,
        );
        _expectTaskActions(
          tester,
          before,
          _pdfActions,
          node: find.bySemanticsLabel(RegExp('^${before.pdfPageA11y(2, 20)}')),
        );
        // La franja de la tarea conserva Completar y Eliminar.
        _expectTaskActions(tester, before, _taskActions);
        final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
        final controller = viewer.controller!;
        final zoom = controller.currentZoom;
        final top = controller.visibleRect.top;
        final state = tester.state(find.byType(TaskPdfView));
        expect(zoom / controller.minScale, closeTo(1.5, 0.01));
        tester.takeAnnouncements();

        tester.platformDispatcher.localesTestValue = [Locale(to)];
        await _settlePdf(tester);

        // El mismo visor, con la misma página y el mismo zoom, en el otro
        // idioma y sin anuncios.
        expect(tester.takeException(), isNull);
        expect(tester.state(find.byType(TaskPdfView)), same(state));
        expect(
          tester.widget<PdfViewer>(find.byType(PdfViewer)).controller,
          same(controller),
        );
        expect(controller.currentZoom, closeTo(zoom, 0.0001));
        expect(controller.visibleRect.top, closeTo(top, 0.5));
        expect(
          find.bySemanticsLabel(RegExp('^${after.pdfPageA11y(2, 20)}')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('^${before.pdfPageA11y(2, 20)}')),
          findsNothing,
        );
        _expectTaskActions(
          tester,
          after,
          _pdfActions,
          node: find.bySemanticsLabel(RegExp('^${after.pdfPageA11y(2, 20)}')),
        );
        _expectTaskActions(tester, after, _taskActions);
        expect(tester.takeAnnouncements(), isEmpty);
        // pdfrx deja temporizadores propios: se desmonta y se dejan correr.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        semantics.dispose();
      });

      testWidgets('web: no se recarga y sus acciones, en orden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpWith(tester, [_webTask()], from);
        expect(find.byType(WebBar), findsOneWidget);
        web.last
          ..started(_webAddress)
          ..progress(100)
          ..finished(_webAddress);
        await tester.pumpAndSettle();
        final driver = web.last;
        final loads = driver.loads.length;
        expect(loads, 1);
        _expectTaskActions(tester, before, _taskActions);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        // Ni una WebView nueva ni otra petición de carga ni un cierre.
        expect(find.byType(WebBar), findsOneWidget);
        expect(web.drivers, [same(driver)]);
        expect(driver.loads.length, loads);
        expect(driver.attachCount, 1);
        expect(driver.stops, 0);
        expect(driver.destroyed, isFalse);
        expect(driver.disposed, isFalse);
        _expectTaskActions(tester, after, _taskActions);
        expect(tester.takeAnnouncements(), isEmpty);
        semantics.dispose();
      });

      testWidgets('fila del listado: acciones en el mismo orden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpWith(tester, [
          for (final (i, t) in _tasks.indexed)
            sampleTask(
              id: 't$i',
              text: t,
              rank: 'M${String.fromCharCode(65 + i)}',
              colorKey: i,
            ),
        ], from);
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuAllTasks));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);

        // Fila actual, del medio y última: cada una con sus acciones.
        final rows = <(String Function(AppLocalizations), List<_ActionName>)>[
          (
            (l) => l.a11yRowCurrent(_tasks.length, _tasks[0]),
            [(l) => l.listEdit, (l) => l.deleteA11yAction],
          ),
          (
            (l) => l.a11yRowPosition(2, _tasks.length, _tasks[1]),
            [
              (l) => l.listMakeCurrent,
              (l) => l.listMoveDown,
              (l) => l.listEdit,
              (l) => l.deleteA11yAction,
            ],
          ),
          (
            (l) => l.a11yRowPosition(3, _tasks.length, _tasks[2]),
            [
              (l) => l.listMakeCurrent,
              (l) => l.listMoveUp,
              (l) => l.listEdit,
              (l) => l.deleteA11yAction,
            ],
          ),
        ];
        void expectRows(AppLocalizations l10n) {
          for (final (label, expected) in rows) {
            final node = tester.getSemantics(
              find.bySemanticsLabel(label(l10n)),
            );
            expect(_actionNames(node), [
              for (final name in expected) name(l10n),
            ], reason: label(l10n));
          }
        }

        expectRows(before);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskListScreen), findsOneWidget);
        expectRows(after);
        expect(tester.takeAnnouncements(), isEmpty);
        semantics.dispose();
      });
    });
  }

  // Ajustes (spec 015, CL-015-13): los dos niveles cambian de idioma sin
  // cerrarse (el idioma del sistema cambia con "Como el sistema").
  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CL-015-13 ($from → $to): Ajustes en caliente', () {
      /// Abre el menú, "Ajustes" y, según [depth], la página de Idioma.
      Future<void> openLevel(WidgetTester tester, int depth) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
          overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuSettings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        if (depth >= 1) {
          await tester.tap(find.text(before.settingsLanguage));
          await tester.pumpAndSettle();
          expect(find.byType(LanguagePage), findsOneWidget);
        }
      }

      testWidgets('nivel 1: sigue abierto, con los textos y el nombre de las '
          'filas de web en el idioma nuevo', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLevel(tester, 0);
        expect(find.text(before.settingsTitle), findsOneWidget);
        expect(find.text(before.settingsPrivacy), findsOneWidget);
        expect(find.bySemanticsLabel(before.settingsClose), findsOneWidget);
        expect(
          semanticsTexts(tester),
          contains('${before.settingsPrivacy}, ${before.settingsOpensWebHint}'),
        );
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(after.settingsTitle), findsOneWidget);
        expect(find.text(after.settingsLanguage), findsOneWidget);
        expect(find.text(after.settingsLanguageSystem), findsOneWidget);
        expect(find.text(after.settingsKeepAwake), findsOneWidget);
        expect(find.text(after.settingsInfo), findsOneWidget);
        expect(find.text(after.settingsPrivacy), findsOneWidget);
        expect(find.text(after.settingsThirdPartyLicenses), findsOneWidget);
        expect(find.text(after.settingsHelp), findsOneWidget);
        expect(find.text(before.settingsPrivacy), findsNothing);
        expect(find.bySemanticsLabel(after.settingsClose), findsOneWidget);
        expect(find.bySemanticsLabel(before.settingsClose), findsNothing);
        final reads = semanticsTexts(tester);
        expect(
          reads,
          contains('${after.settingsPrivacy}, ${after.settingsOpensWebHint}'),
        );
        expect(
          reads,
          isNot(
            contains(
              '${before.settingsPrivacy}, ${before.settingsOpensWebHint}',
            ),
          ),
        );
        // El título sigue siendo un encabezado en el otro idioma.
        expect(
          tester
              .getSemantics(find.text(after.settingsTitle).first)
              .flagsCollection
              .isHeader,
          isTrue,
        );
        _expectNoLeaksAfterSwitch(tester, to);
        semantics.dispose();
      });

      testWidgets('nivel 2: sigue abierto, con "Como el sistema" y el idioma '
          'que resulta ahora', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLevel(tester, 1);
        expect(find.text(before.settingsLanguage), findsOneWidget);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(LanguagePage), findsOneWidget);
        expect(find.text(after.settingsLanguage), findsOneWidget);
        expect(find.text(after.settingsLanguageSystem), findsOneWidget);
        expect(find.text(before.settingsLanguageSystem), findsNothing);
        expect(find.bySemanticsLabel(after.settingsBack), findsOneWidget);
        expect(find.bySemanticsLabel(before.settingsBack), findsNothing);
        _expectNoLeaksAfterSwitch(tester, to);
        semantics.dispose();
      });

      testWidgets('los dos niveles siguen apilados: atrás sube de uno en '
          'uno tras el cambio', (tester) async {
        await openLevel(tester, 1);
        await _switchTo(tester, [Locale(to)]);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePage), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(after.settingsLanguage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // El menú se cerró al abrir Ajustes (CA-015-01a): se vuelve a la tarea.
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MenuSheet), findsNothing);
        expect(find.text(_tasks.first), findsOneWidget);
      });
    });
  }
}
