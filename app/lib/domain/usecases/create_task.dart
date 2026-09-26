import '../entities/color_picker.dart';
import '../entities/queue_position.dart';
import '../entities/rank.dart';
import '../entities/task.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/task_repository.dart';

/// Crea una tarea de texto (R3) en la posición indicada (R4). Si no hay
/// ninguna pendiente, la posición es indiferente: pasa a ser la actual.
class CreateTask {
  CreateTask({
    required this.repository,
    required this.clock,
    required this.ids,
    ColorPicker? colors,
  }) : colors = colors ?? ColorPicker();

  final TaskRepository repository;
  final Clock clock;
  final IdGenerator ids;
  final ColorPicker colors;

  Future<Task> call(
    String rawText, {
    QueuePosition position = QueuePosition.top,
    int? colorKey,
  }) async {
    final text = validateTaskText(rawText);
    final current = await repository.currentTask();
    Future<String> rankFor() async => switch (position) {
      QueuePosition.top => Rank.before(await repository.firstPendingRank()),
      QueuePosition.end => Rank.after(await repository.lastPendingRank()),
    };
    final now = clock.now();
    var rank = await rankFor();
    // Muchas inserciones en el mismo extremo alargan las claves (ADR-0002).
    if (rank.length > Rank.maxLength) {
      await repository.renumberPending(now);
      rank = await rankFor();
    }
    final task = Task(
      id: ids.newId(),
      text: text,
      status: TaskStatus.pending,
      rank: rank,
      colorKey: colorKey ?? colors.pick(currentColorKey: current?.colorKey),
      createdAt: now,
      updatedAt: now,
    );
    await repository.insert(task);
    return task;
  }
}
