import '../../domain/entities/attachment.dart';
import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';

/// Plataforma sin cámara ni selector: elegir es como cancelar (no pasa nada).
class UnavailableImageImporter implements ImageImporter {
  const UnavailableImageImporter();

  @override
  bool get heicSupported => false;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async => null;

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) => throw const ImageImportFailure(ImageImportError.unreadable);

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) => throw const ImageImportFailure(ImageImportError.unreadable);

  @override
  Future<void> cancel(String id) async {}
}
