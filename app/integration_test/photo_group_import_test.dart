// Importación nativa de un grupo de fotos (spec 016, T-016-08). En el
// emulador (nunca en el móvil del propietario sin su permiso):
//   flutter test integration_test/photo_group_import_test.dart -d emulator-5554
//
// El selector del sistema es de otra app y no se puede conducir desde aquí:
// los tests de abajo sustituyen solo `pickMany` (entregan ficheros de prueba
// con `debugCopyFile`) y usan el canal nativo, el almacén y el barrido reales.
// Los dos últimos abren el selector **de verdad** y solo corren con
// `--dart-define=UNA_PICKER=photos` o `=documents` (los maneja `adb`, ver
// specs/016-varias-imagenes-carrusel/dispositivo.md).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/import/native_image_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/import_budget.dart';
import 'package:app/domain/usecases/import_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'fixtures/image_fixtures.g.dart';

const _picker = String.fromEnvironment('UNA_PICKER');

late NativeImageImporter _native;
late Directory _cache;
late AttachmentJanitor _janitor;
late ImportRegistry _registry;

/// Token que no acaba nunca: `/dev/urandom` hasta que se cancele.
const _hang = '__hang__';

/// Importador de pruebas: el canal nativo de verdad, salvo `pickMany`, que
/// devuelve los ficheros de prueba [next] (o un token propio).
class _GroupImporter implements ImageImporter {
  List<String> next = const [];
  var total = 0;

  @override
  bool get heicSupported => _native.heicSupported;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) =>
      throw UnimplementedError();

  @override
  Future<PickedImages?> pickMany({required int max}) async => (
    items: [
      for (final t in next.take(max))
        (token: t, origin: AttachmentOrigin.gallery),
    ],
    total: total == 0 ? next.length : total,
  );

  @override
  Future<int?> freeSpace() => _native.freeSpace();

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) {
    final token = picked.token;
    if (token == _hang) {
      return _native.debugCopyFile('/dev/urandom', id, maxBytes: 1 << 40);
    }
    // Una dirección de verdad: el nativo la rechaza (T-8) sin abrirla.
    if (token.contains('://')) {
      return _native.copy(picked, id, maxBytes: maxBytes);
    }
    final file = File('${_cache.path}/fixtures/$token')
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64.decode(imageFixtures[token]!));
    return _native.debugCopyFile(file.path, id, maxBytes: maxBytes);
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) => _native.sanitize(
    id,
    type,
    origin,
    maxPixels: maxPixels,
    storedMaxPixels: storedMaxPixels,
  );

  @override
  Future<void> cancel(String id) => _native.cancel(id);

  @override
  Future<void> regenerateDerived(Attachment attachment) =>
      _native.regenerateDerived(attachment);
}

Directory get _import => Directory('${_cache.path}/import');

Directory _staging(String id) => Directory('${_import.path}/$id');

/// Preparaciones que existen ahora mismo.
List<String> _stagingIds() => _import.existsSync()
    ? [
        for (final d in _import.listSync().whereType<Directory>())
          d.uri.pathSegments.where((s) => s.isNotEmpty).last,
      ]
    : [];

/// Cuántos originales (`source`) hay ahora mismo en disco.
int _sources() => _import.existsSync()
    ? _import
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/source').existsSync())
          .length
    : 0;

ImportImage _imports(
  ImageImporter importer, {
  PeriodicTimerFactory? periodic,
}) => ImportImage(
  importer: importer,
  janitor: _janitor,
  ids: const UuidV7Ids(),
  periodic: periodic,
);

/// Vigila que nunca haya más de un original en disco (CA-016-04, T-3).
class _SourceWatch {
  _SourceWatch() {
    _timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final n = _sources();
      if (n > max) max = n;
    });
  }

  late final Timer _timer;
  var max = 0;

  void stop() => _timer.cancel();
}

