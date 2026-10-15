import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_harness.dart';
import '../support/app_harness.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

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
}
