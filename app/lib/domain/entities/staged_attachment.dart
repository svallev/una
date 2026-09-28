import 'attachment.dart';

/// Adjunto ya preparado en la zona de preparación `<id>`, listo para guardarse
/// con la tarea (`AttachmentStore.commit`). Una tarea tiene uno como mucho.
sealed class StagedAttachment {
  const StagedAttachment({required this.id, required this.byteSize});

  final String id;
  final int byteSize;
}

/// Imagen ya limpia: versión completa en teselas, versión de pantalla y
/// miniatura (spec 007).
final class StagedImage extends StagedAttachment {
  const StagedImage({
    required super.id,
    required this.origin,
    required this.width,
    required this.height,
    required super.byteSize,
  });

  final AttachmentOrigin origin;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is StagedImage &&
      other.id == id &&
      other.origin == origin &&
      other.width == width &&
      other.height == height &&
      other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(id, origin, width, height, byteSize);

  @override
  String toString() => 'StagedImage($id, ${width}x$height, $byteSize)';
}

/// PDF comprobado (1..20 páginas, se abre sin contraseña): `document.pdf` y la
/// versión de pantalla de la primera página (spec 008).
final class StagedPdf extends StagedAttachment {
  const StagedPdf({
    required super.id,
    required super.byteSize,
    required this.pageCount,
    required this.width,
    required this.height,
    required this.originalName,
  });

  final int pageCount;

  /// Tamaño de la primera página en puntos.
  final int width;
  final int height;

  /// Nombre saneado (CA-008-07), o null si quedó vacío.
  final String? originalName;

  @override
  bool operator ==(Object other) =>
      other is StagedPdf &&
      other.id == id &&
      other.byteSize == byteSize &&
      other.pageCount == pageCount &&
      other.width == width &&
      other.height == height &&
      other.originalName == originalName;

  @override
  int get hashCode =>
      Object.hash(id, byteSize, pageCount, width, height, originalName);

  @override
  String toString() => 'StagedPdf($id, $pageCount p., $byteSize)';
}
