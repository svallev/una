import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../support/icon_image.dart';

/// El icono de Google Play (spec 018, T-018-04, CA-018-08): vive en
/// `store/google-play/` (raíz del repo, fuera de `app/`) y no se empaqueta.
const _play = '../store/google-play/icon-512.png';
const _original = '../design/prototype/assets/icon/icon-1024.png';

/// El original reducido a 512 por promedio 2 x 2 (exacto en un factor entero),
/// calculado aquí aparte del generador.
RgbaImage _halved(RgbaImage src) {
  final w = src.width ~/ 2;
  final h = src.height ~/ 2;
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0;
        for (var dy = 0; dy < 2; dy++) {
          for (var dx = 0; dx < 2; dx++) {
            sum += src.data[((2 * y + dy) * src.width + 2 * x + dx) * 4 + c];
          }
        }
        out[(y * w + x) * 4 + c] = (sum / 4).round();
      }
    }
  }
  return RgbaImage(w, h, out);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tokens = readIconTokens();

  test('CA-018-08: el PNG de Play es RGBA de 8 bits, 512 x 512 y de menos de 1024 KB', () {
    final file = File(_play);
    expect(file.existsSync(), isTrue, reason: 'falta $_play');
    final bytes = file.readAsBytesSync();
    final header = readPngHeader(bytes);
    expect(header.width, 512);
    expect(header.height, 512);
    expect(header.bitDepth, 8);
    expect(header.colorType, 6, reason: 'RGBA (32 bits)');
    expect(bytes.length, lessThan(1024 * 1024));
  });

  test('CA-018-08: alfa 255 en todo píxel y las cuatro esquinas son el amarillo del token', () async {
    final image = await loadRgba(_play);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (image.alpha(x, y) != 255) {
          fail('el píxel ($x, $y) tiene alfa ${image.alpha(x, y)}');
        }
      }
    }
    final last = image.width - 1;
    for (final (x, y) in [(0, 0), (last, 0), (0, last), (last, last)]) {
      expect(image.rgb(x, y), tokens.yellow, reason: 'esquina ($x, $y)');
    }
  });

  test(
    'CA-018-08: solo tinta, amarillo y su suavizado; sin borde ni sombra',
    () async {
      final image = await loadRgba(_play);
      for (final entry in colorCounts(image).entries) {
        expect(
          deviationFromBlend(entry.key, tokens.yellow, tokens.ink),
          lessThanOrEqualTo(10),
          reason: '${hexOf(entry.key)} (${entry.value} px) no es del icono',
        );
      }
      // Sin borde: la primera y la última fila y columna son amarillo liso.
      for (var i = 0; i < image.width; i++) {
        expect(image.rgb(i, 0), tokens.yellow);
        expect(image.rgb(i, image.height - 1), tokens.yellow);
        expect(image.rgb(0, i), tokens.yellow);
        expect(image.rgb(image.width - 1, i), tokens.yellow);
      }
    },
  );

  test('CA-018-08: es el original reducido a 512 (diferencia media <= 2/255) y mide el 56 %', () async {
    final play = await loadRgba(_play);
    final expected = _halved(await loadRgba(_original));
    expect(play.width, expected.width);
    var total = 0;
    for (var i = 0; i < play.data.length; i++) {
      total += (play.data[i] - expected.data[i]).abs();
    }
    expect(total / play.data.length, lessThanOrEqualTo(2));
    final m = measureFigure(
      play,
      isFigure: differsFrom(tokens.yellow, tolerance: 64),
    );
    expect(m.widthRatio, closeTo(0.56, 0.01));
    expect(m.offsetX.abs(), lessThanOrEqualTo(1));
    expect(m.offsetY.abs(), lessThanOrEqualTo(1));
  });

  test('CA-018-08: el PNG de Play no se empaqueta (ni en pubspec.yaml ni dentro de app/)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('icon-512')));
    expect(pubspec, isNot(contains('google-play')));
    expect(pubspec, isNot(contains('store/')));
    // Fuera de app/: ningún icon-512.png dentro de app/ salvo el de la web de pruebas.
    final inside = Directory('.')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('icon-512.png'))
        .map((f) => f.path)
        .where(
          (p) =>
              !p.contains('/build/') && !p.contains('flutter_template_icons'),
        );
    expect(inside, isEmpty);
  });
}
