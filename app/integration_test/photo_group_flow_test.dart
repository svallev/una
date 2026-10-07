// Flujo completo con un grupo de fotos en el emulador (spec 016, T-016-22):
// crear una tarea con 3 fotos, verla en el carrusel, reiniciar la app (el
// orden se conserva) y recorrerlo. Canal nativo, almacén en disco, base de
// datos e interfaz reales; solo el selector se sustituye (entrega ficheros de
// prueba con `debugCopyFile`, como `photo_group_import_test.dart`): el
// selector del sistema se prueba a mano (`dispositivo.md`).
//
//   flutter test integration_test/photo_group_flow_test.dart -d emulator-5554
//
// **Sin red** (CA-016-17): la app no la usa y la prueba tampoco. Para probarlo
// de verdad, con el modo avión del emulador:
//   adb -s emulator-5554 shell cmd connectivity airplane-mode enable
// (y `disable` al acabar).
import 'dart:convert';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/native_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/photo_carousel.dart';
import 'package:app/features/attachments/photo_dots.dart';
import 'package:app/features/attachments/photo_stack.dart';
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

import 'fixtures/image_fixtures.g.dart';

late Directory _support;
late Directory _cache;

/// Las tres fotos de prueba, en el orden en que se eligen. Tienen medidas
/// distintas: así se sabe cuál es cuál al volver a leerlas.
const _chosen = ['photo_gps.jpg', 'tall_1080x20000.png', 'orientation_6.jpg'];

/// El canal nativo de verdad, salvo `pickMany`, que devuelve [_chosen].
class _GroupImporter implements ImageImporter {
  _GroupImporter(this.native);

  final NativeImageImporter native;

  @override
  bool get heicSupported => native.heicSupported;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async =>
      throw UnimplementedError();

  @override
  Future<PickedImages?> pickMany({required int max}) async => (
    items: [
      for (final t in _chosen) (token: t, origin: AttachmentOrigin.gallery),
    ],
    total: _chosen.length,
  );

  @override
  Future<int?> freeSpace() => native.freeSpace();

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) {
    final file = File('${_cache.path}/fixtures/${picked.token}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64.decode(imageFixtures[picked.token]!));
    return native.debugCopyFile(file.path, id, maxBytes: maxBytes);
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) => native.sanitize(
    id,
    type,
    origin,
    maxPixels: maxPixels,
    storedMaxPixels: storedMaxPixels,
  );

  @override
  Future<void> cancel(String id) => native.cancel(id);

  @override
  Future<void> regenerateDerived(Attachment attachment) =>
      native.regenerateDerived(attachment);
}

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
  return (
    store: real.store,
    images: real.images,
    importer: _GroupImporter(real.importer as NativeImageImporter),
    pdfImporter: real.pdfImporter,
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeRouter)));

/// Desmonta la app y cierra la BD (antes de rearrancar o de borrarla).
Future<void> _shutdown(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await repo.db.close();
}

/// Deja pasar el reloj real hasta que se cumpla [done] (E/S nativa).
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  String? reason,
}) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) return;
  }
  fail(reason ?? 'no se cumplió a tiempo');
}

