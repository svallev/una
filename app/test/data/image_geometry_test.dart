import 'package:app/data/import/image_geometry.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';

/// Cabeceras mínimas (solo lo que lee [readImageSize]).
List<int> _png(int w, int h) => [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, //
  ...'IHDR'.codeUnits,
  (w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF,
  (h >> 24) & 0xFF, (h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF,
];

List<int> _le16(int v) => [v & 0xFF, v >> 8];
List<int> _be16(int v) => [v >> 8, v & 0xFF];
List<int> _le24(int v) => [v & 0xFF, (v >> 8) & 0xFF, v >> 16];

List<int> _riff(String chunk, List<int> data) => [
  ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, //
  ...chunk.codeUnits, 0, 0, 0, 0, ...data,
];

/// JPEG con un APP1 (EXIF) grande antes del SOF, como las fotos del móvil.
List<int> _jpeg(int w, int h, {int sof = 0xC0, int exif = 3000}) => [
  0xFF, 0xD8, //
  0xFF, 0xE1, ..._be16(exif + 2), ...List.filled(exif, 0),
  0xFF, 0xDB, ..._be16(4), 0, 0,
  0xFF, sof, ..._be16(17), 8, ..._be16(h), ..._be16(w), 3,
];

void main() {
  group('CA-007-14 (web de pruebas): dimensiones por la cabecera, sin '
      'decodificar', () {
    test('PNG', () {
      expect(readImageSize(_png(9000, 8000), ImageType.png), (
        width: 9000,
        height: 8000,
      ));
      expect(readImageSize(tinyImage, ImageType.png), (width: 1, height: 1));
    });

    test('GIF', () {
      expect(
        readImageSize([
          ...'GIF89a'.codeUnits,
          ..._le16(640),
          ..._le16(480),
        ], ImageType.gif),
        (width: 640, height: 480),
      );
    });

    test('WebP con pérdida, sin pérdida y extendido', () {
      final lossy = _riff('VP8 ', [
        0, 0, 0, 0x9D, 0x01, 0x2A, ..._le16(1920), ..._le16(1080), 0, 0, //
      ]);
      expect(readImageSize(lossy, ImageType.webp), (width: 1920, height: 1080));

      // 14 bits de ancho − 1 y 14 de alto − 1 tras la firma 0x2F.
      const w = 3000, h = 2000;
      final bits = (w - 1) | ((h - 1) << 14);
      final lossless = _riff('VP8L', [
        0x2F, bits & 0xFF, (bits >> 8) & 0xFF, (bits >> 16) & 0xFF, //
        (bits >> 24) & 0xFF, 0, 0, 0, 0, 0,
      ]);
      expect(readImageSize(lossless, ImageType.webp), (width: w, height: h));

      final extended = _riff('VP8X', [
        0, 0, 0, 0, ..._le24(12000 - 1), ..._le24(9000 - 1), //
      ]);
      expect(readImageSize(extended, ImageType.webp), (
        width: 12000,
        height: 9000,
      ));
    });

    test('JPEG: salta los segmentos hasta el SOF (base y progresivo)', () {
      expect(readImageSize(_jpeg(4000, 3000), ImageType.jpeg), (
        width: 4000,
        height: 3000,
      ));
      expect(readImageSize(_jpeg(9248, 6936, sof: 0xC2), ImageType.jpeg), (
        width: 9248,
        height: 6936,
      ));
    });

    test('cabeceras truncadas, vacías o con 0 px: null', () {
      expect(readImageSize(_png(10, 10).sublist(0, 20), ImageType.png), isNull);
      expect(readImageSize(_png(0, 10), ImageType.png), isNull);
      expect(
        readImageSize([0xFF, 0xD8, 0xFF, 0xDA, 0, 2], ImageType.jpeg),
        isNull,
      );
      expect(
        readImageSize(_jpeg(10, 10).sublist(0, 100), ImageType.jpeg),
        isNull,
      );
      expect(readImageSize(const [], ImageType.gif), isNull);
      expect(
        readImageSize(_riff('ABCD', List.filled(10, 0)), ImageType.webp),
        isNull,
      );
      expect(readImageSize(_png(10, 10), ImageType.heic), isNull);
    });
  });

  group('CA-007-07: tamaño de la versión completa', () {
    test('hasta 24 MP no se toca', () {
      expect(storedImageSize(6000, 4000, ImageLimits.storedMaxPixels), (
        width: 6000,
        height: 4000,
      ));
    });

    test('de más, se reduce sin pasar de 24 MP y sin límite de lado', () {
      final s = storedImageSize(8000, 6000, ImageLimits.storedMaxPixels);
      expect(
        s.width * s.height,
        lessThanOrEqualTo(ImageLimits.storedMaxPixels),
      );
      expect(s.width / s.height, closeTo(8000 / 6000, 0.001));
      // Captura muy alta: el lado largo sigue pasando de 4096 (teselas).
      final tall = storedImageSize(1080, 20000, ImageLimits.storedMaxPixels);
      expect(tall, (width: 1080, height: 20000));
    });
  });

  group('versión de pantalla: al ancho, sin perder los lados', () {
    test('foto apaisada: entera, más baja que la pantalla', () {
      final c = fitWidthCrop(4000, 3000, 1080, 2400);
      expect(c.crop, (left: 0, top: 0, width: 4000, height: 3000));
      expect((c.width, c.height), (1080, 810));
    });

    test('captura larga: todo el ancho y solo la parte de arriba', () {
      final c = fitWidthCrop(1080, 20000, 1080, 2400);
      expect(c.crop, (left: 0, top: 0, width: 1080, height: 2400));
      expect((c.width, c.height), (1080, 2400));
    });

    test('imagen estrecha: no se amplía', () {
      final c = fitWidthCrop(500, 400, 1080, 2400);
      expect(c.crop, (left: 0, top: 0, width: 500, height: 400));
      expect((c.width, c.height), (500, 400));
    });
  });

  group('miniatura: recorte centrado sin ampliar', () {
    test('miniatura cuadrada de 176 px', () {
      final c = coverCrop(4000, 3000, 176, 176);
      expect(c.crop, (left: 500, top: 0, width: 3000, height: 3000));
      expect((c.width, c.height), (176, 176));
    });

    test('imagen pequeña: no se amplía', () {
      final c = coverCrop(100, 50, 176, 176);
      expect(c.crop, (left: 25, top: 0, width: 50, height: 50));
      expect((c.width, c.height), (50, 50));
    });
  });
}
