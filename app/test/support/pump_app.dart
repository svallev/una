import 'package:app/app/providers.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta un widget con tema, localización y repositorio en memoria.
Future<InMemoryTaskRepository> pumpWithApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('es'),
  InMemoryTaskRepository? repo,
  bool firstRunDone = true,
  Task? currentTask,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Size size = const Size(390, 844),
}) async {
  final r = repo ?? InMemoryTaskRepository();
  // La superficie del test coincide con la pantalla simulada (por defecto es 800 × 600).
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(r),
        settingsRepositoryProvider.overrideWithValue(r),
        bootStateProvider.overrideWithValue(
          BootState(currentTask: currentTask, firstRunDone: firstRunDone),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: viewInsets,
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: UnaTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    ),
  );
  return r;
}

Task sampleTask({
  String text = 'Llamar a Marta',
  int colorKey = 1,
  String rank = 'V',
  String id = 't1',
}) {
  final now = DateTime.utc(2026, 9, 24, 10);
  return Task(
    id: id,
    text: text,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: colorKey,
    createdAt: now,
    updatedAt: now,
  );
}
