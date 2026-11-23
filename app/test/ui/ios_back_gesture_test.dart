// El gesto atrás de iOS (T-028-12; CA-028-09): deslizar desde el borde izquierdo
// vuelve atrás con **la misma transición que Android**, movida por el dedo, y
// decide solo por la mitad. Con las mismas reglas del atrás de Android (PopScope,
// la tarea actual no tiene atrás) y sin efecto en Android.
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/ios_back_gesture.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_harness.dart';
import '../features/task_list/list_harness.dart';
import '../support/app_harness.dart';
import '../support/pump_app.dart' show sampleTask;

const _width = 390.0;
const _edgeY = 400.0;

/// Lo que se ve de la pantalla empujada y de la de debajo.
final _detail = find.text('Detalle');
final _home = find.text('abrir');

/// Pantalla de partida con un botón que empuja [route].
Widget _app(Route<void> Function(BuildContext context) route) => MaterialApp(
  theme: UnaTheme.light(),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(route(context)),
          child: const Text('abrir'),
        ),
      ),
    ),
  ),
);

/// Ruta con el fundido de las pantallas de la app (editor, Idioma).
Route<void> _fadeRoute(BuildContext context, {Widget? page}) =>
    UnaPageRoute<void>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          page ?? const Scaffold(body: Center(child: Text('Detalle'))),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

Future<void> _open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(_width, 844)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.tap(_home);
  await tester.pumpAndSettle();
  expect(_detail, findsOneWidget);
}

/// La animación de la ruta de "Detalle": 1 puesta, 0 quitada.
double _animation(WidgetTester tester) =>
    ModalRoute.of(tester.element(_detail))!.animation!.value;

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Opacidad que se está dibujando (el fundido de la ruta de prueba).
double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _detail, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

/// Pone el dedo en el borde y lo mueve [dx] en pasos de 10 px, sin soltarlo.
Future<TestGesture> _dragIn(
  WidgetTester tester,
  double dx, {
  double x = 5,
}) async {
  final gesture = await tester.startGesture(Offset(x, _edgeY));
  var moved = 0.0;
  var stamp = 0;
  while (moved < dx) {
    stamp += 16;
    await gesture.moveBy(
      const Offset(10, 0),
      timeStamp: Duration(milliseconds: stamp),
    );
    moved += 10;
  }
  await tester.pump();
  return gesture;
}

/// Mueve el dedo en pasos de 10 px hasta que la animación baja a [value].
Future<TestGesture> _dragUntil(WidgetTester tester, double value) async {
  final gesture = await tester.startGesture(const Offset(5, _edgeY));
  var stamp = 0;
  for (var i = 0; i < 60 && _animation(tester) > value; i++) {
    stamp += 16;
    await gesture.moveBy(
      const Offset(10, 0),
      timeStamp: Duration(milliseconds: stamp),
    );
    await tester.pump();
  }
  return gesture;
}