void _expectPrepared(StagedImage s) {
  final dir = _staging(s.id);
  expect(File('${dir.path}/screen.jpg').existsSync(), isTrue, reason: s.id);
  expect(File('${dir.path}/thumb.jpg').existsSync(), isTrue, reason: s.id);
  expect(File('${dir.path}/source').existsSync(), isFalse, reason: s.id);
  expect(s.origin, AttachmentOrigin.gallery);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FileAttachmentStore store;

  setUpAll(() async {
    _native = await NativeImageImporter.open();
    _cache = await getTemporaryDirectory();
    store = await FileAttachmentStore.open();
  });

  // Un registro y un barrendero nuevos por test: las preparadas que tienen éxito
  // quedan registradas hasta que se guarde la tarea (por diseño).
  setUp(() {
    _registry = ImportRegistry();
    _janitor = AttachmentJanitor(
      store: store,
      repository: InMemoryTaskRepository(),
      registry: _registry,
    );
  });

  tearDown(() {
    for (final d in ['fixtures', 'import']) {
      final dir = Directory('${_cache.path}/$d');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  testWidgets('CL-016-6: el nativo da el espacio libre de la partición', (
    tester,
  ) async {
    final free = await _native.freeSpace();
    expect(free, isNotNull);
    expect(free, greaterThan(100 * 1024 * 1024));
  });

  testWidgets('CA-016-04: tres fotos se preparan una a una y en su orden', (
    tester,
  ) async {
    final importer = _GroupImporter()
      ..next = ['photo_gps.jpg', 'orientation_3.jpg', 'transparent.png'];
    final watch = _SourceWatch();
    final group = (await _imports(importer).pickMany())!;
    final progress = <int>[];
    final result = await group.prepareAll(
      onProgress: (i, n) => progress.add(i),
    );
    watch.stop();

    expect(progress, [1, 2, 3]);
    expect(result.staged, hasLength(3));
    expect(result.failed, isEmpty);
    expect(result.limited, isFalse);
    expect(result.staged.map((s) => (s.width, s.height)), [
      (4000, 3000),
      (300, 200),
      (300, 200),
    ]);
    result.staged.forEach(_expectPrepared);
    expect(watch.max, lessThanOrEqualTo(1), reason: 'dos originales a la vez');
    expect(_registry.active, {for (final s in result.staged) s.id});
  });

  testWidgets('CA-016-02: 5000 elegidas, solo 10 tocadas, y se avisa', (
    tester,
  ) async {
    final importer = _GroupImporter()
      ..next = List.filled(5000, 'orientation_1.jpg')
      ..total = 5000;
    final group = (await _imports(importer).pickMany())!;
    expect(group.length, 10);
    expect(group.limited, isTrue);
    final result = await group.prepareAll();
    expect(result.staged, hasLength(10));
    expect(_stagingIds(), hasLength(10));
  });

  testWidgets(
    'CL-016-19: malformados, enormes y de otra app dentro de un grupo no '
    'cierran la app ni dejan archivos; las buenas siguen, en su orden',
    (tester) async {
      final importer = _GroupImporter()
        ..next = [
          'photo_gps.jpg',
          'truncated.jpg',
          'fake_dims_small.png',
          'corrupt.heic',
          'html_as.jpg',
          'px65.png',
          'file:///data/data/x',
          'content://0@invalid.pending.app.imports/x',
          'orientation_2.jpg',
        ];
      final watch = _SourceWatch();
      final group = (await _imports(importer).pickMany())!;
      // 9 elegidas, 7 fallan (ninguna es la buena): quedan 2.
      final result = await group.prepareAll();
      watch.stop();
      expect(result.staged.map((s) => (s.width, s.height)), [
        (4000, 3000),
        (300, 200),
      ]);
      result.staged.forEach(_expectPrepared);
      expect(result.failed, hasLength(7));
      expect(result.failed, contains(ImageImportError.tooManyPixels));
      expect(watch.max, lessThanOrEqualTo(1));
      // Lo que falló no deja nada en la preparación.
      expect(_stagingIds().toSet(), {for (final s in result.staged) s.id});
      expect(_registry.active, {for (final s in result.staged) s.id});
    },
  );

  testWidgets('CA-016-04: fallan todas = el error de la primera, sin restos', (
    tester,
  ) async {
    final importer = _GroupImporter()
      ..next = ['truncated.jpg', 'html_as.jpg', 'px65.png'];
    final group = (await _imports(importer).pickMany())!;
    await expectLater(
      group.prepareAll(),
      throwsA(
        isA<ImageImportFailure>().having(
          (e) => e.toString(),
          'texto',
          startsWith('ImageImportFailure('),
        ),
      ),
    );
    expect(_stagingIds(), isEmpty);
    expect(_registry.active, isEmpty);
  });

  testWidgets(
    'CA-016-04 / CL-016-19: tiempo agotado forzado en la foto 1 (la copia '
    'no acaba): nunca dos originales a la vez y la foto 2 no se cae en '
    'cascada ni agota sus 20 s esperando turno',
    (tester) async {
      var photos = 0;
      final importer = _GroupImporter()
        ..next = [_hang, 'photo_gps.jpg', 'orientation_5.jpg'];
      final imports = _imports(
        importer,
        // Solo la foto 1 tiene un reloj acelerado (20 s en ~100 ms): vence en
        // plena copia. Las demás, el de verdad.
        periodic: (period, callback) => photos++ == 0
            ? Timer.periodic(const Duration(milliseconds: 5), callback)
            : Timer.periodic(period, callback),
      );
      final watch = _SourceWatch();
      final sw = Stopwatch()..start();
      final result = await (await imports.pickMany())!.prepareAll();
      watch.stop();

      expect(result.failed, [ImageImportError.unreadable]);
      expect(result.staged.map((s) => (s.width, s.height)), [
        (4000, 3000),
        (300, 200),
      ]);
      result.staged.forEach(_expectPrepared);
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 15)),
        reason: 'la foto 2 no esperó turno: ${sw.elapsed}',
      );
      expect(watch.max, lessThanOrEqualTo(1), reason: 'dos originales');
      expect(_stagingIds().toSet(), {for (final s in result.staged) s.id});
    },
  );

  testWidgets(
    'CA-016-04 / CL-016-19: tiempo agotado forzado en la foto 1 (64 MP, copia '
    'o limpieza en curso): la 2 espera a la 1 y se prepara entera',
    (tester) async {
      var photos = 0;
      final importer = _GroupImporter()
        ..next = ['px64.png', 'photo_gps.jpg', 'orientation_6.jpg'];
      final imports = _imports(
        importer,
        // La foto 1 vence a los ~100 ms de empezar: copia o limpieza en curso.
        periodic: (period, callback) => photos++ == 0
            ? Timer.periodic(const Duration(milliseconds: 20), callback)
            : Timer.periodic(period, callback),
      );
      final watch = _SourceWatch();
      final sw = Stopwatch()..start();
      final result = await (await imports.pickMany())!.prepareAll();
      watch.stop();

      // La 1 (64 MP) no llega a acabar en 20 × 20 ms: vence y se omite; las
      // otras dos, con su reloj de verdad, quedan enteras.
      expect(result.failed, [ImageImportError.unreadable]);
      expect(result.staged.map((s) => (s.width, s.height)), [
        (4000, 3000),
        (300, 200),
      ]);
      result.staged.forEach(_expectPrepared);
      expect(sw.elapsed, lessThan(const Duration(seconds: 25)));
      expect(watch.max, lessThanOrEqualTo(1), reason: 'dos originales');
      expect(_stagingIds().toSet(), {for (final s in result.staged) s.id});
    },
  );

  testWidgets('CA-016-04: cancelar a mitad de la copia no deja nada', (
    tester,
  ) async {
    final importer = _GroupImporter()
      ..next = ['photo_gps.jpg', _hang, 'orientation_1.jpg'];
    final group = (await _imports(importer).pickMany())!;
    final outcome = expectLater(
      group.prepareAll(),
      throwsA(isA<ImageImportCancelled>()),
    );
    // Deja que la 1 acabe y la 2 empiece a copiar (no acaba nunca).
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(_sources(), 1, reason: 'la 2 está copiando');
    await group.cancel();
    await outcome;
    expect(_stagingIds(), isEmpty);
    expect(_registry.active, isEmpty);
  });

  testWidgets('CA-016-02: sin elegidas no se registra nada', (tester) async {
    final importer = _GroupImporter()..next = const [];
    expect(await _imports(importer).pickMany(), isNull);
    expect(_registry.active, isEmpty);
  });

  // --- A mano, con el selector del sistema (se conduce con adb) -----------------

  testWidgets(
    'CA-016-02: selector de fotos real (UNA_PICKER=photos)',
    skip: _picker != 'photos',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await _realPicker(_native.pickMany);
    },
  );

  testWidgets(
    'CA-016-02: selector de documentos real (UNA_PICKER=documents)',
    skip: _picker != 'documents',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await _realPicker(_native.debugPickManyDocuments);
    },
  );
}

