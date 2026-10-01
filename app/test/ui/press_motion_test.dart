import 'package:app/app/theme/tokens.g.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/press_motion.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

/// Un control que se hunde, con lo que hace falta para probarlo.
typedef _Build = Widget Function({required VoidCallback? onPressed});

class _Case {
  const _Case(
    this.name,
    this.build,
    this.sink,
    this.restShadow,
    this.pressedShadow,
  );
  final String name;
  final _Build build;

  /// Desplazamiento (en x e y) cuando el control está hundido.
  final double sink;
  final List<BoxShadow> restShadow;
  final List<BoxShadow> pressedShadow;
}

final _cases = <_Case>[
  _Case(
    'BrutalButton',
    ({required onPressed}) =>
        BrutalButton(label: 'Guardar', onPressed: onPressed),
    4,
    const [UnaShadows.button],
    const [UnaShadows.buttonPressed],
  ),
  _Case(
    'BrutalButton.icon',
    ({required onPressed}) => BrutalButton.icon(
      label: 'Nueva tarea',
      icon: UnaIcons.plus,
      onPressed: onPressed,
    ),
    4,
    const [UnaShadows.button],
    const [UnaShadows.buttonPressed],
  ),
  _Case(
    'BrutalButton ghost',
    ({required onPressed}) =>
        BrutalButton(label: 'Cancelar', ghost: true, onPressed: onPressed),
    1,
    const [],
    const [],
  ),
  _Case(
    'SquareIconButton',
    ({required onPressed}) => SquareIconButton(
      icon: UnaIcons.menu,
      label: 'Configuración y perfil',
      fill: UnaColors.surface,
      onPressed: onPressed ?? () {},
    ),
    UnaShadows.iconButton.offset.dx,
    const [UnaShadows.iconButton],
    const [],
  ),
];

/// Lo que se ve del control en este fotograma: posición, sombra y duración.
class _Look {
  _Look(this.dx, this.dy, this.shadow, this.duration);
  final double dx;
  final double dy;
  final List<BoxShadow> shadow;
  final Duration duration;

  @override
  String toString() => '($dx, $dy) $shadow $duration';
}

_Look _look(WidgetTester tester, Finder control) {
  final animated = find.descendant(
    of: control,
    matching: find.byType(AnimatedContainer),
  );
  final duration = tester.widget<AnimatedContainer>(animated).duration;
  final transform = tester.widget<Transform>(
    find.descendant(of: animated, matching: find.byType(Transform)).first,
  );
  final t = transform.transform.getTranslation();
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: animated, matching: find.byType(DecoratedBox)).first,
  );
  final shadow = (box.decoration as BoxDecoration).boxShadow ?? const [];
  return _Look(t.x, t.y, shadow, duration);
}

void _expectRest(_Look l, _Case c) {
  expect(l.dx, 0, reason: '$l');
  expect(l.dy, 0, reason: '$l');
  expect(l.shadow, c.restShadow);
}

void _expectSunk(_Look l, _Case c) {
  expect(l.dx, c.sink, reason: '$l');
  expect(l.dy, c.sink, reason: '$l');
  expect(l.shadow, c.pressedShadow);
}

Future<void> _pumpControl(
  WidgetTester tester,
  _Case c, {
  required bool reduced,
  VoidCallback? onPressed,
  bool enabled = true,
}) => pumpWithApp(
  tester,
  Center(child: c.build(onPressed: enabled ? (onPressed ?? () {}) : null)),
  disableAnimations: reduced,
);

