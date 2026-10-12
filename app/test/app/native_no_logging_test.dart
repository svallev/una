import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CA-019-23: el nativo de los avisos no escribe registros ni deja salir el texto de una
/// excepción. Recorre `kotlin/**/notifications/*.kt` y falla ante `Log.`, `println`,
/// `printStackTrace`, `Timber`, `Throwable.message` o el uso de la excepción capturada.
const _dir = 'android/app/src/main/kotlin/invalid/pending/app/notifications';

/// El código sin comentarios ni cadenas (para no confundir un texto con una llamada).
String strip(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
    } else if (c == '"') {
      // Cadena (también triple comilla): se sustituye por "" para conservar la estructura.
      if (source.startsWith('"""', i)) {
        final end = source.indexOf('"""', i + 3);
        i = end < 0 ? source.length : end + 3;
      } else {
        i++;
        while (i < source.length && source[i] != '"' && source[i] != '\n') {
          if (source[i] == r'\') i++;
          i++;
        }
        i++;
      }
      out.write('""');
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Cuerpo de cada `catch (nombre: Tipo) { ... }`: (nombre, cuerpo).
List<({String name, String body})> catches(String code) {
  final result = <({String name, String body})>[];
  for (final m in RegExp(
    r'catch\s*\(\s*(\w+)\s*:[^)]*\)\s*\{',
  ).allMatches(code)) {
    var depth = 1;
    var i = m.end;
    while (i < code.length && depth > 0) {
      if (code[i] == '{') depth++;
      if (code[i] == '}') depth--;
      i++;
    }
    result.add((name: m.group(1)!, body: code.substring(m.end, i - 1)));
  }
  return result;
}

/// Lo que está prohibido en [source] (ya sin comentarios ni cadenas).
List<String> violations(String source) {
  final code = strip(source);
  final found = <String>[];
  final banned = {
    r'\bLog\s*\.': 'Log.',
    r'\bprintln\s*\(': 'println',
    r'\bprint\s*\(': 'print',
    r'printStackTrace': 'printStackTrace',
    r'\bTimber\b': 'Timber',
    r'\bSystem\s*\.\s*(out|err)\b': 'System.out/err',
    r'\bandroid\.util\.Log\b': 'android.util.Log',
  };
  banned.forEach((pattern, label) {
    if (RegExp(pattern).hasMatch(code)) found.add(label);
  });
  for (final c in catches(code)) {
    if (c.name != '_') found.add('catch con la excepción nombrada (${c.name})');
    if (RegExp(r'\.(message|localizedMessage|cause|stackTrace)\b')
        .hasMatch(c.body)) {
      found.add('.message dentro de un catch');
    }
  }
  return found;
}

void main() {
  final files = Directory(_dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.kt'))
      .toList();

  test('CA-019-23: hay archivos del nativo de avisos que vigilar', () {
    expect(files, isNotEmpty);
  });

  for (final f in files) {
    test('CA-019-23: ${f.uri.pathSegments.last} no registra nada', () {
      expect(violations(f.readAsStringSync()), isEmpty);
    });
  }

  group('CA-019-23: el vigilante detecta lo que debe', () {
    test('cada forma prohibida', () {
      expect(violations('fun f() { Log.d("t", "x") }'), contains('Log.'));
      expect(
        violations('fun f() { android.util.Log.e("t", "x") }'),
        isNotEmpty,
      );
      expect(violations('fun f() { println("x") }'), contains('println'));
      expect(
        violations('fun f() { e.printStackTrace() }'),
        contains('printStackTrace'),
      );
      expect(violations('fun f() { Timber.d("x") }'), contains('Timber'));
      expect(violations('fun f() { System.err.println("x") }'), isNotEmpty);
      expect(
        violations('fun f() { try { a() } catch (e: Throwable) { throw e } }'),
        isNotEmpty,
      );
      expect(
        violations(
          'fun f() { try { a() } catch (_: Throwable) { x(it.message) } }',
        ),
        contains('.message dentro de un catch'),
      );
    });

    test(
      'lo permitido pasa: catch con _ y menciones en comentarios o cadenas',
      () {
        const ok = '''
// Sin Log. ni printStackTrace aqui
/* println("x") */
fun f() {
    val s = "Log.d y println(\\"x\\")"
    try { a() } catch (_: Throwable) { b() }
}
''';
        expect(violations(ok), isEmpty);
      },
    );
  });
}
