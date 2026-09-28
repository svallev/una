import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import 'pdf_labels.dart';

/// Tipo del adjunto para la insignia del listado: "Foto" (de la cámara),
/// "Imagen" (de la galería) o "PDF" (CA-008-19), o null sin adjunto.
String? attachmentKindLabel(AppLocalizations l10n, Task task) =>
    switch (task.attachment) {
      null => null,
      final a when a.isPdf => l10n.attachmentPdf,
      final a => a.isPhoto ? l10n.attachmentPhoto : l10n.attachmentImage,
    };

/// Cómo se nombra la tarea en el listado, la confirmación de eliminar y los
/// anuncios: su texto o, sin texto, "Foto"/"Imagen" (CA-007-20, CL-003-8) o
/// el nombre del PDF ("PDF" si no tiene, CA-008-19).
String taskLabel(AppLocalizations l10n, Task task) {
  final text = task.text ?? '';
  if (text.isNotEmpty) return text;
  final attachment = task.attachment;
  if (attachment != null && attachment.isPdf) {
    return pdfName(l10n, attachment.originalName);
  }
  return attachmentKindLabel(l10n, task) ?? '';
}

/// Lectura para el lector de pantalla (CA-007-21, CA-008-20): "{texto}. Con
/// foto" / "Con imagen" / "Con PDF", o "Foto"/"Imagen" sin texto. Con PDF y
/// sin texto, `a11yRowWithPdf` con el nombre (tabla de textos de la spec 008).
String taskReading(AppLocalizations l10n, Task task) {
  final text = task.text ?? '';
  final attachment = task.attachment;
  if (attachment == null) return text;
  if (attachment.isPdf) return l10n.a11yRowWithPdf(taskLabel(l10n, task));
  if (text.isEmpty) return attachmentKindLabel(l10n, task)!;
  return attachment.isPhoto
      ? l10n.a11yWithPhoto(text)
      : l10n.a11yWithImage(text);
}
