import '../entities/task.dart';
import '../ports/attachment_store.dart';
import '../ports/clock.dart';
import '../ports/image_importer.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';

/// Qué pasa con el adjunto al editar (spec 007, CA-007-06).
sealed class AttachmentEdit {
  const AttachmentEdit();
}

final class KeepAttachment extends AttachmentEdit {
  const KeepAttachment();
}

final class RemoveAttachment extends AttachmentEdit {
  const RemoveAttachment();
}

final class ReplaceAttachment extends AttachmentEdit {
  const ReplaceAttachment(this.staged);
  final StagedAttachment staged;
}

/// Edita el texto y el adjunto de una tarea (R11, specs 005 y 007). Conserva su
/// posición y su color (CA-005-05, CA-007-06); si nada cambia, no escribe
/// (CL-005-2).
class EditTask {
  EditTask({
    required this.repository,
    required this.store,
    required this.janitor,
    required this.clock,
  });

  final TaskRepository repository;
  final AttachmentStore store;
  final AttachmentJanitor janitor;
  final Clock clock;

  /// Devuelve la tarea actualizada (o la misma, si no había cambios). Lanza
  /// [InvalidTaskText] si queda sin texto ni adjunto (CA-007-06).
  ///
  /// Si falla al guardar, la imagen nueva vuelve a la preparación para poder
  /// reintentar; la preparación la descarta el editor al cancelar.
  Future<Task> call(
    Task task,
    String rawText, {
    AttachmentEdit attachment = const KeepAttachment(),
  }) async {
    final hasAttachment = switch (attachment) {
      KeepAttachment() => task.attachment != null,
      RemoveAttachment() => false,
      ReplaceAttachment() => true,
    };
    final text = validateTaskContent(rawText, hasAttachment: hasAttachment);
    if (text == task.text &&
        (attachment is KeepAttachment ||
            (attachment is RemoveAttachment && task.attachment == null))) {
      return task;
    }
    final at = clock.now();
    final old = task.attachment;
    final next = switch (attachment) {
      KeepAttachment() => old,
      RemoveAttachment() => null,
      ReplaceAttachment(:final staged) => await store.commit(staged, at),
    };
    final isNew = attachment is ReplaceAttachment;
    final bool saved;
    try {
      saved = await repository.updateContent(task.id, text, next, at);
    } on Object {
      if (isNew) await janitor.restage(next!.id);
      rethrow;
    }
    if (isNew) janitor.release(next!.id);
    if (!saved) {
      // Ya no existe o está eliminada: el adjunto nuevo no tiene tarea.
      if (isNew) await janitor.discard(next!.id);
      return task;
    }
    if (old != null && old.id != next?.id) await janitor.discard(old.id);
    return task.withContent(text, next, at);
  }
}
