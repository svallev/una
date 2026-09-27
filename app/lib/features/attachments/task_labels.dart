import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Foto" (de la cámara) o "Imagen" (de la galería), o null sin adjunto.
String? attachmentKindLabel(AppLocalizations l10n, Task task) =>
    switch (task.attachment) {
      null => null,
      final a => a.isPhoto ? l10n.attachmentPhoto : l10n.attachmentImage,
    };

/// Cómo se nombra la tarea en el listado, la confirmación de eliminar y los
/// anuncios: su texto o, sin texto, "Foto"/"Imagen" (CA-007-20, CL-003-8).
String taskLabel(AppLocalizations l10n, Task task) {
  final text = task.text ?? '';
  if (text.isNotEmpty) return text;
  return attachmentKindLabel(l10n, task) ?? '';
}

/// Lectura para el lector de pantalla (CA-007-21): "{texto}. Con foto" /
/// "Con imagen", o "Foto"/"Imagen" sin texto.
String taskReading(AppLocalizations l10n, Task task) {
  final text = task.text ?? '';
  final attachment = task.attachment;
  if (attachment == null) return text;
  if (text.isEmpty) return attachmentKindLabel(l10n, task)!;
  return attachment.isPhoto
      ? l10n.a11yWithPhoto(text)
      : l10n.a11yWithImage(text);
}
