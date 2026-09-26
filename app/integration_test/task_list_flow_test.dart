// Flujo del listado en el dispositivo (spec 006, T-006-15). En el emulador:
//   flutter test integration_test/task_list_flow_test.dart -d emulator-5554
// En el móvil del propietario, nunca sin --keep-app-running (flutter drive
// desinstala la app al terminar) y solo contra la app de pruebas (.debug).
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/queue_position.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

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

/// Asa (botón "Mover") de la fila con [text].
Finder _handleOf(String text) => find.descendant(
  of: find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'TaskListRow',
    ),
  ),
  matching: find.byWidgetPredicate(
    (w) =>
        w is CustomPaint && w.painter.runtimeType.toString() == '_GripPainter',
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-006-01/04/06/10: abrir el listado, llevar una tarea arriba arrastrando y que persista',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _wipeDatabase();
      await bootstrap();
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      await container.read(settingsRepositoryProvider).setFirstRunDone();
      final create = container.read(createTaskProvider);
      for (final t in ['Llamar a Marta', 'Comprar pan', 'Regar las plantas']) {
        await create.call(t, position: QueuePosition.end);
      }
      // Rearranque con las tareas ya creadas.
      final created =
          container.read(taskRepositoryProvider) as DriftTaskRepository;
      await tester.pumpWidget(const SizedBox());
      await created.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CurrentTaskScreen)),
      );

      await tester.tap(find.bySemanticsLabel(l10n.menuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.menuAllTasks));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);

      // Arrastrar "Regar las plantas" por encima de la primera.
      final g = await tester.startGesture(
        tester.getCenter(_handleOf('Regar las plantas')),
      );
      final top = tester.getTopLeft(find.text('Llamar a Marta')).dy;
      for (
        var y = tester.getCenter(_handleOf('Regar las plantas')).dy;
        y > top - 30;
        y -= 20
      ) {
        await g.moveTo(
          Offset(tester.getCenter(find.text('Llamar a Marta')).dx, y),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.listBack));
      await tester.pumpAndSettle();
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(find.text('Regar las plantas'), findsOneWidget);

      // Rearranque: el orden se ha guardado.
      container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      final repo =
          container.read(taskRepositoryProvider) as DriftTaskRepository;
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.text('Regar las plantas'), findsOneWidget);
      container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      final order = [
        for (final t
            in await container.read(taskRepositoryProvider).pendingTasks())
          t.text,
      ];
      expect(order, ['Regar las plantas', 'Llamar a Marta', 'Comprar pan']);
      semantics.dispose();
    },
  );
}
