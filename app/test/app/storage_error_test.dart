import 'package:app/app/storage_errors.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/repository_factory.dart';
import 'package:app/features/app_error/storage_error_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets(
    'CL-001-6: si la BD no abre se ve el error recuperable y Reintentar vuelve a abrirla',
    (tester) async {
      var attempts = 0;
      Future<Repositories> open() async {
        attempts++;
        if (attempts == 1) throw StateError('SqliteException(26): not a db');
        final r = InMemoryTaskRepository();
        return (tasks: r, settings: r);
      }

      await bootstrap(open: open);
      await tester.pump();
      expect(find.byType(StorageErrorScreen), findsOneWidget);
      expect(
        tester
            .widget<StorageErrorScreen>(find.byType(StorageErrorScreen))
            .noSpace,
        isFalse,
      );

      await tester.tap(find.byType(BrutalButton));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(StorageErrorScreen), findsNothing);
      expect(find.byType(WelcomeIntro), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('CL-001-6: sin espacio se explica que falta espacio', (
    tester,
  ) async {
    await bootstrap(
      open: () async =>
          throw StateError('SqliteException(13): database or disk is full'),
    );
    await tester.pump();
    expect(
      tester
          .widget<StorageErrorScreen>(find.byType(StorageErrorScreen))
          .noSpace,
      isTrue,
    );
  });

  test('CL-001-6: reconoce los errores de falta de espacio', () {
    expect(isNoSpaceError('SqliteException(13): SQLITE_FULL'), isTrue);
    expect(isNoSpaceError('database or disk is full'), isTrue);
    expect(
      isNoSpaceError('FileSystemException: No space left on device'),
      isTrue,
    );
    expect(isNoSpaceError('OS Error: errno = 28'), isTrue);
    expect(
      isNoSpaceError('SqliteException(26): file is not a database'),
      isFalse,
    );
  });

  for (final noSpace in [false, true]) {
    testWidgets(
      'CL-001-9: pantalla de error al 200 % en un móvil pequeño, sin cortes y accesible (noSpace=$noSpace)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithApp(
          tester,
          StorageErrorScreen(noSpace: noSpace, onRetry: () {}),
          textScale: 2.0,
          size: const Size(360, 640),
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.byType(BrutalButton), 100);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }
}
