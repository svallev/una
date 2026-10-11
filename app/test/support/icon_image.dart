import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Ayudas de los tests de recursos del icono (spec 018, T-018-01).
///
/// Deciden **con `dart:ui`**, sin el paquete `image` y sin reutilizar
/// `tool/png_lite.dart`: así un fallo del generador no se esconde a sí mismo
/// (plan §1.4 y §5). Las rutas son relativas a `app/` (el directorio de
/// `flutter test`).

/// Cabecera IHDR de un PNG.
class PngHeader {
  const PngHeader({
    required this.width,
    required this.height,
    required this.bitDepth,
    required this.colorType,
  });

  final int width;
  final int height;
  final int bitDepth;

  /// 0 grises, 2 RGB, 3 paleta, 4 grises + alfa, 6 RGBA.
  final int colorType;

  bool get hasAlphaChannel => colorType == 4 || colorType == 6;
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Lee la cabecera IHDR a mano. Lanza si no es un PNG.
PngHeader readPngHeader(Uint8List bytes) {
  if (bytes.length < 33) {
    throw const FormatException('PNG demasiado corto');
  }
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) {
      throw const FormatException('Firma PNG incorrecta');
    }
  }
  final data = ByteData.sublistView(bytes);
  final type = ascii.decode(bytes.sublist(12, 16));
  if (type != 'IHDR') {
    throw FormatException('El primer bloque es $type, no IHDR');
  }
  return PngHeader(
    width: data.getUint32(16),
    height: data.getUint32(20),
    bitDepth: bytes[24],
    colorType: bytes[25],
  );
}

/// Imagen decodificada a RGBA **sin premultiplicar** (4 bytes por píxel).
class RgbaImage {
  RgbaImage(this.width, this.height, this.data)
    : assert(data.length == width * height * 4);

  final int width;
  final int height;
  final Uint8List data;

  int _o(int x, int y) => (y * width + x) * 4;
  int red(int x, int y) => data[_o(x, y)];
  int green(int x, int y) => data[_o(x, y) + 1];
  int blue(int x, int y) => data[_o(x, y) + 2];
  int alpha(int x, int y) => data[_o(x, y) + 3];

  /// `0xRRGGBB` del píxel.
  int rgb(int x, int y) => (red(x, y) << 16) | (green(x, y) << 8) | blue(x, y);
}

/// Decodifica un PNG a RGBA con `dart:ui` (hace falta
/// `TestWidgetsFlutterBinding.ensureInitialized()`; dentro de `testWidgets`,
/// `tester.runAsync`).
Future<RgbaImage> decodeRgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return RgbaImage(
        image.width,
        image.height,
        Uint8List.fromList(data!.buffer.asUint8List()),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Lee un archivo (ruta relativa a `app/`) y lo decodifica.
Future<RgbaImage> loadRgba(String path) async =>
    decodeRgba(File(path).readAsBytesSync());

/// ¿Es el píxel parte de la figura (la «u.»)?
typedef FigurePredicate = bool Function(int r, int g, int b, int a);

/// Figura con alfa > 0: lo que miden el primer plano y la capa monocroma.
bool opaqueFigure(int r, int g, int b, int a) => a > 0;

/// Figura por color, para un icono **sin alfa** (el original de 1024 y los de
/// Play y web): todo lo que se aleja más de [tolerance] del fondo [background]
/// (canal a canal, 0xRRGGBB).
FigurePredicate differsFrom(int background, {int tolerance = 0}) {
  final br = (background >> 16) & 0xFF;
  final bg = (background >> 8) & 0xFF;
  final bb = background & 0xFF;
  return (r, g, b, a) =>
      (r - br).abs() > tolerance ||
      (g - bg).abs() > tolerance ||
      (b - bb).abs() > tolerance;
}

/// Medidas de la figura de una imagen, en píxeles de esa imagen.
class FigureMeasure {
  const FigureMeasure({
    required this.imageWidth,
    required this.imageHeight,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.maxDistance,
    required this.pixels,
  });

  final int imageWidth;
  final int imageHeight;

  /// Caja de la figura, con los extremos **incluidos**.
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  /// Distancia del centro de la imagen al punto de la figura más lejano (la
  /// esquina exterior del píxel más lejano), en píxeles.
  final double maxDistance;

  /// Cuántos píxeles tiene la figura.
  final int pixels;

  int get boxWidth => maxX - minX + 1;
  int get boxHeight => maxY - minY + 1;

  /// Ancho de la caja respecto al lado de la imagen (0..1).
  double get widthRatio => boxWidth / imageWidth;

  /// Centro de la caja, en píxeles (el de un píxel es su mitad: 0,5).
  double get centerX => (minX + maxX + 1) / 2;
  double get centerY => (minY + maxY + 1) / 2;

  /// Cuánto se aparta el centro de la caja del centro de la imagen.
  double get offsetX => centerX - imageWidth / 2;
  double get offsetY => centerY - imageHeight / 2;

  /// Distancia máxima al centro respecto al lado de la imagen (0..1).
  double get maxDistanceRatio => maxDistance / imageWidth;
}

/// Mide la figura. Lanza si no hay ningún píxel de figura.
FigureMeasure measureFigure(
  RgbaImage image, {
  FigurePredicate isFigure = opaqueFigure,
}) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  var count = 0;
  var maxD2 = 0.0;
  final cx = image.width / 2;
  final cy = image.height / 2;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (!isFigure(
        image.red(x, y),
        image.green(x, y),
        image.blue(x, y),
        image.alpha(x, y),
      )) {
        continue;
      }
      count++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      // La esquina más lejana del píxel: así la medida nunca queda por debajo
      // de la figura dibujada (se compara con la zona segura).
      final dx = (x + 0.5 - cx).abs() + 0.5;
      final dy = (y + 0.5 - cy).abs() + 0.5;
      final d2 = dx * dx + dy * dy;
      if (d2 > maxD2) maxD2 = d2;
    }
  }
  if (count == 0) {
    throw StateError('La imagen no tiene ningún píxel de figura');
  }
  return FigureMeasure(
    imageWidth: image.width,
    imageHeight: image.height,
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    maxDistance: math.sqrt(maxD2),
    pixels: count,
  );
}

