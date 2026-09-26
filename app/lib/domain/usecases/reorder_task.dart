import '../entities/rank.dart';
import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/task_repository.dart';
import 'delete_pending_task.dart' show TaskNotPending;

/// Posición final (1…total) de la tarea movida, para el anuncio (CA-006-17).
typedef ReorderResult = ({int position, int total});

/// Lleva la tarea pendiente [id] a la posición [toIndex] (0 = tarea actual)
/// de la cola (spec 006). Solo cambia su `rank` (ADR-0002, CA-006-10); si la
/// clave nueva fuera demasiado larga, antes renumera la cola (CL-006-8).
class ReorderTask {
  ReorderTask({required this.repository, required this.clock});

  final TaskRepository repository;
  final Clock clock;

  /// Devuelve null si la tarea ya estaba en esa posición (no escribe nada,
  /// CL-006-4). Lanza [TaskNotPending] si ya no está pendiente.
  Future<ReorderResult?> call(String id, int toIndex) async {
    var queue = await repository.pendingTasks();
    final from = queue.indexWhere((t) => t.id == id);
    if (from < 0) throw const TaskNotPending();
    final to = toIndex.clamp(0, queue.length - 1);
    if (to == from) return null;
    final now = clock.now();
    // Clave entre las vecinas de destino, sin contar la propia tarea.
    String rankIn(List<Task> q) {
      final others = [
        for (final t in q)
          if (t.id != id) t.rank,
      ];
      return Rank.between(
        to > 0 ? others[to - 1] : null,
        to < others.length ? others[to] : null,
      );
    }

    String? candidate;
    try {
      candidate = rankIn(queue);
    } on ArgumentError {
      // Vecinas con la misma clave: sin hueco entre ellas. Se renumera.
      candidate = null;
    }
    var rank = candidate ?? '';
    if (candidate == null || rank.length > Rank.maxLength) {
      await repository.renumberPending(now);
      queue = await repository.pendingTasks();
      rank = rankIn(queue);
    }
    if (!await repository.reorder(id, rank, now)) throw const TaskNotPending();
    return (position: to + 1, total: queue.length);
  }
}
