/// Lo que dice el sistema sobre el tiempo para actuar (spec 014, CA-014-06):
/// - `recommendedMs`: el "Tiempo para actuar" de Android 10 o posterior para
///   un aviso de 4 s con controles y texto, o null si el sistema no lo tiene
///   (Android 8 y 9) o no hay canal;
/// - `serviceEnabled`: si hay algún servicio de accesibilidad activo.
///
/// Son solo hechos del sistema: la regla está en `UndoDuration`. Ninguno de los
/// dos se guarda ni se registra (dejaría deducir que se usa tecnología de
/// apoyo).
typedef SystemTimeouts = ({int? recommendedMs, bool serviceEnabled});

/// Puerto del tiempo de accesibilidad del sistema (canal `una/a11y` en
/// Android). Se consulta al empezar cada eliminación, nunca antes del primer
/// fotograma (P2).
abstract interface class AccessibilityTimeouts {
  /// Sin canal o con un error: `(recommendedMs: null, serviceEnabled: false)`.
  Future<SystemTimeouts> read();
}

/// Sin canal (iOS, web de pruebas): nada que alargar.
class NoAccessibilityTimeouts implements AccessibilityTimeouts {
  const NoAccessibilityTimeouts();

  @override
  Future<SystemTimeouts> read() async =>
      (recommendedMs: null, serviceEnabled: false);
}