/// Los colores distintos de la imagen (`0xRRGGBB`) con su número de píxeles,
/// contando solo los de alfa >= [minAlpha]. `dart:ui` decodifica premultiplicado:
/// con alfa bajo (< ~64) el color se redondea y se aparta de la tinta (17/255 con
/// alfa 1), así que para comparar colores de un PNG con transparencia hay que
/// subir [minAlpha] (la spec habla de «transparencia y suavizado de tinta»).
Map<int, int> colorCounts(RgbaImage image, {int minAlpha = 1}) {
  final counts = <int, int>{};
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.alpha(x, y) < minAlpha) continue;
      counts.update(image.rgb(x, y), (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

/// Cuánto se aparta un color del segmento entre [from] y [to] (el suavizado
/// de un borde): la mayor diferencia de canal con el punto más cercano del
/// segmento. 0 si es uno de los dos colores o una mezcla exacta de ambos.
int deviationFromBlend(int color, int from, int to) {
  List<int> c(int v) => [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  final p = c(color);
  final a = c(from);
  final d = [for (var i = 0; i < 3; i++) c(to)[i] - a[i]];
  final len2 = d.fold<int>(0, (s, v) => s + v * v);
  var t = 0.0;
  if (len2 > 0) {
    var dot = 0;
    for (var i = 0; i < 3; i++) {
      dot += (p[i] - a[i]) * d[i];
    }
    t = (dot / len2).clamp(0.0, 1.0);
  }
  var worst = 0;
  for (var i = 0; i < 3; i++) {
    final diff = (p[i] - (a[i] + d[i] * t)).abs().round();
    if (diff > worst) worst = diff;
  }
  return worst;
}

/// Los tokens que usan los iconos, leídos de `design/tokens.json` (CA-018-03:
/// nunca se copian los valores a ciegas).
class IconTokens {
  const IconTokens({required this.yellow, required this.ink});

  /// `palette.classic.0` (el amarillo), `0xRRGGBB`.
  final int yellow;

  /// `color.ink` (la tinta), `0xRRGGBB`.
  final int ink;

  /// `#RRGGBB` en mayúsculas, tal y como se escribe en un recurso XML.
  String get yellowHex => hexOf(yellow);
  String get inkHex => hexOf(ink);
}

String hexOf(int rgb) =>
    '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

int _parseHex(String value) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
  if (m == null) {
    throw FormatException('No es un color #RRGGBB: $value');
  }
  return int.parse(m.group(1)!, radix: 16);
}

/// Lee `palette.classic.0` y `color.ink` de [path] (por defecto, el del repo).
IconTokens readIconTokens({String path = '../design/tokens.json'}) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map;
  String value(Map<dynamic, dynamic> node) => node[r'$value'] as String;
  final palette = json['palette'] as Map;
  final classic = palette['classic'] as Map;
  final color = json['color'] as Map;
  return IconTokens(
    yellow: _parseHex(value(classic['0'] as Map)),
    ink: _parseHex(value(color['ink'] as Map)),
  );
}
