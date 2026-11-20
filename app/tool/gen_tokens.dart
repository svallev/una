// Genera lib/app/theme/tokens.g.dart y el color de arranque de iOS desde ../design/tokens.json
// (fuente única, P12).
//
//   dart run tool/gen_tokens.dart          → escribe los archivos
//   dart run tool/gen_tokens.dart --check  → falla si alguno no está al día (CI)
//
// Archivos (rutas desde `app/`):
//   lib/app/theme/tokens.g.dart
//   ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json  (spec 028, CA-028-06:
//     `color.paper` en sRGB, un solo color y sin variante oscura; lo usa `LaunchScreen.storyboard`
//     y, más adelante, la vista que tapa el selector de apps, T-028-11)
import 'dart:convert';
import 'dart:io';

const _out = 'lib/app/theme/tokens.g.dart';
const _launchColorset =
    'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json';

void main(List<String> args) {
  exit(runGenTokens(args));
}

/// Ejecuta el generador. Devuelve el código de salida: 0 bien, 1 desactualizado o fuente no
/// válida. [tokensPath] y [appDir] permiten probarlo en un directorio temporal; [dart] es el
/// ejecutable con el que se formatea (por defecto el del propio proceso; dentro de `flutter test`
/// es `flutter_tester`, así que un test pasa `'dart'`).
int runGenTokens(
  List<String> args, {
  String tokensPath = '../design/tokens.json',
  String appDir = '.',
  StringSink? out,
  StringSink? err,
  String? dart,
}) {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  final t =
      jsonDecode(File(tokensPath).readAsStringSync()) as Map<String, dynamic>;
  final b = StringBuffer()
    ..writeln(
      '// GENERADO por tool/gen_tokens.dart desde design/tokens.json. No editar a mano.',
    )
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln("import 'package:flutter/animation.dart';")
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln();

  // Colores
  final colors = _entries(t['color']);
  b.writeln('abstract final class UnaColors {');
  colors.forEach(
    (k, v) => b
      ..writeln('  /// ${_doc(v)}')
      ..writeln('  static const Color $k = ${_color(v[r'$value'] as String)};'),
  );
  b.writeln('}\n');

  // Paletas (colorKey 0..4)
  b.writeln('abstract final class UnaPalettes {');
  _entries(t['palette']).forEach((name, pal) {
    final list = List.generate(
      5,
      (i) => _color((pal['$i'] as Map<String, dynamic>)[r'$value'] as String),
    );
    b.writeln('  static const List<Color> $name = [${list.join(', ')}];');
  });
  b.writeln('}\n');

  // Tipografía
  final font = t['font'] as Map<String, dynamic>;
  b.writeln('abstract final class UnaFonts {');
  _entries(font['family']).forEach(
    (k, v) => b.writeln(
      "  static const String $k = '${(v[r'$value'] as List).first}';",
    ),
  );
  b.writeln('}\n');
  b.writeln('abstract final class UnaFontWeights {');
  _entries(font['weight']).forEach(
    (k, v) => b.writeln(
      '  static const FontWeight $k = FontWeight.w${v[r'$value']};',
    ),
  );
  b.writeln('}\n');
  b.writeln('abstract final class UnaFontSizes {');
  _entries(font['size']).forEach(
    (k, v) => b
      ..writeln('  /// ${_doc(v)}')
      ..writeln('  static const double $k = ${_num(v[r'$value'])};'),
  );
  b.writeln('}\n');
  b.writeln('/// Interletrado en em (multiplicar por el tamaño de fuente).');
  b.writeln('abstract final class UnaLetterSpacing {');
  _entries(font['letterSpacing']).forEach(
    (k, v) => b.writeln('  static const double $k = ${_num(v[r'$value'])};'),
  );
  b.writeln('}\n');
  final breaks =
      (font['noteLengthBreakpoints'] as Map<String, dynamic>)[r'$value']
          as List;
  b
    ..writeln(
      '/// Longitud del texto (caracteres) a partir de la cual la nota usa un tamaño menor.',
    )
    ..writeln(
      'const List<int> unaNoteLengthBreakpoints = [${breaks.join(', ')}];\n',
    );

  // Espacios, tamaños, bordes
  for (final (cls, key) in [('UnaSpace', 'space'), ('UnaSizes', 'size')]) {
    b.writeln('abstract final class $cls {');
    _entries(t[key]).forEach(
      (k, v) => b.writeln('  static const double $k = ${_num(v[r'$value'])};'),
    );
    b.writeln('}\n');
  }
  final border = t['border'] as Map<String, dynamic>;
  b.writeln('abstract final class UnaBorders {');
  _entries(border['width']).forEach(
    (k, v) =>
        b.writeln('  static const double ${k}Width = ${_num(v[r'$value'])};'),
  );
  _entries(border['radius']).forEach(
    (k, v) =>
        b.writeln('  static const double ${k}Radius = ${_num(v[r'$value'])};'),
  );
  b.writeln('}\n');

  // Sombras duras
  b.writeln('abstract final class UnaShadows {');
  _entries(t['shadow']).forEach((k, v) {
    final s = v[r'$value'] as Map<String, dynamic>;
    b.writeln(
      '  static const BoxShadow $k = BoxShadow(color: ${_color(s['color'] as String)}, '
      'offset: Offset(${_num(s['offsetX'])}, ${_num(s['offsetY'])}), '
      'blurRadius: ${_num(s['blur'])}, spreadRadius: ${_num(s['spread'])});',
    );
  });
  b.writeln('}\n');

  // Movimiento
  final motion = t['motion'] as Map<String, dynamic>;
  b.writeln('abstract final class UnaMotion {');
  _entries(motion['duration']).forEach(
    (k, v) => b
      ..writeln('  /// ${_doc(v)}')
      ..writeln(
        '  static const Duration $k = Duration(milliseconds: ${_int(v[r'$value'])});',
      ),
  );
  _entries(motion['easing']).forEach((k, v) {
    final c = (v[r'$value'] as List)
        .map((e) => (e as num).toDouble())
        .join(', ');
    b.writeln('  static const Cubic ${k}Curve = Cubic($c);');
  });
  // Resto de valores sueltos (umbral de arrastre en px, inclinación en grados).
  for (final e in motion.entries) {
    if (e.key.startsWith(r'$') || e.key == 'duration' || e.key == 'easing') {
      continue;
    }
    final v = e.value as Map<String, dynamic>;
    b.writeln('  static const double ${e.key} = ${_num(v[r'$value'])};');
  }
  b.writeln('}');

  final String colorset;
  try {
    colorset = _launchColorsetJson(t);
  } on FormatException catch (e) {
    stderrSink.writeln('$tokensPath: ${e.message}');
    return 1;
  }
  final files = {
    '$appDir/$_out': _formatDart(
      b.toString(),
      dart ?? Platform.resolvedExecutable,
    ),
    '$appDir/$_launchColorset': colorset,
  };
  final stale = [
    for (final e in files.entries)
      if (!File(e.key).existsSync() ||
          File(e.key).readAsStringSync() != e.value)
        e.key,
  ];
  if (args.contains('--check')) {
    if (stale.isNotEmpty) {
      stderrSink.writeln(
        '${stale.map((p) => p.substring(appDir.length + 1)).join(', ')} no está al día con '
        'design/tokens.json. Ejecuta `dart run tool/gen_tokens.dart`.',
      );
      return 1;
    }
    stdoutSink.writeln('Tokens al día.');
    return 0;
  }
  for (final e in files.entries) {
    if (!stale.contains(e.key)) continue;
    File(e.key)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(e.value);
  }
  stdoutSink.writeln('Tokens generados en $_out y $_launchColorset.');
  return 0;
}

