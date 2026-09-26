import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
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

/// Menú → Eliminar → Eliminar, con los textos del idioma del dispositivo.
Future<void> _deleteFromMenu(WidgetTester tester) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(CurrentTaskScreen)),
  );
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.menuDelete));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-004-03/07/08/09: eliminar en el dispositivo no deja contenido y al rearrancar se ve "Todo hecho."',
    (tester) async {
      // El menú se busca por su etiqueta accesible.
      final semantics = tester.ensureSemantics();
      await _wipeDatabase();
      await bootstrap();
      await tester.pumpAndSettle();
      // Primera tarea desde la bienvenida, como un usuario.
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
      final repo =
          container.read(taskRepositoryProvider) as DriftTaskRepository;
      final first = (await repo.currentTask())!;
      expect(first.text, 'Llamar a Marta');

      await _deleteFromMenu(tester);
      expect(find.byType(AllDoneScreen), findsOneWidget);
      final gone = (await repo.findById(first.id))!;
      expect(gone.deletedAt, isNotNull);
      expect(gone.text, isNull);

      // Rearranque: sin pendientes y con una eliminada → "Todo hecho.".
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
      await bootstrap();
      await tester.pumpAndSettle();
      expect(find.byType(AllDoneScreen), findsOneWidget);
      expect(find.byType(CurrentTaskScreen), findsNothing);
      semantics.dispose();
    },
  );
}
