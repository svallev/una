// Genera los recursos del icono de la app a partir del tablero 17 (spec 018, CA-018-10 y 15).
//
//   dart run tool/gen_icons.dart [android] [play] [web] [notification]
//                                                         → escribe los archivos (sin objetivos, los cuatro)
//   dart run tool/gen_icons.dart --check [objetivos]      → falla si alguno no está al día
//   --out <carpeta>     la carpeta de la app (por defecto `.`); así se prueba sin tocar el árbol
//   --source <carpeta>  la raíz del repositorio, con `design/` (por defecto `..`)
//
// Fuente única: `design/prototype/assets/icon/` (el original de 1024 y el primer plano de 432) y
// `design/tokens.json` (`palette.classic.0`, el amarillo). Sin paquetes (D29, P11): solo `dart:io`,
// `dart:convert` y `png_lite.dart`. No va en `lib/` ni se empaqueta.
//
// Qué escribe cada objetivo (rutas desde `--out`):
//   android → res/drawable-nodpi/ic_launcher_foreground.png (copia exacta del primer plano de 432)
//             res/values/ic_launcher_background.xml (el color del token)
//   play    → ../store/google-play/icon-512.png (el original a 512, RGBA con alfa 255)
//   web     → web/favicon.png (32) y web/icons/Icon-{192,512}.png y Icon-maskable-{192,512}.png
//   notification → android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_stat_una.png
//             (spec 019, P-019-7: el icono pequeño de la notificación, de 24 dp)
//
// El XML adaptable (`mipmap-anydpi/ic_launcher.xml`), el manifiesto de la web y `index.html` se
// escriben a mano: no los toca este generador.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'png_lite.dart';

const _targets = ['android', 'play', 'web', 'notification'];

final _usage =
    'Uso: dart run tool/gen_icons.dart [--check] [--out <carpeta de la app>] '
    '[--source <raíz del repositorio>] [${_targets.join('|')}]...';

void main(List<String> args) {
  exit(runGenIcons(args));
}

/// Ejecuta el generador. Devuelve el código de salida: 0 bien, 1 desactualizado o error de
/// lectura, 2 uso incorrecto. [out] y [err] son donde escribe los mensajes (por defecto, la
/// consola); así lo prueba un test sin lanzar un proceso.
int runGenIcons(List<String> args, {StringSink? out, StringSink? err}) {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  var check = false;
  var outDir = '.';
  var source = '..';
  final targets = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--check') {
      check = true;
    } else if (arg == '--out' || arg == '--source') {
      if (i + 1 >= args.length) {
        stderrSink.writeln('$arg necesita un valor.\n$_usage');
        return 2;
      }
      if (arg == '--out') {
        outDir = args[++i];
      } else {
        source = args[++i];
      }
    } else if (_targets.contains(arg)) {
      if (!targets.contains(arg)) targets.add(arg);
    } else {
      stderrSink.writeln('Argumento desconocido: $arg\n$_usage');
      return 2;
    }
  }
  if (targets.isEmpty) targets.addAll(_targets);

  final List<_Output> outputs;
  try {
    outputs = _build(source, targets);
  } on FileSystemException catch (e) {
    stderrSink.writeln(
      'No se puede leer ${e.path ?? 'una fuente'}: ${e.message}. '
      '¿Está `--source` ($source) en la raíz del repositorio?',
    );
    return 1;
  } on FormatException catch (e) {
    stderrSink.writeln('Fuente del icono no válida: ${e.message}');
    return 1;
  }

  final stale = <String>[];
  for (final output in outputs) {
    final file = File('$outDir/${output.path}');
    if (output.matches(file)) continue;
    stale.add(output.path);
    if (!check) {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(output.bytes);
    }
  }

  if (check && stale.isNotEmpty) {
    stderrSink.writeln(
      'Iconos desactualizados. Ejecuta `dart run tool/gen_icons.dart`:\n - ${stale.join('\n - ')}',
    );
    return 1;
  }
  stdoutSink.writeln(
    check
        ? 'Iconos al día.'
        : 'Iconos generados (${stale.length} archivos actualizados).',
  );
  return 0;
}

/// Un archivo que debe existir con este contenido.
class _Output {
  const _Output.exact(this.path, this.bytes) : comparePixels = false;

  /// Un PNG recodificado por el generador: se compara por **píxeles**, no por bytes (otra versión
  /// de zlib comprime distinto el mismo dibujo y eso no es una diferencia).
  const _Output.png(this.path, this.bytes) : comparePixels = true;

  /// Ruta desde la carpeta de la app (`--out`).
  final String path;
  final Uint8List bytes;
  final bool comparePixels;

