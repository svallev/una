// Importación y limpieza nativas de imágenes (spec 007, T-007-08/09). En el
// emulador (nunca en el móvil del propietario sin su permiso):
//   flutter test integration_test/image_import_test.dart -d emulator-5554
//
// Los ficheros de prueba vienen de tools/fixtures/gen_image_fixtures.py y se
// escriben en `cache/fixtures/`, el único sitio que acepta `debugCopyFile`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/data/import/native_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'fixtures/image_fixtures.g.dart';

late NativeImageImporter importer;
late Directory cache;
var _n = 0;

Directory _staging(String id) => Directory('${cache.path}/import/$id');

/// Copia y limpia el fichero de prueba [name] como lo haría el editor.
Future<(StagedImage, Directory)> _import(
  String name, {
  AttachmentOrigin origin = AttachmentOrigin.gallery,
}) async {
  final id = 'it-${_n++}';
  final file = File('${cache.path}/fixtures/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(base64.decode(imageFixtures[name]!));
  final copied = await importer.debugCopyFile(
    file.path,
    id,
    maxBytes: ImageLimits.maxBytes,
  );
  final type = sniffImageType(
    copied.head,
    heicSupported: importer.heicSupported,
  );
  if (type == null) {
    throw const ImageImportFailure(ImageImportError.unsupportedType);
  }
  final staged = await importer.sanitize(
    id,
    type,
    origin,
    maxPixels: ImageLimits.maxPixels,
    storedMaxPixels: ImageLimits.storedMaxPixels,
  );
  return (staged, _staging(id));
}

Future<ui.Image> _decode(File f) async {
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<List<int>> _pixel(ui.Image img, int x, int y) async {
  final data = (await img.toByteData())!;
  final i = (y * img.width + x) * 4;
  return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
}

bool _contains(Uint8List hay, List<int> needle) {
  outer:
  for (var i = 0; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Todos los archivos que la app guarda para la imagen.
List<File> _outputs(Directory dir) =>
    dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void _expectClean(Directory dir) {
  final files = _outputs(dir);
  expect(files.map((f) => f.uri.pathSegments.last), contains('screen.jpg'));
  expect(files.map((f) => f.uri.pathSegments.last), contains('thumb.jpg'));
  expect(files.any((f) => f.path.endsWith('source')), isFalse);
  for (final f in files) {
    final bytes = f.readAsBytesSync();
    // JPEG limpio: SOI y, justo después, sin APP1 (EXIF/XMP) ni comentarios.
    expect(bytes.sublist(0, 2), [0xFF, 0xD8]);
    expect(bytes.sublist(bytes.length - 2), [
      0xFF,
      0xD9,
    ], reason: '${f.path}: datos tras el final');
    for (final m in imageFixtureMarkers) {
      expect(
        _contains(bytes, ascii.encode(m)),
        isFalse,
        reason: '${f.path} contiene $m',
      );
    }
    for (var i = 2; i + 1 < bytes.length && bytes[i] == 0xFF;) {
      final marker = bytes[i + 1];
      if (marker == 0xDA) break; // empieza la imagen
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      // APP2 solo con el perfil de color sRGB que escribe Android al
      // codificar (no viene del original: CA-007-07 pide sRGB).
      final isIcc =
          marker == 0xE2 &&
          ascii.decode(bytes.sublist(i + 4, i + 15), allowInvalid: true) ==
              'ICC_PROFILE';
      expect(
        isIcc || ![0xE1, 0xE2, 0xED, 0xFE].contains(marker),
        isTrue,
        reason: '${f.path}: segmento 0x${marker.toRadixString(16)}',
      );
      i += 2 + len;
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    importer = await NativeImageImporter.open();
    cache = await getTemporaryDirectory();
  });

  tearDownAll(() {
    for (final d in ['fixtures', 'import']) {
      final dir = Directory('${cache.path}/$d');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'CA-007-07: foto de 12 MP sin metadatos, orientada y con sus tres versiones',
    (tester) async {
      final (s, dir) = await _import(
        'photo_gps.jpg',
        origin: AttachmentOrigin.camera,
      );
      expect((s.width, s.height), (4000, 3000)); // Orientación 6 aplicada
      expect(s.origin, AttachmentOrigin.camera);
      _expectClean(dir);
      final full = await _decode(File('${dir.path}/full-0-0.jpg'));
      expect(await _pixel(full, 10, 10), [
        greaterThan(200),
        lessThan(60),
        lessThan(60),
      ]);
      final thumb = await _decode(File('${dir.path}/thumb.jpg'));
      expect((thumb.width, thumb.height), (176, 176));
      final screen = await _decode(File('${dir.path}/screen.jpg'));
      expect(screen.height, greaterThan(screen.width));
      expect(s.byteSize, File('${dir.path}/full-0-0.jpg').lengthSync());
    },
  );

  testWidgets('CA-007-07: las 8 orientaciones EXIF se corrigen', (
    tester,
  ) async {
    for (var o = 1; o <= 8; o++) {
      final (s, dir) = await _import('orientation_$o.jpg');
      expect((s.width, s.height), (300, 200), reason: 'orientación $o');
      final full = await _decode(File('${dir.path}/full-0-0.jpg'));
      final px = await _pixel(full, 20, 20);
      expect(px[0], greaterThan(200), reason: 'orientación $o: $px');
      expect(px[2], lessThan(60), reason: 'orientación $o: $px');
      _expectClean(dir);
    }
  });

  testWidgets(
    'CA-007-07: ni vídeo de "foto con movimiento" ni datos tras el final',
    (tester) async {
      final (_, dir) = await _import('trailing.jpg');
      _expectClean(dir);
    },
  );

  testWidgets('CL-007-4: PNG con transparencia, sobre blanco y sin tEXt', (
    tester,
  ) async {
    final (_, dir) = await _import('transparent.png');
    _expectClean(dir);
    final full = await _decode(File('${dir.path}/full-0-0.jpg'));
    expect(await _pixel(full, 250, 150), [
      greaterThan(240),
      greaterThan(240),
      greaterThan(240),
    ]);
    expect((await _pixel(full, 20, 20))[0], greaterThan(200));
  });

  testWidgets('CA-007-07/13: WebP con EXIF, GIF (primer fotograma) y HEIC', (
    tester,
  ) async {
    _expectClean((await _import('exif.webp')).$2);
    final (gif, gifDir) = await _import('frames5000.gif');
    expect((gif.width, gif.height), (16, 16));
    _expectClean(gifDir);
    if (importer.heicSupported) {
      final (heic, heicDir) = await _import('photo.heic');
      expect(heic.width * heic.height, 800 * 600);
      _expectClean(heicDir);
    }
  });

  testWidgets('CL-007-5: 50 MP se acepta y se guarda reducida a ≤ 24 MP', (
    tester,
  ) async {
    final (s, dir) = await _import('px50.png');
    expect(s.width * s.height, lessThanOrEqualTo(ImageLimits.storedMaxPixels));
    expect(s.width * s.height, greaterThan(ImageLimits.storedMaxPixels * 0.98));
    expect((s.width / s.height - 8660 / 5774).abs(), lessThan(0.01));
    final tiles = ImageTiles(s.width, s.height);
    expect(
      _outputs(dir).where((f) => f.path.contains('full-')).length,
      tiles.rows * tiles.columns,
    );
  });

  testWidgets(
    'CA-007-13: 64 MP (bomba PNG) se acepta; 65 MP se rechaza por la cabecera',
    (tester) async {
      final (s, _) = await _import('px64.png');
      expect(
        s.width * s.height,
        lessThanOrEqualTo(ImageLimits.storedMaxPixels),
      );
      for (final name in ['px65.png', 'fake_dims_huge.png']) {
        final sw = Stopwatch()..start();
        await expectLater(
          _import(name),
          throwsA(
            isA<ImageImportFailure>().having(
              (e) => e.error,
              'error',
              ImageImportError.tooManyPixels,
            ),
          ),
        );
        expect(sw.elapsedMilliseconds, lessThan(2000), reason: name);
      }
    },
  );

  testWidgets('CL-007-2: captura de 1080 × 20 000 entera, en 5 franjas', (
    tester,
  ) async {
    final (s, dir) = await _import('tall_1080x20000.png');
    expect((s.width, s.height), (1080, 20000));
    for (var r = 0; r < 5; r++) {
      final t = await _decode(File('${dir.path}/${ImageTiles.fileName(r, 0)}'));
      expect(t.width, 1080);
      expect(t.height, r < 4 ? 4096 : 20000 - 4 * 4096);
    }
  });

  testWidgets('CA-007-13: tipos no admitidos por el contenido', (tester) async {
    for (final name in ['svg_as.png', 'image.avif', 'html_as.jpg']) {
      await expectLater(
        _import(name),
        throwsA(
          isA<ImageImportFailure>().having(
            (e) => e.error,
            'error',
            ImageImportError.unsupportedType,
          ),
        ),
        reason: name,
      );
    }
  });

  testWidgets('CA-007-14: malformados nunca cierran la app ni dejan archivos', (
    tester,
  ) async {
    for (final name in [
      'truncated.jpg',
      'fake_dims_small.png',
      'corrupt.heic',
    ]) {
      try {
        await _import(name);
      } on ImageImportFailure catch (e) {
        expect(
          e.error,
          anyOf(ImageImportError.unreadable, ImageImportError.unsupportedType),
          reason: name,
        );
      }
    }
    // Lo que falló no deja nada en la preparación.
    final left = Directory('${cache.path}/import')
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last);
    for (final id in left) {
      expect(
        Directory('${cache.path}/import/$id/source').existsSync(),
        isFalse,
      );
    }
  });

  testWidgets(
    'CA-007-14: el tamaño se cuenta al copiar (flujo sin fin y 31 MB)',
    (tester) async {
      await expectLater(
        importer.debugCopyFile(
          '/dev/zero',
          'endless',
          maxBytes: ImageLimits.maxBytes,
        ),
        throwsA(
          isA<ImageImportFailure>().having(
            (e) => e.error,
            'error',
            ImageImportError.tooLarge,
          ),
        ),
      );
      expect(_staging('endless').existsSync(), isFalse);
      final big = File('${cache.path}/fixtures/big.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(
          Uint8List(ImageLimits.maxBytes + 1)..setAll(0, [0xFF, 0xD8, 0xFF]),
        );
      await expectLater(
        importer.debugCopyFile(big.path, 'big', maxBytes: ImageLimits.maxBytes),
        throwsA(
          isA<ImageImportFailure>().having(
            (e) => e.error,
            'error',
            ImageImportError.tooLarge,
          ),
        ),
      );
      expect(_staging('big').existsSync(), isFalse);
    },
  );

  testWidgets(
    'CA-007-14: nada fuera de la zona de prueba; rutas con ../ rechazadas',
    (tester) async {
      final docs = await getApplicationDocumentsDirectory();
      for (final path in [
        '${cache.path}/fixtures/../../app_flutter/una.sqlite',
        '${docs.path}/una.sqlite',
        '/proc/self/maps',
      ]) {
        await expectLater(
          importer.debugCopyFile(path, 'evil', maxBytes: ImageLimits.maxBytes),
          throwsA(isA<ImageImportFailure>()),
          reason: path,
        );
      }
      await expectLater(
        importer.copy(
          (token: 'file:///data/data/x', origin: AttachmentOrigin.gallery),
          'evil',
          maxBytes: 10,
        ),
        throwsA(isA<ImageImportFailure>()),
      );
    },
  );

  testWidgets('CA-007-15: cancelar borra la preparación', (tester) async {
    final future = importer.debugCopyFile(
      '/dev/urandom',
      'cancel-me',
      maxBytes: 1 << 40,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await importer.cancel('cancel-me');
    await expectLater(future, throwsA(isA<ImageImportCancelled>()));
    expect(_staging('cancel-me').existsSync(), isFalse);
  });
}
