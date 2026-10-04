import 'dart:ui' show Tristate;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/delete/undo_card_host.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import '../../support/pump_app.dart' show sampleTask;
import '../../support/undo.dart';

const _es = Locale('es');
const _en = Locale('en');

/// Lo que la card ha avisado.
class _Calls {
  int undos = 0;
  final shown = <(int, bool)>[];
  final focus = <(int, UndoFocus, bool)>[];
  final readers = <bool>[];
}

/// La card sola, abajo del todo, como la pone su sitio. Volver a llamarla con
/// otros valores actualiza la misma card (no la vuelve a montar).
Future<_Calls> _pump(
  WidgetTester tester, {
  _Calls? calls,
  Task? task,
  int serial = 1,
  double Function()? fraction,
  Locale locale = _es,
  double textScale = 1,
  Size size = const Size(360, 640),
  EdgeInsets padding = EdgeInsets.zero,
  bool reduced = false,
  bool screenReader = false,
  FocusNode? focusNode,
  Widget Function(Widget card)? wrap,
}) async {
  final c = calls ?? _Calls();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final card = UndoCard(
    task: task ?? sampleTask(),
    serial: serial,
    fraction: fraction ?? () => 1,
    onUndo: () => c.undos++,
    onShown: (s, {required screenReader}) => c.shown.add((s, screenReader)),
    onFocusChanged: (s, source, {required focused}) =>
        c.focus.add((s, source, focused)),
    onScreenReaderChanged: ({required enabled}) => c.readers.add(enabled),
    focusNode: focusNode,
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: UnaTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewPadding: padding,
          disableAnimations: reduced,
          accessibleNavigation: screenReader,
        ),
        child: child!,
      ),
      home: ColoredBox(
        color: UnaColors.paper,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: wrap == null ? card : wrap(card),
            ),
          ],
        ),
      ),
    ),
  );
  return c;
}

Finder get _card => find.byType(UndoCard);
Finder get _button => find.byKey(UndoCard.buttonKey);
Finder get _bar => find.byKey(UndoCard.barKey);

Finder _icon(UnaIconData data) => find.descendant(
  of: _card,
  matching: find.byWidgetPredicate((w) => w is UnaIcon && w.icon == data),
);

Text _text(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

SemanticsNode _node(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label));

void _act(WidgetTester tester, String label, SemanticsAction action) {
  final node = _node(tester, label);
  node.owner!.performAction(node.id, action);
}

Task _photoTask() => Task(
  id: 'p1',
  text: null,
  status: TaskStatus.pending,
  rank: 'V',
  colorKey: 3,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
  attachment: Attachment(
    id: 'img-p1',
    kind: AttachmentKind.image,
    origin: AttachmentOrigin.camera,
    mime: 'image/jpeg',
    byteSize: 10,
    width: 4,
    height: 3,
    createdAt: DateTime.utc(2026, 10, 1),
  ),
);

