// PNG mínimo para `tool/gen_icons.dart` (spec 018, CA-018-10 y 12).
//
// Solo `dart:io`, `dart:convert` y `ZLibCodec`: sin el paquete `image` ni ningún otro (D29, P11).
// Lee PNG de 8 bits RGB o RGBA sin entrelazar (lo que trae el tablero 17), reduce por promedio de
// áreas y escribe RGBA. No va en `lib/` ni se empaqueta.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Imagen RGBA de 8 bits, **sin premultiplicar** (4 bytes por píxel, fila a fila).
class PngImage {
  PngImage(this.width, this.height, this.rgba)
    : assert(width > 0 && height > 0),
      assert(rgba.length == width * height * 4);

  /// Una imagen lisa del color `0xRRGGBB` y de alfa [alpha].
  factory PngImage.solid(int width, int height, int rgb, {int alpha = 255}) {
    final data = Uint8List(width * height * 4);
    for (var i = 0; i < data.length; i += 4) {
      data[i] = (rgb >> 16) & 0xFF;
      data[i + 1] = (rgb >> 8) & 0xFF;
      data[i + 2] = rgb & 0xFF;
      data[i + 3] = alpha;
    }
    return PngImage(width, height, data);
  }

  final int width;
  final int height;
  final Uint8List rgba;
}

/// El mayor lado que se acepta al leer (los iconos miden 1024 como mucho): evita reservar memoria
/// por una cabecera corrupta (spec 020, CA-020-15: antes 8192).
const maxPngSide = 2048;

const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Decodifica un PNG de 8 bits, RGB (2) o RGBA (6), sin entrelazar. Lo demás lanza
/// [FormatException]. El resultado siempre es RGBA (un RGB sale con alfa 255).
PngImage decodePng(Uint8List bytes) {
  if (bytes.length < _signature.length + 12) {
    throw const FormatException('PNG demasiado corto');
  }
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) {
      throw const FormatException('Firma PNG incorrecta');
    }
  }
  final data = ByteData.sublistView(bytes);
  var pos = _signature.length;
  int? width;
  int? height;
  int? colorType;
  var sawEnd = false;
  final idat = BytesBuilder(copy: false);
  while (pos + 12 <= bytes.length && !sawEnd) {
    final length = data.getUint32(pos);
    final end = pos + 8 + length;
    if (end + 4 > bytes.length) {
      throw const FormatException('Bloque PNG truncado');
    }
    final type = ascii.decode(bytes.sublist(pos + 4, pos + 8));
    final body = Uint8List.sublistView(bytes, pos + 8, end);
    if (_crc32(Uint8List.sublistView(bytes, pos + 4, end)) !=
        data.getUint32(end)) {
      throw FormatException('CRC incorrecto en el bloque $type');
    }
    switch (type) {
      case 'IHDR':
        // Un PNG tiene un solo IHDR: un segundo cambiaría las medidas ya aceptadas (CA-020-15).
        if (width != null) {
          throw const FormatException('IHDR repetido');
        }
        if (body.length != 13) {
          throw const FormatException('IHDR incorrecto');
        }
        final header = ByteData.sublistView(body);
        width = header.getUint32(0);
        height = header.getUint32(4);
        colorType = body[9];
        if (body[8] != 8) {
          throw FormatException('Solo 8 bits por canal (hay ${body[8]})');
        }
        if (colorType != 2 && colorType != 6) {
          throw FormatException('Tipo de color $colorType no admitido');
        }
        if (body[10] != 0 || body[11] != 0) {
          throw const FormatException('Compresión o filtro no estándar');
        }
        if (body[12] != 0) {
          throw const FormatException('PNG entrelazado no admitido');
        }
        if (width < 1 ||
            height < 1 ||
            width > maxPngSide ||
            height > maxPngSide) {
          throw FormatException(
            'Tamaño $width x $height fuera de límites (máximo $maxPngSide px por lado)',
          );
        }
      case 'IDAT':
        idat.add(body);
      case 'IEND':
        sawEnd = true;
    }
    pos = end + 4;
  }
  if (width == null || height == null || colorType == null) {
    throw const FormatException('Falta IHDR');
  }
  if (!sawEnd) {
    throw const FormatException('Falta IEND');
  }
  final bpp = colorType == 6 ? 4 : 3;
  final stride = width * bpp;
  // Se descomprime con tope: lo que corresponde a las medidas declaradas, ni un byte más.
  final raw = inflateBounded(idat.takeBytes(), maxBytes: (stride + 1) * height);
  if (raw.length != (stride + 1) * height) {
    throw const FormatException('Tamaño de los datos de imagen incorrecto');
  }

  // Quita el filtro de cada fila, usando la anterior ya reconstruida.
  final pixels = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    final filter = raw[y * (stride + 1)];
    final src = y * (stride + 1) + 1;
    final row = y * stride;
    final prev = row - stride;
    for (var i = 0; i < stride; i++) {
      final x = raw[src + i];
      final a = i >= bpp ? pixels[row + i - bpp] : 0;
      final b = y > 0 ? pixels[prev + i] : 0;
      final c = (y > 0 && i >= bpp) ? pixels[prev + i - bpp] : 0;
      final int value;
      switch (filter) {
        case 0:
          value = x;
        case 1:
          value = x + a;
        case 2:
          value = x + b;
        case 3:
          value = x + ((a + b) >> 1);
        case 4:
          value = x + _paeth(a, b, c);
        default:
          throw FormatException('Filtro $filter desconocido');
      }
      pixels[row + i] = value & 0xFF;
    }
  }
  if (bpp == 4) return PngImage(width, height, pixels);
  final rgba = Uint8List(width * height * 4);
  for (var p = 0; p < width * height; p++) {
    rgba[p * 4] = pixels[p * 3];
    rgba[p * 4 + 1] = pixels[p * 3 + 1];
    rgba[p * 4 + 2] = pixels[p * 3 + 2];
    rgba[p * 4 + 3] = 255;
  }
  return PngImage(width, height, rgba);
}

