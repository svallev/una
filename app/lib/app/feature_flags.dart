/// Indicadores de función (P10, `docs/architecture.md` §6): constantes de
/// compilación (`--dart-define`). Nada detrás de un indicador llega a
/// producción sin su spec aprobada.
abstract final class FeatureFlags {
  /// Notificaciones locales con la tarea actual (spec 019, plan P-019-9).
  /// **Apagado** durante el desarrollo: se enciende con
  /// `--dart-define=UNA_NOTIFICATIONS=true` y T-019-17 cambia el valor por
  /// defecto. Con él apagado la fila no se ve en ninguna plataforma
  /// (CA-019-28).
  static const bool notifications = bool.fromEnvironment('UNA_NOTIFICATIONS');
}