/// Un swipe horizontal de [dx] dp sobre la foto, empezando lejos del borde
/// del sistema.
Future<void> _swipe(WidgetTester tester, double dx) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.timedDragFrom(
    Offset(dx < 0 ? size.width * 0.8 : size.width * 0.3, size.height * 0.45),
    Offset(dx, 0),
    const Duration(milliseconds: 320),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

int _shown(WidgetTester tester) =>
    tester.widget<PhotoDots>(find.byType(PhotoDots)).index;

/// Las medidas de las fotos de la tarea, en su orden.
String _sizes(Task task) =>
    task.attachments.map((a) => '${a.width}x${a.height}').join(',');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _support = await getApplicationSupportDirectory();
    _cache = await getTemporaryDirectory();
  });

  testWidgets('CA-016-02/06/09/14/15: crear un grupo de 3 fotos, verlo en el '
      'carrusel, reiniciar la app (mismo orden) y recorrerlo', (tester) async {
    // El emulador en vertical (con el sensor virtual girado, la app sale en
    // horizontal y no hay puntos): `settings put system accelerometer_rotation 0`.
    final view = tester.view;
    expect(
      view.physicalSize.height,
      greaterThan(view.physicalSize.width),
      reason: 'el dispositivo debe estar en vertical',
    );
    await _wipe();
    await bootstrap(openImages: _openImages);
    await tester.pumpAndSettle();

    // Primera tarea: (+) → "Subir imágenes" → 3 fotos → la pila.
    await tester.tap(find.byType(WelcomeIntro));
    await tester.pumpAndSettle();
    final l10n = _l10n(tester);
    await tester.tap(find.bySemanticsLabel(l10n.attachButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.attachPickImage));
    await _until(
      tester,
      () =>
          find.byType(PhotoStack).evaluate().isNotEmpty &&
          find.byType(PhotoStack).evaluate().length == 1 &&
          find.text(l10n.imagePreparingCancel).evaluate().isEmpty &&
          find.byType(AttachmentPreview).evaluate().isNotEmpty,
      reason: 'la pila de 3 fotos no llegó a verse',
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.photoCount(3)), findsOneWidget);

    // Guardar: la tarea actual muestra el carrusel, en la primera foto.
    await tester.enterText(find.byType(TextField), 'Horario del festival');
    await tester.tap(
      find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly).last,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CurrentTaskScreen), findsOneWidget);
    expect(find.byType(PhotoCarousel), findsOneWidget);
    await _until(
      tester,
      () => find.byType(PhotoDots).evaluate().isNotEmpty,
      reason: 'los puntos no llegaron a verse',
    );
    expect(_shown(tester), 0);

    final repo =
        _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
    final saved = (await repo.currentTask())!;
    expect(saved.attachments, hasLength(3));
    final ids = [for (final a in saved.attachments) a.id];
    expect(ids.toSet(), hasLength(3));
    final sizes = _sizes(saved);
    expect(
      saved.attachments.map((a) => a.height).toSet(),
      hasLength(greaterThan(1)),
      reason: 'las fotos de prueba se distinguen por sus medidas: $sizes',
    );
    // En disco: cada foto en su carpeta; ni originales ni temporales.
    for (final a in saved.attachments) {
      expect(File('${_support.path}/${a.dir}/screen.jpg').existsSync(), isTrue);
    }
    final staging = Directory('${_cache.path}/import');
    expect(
      staging.existsSync() ? staging.listSync() : const <FileSystemEntity>[],
      isEmpty,
    );

    // Reiniciar la app (sin red tampoco hace falta nada): mismas fotos, mismo
    // orden, abre en la primera.
    await _shutdown(tester);
    await bootstrap(openImages: _openImages);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCarousel), findsOneWidget);
    await _until(
      tester,
      () => find.byType(PhotoDots).evaluate().isNotEmpty,
      reason: 'los puntos no llegaron a verse tras reiniciar',
    );
    expect(_shown(tester), 0);
    final repo2 =
        _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
    final restored = (await repo2.currentTask())!;
    expect([for (final a in restored.attachments) a.id], ids);
    expect(_sizes(restored), sizes);

    // Recorrerlo: hacia delante 0 → 1 → 2 → 0 (infinito) y hacia atrás.
    final a11y = tester.ensureSemantics();
    await _swipe(tester, -250);
    expect(_shown(tester), 1);
    await _swipe(tester, -250);
    expect(_shown(tester), 2);
    await _swipe(tester, -250);
    expect(_shown(tester), 0, reason: 'la última da la primera');
    await _swipe(tester, 250);
    expect(_shown(tester), 2, reason: 'la primera, hacia atrás, da la última');
    expect(find.byType(PhotoCarousel), findsOneWidget);
    expect(tester.takeException(), isNull);
    a11y.dispose();

    await _shutdown(tester);
  });
}