  bool matches(File file) {
    if (!file.existsSync()) return false;
    final current = Uint8List.fromList(file.readAsBytesSync());
    if (!comparePixels) return _sameBytes(current, bytes);
    try {
      final a = decodePng(current);
      final b = decodePng(bytes);
      return a.width == b.width &&
          a.height == b.height &&
          _sameBytes(a.rgba, b.rgba);
    } on FormatException {
      return false;
    }
  }
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<_Output> _build(String source, List<String> targets) {
  final iconDir = '$source/design/prototype/assets/icon';
  final outputs = <_Output>[];

  if (targets.contains('android')) {
    final foreground = File('$iconDir/adaptive-foreground-432.png');
    final bytes = Uint8List.fromList(foreground.readAsBytesSync());
    final image = decodePng(bytes);
    if (image.width != 432 || image.height != 432) {
      throw FormatException(
        'adaptive-foreground-432.png mide ${image.width} x ${image.height}, '
        'no 432 x 432 (4 x 108 dp)',
      );
    }
    final yellow = _yellowHex('$source/design/tokens.json');
    outputs
      ..add(
        _Output.exact(
          'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
          bytes,
        ),
      )
      ..add(
        _Output.exact(
          'android/app/src/main/res/values/ic_launcher_background.xml',
          Uint8List.fromList(
            utf8.encode('''
<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por tool/gen_icons.dart desde design/tokens.json (palette.classic.0). No editar a mano. -->
<resources>
    <color name="ic_launcher_background">$yellow</color>
</resources>
'''),
          ),
        ),
      );
  }

  PngImage? original;
  PngImage loadOriginal() {
    final image = original ??= readPngFile('$iconDir/icon-1024.png');
    if (image.width != 1024 || image.height != 1024) {
      throw FormatException(
        'icon-1024.png mide ${image.width} x ${image.height}, no 1024 x 1024',
      );
    }
    return image;
  }

  if (targets.contains('play')) {
    outputs.add(
      _Output.png(
        '../store/google-play/icon-512.png',
        encodePng(resizeArea(loadOriginal(), 512, 512)),
      ),
    );
  }

  if (targets.contains('web')) {
    PngImage at(int size) => resizeArea(loadOriginal(), size, size);
    final i192 = encodePng(at(192));
    final i512 = encodePng(at(512));
    // Los «maskable» son el mismo dibujo: la «u.» a sangre ya cabe en su zona segura (40 %).
    outputs
      ..add(_Output.png('web/favicon.png', encodePng(at(32))))
      ..add(_Output.png('web/icons/Icon-192.png', i192))
      ..add(_Output.png('web/icons/Icon-512.png', i512))
      ..add(_Output.png('web/icons/Icon-maskable-192.png', i192))
      ..add(_Output.png('web/icons/Icon-maskable-512.png', i512));
  }

  if (targets.contains('notification')) {
    outputs.addAll(_notificationIcons('$iconDir/adaptive-foreground-432.png'));
  }
  return outputs;
}

/// Las cinco densidades del icono pequeño de la notificación (24 dp: 24, 36, 48, 72 y 96 px).
const _notificationDensities = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

/// Lado del icono pequeño en dp y margen que se deja por cada lado: la «u.» ocupa 22 dp de ancho.
const _notificationDp = 24;
const _notificationMarginDp = 1;

/// El icono pequeño de la notificación (spec 019, P-019-7): **la silueta de la «u.»** del primer
/// plano del icono adaptable (la caja de su alfa, recortada), solo con alfa y en blanco (Android
/// ignora el color de un icono pequeño y lo pinta de gris o con el acento), centrada en 24 dp con
/// 1 dp de margen. La capa monocroma de 432 px dibuja la «u.» al 56 % del círculo: a 24 dp
/// saldría minúscula y pesada.
List<_Output> _notificationIcons(String foregroundPath) {
  final foreground = readPngFile(foregroundPath);
  var minX = foreground.width;
  var minY = foreground.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < foreground.height; y++) {
    for (var x = 0; x < foreground.width; x++) {
      if (foreground.rgba[(y * foreground.width + x) * 4 + 3] == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) {
    throw const FormatException(
      'adaptive-foreground-432.png no tiene ningún píxel visible',
    );
  }
  final cropWidth = maxX - minX + 1;
  final cropHeight = maxY - minY + 1;
  // La figura recortada, en blanco y con su alfa.
  final crop = Uint8List(cropWidth * cropHeight * 4);
  for (var y = 0; y < cropHeight; y++) {
    for (var x = 0; x < cropWidth; x++) {
      final from = ((minY + y) * foreground.width + minX + x) * 4;
      final to = (y * cropWidth + x) * 4;
      crop[to] = 255;
      crop[to + 1] = 255;
      crop[to + 2] = 255;
      crop[to + 3] = foreground.rgba[from + 3];
    }
  }
  final silhouette = PngImage(cropWidth, cropHeight, crop);

  return [
    for (final MapEntry(key: density, value: side)
        in _notificationDensities.entries)
      _Output.png(
        'android/app/src/main/res/drawable-$density/ic_stat_una.png',
        encodePng(_centered(silhouette, side)),
      ),
  ];
}

/// [silhouette] reducida al ancho de contenido (22 dp) y centrada sobre un lienzo transparente
/// de [side] x [side] px. En hdpi (1,5 px por dp) el contenido pierde un píxel para que los
/// márgenes sean iguales en los dos lados.
PngImage _centered(PngImage silhouette, int side) {
  var width =
      side * (_notificationDp - 2 * _notificationMarginDp) ~/ _notificationDp;
  if ((side - width).isOdd) width--;
  final height = (width * silhouette.height / silhouette.width).round();
  final scaled = resizeArea(silhouette, width, height);
  final canvas = Uint8List(side * side * 4);
  final left = (side - width) ~/ 2;
  final top = (side - height) ~/ 2;
  for (var y = 0; y < height; y++) {
    canvas.setRange(
      ((top + y) * side + left) * 4,
      ((top + y) * side + left + width) * 4,
      scaled.rgba,
      y * width * 4,
    );
  }
  return PngImage(side, side, canvas);
}

/// `palette.classic.0` de [tokensPath] como `#RRGGBB` en mayúsculas.
String _yellowHex(String tokensPath) {
  final json = jsonDecode(File(tokensPath).readAsStringSync());
  final palette = json is Map ? json['palette'] : null;
  final classic = palette is Map ? palette['classic'] : null;
  final first = classic is Map ? classic['0'] : null;
  final value = first is Map ? first[r'$value'] : null;
  if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw const FormatException(
      'design/tokens.json: falta palette.classic.0 como #RRGGBB',
    );
  }
  return value.toUpperCase();
}
