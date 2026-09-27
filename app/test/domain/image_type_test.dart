import 'dart:convert';

import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _ftyp(String major, List<String> compatible) {
  final body = [
    ...ascii.encode('ftyp'),
    ...ascii.encode(major),
    0,
    0,
    0,
    0,
    for (final b in compatible) ...ascii.encode(b),
  ];
  final size = body.length + 4;
  return [0, 0, 0, size, ...body, 0, 0, 0, 0];
}

ImageType? _sniff(List<int> head, {bool heic = true}) =>
    sniffImageType(head, heicSupported: heic);

void main() {
  group('CA-007-13: el tipo se decide por el contenido', () {
    test('acepta JPEG, PNG, WebP, GIF y HEIC por sus primeros bytes', () {
      expect(_sniff([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]), ImageType.jpeg);
      expect(
        _sniff([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]),
        ImageType.png,
      );
      expect(_sniff(ascii.encode('GIF89a....')), ImageType.gif);
      expect(_sniff(ascii.encode('GIF87a....')), ImageType.gif);
      expect(
        _sniff(ascii.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')),
        ImageType.webp,
      );
      expect(_sniff(_ftyp('heic', ['mif1', 'heic'])), ImageType.heic);
      expect(_sniff(_ftyp('mif1', ['heic'])), ImageType.heic);
      expect(_sniff(_ftyp('heix', [])), ImageType.heic);
    });

    test('rechaza AVIF aunque comparta la marca mif1', () {
      expect(_sniff(_ftyp('avif', ['mif1', 'miaf'])), isNull);
      expect(_sniff(_ftyp('mif1', ['avif', 'miaf'])), isNull);
      expect(_sniff(_ftyp('avis', ['msf1'])), isNull);
    });

    test('rechaza la caja ftyp que no cabe entera en la cabecera (podría ser '
        'AVIF más allá) o que es demasiado corta', () {
      final long = _ftyp('mif1', [for (var i = 0; i < 14; i++) 'miaf', 'avif']);
      expect(long.length, greaterThan(ImageLimits.headBytes));
      expect(_sniff(long.sublist(0, ImageLimits.headBytes)), isNull);
      expect(_sniff([0, 0, 0, 8, ...ascii.encode('ftypheic')]), isNull);
    });

    test('rechaza HEIC en Android 8', () {
      expect(_sniff(_ftyp('heic', ['mif1']), heic: false), isNull);
    });

    test('rechaza SVG, HTML, ZIP, ejecutables, vídeo y texto', () {
      for (final head in [
        ascii.encode('<svg xmlns="http://www.w3.org/2000/svg">'),
        ascii.encode('<?xml version="1.0"?><svg>'),
        ascii.encode('<!doctype html><script>'),
        [0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0],
        [0x4D, 0x5A, 0x90, 0, 3, 0, 0, 0],
        [0x7F, 0x45, 0x4C, 0x46, 2, 1, 1, 0],
        _ftyp('isom', ['iso2', 'mp41']),
        ascii.encode('%PDF-1.7'),
        ascii.encode('hola'),
        <int>[],
      ]) {
        expect(_sniff(head), isNull, reason: '$head');
      }
    });

    test('CA-007-14: no se confunde con cabeceras cortas', () {
      expect(_sniff([0xFF, 0xD8]), isNull);
      expect(_sniff(ascii.encode('RIFF')), isNull);
      expect(_sniff(ascii.encode('\x00\x00\x00\x18ftyp')), isNull);
    });
  });

  group('ImageTiles', () {
    test('CA-007-07: una foto de 12 MP es una sola tesela', () {
      const t = ImageTiles(4000, 3000);
      expect((t.rows, t.columns), (1, 1));
      expect(t.rect(0, 0), (left: 0, top: 0, width: 4000, height: 3000));
    });

    test('CL-007-2: 1080 × 20 000 son 5 franjas; la última, la sobrante', () {
      const t = ImageTiles(1080, 20000);
      expect((t.rows, t.columns), (5, 1));
      expect(t.rect(4, 0), (left: 0, top: 16384, width: 1080, height: 3616));
      expect(ImageTiles.fileName(4, 0), 'full-4-0.jpg');
    });

    test('CA-007-07: una panorámica se parte también en columnas', () {
      const t = ImageTiles(20000, 1200);
      expect((t.rows, t.columns), (1, 5));
    });
  });
}