void main() {
  setUpAll(loadAppFonts);

  test('CA-013-03: el hundido normal sigue siendo de 80 ms (token)', () {
    expect(UnaMotion.press, const Duration(milliseconds: 80));
  });

  testWidgets('CA-013-03: pressDuration lee el ajuste de MediaQuery', (
    tester,
  ) async {
    late Duration normal;
    late Duration reduced;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            normal = pressDuration(context);
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reduced = pressDuration(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, UnaMotion.press);
    expect(reduced, Duration.zero);
  });

  for (final c in _cases) {
    group('CA-013-03: ${c.name}', () {
      testWidgets(
        'con reducir movimiento se hunde al instante, con la sombra, al pulsar',
        (tester) async {
          await _pumpControl(tester, c, reduced: true);
          final root = _root(c);
          _expectRest(_look(tester, root), c);

          final g = await tester.startGesture(tester.getCenter(root));
          await tester.pump(kPressTimeout);
          final look = _look(tester, root);
          expect(look.duration, Duration.zero);
          _expectSunk(look, c);
          await g.cancel();
        },
      );

      testWidgets('con reducir movimiento vuelve al instante al soltar', (
        tester,
      ) async {
        await _pumpControl(tester, c, reduced: true);
        final root = _root(c);
        final g = await tester.startGesture(tester.getCenter(root));
        await tester.pump(kPressTimeout);
        await g.up();
        await tester.pump();
        final look = _look(tester, root);
        expect(look.duration, Duration.zero);
        _expectRest(look, c);
      });

      testWidgets(
        'CL-013-5: con reducir movimiento vuelve al instante al cancelar (el dedo sale)',
        (tester) async {
          await _pumpControl(tester, c, reduced: true);
          final root = _root(c);
          final g = await tester.startGesture(tester.getCenter(root));
          await tester.pump(kPressTimeout);
          _expectSunk(_look(tester, root), c);
          await g.moveBy(const Offset(0, 300));
          await g.cancel();
          await tester.pump();
          final look = _look(tester, root);
          expect(look.duration, Duration.zero);
          _expectRest(look, c);
        },
      );

      testWidgets(
        'CL-013-7: con reducir movimiento, activar con teclado ejecuta la acción y deja el control en su sitio',
        (tester) async {
          var pressed = 0;
          await _pumpControl(
            tester,
            c,
            reduced: true,
            onPressed: () => pressed++,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(pressed, 1);
          final look = _look(tester, _root(c));
          expect(look.duration, Duration.zero);
          _expectRest(look, c);
        },
      );

      testWidgets(
        'sin reducir movimiento sigue tardando 80 ms: en el origen tras el pump y a medio camino tras 40 ms',
        (tester) async {
          await _pumpControl(tester, c, reduced: false);
          final root = _root(c);
          final g = await tester.startGesture(tester.getCenter(root));
          await tester.pump(kPressTimeout);
          final first = _look(tester, root);
          expect(first.duration, UnaMotion.press);
          _expectRest(first, c);
          await tester.pump(const Duration(milliseconds: 40));
          final mid = _look(tester, root);
          expect(mid.dx, greaterThan(0), reason: '$mid');
          expect(mid.dx, lessThan(c.sink), reason: '$mid');
          await tester.pump(const Duration(milliseconds: 60));
          _expectSunk(_look(tester, root), c);
          await g.cancel();
        },
      );

      testWidgets(
        'CL-013-4: cambiar el ajuste con la app abierta vale en la siguiente pulsación',
        (tester) async {
          final reduced = ValueNotifier(false);
          addTearDown(reduced.dispose);
          await pumpWithApp(
            tester,
            ValueListenableBuilder<bool>(
              valueListenable: reduced,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: value),
                child: Center(child: c.build(onPressed: () {})),
              ),
            ),
          );
          final root = _root(c);
          var g = await tester.startGesture(tester.getCenter(root));
          await tester.pump(kPressTimeout);
          expect(_look(tester, root).duration, UnaMotion.press);
          await g.up();
          await tester.pumpAndSettle();

          reduced.value = true;
          await tester.pump();
          g = await tester.startGesture(tester.getCenter(root));
          await tester.pump(kPressTimeout);
          final look = _look(tester, root);
          expect(look.duration, Duration.zero);
          _expectSunk(look, c);
          await g.up();
          await tester.pump();
          _expectRest(_look(tester, root), c);

          reduced.value = false;
          await tester.pump();
          expect(_look(tester, root).duration, UnaMotion.press);
        },
      );
    });
  }

  group('CL-013-6: BrutalButton pasa de deshabilitado a habilitado', () {
    for (final reduced in [true, false]) {
      testWidgets(
        'con reducir movimiento: $reduced, posición y sombra en el fotograma ${reduced ? 'siguiente' : 'de origen'}',
        (tester) async {
          final enabled = ValueNotifier(false);
          addTearDown(enabled.dispose);
          await pumpWithApp(
            tester,
            ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (context, on, _) => Center(
                child: BrutalButton(
                  label: 'Guardar',
                  onPressed: on ? () {} : null,
                ),
              ),
            ),
            disableAnimations: reduced,
          );
          final root = find.byType(BrutalButton);
          // Deshabilitado: hundido y sin sombra.
          final off = _look(tester, root);
          expect(off.dx, 4);
          expect(off.shadow, isEmpty);

          enabled.value = true;
          await tester.pump();
          final on = _look(tester, root);
          if (reduced) {
            expect(on.duration, Duration.zero);
            expect(on.dx, 0, reason: '$on');
            expect(on.shadow, const [UnaShadows.button]);
          } else {
            expect(on.duration, UnaMotion.press);
            expect(on.dx, 4, reason: 'sigue en el origen: $on');
            await tester.pumpAndSettle();
            expect(_look(tester, root).dx, 0);
          }

          // Y al revés.
          enabled.value = false;
          await tester.pump();
          final back = _look(tester, root);
          if (reduced) {
            expect(back.dx, 4, reason: '$back');
            expect(back.shadow, isEmpty);
          } else {
            expect(back.dx, 0, reason: 'sigue en el origen: $back');
          }
        },
      );
    }
  });
}

/// El control a probar: el único widget de su tipo en pantalla.
Finder _root(_Case c) => switch (c.name) {
  'SquareIconButton' => find.byType(SquareIconButton),
  _ => find.byType(BrutalButton),
};