void main() {
  group('CA-028-09: el gesto atrás en iOS, con la transición de Android', () {
    testWidgets(
      'CA-028-09: deslizar desde el borde pasada la mitad vuelve a la '
      'pantalla anterior',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
        expect(_home, findsOneWidget);
        expect(_navigator(tester).userGestureInProgress, isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: durante el arrastre, la transición de la ruta avanza con el '
      'dedo (lineal a su anchura)',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        final gesture = await _dragIn(tester, 100);
        final first = _animation(tester);
        expect(first, lessThan(1.0), reason: 'ya se mueve con el dedo');
        // La transición que se ve es la de la ruta (el fundido), no otra.
        expect(_opacity(tester), closeTo(first, 0.001));
        await gesture.moveBy(
          const Offset(100, 0),
          timeStamp: const Duration(seconds: 1),
        );
        await tester.pump();
        expect(_animation(tester), closeTo(first - 100 / _width, 0.001));
        expect(_opacity(tester), closeTo(_animation(tester), 0.001));
        // Aún no se ha soltado: no ha vuelto, y el Navigator sabe que hay un
        // gesto en curso (lo que usan las transiciones).
        expect(_detail, findsOneWidget);
        expect(_navigator(tester).userGestureInProgress, isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_navigator(tester).userGestureInProgress, isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: soltar antes de la mitad vuelve a su sitio sin cambiar de '
      'pantalla',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        final gesture = await _dragUntil(tester, 0.7);
        expect(_animation(tester), lessThan(0.7));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        expect(_animation(tester), 1.0);
        expect(_opacity(tester), 1.0);
        expect(_navigator(tester).userGestureInProgress, isFalse);
        // Y se puede volver a deslizar después.
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: decide por la mitad: justo antes se queda, justo después '
      'vuelve',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        // Por encima de la mitad (todavía no ha pasado): se queda.
        var gesture = await _dragUntil(tester, 0.53);
        expect(_animation(tester), inExclusiveRange(0.5, 0.53));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        // Por debajo de la mitad (ya la pasó): vuelve.
        gesture = await _dragUntil(tester, 0.49);
        expect(_animation(tester), lessThanOrEqualTo(0.49));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: sin regla de velocidad: un lanzamiento rápido y corto no '
      'vuelve, y soltar pasada la mitad con el dedo yendo hacia atrás, sí',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        await tester.flingFrom(
          const Offset(5, _edgeY),
          const Offset(120, 0),
          4000,
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget, reason: 'corto y rápido: se queda');

        // Pasada la mitad, y a la vez un tirón rápido hacia el borde.
        final gesture = await _dragUntil(tester, 0.45);
        await gesture.moveBy(
          const Offset(-4, 0),
          timeStamp: const Duration(seconds: 2),
        );
        await gesture.moveBy(
          const Offset(-4, 0),
          timeStamp: const Duration(seconds: 2, milliseconds: 1),
        );
        expect(_animation(tester), lessThan(0.5));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsNothing, reason: 'solo cuenta la mitad');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: la franja del borde es la del token; fuera de ella no hay '
      'gesto',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        expect(UnaSizes.backGestureEdge, 20.0);
        final strip = tester.getRect(find.byKey(IosBackSwipe.edgeKey));
        expect(strip.left, 0.0);
        expect(strip.width, UnaSizes.backGestureEdge);
        expect(strip.height, tester.view.physicalSize.height);

        await tester.timedDragFrom(
          const Offset(UnaSizes.backGestureEdge + 6, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        expect(_animation(tester), 1.0);

        await tester.timedDragFrom(
          const Offset(UnaSizes.backGestureEdge - 4, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: un arrastre vertical desde el borde no vuelve atrás',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(0, 300),
          const Duration(milliseconds: 400),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: la primera ruta no tiene atrás (la tarea actual): no hay '
      'gesto ni efecto',
      (tester) async {
        tester.view
          ..physicalSize = const Size(_width, 844)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: UnaTheme.light(),
            // Un Navigator propio: su primera (y única) ruta.
            home: Navigator(
              onGenerateRoute: (_) => UnaPageRoute<void>(
                pageBuilder: (_, _, _) =>
                    const Scaffold(body: Center(child: Text('Detalle'))),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: una ruta sin transición (el listado) también vuelve, y '
      'también decide por la mitad',
      (tester) async {
        await tester.pumpWidget(
          _app(
            (_) => UnaPageRoute<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, _, _) =>
                  const Scaffold(body: Center(child: Text('Detalle'))),
            ),
          ),
        );
        await _open(tester);
        var gesture = await _dragUntil(tester, 0.7);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        gesture = await _dragUntil(tester, 0.45);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: con reducir movimiento, al soltar la vuelta es inmediata '
      '(y sin él, se ve terminar)',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          _app(
            (_) => UnaPageRoute<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, _, _) =>
                  const Scaffold(body: Center(child: Text('Detalle'))),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        );
        await _open(tester);
        var gesture = await _dragUntil(tester, 0.45);
        await gesture.up();
        await tester.pump();
        expect(_detail, findsNothing, reason: 'un solo fotograma');

        // Soltar antes de la mitad: vuelve a su sitio en el acto.
        await tester.tap(_home);
        await tester.pumpAndSettle();
        gesture = await _dragUntil(tester, 0.8);
        expect(_animation(tester), lessThan(0.8));
        await gesture.up();
        await tester.pump();
        expect(_animation(tester), 1.0);
        expect(
          tester.hasRunningAnimations,
          isFalse,
          reason: 'sin animación de vuelta',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: sin reducir movimiento, al soltar la vuelta se anima '
      'durante el tiempo del token',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        final gesture = await _dragUntil(tester, 0.45);
        await gesture.up();
        await tester.pump();
        await tester.pump(UnaMotion.backGestureSettle ~/ 3);
        expect(_detail, findsOneWidget, reason: 'aún animándose');
        await tester.pump(UnaMotion.backGestureSettle);
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('CA-028-09: mismas reglas que el atrás de Android', () {
    testWidgets(
      'CA-028-09: con PopScope(canPop: false) el gesto no vuelve ni mueve '
      'nada; el atrás del sistema (escape de VoiceOver) avisa al PopScope',
      (tester) async {
        final calls = <bool>[];
        await tester.pumpWidget(
          _app(
            (c) => _fadeRoute(
              c,
              page: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) => calls.add(didPop),
                child: const Scaffold(body: Center(child: Text('Detalle'))),
              ),
            ),
          ),
        );
        await _open(tester);
        final gesture = await _dragIn(tester, 250);
        expect(_animation(tester), 1.0, reason: 'no se mueve con el dedo');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        expect(calls, isEmpty);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        expect(calls, [false]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: el escape de VoiceOver (handlePopRoute) vuelve atrás',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
        expect(_home, findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'CA-028-09: en Android no hay franja ni gesto (todo como antes)',
      (tester) async {
        await tester.pumpWidget(_app(_fadeRoute));
        await _open(tester);
        expect(find.byKey(IosBackSwipe.edgeKey), findsNothing);
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsOneWidget);
        // El atrás de Android sigue igual.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('CA-028-09: transiciones de iOS = las de Android', () {
    test('CA-028-09: el tema da a iOS el mismo constructor que Android al '
        'navegar (no el de Cupertino), y Android no cambia', () {
      final builders = UnaTheme.light().pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.iOS],
        isA<FadeForwardsPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS].runtimeType.toString(),
        isNot('CupertinoPageTransitionsBuilder'),
      );
      // Android: el de siempre (el que trae Flutter), sin tocarlo.
      expect(
        builders[TargetPlatform.android].runtimeType,
        const PageTransitionsTheme()
            .builders[TargetPlatform.android]
            .runtimeType,
      );
    });

    testWidgets(
      'CA-028-09: una ruta de Material en iOS no usa la transición de '
      'Cupertino y también se cierra con el gesto',
      (tester) async {
        await tester.pumpWidget(
          _app(
            (_) => UnaMaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Detalle'))),
            ),
          ),
        );
        await _open(tester);
        expect(find.byType(CupertinoPageTransition), findsNothing);
        await tester.timedDragFrom(
          const Offset(5, _edgeY),
          const Offset(320, 0),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(_detail, findsNothing);
        expect(find.byType(CupertinoPageTransition), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('CA-028-09: en las pantallas de la app', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    Future<void> swipeBack(WidgetTester tester, {double x = 5}) async {
      await tester.timedDragFrom(
        Offset(x, _edgeY),
        const Offset(320, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CA-028-09: Ajustes vuelve a la tarea con el gesto y con el '
        'escape de VoiceOver', (tester) async {
      await openSettingsScreen(tester);
      await swipeBack(tester);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Primera'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
    }, variant: ios);

    testWidgets(
      'CA-028-09: la página de Idioma vuelve a Ajustes (no cierra Ajustes)',
      (tester) async {
        await openSettingsScreen(tester);
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        expect(find.byType(LanguagePage), findsOneWidget);
        await swipeBack(tester);
        expect(find.byType(LanguagePage), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
      variant: ios,
    );

    testWidgets('CA-028-09: el listado vuelve a la tarea; la lista sigue '
        'desplazándose por el borde', (tester) async {
      await openList(tester, tasks: [for (var i = 0; i < 16; i++) 'Tarea $i']);
      final before = tester.getTopLeft(rowOf('Tarea 6')).dy;
      await tester.timedDragFrom(
        const Offset(5, 500),
        const Offset(0, -120),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(rowOf('Tarea 6')).dy,
        lessThan(before),
        reason: 'el arrastre vertical por el borde desplaza la lista',
      );
      expect(find.byType(TaskListScreen), findsOneWidget);

      await swipeBack(tester);
      expect(find.byType(TaskListScreen), findsNothing);
      expect(find.text('Tarea 0'), findsOneWidget);
    }, variant: ios);

    testWidgets('CA-028-09: soltar el listado antes de la mitad no lo cierra', (
      tester,
    ) async {
      await openList(tester, tasks: ['Uno', 'Dos', 'Tres']);
      await tester.timedDragFrom(
        const Offset(5, 600),
        const Offset(120, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
    }, variant: ios);

    testWidgets('CA-028-09: el editor descarta sin preguntar, como el atrás de '
        'Android (CA-002-07)', (tester) async {
      final repo = InMemoryTaskRepository();
      await pumpUnaApp(tester, repo: repo, tasks: ['Primera']);
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Algo a medias');
      await tester.pump();
      await swipeBack(tester);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Primera'), findsOneWidget);
      expect((await repo.pendingTasks()).length, 1);
    }, variant: ios);

    testWidgets('CA-028-09: «Todo hecho.» abre el editor y el gesto vuelve a '
        '«Todo hecho.»', (tester) async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask(id: 'a', rank: 'a'));
      await repo.remove('a');
      await pumpUnaApp(tester, repo: repo);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      await tester.tap(find.byType(BrutalButton));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(find.byType(CupertinoPageTransition), findsNothing);
      await swipeBack(tester);
      expect(find.byType(TaskEditorScreen), findsNothing);
      expect(find.byType(AllDoneScreen), findsOneWidget);
    }, variant: ios);

    testWidgets('CA-028-09: la tarea actual no tiene atrás: el gesto no hace '
        'nada', (tester) async {
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
      );
      await swipeBack(tester);
      expect(find.text('Primera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: ios);

    /// Desplazamiento que dibujan las `SlideTransition` por encima de [page].
    List<Offset> slidesAbove(WidgetTester tester, Finder page) => [
      for (final slide in tester.widgetList<SlideTransition>(
        find.ancestor(of: page, matching: find.byType(SlideTransition)),
      ))
        slide.position.value,
    ];

    testWidgets('CA-028-09 / CA-015-01d (P6): con reducir movimiento, el dedo '
        'a mitad del gesto no mueve Ajustes en vertical (fundido)', (
      tester,
    ) async {
      await openSettingsScreen(tester, reduced: true);
      final settings = find.byType(SettingsScreen);
      final gesture = await tester.startGesture(const Offset(5, _edgeY));
      var stamp = 0;
      for (var i = 0; i < 20; i++) {
        stamp += 16;
        await gesture.moveBy(
          const Offset(10, 0),
          timeStamp: Duration(milliseconds: stamp),
        );
        await tester.pump();
      }
      final value = ModalRoute.of(tester.element(settings))!.animation!.value;
      expect(value, inExclusiveRange(0.2, 0.8), reason: 'a mitad del gesto');
      expect(
        slidesAbove(tester, settings).where((o) => o != Offset.zero),
        isEmpty,
        reason: 'ningún deslizamiento',
      );
      expect(tester.getTopLeft(settings), Offset.zero);
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: settings, matching: find.byType(FadeTransition)),
      );
      expect(
        fades.map((f) => f.opacity.value),
        contains(closeTo(value, 0.001)),
        reason: 'el dedo mueve un fundido',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(settings, findsNothing);
    }, variant: ios);

    testWidgets('CA-028-09: sin reducir movimiento, Ajustes sigue bajando con '
        'el dedo (la hoja, como en Android)', (tester) async {
      await openSettingsScreen(tester);
      final settings = find.byType(SettingsScreen);
      final gesture = await tester.startGesture(const Offset(5, _edgeY));
      var stamp = 0;
      for (var i = 0; i < 20; i++) {
        stamp += 16;
        await gesture.moveBy(
          const Offset(10, 0),
          timeStamp: Duration(milliseconds: stamp),
        );
        await tester.pump();
      }
      expect(tester.getTopLeft(settings).dy, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
    }, variant: ios);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('P6 / CA-028-21: con reducir movimiento, «Todo hecho.» → '
          '«Nueva tarea» abre el editor con el fundido corto, sin deslizar '
          '(${platform.name})', (tester) async {
        final repo = InMemoryTaskRepository();
        await repo.insert(sampleTask(id: 'a', rank: 'a'));
        await repo.remove('a');
        await pumpUnaApp(tester, repo: repo, reduced: true);
        expect(find.byType(AllDoneScreen), findsOneWidget);
        await tester.tap(find.byType(BrutalButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final editor = find.byType(TaskEditorScreen);
        final route = ModalRoute.of(tester.element(editor))! as PageRoute;
        expect(
          route.transitionDuration,
          lessThanOrEqualTo(UnaMotion.reducedMotionFade),
        );
        for (var t = 0; t < 30; t++) {
          expect(
            slidesAbove(tester, editor).where((o) => o != Offset.zero),
            isEmpty,
          );
          expect(tester.getTopLeft(editor), Offset.zero);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(route.animation!.status, AnimationStatus.completed);
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('CA-028-09: en Android, el mismo gesto no cierra Ajustes', (
      tester,
    ) async {
      await openSettingsScreen(tester);
      await swipeBack(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
