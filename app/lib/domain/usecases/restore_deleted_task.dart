import '../entities/task.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';

/// Otra tarea pendiente ocupa ya el sitio (`rank`) de la que se quiere
/// recuperar. No debería pasar: todo lo que cambia la cola hace antes
/// definitiva la eliminación (CA-014-11, ADR-0021). Si pasa, no se recupera:
/// nunca dos filas con el mismo `rank`.
class RankTaken implements Exception {
  const RankTaken();
}

/// Deshace una eliminación (CA-014-09, ADR-0021): vuelve a guardar la misma
/// [Task] que se eliminó (id, `rank`, color, fechas y adjunto), en el mismo
/// sitio de la cola. No es una tarea nueva: no pasa por la preparación de
/// adjuntos (sus archivos siguen en su sitio, retenidos) y conserva
/// `createdAt` y `updatedAt` (plan §10).
class RestoreDeletedTask {
  RestoreDeletedTask({required this.repository, required this.janitor});

  final TaskRepository repository;
  final AttachmentJanitor janitor;

  /// Si [task] ya está (otra recuperación se adelantó), no hace nada. Si
  /// falla, lanza y sus archivos siguen retenidos: se puede reintentar o, si
  /// la eliminación pasa a ser definitiva, borrarlos (CA-014-23).
  Future<void> call(Task task) async {
    if (await repository.findById(task.id) != null) return;
    final pending = await repository.pendingTasks();
    if (pending.any((t) => t.rank == task.rank)) throw const RankTaken();
    await repository.insert(task);
    // Primero la fila y después soltar: el barrido nunca ve los archivos sin
    // fila ni retención.
    if (task.attachment case final a?) janitor.releaseHeld(a.id);
  }
}
