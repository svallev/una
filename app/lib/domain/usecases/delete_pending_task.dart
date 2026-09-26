import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/task_repository.dart';

/// La tarea ya no está pendiente (completada, eliminada o inexistente).
class TaskNotPending implements Exception {
  const TaskNotPending();
}

/// Resultado de eliminar desde el listado: la eliminada, la tarea actual que
/// queda, cuántas quedan y si la eliminada era la actual (CA-006-14/17).
typedef PendingDeletionResult = ({
  Task deleted,
  Task? next,
  int remaining,
  bool wasCurrent,
});

/// Elimina de forma definitiva cualquier tarea pendiente (spec 006, ADR-0011):
/// a diferencia de `DeleteCurrentTask`, no exige que sea la actual.
class DeletePendingTask {
  DeletePendingTask({required this.repository, required this.clock});

  final TaskRepository repository;
  final Clock clock;

  Future<PendingDeletionResult> call(String id) async {
    final task = await repository.findById(id);
    if (task == null || !task.isPending) throw const TaskNotPending();
    final wasCurrent = (await repository.currentTask())?.id == id;
    if (!await repository.delete(id, clock.now())) {
      throw const TaskNotPending();
    }
    return (
      deleted: task,
      next: await repository.currentTask(),
      remaining: await repository.countPending(),
      wasCurrent: wasCurrent,
    );
  }
}