/// Descomprime [compressed] (zlib) **parándose** en cuanto el resultado pasa de [maxBytes]: una
/// «bomba» (megas de ceros en unos kilobytes) no llega a ocuparlos en memoria (CA-020-15). Lanza
/// [FormatException] si se pasa del tope o si los datos están corruptos. [onChunk] recibe el
/// total producido tras cada trozo (para que un test compruebe que se paró pronto).
Uint8List inflateBounded(
  List<int> compressed, {
  required int maxBytes,
  void Function(int total)? onChunk,
}) {
  final sink = _BoundedSink(maxBytes, onChunk);
  try {
    final conversion = ZLibCodec().decoder.startChunkedConversion(sink);
    const slice = 16 * 1024;
    for (var i = 0; i < compressed.length; i += slice) {
      conversion.add(
        compressed.sublist(i, math.min(i + slice, compressed.length)),
      );
    }
    conversion.close();
  } on FormatException catch (e) {
    // El nuestro (tope) o el de zlib con datos malos: los dos son FormatException.
    if (e is _TooLarge) rethrow;
    throw FormatException('Datos de imagen corruptos: ${e.message}');
  } on Object catch (e) {
    throw FormatException('Datos de imagen corruptos: $e');
  }
  return sink.takeBytes();
}

class _TooLarge extends FormatException {
  _TooLarge(int max)
    : super('Los datos de imagen descomprimidos superan los $max bytes');
}

