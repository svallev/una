import 'dart:math';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Monta la app completa (UnaApp) con un repositorio en memoria y las tareas
/// indicadas (la primera, la actual). El sistema está en [locale] (español
/// por defecto); con [firstRunDone] a false, arranca en la bienvenida.
Future<T> pumpUnaApp<T extends InMemoryTaskRepository>(
  WidgetTester tester, {
  required T repo,
  List<String> tasks = const [],
  Locale locale = const Locale('es'),
  bool firstRunDone = true,
  bool screenReader = false,
  bool reduced = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  Clock? clock,
  List<Override> overrides = const [],
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (screenReader || reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          accessibleNavigation: screenReader,
          disableAnimations: reduced,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  for (final (i, text) in tasks.indexed) {
    await repo.insert(
      // Claves de orden válidas (sin "0" final): MB, MC, MD…
      sampleTask(
        id: 't$i',
        text: text,
        rank: 'M${String.fromCharCode(66 + i)}',
        colorKey: i % 5,
      ),
    );
  }
  if (firstRunDone) await repo.setFirstRunDone();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        bootStateProvider.overrideWithValue(
          // Como el arranque real (main.dart), con el primer uso hecho.
          await readBootState(repo, repo),
        ),
        colorPickerProvider.overrideWithValue(ColorPicker(Random(0))),
        if (clock != null) clockProvider.overrideWithValue(clock),
        ...overrides,
      ],
      child: const UnaApp(),
    ),
  );
  await tester.pump();
  return repo;
}