/// El `Contents.json` del color de arranque de iOS: `color.paper` en sRGB, un solo color
/// universal y **sin** variante oscura (`appearances`): el arranque es siempre `paper` (CA-028-06).
/// Los componentes van en hexadecimal (`0xF4`), exactos, en el orden alfabético que escribe Xcode.
String _launchColorsetJson(Map<String, dynamic> tokens) {
  final color = tokens['color'];
  final paper = color is Map ? color['paper'] : null;
  final value = paper is Map ? paper[r'$value'] : null;
  final hex = value is String
      ? RegExp(r'^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$')
            .firstMatch(value)
      : null;
  if (hex == null) {
    throw const FormatException('falta color.paper como #RRGGBB');
  }
  String c(int group) => '0x${hex[group]!.toUpperCase()}';
  return '''{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "${c(3)}",
          "green" : "${c(2)}",
          "red" : "${c(1)}"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''';
}

Map<String, Map<String, dynamic>> _entries(Object? group) => {
  for (final e in (group! as Map<String, dynamic>).entries)
    if (!e.key.startsWith(r'$') && e.value is Map<String, dynamic>)
      e.key: e.value as Map<String, dynamic>,
};

String _doc(Map<String, dynamic> v) =>
    ((v[r'$description'] as String?) ?? '${v[r'$value']}').replaceAll(
      '\n',
      ' ',
    );

String _num(Object? v) {
  final n = v is Map<String, dynamic> ? v['value'] as num : v! as num;
  return n.toDouble().toString();
}

String _int(Object? v) {
  final n = v is Map<String, dynamic> ? v['value'] as num : v! as num;
  return n.round().toString();
}

String _color(String v) {
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(v);
  if (hex != null) return 'Color(0xFF${hex[1]!.toUpperCase()})';
  final m = RegExp(r'^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$')
      .firstMatch(v);
  if (m == null) throw FormatException('Color no admitido: $v');
  final a = (double.parse(m[4]!) * 255).round();
  String h(int x) => x.toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'Color(0x${h(a)}${h(int.parse(m[1]!))}${h(int.parse(m[2]!))}${h(int.parse(m[3]!))})';
}

/// Formatea código Dart con `dart format` para que coincida con lo que exige CI.
String _formatDart(String source, String dart) {
  final tmp = Directory.systemTemp.createTempSync('gen_');
  try {
    final f = File('${tmp.path}/gen.dart')..writeAsStringSync(source);
    final r = Process.runSync(dart, ['format', f.path]);
    if (r.exitCode != 0) throw StateError('dart format falló: ${r.stderr}');
    return f.readAsStringSync();
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