/// Recoge lo descomprimido y corta al pasar del tope.
class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this._max, this._onChunk);

  final int _max;
  final void Function(int total)? _onChunk;
  final _out = BytesBuilder();
  var _total = 0;

  @override
  void add(List<int> chunk) {
    _total += chunk.length;
    _onChunk?.call(_total);
    if (_total > _max) throw _TooLarge(_max);
    _out.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _out.takeBytes();
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// Codifica [image] como PNG RGBA de 8 bits (sin filtro, comprimido con zlib).
Uint8List encodePng(PngImage image) {
  final stride = image.width * 4;
  final raw = Uint8List((stride + 1) * image.height);
  for (var y = 0; y < image.height; y++) {
    // Byte de filtro 0 (ninguno) y la fila tal cual.
    raw.setRange(
      y * (stride + 1) + 1,
      (y + 1) * (stride + 1),
      image.rgba,
      y * stride,
    );
  }
  final header = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8) // bits por canal
    ..setUint8(9, 6); // RGBA
  final out = BytesBuilder(copy: false)
    ..add(_signature)
    ..add(pngChunk('IHDR', header.buffer.asUint8List()))
    ..add(pngChunk('IDAT', ZLibCodec(level: 9).encode(raw)))
    ..add(pngChunk('IEND', const []));
  return out.takeBytes();
}

/// Un bloque PNG: longitud, tipo, datos y CRC. Público para que los tests construyan PNG a mano.
Uint8List pngChunk(String type, List<int> body) {
  final out = Uint8List(12 + body.length);
  final data = ByteData.sublistView(out)..setUint32(0, body.length);
  out
    ..setRange(4, 8, ascii.encode(type))
    ..setRange(8, 8 + body.length, body);
  data.setUint32(
    8 + body.length,
    _crc32(Uint8List.sublistView(out, 4, 8 + body.length)),
  );
  return out;
}

/// Reduce (o escala) [src] a [width] x [height] **promediando las áreas** que cubre cada píxel
/// nuevo, con peso fraccionario en los bordes. Con un factor entero (1024 → 512) es el promedio
/// exacto de cada bloque. El color pesa por el alfa (un píxel transparente no tiñe a sus
/// vecinos); el resultado se redondea al entero más cercano.
PngImage resizeArea(PngImage src, int width, int height) {
  if (width < 1 || height < 1) {
    throw ArgumentError('Tamaño de destino no válido: $width x $height');
  }
  final scaleX = src.width / width;
  final scaleY = src.height / height;
  final out = Uint8List(width * height * 4);
  for (var dy = 0; dy < height; dy++) {
    final y0 = dy * scaleY;
    final y1 = (dy + 1) * scaleY;
    final sy0 = y0.floor();
    final sy1 = math.min(y1.ceil(), src.height);
    for (var dx = 0; dx < width; dx++) {
      final x0 = dx * scaleX;
      final x1 = (dx + 1) * scaleX;
      final sx0 = x0.floor();
      final sx1 = math.min(x1.ceil(), src.width);
      var weight = 0.0; // área cubierta
      var alphaSum = 0.0; // Σ alfa · área
      var redSum = 0.0; // Σ color · alfa · área
      var greenSum = 0.0;
      var blueSum = 0.0;
      for (var sy = sy0; sy < sy1; sy++) {
        final wy = math.min(sy + 1.0, y1) - math.max(sy.toDouble(), y0);
        if (wy <= 0) continue;
        for (var sx = sx0; sx < sx1; sx++) {
          final wx = math.min(sx + 1.0, x1) - math.max(sx.toDouble(), x0);
          if (wx <= 0) continue;
          final w = wx * wy;
          final i = (sy * src.width + sx) * 4;
          final a = src.rgba[i + 3] * w;
          weight += w;
          alphaSum += a;
          redSum += src.rgba[i] * a;
          greenSum += src.rgba[i + 1] * a;
          blueSum += src.rgba[i + 2] * a;
        }
      }
      final o = (dy * width + dx) * 4;
      if (alphaSum > 0) {
        out[o] = _round(redSum / alphaSum);
        out[o + 1] = _round(greenSum / alphaSum);
        out[o + 2] = _round(blueSum / alphaSum);
      }
      out[o + 3] = weight > 0 ? _round(alphaSum / weight) : 0;
    }
  }
  return PngImage(width, height, out);
}

int _round(double v) => (v + 0.5).floor().clamp(0, 255);

// CRC-32 (el de PNG y zip), con la tabla calculada una vez.
final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Lee un archivo PNG de [path] (atajo para el generador).
PngImage readPngFile(String path) =>
    decodePng(Uint8List.fromList(File(path).readAsBytesSync()));