void main() {
  setUpAll(loadAppFonts);
  setUp(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  group('Aspecto (CA-014-03, CA-014-04)', () {
    testWidgets('CA-014-03: medidas y colores del prototipo (tablero 12)', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(UnaMotion.undoEnter);

      // Franja negra a todo el ancho, pegada abajo: 112 + barra de 6.
      final card = tester.getRect(_card);
      expect(card, const Rect.fromLTWH(0, 640.0 - 118, 360, 118));
      final ink = find.descendant(
        of: _card,
        matching: find.byWidgetPredicate(
          (w) => w is Material && w.color == UnaColors.ink,
        ),
      );
      expect(tester.getRect(ink.first), card);
      expect(
        tester.getSize(find.byKey(UndoCard.contentKey)).height,
        UnaSizes.undoCard,
      );

      // Papelera de 22, a 24 del borde; título y etiqueta 14 más allá.
      final trash = tester.getRect(_icon(UnaIcons.trash));
      expect(trash.left, UnaSpace.l);
      expect(trash.size, const Size.square(UnaSizes.icon));
      final trashIcon = tester.widget<UnaIcon>(_icon(UnaIcons.trash));
      expect(trashIcon.color, UnaColors.onInk);
      expect(trashIcon.strokeWidth, UnaSizes.iconStroke);
      final title = tester.getRect(find.text('Tarea eliminada'));
      expect(title.left, trash.right + UnaSizes.undoGap);
      final label = tester.getRect(find.text('Llamar a Marta'));
      expect(label.left, title.left);
      expect(label.top, title.bottom + UnaSizes.undoTextGap);

      final titleStyle = _text(tester, 'Tarea eliminada').style!;
      expect(titleStyle.fontFamily, UnaFonts.display);
      expect(titleStyle.fontSize, UnaFontSizes.body);
      expect(titleStyle.fontWeight, UnaFontWeights.extrabold);
      expect(titleStyle.color, UnaColors.onInk);
      final labelText = _text(tester, 'Llamar a Marta');
      expect(labelText.style!.fontFamily, UnaFonts.mono);
      expect(labelText.style!.fontSize, UnaFontSizes.micro);
      expect(labelText.style!.color, UnaColors.onInkMuted);
      expect(labelText.maxLines, 1);
      expect(labelText.overflow, TextOverflow.ellipsis);

      // "Deshacer": 44 de alto, a 20 del borde derecho, centrado en los 112,
      // borde blanco de 2, icono de 18 con trazo 2,8 y texto 15/800.
      final button = tester.getRect(_button);
      expect(button.height, UnaSizes.undoButton);
      expect(button.right, 360 - UnaSpace.ml);
      expect(button.center.dy, card.top + UnaSizes.undoCard / 2);
      final box =
          tester.widget<DecoratedBox>(_button).decoration as BoxDecoration;
      expect(
        box.border,
        Border.all(color: UnaColors.onInk, width: UnaBorders.undoButtonWidth),
      );
      expect(box.color, isNull, reason: 'fondo transparente');
      final undoIcon = tester.widget<UnaIcon>(_icon(UnaIcons.arrowUTurnLeft));
      expect(undoIcon.size, UnaSizes.undoIcon);
      expect(undoIcon.strokeWidth, UnaSizes.undoIconStroke);
      expect(undoIcon.color, UnaColors.onInk);
      final iconRect = tester.getRect(_icon(UnaIcons.arrowUTurnLeft));
      expect(
        iconRect.left,
        button.left + UnaBorders.undoButtonWidth + UnaSizes.undoButtonPadX,
      );
      final undoText = tester.getRect(find.text('Deshacer'));
      expect(undoText.left, iconRect.right + UnaSpace.s);
      expect(button.left, greaterThanOrEqualTo(title.right + UnaSizes.undoGap));
      final buttonStyle = _text(tester, 'Deshacer').style!;
      expect(buttonStyle.fontSize, UnaFontSizes.bodyS);
      expect(buttonStyle.fontWeight, UnaFontWeights.extrabold);
      expect(buttonStyle.color, UnaColors.onInk);

      // Barra de 6 abajo del todo, a todo el ancho.
      expect(tester.getRect(_bar), const Rect.fromLTWH(0, 640.0 - 6, 360, 6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA-014-03: al pulsar, "Deshacer" baja 2 px en diagonal', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(UnaMotion.undoEnter);
      final before = tester.getRect(_button);
      final gesture = await tester.startGesture(before.center);
      await tester.pump();
      expect(
        tester.getRect(_button).topLeft,
        before.topLeft +
            const Offset(UnaSizes.undoButtonPress, UnaSizes.undoButtonPress),
      );
      await gesture.up();
      await tester.pump();
      expect(tester.getRect(_button), before);
    });

    testWidgets('CA-014-04, CL-014-5: la etiqueta va en una línea con "…", '
        'sin saltos de línea, y el lector la lee completa', (tester) async {
      final handle = tester.ensureSemantics();
      final long = List.filled(10000, 'a').join();
      await _pump(tester, task: sampleTask(text: 'Comprar\npan\n\n$long'));
      await tester.pump(UnaMotion.undoEnter);
      final shown = 'Comprar pan $long';
      expect(find.text(shown), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(shown));
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(
        tester.getSize(find.text(shown)).height,
        lessThan(UnaFontSizes.micro * 2),
        reason: 'una sola línea',
      );
      expect(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: $shown'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
      'CA-014-04: sin texto, la etiqueta de la confirmación ("Foto")',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, task: _photoTask());
        expect(find.text('Foto'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Deshacer. Tarea eliminada: Foto'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('CL-014-6: con escala de texto ≥ 1,3, la etiqueta puede ocupar '
        'dos líneas; por debajo, una', (tester) async {
      final long = List.filled(30, 'palabra').join(' ');
      await _pump(tester, task: sampleTask(text: long), textScale: 1.2);
      expect(_text(tester, long).maxLines, 1);
      await _pump(tester, task: sampleTask(text: long), textScale: 1.3);
      expect(_text(tester, long).maxLines, 2);
      expect(_text(tester, long).overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Barra de tiempo (CA-014-03, CA-014-21)', () {
    for (final reduced in [false, true]) {
      testWidgets('CA-014-03${reduced ? ', CA-014-21' : ''}: se vacía de '
          'derecha a izquierda con la fracción, del color de la nota, sobre '
          'la pista${reduced ? ' (con reducir movimiento)' : ''}', (
        tester,
      ) async {
        var fraction = 1.0;
        await _pump(
          tester,
          task: sampleTask(colorKey: 2),
          fraction: () => fraction,
          reduced: reduced,
        );
        final note = UnaPalettes.classic[2];
        expect(
          find.byKey(UndoCard.barKey),
          paints
            ..rect(
              rect: const Rect.fromLTWH(0, 0, 360, 6),
              color: UnaColors.undoTrack,
            )
            ..rect(rect: const Rect.fromLTWH(0, 0, 360, 6), color: note),
        );
        // Lineal: lo que diga el controlador, en cada fotograma.
        for (final f in [0.75, 0.5, 0.1]) {
          fraction = f;
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            find.byKey(UndoCard.barKey),
            paints
              ..rect(color: UnaColors.undoTrack)
              ..rect(rect: Rect.fromLTWH(0, 0, 360 * f, 6), color: note),
          );
        }
        expect(
          find.ancestor(of: _bar, matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );
      });
    }
  });

  group('Entrada (CA-014-03, CA-014-21)', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(of: _card, matching: find.byType(FadeTransition)),
        )
        .opacity
        .value;
    double shift(WidgetTester tester) =>
        tester.getRect(find.byKey(UndoCard.contentKey)).top - (640.0 - 118);

    testWidgets('CA-014-03: entra subiendo 24 px y fundiéndose en 0,22 s, '
        'y está en el árbol del lector desde el primer fotograma', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(opacity(tester), 0);
      expect(shift(tester), UnaSizes.undoEnterOffset);
      expect(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: Llamar a Marta'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FadeTransition>(
              find.descendant(of: _card, matching: find.byType(FadeTransition)),
            )
            .alwaysIncludeSemantics,
        isTrue,
      );
      await tester.pump(UnaMotion.undoEnter ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(shift(tester), inExclusiveRange(0, UnaSizes.undoEnterOffset));
      await tester.pump(UnaMotion.undoEnter ~/ 2);
      expect(opacity(tester), 1);
      expect(shift(tester), 0);
      handle.dispose();
    });

    testWidgets('CA-014-21: con reducir movimiento, solo el fundido', (
      tester,
    ) async {
      await _pump(tester, reduced: true);
      expect(opacity(tester), 0);
      expect(shift(tester), 0);
      await tester.pump(UnaMotion.undoEnter ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(shift(tester), 0);
      await tester.pump(UnaMotion.undoEnter ~/ 2);
      expect(opacity(tester), 1);
    });

    testWidgets('CA-014-21: "Quitar animaciones" del sistema no acorta la '
        'entrada (sin desplazamiento)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, reduced: true);
      // Acortada 20 veces duraría 11 ms.
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(shift(tester), 0);
      await tester.pump(UnaMotion.undoEnter);
      expect(opacity(tester), 1);
    });

    testWidgets('CA-014-08: con otra serie, la misma card cambia de texto y '
        'de color sin volver a entrar, con un nodo del lector nuevo y sin '
        'perder el foco del teclado', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      var fraction = 0.3;
      final calls = await _pump(
        tester,
        focusNode: node,
        fraction: () => fraction,
      );
      await tester.pump(UnaMotion.undoEnter);
      node.requestFocus();
      await tester.pump();
      final state = tester.state(_card);
      final before = _node(tester, 'Deshacer. Tarea eliminada: Llamar a Marta');
      fraction = 1;
      await _pump(
        tester,
        calls: calls,
        task: sampleTask(text: 'Comprar pan', colorKey: 4),
        serial: 2,
        focusNode: node,
        fraction: () => fraction,
      );
      expect(tester.state(_card), same(state));
      expect(opacity(tester), 1);
      expect(shift(tester), 0);
      expect(find.text('Comprar pan'), findsOneWidget);
      final after = _node(tester, 'Deshacer. Tarea eliminada: Comprar pan');
      expect(after.id, isNot(before.id));
      expect(
        find.bySemanticsLabel('Deshacer. Tarea eliminada: Llamar a Marta'),
        findsNothing,
      );
      expect(node.hasFocus, isTrue);
      expect(
        find.byKey(UndoCard.barKey),
        paints
          ..rect(color: UnaColors.undoTrack)
          ..rect(
            rect: const Rect.fromLTWH(0, 0, 360, 6),
            color: UnaPalettes.classic[4],
          ),
      );
      handle.dispose();
    });
  });

  group('Lector (CA-014-16, CA-014-17)', () {
    const label = 'Deshacer. Tarea eliminada: Llamar a Marta';

    testWidgets('CA-014-16: un solo nodo con papel de botón, la etiqueta '
        'exacta, sin región en vivo y la clave de orden que le pasan', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        wrap: (card) => Semantics(
          sortKey: const OrdinalSortKey(0),
          explicitChildNodes: true,
          child: card,
        ),
      );
      final node = _node(tester, label);
      final data = node.getSemanticsData();
      expect(data.label, label);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isLiveRegion, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(node.childrenCount, 0, reason: 'nada más dentro');
      // Ninguna otra parte de la card llega al lector.
      for (final text in ['Tarea eliminada', 'Llamar a Marta', 'Deshacer']) {
        expect(find.bySemanticsLabel(text), findsNothing, reason: text);
      }
      handle.dispose();
    });

    testWidgets('CA-014-16: lleva la clave de orden que le pasa quien la '
        'monta', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: _es,
          home: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Semantics(
                  sortKey: const OrdinalSortKey(1),
                  child: const Text('Arriba'),
                ),
                UndoCard(
                  task: sampleTask(),
                  serial: 1,
                  fraction: () => 1,
                  onUndo: () {},
                  onShown: (_, {required screenReader}) {},
                  onFocusChanged: (_, _, {required focused}) {},
                  sortKey: const OrdinalSortKey(0),
                ),
              ],
            ),
          ),
        ),
      );
      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .where((l) => l.isNotEmpty)
          .toList();
      expect(labels, [label, 'Arriba']);
      handle.dispose();
    });

    testWidgets('CA-014-17: el foco del lector entra y sale (con su serie)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final calls = await _pump(tester, serial: 7);
      _act(tester, label, SemanticsAction.didGainAccessibilityFocus);
      _act(tester, label, SemanticsAction.didLoseAccessibilityFocus);
      expect(calls.focus, [
        (7, UndoFocus.reader, true),
        (7, UndoFocus.reader, false),
      ]);
      handle.dispose();
    });

    testWidgets('CA-014-18: el doble toque del lector la activa', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final calls = await _pump(tester);
      _act(tester, label, SemanticsAction.tap);
      expect(calls.undos, 1);
      handle.dispose();
    });

    testWidgets('CA-014-17: avisa de que se ha dibujado tras su primer '
        'fotograma, una vez por serie, con el lector o sin él', (tester) async {
      final calls = await _pump(tester, serial: 3, screenReader: true);
      expect(calls.shown, [(3, true)]);
      await tester.pump(UnaMotion.undoEnter);
      expect(calls.shown, [(3, true)]);
      await _pump(tester, calls: calls, serial: 4, screenReader: true);
      expect(calls.shown, [(3, true), (4, true)]);
      final other = await _pump(tester, task: sampleTask(id: 'x'), serial: 4);
      expect(other.shown, isEmpty, reason: 'la misma serie no vuelve a avisar');
    });

    testWidgets('CA-014-17: si el lector se apaga con la card a la vista, lo '
        'dice', (tester) async {
      final calls = await _pump(tester, screenReader: true);
      await _pump(tester, calls: calls, screenReader: false);
      expect(calls.readers, [false]);
    });
  });

  group('Teclado y toque (CA-014-20, CL-014-3)', () {
    testWidgets('CA-014-20: Tab llega a "Deshacer", se ve su anillo y el nodo '
        'dice que tiene el foco; avisa del foco del teclado', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      final calls = await _pump(tester, serial: 5, focusNode: node);
      await tester.pump(UnaMotion.undoEnter);
      FocusRing ring() => tester.widget<FocusRing>(
        find.descendant(of: _card, matching: find.byType(FocusRing)),
      );
      expect(ring().visible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(ring().visible, isTrue);
      final data = _node(
        tester,
        'Deshacer. Tarea eliminada: Llamar a Marta',
      ).getSemanticsData();
      expect(data.flagsCollection.isFocused, Tristate.isTrue);
      expect(calls.focus, [(5, UndoFocus.keyboard, true)]);
      node.unfocus();
      await tester.pump();
      expect(calls.focus.last, (5, UndoFocus.keyboard, false));
      handle.dispose();
    });

    testWidgets('CA-014-20, CL-014-3: Intro y Espacio la activan una vez; '
        'Intro mantenido, también una', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final calls = await _pump(tester, focusNode: node);
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls.undos, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(calls.undos, 2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(calls.undos, 3);
    });

    testWidgets('CA-014-20: Escape no hace nada y no se propaga (en Android '
        'volvería como ATRÁS)', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var escaped = 0;
      final calls = await _pump(
        tester,
        focusNode: node,
        wrap: (card) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => escaped++,
          },
          child: card,
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue);
      expect(escaped, 0);
      expect(calls.undos, 0);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('CA-014-03: zona táctil de 48 dp: un toque en su borde, fuera '
        'de los 44 visibles, la activa; fuera de la zona, no', (tester) async {
      final calls = await _pump(tester);
      await tester.pump(UnaMotion.undoEnter);
      final button = tester.getRect(_button);
      const extra = (kMinInteractiveDimension - UnaSizes.undoButton) / 2;
      await tester.tapAt(Offset(button.center.dx, button.top - extra + 0.5));
      await tester.tapAt(Offset(button.center.dx, button.bottom + extra - 0.5));
      expect(calls.undos, 2);
      await tester.tapAt(Offset(button.center.dx, button.top - extra - 1));
      await tester.tapAt(tester.getCenter(find.text('Tarea eliminada')));
      expect(calls.undos, 2);
    });
  });

  group('Texto grande y márgenes (CL-014-6, CL-014-7, CA-014-20)', () {
    /// El anillo de foco (9 px alrededor del botón) cabe en la card, sin
    /// recorte y sin tocar la barra.
    void expectRingRoom(WidgetTester tester) {
      final ring = tester.getRect(_button).inflate(UnaBorders.focusWidth * 3);
      final content = tester.getRect(find.byKey(UndoCard.contentKey));
      expect(content.contains(ring.topLeft), isTrue, reason: '$ring $content');
      expect(
        content.contains(ring.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: '$ring $content',
      );
      expect(
        find.ancestor(
          of: _button,
          matching: find.byWidgetPredicate(
            (w) => w is ClipRect || w is ClipRRect || w is ClipPath,
          ),
        ),
        findsNothing,
      );
    }

    testWidgets('CA-014-20: el anillo de foco tiene 9 px libres a ×1,0', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(UnaMotion.undoEnter);
      expectRingRoom(tester);
    });

    for (final locale in [_es, _en]) {
      testWidgets('CL-014-6: al 200 % a 360 dp (${locale.languageCode}), '
          '"Deshacer" pasa debajo, entero, sin desbordes; etiqueta en dos '
          'líneas', (tester) async {
        final long = List.filled(20, 'palabra').join(' ');
        await _pump(
          tester,
          task: sampleTask(text: long),
          textScale: 2,
          locale: locale,
        );
        await tester.pump(UnaMotion.undoEnter);
        expect(tester.takeException(), isNull);
        final title = locale == _es ? 'Tarea eliminada' : 'Task deleted';
        final undo = locale == _es ? 'Deshacer' : 'Undo';
        final titleRect = tester.getRect(find.text(title));
        final labelRect = tester.getRect(find.text(long));
        final button = tester.getRect(_button);
        expect(button.top, greaterThanOrEqualTo(labelRect.bottom));
        expect(button.right, lessThanOrEqualTo(360 - UnaSpace.ml));
        expect(button.left, greaterThanOrEqualTo(0));
        expect(_text(tester, long).maxLines, 2);
        expect(titleRect.height, lessThan(UnaFontSizes.body * 2 * 1.6));
        final undoParagraph = tester.renderObject<RenderParagraph>(
          find.text(undo),
        );
        expect(undoParagraph.didExceedMaxLines, isFalse);
        expect(
          undoParagraph.getMinIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(undoParagraph.size.width + 0.01),
        );
        expect(button.top, greaterThanOrEqualTo(tester.getRect(_card).top));
        expect(tester.getRect(_bar).top, greaterThanOrEqualTo(button.bottom));
        expectRingRoom(tester);
      });
    }

    testWidgets('CL-014-6: a ×1,0 en 360 dp, "Deshacer" va al lado del texto', (
      tester,
    ) async {
      await _pump(tester, locale: _en);
      final button = tester.getRect(_button);
      final title = tester.getRect(find.text('Task deleted'));
      expect(button.left, greaterThan(title.right));
      expect(
        button.center.dy,
        closeTo(tester.getRect(find.byKey(UndoCard.contentKey)).center.dy, 0.5),
      );
    });

    testWidgets('CL-014-7: en horizontal, al 200 % y con la barra de 3 botones '
        'y el recorte de la cámara a los lados, "Deshacer" sigue al lado del '
        'texto', (tester) async {
      await _pump(
        tester,
        size: const Size(640, 360),
        textScale: 2,
        padding: const EdgeInsets.only(left: 48, right: 32),
      );
      await tester.pump(UnaMotion.undoEnter);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(_button);
      final title = tester.getRect(find.text('Tarea eliminada'));
      expect(button.left, greaterThanOrEqualTo(title.right));
      expect(button.top, lessThan(title.bottom));
      expectRingRoom(tester);
    });

    testWidgets('P-014-2: márgenes del sistema: el negro llega a los bordes, '
        'el contenido queda dentro y la barra, encima del margen inferior', (
      tester,
    ) async {
      const padding = EdgeInsets.only(left: 30, right: 48, bottom: 24);
      await _pump(tester, size: const Size(640, 360), padding: padding);
      await tester.pump(UnaMotion.undoEnter);
      final card = tester.getRect(_card);
      expect(card.left, 0);
      expect(card.right, 640);
      expect(card.bottom, 360);
      expect(card.height, 118 + padding.bottom);
      final trash = tester.getRect(_icon(UnaIcons.trash));
      expect(trash.left, padding.left + UnaSpace.l);
      expect(tester.getRect(_button).right, 640 - padding.right - UnaSpace.ml);
      final bar = tester.getRect(_bar);
      expect(bar.bottom, 360 - padding.bottom);
      expect(bar.left, padding.left);
      expect(bar.right, 640 - padding.right);
    });
  });

  group('Su sitio (UndoCardHost)', () {
    Future<ProviderContainer> pumpHost(
      WidgetTester tester, {
      UndoHost host = UndoHost.home,
      bool ticking = true,
    }) async {
      final repo = InMemoryTaskRepository();
      final store = MemoryAttachmentStore();
      await repo.insert(sampleTask(id: 'a', text: 'Primera', rank: 'M'));
      await repo.insert(sampleTask(id: 'b', text: 'Segunda', rank: 'N'));
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(repo),
            attachmentStoreProvider.overrideWithValue(store),
            clockProvider.overrideWithValue(TesterClock(tester)),
            accessibilityTimeoutsProvider.overrideWithValue(
              FakeAccessibilityTimeouts(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _es,
            home: TickerMode(
              enabled: ticking,
              child: UndoCardHost(
                host: host,
                child: Builder(
                  builder: (context) {
                    final scope = UndoCardScope.of(context);
                    return Column(
                      children: [
                        const Text('Pantalla'),
                        Text('card ${scope.visible} ${scope.height}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      return ProviderScope.containerOf(tester.element(find.text('Pantalla')));
    }

    /// Elimina "Segunda" desde el listado: la card se ve ya.
    Future<void> deleteB(ProviderContainer container) async {
      final undo = container.read(undoProvider.notifier);
      final epoch = undo.epoch;
      final deleted =
          (await container.read(deletePendingTaskProvider).call('b')).deleted;
      undo.hold(deleted, host: UndoHost.list, epoch: epoch);
    }

    testWidgets('CA-014-07: solo se ve en la pantalla de su eliminación', (
      tester,
    ) async {
      final container = await pumpHost(tester, host: UndoHost.home);
      await deleteB(container);
      await tester.pump();
      expect(container.read(undoProvider).cardVisible, isTrue);
      expect(find.byType(UndoCard), findsNothing);
      expect(find.text('card false 0.0'), findsOneWidget);
    });

    testWidgets('CA-014-03: sin "TickerMode" (la pantalla que sale) no se '
        'dibuja', (tester) async {
      final container = await pumpHost(
        tester,
        host: UndoHost.list,
        ticking: false,
      );
      await deleteB(container);
      await tester.pump();
      expect(find.byType(UndoCard), findsNothing);
    });

    testWidgets('CA-014-05, CA-014-16, CA-014-06: abajo, primera para el '
        'lector; publica su alto; con el tiempo, desaparece', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await pumpHost(tester, host: UndoHost.list);
      await deleteB(container);
      await tester.pump();
      expect(find.byType(UndoCard), findsOneWidget);
      expect(tester.getRect(find.byType(UndoCard)).bottom, 640);
      await tester.pump();
      expect(find.text('card true 118.0'), findsOneWidget);
      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .where((l) => l.isNotEmpty)
          .toList();
      expect(labels, [
        'Deshacer. Tarea eliminada: Segunda',
        'Pantalla',
        'card true 118.0',
      ]);
      // La cuenta empieza tras el primer fotograma de la card.
      await tester.pump(UnaMotion.undoWindow);
      expect(container.read(undoProvider).phase, UndoPhase.none);
      await tester.pump();
      expect(find.byType(UndoCard), findsNothing);
      expect(find.text('card false 0.0'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CA-014-17: con el foco del lector en la card, el tiempo no '
        'corre', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await pumpHost(tester, host: UndoHost.list);
      await deleteB(container);
      await tester.pump();
      _act(
        tester,
        'Deshacer. Tarea eliminada: Segunda',
        SemanticsAction.didGainAccessibilityFocus,
      );
      await tester.pump(UnaMotion.undoWindow * 2);
      expect(container.read(undoProvider).cardVisible, isTrue);
      _act(
        tester,
        'Deshacer. Tarea eliminada: Segunda',
        SemanticsAction.didLoseAccessibilityFocus,
      );
      await tester.pump(UnaMotion.undoWindow);
      expect(container.read(undoProvider).phase, UndoPhase.none);
      handle.dispose();
    });

    testWidgets('CA-014-09: "Deshacer" recupera la tarea (pasados 350 ms)', (
      tester,
    ) async {
      final container = await pumpHost(tester, host: UndoHost.list);
      await deleteB(container);
      await tester.pump(UnaMotion.doubleTapWindow);
      await tester.tap(find.byKey(UndoCard.buttonKey));
      await tester.pump();
      expect(container.read(undoProvider).phase, UndoPhase.none);
      final restored = await container
          .read(taskRepositoryProvider)
          .findById('b');
      expect(restored?.text, 'Segunda');
      expect(find.byType(UndoCard), findsNothing);
    });
  });
}
