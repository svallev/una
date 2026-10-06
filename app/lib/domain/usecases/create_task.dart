import '../entities/attachment.dart';
import '../entities/color_picker.dart';
import '../entities/queue_position.dart';
import '../entities/rank.dart';
import '../entities/staged_attachment.dart';
import '../entities/task.dart';
import '../ports/attachment_store.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';
import '../services/commit_group.dart';

/// Crea una tarea (R3) en la posición indicada (R4). Si no hay ninguna
/// pendiente, la posición es indiferente: pasa a ser la actual. Con imagen, va
/// siempre arriba del todo (R5, CA-007-05) y el texto es opcional. Una página
/// web también va arriba y nunca tiene texto: el del editor se descarta
/// (CA-009-03). Con varias imágenes (de 2 a 10, spec 016) forman un solo grupo
/// de la misma tarea: o se guardan todas o ninguna.
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

  /// Si falla al guardar, los [attachments] vuelven a la preparación para poder
  /// reintentar; la preparación la descarta el editor al cancelar. Si falta
  /// alguna preparación lanza [StagedPhotosLost] sin mover nada (CL-016-6b), y
  /// un grupo que no se puede guardar (más de 10, o mezcla de tipos),
  /// [ArgumentError] antes de tocar ningún archivo.
  Future<Task> call(
    String rawText, {
    QueuePosition position = QueuePosition.top,
    int? colorKey,
    List<StagedAttachment> attachments = const [],
  }) async {
    if (!attachments.isValidStagedGroup) {
      throw ArgumentError.value(attachments.length, 'attachments');
    }
    final staged = attachments.isEmpty ? null : attachments.first;
    final text = staged is StagedWeb
        ? null
        : validateTaskContent(rawText, hasAttachment: staged != null);
    // Los adjuntos van siempre arriba (R5, CA-007-05, CA-008-05).
    if (staged != null) position = QueuePosition.top;
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
    final saved = attachments.isEmpty
        ? const <Attachment>[]
        : await commitGroup(store, attachments, now);
    final task = Task(
      id: ids.newId(),
      text: text,
      attachments: saved,
      status: TaskStatus.pending,
      rank: rank,
      colorKey: colorKey ?? colors.pick(currentColorKey: current?.colorKey),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await repository.insert(task);
    } on Object {
      // Una web no tiene preparación: no queda nada que devolver.
      await janitor.restageAll([
        for (final a in saved)
          if (!a.isWeb) a.id,
      ]);
      rethrow;
    }
    janitor.releaseAll([for (final a in saved) a.id]);
    return task;
  }
}
