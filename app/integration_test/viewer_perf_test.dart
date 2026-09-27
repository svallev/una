// Memoria y fluidez del visor con la imagen más grande que se guarda (spec 007,
// T-007-23). Presupuesto (docs/architecture.md §7): el visor a ×8 añade
// < 200 MB sobre la tarea actual. Aquí es solo un aviso: la RSS del proceso
// no cuenta toda la memoria de la GPU y arrastra la importación de 50 MP. La
// medida que manda es `dumpsys meminfo` en un proceso nuevo (dispositivo.md §3).
// En el móvil, en modo profile y con permiso del propietario:
//   flutter drive --profile --no-dds --keep-app-running \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/viewer_perf_test.dart -d <serial>
// Después se desinstala a mano `invalid.pending.app.profile` (docs/testing.md).
import 'dart:io';

import 'package:app/data/image_services.dart';
import 'package:app/data/import/native_image_importer.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/image_viewer_screen.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/fixture_importer.dart';

int _mb(int bytes) => bytes ~/ (1024 * 1024);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('rendimiento: visor con una imagen de 24 MP hasta ×8', (
    tester,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    // Solo en la app de pruebas: nunca borra las tareas reales.
    if (!docs.path.contains('.profile') && !docs.path.contains('.debug')) {
      throw StateError('Fuera de la app de pruebas: ${docs.path}');
    }
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${docs.path}/una.sqlite$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final cache = await getTemporaryDirectory();
    Future<ImageServices> openImages() async {
      final real = await openImageServices();
      final importer = FixtureImporter(
        real.importer as NativeImageImporter,
        cache,
      )..next = 'px50.png'; // 50 MP → se guarda a 24 MP
      return (store: real.store, images: real.images, importer: importer);
    }

    await bootstrap(openImages: openImages);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.bySemanticsLabel(l10n.attachButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.attachPickImage));
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(l10n.imagePreparing).evaluate().isEmpty &&
          find.byType(AttachmentPreview).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly).last,
    );
    await tester.pumpAndSettle();

    final rssBefore = ProcessInfo.currentRss;
    await tester.tap(find.byType(TaskImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    final center = tester.getCenter(find.byType(InteractiveViewer));

    // Doble toque: ×2,5 y ×8, con desplazamientos ampliada.
    await binding.watchPerformance(() async {
      for (var step = 0; step < 2; step++) {
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(InteractiveViewer),
          const Offset(-300, -600),
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'viewer_zoom_frames');

    // Deja que se decodifiquen las teselas a ×8 y mide.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final rssAtX8 = ProcessInfo.currentRss;
    binding.reportData = {
      ...?binding.reportData,
      'viewer_memory_mb': {
        'rss_before_viewer': _mb(rssBefore),
        'rss_at_x8': _mb(rssAtX8),
        'viewer_added': _mb(rssAtX8 - rssBefore),
        // Pico de todo el proceso, importación incluida: solo informativo.
        'max_rss': _mb(ProcessInfo.maxRss),
      },
    };
    // Si falla, el driver no escribe el informe: las cifras quedan en el log.
    debugPrint('viewer_memory_mb: ${binding.reportData!['viewer_memory_mb']}');
    expect(_mb(rssAtX8 - rssBefore), lessThan(200));
  });
}
