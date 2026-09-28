import 'link_policy.dart' show toPunycodeLabel;

final _space = RegExp(r'\s');
final _numeric = RegExp(r'^(0x[0-9a-f]*|[0-9]+)$');

/// Intérprete de la *Public Suffix List* (publicsuffix.org, de Mozilla, MPL-2.0;
/// la lista va empaquetada sin modificar y fijada en `tools/psl.lock`).
///
/// Sirve para decidir qué es "el mismo sitio" (CA-009-11): dos hosts lo son si
/// tienen el mismo dominio registrable. Sin la lista, `ejemplo.co.uk` y
/// `otro.co.uk` parecerían el mismo sitio.
///
/// Sigue el algoritmo de publicsuffix.org/list: gana una regla de excepción
/// (`!city.kobe.jp`); si no hay, la regla más larga que coincide (normal o
/// comodín `*.kobe.jp`); si ninguna coincide, la regla por defecto `*` (la
/// última etiqueta). Se usan las dos secciones (ICANN y privada): cada usuario
/// de `github.io` es un sitio distinto. Las reglas y los hosts se comparan en
/// punycode, así que los hosts valen en Unicode o en `xn--`.
class PublicSuffixList {
  PublicSuffixList._(this._rules, this._wildcards, this._exceptions);

  /// Interpreta el texto de la lista: una regla por línea, hasta el primer
  /// espacio; se ignoran las líneas vacías y los comentarios (`//`).
  factory PublicSuffixList.parse(String source) {
    final rules = <String>{};
    final wildcards = <String>{};
    final exceptions = <String>{};
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//')) continue;
      final rule = line.split(_space).first.toLowerCase();
      if (rule.startsWith('!')) {
        exceptions.add(_ascii(rule.substring(1)));
      } else if (rule.startsWith('*.')) {
        wildcards.add(_ascii(rule.substring(2)));
      } else {
        rules.add(_ascii(rule));
      }
    }
    return PublicSuffixList._(rules, wildcards, exceptions);
  }

  /// Reglas normales (`com`), comodines sin el `*.` y excepciones sin el `!`,
  /// todas en punycode.
  final Set<String> _rules;
  final Set<String> _wildcards;
  final Set<String> _exceptions;

  /// Número de reglas cargadas (para comprobar la lista).
  int get ruleCount => _rules.length + _wildcards.length + _exceptions.length;

  /// El dominio registrable de [host] (el sufijo público más una etiqueta),
  /// en minúsculas y en la forma en que llega (Unicode o punycode). Null si
  /// [host] es un sufijo público, una IP o no es un nombre bien formado (vacío,
  /// con un punto al principio o al final, etiquetas vacías o espacios).
  String? registrableDomain(String host) {
    final lower = host.toLowerCase();
    if (lower.isEmpty || lower.contains(':') || lower.contains(_space)) {
      return null;
    }
    final labels = lower.split('.');
    if (labels.any((l) => l.isEmpty) || _isIpv4(labels)) return null;
    final ascii = labels.map(toPunycodeLabel).toList();
    final suffix = _suffixLength(ascii);
    if (suffix >= labels.length) return null;
    return labels.sublist(labels.length - suffix - 1).join('.');
  }

  /// Número de etiquetas del sufijo público de [labels] (en punycode).
  int _suffixLength(List<String> labels) {
    final n = labels.length;
    // Una excepción gana siempre: su sufijo es la regla sin su primera etiqueta.
    for (var i = 0; i < n; i++) {
      if (_exceptions.contains(labels.sublist(i).join('.'))) return n - i - 1;
    }
    // Si no, la regla más larga: se recorre de la más larga a la más corta, y
    // en cada paso un comodín (`*.` + el resto) abarca una etiqueta más.
    for (var i = 0; i < n; i++) {
      final rest = labels.sublist(i).join('.');
      if (i > 0 && _wildcards.contains(rest)) return n - i + 1;
      if (_rules.contains(rest)) return n - i;
    }
    return 1; // Regla por defecto "*".
  }

  /// Una IPv4 escrita con puntos (la última etiqueta es numérica, como en el
  /// estándar URL): no tiene dominio registrable.
  static bool _isIpv4(List<String> labels) => _numeric.hasMatch(labels.last);

  static String _ascii(String domain) =>
      domain.split('.').map(toPunycodeLabel).join('.');
}
