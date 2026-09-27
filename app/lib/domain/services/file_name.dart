import 'package:characters/characters.dart';

import 'text_safety.dart';

/// Caracteres visibles como máximo del nombre guardado (CA-008-07).
const int maxFileNameLength = 120;

/// Extensión que se conserva al recortar (".pdf"); más larga no se conserva.
const int _maxExtension = 10;

/// Sanea el nombre de un archivo elegido (CA-008-07, T-3): sin rutas, sin
/// caracteres de control ni de cambio de dirección, sin espacios alrededor y
/// con [maxFileNameLength] caracteres visibles como máximo, conservando la
/// extensión. Devuelve null si no queda nada (entonces se usa "PDF").
String? sanitizeFileName(String? raw) {
  if (raw == null) return null;
  final base = raw.split(RegExp(r'[/\\]')).last;
  final clean = stripUnsafeChars(base).trim();
  if (clean.isEmpty) return null;
  final chars = clean.characters;
  if (chars.length <= maxFileNameLength) return clean;
  final dot = clean.lastIndexOf('.');
  final ext = dot > 0 ? clean.substring(dot).characters : Characters.empty;
  if (ext.isEmpty || ext.length > _maxExtension) {
    return chars.take(maxFileNameLength).toString();
  }
  final stem = clean.substring(0, dot).characters;
  return '${stem.take(maxFileNameLength - ext.length)}$ext';
}
