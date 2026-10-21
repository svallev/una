import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/undo_card.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_harness.dart';
import '../support/app_harness.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';
import '../support/undo.dart';

/// Spec 021, CA-021-09 (plan §1.3, §5): con la app abierta las barras del sistema son
/// transparentes (detrás se ve el fondo de la app), con iconos oscuros y sin el velo que
/// añade el sistema, igual con el sistema en claro y en oscuro.
///
/// [Hecho, T-021-03, leído en `PlatformPlugin.java` del motor de Flutter 3.47.5] los iconos
/// oscuros de la barra de navegación se piden con
/// `WindowInsetsControllerCompat.setAppearanceLightNavigationBars(true)` desde API 26
/// (`if (SDK_INT >= API_26)`), así que también en Android 8.0 (P-021-2).
void main() {
  setUpAll(loadAppFonts);

  const transparent = Color(0x00000000);

  /// Qué espera CA-021-09 de cada barra: la misma regla para todas las pantallas.
  void expectLightBars() {
    final style = SystemChrome.latestStyle;
    expect(style, isNotNull, reason: 'la app debe pedir un estilo de barras');
    expect(style!.statusBarColor, transparent);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemStatusBarContrastEnforced, isFalse);
    expect(style.systemNavigationBarColor, transparent);
    expect(style.systemNavigationBarDividerColor, transparent);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
  }

  /// El estilo pedido se guarda en una variable estática del motor que sobrevive entre tests:
  /// se borra (como al desprender la app) para que un test no pase con lo que dejó otro.
  Future<void> forgetStyle(WidgetTester tester) async {
    SystemChrome.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(SystemChrome.latestStyle, isNull);
  }

  void setBrightness(WidgetTester tester, Brightness brightness) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'oscuro' : 'claro';

    group('sistema en $mode', () {
      testWidgets('CA-021-09: la tarea actual', (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
        );
        await tester.pump();
        expectLightBars();
      });

      testWidgets('CA-021-09: la bienvenida', (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          firstRunDone: false,
        );
        await tester.pump();
        expect(find.byType(WelcomeIntro), findsOneWidget);
        expectLightBars();
      });

      testWidgets('CA-021-09: el editor', (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await pumpUnaApp(tester, repo: InMemoryTaskRepository());
        await tester.pump();
        expect(find.byType(TaskEditorScreen), findsOneWidget);
        expectLightBars();
      });

      testWidgets('CA-021-09: "Todo hecho."', (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        final repo = InMemoryTaskRepository();
        await repo.insert(sampleTask(id: 'a', rank: 'a'));
        await repo.remove('a');
        await repo.setFirstRunDone();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskRepositoryProvider.overrideWithValue(repo),
              settingsRepositoryProvider.overrideWithValue(repo),
              bootStateProvider.overrideWithValue(
                BootState(
                  currentTask: null,
                  firstRunDone: true,
                  hasEverHadTasks: await repo.hasEverHadTasks(),
                ),
              ),
            ],
            child: const UnaApp(),
          ),
        );
        await tester.pump();
        expect(find.byType(AllDoneScreen), findsOneWidget);
        expectLightBars();
      });

      testWidgets('CA-021-09: Ajustes', (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await openSettingsScreen(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expectLightBars();
      });

      testWidgets('CA-021-09: el error al abrir el almacenamiento', (
        tester,
      ) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await tester.pumpWidget(
          StorageErrorApp(noSpace: false, onRetry: () {}),
        );
        await tester.pump();
        expect(find.byType(StorageErrorScreen), findsOneWidget);
        expectLightBars();
      });
    });
  }

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'oscuro' : 'claro';

    // La enhorabuena pinta `ink` a sangre bajo las dos barras: allí los iconos son claros
    // (CA-021-09, tercer punto) y, al terminar, vuelven los oscuros.
    testWidgets(
      'CA-021-09: la enhorabuena (fondo oscuro tras las barras) pide iconos claros, con el sistema en $mode',
      (tester) async {
        setBrightness(tester, brightness);
        await forgetStyle(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera', 'Segunda'],
        );
        await tester.pump();
        expectLightBars();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(HoldToCompleteButton)),
        );
        await tester.pump();
        await tester.pump(UnaMotion.holdToComplete);
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(UnaMotion.holdDonePause);
        await tester.pump(UnaMotion.tear ~/ 2);
        expect(find.byType(CelebrationOverlay), findsOneWidget);

        final style = SystemChrome.latestStyle!;
        expect(style.statusBarColor, transparent);
        expect(style.statusBarIconBrightness, Brightness.light);
        expect(style.systemNavigationBarColor, transparent);
        expect(style.systemNavigationBarIconBrightness, Brightness.light);
        expect(style.systemStatusBarContrastEnforced, isFalse);
        expect(style.systemNavigationBarContrastEnforced, isFalse);

        await tester.pump(UnaMotion.tear);
        await tester.pump(UnaMotion.successHold);
        await tester.pump(UnaMotion.successFade);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(UnaMotion.introFade);
        expect(find.byType(CelebrationOverlay), findsNothing);
        expectLightBars();
      },
    );
  }

  testWidgets(
    'CA-021-09: el estilo se envía de verdad al sistema por el canal de plataforma',
    (tester) async {
      await forgetStyle(tester);
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera'],
      );
      await tester.pump();
      final sent = calls
          .where((c) => c.method == 'SystemChrome.setSystemUIOverlayStyle')
          .map((c) => c.arguments as Map<Object?, Object?>)
          .toList();
      expect(sent, isNotEmpty);
      expect(sent.last['statusBarIconBrightness'], 'Brightness.dark');
      expect(sent.last['systemNavigationBarIconBrightness'], 'Brightness.dark');
      expect(sent.last['systemNavigationBarContrastEnforced'], isFalse);
      expect(sent.last['systemStatusBarContrastEnforced'], isFalse);
    },
  );

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'oscuro' : 'claro';

    testWidgets(
      'CA-021-09 / P-021-1: los dos MaterialApp piden el tema claro y el tema es claro con el sistema en $mode',
      (tester) async {
        setBrightness(tester, brightness);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
        );
        await tester.pump();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.light,
        );
        expect(
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
          Brightness.light,
        );

        await tester.pumpWidget(
          StorageErrorApp(noSpace: false, onRetry: () {}),
        );
        await tester.pump();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.light,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Spec 024, CA-024-01 y 03 (H-022-04): con la card de deshacer a la vista, los
  // iconos de la barra de navegación son claros (la card es negra); la barra de
  // estado no cambia. Al irse la card, vuelve CA-021-09.
  // ---------------------------------------------------------------------------
  group('spec 024: card de deshacer', () {
    const frame = Duration(milliseconds: 16);
    Finder menuButton() => find.bySemanticsLabel('Menú de la tarea');
    final card = find.byType(UndoCard);

    /// La barra de navegación con iconos claros y la de estado como siempre.
    void expectNavLightOnCard() {
      final style = SystemChrome.latestStyle;
      expect(style, isNotNull);
      expect(style!.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, transparent);
      expect(style.systemNavigationBarDividerColor, transparent);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
      // La barra de estado no cambia (CA-021-09).
      expect(style.statusBarColor, transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemStatusBarContrastEnforced, isFalse);
    }

    Future<InMemoryTaskRepository> openApp(
      WidgetTester tester, {
      required List<String> tasks,
      double bottomInset = 24,
      Size size = const Size(390, 844),
    }) async {
      await forgetStyle(tester);
      return pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: tasks,
        bottomInset: bottomInset,
        size: size,
        clock: TesterClock(tester),
        overrides: [
          accessibilityTimeoutsProvider.overrideWithValue(
            FakeAccessibilityTimeouts(),
          ),
        ],
      );
    }

    /// Menú → Eliminar en la tarea actual y deja acabar el arrugado.
    Future<void> deleteCurrent(WidgetTester tester) async {
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump(frame);
      await tester.pump(frame);
      await tester.pump(UnaMotion.crumple);
      await tester.pump(frame);
      await tester.pump(frame);
    }

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
    }

    /// El botón "Eliminar tarea" (segundo icono) de la fila [text].
    Finder trash(String text) => find
        .descendant(
          of: find
              .ancestor(of: find.text(text), matching: find.byType(TaskListRow))
              .first,
          matching: find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_UnaIconPainter',
          ),
        )
        .at(1);

    Future<void> deleteRow(WidgetTester tester, String text) async {
      await tester.tap(trash(text));
      await tester.pump();
      await tester.pump(frame);
    }

    testWidgets(
      'CA-024-01: la card sobre la tarea actual pide iconos claros en la navegación y deja la barra de estado',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda']);
        await tester.pump();
        expectLightBars();
        await deleteCurrent(tester);
        expect(card, findsOneWidget);
        expectNavLightOnCard();
      },
    );

    testWidgets(
      'CA-024-01 / CL-024-1: la card sobre "Todo hecho." pide iconos claros en la navegación',
      (tester) async {
        await openApp(tester, tasks: ['Única']);
        await deleteCurrent(tester);
        expect(find.byType(AllDoneScreen), findsOneWidget);
        expect(card, findsOneWidget);
        expectNavLightOnCard();
      },
    );

    testWidgets(
      'CA-024-01: la card en el listado pide iconos claros en la navegación',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
        await openList(tester);
        expectLightBars();
        await deleteRow(tester, 'Segunda');
        expect(card, findsOneWidget);
        expectNavLightOnCard();
      },
    );

    testWidgets(
      'CA-024-01 / CL-024-2: una card que sustituye a otra no deja ni un fotograma con iconos oscuros',
      (tester) async {
        await openApp(
          tester,
          tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta'],
        );
        await openList(tester);
        await deleteRow(tester, 'Segunda');
        expectNavLightOnCard();
        // Pasada la guarda de la card (CL-014-2), otra eliminación.
        await tester.pump(UnaMotion.doubleTapWindow + frame);
        await tester.tap(trash('Tercera'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(frame);
          expectNavLightOnCard();
        }
        expect(
          find.descendant(of: card, matching: find.text('Tercera')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CA-024-01 / CL-024-4: con la barra de navegación a un lado (sin margen abajo) la navegación sigue oscura',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda'], bottomInset: 0);
        await deleteCurrent(tester);
        expect(card, findsOneWidget);
        expectLightBars();
      },
    );

    testWidgets(
      'CA-024-01 / CL-024-4: con la card más estrecha que la pantalla la navegación sigue oscura',
      (tester) async {
        await openApp(
          tester,
          tasks: ['Primera', 'Segunda'],
          size: const Size(800, 400),
        );
        await deleteCurrent(tester);
        expect(card, findsOneWidget);
        expect(tester.getSize(card).width, lessThan(800));
        expectLightBars();
      },
    );

    testWidgets(
      'CA-024-01 / CL-024-4: girar con la card visible mantiene la regla de cada forma',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda']);
        await deleteCurrent(tester);
        expectNavLightOnCard();
        // Horizontal con tres botones a un lado: sin margen abajo.
        tester.view
          ..physicalSize = const Size(844, 390)
          ..padding = FakeViewPadding.zero
          ..viewPadding = FakeViewPadding.zero;
        await tester.pump(frame);
        await tester.pump(frame);
        expect(card, findsOneWidget);
        expectLightBars();
        // De vuelta a vertical.
        tester.view
          ..physicalSize = const Size(390, 844)
          ..padding = const FakeViewPadding(bottom: 24)
          ..viewPadding = const FakeViewPadding(bottom: 24);
        await tester.pump(frame);
        await tester.pump(frame);
        expectNavLightOnCard();
      },
    );

    testWidgets(
      'CA-024-03: al caducar la card vuelven los iconos oscuros en el mismo fotograma',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda']);
        await deleteCurrent(tester);
        expectNavLightOnCard();
        var gone = false;
        for (var i = 0; i < 400 && !gone; i++) {
          await tester.pump(frame);
          gone = card.evaluate().isEmpty;
          if (gone) {
            expectLightBars();
          } else {
            expectNavLightOnCard();
          }
        }
        expect(gone, isTrue);
      },
    );

    testWidgets('CA-024-03: al tocar "Deshacer" vuelven los iconos oscuros', (
      tester,
    ) async {
      await openApp(tester, tasks: ['Primera', 'Segunda']);
      await deleteCurrent(tester);
      expectNavLightOnCard();
      await tester.pump(UnaMotion.doubleTapWindow + frame);
      await tester.tap(
        find.descendant(of: card, matching: find.text('Deshacer')),
      );
      await tester.pump();
      await tester.pump(frame);
      expect(card, findsNothing);
      expectLightBars();
      // La restauración de la tarea deja un temporizador corto.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'CA-024-03 / CL-024-3: al pasar a segundo plano la card se da por terminada y vuelven los iconos oscuros',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda']);
        await deleteCurrent(tester);
        expectNavLightOnCard();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(frame);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(frame);
        expect(card, findsNothing);
        expectLightBars();
      },
    );

    testWidgets(
      'CA-024-03: al salir de la pantalla (abrir el listado) vuelven los iconos oscuros',
      (tester) async {
        await openApp(tester, tasks: ['Primera', 'Segunda', 'Tercera']);
        await deleteCurrent(tester);
        expectNavLightOnCard();
        await tester.pump(UnaMotion.doubleTapWindow + frame);
        await tester.tap(menuButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todas mis tareas'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskListScreen), findsOneWidget);
        expect(card, findsNothing);
        expectLightBars();
      },
    );
  });
}
