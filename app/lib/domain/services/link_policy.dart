import '../entities/link_target.dart';
import 'text_safety.dart';

/// Decide qué hace un enlace de un PDF (CA-008-12, T-5). [destPage] es el
/// destino interno (desde 1); [url], la dirección de un enlace externo. Todo lo
/// que no sea una página del PDF, `http(s)`, `mailto:` o `tel:` se bloquea.
LinkTarget classifyLink({Uri? url, int? destPage}) {
  if (destPage != null && destPage >= 1) return InternalLink(destPage);
  if (url == null) return const BlockedLink();
  return switch (url.scheme.toLowerCase()) {
    'http' || 'https' => _web(url),
    'mailto' => _mail(url),
    'tel' => _phone(url),
    _ => const BlockedLink(),
  };
}

LinkTarget _web(Uri url) {
  // `usuario:clave@` sirve para disfrazar el dominio real (T-5).
  if (url.userInfo.isNotEmpty || url.host.isEmpty) return const BlockedLink();
  final host = stripUnsafeChars(_decode(url.host)).toLowerCase();
  if (host.isEmpty) return const BlockedLink();
  return WebLink(url, host.split('.').map(_displayLabel).join('.'));
}

String _decode(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  }
}

final _address = RegExp(r'^[^@\s,;<>"]+@[^@\s,;<>"]+\.[^@\s,;<>"]+$');

LinkTarget _mail(Uri url) {
  final raw = <String>[
    ..._decode(url.path).split(','),
    for (final e in url.queryParametersAll.entries)
      if (e.key.toLowerCase() == 'to') ...e.value.expand((v) => v.split(',')),
  ];
  final to = [
    for (final r in raw)
      if (stripUnsafeChars(r).trim() case final a when _address.hasMatch(a)) a,
  ];
  if (to.isEmpty) return const BlockedLink();
  final subject = url.queryParametersAll.entries
      .where((e) => e.key.toLowerCase() == 'subject')
      .expand((e) => e.value)
      .map(stripUnsafeChars)
      .firstOrNull;
  return MailLink(
    Uri(
      scheme: 'mailto',
      path: to.join(','),
      queryParameters: subject == null ? null : {'subject': subject},
    ),
    to.join(', '),
  );
}

LinkTarget _phone(Uri url) {
  final number = _decode(url.path).split(';').first;
  final digits = number.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?[0-9]{3,20}$').hasMatch(digits)) return const BlockedLink();
  return PhoneLink(Uri.parse('tel:$digits'), digits);
}

/// Una etiqueta del dominio: legible si usa un solo alfabeto; en punycode si
/// los mezcla (p. ej., una "а" cirílica en "аpple", T-5).
String _displayLabel(String label) =>
    _mixesScripts(label) ? toPunycodeLabel(label) : label;

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

/// Codifica una etiqueta de dominio en punycode (RFC 3492) con el prefijo
/// `xn--`; si es solo ASCII, la devuelve tal cual.
String toPunycodeLabel(String label) {
  final input = label.runes.toList();
  if (input.every((c) => c < 0x80)) return label;
  const base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700;
  int adapt(int delta, int numPoints, bool first) {
    delta = first ? delta ~/ damp : delta ~/ 2;
    delta += delta ~/ numPoints;
    var k = 0;
    while (delta > ((base - tMin) * tMax) ~/ 2) {
      delta ~/= base - tMin;
      k += base;
    }
    return k + (base - tMin + 1) * delta ~/ (delta + skew);
  }

  String digit(int d) => String.fromCharCode(d < 26 ? 0x61 + d : 0x30 + d - 26);

  final out = StringBuffer()
    ..writeAll(input.where((c) => c < 0x80).map(String.fromCharCode));
  final basic = out.length;
  var handled = basic;
  if (basic > 0) out.write('-');
  var n = 0x80, delta = 0, bias = 72;
  while (handled < input.length) {
    final m = input.where((c) => c >= n).reduce((a, b) => a < b ? a : b);
    delta += (m - n) * (handled + 1);
    n = m;
    for (final c in input) {
      if (c < n) delta++;
      if (c == n) {
        var q = delta;
        for (var k = base; ; k += base) {
          final t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias);
          if (q < t) break;
          out.write(digit(t + (q - t) % (base - t)));
          q = (q - t) ~/ (base - t);
        }
        out.write(digit(q));
        bias = adapt(delta, handled + 1, handled == basic);
        delta = 0;
        handled++;
      }
    }
    delta++;
    n++;
  }
  return 'xn--$out';
}
