import '../entities/task.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';

/// La tarea ya no está (completada, eliminada o inexistente).
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

/// Elimina de forma definitiva cualquier tarea pendiente (spec 006, ADR-0012):
/// a diferencia de `DeleteCurrentTask`, no exige que sea la actual.
class DeletePendingTask {
  DeletePendingTask({required this.repository, required this.janitor});

  final TaskRepository repository;
  final AttachmentJanitor janitor;

  Future<PendingDeletionResult> call(String id) async {
    final task = await repository.findById(id);
    if (task == null || !task.isPending) throw const TaskNotPending();
    final wasCurrent = (await repository.currentTask())?.id == id;
    if (!await repository.remove(id)) throw const TaskNotPending();
    // Después de guardar, los archivos (CA-007-16).
    if (task.attachment case final a?) await janitor.discard(a.id);
    return (
      deleted: task,
      next: await repository.currentTask(),
      remaining: await repository.countPending(),
      wasCurrent: wasCurrent,
    );
  }
}
