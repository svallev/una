import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/png_lite.dart';

/// Spec 020, T-020-08 (CA-020-15): el lector de PNG de `tool/png_lite.dart`, acotado.
///
/// Rechaza un lado de más de 2048 px, un segundo `IHDR` y unos datos que, ya descomprimidos,
/// superen lo que corresponde a las dimensiones declaradas (una «bomba de descompresión»).
/// Los PNG de prueba se arman a mano con `pngChunk`; no se leen del árbol.
const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Uint8List _ihdr(int width, int height, {int colorType = 6}) {
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, colorType);
  return pngChunk('IHDR', header.buffer.asUint8List());
}

/// Un PNG con los bloques [chunks] tras la firma.
Uint8List _png(List<Uint8List> chunks) {
  final out = BytesBuilder()..add(_signature);
  chunks.forEach(out.add);
  return out.takeBytes();
}

/// El contenido de un IDAT válido para [width] x [height] RGBA (filtro 0, todo a cero).
Uint8List _idatFor(int width, int height) =>
    pngChunk('IDAT', ZLibCodec().encode(Uint8List((width * 4 + 1) * height)));

void main() {
  group('png_lite: límites (CA-020-15)', () {
    test('CA-020-15: un PNG de 4096 px de lado se rechaza antes de reservar '
        'memoria', () {
      // La cabecera dice 4096 x 4096 (64 MB de píxeles RGBA); el IDAT es de juguete.
      final png = _png([
        _ihdr(4096, 4096),
        pngChunk('IDAT', ZLibCodec().encode([0, 1, 2, 3, 4])),
        pngChunk('IEND', const []),
      ]);
      expect(
        () => decodePng(png),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('4096'), contains('2048')),
          ),
        ),
      );
    });

    test('CA-020-15: el límite es 2048 en cada lado: 2048 pasa y 2049 no', () {
      // Imágenes de una fila o una columna para no gastar tiempo.
      for (final (w, h) in [(2048, 1), (1, 2048)]) {
        final image = PngImage(w, h, Uint8List(w * h * 4));
        final back = decodePng(encodePng(image));
        expect((back.width, back.height), (w, h));
      }
      for (final (w, h) in [(2049, 1), (1, 2049)]) {
        final png = _png([
          _ihdr(w, h),
          _idatFor(w, h),
          pngChunk('IEND', const []),
        ]);
        expect(() => decodePng(png), throwsFormatException, reason: '$w x $h');
      }
    });

    test('CA-020-15: un segundo IHDR se rechaza (aunque sea idéntico, y '
        'también si llega después de los datos)', () {
      final ok = _png([
        _ihdr(2, 2),
        _idatFor(2, 2),
        pngChunk('IEND', const []),
      ]);
      expect(decodePng(ok).width, 2);

      final twice = _png([
        _ihdr(2, 2),
        _ihdr(2, 2),
        _idatFor(2, 2),
        pngChunk('IEND', const []),
      ]);
      expect(
        () => decodePng(twice),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('IHDR'),
          ),
        ),
      );

      final late = _png([
        _ihdr(2, 2),
        _idatFor(2, 2),
        _ihdr(1, 1),
        pngChunk('IEND', const []),
      ]);
      expect(() => decodePng(late), throwsFormatException);

      // Con medidas distintas (el segundo no puede cambiar lo que se reservó).
      final different = _png([
        _ihdr(2, 2),
        _ihdr(4, 4),
        _idatFor(4, 4),
        pngChunk('IEND', const []),
      ]);
      expect(() => decodePng(different), throwsFormatException);
    });

    test('CA-020-15: una bomba de descompresión (1 x 1 con 32 MB de ceros '
        'comprimidos) se rechaza', () {
      final bomb = ZLibCodec(level: 1).encode(Uint8List(32 * 1024 * 1024));
      expect(bomb.length, lessThan(200 * 1024)); // la bomba pesa poco...
      final png = _png([
        _ihdr(1, 1),
        pngChunk('IDAT', bomb),
        pngChunk('IEND', const []),
      ]);
      expect(
        () => decodePng(png),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('descomprim'),
          ),
        ),
      );
    });

    test('CA-020-15: un solo byte de más sobre lo que dicen las medidas ya '
        'es «demasiado grande» (no «corrupto»)', () {
      // 1 x 1 RGBA = 1 + 4 = 5 bytes; con 6 se pasa del tope.
      final png = _png([
        _ihdr(1, 1),
        pngChunk('IDAT', ZLibCodec().encode(Uint8List(6))),
        pngChunk('IEND', const []),
      ]);
      expect(
        () => decodePng(png),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('descomprim'), isNot(contains('corruptos'))),
          ),
        ),
      );
    });

    test('CA-020-15: inflateBounded se para al pasar del límite, sin '
        'descomprimirlo todo', () {
      // 128 MB de ceros: si se descomprimiera entero, el contador llegaría a 128 MB.
      final bomb = ZLibCodec(level: 1).encode(Uint8List(128 * 1024 * 1024));
      var produced = 0;
      expect(
        () => inflateBounded(
          bomb,
          maxBytes: 1000,
          onChunk: (total) => produced = total,
        ),
        throwsFormatException,
      );
      expect(produced, greaterThan(1000));
      expect(produced, lessThan(4 * 1024 * 1024));
    });

    test('CA-020-15: inflateBounded devuelve los datos si caben, exactos', () {
      final data = Uint8List.fromList([for (var i = 0; i < 5000; i++) i % 251]);
      final back = inflateBounded(ZLibCodec().encode(data), maxBytes: 5000);
      expect(back, data);
      // Un byte menos de margen: ya no cabe.
      expect(
        () => inflateBounded(ZLibCodec().encode(data), maxBytes: 4999),
        throwsFormatException,
      );
    });

    test('CA-020-15: unos datos de menos de los que dicen las medidas siguen '
        'rechazándose', () {
      final png = _png([
        _ihdr(4, 4),
        pngChunk('IDAT', ZLibCodec().encode(Uint8List(10))),
        pngChunk('IEND', const []),
      ]);
      expect(() => decodePng(png), throwsFormatException);
    });

    test('CA-020-15: unos datos corruptos siguen dando FormatException (no '
        'otro tipo de error)', () {
      final png = _png([
        _ihdr(2, 2),
        pngChunk('IDAT', utf8.encode('esto no es zlib')),
        pngChunk('IEND', const []),
      ]);
      expect(() => decodePng(png), throwsFormatException);
    });
  });
}
