import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_icons.dart';
import '../../tool/png_lite.dart';
import '../support/icon_image.dart';

/// Spec 018, T-018-02: el generador de iconos sin dependencias (`tool/gen_icons.dart` y
/// `tool/png_lite.dart`). Las rutas son relativas a `app/` (el directorio de `flutter test`).
///
/// Los tests **no** miden con `png_lite`: las dimensiones, el tipo de color y los píxeles de lo
/// que escribe el generador se leen con las ayudas de `test/support/icon_image.dart`
/// (cabecera a mano y `dart:ui`), de modo que un fallo del generador no se esconde a sí mismo.
const _iconDir = '../design/prototype/assets/icon';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('png_lite', () {
    test(
      'CA-018-10: ida y vuelta: codificar y decodificar da la misma imagen',
      () {
        final data = Uint8List(5 * 3 * 4);
        for (var i = 0; i < data.length; i++) {
          data[i] = (i * 37 + 11) & 0xFF;
        }
        final image = PngImage(5, 3, data);
        final bytes = encodePng(image);
        final back = decodePng(bytes);
        expect(back.width, 5);
        expect(back.height, 3);
        expect(back.rgba, data);
        // Y es un RGBA de 8 bits para un lector independiente.
        final header = readPngHeader(bytes);
        expect(
          [header.width, header.height, header.bitDepth, header.colorType],
          [5, 3, 8, 6],
        );
      },
    );

    test('CA-018-10: decodifica los PNG del tablero igual que dart:ui '
        '(RGB y RGBA, filtros 1, 2 y 4)', () async {
      for (final name in [
        'icon-1024.png', // RGB; filtros 1, 2 y 4
        'adaptive-foreground-432.png', // RGBA; filtro 2
        'adaptive-monochrome-432.png',
      ]) {
        final bytes = File('$_iconDir/$name').readAsBytesSync();
        final mine = decodePng(Uint8List.fromList(bytes));
        final theirs = await decodeRgba(bytes);
        expect(mine.width, theirs.width, reason: name);
        expect(mine.height, theirs.height, reason: name);
        var checked = 0;
        for (var y = 0; y < mine.height; y++) {
          for (var x = 0; x < mine.width; x++) {
            final o = (y * mine.width + x) * 4;
            // `dart:ui` decodifica premultiplicado: el color solo se compara con alfa alto.
            expect(mine.rgba[o + 3], theirs.alpha(x, y), reason: '$name $x,$y');
            if (mine.rgba[o + 3] >= 200) {
              checked++;
              expect(mine.rgba[o], closeTo(theirs.red(x, y), 1));
              expect(mine.rgba[o + 1], closeTo(theirs.green(x, y), 1));
              expect(mine.rgba[o + 2], closeTo(theirs.blue(x, y), 1));
            }
          }
        }
        expect(checked, greaterThan(1000), reason: name);
      }
    });

    test('CA-018-10: un PNG RGB sale con alfa 255', () {
      final bytes = File('$_iconDir/icon-1024.png').readAsBytesSync();
      expect(readPngHeader(Uint8List.fromList(bytes)).colorType, 2);
      final image = decodePng(Uint8List.fromList(bytes));
      for (var i = 3; i < image.rgba.length; i += 4) {
        expect(image.rgba[i], 255);
      }
    });

    test('CA-018-10: deshace los cinco filtros (incluido el 3, que los '
        'PNG del tablero no usan)', () {
      const w = 6;
      const h = 5;
      const bpp = 4;
      final pixels = Uint8List(w * h * bpp);
      for (var i = 0; i < pixels.length; i++) {
        pixels[i] = (i * 53 + (i >> 3) * 7) & 0xFF;
      }
      // Filtra cada fila con un tipo distinto (0..4), como lo haría un codificador.
      final raw = BytesBuilder();
      for (var y = 0; y < h; y++) {
        final filter = y % 5;
        raw.addByte(filter);
        for (var i = 0; i < w * bpp; i++) {
          int at(int row, int col) =>
              (row < 0 || col < 0) ? 0 : pixels[row * w * bpp + col];
          final x = at(y, i);
          final a = at(y, i - bpp);
          final b = at(y - 1, i);
          final c = at(y - 1, i - bpp);
          final predictor = switch (filter) {
            0 => 0,
            1 => a,
            2 => b,
            3 => (a + b) >> 1,
            _ => _paethPredictor(a, b, c),
          };
          raw.addByte((x - predictor) & 0xFF);
        }
      }
      final header = ByteData(13)
        ..setUint32(0, w)
        ..setUint32(4, h)
        ..setUint8(8, 8)
        ..setUint8(9, 6);
      final png = BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(pngChunk('IHDR', header.buffer.asUint8List()))
        ..add(pngChunk('IDAT', ZLibCodec().encode(raw.takeBytes())))
        ..add(pngChunk('IEND', const []));
      expect(decodePng(png.takeBytes()).rgba, pixels);
    });

    test('CA-018-10: rechaza lo que no entiende, con un error claro', () {
      Uint8List png({
        int depth = 8,
        int colorType = 6,
        int interlace = 0,
        bool corruptCrc = false,
      }) {
        final header = ByteData(13)
          ..setUint32(0, 1)
          ..setUint32(4, 1)
          ..setUint8(8, depth)
          ..setUint8(9, colorType)
          ..setUint8(12, interlace);
        final idat = pngChunk('IDAT', ZLibCodec().encode([0, 1, 2, 3, 4]));
        if (corruptCrc) idat[idat.length - 1] ^= 0xFF;
        return (BytesBuilder()
              ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
              ..add(pngChunk('IHDR', header.buffer.asUint8List()))
              ..add(idat)
              ..add(pngChunk('IEND', const [])))
            .takeBytes();
      }

      expect(() => decodePng(png()), returnsNormally);
      expect(() => decodePng(png(depth: 16)), throwsFormatException);
      expect(() => decodePng(png(colorType: 3)), throwsFormatException);
      expect(() => decodePng(png(interlace: 1)), throwsFormatException);
      expect(() => decodePng(png(corruptCrc: true)), throwsFormatException);
      expect(() => decodePng(Uint8List(40)), throwsFormatException);
      expect(() => decodePng(Uint8List(3)), throwsFormatException);
    });

    test(
      'CA-018-08: la reducción 2 x 2 es el promedio exacto de cada bloque',
      () {
        // Cuatro píxeles opacos (0, 100, 200, 40 en rojo) -> 85 exacto; verde y azul distintos.
        final data = Uint8List.fromList([
          0, 10, 20, 255, //
          100, 30, 40, 255,
          200, 50, 60, 255,
          40, 70, 80, 255,
        ]);
        final out = resizeArea(PngImage(2, 2, data), 1, 1);
        expect(out.rgba, [85, 40, 50, 255]);
      },
    );

    test('CA-018-08: 4 x 4 a 2 x 2 promedia cada bloque por separado', () {
      final data = Uint8List(4 * 4 * 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final o = (y * 4 + x) * 4;
          // Bloque (0,0)=10, (1,0)=20, (0,1)=30, (1,1)=40, más un +0/+2 dentro del bloque.
          final base = 10 * ((x ~/ 2) + 2 * (y ~/ 2) + 1);
          data[o] = base + ((x % 2 + y % 2) == 1 ? 2 : 0);
          data[o + 1] = 0;
          data[o + 2] = 0;
          data[o + 3] = 255;
        }
      }
      final out = resizeArea(PngImage(4, 4, data), 2, 2);
      expect([for (var i = 0; i < 16; i += 4) out.rgba[i]], [11, 21, 31, 41]);
    });

    test('CA-018-08: un color liso se conserva, también con un factor '
        'fraccionario (1024 a 192)', () {
      final out = resizeArea(PngImage.solid(1024, 1024, 0xFFE55C), 192, 192);
      expect(out.width, 192);
      for (var i = 0; i < out.rgba.length; i += 4) {
        expect(out.rgba[i], 0xFF);
        expect(out.rgba[i + 1], 0xE5);
        expect(out.rgba[i + 2], 0x5C);
        expect(out.rgba[i + 3], 255);
      }
    });

    test('CA-018-08: el color pesa por el alfa (un píxel transparente no '
        'tiñe a su vecino)', () {
      final data = Uint8List.fromList([
        17, 17, 17, 255, //
        255, 255, 255, 0,
      ]);
      final out = resizeArea(PngImage(2, 1, data), 1, 1);
      // Mitad de alfa y el color del píxel opaco, no un gris.
      expect(out.rgba, [17, 17, 17, 128]);
    });
  });

  group('gen_icons', () {
    late Directory tmp;
    late String outDir;
    late StringBuffer stdoutBuf;
    late StringBuffer stderrBuf;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('gen_icons_test_');
      outDir = '${tmp.path}/app';
      Directory(outDir).createSync();
      stdoutBuf = StringBuffer();
      stderrBuf = StringBuffer();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    int run(List<String> args) => runGenIcons(
      [...args, '--out', outDir, '--source', '..'],
      out: stdoutBuf,
      err: stderrBuf,
    );

    String relative(String path) => path.substring(tmp.path.length + 1);

    List<String> filesUnderTmp() => [
      for (final e in tmp.listSync(recursive: true))
        if (e is File) relative(e.path),
    ]..sort();

    test('CA-018-10: android escribe el primer plano (copia exacta) y el fondo '
        'con el color del token', () {
      expect(run(['android']), 0, reason: stderrBuf.toString());
      expect(filesUnderTmp(), [
        'app/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
        'app/android/app/src/main/res/values/ic_launcher_background.xml',
      ]);
      const res = 'android/app/src/main/res';
      expect(
        File('$outDir/$res/drawable-nodpi/ic_launcher_foreground.png')
            .readAsBytesSync(),
        File('$_iconDir/adaptive-foreground-432.png').readAsBytesSync(),
      );
      final xml = File('$outDir/$res/values/ic_launcher_background.xml')
          .readAsStringSync();
      final yellow = readIconTokens().yellowHex;
      expect(yellow, '#FFE55C');
      expect(xml, contains('GENERADO'));
      expect(
        xml,
        contains('<color name="ic_launcher_background">$yellow</color>'),
      );
      expect(xml, startsWith('<?xml version="1.0" encoding="utf-8"?>'));
    });

    test('CA-018-08: play escribe el icono de 512 en RGBA, con alfa 255, '
        'fuera de app/', () async {
      expect(run(['play']), 0, reason: stderrBuf.toString());
      expect(filesUnderTmp(), ['store/google-play/icon-512.png']);
      final bytes = File('${tmp.path}/store/google-play/icon-512.png')
          .readAsBytesSync();
      final header = readPngHeader(bytes);
      expect(
        [header.width, header.height, header.bitDepth, header.colorType],
        [512, 512, 8, 6],
      );
      final image = await decodeRgba(bytes);
      for (var y = 0; y < image.height; y += 7) {
        for (var x = 0; x < image.width; x += 7) {
          expect(image.alpha(x, y), 255);
        }
      }
      final yellow = readIconTokens().yellow;
      for (final (x, y) in [(0, 0), (511, 0), (0, 511), (511, 511)]) {
        expect(image.rgb(x, y), yellow, reason: 'esquina $x,$y');
      }
      expect(bytes.length, lessThan(1024 * 1024));
    });

    test('CA-018-09: web escribe el favicon de 32 y los iconos 192 y 512, '
        'normales y maskable', () async {
      expect(run(['web']), 0, reason: stderrBuf.toString());
      expect(filesUnderTmp(), [
        'app/web/favicon.png',
        'app/web/icons/Icon-192.png',
        'app/web/icons/Icon-512.png',
        'app/web/icons/Icon-maskable-192.png',
        'app/web/icons/Icon-maskable-512.png',
      ]);
      final sizes = {
        'favicon.png': 32,
        'icons/Icon-192.png': 192,
        'icons/Icon-512.png': 512,
        'icons/Icon-maskable-192.png': 192,
        'icons/Icon-maskable-512.png': 512,
      };
      final yellow = readIconTokens().yellow;
      for (final entry in sizes.entries) {
        final bytes = File('$outDir/web/${entry.key}').readAsBytesSync();
        final header = readPngHeader(bytes);
        expect(
          [header.width, header.height, header.bitDepth, header.colorType],
          [entry.value, entry.value, 8, 6],
          reason: entry.key,
        );
        final image = await decodeRgba(bytes);
        final last = entry.value - 1;
        expect(image.rgb(0, 0), yellow, reason: entry.key);
        expect(image.rgb(last, last), yellow, reason: entry.key);
        expect(image.alpha(last, 0), 255, reason: entry.key);
      }
    });

    test('CA-018-10: sin objetivos, genera los tres', () {
      expect(run([]), 0, reason: stderrBuf.toString());
      expect(filesUnderTmp(), hasLength(8));
    });

    test('CA-018-15: --check sobre un árbol sin generar falla y lista lo '
        'que falta, sin escribir nada', () {
      expect(run(['--check']), 1);
      expect(filesUnderTmp(), isEmpty);
      final message = stderrBuf.toString();
      expect(message, contains('ic_launcher_foreground.png'));
      expect(message, contains('icon-512.png'));
      expect(message, contains('Icon-maskable-192.png'));
    });

    test('CA-018-15: --check pasa justo después de generar', () {
      expect(run([]), 0);
      stdoutBuf.clear();
      expect(run(['--check']), 0, reason: stderrBuf.toString());
      expect(stdoutBuf.toString(), contains('al día'));
    });

    test('CA-018-15: --check falla si un PNG difiere, si lo hace el XML o '
        'si el color del token no coincide', () {
      expect(run([]), 0);
      final favicon = File('$outDir/web/favicon.png');
      final original = favicon.readAsBytesSync();

      // Un píxel distinto (y el archivo sigue siendo un PNG válido).
      final changed = decodePng(Uint8List.fromList(original));
      changed.rgba[0] ^= 0xFF;
      favicon.writeAsBytesSync(encodePng(changed));
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('web/favicon.png'));
      expect(run(['web']), 0);
      expect(run(['--check']), 0, reason: stderrBuf.toString());

      // Basura en lugar de un PNG.
      favicon.writeAsBytesSync([1, 2, 3]);
      stderrBuf.clear();
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('web/favicon.png'));
      expect(run([]), 0);

      // El XML con otro color.
      final xml = File(
        '$outDir/android/app/src/main/res/values/ic_launcher_background.xml',
      );
      xml.writeAsStringSync(
        xml.readAsStringSync().replaceAll('#FFE55C', '#0175C2'),
      );
      stderrBuf.clear();
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('ic_launcher_background.xml'));

      // El primer plano de Android no es la copia exacta.
      expect(run(['android']), 0);
      File(
        '$outDir/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
      ).writeAsBytesSync(encodePng(PngImage.solid(432, 432, 0xFFE55C)));
      stderrBuf.clear();
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('ic_launcher_foreground.png'));
    });

    test('CA-018-15: --check no reescribe un PNG que solo difiere en la '
        'compresión', () {
      expect(run(['web']), 0);
      final favicon = File('$outDir/web/favicon.png');
      // El mismo dibujo, con otro nivel de zlib: no es una diferencia.
      final image = decodePng(Uint8List.fromList(favicon.readAsBytesSync()));
      final raw = BytesBuilder();
      for (var y = 0; y < image.height; y++) {
        raw.addByte(0);
        raw.add(
          image.rgba.sublist(y * image.width * 4, (y + 1) * image.width * 4),
        );
      }
      final header = ByteData(13)
        ..setUint32(0, image.width)
        ..setUint32(4, image.height)
        ..setUint8(8, 8)
        ..setUint8(9, 6);
      final other =
          (BytesBuilder()
                ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
                ..add(pngChunk('IHDR', header.buffer.asUint8List()))
                ..add(
                  pngChunk('IDAT', ZLibCodec(level: 1).encode(raw.takeBytes())),
                )
                ..add(pngChunk('IEND', const [])))
              .takeBytes();
      favicon.writeAsBytesSync(other);
      expect(run(['web', '--check']), 0, reason: stderrBuf.toString());
      expect(run(['web']), 0);
      expect(favicon.readAsBytesSync(), other);
    });

    test('CA-018-12: un objetivo o una opción desconocidos fallan con el uso '
        'y no escriben nada', () {
      expect(run(['ios']), 2);
      expect(stderrBuf.toString(), contains('android'));
      expect(runGenIcons(['--nope'], out: stdoutBuf, err: stderrBuf), 2);
      expect(runGenIcons(['--out'], out: stdoutBuf, err: stderrBuf), 2);
      expect(filesUnderTmp(), isEmpty);
    });

    test('CA-018-12: sin fuentes, falla con un mensaje claro', () {
      final code = runGenIcons(
        ['android', '--out', outDir, '--source', '${tmp.path}/nada'],
        out: stdoutBuf,
        err: stderrBuf,
      );
      expect(code, 1);
      expect(stderrBuf.toString(), contains('adaptive-foreground-432.png'));
    });

    test('CA-018-12: las herramientas solo importan dart: y su vecina '
        '(sin paquetes, D29)', () {
      final imports = RegExp(
        r'''^import\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );
      for (final path in ['tool/gen_icons.dart', 'tool/png_lite.dart']) {
        final source = File(path).readAsStringSync();
        final found = [for (final m in imports.allMatches(source)) m.group(1)!];
        expect(found, isNotEmpty, reason: path);
        for (final import in found) {
          expect(
            import.startsWith('dart:') || import == 'png_lite.dart',
            isTrue,
            reason: '$path importa $import',
          );
        }
      }
    });
  });
}

int _paethPredictor(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}
