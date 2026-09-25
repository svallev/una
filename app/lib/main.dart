import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/font_licenses.dart';
import 'app/providers.dart';
import 'app/storage_errors.dart';
import 'app/una_app.dart';
import 'data/repository_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await bootstrap();
}

/// Abre el almacenamiento y lee la tarea actual ANTES del primer fotograma (P2,
/// CA-001-09): la primera pantalla ya es la tarea, sin "cargando".
/// [open] se sustituye en los tests para simular fallos de disco (CL-001-6).
Future<void> bootstrap({
  Future<Repositories> Function() open = openRepositories,
}) async {
  try {
    final repos = await open();
    final boot = BootState(
      currentTask: await repos.tasks.currentTask(),
      firstRunDone: await repos.settings.firstRunDone(),
    );
    runApp(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repos.tasks),
          settingsRepositoryProvider.overrideWithValue(repos.settings),
          bootStateProvider.overrideWithValue(boot),
        ],
        child: const UnaApp(),
      ),
    );
  } on Object catch (e) {
    runApp(
      StorageErrorApp(
        noSpace: isNoSpaceError(e),
        onRetry: () => bootstrap(open: open),
      ),
    );
  }
}
