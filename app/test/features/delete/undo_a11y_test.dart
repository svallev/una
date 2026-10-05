import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart' show attachmentFrom;
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../../support/undo.dart';

/// La card de deshacer y el lector de pantalla, el teclado y la geometría con
/// la app entera (spec 014, CA-014-05, CA-014-16, CA-014-17, CA-014-20,
/// CL-014-7, CL-014-8). Lo que TalkBack hace de verdad se mira en el
/// emulador (`specs/014-eliminar-con-deshacer/dispositivo.md`).
const _frame = Duration(milliseconds: 16);
const _cardLabel = 'Deshacer. Tarea eliminada: Primera';

final _card = find.byType(UndoCard);
final _menuButton = find.bySemanticsLabel('Menú de la tarea');

late MemoryAttachmentStore _store;
late FakeWebPages _web;

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<_FailingInsertRepo> _pump(
  WidgetTester tester, {
  List<String> tasks = const ['Primera', 'Segunda'],
  List<Task> extra = const [],
  bool screenReader = false,
  bool? touchExploration,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  double bottomInset = 0,
}) async {
  final repo = _FailingInsertRepo();
  for (final t in extra) {
    await repo.insert(t);
  }
  await pumpUnaApp(
    tester,
    repo: repo,
    tasks: tasks,
    screenReader: screenReader,
    textScale: textScale,
    size: size,
    bottomInset: bottomInset,
    clock: TesterClock(tester),
    overrides: [
      accessibilityTimeoutsProvider.overrideWithValue(
        FakeAccessibilityTimeouts(touchExploration: touchExploration),
      ),
      attachmentStoreProvider.overrideWithValue(_store),
      pdfImporterProvider.overrideWithValue(FakePdfImporter(_store)),
      ...fakePdfViews,
      ..._web.overrides,
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Menú → Eliminar y el arrugado entero. Deja la card recién aparecida.
Future<void> _deleteFromMenu(WidgetTester tester) async {
  await tester.tap(_menuButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar'));
  await tester.pump(_frame);
  await _finishCrumple(tester);
}

Future<void> _finishCrumple(WidgetTester tester) async {
  await tester.pump(UnaMotion.crumple);
  await tester.pump(_frame);
  await tester.pump(_frame);
}

/// Lo que lee el lector, en orden.
List<String> _reading(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((n) => n.label)
    .where((l) => l.isNotEmpty)
    .toList();

/// Los avisos de foco del lector (el id del nodo al que va).
List<int> _listenFocusEvents(
  WidgetTester tester, {
  List<String>? announcements,
}) {
  final events = <int>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'focus') events.add(map['nodeId']! as int);
      if (map['type'] == 'announce' && announcements != null) {
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
  return events;
}

/// No puede volver a insertar (CA-014-23).
class _FailingInsertRepo extends InMemoryTaskRepository {
  bool failInsert = false;

  @override
  Future<void> insert(Task task) async {
    if (failInsert) throw StateError('disk I/O error: ${task.text}');
    return super.insert(task);
  }
}

/// La acción personalizada [action] del nodo que se lee [label].
void _customAction(WidgetTester tester, String label, String action) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  final id = node.getSemanticsData().customSemanticsActionIds!.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)!.label == action,
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

String? _focusLabel() => FocusManager.instance.primaryFocus?.debugLabel;

Future<Task> _pdfTask(String id, String rank) async {
  final aid = 'p-$id';
  _store
    ..putStaging(aid, 'document.pdf', Uint8List.fromList('%PDF-1.7'.codeUnits))
    ..putStaging(aid, 'screen.jpg', tinyImage);
  final attachment = await _store.commit(
    StagedPdf(
      id: aid,
      byteSize: 2400000,
      pageCount: 12,
      width: 595,
      height: 842,
      originalName: 'Programa.pdf',
    ),
    DateTime.utc(2026, 9, 27),
  );
  final base = sampleTask(id: id, text: 'Programa $id', rank: rank);
  return base.withContent(base.text, attachment, base.updatedAt);
}

Future<Task> _imageTask(String id, String rank) async {
  final attachment = await _store.commit(
    stageImage(_store, 'a-$id'),
    DateTime.utc(2026, 9, 20),
  );
  final base = sampleTask(id: id, text: 'Imagen $id', rank: rank);
  return base.withContent(base.text, attachment, base.updatedAt);
}

Future<Task> _webTask(String id, String rank) async {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: id,
    text: null,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(
      StagedWeb(id: 'w-$id', url: 'https://www.congreso.ejemplo.com/$id'),
      at,
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    _store = MemoryAttachmentStore();
    _web = FakeWebPages();
    taskPdfCalls.clear();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Orden de lectura (CA-014-16)', () {
    testWidgets('CA-014-16: la card es el primer nodo y el resto del orden no '
        'cambia (tarea vertical)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final before = _reading(tester);
      expect(before, contains('Pulsa para completar'));

      await _deleteFromMenu(tester);
      // En el árbol del lector desde el primer fotograma de la card, aunque
      // aún sea transparente.
      final withCard = _reading(tester);
      expect(withCard.first, _cardLabel);
      expect(withCard.where((l) => l == _cardLabel), hasLength(1));

      await tester.pump(const Duration(milliseconds: 400));
      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump(_frame);
      final without = _reading(tester);
      // Sin card, vuelve el botón de completar y todo está como antes.
      expect(without, contains('Pulsa para completar'));
      expect(
        withCard.skip(1),
        without.where((l) => l != 'Pulsa para completar'),
      );
      handle.dispose();
    });

    testWidgets('CA-014-16: en "Todo hecho." la card es la primera y no se '
        'lee "Crear una tarea"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, tasks: ['Primera']);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final withCard = _reading(tester);
      expect(withCard.first, _cardLabel);
      expect(withCard, isNot(contains('Crear una tarea')));

      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump(_frame);
      final without = _reading(tester);
      expect(without, contains('Crear una tarea'));
      expect(withCard.skip(1), without.where((l) => l != 'Crear una tarea'));
      handle.dispose();
    });

    testWidgets('CA-014-16: un solo nodo, papel de botón, sin región en vivo, '
        'con la etiqueta exacta', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final nodes = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => n.label == _cardLabel)
          .toList();
      expect(nodes, hasLength(1));
      final data = nodes.single.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    for (final kind in ['imagen', 'PDF', 'web']) {
      testWidgets('CL-014-7, CA-014-16: en horizontal con $kind, la card es '
          'la primera, el resto del orden no cambia y el $kind acaba encima '
          'de ella', (tester) async {
        final handle = tester.ensureSemantics();
        final make = switch (kind) {
          'imagen' => _imageTask,
          'PDF' => _pdfTask,
          _ => _webTask,
        };
        await _pump(
          tester,
          tasks: const [],
          extra: [await make('a', 'MB'), await make('b', 'MC')],
          screenReader: true,
          size: const Size(844, 390),
        );
        if (kind == 'web') {
          _web.last
            ..started('https://www.congreso.ejemplo.com/a')
            ..finished('https://www.congreso.ejemplo.com/a');
          await tester.pumpAndSettle();
        }
        final label = switch (kind) {
          'imagen' => 'Tarea actual: Imagen a. Con foto',
          'PDF' => 'Tarea actual: Programa a',
          _ => 'Tarea actual: Página web de congreso.ejemplo.com',
        };
        final before = _reading(tester);
        if (kind == 'PDF') {
          taskPdfCalls.last.actions.entries
              .firstWhere((e) => e.key.label == 'Eliminar tarea')
              .value();
        } else {
          _customAction(tester, label, 'Eliminar tarea');
        }
        await tester.pump(_frame);
        await _finishCrumple(tester);
        if (kind == 'web') {
          // La siguiente tarea web: otra página.
          _web.last
            ..started('https://www.congreso.ejemplo.com/b')
            ..finished('https://www.congreso.ejemplo.com/b');
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(_card, findsOneWidget);
        final withCard = _reading(tester);
        expect(withCard.first, startsWith('Deshacer. Tarea eliminada: '));

        // Sin tapar: el PDF y la web acaban encima de la card; la imagen, que
        // es un solo elemento, queda debajo.
        final cardTop = tester.getRect(_card).top;
        final viewer = switch (kind) {
          'PDF' => find.byKey(const Key('fake-task-pdf')),
          'web' => find.byKey(
            const ValueKey('web-view-0'),
            skipOffstage: false,
          ),
          _ => null,
        };
        if (viewer != null) {
          expect(tester.getRect(viewer).bottom, lessThanOrEqualTo(cardTop));
        }

        _container(tester).read(undoProvider.notifier).commit();
        await tester.pump(_frame);
        await tester.pump(const Duration(milliseconds: 100));
        final without = _reading(tester);
        expect(withCard.skip(1), without);
        expect(before.length, without.length);
        handle.dispose();
      });
    }
  });

  group('Foco explícito (CA-014-16, CA-014-20, P-014-3)', () {
    testWidgets('CA-014-16, P-014-3: con lector, el aviso de foco y el foco '
        'de entrada van a la card, aunque hubiera una señal de foco previa y '
        'nada compita', (tester) async {
      final handle = tester.ensureSemantics();
      final events = _listenFocusEvents(tester);
      await _pump(tester, screenReader: true);
      // Una señal previa > 0: el montaje de la pantalla que sale tras el
      // arrugado la pediría sola.
      _container(tester).read(screenFocusProvider.notifier)
        ..signal()
        ..signal();
      await tester.pump();
      await tester.tap(_menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      events.clear();
      await _finishCrumple(tester);
      await tester.pump(const Duration(milliseconds: 400));

      final card = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      expect(events, isNotEmpty);
      expect(events.last, card.id, reason: 'el último aviso es el de la card');
      expect(events.where((id) => id != card.id), isEmpty);
      expect(_focusLabel(), 'undo');
      handle.dispose();
    });

    testWidgets('CA-014-16: en "Todo hecho." también, con una señal previa', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final events = _listenFocusEvents(tester);
      await _pump(tester, tasks: ['Primera'], screenReader: true);
      _container(tester).read(screenFocusProvider.notifier).signal();
      await tester.pump();
      await tester.tap(_menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(_frame);
      events.clear();
      await _finishCrumple(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AllDoneScreen), findsOneWidget);
      final card = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      expect(events.last, card.id);
      expect(events.where((id) => id != card.id), isEmpty);
      expect(_focusLabel(), 'undo');
      handle.dispose();
    });

    testWidgets('CA-014-20: con teclado físico, el foco va a "Deshacer" y el '
        'tiempo se detiene mientras lo tiene', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), 'undo');
      await tester.pump(UnaMotion.undoWindow * 3);
      expect(_card, findsOneWidget, reason: 'el foco del teclado detiene');
      expect(_container(tester).read(undoProvider).cardVisible, isTrue);
    });

    testWidgets('CA-014-17: con TalkBack (exploración táctil) el tiempo no '
        'empieza hasta el primer foco de la card y no corre mientras lo '
        'tiene', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, screenReader: true);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(UnaMotion.undoWindow * 3);
      expect(_card, findsOneWidget);
      expect(_container(tester).read(undoProvider).cardVisible, isTrue);
      handle.dispose();
    });

    testWidgets('CA-014-17: con Switch Access (`accessibleNavigation` true '
        'pero sin exploración táctil) no cuenta como lector: no se pide el '
        'foco de entrada y la card caduca a los 4 s sin foco', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, screenReader: true, touchExploration: false);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_card, findsOneWidget);
      expect(_focusLabel(), isNot('undo'));
      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
      handle.dispose();
    });

    testWidgets('CA-014-20: con la pantalla táctil y sin lector, el foco no '
        'se mueve a "Deshacer" y el tiempo corre', (tester) async {
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), isNot('undo'));
      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
    });

    testWidgets('CA-014-05: con teclado, Tab no llega al botón oculto', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(_frame);
        final context = FocusManager.instance.primaryFocus?.context;
        expect(
          context?.findAncestorWidgetOfExactType<HoldToCompleteButton>(),
          isNull,
        );
      }
    });
  });

  group('Geometría (CA-014-05, WCAG 2.4.11)', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'CA-014-05: la nota acaba encima de la card (texto ×$scale)',
        (tester) async {
          await _pump(
            tester,
            textScale: scale,
            size: const Size(360, 800),
            bottomInset: 24,
          );
          final noteBefore = tester.getRect(
            find.byType(SingleChildScrollView).first,
          );
          await _deleteFromMenu(tester);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          final cardTop = tester.getRect(_card).top;
          final note = tester.getRect(find.byType(SingleChildScrollView).first);
          expect(note.bottom, lessThanOrEqualTo(cardTop + 0.01));
          // Con la card, el sitio del botón crece como mucho lo que haga falta.
          expect(note.bottom, lessThanOrEqualTo(noteBefore.bottom));
          // La card llega al borde de abajo.
          expect(tester.getRect(_card).bottom, 800);
        },
      );

      testWidgets('CA-014-05: en "Todo hecho." el título acaba encima de la '
          'card (texto ×$scale)', (tester) async {
        await _pump(
          tester,
          tasks: ['Primera'],
          textScale: scale,
          size: const Size(360, 800),
          bottomInset: 24,
        );
        await _deleteFromMenu(tester);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        final cardTop = tester.getRect(_card).top;
        final body = tester.getRect(find.text('Todo').first);
        expect(body.bottom, lessThanOrEqualTo(cardTop));
      });
    }
  });

  group('Guías de Flutter con la card a la vista (spec 014 §6)', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('CA-014-03: objetivos táctiles y etiquetas, en la pantalla '
          'principal (texto ×$scale)', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, textScale: scale, size: const Size(360, 800));
        await _deleteFromMenu(tester);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(_card, findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('CA-014-03: objetivos táctiles y etiquetas, en "Todo hecho."', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, tasks: ['Primera'], size: const Size(360, 800));
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_card, findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Deshacer: foco y anuncio (CA-014-18, CA-014-20, CA-014-23)', () {
    final undoButton = find.descendant(
      of: _card,
      matching: find.byKey(UndoCard.buttonKey),
    );

    bool onTask(WidgetTester tester) =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<CurrentTaskScreen>() !=
        null;

    testWidgets('CA-014-18: con lector, un solo aviso de foco a la tarea '
        'recuperada, el foco de entrada en ella y un anuncio único', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final announcements = <String>[];
      final events = _listenFocusEvents(tester, announcements: announcements);
      await _pump(tester, screenReader: true);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), 'undo');
      events.clear();

      // Con el lector se activa el nodo de la card.
      final card = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      card.owner!.performAction(card.id, SemanticsAction.tap);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(_card, findsNothing);

      final task = tester.getSemantics(
        find.bySemanticsLabel('Tarea actual: Primera'),
      );
      expect(events, isNotEmpty);
      expect(events.toSet(), {
        task.id,
      }, reason: 'un solo aviso de foco, al nodo de la tarea');
      expect(onTask(tester), isTrue);
      // El anuncio llega cuando la pantalla ya se ve, y es uno.
      expect(announcements, isEmpty);
      await tester.pump(UnaMotion.sheetOut + _frame);
      expect(announcements, ['Tarea recuperada']);
      handle.dispose();
    });

    testWidgets('CA-014-18, CA-014-20: con teclado, el foco queda en la tarea '
        'recuperada y no en el botón', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), 'undo');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(_card, findsNothing);
      expect(find.text('Primera'), findsOneWidget);
      expect(onTask(tester), isTrue);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<HoldToCompleteButton>(),
        isNull,
      );
      await tester.pump(UnaMotion.sheetOut * 2);
    });

    testWidgets('CA-014-18: desde "Todo hecho." vuelve la tarea con el foco '
        'en ella', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, tasks: ['Primera'], screenReader: true);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AllDoneScreen), findsOneWidget);
      final card = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      card.owner!.performAction(card.id, SemanticsAction.tap);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(find.byType(AllDoneScreen), findsNothing);
      expect(onTask(tester), isTrue);
      await tester.pump(UnaMotion.sheetOut * 2);
      handle.dispose();
    });

    testWidgets('CA-014-20: si la card desaparece sin deshacer con el foco '
        'del teclado en ella, el foco va a la tarea', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), 'undo');

      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump();
      await tester.pump(_frame);
      expect(_card, findsNothing);
      expect(onTask(tester), isTrue);
    });

    testWidgets('CA-014-20: lo mismo en "Todo hecho.": el foco va al título', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await _pump(tester, tasks: ['Primera']);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_focusLabel(), 'undo');

      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump();
      await tester.pump(_frame);
      expect(_card, findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<AllDoneScreen>(),
        isNotNull,
      );
    });

    testWidgets('CA-014-23: el aviso de error lleva el foco de teclado y el '
        'aviso de foco del lector a "Reintentar"', (tester) async {
      final handle = tester.ensureSemantics();
      final events = _listenFocusEvents(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final repo = await _pump(tester, screenReader: true);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      repo.failInsert = true;
      events.clear();

      await tester.tap(undoButton);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Reintentar'), findsOneWidget);
      final retry = tester.getSemantics(find.bySemanticsLabel('Reintentar'));
      expect(events, isNotEmpty);
      expect(events.last, retry.id);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      expect(
        focus!.context!.findAncestorWidgetOfExactType<TextButton>(),
        isNotNull,
        reason: 'el foco de entrada está en "Reintentar"',
      );
      _container(tester).read(undoProvider.notifier).commit();
      await tester.pump();
      handle.dispose();
    });
  });

  group('Girar con la card (CL-014-8, CA-014-12)', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('CL-014-8: al girar, la card conserva su nodo y la cuenta '
          'no se reinicia (texto ×$scale)', (tester) async {
        final handle = tester.ensureSemantics();
        addTearDown(tester.view.reset);
        await _pump(tester, textScale: scale, size: const Size(390, 844));
        await _deleteFromMenu(tester);
        await tester.pump(const Duration(milliseconds: 400));
        final before = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
        final state = tester.state(_card);

        await tester.pump(const Duration(seconds: 2));
        tester.view.physicalSize = const Size(844, 390);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final after = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
        expect(after.id, before.id);
        expect(tester.state(_card), same(state));

        // Pasaron 2,4 s: la cuenta sigue, no empieza de nuevo.
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pump();
        expect(_card, findsNothing);
        handle.dispose();
      });
    }

    testWidgets('CL-014-8: con el foco del lector en la card, al girar lo '
        'conserva y el tiempo sigue parado', (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(tester.view.reset);
      await _pump(tester, screenReader: true);
      await _deleteFromMenu(tester);
      await tester.pump(const Duration(milliseconds: 400));
      var node = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      node.owner!.performAction(
        node.id,
        SemanticsAction.didGainAccessibilityFocus,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(_card, findsOneWidget);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      node = tester.getSemantics(find.bySemanticsLabel(_cardLabel));
      expect(_card, findsOneWidget);

      node.owner!.performAction(
        node.id,
        SemanticsAction.didLoseAccessibilityFocus,
      );
      await tester.pump(UnaMotion.undoWindow);
      await tester.pump();
      expect(_card, findsNothing);
      handle.dispose();
    });
  });
}
