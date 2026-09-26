import 'dart:math';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/color_picker.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Monta la app completa (UnaApp) en español con un repositorio en memoria y
/// las tareas indicadas (la primera, la actual).
Future<T> pumpUnaApp<T extends InMemoryTaskRepository>(
  WidgetTester tester, {
  required T repo,
  List<String> tasks = const [],
  bool screenReader = false,
  bool reduced = false,
  Clock? clock,
}) async {
  tester.platformDispatcher.localesTestValue = const [Locale('es')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view
    ..physicalSize = const Size(390, 844)
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
  await repo.setFirstRunDone();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        bootStateProvider.overrideWithValue(
          BootState(currentTask: await repo.currentTask(), firstRunDone: true),
        ),
        colorPickerProvider.overrideWithValue(ColorPicker(Random(0))),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      child: const UnaApp(),
    ),
  );
  await tester.pump();
  return repo;
}
