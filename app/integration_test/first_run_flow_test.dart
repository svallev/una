import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Falla (y lo anota) ante cualquier intento de abrir una conexión HTTP (CA-001-11).
class _NoNetwork extends HttpOverrides {
  final attempts = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts.add(StackTrace.current.toString().split('\n').take(3).join(' | '));
    throw const SocketException('Red prohibida en este test (CA-001-11)');
  }
}

/// Borra la BD real de la app para empezar como en una instalación nueva.
Future<void> _wipeDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // Solo en las apps de pruebas (`.debug`, `.profile`): nunca borra las
  // tareas reales.
  if (!dir.path.contains('.debug') && !dir.path.contains('.profile')) {
    throw StateError(
      'Pruebas de integración fuera de la app .debug: ${dir.path}',
    );
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dir.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-001-10 + CA-001-11: primer uso completo en el dispositivo, sin red, y la tarea sobrevive a un rearranque',
    (tester) async {
      final net = _NoNetwork();
      HttpOverrides.global = net;
      addTearDown(() => HttpOverrides.global = null);
      await _wipeDatabase();

      // Primer arranque: bienvenida → editor → guardar.
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeIntro), findsOneWidget);
      await tester.tap(find.byType(WelcomeIntro)); // saltar
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Llamar a Marta');
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
      );
      await tester.pumpAndSettle();
      final created = tester
          .widget<CurrentTaskScreen>(find.byType(CurrentTaskScreen))
          .task;
      expect(created.text, 'Llamar a Marta');

      // Rearranque: se cierra la conexión (como al matar el proceso) y se abre
      // otra sobre el mismo archivo en disco.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CurrentTaskScreen)),
      );
      final repo =
          container.read(taskRepositoryProvider) as DriftTaskRepository;
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeIntro), findsNothing);
      final reloaded = tester
          .widget<CurrentTaskScreen>(find.byType(CurrentTaskScreen))
          .task;
      expect(reloaded.id, created.id);
      expect(reloaded.text, created.text);
      expect(reloaded.colorKey, created.colorKey);
      expect(reloaded.rank, created.rank);

      expect(net.attempts, isEmpty, reason: 'CA-001-11: ninguna conexión');
    },
  );
}
