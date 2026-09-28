import 'text_safety.dart';

/// Cómo se muestra un dominio (T-5): el de los enlaces del PDF (CA-008-12) y el
/// de la tarea web (barra, listado y anuncios, CA-009-14).
///
/// - Sin caracteres de control ni de cambio de dirección, y en minúsculas.
/// - Cada etiqueta, legible si usa un solo alfabeto; en punycode (`xn--…`) si
///   los mezcla (p. ej., una "а" cirílica en "аpple"). Una etiqueta que ya
///   llega en punycode se descodifica para decidirlo: la WebView da los
///   dominios en ASCII, y `xn--e1afmkfd.xn--p1ai` se ve como `пример.рф`.
/// - Con [dropWww], sin el `www.` del principio (la barra y la etiqueta de la
///   tarea web, como el prototipo) si detrás queda un dominio con punto; las
///   confirmaciones lo muestran entero.
///
/// [host] puede venir con escapes `%XX` (`Uri.host` los usa en los dominios
/// internacionales). Devuelve '' si no queda nada.
String displayHost(String host, {bool dropWww = false}) {
  var shown = stripUnsafeChars(_decodePercent(host)).toLowerCase();
  // `www.com` se queda entero: nunca se muestra un sufijo suelto.
  if (dropWww && shown.startsWith('www.') && shown.indexOf('.', 4) > 4) {
    shown = shown.substring(4);
  }
  return shown.split('.').map(_displayLabel).join('.');
}

/// El dominio de la dirección guardada de una tarea web, como en la barra
/// (sin `www.`, CA-009-14), o null si no tiene dominio o no se puede leer.
String? webAddressHost(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  final host = displayHost(uri.host, dropWww: true);
  return host.isEmpty ? null : host;
}

String _decodePercent(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  }
}

String _displayLabel(String label) {
  final unicode = label.startsWith('xn--') ? fromPunycodeLabel(label) : label;
  // Punycode mal formado o que esconde caracteres peligrosos: tal cual llegó.
  if (unicode == null || stripUnsafeChars(unicode) != unicode) return label;
  return _mixesScripts(unicode) ? toPunycodeLabel(unicode) : unicode;
}

bool _mixesScripts(String label) {
  final scripts = <String>{};
  for (final r in label.runes) {
    final s = _script(r);
    if (s != null) scripts.add(s);
  }
  return scripts.length > 1;
}

/// Alfabeto de una letra; null para dígitos, guiones y lo que no es letra.
String? _script(int r) {
  if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) return 'latin';
  if (r < 0x80) return null;
  if ((r >= 0xC0 && r <= 0x24F) || (r >= 0x1E00 && r <= 0x1EFF)) return 'latin';
  if (r >= 0x370 && r <= 0x3FF) return 'greek';
  if (r >= 0x400 && r <= 0x52F) return 'cyrillic';
  if (r >= 0x530 && r <= 0x58F) return 'armenian';
  if (r >= 0x590 && r <= 0x5FF) return 'hebrew';
  if (r >= 0x600 && r <= 0x6FF) return 'arabic';
  // Resto: por bloques de 128 (basta para detectar la mezcla).
  return 'block${r >> 7}';
}

// Parámetros de punycode (RFC 3492 §5).
const _base = 36, _tMin = 1, _tMax = 26, _skew = 38, _damp = 700;
const _initialBias = 72, _initialN = 0x80;

int _adapt(int delta, int numPoints, bool first) {
  delta = first ? delta ~/ _damp : delta ~/ 2;
  delta += delta ~/ numPoints;
  var k = 0;
  while (delta > ((_base - _tMin) * _tMax) ~/ 2) {
    delta ~/= _base - _tMin;
    k += _base;
  }
  return k + (_base - _tMin + 1) * delta ~/ (delta + _skew);
}

int _threshold(int k, int bias) =>
    k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);

/// Codifica una etiqueta de dominio en punycode (RFC 3492) con el prefijo
/// `xn--`; si es solo ASCII, la devuelve tal cual.
String toPunycodeLabel(String label) {
  final input = label.runes.toList();
  if (input.every((c) => c < 0x80)) return label;
  String digit(int d) => String.fromCharCode(d < 26 ? 0x61 + d : 0x30 + d - 26);

  final out = StringBuffer()
    ..writeAll(input.where((c) => c < 0x80).map(String.fromCharCode));
  final basic = out.length;
  var handled = basic;
  if (basic > 0) out.write('-');
  var n = _initialN, delta = 0, bias = _initialBias;
  while (handled < input.length) {
    final m = input.where((c) => c >= n).reduce((a, b) => a < b ? a : b);
    delta += (m - n) * (handled + 1);
    n = m;
    for (final c in input) {
      if (c < n) delta++;
      if (c == n) {
        var q = delta;
        for (var k = _base; ; k += _base) {
          final t = _threshold(k, bias);
          if (q < t) break;
          out.write(digit(t + (q - t) % (_base - t)));
          q = (q - t) ~/ (_base - t);
        }
        out.write(digit(q));
        bias = _adapt(delta, handled + 1, handled == basic);
        delta = 0;
        handled++;
      }
    }
    delta++;
    n++;
  }
  return 'xn--$out';
}

/// Descodifica una etiqueta `xn--…` (RFC 3492). Null si no empieza por
/// `xn--`, está mal formada o da algo que no es Unicode válido.
String? fromPunycodeLabel(String label) {
  final lower = label.toLowerCase();
  if (!lower.startsWith('xn--')) return null;
  final input = lower.substring(4);
  final dash = input.lastIndexOf('-');
  final output = <int>[];
  for (var j = 0; j < (dash < 0 ? 0 : dash); j++) {
    final c = input.codeUnitAt(j);
    if (c >= 0x80) return null;
    output.add(c);
  }
  int? value(int c) {
    if (c >= 0x61 && c <= 0x7A) return c - 0x61;
    if (c >= 0x30 && c <= 0x39) return c - 0x30 + 26;
    return null;
  }

  var n = _initialN, i = 0, bias = _initialBias;
  var pos = dash < 0 ? 0 : dash + 1;
  while (pos < input.length) {
    final oldI = i;
    var w = 1;
    for (var k = _base; ; k += _base) {
      if (pos >= input.length) return null;
      final d = value(input.codeUnitAt(pos++));
      if (d == null) return null;
      i += d * w;
      final t = _threshold(k, bias);
      if (d < t) break;
      w *= _base - t;
      // Etiquetas absurdas: se descartan antes de desbordar.
      if (i > 0x10FFFF * 64 || w > 0x10FFFF * 64) return null;
    }
    bias = _adapt(i - oldI, output.length + 1, oldI == 0);
    n += i ~/ (output.length + 1);
    i %= output.length + 1;
    if (n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF)) return null;
    output.insert(i, n);
    i++;
  }
  if (output.every((c) => c < 0x80)) return null;
  return String.fromCharCodes(output);
}
