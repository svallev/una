import 'dart:convert';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/settings/license_detail_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
import '../support/fonts.dart';
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

/// Fuente de licencias sin registro (spec 012): un elemento con dos textos,
/// neutros (ni ES ni EN) para no confundirlos con la interfaz. Cuenta las
/// lecturas.
class _LicenseSource implements LicenseSource {
  int loads = 0;

  @override
  Future<List<LicensePackage>> load() async {
    loads++;
    return const [
      LicensePackage(
        name: 'zxq_pkg',
        texts: [
          LicenseText([(text: 'Zxq licence text one.', indent: 0)]),
          LicenseText([(text: 'Zxq licence text two.', indent: 1)]),
        ],
      ),
    ];
  }
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
        final image = tester.state(find.byType(TaskImage));
        _expectTaskActions(tester, before, _taskActions);
        expect(find.bySemanticsLabel(_photoLabel(before)), findsOneWidget);
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(TaskImage), findsOneWidget);
        // La misma pantalla, no una nueva: la imagen no se vuelve a cargar.
        expect(tester.state(find.byType(TaskImage)), same(image));
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

  // La Configuración (spec 012, CA-012-07): los tres niveles cambian de idioma
  // sin cerrarse; el texto de las licencias no cambia y sigue marcado como
  // inglés para el lector.
  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CA-012-07 ($from → $to): la Configuración en caliente', () {
      late _LicenseSource source;

      setUp(() => source = _LicenseSource());

      /// Abre el menú, "Configuración y perfil" y, según [depth], los niveles
      /// 2 (1) y 3 (2).
      Future<void> openLevel(WidgetTester tester, int depth) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
          overrides: [
            licenseSourceProvider.overrideWithValue(source),
            linkOpenerProvider.overrideWithValue(_Opener()),
          ],
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuSettings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        if (depth >= 1) {
          await tester.tap(find.text(before.settingsLicenses));
          await tester.pumpAndSettle();
          expect(find.byType(LicensesScreen), findsOneWidget);
        }
        if (depth >= 2) {
          await tester.tap(find.text('zxq_pkg'));
          await tester.pumpAndSettle();
          expect(find.byType(LicenseDetailScreen), findsOneWidget);
        }
      }

      Locale? localeOf(WidgetTester tester, Finder f) =>
          tester.getSemantics(f).getSemanticsData().locale;

      testWidgets('nivel 1: sigue abierto, con los textos y la pista del '
          'lector en el idioma nuevo', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLevel(tester, 0);
        expect(find.text(before.menuSettings), findsOneWidget);
        expect(find.text(before.settingsPrivacy), findsOneWidget);
        expect(find.bySemanticsLabel(before.settingsClose), findsOneWidget);
        expect(semanticsTexts(tester), contains(before.settingsPrivacyHint));
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(after.menuSettings), findsOneWidget);
        expect(find.text(after.settingsLicenses), findsOneWidget);
        expect(find.text(after.settingsPrivacy), findsOneWidget);
        expect(find.text(before.settingsPrivacy), findsNothing);
        expect(find.bySemanticsLabel(after.settingsClose), findsOneWidget);
        expect(find.bySemanticsLabel(before.settingsClose), findsNothing);
        final reads = semanticsTexts(tester);
        expect(reads, contains(after.settingsPrivacyHint));
        expect(reads, isNot(contains(before.settingsPrivacyHint)));
        // El título dice lo mismo en el otro idioma (y no es el del sistema).
        expect(
          tester
              .getSemantics(find.text(after.menuSettings))
              .flagsCollection
              .isHeader,
          isTrue,
        );
        _expectNoLeaksAfterSwitch(tester, to);
        semantics.dispose();
      });

      testWidgets('nivel 2: sigue abierto, con "N licencias" en el idioma '
          'nuevo y sin volver a leer las licencias', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLevel(tester, 1);
        expect(source.loads, 1);
        expect(find.text(before.licensesTitle), findsOneWidget);
        expect(
          find.bySemanticsLabel('zxq_pkg, ${before.licensesCount(2)}'),
          findsOneWidget,
        );
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(LicensesScreen), findsOneWidget);
        expect(find.text(after.licensesTitle), findsOneWidget);
        expect(
          find.bySemanticsLabel('zxq_pkg, ${after.licensesCount(2)}'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('zxq_pkg, ${before.licensesCount(2)}'),
          findsNothing,
        );
        expect(find.bySemanticsLabel(after.licensesBack), findsOneWidget);
        expect(find.bySemanticsLabel(before.licensesBack), findsNothing);
        expect(source.loads, 1, reason: 'no se vuelven a leer');
        _expectNoLeaksAfterSwitch(tester, to);
        semantics.dispose();
      });

      testWidgets('nivel 3: sigue abierto; el título, los encabezados y '
          'Volver cambian; el texto de la licencia no, y sigue marcado como '
          'inglés', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLevel(tester, 2);
        final one = find.text('Zxq licence text one.');
        final two = find.text('Zxq licence text two.');
        expect(find.text(before.licensesTextOf(1, 2)), findsOneWidget);
        expect(localeOf(tester, one), const Locale('en'));
        tester.takeAnnouncements();

        await _switchTo(tester, [Locale(to)]);

        expect(find.byType(LicenseDetailScreen), findsOneWidget);
        // El título es el nombre del elemento: no cambia.
        expect(find.text('zxq_pkg'), findsOneWidget);
        expect(find.text(after.licensesTextOf(1, 2)), findsOneWidget);
        expect(find.text(after.licensesTextOf(2, 2)), findsOneWidget);
        expect(find.text(before.licensesTextOf(1, 2)), findsNothing);
        expect(find.bySemanticsLabel(after.licensesBack), findsOneWidget);
        expect(find.bySemanticsLabel(before.licensesBack), findsNothing);
        // El texto de la licencia, intacto y en inglés para el lector.
        expect(one, findsOneWidget);
        expect(two, findsOneWidget);
        expect(localeOf(tester, one), const Locale('en'));
        expect(localeOf(tester, two), const Locale('en'));
        // Lo demás, en el idioma nuevo.
        expect(
          localeOf(tester, find.text(after.licensesTextOf(1, 2))),
          Locale(to),
        );
        expect(
          localeOf(tester, find.bySemanticsLabel(after.licensesBack)),
          Locale(to),
        );
        _expectNoLeaksAfterSwitch(tester, to);
        semantics.dispose();
      });

      testWidgets('los tres niveles siguen apilados: atrás sube de uno en '
          'uno tras el cambio', (tester) async {
        await openLevel(tester, 2);
        await _switchTo(tester, [Locale(to)]);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(LicensesScreen), findsOneWidget);
        expect(find.text(after.licensesTitle), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text(after.settingsLicenses), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(MenuSheet), findsOneWidget);
        expect(find.text(after.menuAllTasks), findsOneWidget);
      });
    });
  }

  // La entrada de las bibliotecas de Android cambia de nombre (y de sitio en la
  // lista) con el idioma; el foco y la fila abierta la siguen (spec 013,
  // CA-013-02, P-013-3).
  for (final (from, to) in [('es', 'en'), ('en', 'es')]) {
    final before = _l10n(from);
    final after = _l10n(to);

    group('CA-013-02 ($from → $to): la entrada de Android al cambiar de '
        'idioma', () {
      setUpAll(loadAppFonts);

      String androidName(AppLocalizations l10n) =>
          l10n.licensesAndroidLibraries;
      String labelOf(AppLocalizations l10n, String name) =>
          '$name, ${l10n.licensesCount(1)}';

      final inLicenses = find.byType(LicensesScreen);
      final list = find.descendant(
        of: inLicenses,
        matching: find.byType(ListView),
      );
      final listScrollable = find.descendant(
        of: inLicenses,
        matching: find.byType(Scrollable),
      );

      /// Abre el nivel 2 con [count] paquetes "ant_NN" y la entrada de Android,
      /// que va primera en inglés ("Android…") y última en español
      /// ("Bibliotecas…"), de modo que cambia de sitio todo lo posible.
      Future<void> openLicenses(WidgetTester tester, int count) async {
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          locale: Locale(from),
          tasks: _tasks,
          overrides: [
            licenseSourceProvider.overrideWithValue(_ManySource(count)),
            linkOpenerProvider.overrideWithValue(_Opener()),
          ],
        );
        await tester.tap(find.bySemanticsLabel(before.menuButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.menuSettings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(before.settingsLicenses));
        await tester.pumpAndSettle();
        expect(inLicenses, findsOneWidget);
      }

      /// Pone el foco de teclado en la fila de [name] (la lleva a la vista).
      Future<void> focusRow(WidgetTester tester, String name) async {
        await tester.scrollUntilVisible(
          find.text(name),
          300,
          scrollable: listScrollable.first,
        );
        Focus.of(tester.element(find.text(name))).requestFocus();
        await tester.pump();
        expect(_focusedRow(), name);
      }

      /// La fila de [name] está entera dentro de la lista visible.
      void expectInView(WidgetTester tester, String name) {
        expect(find.text(name), findsOneWidget, reason: 'fila construida');
        final row = tester.getRect(find.text(name));
        final view = tester.getRect(list);
        expect(row.top, greaterThanOrEqualTo(view.top));
        expect(row.bottom, lessThanOrEqualTo(view.bottom));
      }

      /// Anota los avisos de foco que recibe el sistema de accesibilidad.
      List<int> captureFocusEvents(WidgetTester tester) {
        final events = <int>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (message) async {
                final map = message! as Map<Object?, Object?>;
                if (map['type'] == 'focus') events.add(map['nodeId']! as int);
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
        return events;
      }

      int nodeId(WidgetTester tester, String label) =>
          tester.getSemantics(find.bySemanticsLabel(label)).id;

      testWidgets('lista pequeña: la entrada sigue en la ventana, con el '
          'mismo nodo y el foco de teclado, en su sitio nuevo', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLicenses(tester, 2);
        await focusRow(tester, androidName(before));
        final id = nodeId(tester, labelOf(before, androidName(before)));

        await _switchTo(tester, [Locale(to)]);

        expect(find.text(androidName(before)), findsNothing);
        expect(_focusedRow(), androidName(after));
        expect(nodeId(tester, labelOf(after, androidName(after))), id);
        // Orden nuevo: la entrada, primera en inglés y última en español.
        final tops = [
          for (final n in ['ant_00', 'ant_01', androidName(after)])
            tester.getTopLeft(find.text(n)).dy,
        ];
        expect(tops[0] < tops[1], isTrue);
        expect(
          to == 'en' ? tops[2] < tops[0] : tops[2] > tops[1],
          isTrue,
          reason: 'la entrada va en su sitio alfabético nuevo',
        );
        semantics.dispose();
      });

      testWidgets('lista de 60: la entrada se mueve más de una ventana; el '
          'foco de teclado sigue en su fila, a la vista y avisada al lector', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final events = captureFocusEvents(tester);
        await openLicenses(tester, 59);
        await focusRow(tester, androidName(before));
        events.clear();

        await _switchTo(tester, [Locale(to)]);

        expect(_focusedRow(), androidName(after));
        expectInView(tester, androidName(after));
        expect(
          events,
          contains(nodeId(tester, labelOf(after, androidName(after)))),
        );
        semantics.dispose();
      });

      testWidgets('nivel 3 abierto: el título cambia, el desplazamiento se '
          'conserva y al volver el foco va a la fila, en su sitio nuevo', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final events = captureFocusEvents(tester);
        await openLicenses(tester, 59);
        await tester.scrollUntilVisible(
          find.text(androidName(before)),
          300,
          scrollable: listScrollable.first,
        );
        await tester.tap(find.text(androidName(before)));
        await tester.pumpAndSettle();
        final detail = find.byType(LicenseDetailScreen);
        expect(detail, findsOneWidget);
        final detailScrollable = find.descendant(
          of: detail,
          matching: find.byType(Scrollable),
        );
        await tester.drag(detailScrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
        double offset() => tester
            .state<ScrollableState>(detailScrollable.first)
            .position
            .pixels;
        final scrolled = offset();
        expect(scrolled, greaterThan(0));

        await _switchTo(tester, [Locale(to)]);

        expect(
          find.descendant(of: detail, matching: find.text(androidName(after))),
          findsOneWidget,
        );
        expect(offset(), scrolled);

        events.clear();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(detail, findsNothing);
        expect(_focusedRow(), androidName(after));
        expectInView(tester, androidName(after));
        expect(
          events,
          contains(nodeId(tester, labelOf(after, androidName(after)))),
        );
        semantics.dispose();
      });

      // F-2 (T-013-08c): la fila sube y queda justo por encima de la ventana,
      // todavía construida (dentro del margen de construcción). Solo aplica a
      // es → en: es la dirección en que la entrada sube (de última a primera).
      if (from == 'es') {
        testWidgets('la fila sube y queda justo sobre la ventana, aún '
            'construida: se lleva a la vista', (tester) async {
          final semantics = tester.ensureSemantics();
          await openLicenses(tester, 11);
          await tester.scrollUntilVisible(
            find.text(androidName(before)),
            300,
            scrollable: listScrollable.first,
          );
          await tester.drag(list, const Offset(0, -2000));
          await tester.pumpAndSettle();
          Focus.of(tester.element(find.text(androidName(before))))
              .requestFocus();
          await tester.pump();
          expect(_focusedRow(), androidName(before));
          final position = tester
              .state<ScrollableState>(listScrollable.first)
              .position;
          expect(
            position.pixels,
            greaterThan(0),
            reason: 'la lista está desplazada',
          );

          await _switchTo(tester, [Locale(to)]);

          expect(_focusedRow(), androidName(after));
          expectInView(tester, androidName(after));
          semantics.dispose();
        });

        testWidgets('al volver del nivel 3 la fila, que subió y quedó sobre '
            'la ventana, se lleva a la vista', (tester) async {
          final semantics = tester.ensureSemantics();
          await openLicenses(tester, 11);
          await tester.scrollUntilVisible(
            find.text(androidName(before)),
            300,
            scrollable: listScrollable.first,
          );
          await tester.drag(list, const Offset(0, -2000));
          await tester.pumpAndSettle();
          await tester.tap(find.text(androidName(before)));
          await tester.pumpAndSettle();
          expect(find.byType(LicenseDetailScreen), findsOneWidget);

          await _switchTo(tester, [Locale(to)]);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(find.byType(LicenseDetailScreen), findsNothing);
          expect(_focusedRow(), androidName(after));
          expectInView(tester, androidName(after));
          semantics.dispose();
        });
      }

      testWidgets('un giro de pantalla no mueve el desplazamiento ni el '
          'foco', (tester) async {
        final semantics = tester.ensureSemantics();
        await openLicenses(tester, 59);
        await tester.drag(list, const Offset(0, -900));
        await tester.pumpAndSettle();
        final name = tester
            .widget<Text>(
              find
                  .descendant(of: list, matching: find.textContaining('ant_'))
                  .first,
            )
            .data!;
        Focus.of(tester.element(find.text(name))).requestFocus();
        await tester.pump();
        double offset() =>
            tester.state<ScrollableState>(listScrollable.first).position.pixels;
        final scrolled = offset();

        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();

        expect(offset(), scrolled);
        expect(_focusedRow(), name);
        semantics.dispose();
      });
    });
  }
}

