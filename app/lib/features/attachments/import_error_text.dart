import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';
import '../../domain/ports/pdf_importer.dart';
import '../../domain/services/pdf_sniffer.dart';
import '../../l10n/generated/app_localizations.dart';
import 'attachment_import_controller.dart';

/// Aviso de cada error de importación: [error] es un [ImageImportError] (spec
/// 007 §5) o un [PdfImportError] (spec 008 §5).
String importErrorText(AppLocalizations l10n, Enum error) => switch (error) {
  ImageImportError.unsupportedType => l10n.errImageType,
  ImageImportError.tooLarge => l10n.errImageTooBig(ImageLimits.maxBytesInMb),
  ImageImportError.tooManyPixels => l10n.errImageTooManyPixels(
    ImageLimits.maxMegapixels,
  ),
  ImageImportError.unreadable => l10n.errImageUnreadable,
  ImageImportError.noCamera => l10n.errNoCamera,
  ImageImportError.noSpace => l10n.storageErrorNoSpace,
  PdfImportError.notPdf => l10n.errPdfType,
  PdfImportError.tooLarge => l10n.errPdfTooBig(PdfLimits.maxBytesInMb),
  PdfImportError.tooManyPages => l10n.errPdfTooManyPages(PdfLimits.maxPages),
  PdfImportError.protected => l10n.errPdfProtected,
  PdfImportError.unreadable => l10n.errPdfUnreadable,
  PdfImportError.noSpace => l10n.storageErrorNoSpace,
  _ => l10n.errPdfUnreadable,
};

/// El aviso compuesto al volver del selector múltiple (CA-016-21), que es a la
/// vez el texto visible y el anuncio: une, en este orden y con un espacio, lo
/// que haya de "Solo se usarán las 10 primeras." · "{n} fotos añadidas." ·
/// "No se pudo añadir 1 foto.". Cada parte acaba en punto.
String importNoticeText(AppLocalizations l10n, ImportNotice notice) {
  String sentence(String text) => text.endsWith('.') ? text : '$text.';
  return [
    if (notice.limited) l10n.imagesLimitNotice(ImageLimits.maxGroup),
    if (notice.added > 0) l10n.a11yPhotosAdded(notice.added),
    if (notice.failed > 0) l10n.imagesSomeFailed(notice.failed),
  ].map(sentence).join(' ');
}
