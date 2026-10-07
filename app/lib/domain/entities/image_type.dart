/// Formatos de imagen que se aceptan al importar (spec 007, CA-007-13).
enum ImageType { jpeg, png, webp, gif, heic }

/// Límites de la importación de imágenes (spec 007).
abstract final class ImageLimits {
  /// 30 MB, contados mientras se copia (CA-007-14).
  static const int maxBytes = 30 * 1000 * 1000;
  static const int maxBytesInMb = 30;

  /// 64 megapíxeles, leídos de la cabecera antes de decodificar.
  static const int maxPixels = 64 * 1000 * 1000;
  static const int maxMegapixels = 64;

  /// La versión completa se reduce solo si pasa de 24 MP (CA-007-07).
  static const int storedMaxPixels = 24 * 1000 * 1000;

  /// Lado corto de la miniatura (44 dp × 4).
  static const int thumbShortSide = 176;

  /// Tiempo máximo de copia + limpieza (CA-007-14).
  static const Duration timeout = Duration(seconds: 20);

  /// Máximo de fotos de una tarea (spec 016, ADR-0024).
  static const int maxGroup = 10;

  /// Tiempo máximo de preparar un grupo entero, de tiempo activo (CA-016-24).
  static const Duration groupTimeout = Duration(minutes: 2);

  /// Bytes que se estima que ocupa una foto guardada, para comprobar el espacio
  /// libre antes de importar un grupo. **[Hecho]** 16 MB, cota superior medida
  /// en el emulador: ninguna foto guardó más de 14,5 MB (R-24, T-016-20;
  /// `specs/016-varias-imagenes-carrusel/dispositivo.md`).
  static const int storedPhotoEstimate = 16 * 1000 * 1000;

  /// Bytes de cabecera que necesita [sniffImageType].
  static const int headBytes = 64;
}

/// Marcas `ftyp` de HEIC/HEIF (ISO/IEC 23008-12).
const _heicBrands = {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1'};

/// Marcas de AVIF: no se admite en la v1 aunque también use `mif1`.
const _avifBrands = {'avif', 'avis'};

/// Decide el tipo de imagen **por el contenido** (CA-007-13), nunca por la
/// extensión ni por el tipo declarado. Devuelve null si no es un formato
/// admitido: SVG, AVIF, HTML, ZIP, ejecutables, texto… Si [heicSupported] es
/// false (Android 8), HEIC tampoco se admite.
ImageType? sniffImageType(List<int> head, {required bool heicSupported}) {
  bool starts(List<int> sig, [int at = 0]) {
    if (head.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (head[at + i] != sig[i]) return false;
    }
    return true;
  }

  String ascii(int from, int to) =>
      String.fromCharCodes(head.sublist(from, to).map((b) => b & 0x7f));

  if (starts(const [0xFF, 0xD8, 0xFF])) return ImageType.jpeg;
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return ImageType.png;
  }
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) {
    return ImageType.gif;
  }
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) {
    return ImageType.webp;
  }
  // ISO BMFF: [tamaño de la caja (4)] 'ftyp' [marca (4)] [versión (4)] [compatibles…]
  if (starts('ftyp'.codeUnits, 4) && head.length >= 12) {
    final boxSize =
        (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
    // Sin ver todas las marcas no se puede descartar AVIF: no se admite.
    if (boxSize < 16 || boxSize > head.length) return null;
    final end = boxSize;
    final brands = <String>{ascii(8, 12)};
    for (var i = 16; i + 4 <= end; i += 4) {
      brands.add(ascii(i, i + 4));
    }
    if (brands.any(_avifBrands.contains)) return null;
    if (brands.any(_heicBrands.contains)) {
      return heicSupported ? ImageType.heic : null;
    }
  }
  return null;
}
