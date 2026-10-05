import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/undo.dart';

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

/// Menú → Eliminar: sin confirmación; se espera al final del arrugado, que es
/// cuando aparece la card de deshacer (CA-014-01).
Future<void> _deleteFromMenu(WidgetTester tester) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(CurrentTaskScreen)),
  );
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.menuDelete));
  // Sin hoja: la eliminación empieza al tocar.
  await pumpUntilCard(tester);
}

/// Primera tarea desde la bienvenida, como un usuario.
Future<(DriftTaskRepository, Task)> _firstTask(WidgetTester tester) async {
  await _wipeDatabase();
  await bootstrap();
  await tester.pumpAndSettle();
  await tester.tap(find.byType(WelcomeIntro));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Llamar a Marta');
  await tester.pump();
  await tester.tap(
    find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeRouter)),
  );
  final repo = container.read(taskRepositoryProvider) as DriftTaskRepository;
  final first = (await repo.currentTask())!;
  expect(first.text, 'Llamar a Marta');
  return (repo, first);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-004-03/07/08/09 (ADR-0012): eliminar en el dispositivo borra la '
    'tarea y al rearrancar se ve "Todo hecho."',
    (tester) async {
      // El menú se busca por su etiqueta accesible.
      final semantics = tester.ensureSemantics();
      final (repo, first) = await _firstTask(tester);
      await _deleteFromMenu(tester);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(await repo.findById(first.id), isNull);

      // Rearranque: sin pendientes, pero ya hubo una tarea → "Todo hecho.".
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(find.byType(CurrentTaskScreen), findsNothing);
      final reopened = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      await tester.pumpWidget(const SizedBox());
      await reopened.db.close();
      semantics.dispose();
    },
  );

  testWidgets(
    'CA-014-09/15: deshacer devuelve la tarea a su sitio y, si pasa el '
    'tiempo, la eliminación es definitiva y se rearranca en "Todo hecho."',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final (repo, first) = await _firstTask(tester);

      // Deshacer: la misma tarea (id y posición) vuelve a la pantalla.
      await _deleteFromMenu(tester);
      expect(await repo.findById(first.id), isNull);
      // La guarda de 350 ms contra toques de rebote (CL-014-2).
      await pumpFor(tester, UnaMotion.doubleTapWindow * 2);
      await tester.tap(undoButtonFinder);
      await pumpUntil(
        tester,
        () => find.byType(CurrentTaskScreen).evaluate().isNotEmpty,
        reason: 'la tarea recuperada',
      );
      await pumpUntilCardGone(tester);
      final back = (await repo.currentTask())!;
      expect(back.id, first.id);
      expect(back.rank, first.rank);
      expect(back.text, 'Llamar a Marta');
      expect(find.byType(AllDoneScreen), findsNothing);

      // Sin deshacer: la card caduca y la fila sigue sin estar.
      await _deleteFromMenu(tester);
      await pumpUntilCardGone(tester);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(await repo.findById(first.id), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      semantics.dispose();
    },
  );
}
