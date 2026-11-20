import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_icons.dart';
import '../../tool/png_lite.dart';
import '../support/icon_image.dart';

/// Spec 028, T-028-04, CA-028-07: el objetivo `ios` de `tool/gen_icons.dart` (el icono de iOS
/// desde el original de 1024 de la 018, sin canal alfa y sin ningún icono de la plantilla de
/// Flutter). Las rutas son relativas a `app/` (el directorio de `flutter test`).
///
/// Como en `gen_icons_test.dart`, lo que escribe el generador se mide con `dart:ui` y con la
/// cabecera leída a mano, no con `png_lite`.
const _source = '../design/prototype/assets/icon/icon-1024.png';
const _set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('png_lite (RGB)', () {
    test('CA-028-07: encodePngRgb escribe RGB de 8 bits, sin alfa, y la '
        'vuelta da los mismos píxeles', () {
      final data = Uint8List(4 * 3 * 4);
      for (var i = 0; i < data.length; i++) {
        data[i] = (i * 29 + 5) & 0xFF;
      }
      for (var i = 3; i < data.length; i += 4) {
        data[i] = 255;
      }
      final bytes = encodePngRgb(PngImage(4, 3, data));
      final header = readPngHeader(bytes);
      expect(
        [header.width, header.height, header.bitDepth, header.colorType],
        [4, 3, 8, 2],
      );
      expect(header.hasAlphaChannel, isFalse);
      expect(decodePng(bytes).rgba, data);
    });

    test('CA-028-07: isOpaque distingue una imagen opaca de una con un solo '
        'píxel translúcido', () {
      final opaque = PngImage.solid(2, 2, 0x112233, alpha: 255);
      expect(isOpaque(opaque), isTrue);
      final holed = PngImage(2, 2, Uint8List.fromList(opaque.rgba));
      holed.rgba[4 * 3 + 3] = 254;
      expect(isOpaque(holed), isFalse);
    });
  });

  group('gen_icons ios', () {
    late Directory tmp;
    late String outDir;
    late StringBuffer stdoutBuf;
    late StringBuffer stderrBuf;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('gen_icons_ios_test_');
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

    List<String> setFiles() => [
      for (final e in Directory('$outDir/$_set').listSync())
        e.path.substring('$outDir/$_set/'.length),
    ]..sort();

    List<Map<String, dynamic>> contentsImages() {
      final json = jsonDecode(
        File('$outDir/$_set/Contents.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      return [
        for (final i in json['images'] as List) i as Map<String, dynamic>,
      ];
    }

    /// Píxeles de lado de un `size` (puntos, «60x60» o «83.5x83.5») y una `scale` («3x»).
    int pixels(Map<String, dynamic> image) {
      final points = double.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      return (points * scale).round();
    }

    test('CA-028-07: escribe Contents.json y un PNG por entrada, solo de '
        'iPhone (más el de la tienda) y sin sobras', () {
      expect(run(['ios']), 0, reason: stderrBuf.toString());
      final images = contentsImages();
      expect(images, hasLength(9));
      // La app es solo iPhone (CA-028-04): ninguna entrada de iPad.
      expect({for (final i in images) i['idiom']}, {'iphone', 'ios-marketing'});
      expect(images.where((i) => i['idiom'] == 'ios-marketing'), hasLength(1));
      // Cada entrada apunta a un archivo y no hay más PNG que los de Contents.json.
      final names = [for (final i in images) i['filename'] as String];
      expect(names.toSet(), hasLength(names.length));
      expect(setFiles(), [...names, 'Contents.json']..sort());
      // Los tamaños que exige iOS 16 en iPhone: 20, 29, 40, 60 pt a 2x y 3x, y 1024.
      expect(
        {for (final i in images) '${i['size']}@${i['scale']}'},
        {
          '20x20@2x',
          '20x20@3x',
          '29x29@2x',
          '29x29@3x',
          '40x40@2x',
          '40x40@3x',
          '60x60@2x',
          '60x60@3x',
          '1024x1024@1x',
        },
      );
    });

    test('CA-028-07: cada PNG mide lo que dice su entrada y es RGB de 8 bits '
        'sin canal alfa', () {
      expect(run(['ios']), 0, reason: stderrBuf.toString());
      for (final image in contentsImages()) {
        final name = image['filename'] as String;
        final header = readPngHeader(
          File('$outDir/$_set/$name').readAsBytesSync(),
        );
        final side = pixels(image);
        expect(
          [header.width, header.height, header.bitDepth, header.colorType],
          [side, side, 8, 2],
          reason: name,
        );
        expect(header.hasAlphaChannel, isFalse, reason: name);
      }
    });

    test('CA-028-07: el de 1024 es el original de la 018 (mismos píxeles) y '
        'los demás son el mismo dibujo reducido', () async {
      expect(run(['ios']), 0, reason: stderrBuf.toString());
      final original = await loadRgba(_source);
      // Zonas del dibujo: el fondo amarillo en la esquina y la tinta en el palo izquierdo de la «u».
      final paper = original.rgb(2, 2);
      final ink = original.rgb(300, 450);
      expect(paper, isNot(ink));
      for (final image in contentsImages()) {
        final name = image['filename'] as String;
        final made = await loadRgba('$outDir/$_set/$name');
        expect(made.width, pixels(image), reason: name);
        // Esquinas y un punto dentro del palo, a la misma posición relativa.
        for (final corner in [(0, 0), (1, 0), (0, 1), (1, 1)]) {
          final x = corner.$1 == 0 ? 0 : made.width - 1;
          final y = corner.$2 == 0 ? 0 : made.height - 1;
          expect(made.rgb(x, y), paper, reason: '$name esquina $x,$y');
          expect(made.alpha(x, y), 255, reason: name);
        }
        final inside = made.rgb(
          (300 * made.width / 1024).floor(),
          (450 * made.height / 1024).floor(),
        );
        expect(inside, ink, reason: '$name palo de la «u»');
        if (made.width == 1024) {
          expect(made.data, original.data, reason: name);
        }
      }
    });

    test(
      'CA-028-07: la sección icon de check-ios-parity.sh da por buenos los '
      'iconos escritos (ninguno igual a uno de la plantilla, ninguno con alfa)',
      () {
        expect(run(['ios']), 0, reason: stderrBuf.toString());
        final result = Process.runSync('bash', [
          '../tools/check-ios-parity.sh',
          '--root',
          tmp.path,
          '--section',
          'icon',
        ]);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      },
    );

    test('CA-028-07: retira lo que sobra en la carpeta (los PNG de la '
        'plantilla, por ejemplo los de iPad) y deja Contents.json', () {
      Directory('$outDir/$_set').createSync(recursive: true);
      for (final stale in [
        'Icon-App-76x76@2x.png',
        'Icon-App-83.5x83.5@2x.png',
        'Icon-App-29x29@1x.png',
      ]) {
        File('$outDir/$_set/$stale').writeAsBytesSync([1, 2, 3]);
      }
      expect(run(['ios']), 0, reason: stderrBuf.toString());
      final names = [for (final i in contentsImages()) i['filename']];
      expect(setFiles(), [...names, 'Contents.json']..sort());
    });

    test('CA-028-07: --check falla si sobra un PNG de la plantilla, lo nombra '
        'y no lo borra', () {
      expect(run(['ios']), 0);
      final stale = File('$outDir/$_set/Icon-App-76x76@2x.png')
        ..writeAsBytesSync([1, 2, 3]);
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Icon-App-76x76@2x.png'));
      expect(stale.existsSync(), isTrue);
    });

    test('CA-028-07: --check sobre un árbol sin generar falla, lista los '
        'iconos y no escribe nada', () {
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Icon-App-60x60@3x.png'));
      expect(stderrBuf.toString(), contains('Contents.json'));
      expect(Directory(outDir).listSync(), isEmpty);
    });

    test('CA-028-07: --check pasa justo después de generar', () {
      expect(run(['ios']), 0);
      stdoutBuf.clear();
      expect(run(['ios', '--check']), 0, reason: stderrBuf.toString());
      expect(stdoutBuf.toString(), contains('al día'));
    });

    test('CA-028-07: --check falla si un icono deja de coincidir, si falta uno '
        'o si Contents.json cambia', () {
      expect(run(['ios']), 0);
      final file = File('$outDir/$_set/Icon-App-60x60@3x.png');
      final good = file.readAsBytesSync();
      // Otro dibujo (del mismo tamaño).
      final other = decodePng(Uint8List.fromList(good));
      other.rgba[0] ^= 0xFF;
      file.writeAsBytesSync(encodePngRgb(other));
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Icon-App-60x60@3x.png'));
      file.writeAsBytesSync(good);
      expect(run(['ios', '--check']), 0, reason: stderrBuf.toString());

      file.deleteSync();
      stderrBuf.clear();
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Icon-App-60x60@3x.png'));
      expect(file.existsSync(), isFalse);

      expect(run(['ios']), 0);
      final contents = File('$outDir/$_set/Contents.json');
      contents.writeAsStringSync(
        contents.readAsStringSync().replaceAll('iphone', 'ipad'),
      );
      stderrBuf.clear();
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Contents.json'));
    });

    test('CA-028-07: --check falla si un icono tiene canal alfa aunque sus '
        'píxeles sean los buenos (iOS lo rechaza)', () {
      expect(run(['ios']), 0);
      final file = File('$outDir/$_set/Icon-App-40x40@2x.png');
      file.writeAsBytesSync(
        encodePng(decodePng(Uint8List.fromList(file.readAsBytesSync()))),
      );
      expect(readPngHeader(file.readAsBytesSync()).colorType, 6);
      expect(run(['ios', '--check']), 1);
      expect(stderrBuf.toString(), contains('Icon-App-40x40@2x.png'));
      // Y generar lo repone.
      expect(run(['ios']), 0);
      expect(readPngHeader(file.readAsBytesSync()).colorType, 2);
    });

    test('CA-028-07: un original con transparencia no se acepta (el alfa se '
        'perdería en silencio)', () {
      final source = Directory('${tmp.path}/repo/design/prototype/assets/icon')
        ..createSync(recursive: true);
      for (final name in [
        'icon-1024.png',
        'adaptive-foreground-432.png',
        'adaptive-monochrome-432.png',
      ]) {
        File('../design/prototype/assets/icon/$name')
            .copySync('${source.path}/$name');
      }
      File('../design/tokens.json')
          .copySync('${tmp.path}/repo/design/tokens.json');
      final holed = decodePng(
        Uint8List.fromList(
          File('${source.path}/icon-1024.png').readAsBytesSync(),
        ),
      );
      holed.rgba[3] = 0;
      File('${source.path}/icon-1024.png').writeAsBytesSync(encodePng(holed));
      final code = runGenIcons(
        ['ios', '--out', outDir, '--source', '${tmp.path}/repo'],
        out: stdoutBuf,
        err: stderrBuf,
      );
      expect(code, 1);
      expect(stderrBuf.toString(), contains('icon-1024.png'));
      expect(stderrBuf.toString(), contains('transparen'));
      expect(Directory(outDir).listSync(), isEmpty);
    });

    test('CA-028-07: sin objetivos no escribe el de iOS (el conjunto de la 018 '
        'sigue igual) y un objetivo desconocido sigue fallando', () {
      expect(run([]), 0, reason: stderrBuf.toString());
      expect(Directory('$outDir/ios').existsSync(), isFalse);
      expect(run(['windows']), 2);
      expect(stderrBuf.toString(), contains('ios'));
    });

    test('CA-028-07: si la carpeta del conjunto es un enlace simbólico, falla '
        'y no escribe a través de él (CA-020-15)', () {
      final target = Directory('${tmp.path}/fuera')..createSync();
      Directory('$outDir/ios/Runner/Assets.xcassets')
          .createSync(recursive: true);
      Link('$outDir/$_set').createSync(target.path);
      expect(run(['ios']), 1);
      expect(stderrBuf.toString(), contains('enlace'));
      expect(target.listSync(), isEmpty);
    });
  });

  test('CA-028-07: el icono de iOS del árbol está al día con el generador '
      '(--check ios)', () {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(
      runGenIcons(['ios', '--check'], out: out, err: err),
      0,
      reason: err.toString(),
    );
  });
}
