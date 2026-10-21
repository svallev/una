// Gráfico de funciones de la ficha de Google Play (spec 023, T-023-10, CA-023-10).
//
// El archivo de referencia ES el gráfico que se sube: `store/google-play/feature-graphic.png`
// (1024 × 500, PNG de 24 bits sin alfa). Con `--update-goldens` se escribe; sin él, falla si el
// dibujo ya no coincide con los tokens, el icono o el nombre de la identidad (CL-023-9).
// Se genera y compara solo en Linux (CI): ver docs/testing.md, «Goldens».
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/app/app_identity.g.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/icon_image.dart';
import '../support/rgb_golden.dart';

const _golden = '../../../store/google-play/feature-graphic.png';
const _goldenPath = '../store/google-play/feature-graphic.png';
const _foreground =
    'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _width = 1024.0;
const _height = 500.0;
const _tile = 252.0;

/// Primer plano del icono (la «u.» sobre fondo transparente) recortado a su
/// figura, para dibujarlo sin el margen de la zona segura del icono adaptable.
class _Mark {
  const _Mark(this.image, this.crop);
  final ui.Image image;
  final Rect crop;
}

Future<_Mark> _loadMark() async {
  final bytes = File(_foreground).readAsBytesSync();
  final rgba = await decodeRgba(bytes);
  var minX = rgba.width, minY = rgba.height, maxX = -1, maxY = -1;
  for (var y = 0; y < rgba.height; y++) {
    for (var x = 0; x < rgba.width; x++) {
      if (rgba.alpha(x, y) > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return _Mark(
    frame.image,
    Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark);
  final _Mark mark;

  @override
  void paint(Canvas canvas, Size size) {
    // La figura ocupa el 68 % del ancho del bloque, centrada.
    final w = size.width * 0.68;
    final h = w * mark.crop.height / mark.crop.width;
    final dst = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: h,
    );
    canvas.drawImageRect(
      mark.image,
      mark.crop,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mark != mark;
}

Widget _graphic(_Mark mark) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: UnaColors.paper,
      child: SizedBox(
        width: _width,
        height: _height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // El bloque del icono: amarillo del icono, borde de tinta y sombra dura.
            Container(
              width: _tile,
              height: _tile,
              decoration: BoxDecoration(
                color: UnaPalettes.classic[0],
                border: Border.all(color: UnaColors.ink, width: 6),
                boxShadow: const [
                  BoxShadow(color: UnaColors.ink, offset: Offset(14, 14)),
                ],
              ),
              child: CustomPaint(painter: _MarkPainter(mark)),
            ),
            const SizedBox(width: 84),
            const Text(
              AppIdentity.displayName,
              style: TextStyle(
                fontFamily: UnaFonts.display,
                fontWeight: UnaFontWeights.black,
                fontSize: 210,
                height: 1,
                letterSpacing: -6,
                color: UnaColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  group('CA-023-10: gráfico de funciones', () {
    testWidgets(
      'CA-023-10: el dibujo coincide con store/google-play/feature-graphic.png',
      (tester) async {
        final previous = goldenFileComparator;
        goldenFileComparator = RgbGoldenComparator(
          Uri.parse(
            '${Directory.current.path}/test/store/feature_graphic_test.dart',
          ),
        );
        addTearDown(() => goldenFileComparator = previous);
        tester.view
          ..physicalSize = const Size(_width, _height)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        late _Mark mark;
        await tester.runAsync(() async => mark = await _loadMark());
        await tester.pumpWidget(_graphic(mark));
        await tester.pump();

        await expectLater(
          find.byType(SizedBox).first,
          matchesGoldenFile(_golden),
        );
      },
      skip: _skip,
    );

    test(
      'CA-023-10: el archivo es un PNG de 24 bits sin alfa de 1024 × 500',
      () {
        final header = readPngHeader(File(_goldenPath).readAsBytesSync());
        expect(header.width, 1024);
        expect(header.height, 500);
        expect(header.bitDepth, 8);
        expect(header.colorType, 2, reason: 'RGB: sin canal alfa');
        expect(header.hasAlphaChannel, isFalse);
      },
    );
  });
}
