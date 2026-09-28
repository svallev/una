import 'package:flutter/foundation.dart';

import 'host_display.dart' show toPunycodeLabel;

/// Longitud máxima de la dirección que se guarda (CA-009-02, CL-009-8).
const int maxWebAddressLength = 2048;

/// Por qué no vale una dirección (CA-009-02; textos `urlErrEmpty`,
/// `urlErrScheme` y `urlErrInvalid`).
enum WebAddressError {
  /// Vacía o solo espacios.
  empty,

  /// Un esquema distinto de `http` o `https`.
  scheme,

  /// No analizable, sin dominio o sin punto, privada o local, con usuario o
  /// contraseña, o de más de [maxWebAddressLength] caracteres.
  invalid,
}

/// Resultado de [validateWebAddress].
@immutable
sealed class WebAddressCheck {
  const WebAddressCheck();
}

/// La dirección que se guarda, ya normalizada (CA-009-04).
final class ValidWebAddress extends WebAddressCheck {
  const ValidWebAddress(this.url);
  final String url;

  @override
  bool operator ==(Object other) =>
      other is ValidWebAddress && other.url == url;
  @override
  int get hashCode => url.hashCode;

  // Sin la dirección: no va a ningún registro (CL-009-9).
  @override
  String toString() => 'ValidWebAddress()';
}

final class InvalidWebAddress extends WebAddressCheck {
  const InvalidWebAddress(this.error);
  final WebAddressError error;

  @override
  bool operator ==(Object other) =>
      other is InvalidWebAddress && other.error == error;
  @override
  int get hashCode => error.hashCode;
  @override
  String toString() => 'InvalidWebAddress(${error.name})';
}

final _schemeLike = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):(.*)$', dotAll: true);
final _port = RegExp(r'^[0-9]+([/?#\\]|$)');
final _control = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
final _space = RegExp(r'\s');
final _label = RegExp(r'^[a-z0-9_\-]{1,63}$');
final _numericLabel = RegExp(r'^(0[xX][0-9a-fA-F]*|[0-9]+)$');

/// Nombres que nunca salen a internet (RFC 6761, 6762, 8375; `.internal`).
const _localSuffixes = ['localhost', 'local', 'home.arpa', 'internal'];

const _invalid = InvalidWebAddress(WebAddressError.invalid);

/// Valida y normaliza lo escrito en "Cargar URL" (CA-009-02, CL-009-8):
///
/// - quita los espacios del principio y del final;
/// - sin esquema, añade `https://` (`ejemplo.com:8080` lleva puerto, no
///   esquema);
/// - solo `http` y `https`;
/// - rechaza lo que no se puede analizar, un dominio sin punto, una IP
///   privada o local o un nombre local, `usuario:clave@` y lo que pase de
///   [maxWebAddressLength] caracteres (contando la dirección que se guarda);
/// - codifica los espacios y los caracteres internacionales de la ruta, y
///   pasa el dominio a minúsculas y a punycode, como haría un navegador.
///
/// La barra invertida cuenta como `/`, como en un navegador: el dominio que
/// se valida es el mismo que cargaría la página.
WebAddressCheck validateWebAddress(String input) {
  final text = input.trim();
  if (text.isEmpty) return const InvalidWebAddress(WebAddressError.empty);
  if (_control.hasMatch(text)) return _invalid;

  final String withScheme;
  final match = _schemeLike.firstMatch(text);
  if (match == null || _port.hasMatch(match.group(2)!)) {
    withScheme = 'https://$text';
  } else {
    final scheme = match.group(1)!.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return const InvalidWebAddress(WebAddressError.scheme);
    }
    withScheme = text;
  }

  final rest = withScheme.substring(withScheme.indexOf(':') + 1);
  if (!rest.startsWith('//') && !rest.startsWith(r'\\')) return _invalid;
  // La autoridad en crudo: `Uri` descarta un `@` sin usuario.
  final authority = rest.substring(2).split(RegExp(r'[/?#\\]')).first;
  if (authority.contains('@') || authority.contains(_space)) return _invalid;

  final uri = Uri.tryParse(withScheme.replaceAll(_space, '%20'));
  if (uri == null || uri.userInfo.isNotEmpty || uri.host.isEmpty) {
    return _invalid;
  }
  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return _invalid;

  final host = uri.host.contains(':')
      ? _ipv6Host(uri.host)
      : _namedHost(uri.host);
  if (host == null) return _invalid;

  final url = (host == uri.host ? uri : uri.replace(host: host)).toString();
  if (url.length > maxWebAddressLength) return _invalid;
  return ValidWebAddress(url);
}

