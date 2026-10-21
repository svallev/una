import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'icon_image.dart';

/// PNG de 24 bits (RGB, sin canal alfa) a partir de píxeles RGBA: se descarta
/// el alfa (la imagen debe ser opaca). Sin paquetes: `dart:io` y un CRC propio.
Uint8List encodeRgbPng(RgbaImage image) {
  final raw = BytesBuilder();
  for (var y = 0; y < image.height; y++) {
    raw.addByte(0); // filtro «ninguno»
    for (var x = 0; x < image.width; x++) {
      raw
        ..addByte(image.red(x, y))
        ..addByte(image.green(x, y))
        ..addByte(image.blue(x, y));
    }
  }
  final header = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8) // 8 bits por canal
    ..setUint8(9, 2); // RGB
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final length = ByteData(4)..setUint32(0, data.length);
    final body = [...type.codeUnits, ...data];
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    out
      ..add(length.buffer.asUint8List())
      ..add(body)
      ..add(crc.buffer.asUint8List());
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Comparador de *goldens* cuyo archivo de referencia es un PNG de 24 bits
/// **sin alfa** (Play lo exige para el gráfico de funciones y las capturas;
/// spec 023, CA-023-10). Flutter entrega el PNG con alfa; aquí se guarda RGB y
/// se compara **por píxeles** con una tolerancia pequeña (otra versión de zlib
/// comprime distinto y el Mac y Linux suavizan el texto de otra manera).
class RgbGoldenComparator extends LocalFileComparator {
  RgbGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final file = File.fromUri(basedir.resolveUri(golden));
    if (!file.existsSync()) {
      throw TestFailure(
        'Falta el archivo de referencia ${file.path}: genéralo con '
        '--update-goldens.',
      );
    }
    final actual = await decodeRgba(imageBytes);
    final expected = await decodeRgba(file.readAsBytesSync());
    if (actual.width != expected.width || actual.height != expected.height) {
      return false;
    }
    // El archivo se escribe en el Mac y la CI compara en Linux: el suavizado de
    // los bordes del texto difiere un poco. Se admiten diferencias de hasta
    // 40 niveles por canal en como mucho el 1 % de los píxeles.
    var differing = 0;
    for (var i = 0; i < actual.data.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        if ((actual.data[i + c] - expected.data[i + c]).abs() > 40) {
          differing++;
          break;
        }
      }
    }
    if (differing > actual.width * actual.height * 0.01) return false;
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final image = await decodeRgba(imageBytes);
    for (var i = 3; i < image.data.length; i += 4) {
      if (image.data[i] != 255) {
        throw TestFailure('El golden no es opaco: se guardaría con alfa.');
      }
    }
    final file = File.fromUri(basedir.resolveUri(golden));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(encodeRgbPng(image));
  }
}
