import '../ports/accessibility_timeouts.dart';

/// Cuánto dura la card de deshacer (CA-014-06, ADR-0021). La regla está aquí,
/// en Dart y probada; el canal solo da los hechos del sistema
/// ([SystemTimeouts]). Las tres duraciones salen de los tokens
/// (`undoWindow`, `undoWindowLegacyA11y`, `undoWindowMax`): el dominio no los
/// importa para seguir siendo Dart puro.
class UndoDuration {
  const UndoDuration({
    required this.base,
    required this.legacyA11y,
    required this.max,
  });

  /// Por defecto: 4 s (D20).
  final Duration base;

  /// Android 8 y 9 con un servicio de accesibilidad activo: 10 s (excepción a
  /// P6 de la constitución 1.6).
  final Duration legacyA11y;

  /// Tope por si un fabricante devuelve un valor absurdo (el sistema llega a
  /// 2 min): 10 min.
  final Duration max;

  /// - Android 10 o posterior (hay `recommendedMs`): el "Tiempo para actuar"
  ///   del sistema, nunca menos de [base] ni más de [max];
  /// - Android 8 y 9 (sin `recommendedMs`): [legacyA11y] con un servicio de
  ///   accesibilidad activo y, si no, [base];
  /// - sin canal (iOS, web de pruebas, tests): `(null, false)` → [base].
  Duration call(SystemTimeouts timeouts) {
    final recommended = timeouts.recommendedMs;
    if (recommended != null) {
      return Duration(
        milliseconds: recommended.clamp(
          base.inMilliseconds,
          max.inMilliseconds,
        ),
      );
    }
    return timeouts.serviceEnabled ? legacyA11y : base;
  }
}
