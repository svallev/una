import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';
import '../../domain/ports/pdf_importer.dart';
import '../../domain/services/pdf_sniffer.dart';
import '../../l10n/generated/app_localizations.dart';

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