/// Abre el selector real, prepara lo elegido con el nativo real y escribe un
/// resumen (solo números: nunca una dirección ni un nombre).
Future<void> _realPicker(
  Future<PickedImages?> Function({required int max}) open,
) async {
  // ignore: avoid_print
  print('UNA-STEP: abriendo');
  final picked = await open(max: ImageLimits.maxGroup);
  if (picked == null) {
    // ignore: avoid_print
    print('UNA-STEP: cancelado');
    return;
  }
  // ignore: avoid_print
  print('UNA-STEP: elegidas=${picked.items.length} total=${picked.total}');
  final importer = _RealGroup(picked);
  final group = (await _imports(importer).pickMany())!;
  final result = await group.prepareAll();
  // ignore: avoid_print
  print(
    'UNA-STEP: preparadas=${result.staged.length} '
    'falladas=${result.failed.length} limitado=${result.limited} '
    'tamaños=${result.staged.map((s) => '${s.width}x${s.height}').join(',')}',
  );
  for (final s in result.staged) {
    _expectPrepared(s);
  }
  // El orden: el color de la esquina de cada una (solo números).
  final colors = <String>[];
  for (final s in result.staged) {
    final codec = await ui.instantiateImageCodec(
      File('${_staging(s.id).path}/thumb.jpg').readAsBytesSync(),
    );
    final img = (await codec.getNextFrame()).image;
    final data = (await img.toByteData())!;
    colors.add('${data.getUint8(0)}/${data.getUint8(1)}/${data.getUint8(2)}');
  }
  // ignore: avoid_print
  print('UNA-STEP: colores=${colors.join(' ')}');
  expect(_stagingIds().toSet(), {for (final s in result.staged) s.id});
}

/// Entrega lo que el selector real ya devolvió y usa el nativo de verdad.
class _RealGroup extends _GroupImporter {
  _RealGroup(this._picked);
  final PickedImages _picked;

  @override
  Future<PickedImages?> pickMany({required int max}) async => _picked;

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) => _native.copy(picked, id, maxBytes: maxBytes);
}
