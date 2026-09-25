import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/task_repository.dart';

/// Resultado de completar: la tarea completada y la nueva tarea actual (o
/// null si no queda ninguna: "Todo hecho.", R12).
typedef CompletionResult = ({Task completed, Task? next});

/// Completa la tarea actual (R9). Se guarda **antes** de cualquier animación:
/// si la app muere a mitad, la tarea ya consta como completada (CL-003-1).
class CompleteCurrentTask {
  CompleteCurrentTask({required this.repository, required this.clock});

  final TaskRepository repository;
  final Clock clock;

  /// Completa [task] si sigue siendo la tarea actual.
  Future<CompletionResult> call(Task task) async {
    final current = await repository.currentTask();
    if (current == null || current.id != task.id) {
      throw const TaskNotCurrent();
    }
    final at = clock.now();
    // La escritura solo afecta a tareas pendientes: si entre medias dejó de
    // estarlo, no se anuncia como completada.
    if (!await repository.complete(task.id, at)) {
      throw const TaskNotCurrent();
    }
    return (completed: task.complete(at), next: await repository.currentTask());
  }
}

/// La tarea ya no es la actual (se completó o cambió entre medias): no hay
/// nada que completar ni que reintentar.
class TaskNotCurrent implements Exception {
  const TaskNotCurrent();
}
