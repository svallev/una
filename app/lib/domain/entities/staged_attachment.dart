import 'attachment.dart';
import 'image_type.dart';

/// Adjunto ya preparado en la zona de preparación `<id>`, listo para guardarse
/// con la tarea (`AttachmentStore.commit`). Una tarea tiene uno (de cualquier
/// tipo) o, si son imágenes, de 2 a [ImageLimits.maxGroup] (spec 016).
sealed class StagedAttachment {
  const StagedAttachment({required this.id, required this.byteSize});

  final String id;
  final int byteSize;
}

/// Lo que se puede guardar con una tarea (spec 016, ADR-0024): uno de
/// cualquier tipo, o de 2 a [ImageLimits.maxGroup] imágenes. Lo comprueban
/// `CreateTask` y `EditTask` antes de tocar ningún archivo.
extension StagedGroup on List<StagedAttachment> {
  bool get isValidStagedGroup =>
      length <= 1 ||
      (length <= ImageLimits.maxGroup && every((s) => s is StagedImage));
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

/// Página web (spec 009): solo la dirección ya validada (`validateWebAddress`).
/// No hay nada preparado en disco (ADR-0016): [id] es el del adjunto.
final class StagedWeb extends StagedAttachment {
  const StagedWeb({required super.id, required this.url}) : super(byteSize: 0);

  final String url;

  @override
  bool operator ==(Object other) =>
      other is StagedWeb && other.id == id && other.url == url;

  @override
  int get hashCode => Object.hash(id, url);

  // Sin la dirección: no va a ningún registro (CL-009-9).
  @override
  String toString() => 'StagedWeb($id)';
}
