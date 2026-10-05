import '../entities/task.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';
import 'delete_current_task.dart' show removeHolding;

/// La tarea ya no está (completada, eliminada o inexistente).
class TaskNotPending implements Exception {
  const TaskNotPending();
}

/// Resultado de eliminar desde el listado: la eliminada, tal como estaba en la
/// BD (para deshacer, CA-014-09), la tarea actual que queda (null si no queda
/// ninguna o no se pudo leer: la pantalla la toma del flujo), cuántas quedan y
/// si la eliminada era la actual (CA-006-14).
typedef PendingDeletionResult = ({
  Task deleted,
  Task? next,
  int remaining,
  bool wasCurrent,
});

/// Elimina cualquier tarea pendiente (spec 006), en dos tiempos como
/// `DeleteCurrentTask` (ADR-0021): la fila sale al momento y los archivos se
/// retienen hasta que la eliminación es definitiva. A diferencia de
/// `DeleteCurrentTask`, no exige que sea la actual.
class DeletePendingTask {
  DeletePendingTask({required this.repository, required this.janitor});

  final TaskRepository repository;
  final AttachmentJanitor janitor;

  Future<PendingDeletionResult> call(String id) async {
    final task = await repository.findById(id);
    if (task == null || !task.isPending) throw const TaskNotPending();
    final current = await repository.currentTask();
    final wasCurrent = current?.id == id;
    // El recuento, antes: después de quitar la fila no se lee nada que pueda
    // convertir una eliminación ya guardada en un fallo (salvo la siguiente
    // actual, si era esta, y sin lanzar). La cola solo cambia desde la app.
    final pending = await repository.countPending();
    if (!await removeHolding(repository, janitor, task)) {
      throw const TaskNotPending();
    }
    Task? next = current;
    if (wasCurrent) {
      try {
        next = await repository.currentTask();
      } on Object {
        next = null;
      }
    }
    return (
      deleted: task,
      next: next,
      remaining: pending - 1,
      wasCurrent: wasCurrent,
    );
  }
}
