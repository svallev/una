import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/font_licenses.dart';
import 'app/providers.dart';
import 'app/storage_errors.dart';
import 'app/una_app.dart';
import 'data/image_services.dart';
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
  Future<ImageServices> Function() openImages = openImageServices,
}) async {
  try {
    final repos = await open();
    final images = await openImages();
    final boot = await readBootState(repos.tasks, repos.settings);
    runApp(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repos.tasks),
          settingsRepositoryProvider.overrideWithValue(repos.settings),
          attachmentStoreProvider.overrideWithValue(images.store),
          attachmentImagesProvider.overrideWithValue(images.images),
          imageImporterProvider.overrideWithValue(images.importer),
          pdfImporterProvider.overrideWithValue(images.pdfImporter),
          bootStateProvider.overrideWithValue(boot),
        ],
        child: const UnaApp(),
      ),
    );
  } on Object catch (e) {
    runApp(
      StorageErrorApp(
        noSpace: isNoSpaceError(e),
        onRetry: () => bootstrap(open: open, openImages: openImages),
      ),
    );
  }
}
