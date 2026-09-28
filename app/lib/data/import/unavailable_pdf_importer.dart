import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/image_importer.dart' show CopiedImage;
import '../../domain/ports/pdf_importer.dart';

/// Plataforma sin selector de PDF: elegir es como cancelar (no pasa nada).
class UnavailablePdfImporter implements PdfImporter {
  const UnavailablePdfImporter();

  @override
  Future<PickedPdf?> pick(String id) async => null;

  @override
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) => throw const PdfImportFailure(PdfImportError.unreadable);

  @override
  Future<PdfInfo> inspect(String id, {required int maxPages}) =>
      throw const PdfImportFailure(PdfImportError.unreadable);

  @override
  Future<void> renderScreen(
    Attachment attachment,
    PdfPosition position, {
    PageGap gap = noPageGap,
  }) async {}

  @override
  Future<void> cancel(String id) async {}
}
