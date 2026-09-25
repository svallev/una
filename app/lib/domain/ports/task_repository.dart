import '../entities/task.dart';

/// Puerto de persistencia de tareas (ADR-0002). La UI y los casos de uso
/// nunca tocan la base de datos directamente.
abstract interface class TaskRepository {
  /// La primera tarea pendiente según `rank`, o null si no hay ninguna.
  Future<Task?> currentTask();

  /// Emite la tarea actual cada vez que cambia.
  Stream<Task?> watchCurrentTask();

  /// Clave de orden de la primera y la última tarea pendiente.
  Future<String?> firstPendingRank();
  Future<String?> lastPendingRank();

  Future<int> countPending();

  /// Cualquier tarea (pendiente, completada o eliminada) por su id.
  Future<Task?> findById(String id);

  /// ¿Hay alguna tarea completada? (spec 003, CA-003-11: "Todo hecho.")
  Future<bool> hasCompleted();

  Future<void> insert(Task task);

  /// Marca como completada la tarea pendiente [id] (spec 003). Devuelve false
  /// (y no cambia nada) si ya no está pendiente.
  Future<bool> complete(String id, DateTime at);
}

/// Ajustes simples (docs/architecture.md §3).
abstract interface class SettingsRepository {
  Future<bool> firstRunDone();
  Future<void> setFirstRunDone();
}
