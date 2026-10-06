import 'dart:ui' show Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/focus_ring.dart';
import 'package:app/ui/una_icons.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

const _name = 'Pantalla siempre activa';
const _hint = 'Imágenes, documentos y web';
const _label = '$_name, $_hint';

/// Una fila cuyo valor lo lleva el test (como el controlador de Ajustes: la
/// fila no cambia sola, CA-015-03).
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = false,
    this.onToggle,
    this.subtitle = _hint,
    this.focusNode,
    this.semanticsKey,
  });

  final bool initial;
  final VoidCallback? onToggle;
  final String? subtitle;
  final FocusNode? focusNode;
  final GlobalKey? semanticsKey;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool value = widget.initial;

  void set(bool v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UnaSwitchRow(
            icon: UnaIcons.phone,
            label: _name,
            subtitle: widget.subtitle,
            value: value,
            onToggle: widget.onToggle ?? () {},
            focusNode: widget.focusNode,
            semanticsKey: widget.semanticsKey,
          ),
        ],
      ),
    ),
  );
}

GlobalKey<_HostState> _hostKey() => GlobalKey<_HostState>();

Future<GlobalKey<_HostState>> _pump(
  WidgetTester tester, {
  bool initial = false,
  VoidCallback? onToggle,
  String? subtitle = _hint,
  FocusNode? focusNode,
  GlobalKey? semanticsKey,
  bool disableAnimations = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  final key = _hostKey();
  await pumpWithApp(
    tester,
    _Host(
      key: key,
      initial: initial,
      onToggle: onToggle,
      subtitle: subtitle,
      focusNode: focusNode,
      semanticsKey: semanticsKey,
    ),
    disableAnimations: disableAnimations,
    textScale: textScale,
    size: size,
  );
  return key;
}

double _knobX(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(UnaSwitchRow.knobKey)).dx;

/// La decoración propia de la pista o del pomo (la pista contiene al pomo:
/// su `DecoratedBox` es el primero).
BoxDecoration _decorationOf(WidgetTester tester, Key key) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

Color _fillOf(WidgetTester tester, Key key) =>
    _decorationOf(tester, key).color!;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-03: la posición del pomo difiere entre los dos estados '
      'y toggled coincide con ella', (tester) async {
    final handle = tester.ensureSemantics();
    final host = await _pump(tester);
    final off = _knobX(tester);
    var data = tester
        .getSemantics(find.bySemanticsLabel(_label))
        .getSemanticsData();
    expect(data.flagsCollection.isToggled, Tristate.isFalse);

    host.currentState!.set(true);
    await tester.pumpAndSettle();
    final on = _knobX(tester);
    data = tester
        .getSemantics(find.bySemanticsLabel(_label))
        .getSemanticsData();
    expect(data.flagsCollection.isToggled, Tristate.isTrue);

    // Cambia de lado (WCAG 1.4.1), no solo de color: el recorrido es el token.
    expect(on - off, UnaSizes.switchKnobTravel);
    expect(on, greaterThan(off));
    handle.dispose();
  });

  testWidgets('CA-015-03: se intercambian los colores de pista y pomo '
      '(apagado: pista papel y pomo amarillo; encendido, al revés)', (
    tester,
  ) async {
    final host = await _pump(tester);
    expect(_fillOf(tester, UnaSwitchRow.trackKey), UnaColors.paper);
    expect(_fillOf(tester, UnaSwitchRow.knobKey), UnaColors.switchOn);
    host.currentState!.set(true);
    await tester.pumpAndSettle();
    expect(_fillOf(tester, UnaSwitchRow.trackKey), UnaColors.switchOn);
    expect(_fillOf(tester, UnaSwitchRow.knobKey), UnaColors.paper);
  });

  testWidgets('CA-015-03: medidas del prototipo (pista de 54 x 32, pomo de '
      '22 a 2 de la esquina, bordes de tinta de 3 y 2)', (tester) async {
    await _pump(tester);
    expect(
      tester.getSize(find.byKey(UnaSwitchRow.trackKey)),
      const Size(UnaSizes.switchWidth, UnaSizes.switchHeight),
    );
    expect(
      tester.getSize(find.byKey(UnaSwitchRow.knobKey)),
      const Size(UnaSizes.switchKnob, UnaSizes.switchKnob),
    );
    final track = tester.getTopLeft(find.byKey(UnaSwitchRow.trackKey));
    final knob = tester.getTopLeft(find.byKey(UnaSwitchRow.knobKey));
    expect(
      knob - track,
      const Offset(
        UnaBorders.switchTrackWidth + UnaSizes.switchKnobInset,
        UnaBorders.switchTrackWidth + UnaSizes.switchKnobInset,
      ),
    );
    final trackBox = _decorationOf(tester, UnaSwitchRow.trackKey);
    expect(trackBox.border!.top.color, UnaColors.ink);
    expect(trackBox.border!.top.width, UnaBorders.switchTrackWidth);
    expect(
      trackBox.borderRadius,
      BorderRadius.circular(UnaBorders.switchTrackRadius),
    );
  });

  testWidgets('CA-015-03: el interruptor no se mueve hasta que el valor '
      'cambia (sin cambio optimista)', (tester) async {
    var taps = 0;
    final host = await _pump(tester, onToggle: () => taps++);
    final before = _knobX(tester);

    await tester.tap(find.byType(UnaSwitchRow));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_knobX(tester), before, reason: 'el guardado aún no se ha hecho');

    host.currentState!.set(true);
    await tester.pumpAndSettle();
    expect(_knobX(tester), isNot(before));
  });

  testWidgets('CA-015-03: toda la fila es el objetivo táctil', (tester) async {
    var taps = 0;
    await _pump(tester, onToggle: () => taps++);
    // El nombre, a la izquierda, y el borde derecho de la fila.
    await tester.tap(find.text(_name));
    final row = tester.getRect(find.byType(UnaSwitchRow));
    await tester.tapAt(Offset(row.right - 2, row.center.dy));
    expect(taps, 2);
  });

  testWidgets('CA-015-03: Intro y Espacio activan el interruptor', (
    tester,
  ) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(tester, onToggle: () => taps++, focusNode: focus);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('CA-015-21: con el foco del teclado, anillo; con el tacto, no', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(tester, focusNode: focus);
    Finder ring() => find.descendant(
      of: find.byType(UnaSwitchRow),
      matching: find.byType(FocusRing),
    );

    // Con el tacto (modo táctil), aunque tenga el foco, sin anillo.
    await tester.tap(find.byType(UnaSwitchRow));
    await tester.pump();
    expect(tester.widget<FocusRing>(ring().first).visible, isFalse);

    // Con el teclado, anillo.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    expect(tester.widget<FocusRing>(ring().first).visible, isTrue);
  });

  testWidgets('CA-015-20: un solo nodo "interruptor" con nombre y subtítulo '
      'juntos, sin pista aparte', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final data = tester
        .getSemantics(find.bySemanticsLabel(_label))
        .getSemanticsData();
    expect(data.label, _label);
    expect(data.hint, isEmpty);
    expect(data.flagsCollection.isToggled, isNot(Tristate.none));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    // Ni el nombre ni el subtítulo, ni el pomo, son nodos propios.
    expect(find.bySemanticsLabel(_name), findsNothing);
    expect(find.bySemanticsLabel(_hint), findsNothing);
    handle.dispose();
  });

  testWidgets('CA-015-20: la acción de tocar del lector activa el '
      'interruptor', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(tester, onToggle: () => taps++);
    tester.semantics.tap(find.semantics.byLabel(_label));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('CA-015-20: sin subtítulo, el nodo lleva solo el nombre', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, subtitle: null);
    expect(find.bySemanticsLabel(_name), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'CA-015-22: androidTapTargetGuideline y labeledTapTargetGuideline',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('CA-015-01a: ≥ 44 pt visibles (la fila mide 76 con subtítulo y '
      '64 sin él)', (tester) async {
    await _pump(tester);
    expect(
      tester.getSize(find.byType(UnaSwitchRow)).height,
      greaterThanOrEqualTo(UnaSizes.settingsRowSwitchHint),
    );
    await _pump(tester, subtitle: null);
    final height = tester.getSize(find.byType(UnaSwitchRow)).height;
    expect(height, UnaSizes.settingsRowSwitch);
    expect(height, greaterThanOrEqualTo(44));
  });

  testWidgets('CA-015-01d: el pomo y la pista tardan 140 y 120 ms; con '
      'reducir movimiento, cambian en el mismo fotograma', (tester) async {
    final host = await _pump(tester);
    final before = _knobX(tester);
    host.currentState!.set(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final half = _knobX(tester);
    expect(half, greaterThan(before));
    expect(half, lessThan(before + UnaSizes.switchKnobTravel));
    await tester.pump(UnaMotion.switchKnob);
    expect(_knobX(tester), before + UnaSizes.switchKnobTravel);

    // Reducir movimiento: sin transición.
    final reduced = await _pump(tester, disableAnimations: true);
    final start = _knobX(tester);
    reduced.currentState!.set(true);
    await tester.pump();
    await tester.pump();
    expect(_knobX(tester), start + UnaSizes.switchKnobTravel);
    expect(_fillOf(tester, UnaSwitchRow.trackKey), UnaColors.switchOn);
  });

  testWidgets('CA-015-22: al 200 % a 360 dp, sin desbordar, y el interruptor '
      'conserva su tamaño', (tester) async {
    await _pump(tester, textScale: 2, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(UnaSwitchRow.trackKey)),
      const Size(UnaSizes.switchWidth, UnaSizes.switchHeight),
    );
    final row = tester.getRect(find.byType(UnaSwitchRow));
    final text = tester.getRect(find.text(_name));
    final hint = tester.getRect(find.text(_hint));
    expect(text.left, greaterThanOrEqualTo(row.left));
    expect(hint.bottom, lessThanOrEqualTo(row.bottom));
    // El texto no se solapa con el interruptor.
    final track = tester.getRect(find.byKey(UnaSwitchRow.trackKey));
    expect(text.right, lessThanOrEqualTo(track.left));
    expect(hint.right, lessThanOrEqualTo(track.left));
  });

  testWidgets('CA-015-20: el nodo lleva la clave que se le pasa, para el '
      'aviso de foco del lector', (tester) async {
    final key = GlobalKey();
    await _pump(tester, semanticsKey: key);
    expect(key.currentContext, isNotNull);
    expect(key.currentContext!.findRenderObject(), isNotNull);
  });
}
