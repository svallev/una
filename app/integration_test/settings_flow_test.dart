import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Ajustes de punta a punta en el dispositivo (spec 015, T-015-13): el idioma
/// elegido y la pantalla siempre activa se guardan y, tras un rearranque (el
/// proceso nuevo lee los ajustes antes del primer fotograma), la primera
/// pantalla ya sale en ese idioma (CA-015-08, CA-015-09, CA-015-04). La spec 017
/// añade "Bloquear zoom": se enciende, se guarda y sobrevive a un rearranque
/// (CA-017-03, CA-017-11).

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

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(HomeRouter, skipOffstage: false)),
);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomeRouter, skipOffstage: false)),
);

/// Primera tarea desde la bienvenida, como un usuario.
Future<void> _firstTask(WidgetTester tester) async {
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
  expect(find.byType(CurrentTaskScreen), findsOneWidget);
}

/// Menú de la tarea → Ajustes (nivel 1).
Future<void> _openSettings(WidgetTester tester) async {
  final l10n = _l10n(tester);
  await tester.tap(find.bySemanticsLabel(l10n.menuButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.menuSettings));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

/// Cierra la aplicación entera y la vuelve a abrir sobre la misma base de
/// datos (como al matar el proceso).
Future<void> _restart(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await repo.db.close();
  await bootstrap();
  await tester.pumpAndSettle();
}

Future<void> _closeAll(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await repo.db.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'CA-015-08/09: cambiar el idioma en Ajustes cambia la app en el acto y, '
    'tras rearrancar, la primera pantalla ya está en ese idioma',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _firstTask(tester);
      // Se parte de "Como el sistema" (por defecto).
      expect(
        _container(tester).read(settingsProvider).locale,
        LocaleChoice.system,
      );
      final system = _l10n(tester).localeName;
      // Se elige el contrario del que da el sistema para que el cambio se vea.
      final (choice, name, expected) = system == 'es'
          ? (LocaleChoice.en, 'English', 'en')
          : (LocaleChoice.es, 'Español', 'es');

      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsLanguage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePage), findsOneWidget);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      // De vuelta en Ajustes, ya en el idioma elegido, y guardado.
      expect(find.byType(LanguagePage), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_l10n(tester).localeName, expected);
      expect(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsTitle),
        ),
        findsOneWidget,
      );
      expect(_container(tester).read(settingsProvider).locale, choice);
      final repo = _container(
        tester,
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      expect(await repo.locale(), choice);

      // Rearranque: la primera pantalla ya está en el idioma elegido, sin
      // pasar por el del sistema.
      await _restart(tester);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(_l10n(tester).localeName, expected);
      expect(_container(tester).read(settingsProvider).locale, choice);

      // Se deja como estaba ("Como el sistema") y se comprueba que vuelve.
      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsLanguage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).settingsLanguageSystem));
      await tester.pumpAndSettle();
      expect(_l10n(tester).localeName, system);
      expect(
        _container(tester).read(settingsProvider).locale,
        LocaleChoice.system,
      );
      await _closeAll(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'CA-015-03/04: "Pantalla siempre activa" se enciende, se guarda y '
    'sobrevive a un rearranque',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _firstTask(tester);
      expect(_container(tester).read(settingsProvider).keepScreenOn, isFalse);

      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsKeepAwake),
        ),
      );
      await tester.pumpAndSettle();
      expect(_container(tester).read(settingsProvider).keepScreenOn, isTrue);
      final repo = _container(
        tester,
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      expect(await repo.keepScreenOn(), isTrue);

      await _restart(tester);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(_container(tester).read(settingsProvider).keepScreenOn, isTrue);

      // Se apaga otra vez y se guarda.
      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsKeepAwake),
        ),
      );
      await tester.pumpAndSettle();
      expect(_container(tester).read(settingsProvider).keepScreenOn, isFalse);
      await _closeAll(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'CA-017-03/11: "Bloquear zoom" se enciende, se guarda sin tocar los demás '
    'ajustes y sobrevive a un rearranque',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _firstTask(tester);
      expect(_container(tester).read(settingsProvider).lockZoom, isFalse);

      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsLockZoom),
        ),
      );
      await tester.pumpAndSettle();
      expect(_container(tester).read(settingsProvider).lockZoom, isTrue);
      final repo = _container(
        tester,
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      expect(await repo.lockZoom(), isTrue);
      // Cada ajuste tiene su clave: los otros no se tocan.
      expect(await repo.keepScreenOn(), isFalse);
      expect(await repo.locale(), LocaleChoice.system);

      // Rearranque: el proceso nuevo lee el valor antes del primer fotograma.
      await _restart(tester);
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(_container(tester).read(settingsProvider).lockZoom, isTrue);
      expect(_container(tester).read(settingsProvider).keepScreenOn, isFalse);

      // Se apaga otra vez, se guarda y sobrevive a otro rearranque.
      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(_l10n(tester).settingsLockZoom),
        ),
      );
      await tester.pumpAndSettle();
      expect(_container(tester).read(settingsProvider).lockZoom, isFalse);
      final repo2 = _container(
        tester,
      ).read(taskRepositoryProvider) as DriftTaskRepository;
      expect(await repo2.lockZoom(), isFalse);
      await _restart(tester);
      expect(_container(tester).read(settingsProvider).lockZoom, isFalse);
      await _closeAll(tester);
      semantics.dispose();
    },
  );
}
