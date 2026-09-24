// Genera lib/app/theme/tokens.g.dart desde ../design/tokens.json (fuente única, P12).
//
//   dart run tool/gen_tokens.dart          → escribe el archivo
//   dart run tool/gen_tokens.dart --check  → falla si no está al día (CI)
import 'dart:convert';
import 'dart:io';

const _out = 'lib/app/theme/tokens.g.dart';

void main(List<String> args) {
  final t = jsonDecode(
    File('../design/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;
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
        '  static const Duration $k = Duration(milliseconds: ${_num(v[r'$value'])});',
      ),
  );
  _entries(motion['easing']).forEach((k, v) {
    final c = (v[r'$value'] as List)
        .map((e) => (e as num).toDouble())
        .join(', ');
    b.writeln('  static const Cubic ${k}Curve = Cubic($c);');
  });
  b.writeln(
    '  static const double dragThreshold = ${_num((motion['dragThreshold'] as Map<String, dynamic>)[r'$value'])};',
  );
  b.writeln('}');

  final next = _formatDart(b.toString());
  final file = File(_out);
  final current = file.existsSync() ? file.readAsStringSync() : null;
  if (args.contains('--check')) {
    if (current != next) {
      stderr.writeln(
        '$_out no está al día con design/tokens.json. Ejecuta `dart run tool/gen_tokens.dart`.',
      );
      exit(1);
    }
    stdout.writeln('Tokens al día.');
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(next);
  stdout.writeln('Tokens generados en $_out.');
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
String _formatDart(String source) {
  final tmp = Directory.systemTemp.createTempSync('gen_');
  try {
    final f = File('${tmp.path}/gen.dart')..writeAsStringSync(source);
    final r = Process.runSync(Platform.resolvedExecutable, ['format', f.path]);
    if (r.exitCode != 0) throw StateError('dart format falló: ${r.stderr}');
    return f.readAsStringSync();
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
