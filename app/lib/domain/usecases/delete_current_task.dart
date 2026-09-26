import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/task_repository.dart';
import 'complete_current_task.dart' show TaskNotCurrent;

/// Resultado de eliminar: la tarea eliminada (tal como se veía, para la
/// animación) y la nueva tarea actual, o null si no queda ninguna ("Todo
/// hecho.", CA-004-07).
typedef DeletionResult = ({Task deleted, Task? next});

/// Elimina la tarea actual de forma definitiva (R10, ADR-0011). Se guarda
/// **antes** de la animación: si la app muere a mitad, ya está eliminada
/// (CA-004-03).
class DeleteCurrentTask {
  DeleteCurrentTask({required this.repository, required this.clock});

  final TaskRepository repository;
  final Clock clock;

  /// Elimina [task] si sigue siendo la tarea actual.
  Future<DeletionResult> call(Task task) async {
    final current = await repository.currentTask();
    if (current == null || current.id != task.id) {
      throw const TaskNotCurrent();
    }
    if (!await repository.delete(task.id, clock.now())) {
      throw const TaskNotCurrent();
    }
    return (deleted: task, next: await repository.currentTask());
  }
}
