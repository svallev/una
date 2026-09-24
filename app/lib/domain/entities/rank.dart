/// Orden fraccional de la cola (ADR-0002): claves de texto base-62 que se
/// comparan lexicográficamente. Permite insertar entre dos tareas cambiando
/// una sola fila (útil para sincronizar en el futuro).
///
/// Basado en el algoritmo de "fractional indexing" (D. Greenspan). Solo se usa
/// la parte fraccional: una clave nunca está vacía ni termina en el dígito cero.
abstract final class Rank {
  static const String digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

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
