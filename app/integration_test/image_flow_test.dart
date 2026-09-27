// Flujo completo con imagen en el emulador (spec 007, T-007-23): canal nativo,
// almacén en disco e interfaz reales. Solo el selector se sustituye: en lugar
// de abrir la galería o la cámara (otra app, fuera del alcance del test),
// entrega un fichero de prueba con `debugCopyFile`. La cámara y el selector
// reales se prueban a mano (specs/007-adjunto-imagen/dispositivo.md).
//
//   flutter test integration_test/image_flow_test.dart -d emulator-5554
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/native_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/image_viewer_screen.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/task_image.dart';
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

import 'support/fixture_importer.dart';

late Directory _support;
late Directory _cache;
late FixtureImporter _importer;

/// Solo en las apps de pruebas (`.debug`, `.profile`): nunca borra datos
/// reales.
Future<void> _wipe() async {
  final docs = await getApplicationDocumentsDirectory();
  if (!docs.path.contains('.debug') && !docs.path.contains('.profile')) {
    throw StateError('Pruebas de integración fuera de la app .debug: $docs');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${docs.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  for (final d in [
    Directory('${_support.path}/attachments'),
    Directory('${_cache.path}/import'),
    Directory('${_cache.path}/fixtures'),
  ]) {
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
}

Future<ImageServices> _openImages() async {
  final real = await openImageServices();
  _importer = FixtureImporter(real.importer as NativeImageImporter, _cache);
  return (store: real.store, images: real.images, importer: _importer);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeRouter)));

/// (+) → fila [row] de la hoja → espera a que la imagen esté preparada.
Future<void> _attach(WidgetTester tester, String row) async {
  final l10n = _l10n(tester);
  await tester.tap(find.bySemanticsLabel(l10n.attachButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(row));
  // La limpieza nativa tarda de verdad: se espera sin reloj falso.
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final preview = find.byType(AttachmentPreview);
    if (preview.evaluate().isNotEmpty &&
        find
            .descendant(of: preview, matching: find.byType(Image))
            .evaluate()
            .isNotEmpty &&
        find.text(l10n.imagePreparing).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
  expect(find.byType(AttachmentPreview), findsOneWidget);
}

Future<void> _saveEditor(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly).last,
  );
  await tester.pumpAndSettle();
}

/// Desmonta la app y cierra la BD (antes de rearrancar o de borrarla).
Future<void> _shutdown(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await repo.db.close();
}

List<String> _files(Directory d) => d.existsSync()
    ? (d
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort())
    : const [];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _support = await getApplicationSupportDirectory();
    _cache = await getTemporaryDirectory();
  });

  testWidgets('CA-007-02/05/07/08/09, CA-007-19: foto → tarea actual → visor; '
      'restaurada sin archivos, "Adjunto no disponible" y eliminar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _wipe();
    await bootstrap(openImages: _openImages);
    await tester.pumpAndSettle();

    // Primera tarea con una foto (con GPS y EXIF), sin texto.
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    await _attach(tester, _l10n(tester).attachTakePhoto);
    await _saveEditor(tester);

    expect(find.byType(CurrentTaskScreen), findsOneWidget);
    expect(find.byType(TaskImage), findsOneWidget);
    final repo =
        _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
    final task = (await repo.currentTask())!;
    final attachment = task.attachment!;
    expect(attachment.origin, AttachmentOrigin.camera);
    expect(task.text, isNull);

    // En disco: teselas, pantalla y miniatura; ni original ni temporales.
    final dir = Directory('${_support.path}/${attachment.dir}');
    expect(_files(dir), ['full-0-0.jpg', 'screen.jpg', 'thumb.jpg']);
    expect(_files(Directory('${_cache.path}/import')), isEmpty);
    expect(
      Directory('${_cache.path}/import').listSync().whereType<Directory>(),
      isEmpty,
    );

    // Visor: se abre al tocar, amplía con doble toque y se cierra.
    await tester.tap(find.byType(TaskImage));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.bySemanticsLabel(_l10n(tester).viewerClose));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);

    // Restauración sin imágenes (copia en la nube, ADR-0004): la BD tiene
    // la tarea, pero sus archivos no están.
    await _shutdown(tester);
    dir.deleteSync(recursive: true);
    await bootstrap(openImages: _openImages);
    await tester.pumpAndSettle();
    expect(find.byType(MissingAttachmentCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Sin texto, su única acción es eliminar (con confirmación).
    final l10n = _l10n(tester);
    await tester.tap(find.text(l10n.deleteA11yAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is BrutalButton && w.label == l10n.deleteConfirm,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AllDoneScreen), findsOneWidget);
    await _shutdown(tester);
    semantics.dispose();
  });

  testWidgets('CL-007-2: una captura de 1080 × 20 000 se ve al ancho y se '
      'desplaza en vertical en el visor', (tester) async {
    await _wipe();
    await bootstrap(openImages: _openImages);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    _importer.next = 'tall_1080x20000.png';
    await _attach(tester, _l10n(tester).attachPickImage);
    await tester.enterText(find.byType(TextField), 'Horario');
    await _saveEditor(tester);

    final task = (await _container(tester)
        .read(taskRepositoryProvider)
        .currentTask())!;
    expect(task.attachment!.tiles.rows, 5);

    await tester.tap(find.byType(TaskImage));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    Offset translation() {
      final t = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .getTranslation();
      return Offset(t.x, t.y);
    }

    await tester.drag(viewer, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(translation().dy, lessThan(-1000));
    expect(translation().dx, 0);
    await _shutdown(tester);
  });
}
