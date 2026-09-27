import '../entities/task.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';

/// Resultado de completar: la tarea completada (tal como se veía, para la
/// rotura) y la nueva tarea actual (o null si no queda ninguna: "Todo
/// hecho.", R12).
typedef CompletionResult = ({Task completed, Task? next});

/// Completa la tarea actual (R9): la borra del todo, sin histórico
/// (ADR-0012). Se guarda **antes** de cualquier animación: si la app muere a
/// mitad, ya no está (CL-003-1), y el barrido recoge sus archivos.
class CompleteCurrentTask {
  CompleteCurrentTask({required this.repository, required this.janitor});

  final TaskRepository repository;
  final AttachmentJanitor janitor;

  /// Completa [task] si sigue siendo la tarea actual.
  Future<CompletionResult> call(Task task) async {
    final current = await repository.currentTask();
    if (current == null || current.id != task.id) {
      throw const TaskNotCurrent();
    }
    // Solo borra si sigue pendiente: si entre medias dejó de estarlo, no se
    // anuncia como completada.
    if (!await repository.remove(task.id)) throw const TaskNotCurrent();
    // Después de guardar, los archivos (CA-003-06, CA-007-16).
    if (current.attachment case final a?) await janitor.discard(a.id);
    return (completed: task, next: await repository.currentTask());
  }
}

/// La tarea ya no es la actual (se completó o cambió entre medias): no hay
/// nada que completar ni que reintentar.
class TaskNotCurrent implements Exception {
  const TaskNotCurrent();
}
