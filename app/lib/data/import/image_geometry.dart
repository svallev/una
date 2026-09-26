import 'dart:math' as math;

import '../../domain/entities/image_type.dart';

/// Rectángulo en píxeles.
typedef PixelRect = ({int left, int top, int width, int height});

/// Dimensiones leídas de la cabecera, **sin decodificar** la imagen: así se
/// rechaza una de más de 64 MP antes de reservar memoria (CA-007-14). Devuelve
/// null si la cabecera no se entiende. HEIC no se lee (la web de pruebas no lo
/// admite).
({int width, int height})? readImageSize(List<int> b, ImageType type) {
  int be16(int i) => (b[i] << 8) | b[i + 1];
  int le16(int i) => b[i] | (b[i + 1] << 8);
  int be32(int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  bool has(int n) => b.length >= n;
  ({int width, int height})? size(int w, int h) =>
      w > 0 && h > 0 ? (width: w, height: h) : null;

  switch (type) {
    case ImageType.png:
      // Firma (8) + longitud (4) + 'IHDR' (4) + ancho (4) + alto (4).
      return has(24) ? size(be32(16), be32(20)) : null;
    case ImageType.gif:
      return has(10) ? size(le16(6), le16(8)) : null;
    case ImageType.webp:
      if (!has(30)) return null;
      final chunk = String.fromCharCodes(b.sublist(12, 16));
      return switch (chunk) {
        'VP8 ' => size(le16(26) & 0x3FFF, le16(28) & 0x3FFF),
        'VP8L' => size(
          1 + (b[21] | ((b[22] & 0x3F) << 8)),
          1 + ((b[22] >> 6) | (b[23] << 2) | ((b[24] & 0x0F) << 10)),
        ),
        'VP8X' => size(
          1 + (b[24] | (b[25] << 8) | (b[26] << 16)),
          1 + (b[27] | (b[28] << 8) | (b[29] << 16)),
        ),
        _ => null,
      };
    case ImageType.jpeg:
      // Recorre los segmentos hasta el primer SOFn (sin DHT, JPG ni DAC).
      var i = 2;
      while (has(i + 4)) {
        if (b[i] != 0xFF) return null;
        final marker = b[i + 1];
        if (marker == 0xFF) {
          i++;
          continue;
        }
        if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) {
          i += 2;
          continue;
        }
        if (marker == 0xD9 || marker == 0xDA) return null;
        final length = be16(i + 2);
        if (length < 2) return null;
        final isSof =
            marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC;
        if (isSof) return has(i + 9) ? size(be16(i + 7), be16(i + 5)) : null;
        i += 2 + length;
      }
      return null;
    case ImageType.heic:
      return null;
  }
}

/// Tamaño de la versión completa: la original, o reducida para no pasar de
/// [maxPixels] (CA-007-07).
({int width, int height}) storedImageSize(
  int width,
  int height,
  int maxPixels,
) {
  final pixels = width * height;
  if (pixels <= maxPixels) return (width: width, height: height);
  final k = math.sqrt(maxPixels / pixels);
  return (
    width: math.max(1, (width * k).floor()),
    height: math.max(1, (height * k).floor()),
  );
}

/// Recorte centrado que llena [targetWidth] × [targetHeight] sin ampliar
/// nunca (versión de pantalla y miniatura), como `ImageSanitizer.cover` en
/// Android: [crop] en píxeles de la imagen y el tamaño de salida.
({PixelRect crop, int width, int height}) coverCrop(
  int width,
  int height,
  int targetWidth,
  int targetHeight,
) {
  final scale = math.max(targetWidth / width, targetHeight / height);
  final cropW = math.min(width, math.max(1, (targetWidth / scale).round()));
  final cropH = math.min(height, math.max(1, (targetHeight / scale).round()));
  final s = math.min(1.0, scale);
  return (
    crop: (
      left: (width - cropW) ~/ 2,
      top: (height - cropH) ~/ 2,
      width: cropW,
      height: cropH,
    ),
    width: math.max(1, (cropW * s).round()),
    height: math.max(1, (cropH * s).round()),
  );
}
