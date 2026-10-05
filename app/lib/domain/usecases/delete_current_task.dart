import '../entities/task.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';
import 'complete_current_task.dart' show TaskNotCurrent;

/// Resultado de eliminar: la tarea eliminada, tal como estaba en la BD (para
/// la animación y para deshacer, CA-014-09), y la nueva tarea actual, o null
/// si no queda ninguna ("Todo hecho.", CA-004-07) o no se pudo leer (entonces
/// la pantalla la toma del flujo de la tarea actual).
typedef DeletionResult = ({Task deleted, Task? next});

/// Elimina la tarea actual (R10) en dos tiempos (ADR-0021): la fila sale de la
/// BD **antes** de la animación, así que si la app muere a mitad ya está
/// eliminada (CA-004-03, CA-014-13), pero sus archivos se **retienen**: los
/// borra `AttachmentJanitor.discardHeld` cuando la eliminación es definitiva
/// (CA-014-15) o los suelta `RestoreDeletedTask` al deshacer.
class DeleteCurrentTask {
  DeleteCurrentTask({required this.repository, required this.janitor});

  final TaskRepository repository;
  final AttachmentJanitor janitor;

  /// Elimina [task] si sigue siendo la tarea actual.
  Future<DeletionResult> call(Task task) async {
    final current = await repository.currentTask();
    if (current == null || current.id != task.id) {
      throw const TaskNotCurrent();
    }
    final removed = await removeHolding(repository, janitor, current);
    if (!removed) throw const TaskNotCurrent();
    // Ya está eliminada: un fallo al leer la siguiente no es un fallo al
    // eliminar (la card tiene que poder salir).
    Task? next;
    try {
      next = await repository.currentTask();
    } on Object {
      next = null;
    }
    return (deleted: current, next: next);
  }
}

/// Quita la fila de [task] reteniendo antes sus archivos (ADR-0021): si no se
/// llega a quitar (falla o ya no estaba), los suelta, pero solo si los ha
/// retenido esta llamada. Relanza los errores de escritura.
Future<bool> removeHolding(
  TaskRepository repository,
  AttachmentJanitor janitor,
  Task task,
) async {
  final attachment = task.attachment;
  if (attachment == null) return repository.remove(task.id);
  final held = janitor.hold(attachment.id);
  var removed = false;
  try {
    removed = await repository.remove(task.id);
    return removed;
  } finally {
    if (held && !removed) janitor.releaseHeld(attachment.id);
  }
}
