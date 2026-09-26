/// Orden fraccional de la cola (ADR-0002): claves de texto base-62 que se
/// comparan lexicográficamente. Permite insertar entre dos tareas cambiando
/// una sola fila (útil para sincronizar en el futuro).
///
/// Basado en el algoritmo de "fractional indexing" (D. Greenspan). Solo se usa
/// la parte fraccional: una clave nunca está vacía ni termina en el dígito cero.
abstract final class Rank {
  static const String digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /// Longitud a partir de la cual se renumera la cola (ADR-0002).
  static const int maxLength = 50;

  /// [n] claves ordenadas, de la misma longitud y repartidas de forma
  /// uniforme, con hueco delante, entre ellas y detrás (renumeración,
  /// CL-006-8). Se usa un dígito más del mínimo para que las inserciones
  /// siguientes no alarguen las claves enseguida.
  static List<String> evenlySpaced(int n) {
    if (n <= 0) return const [];
    final base = digits.length;
    var length = 1;
    var space = base;
    while (space < 2 * (n + 1)) {
      length++;
      space *= base;
    }
    length++;
    space *= base;
    final step = space ~/ (n + 1);
    return [for (var i = 1; i <= n; i++) _encode(i * step, length)];
  }

  /// [value] en base 62 con [length] dígitos. Si acabara en cero se usa el
  /// siguiente valor (el paso entre claves es ≥ 2, así que no se cruzan).
  static String _encode(int value, int length) {
    var v = value % digits.length == 0 ? value + 1 : value;
    final out = List.filled(length, digits[0]);
    for (var i = length - 1; i >= 0; i--) {
      out[i] = digits[v % digits.length];
      v ~/= digits.length;
    }
    return out.join();
  }

  /// Primera clave para una cola vacía.
  static String initial() => between(null, null);

  /// Clave estrictamente entre [before] y [after] (null = sin límite).
  static String between(String? before, String? after) {
    final a = before ?? '';
    if (after != null && a.compareTo(after) >= 0) {
      throw ArgumentError('Orden inválido: "$a" >= "$after"');
    }
    _checkKey(a, allowEmpty: true);
    if (after != null) _checkKey(after);
    return _midpoint(a, after);
  }

  /// Clave para insertar antes de [first] (arriba del todo).
  static String before(String? first) => between(null, first);

  /// Clave para insertar después de [last] (a la cola).
  static String after(String? last) => between(last, null);

  static void _checkKey(String k, {bool allowEmpty = false}) {
    if (k.isEmpty && allowEmpty) return;
    if (k.isEmpty || k.endsWith(digits[0])) {
      throw ArgumentError('Clave de orden inválida: "$k"');
    }
    for (final c in k.split('')) {
      if (!digits.contains(c)) throw ArgumentError('Carácter no válido: "$c"');
    }
  }

  static String _midpoint(String a, String? b) {
    if (b != null) {
      var n = 0;
      while ((n < a.length ? a[n] : digits[0]) == b[n]) {
        n++;
      }
      if (n > 0) {
        return b.substring(0, n) +
            _midpoint(a.length > n ? a.substring(n) : '', b.substring(n));
      }
    }
    final digitA = a.isNotEmpty ? digits.indexOf(a[0]) : 0;
    final digitB = b != null ? digits.indexOf(b[0]) : digits.length;
    if (digitB - digitA > 1) {
      return digits[((digitA + digitB) / 2).round()];
    }
    if (b != null && b.length > 1) return b.substring(0, 1);
    return digits[digitA] + _midpoint(a.length > 1 ? a.substring(1) : '', null);
  }
}