/// Un dominio o una IPv4, normalizados; null si no vale o es privado o local.
String? _namedHost(String raw) {
  final String decoded;
  try {
    decoded = Uri.decodeComponent(raw).toLowerCase();
  } on ArgumentError {
    return null;
  }
  final name = decoded.endsWith('.')
      ? decoded.substring(0, decoded.length - 1)
      : decoded;
  final labels = name.split('.');
  if (labels.any((l) => l.isEmpty)) return null;
  // Como un navegador: si la última etiqueta es un número, es una IPv4
  // (`127.1`, `0x7f.1` y `2130706433` son 127.0.0.1).
  if (_numericLabel.hasMatch(labels.last)) {
    final ip = _parseIpv4(labels);
    if (ip == null || _isPrivateIpv4(ip)) return null;
    return [for (var s = 24; s >= 0; s -= 8) (ip >> s) & 0xFF].join('.');
  }
  if (labels.length < 2) return null;
  final ascii = labels.map(toPunycodeLabel).toList();
  if (!ascii.every(_label.hasMatch)) return null;
  final host = ascii.join('.');
  if (host.length > 253) return null;
  for (final suffix in _localSuffixes) {
    if (host == suffix || host.endsWith('.$suffix')) return null;
  }
  return host;
}

/// IPv4 como la lee un navegador (WHATWG URL, "IPv4 parser"): hasta cuatro
/// partes en decimal, octal (`0…`) o hexadecimal (`0x…`). Null si no lo es.
int? _parseIpv4(List<String> parts) {
  if (parts.length > 4) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final int? n;
    if (part.startsWith('0x') || part.startsWith('0X')) {
      n = part.length == 2 ? 0 : int.tryParse(part.substring(2), radix: 16);
    } else if (part.length > 1 && part.startsWith('0')) {
      n = int.tryParse(part.substring(1), radix: 8);
    } else {
      n = int.tryParse(part);
    }
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  final last = numbers.removeLast();
  if (numbers.any((n) => n > 255)) return null;
  if (last >= 1 << (8 * (5 - parts.length))) return null;
  var ip = last;
  for (var i = 0; i < numbers.length; i++) {
    ip += numbers[i] << (8 * (3 - i));
  }
  return ip;
}

/// Redes que no son internet (RFC 6890): "esta red", privadas, CGNAT,
/// *loopback*, enlace local, IETF, pruebas de rendimiento, multidifusión,
/// reservadas y difusión.
bool _isPrivateIpv4(int ip) {
  bool inRange(int net, int bits) =>
      (ip >> (32 - bits)) == (net >> (32 - bits));
  return inRange(0x00000000, 8) || // 0.0.0.0/8
      inRange(0x0A000000, 8) || // 10.0.0.0/8
      inRange(0x64400000, 10) || // 100.64.0.0/10
      inRange(0x7F000000, 8) || // 127.0.0.0/8
      inRange(0xA9FE0000, 16) || // 169.254.0.0/16
      inRange(0xAC100000, 12) || // 172.16.0.0/12
      inRange(0xC0000000, 24) || // 192.0.0.0/24
      inRange(0xC0A80000, 16) || // 192.168.0.0/16
      inRange(0xC6120000, 15) || // 198.18.0.0/15
      inRange(0xE0000000, 3); // 224.0.0.0/4 y 240.0.0.0/4
}

/// Una IPv6 pública, tal cual; null si no vale o es privada o local.
String? _ipv6Host(String raw) {
  // Con zona (`fe80::1%eth0`): siempre local.
  if (raw.contains('%')) return null;
  final List<int> b;
  try {
    b = Uri.parseIPv6Address(raw);
  } on FormatException {
    return null;
  }
  bool allZeroTo(int end) => b.take(end).every((x) => x == 0);
  // ::/96 (sin especificar, *loopback* y las compatibles con IPv4) y
  // ::ffff:0:0/96 (IPv4 mapeada): se mira la IPv4 de dentro.
  if (allZeroTo(12)) return null;
  if (allZeroTo(10) && b[10] == 0xFF && b[11] == 0xFF) {
    final ip = (b[12] << 24) | (b[13] << 16) | (b[14] << 8) | b[15];
    return _isPrivateIpv4(ip) ? null : raw;
  }
  if ((b[0] & 0xFE) == 0xFC) return null; // fc00::/7, única local
  if (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) return null; // fe80::/10
  if (b[0] == 0xFF) return null; // ff00::/8, multidifusión
  return raw;
}