/// Fuente de licencias para la lista larga (CA-013-02): la entrada de las
/// bibliotecas de Android, con un texto largo, y [count] paquetes "ant_NN".
/// "ant_" va entre "Android…" y "Bibliotecas…" en el orden alfabético.
class _ManySource implements LicenseSource {
  _ManySource(this.count);

  final int count;

  @override
  Future<List<LicensePackage>> load() async => [
    LicensePackage(
      name: androidLibrariesLicenseKey,
      texts: [
        LicenseText([
          for (var i = 0; i < 60; i++)
            (text: 'Zxq android licence paragraph $i.', indent: 0),
        ]),
      ],
    ),
    for (var i = 0; i < count; i++)
      LicensePackage(
        name: 'ant_${i.toString().padLeft(2, '0')}',
        texts: const [
          LicenseText([(text: 'Zxq licence text.', indent: 0)]),
        ],
      ),
  ];
}

/// El nombre de la fila de la lista de licencias que tiene el foco de teclado,
/// o null si el foco está en otra cosa.
String? _focusedRow() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final texts = find.descendant(
    of: find.byElementPredicate((e) => identical(e, context)),
    matching: find.byType(Text),
  );
  final found = texts.evaluate();
  return found.isEmpty ? null : (found.first.widget as Text).data;
}
