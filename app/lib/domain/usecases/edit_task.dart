import '../entities/attachment.dart';
import '../entities/staged_attachment.dart';
import '../entities/task.dart';
import '../ports/attachment_store.dart';
import '../ports/clock.dart';
import '../ports/image_importer.dart';
import '../ports/task_repository.dart';
import '../services/attachment_janitor.dart';
import '../services/commit_group.dart';

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

/// Sustituye los adjuntos por [staged]: uno de cualquier tipo o de 2 a 10
/// imágenes (spec 016). Una lista vacía no vale: para quitar,
/// [RemoveAttachment].
final class ReplaceAttachment extends AttachmentEdit {
  const ReplaceAttachment(this.staged);

  /// El caso de un solo adjunto (imagen, PDF o web).
  ReplaceAttachment.one(StagedAttachment staged) : staged = [staged];

  final List<StagedAttachment> staged;
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
  /// Con adjuntos nuevos: [commitGroup] → una escritura → soltar la protección
  /// de cada uno; el grupo anterior se descarta **solo tras confirmar**. Si
  /// falla al guardar, los nuevos vuelven a la preparación para poder
  /// reintentar; la preparación la descarta el editor al cancelar. Si falta
  /// alguna preparación lanza [StagedPhotosLost] sin mover nada, y un grupo que
  /// no se puede guardar, [ArgumentError], con la tarea intacta.
  ///
  /// Editar solo el texto (o conservar el adjunto) no toca ningún archivo ni
  /// fila de adjuntos (CL-016-13).
  ///
  /// Una página web nueva deja la tarea sin texto; con la misma dirección que
  /// ya tenía, no cambia nada (CA-009-05).
  Future<Task> call(
    Task task,
    String rawText, {
    AttachmentEdit attachment = const KeepAttachment(),
  }) async {
    if (attachment case ReplaceAttachment(:final staged)) {
      if (staged.isEmpty || !staged.isValidStagedGroup) {
        throw ArgumentError.value(staged.length, 'attachment');
      }
    }
    final hasAttachment = switch (attachment) {
      KeepAttachment() => task.attachments.isNotEmpty,
      RemoveAttachment() => false,
      ReplaceAttachment() => true,
    };
    final webUrl = switch (attachment) {
      ReplaceAttachment(staged: [StagedWeb(:final url)]) => url,
      _ => null,
    };
    final text = webUrl != null
        ? null
        : validateTaskContent(rawText, hasAttachment: hasAttachment);
    final old = task.attachment;
    if (webUrl != null &&
        text == task.text &&
        task.attachments.length == 1 &&
        old!.isWeb &&
        old.url == webUrl) {
      return task;
    }
    if (text == task.text &&
        (attachment is KeepAttachment ||
            (attachment is RemoveAttachment && task.attachments.isEmpty))) {
      return task;
    }
    final at = clock.now();
    final List<Attachment> next = switch (attachment) {
      KeepAttachment() => task.attachments,
      RemoveAttachment() => const [],
      ReplaceAttachment(:final staged) => await commitGroup(store, staged, at),
    };
    final isNew = attachment is ReplaceAttachment;
    final bool saved;
    try {
      saved = await repository.updateContent(
        task.id,
        text,
        at,
        // Conservar = no tocar las filas (null); quitar = lista vacía.
        attachments: switch (attachment) {
          KeepAttachment() => null,
          RemoveAttachment() => const [],
          ReplaceAttachment() => next,
        },
      );
    } on Object {
      // Una web no tiene preparación: no queda nada que devolver.
      if (isNew) {
        await janitor.restageAll([
          for (final a in next)
            if (!a.isWeb) a.id,
        ]);
      }
      rethrow;
    }
    final nextIds = [for (final a in next) a.id];
    if (isNew) janitor.releaseAll(nextIds);
    if (!saved) {
      // Ya no existe o está eliminada: los adjuntos nuevos no tienen tarea.
      if (isNew) await janitor.discardAll(nextIds);
      return task;
    }
    // Solo ahora, con la escritura confirmada, se borra lo que ya no se usa.
    await janitor.discardAll([
      for (final a in task.attachments)
        if (!nextIds.contains(a.id)) a.id,
    ]);
    return task.withContent(text, null, at, attachments: next);
  }
}
