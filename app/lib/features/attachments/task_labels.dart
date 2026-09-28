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
/// sin texto, "{nombre}. PDF" (`a11yRowPdfOnly`).
String taskReading(AppLocalizations l10n, Task task) {
  final text = task.text ?? '';
  final attachment = task.attachment;
  if (attachment == null) return text;
  if (attachment.isPdf) {
    return text.isEmpty
        ? l10n.a11yRowPdfOnly(taskLabel(l10n, task))
        : l10n.a11yRowWithPdf(readingText(text));
  }
  if (text.isEmpty) return attachmentKindLabel(l10n, task)!;
  return attachment.isPhoto
      ? l10n.a11yWithPhoto(readingText(text))
      : l10n.a11yWithImage(readingText(text));
}

/// [text] para ponerlo delante de ". Con PDF", ". Página 1…" y similares:
/// sin los puntos del final, para que el lector no diga "congreso.. Con PDF"
/// (T-008-23). Si solo tiene puntos, tal cual.
String readingText(String text) {
  final trimmed = text.trimRight();
  if (!trimmed.endsWith('.')) return text;
  var end = trimmed.length;
  while (end > 0 && trimmed[end - 1] == '.') {
    end--;
  }
  return end == 0 ? text : trimmed.substring(0, end).trimRight();
}
