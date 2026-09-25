import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

class _Harness {
  int completions = 0;
  bool result = true;

  Future<bool> onComplete() async {
    completions++;
    return result;
  }
}

Future<_Harness> _pump(WidgetTester tester) async {
  final h = _Harness();
  await pumpWithApp(
    tester,
    Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: HoldToCompleteButton(
            label: 'Pulsa para completar',
            a11yAction: 'Completar tarea',
            a11yHint: 'Mantén pulsado o usa las acciones para completar',
            onComplete: h.onComplete,
          ),
        ),
      ),
    ),
  );
  return h;
}

HoldToCompleteButtonState _state(WidgetTester t) =>
    t.state<HoldToCompleteButtonState>(find.byType(HoldToCompleteButton));

Duration _half() => UnaMotion.holdToComplete ~/ 2;

/// Un fotograma: la animación se da por terminada en el siguiente al último.
const _frame = Duration(milliseconds: 16);

void main() {
  testWidgets(
    'CA-003-01: al mantener, el relleno avanza durante 1,2 s y entonces completa',
    (tester) async {
      final h = await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump(); // Arranca la animación.
      await tester.pump(_half());
      expect(_state(tester).progress, closeTo(0.5, 0.05));
      expect(h.completions, 0);
      await tester.pump(_half());
      await tester.pump(_frame);
      expect(h.completions, 1);
      await gesture.up();
      await tester.pump(UnaMotion.holdRelease);
      expect(_state(tester).progress, 1, reason: 'se queda lleno');
    },
  );

  testWidgets(
    'CA-003-02 / CL-003-6: soltar antes de tiempo retrocede y no completa',
    (tester) async {
      final h = await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump(); // Arranca la animación.
      await tester.pump(_half());
      await gesture.up();
      await tester.pump(UnaMotion.holdRelease);
      await tester.pump(UnaMotion.holdToComplete);
      expect(_state(tester).progress, 0);
      expect(h.completions, 0);
    },
  );

  testWidgets('CA-003-02: arrastrar el dedo fuera del botón cancela', (
    tester,
  ) async {
    final h = await _pump(tester);
    final rect = tester.getRect(find.byType(HoldToCompleteButton));
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(); // Arranca la animación.
    await tester.pump(_half());
    await gesture.moveTo(rect.topCenter - const Offset(0, 40));
    await tester.pump(_frame);
    await tester.pump(UnaMotion.holdToComplete);
    expect(h.completions, 0);
    expect(_state(tester).progress, 0);
    await gesture.up();
  });

  testWidgets('CA-003-02 / CL-003-2: pasar a segundo plano cancela', (
    tester,
  ) async {
    final h = await _pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump(); // Arranca la animación.
    await tester.pump(_half());
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await gesture.up();
    // En segundo plano no hay fotogramas: se comprueba al volver.
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(_frame);
    await tester.pump(UnaMotion.holdToComplete);
    expect(h.completions, 0);
    expect(_state(tester).progress, 0);
  });

  testWidgets('CL-003-3: un segundo dedo no cuenta ni cancela', (tester) async {
    final h = await _pump(tester);
    final center = tester.getCenter(find.byType(HoldToCompleteButton));
    final first = await tester.startGesture(center);
    await tester.pump(); // Arranca la animación.
    await tester.pump(_half());
    final second = await tester.startGesture(center + const Offset(20, 0));
    await second.up();
    await tester.pump(_half());
    await tester.pump(_frame);
    expect(h.completions, 1);
    await first.up();
  });

  testWidgets(
    'CA-003-08: mantener Espacio 1,2 s completa; las repeticiones no reinician',
    (tester) async {
      final h = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(_frame);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(_frame);
      await tester.pump(_half());
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump(_half());
      await tester.pump(_frame);
      expect(h.completions, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    },
  );

  testWidgets('CA-003-08: soltar la tecla antes de tiempo no completa', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(_frame);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(_frame);
    await tester.pump(_half());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(UnaMotion.holdToComplete);
    expect(h.completions, 0);
  });

  testWidgets('CA-003-12: si no se pudo completar, el relleno retrocede', (
    tester,
  ) async {
    final h = await _pump(tester)
      ..result = false;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump(); // Arranca la animación.
    await tester.pump(UnaMotion.holdToComplete);
    await tester.pump(_frame);
    expect(h.completions, 1);
    await gesture.up();
    await tester.pump(UnaMotion.holdRelease);
    await tester.pump(_frame);
    expect(_state(tester).progress, 0);
  });

  testWidgets(
    'CA-003-07: con lector se completa con la acción "Completar tarea"; el doble toque no completa',
    (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester);
      final node = tester.getSemantics(find.byType(HoldToCompleteButton));
      final data = node.getSemanticsData();
      expect(data.label, 'Pulsa para completar');
      expect(data.hint, 'Mantén pulsado o usa las acciones para completar');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.hasAction(SemanticsAction.customAction), isTrue);

      tester.semantics.customAction(
        find.semantics.byLabel('Pulsa para completar'),
        const CustomSemanticsAction(label: 'Completar tarea'),
      );
      await tester.pump(_frame);
      expect(h.completions, 1);
      handle.dispose();
    },
  );
}
