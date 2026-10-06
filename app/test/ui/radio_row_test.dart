import 'dart:ui' show CheckedState, Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/radio_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';
import '../support/semantics_stops.dart';

Widget _page({
  String selected = 'system',
  void Function(String)? onPick,
  FocusNode? focusNode,
}) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El título "Idioma" es lo único que nombra el grupo.
          Semantics(header: true, child: const Text('Idioma')),
          UnaRadioGroup(
            child: Column(
              children: [
                UnaRadioRow(
                  label: 'Como el sistema',
                  subtitle: 'Español',
                  selected: selected == 'system',
                  onTap: () => onPick?.call('system'),
                  focusNode: focusNode,
                ),
                UnaRadioRow(
                  label: 'Español',
                  divider: true,
                  selected: selected == 'es',
                  onTap: () => onPick?.call('es'),
                ),
                UnaRadioRow(
                  label: 'English',
                  divider: true,
                  selected: selected == 'en',
                  onTap: () => onPick?.call('en'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-07: cada opción es un botón de radio con "checked" y '
      'dentro de un grupo de selección única', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _page(selected: 'es'));
    final system = tester
        .getSemantics(find.bySemanticsLabel('Como el sistema, Español'))
        .getSemanticsData();
    final es = tester
        .getSemantics(find.bySemanticsLabel('Español').last)
        .getSemanticsData();
    final en = tester
        .getSemantics(find.bySemanticsLabel('English'))
        .getSemanticsData();
    for (final node in [system, es, en]) {
      expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(node.flagsCollection.isChecked, isNot(CheckedState.none));
      expect(node.hasAction(SemanticsAction.tap), isTrue);
    }
    expect(system.flagsCollection.isChecked, CheckedState.isFalse);
    expect(es.flagsCollection.isChecked, CheckedState.isTrue);
    expect(en.flagsCollection.isChecked, CheckedState.isFalse);
    // Es "checked", no "selected" (CA-015-07).
    expect(es.flagsCollection.isSelected, Tristate.none);
    handle.dispose();
  });

  testWidgets('CA-015-07: el grupo no añade ninguna parada con nombre ni sin '
      'él entre el título y la primera opción', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _page());
    expectNoUnnamedSemanticsStops(tester);

    // Paradas del lector: nodos con acción de tocar o con "enfocable".
    final root = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    final stops = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (!node.isMergedIntoParent &&
          !node.isInvisible &&
          (data.hasAction(SemanticsAction.tap) ||
              data.flagsCollection.isButton)) {
        stops.add(data.label);
      }
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(root);
    expect(stops, ['Como el sistema, Español', 'Español', 'English']);
    handle.dispose();
  });

  testWidgets('CA-015-07: el grupo lleva el rol de grupo de botones de radio '
      'y ninguna etiqueta propia', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _page());
    final group = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.role == SemanticsRole.radioGroup,
    );
    expect(group, findsOneWidget);
    final data = tester.getSemantics(group).getSemanticsData();
    expect(data.role, SemanticsRole.radioGroup);
    expect(data.label, isEmpty);
    handle.dispose();
  });

  testWidgets('CA-015-07: "Como el sistema" dice el idioma que resulta, como '
      'segunda línea visible y en el nombre', (tester) async {
    await pumpWithApp(tester, _page());
    expect(find.text('Como el sistema'), findsOneWidget);
    expect(find.text('Español'), findsNWidgets(2));
    final label = tester.getRect(find.text('Como el sistema'));
    final sub = tester.getRect(find.text('Español').first);
    expect(sub.top, greaterThanOrEqualTo(label.bottom));
  });

  testWidgets('CA-015-07: la marca de selección es visible solo en la '
      'opción vigente y es decorativa para el lector', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _page(selected: 'en'));
    expect(find.byKey(UnaRadioRow.markKey), findsOneWidget);
    // La marca está dentro de la fila de English.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('English'),
          matching: find.byType(UnaRadioRow),
        ),
        matching: find.byKey(UnaRadioRow.markKey),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('CA-015-08: tocar una opción la elige; Intro y Espacio también', (
    tester,
  ) async {
    final picks = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _page(onPick: picks.add, focusNode: focus));
    await tester.tap(find.text('English'));
    expect(picks, ['en']);

    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(picks, ['en', 'system', 'system']);
  });

  testWidgets('CA-015-20f: el nodo de la opción refleja el foco de teclado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _page(focusNode: focus));
    SemanticsData data() => tester
        .getSemantics(
          find.ancestor(
            of: find.text('Como el sistema'),
            matching: find.byType(UnaRadioRow),
          ),
        )
        .getSemanticsData();
    expect(data().flagsCollection.isFocused, Tristate.isFalse);

    focus.requestFocus();
    await tester.pump();
    expect(data().flagsCollection.isFocused, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets(
    'CA-015-22: androidTapTargetGuideline y labeledTapTargetGuideline',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(tester, _page());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      final h = tester.getSize(find.byType(UnaRadioRow).first).height;
      expect(h, greaterThanOrEqualTo(UnaSizes.settingsRow));
      handle.dispose();
    },
  );

  testWidgets('CA-015-22: al 200 % a 360 dp la línea de "Como el sistema" y '
      'las opciones no se recortan', (tester) async {
    await pumpWithApp(
      tester,
      _page(),
      textScale: 2,
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    for (final row in tester.widgetList(find.byType(UnaRadioRow))) {
      expect(row, isA<UnaRadioRow>());
    }
    final first = tester.getRect(find.byType(UnaRadioRow).first);
    final sub = tester.getRect(find.text('Español').first);
    expect(sub.bottom, lessThanOrEqualTo(first.bottom));
    expect(sub.right, lessThanOrEqualTo(first.right));
  });
}
