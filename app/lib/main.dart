import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/storage_errors.dart';
import 'app/una_app.dart';
import 'data/image_services.dart';
import 'data/repository_factory.dart';
import 'features/attachments/pdf_boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
}

/// Abre el almacenamiento y lee la tarea actual ANTES del primer fotograma (P2,
/// CA-001-09): la primera pantalla ya es la tarea, sin "cargando". Con un PDF,
/// también su posición y su versión de pantalla (CA-008-08).
/// [open] se sustituye en los tests para simular fallos de disco (CL-001-6).
Future<void> bootstrap({
  Future<Repositories> Function() open = openRepositories,
  Future<ImageServices> Function() openImages = openImageServices,
}) async {
  try {
    final repos = await open();
    final images = await openImages();
    final boot = await readBootState(repos.tasks, repos.settings);
    // Con un PDF, su posición y su versión de pantalla (CA-008-08).
    final pdfSeed = await readPdfBootSeed(
      task: boot.currentTask,
      store: images.store,
      images: images.images,
    );
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
          pdfBootSeedProvider.overrideWithValue(pdfSeed),
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
