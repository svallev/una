import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/settings_row.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/focus.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';
import '../support/semantics_stops.dart';

const _web = 'Abre una página web en el navegador';

Widget _rows({
  VoidCallback? onTap,
  FocusNode? focusNode,
  GlobalKey? semanticsKey,
  AttributedString? attributed,
}) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            SettingsRow(
              icon: UnaIcons.globe,
              label: 'Idioma',
              value: 'Español',
              trailing: SettingsRowTrailing.chevron,
              onTap: onTap ?? () {},
              focusNode: focusNode,
              semanticsKey: semanticsKey,
              attributedLabel: attributed,
            ),
            SettingsRow(
              icon: UnaIcons.lock,
              label: 'Política de privacidad',
              opensWebHint: _web,
              indent: true,
              divider: true,
              onTap: onTap ?? () {},
            ),
            SettingsRow(
              icon: UnaIcons.help,
              label: 'Ayuda',
              opensWebHint: _web,
              divider: true,
              onTap: onTap ?? () {},
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-06: la fila de Idioma muestra el valor y el chevron, y '
      'se lee "Idioma, Español"', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _rows());
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    final data = tester
        .getSemantics(find.bySemanticsLabel('Idioma, Español'))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    // El valor va a la derecha del nombre.
    expect(
      tester.getTopLeft(find.text('Español')).dx,
      greaterThan(tester.getTopRight(find.text('Idioma')).dx),
    );
    handle.dispose();
  });

  testWidgets('CA-015-01b: medidas del prototipo (Idioma y Ayuda 60, Política '
      '52 con sangría de 38)', (tester) async {
    await pumpWithApp(tester, _rows());
    final rows = find.byType(SettingsRow);
    expect(tester.getSize(rows.at(0)).height, UnaSizes.settingsRow);
    // El separador de 1 px va dentro de la altura mínima.
    expect(tester.getSize(rows.at(1)).height, UnaSizes.settingsRowSub);
    expect(tester.getSize(rows.at(2)).height, UnaSizes.settingsRow);
    // Sangría: el icono de las filas de web bajo "Información".
    final left = tester.getTopLeft(rows.at(1)).dx;
    final icon = tester.getTopLeft(
      find.descendant(of: rows.at(1), matching: find.byType(UnaIcon)).first,
    );
    expect(icon.dx - left, UnaSizes.settingsRowSubIndent);
  });

  testWidgets('CA-015-01b: el separador de fila es de 1 px, con el color de '
      'DEV-38', (tester) async {
    await pumpWithApp(tester, _rows());
    final decorated = find.descendant(
      of: find.byType(SettingsRow).at(2),
      matching: find.byType(Container),
    );
    final box = tester
        .widgetList<Container>(decorated)
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    expect(box.border!.top.width, UnaSizes.separatorRow);
    expect(box.border!.top.color, UnaColors.disabled);
  });

  testWidgets('CA-015-20: las filas de web llevan "abre una página web" en la '
      'etiqueta, no como pista', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _rows());
    for (final name in ['Política de privacidad', 'Ayuda']) {
      final data = tester
          .getSemantics(find.bySemanticsLabel('$name, $_web'))
          .getSemanticsData();
      expect(data.label, '$name, $_web');
      expect(data.hint, isEmpty);
      expect(data.flagsCollection.isButton, isTrue);
    }
    handle.dispose();
  });

  testWidgets('CA-015-01b: los iconos de las filas son decorativos', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithApp(tester, _rows());
    expectNoUnnamedSemanticsStops(tester);
    // Solo tres nodos con acción de tocar: las tres filas.
    var taps = 0;
    void visit(SemanticsNode node) {
      if (!node.isMergedIntoParent &&
          !node.isInvisible &&
          node.getSemanticsData().hasAction(SemanticsAction.tap)) {
        taps++;
      }
      node.visitChildren((c) {
        visit(c);
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
    expect(taps, 3);
    handle.dispose();
  });

  testWidgets('CA-015-11: con attributedLabel, el lector recibe esa '
      'etiqueta con sus marcas de idioma', (tester) async {
    final handle = tester.ensureSemantics();
    final label = AttributedString(
      'Idioma, Español',
      attributes: [
        LocaleStringAttribute(
          locale: const Locale('es'),
          range: const TextRange(start: 8, end: 15),
        ),
      ],
    );
    await pumpWithApp(tester, _rows(attributed: label));
    final data = tester
        .getSemantics(find.bySemanticsLabel('Idioma, Español'))
        .getSemanticsData();
    expect(data.attributedLabel.string, 'Idioma, Español');
    expect(data.attributedLabel.attributes, hasLength(1));
    final attr = data.attributedLabel.attributes.single;
    expect(attr, isA<LocaleStringAttribute>());
    expect((attr as LocaleStringAttribute).locale, const Locale('es'));
    expect(attr.range, const TextRange(start: 8, end: 15));
    handle.dispose();
  });

  testWidgets('CA-015-12: tocar la fila la activa; Intro y Espacio también, '
      'con anillo solo con el teclado', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pumpWithApp(tester, _rows(onTap: () => taps++, focusNode: focus));
    await tester.tap(find.text('Idioma'));
    expect(taps, 1);
    expect(
      tester
          .widget<FocusRing>(
            find
                .descendant(
                  of: find.byType(SettingsRow).first,
                  matching: find.byType(FocusRing),
                )
                .first,
          )
          .visible,
      isFalse,
    );

    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 3);
  });

  testWidgets('CA-015-21: con Tab, la fila muestra su anillo', (tester) async {
    await pumpWithApp(tester, _rows());
    expect(await tabUntilRing(tester, 'Idioma, Español'), isTrue);
  });

  testWidgets('CA-015-20: la fila lleva la clave que se le pasa (aviso de '
      'foco del lector)', (tester) async {
    final key = GlobalKey();
    await pumpWithApp(tester, _rows(semanticsKey: key));
    expect(key.currentContext!.findRenderObject(), isNotNull);
  });

  testWidgets(
    'CA-015-22: androidTapTargetGuideline y labeledTapTargetGuideline',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(tester, _rows());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('CA-015-06: al 200 % a 360 dp el valor pasa a una segunda línea '
      'sin recortes', (tester) async {
    await pumpWithApp(
      tester,
      _rows(),
      textScale: 2,
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(SettingsRow).first);
    final name = tester.getRect(find.text('Idioma'));
    final value = tester.getRect(find.text('Español'));
    expect(
      value.top,
      greaterThanOrEqualTo(name.bottom),
      reason: 'el valor va debajo del nombre',
    );
    expect(value.bottom, lessThanOrEqualTo(row.bottom));
    expect(value.left, greaterThanOrEqualTo(row.left));
    expect(value.right, lessThanOrEqualTo(row.right));
    expect(row.height, greaterThan(UnaSizes.settingsRow));
    // El chevron sigue a la derecha, dentro de la fila.
    final chevron = tester.getRect(
      find
          .descendant(
            of: find.byType(SettingsRow).first,
            matching: find.byType(UnaIcon),
          )
          .last,
    );
    expect(chevron.right, lessThanOrEqualTo(row.right));
  });

  testWidgets('CA-015-22: al 200 % las filas de web con nombre largo no se '
      'recortan', (tester) async {
    await pumpWithApp(
      tester,
      _rows(),
      textScale: 2,
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(SettingsRow).at(1));
    final text = tester.getRect(find.text('Política de privacidad'));
    expect(text.left, greaterThanOrEqualTo(row.left));
    expect(text.right, lessThanOrEqualTo(row.right));
    expect(text.bottom, lessThanOrEqualTo(row.bottom));
  });

  testWidgets('CA-015-06: al 100 % el valor está en la misma línea que el '
      'nombre', (tester) async {
    await pumpWithApp(tester, _rows());
    final name = tester.getRect(find.text('Idioma'));
    final value = tester.getRect(find.text('Español'));
    expect((value.center.dy - name.center.dy).abs(), lessThan(8));
  });
}
