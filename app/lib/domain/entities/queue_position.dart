/// Dónde se coloca una tarea nueva (R4).
enum QueuePosition {
  /// Antes de la tarea actual: pasa a ser la actual.
  top,

  /// Después de la última pendiente.
  end,
}
