import '../entities/color_picker.dart';
import '../entities/queue_position.dart';
import '../entities/rank.dart';
import '../entities/task.dart';
import '../ports/attachment_store.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';

/// Crea una tarea (R3) en la posición indicada (R4). Si no hay ninguna
/// pendiente, la posición es indiferente: pasa a ser la actual. Con imagen, va
/// siempre arriba del todo (R5, CA-007-05) y el texto es opcional.
class CreateTask {
  CreateTask({
    required this.repository,
    required this.store,
    required this.janitor,
    required this.clock,
    required this.ids,
    ColorPicker? colors,
  }) : colors = colors ?? ColorPicker();

  final TaskRepository repository;
  final AttachmentStore store;
  final AttachmentJanitor janitor;
  final Clock clock;
  final IdGenerator ids;
  final ColorPicker colors;

  /// Si falla al guardar, la [image] vuelve a la preparación para poder
  /// reintentar; la preparación la descarta el editor al cancelar.
  Future<Task> call(
    String rawText, {
    QueuePosition position = QueuePosition.top,
    int? colorKey,
    StagedImage? image,
  }) async {
    final text = validateTaskContent(rawText, hasAttachment: image != null);
    if (image != null) position = QueuePosition.top;
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
    final attachment = image == null ? null : await store.commit(image, now);
    final task = Task(
      id: ids.newId(),
      text: text,
      attachment: attachment,
      status: TaskStatus.pending,
      rank: rank,
      colorKey: colorKey ?? colors.pick(currentColorKey: current?.colorKey),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await repository.insert(task);
    } on Object {
      if (attachment != null) await janitor.restage(attachment.id);
      rethrow;
    }
    if (attachment != null) janitor.release(attachment.id);
    return task;
  }
}
