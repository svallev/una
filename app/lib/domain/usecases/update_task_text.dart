import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/task_repository.dart';

/// Cambia el texto de una tarea (R11, spec 005). Conserva su posición y su
/// color; si el texto no cambia, no hace nada (CL-005-2).
class UpdateTaskText {
  UpdateTaskText({required this.repository, required this.clock});

  final TaskRepository repository;
  final Clock clock;

  /// Devuelve la tarea actualizada (o la misma, si no había cambios).
  /// Lanza [InvalidTaskText] si el texto queda vacío (CA-005-06).
  Future<Task> call(Task task, String rawText) async {
    final text = validateTaskText(rawText);
    if (text == task.text) return task;
    final at = clock.now();
    await repository.updateText(task.id, text, at);
    return task.withText(text, at);
  }
}
