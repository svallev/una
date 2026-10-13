/// Indicadores de función (P10, `docs/architecture.md` §6): constantes de
/// compilación (`--dart-define`). Nada detrás de un indicador llega a
/// producción sin su spec aprobada.
abstract final class FeatureFlags {
  /// Notificaciones locales con la tarea actual (spec 019, plan P-019-9).
  /// **Encendido** por defecto desde T-019-17 (cierre de la 019); se apaga con
  /// `--dart-define=UNA_NOTIFICATIONS=false`. Con él apagado la fila no se ve
  /// en ninguna plataforma (CA-019-28).
  static const bool notifications = bool.fromEnvironment(
    'UNA_NOTIFICATIONS',
    defaultValue: true,
  );
}
