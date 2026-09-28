import 'package:flutter/foundation.dart';

/// Tipo de adjunto (docs/architecture.md §3): imagen (spec 007), PDF (spec
/// 008) y página web (spec 009). En la v1 no hay otros documentos (ADR-0014).
enum AttachmentKind { image, pdf, web }

/// De dónde vino: la cámara o la galería deciden si se lee "Foto" o "Imagen"
/// (CA-007-20); `file` es el selector de archivos (PDF, spec 008); `url`, una
/// dirección escrita en "Cargar URL" (spec 009).
enum AttachmentOrigin { camera, gallery, file, url }

/// Adjunto de una tarea (v1: 0..1 por tarea). Inmutable. Las rutas son
/// relativas al directorio de adjuntos de la app. De una imagen nunca se guarda
/// el nombre original (CA-007-07); de un PDF, sí, saneado (CA-008-07). Una
/// página web no tiene archivos: solo su dirección ([url], ADR-0016).
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.kind,
    required this.origin,
    required this.mime,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.createdAt,
    this.originalName,
    this.pageCount,
    this.url,
  });

  final String id;
  final AttachmentKind kind;
  final AttachmentOrigin origin;

  /// Tipo de lo guardado (siempre `image/jpeg` para imágenes recodificadas;
  /// `text/html` en una página web).
  final String mime;

  /// Bytes de la versión completa (todas sus teselas); 0 en una página web.
  final int byteSize;

  /// Imagen: dimensiones de la versión completa, ya orientada. PDF: tamaño de
  /// la primera página en puntos. Página web: 0.
  final int width;
  final int height;
  final DateTime createdAt;

  /// Nombre del PDF, saneado (CA-008-07); null en las imágenes o si quedó vacío.
  final String? originalName;

  /// Páginas del PDF (1..20, CA-008-03); null en las imágenes.
  final int? pageCount;

  /// Dirección validada de una página web (`validateWebAddress`, CA-009-04);
  /// null en las imágenes y los PDF.
  final String? url;

  bool get isPdf => kind == AttachmentKind.pdf;

  /// Página web (spec 009): sin archivos, ni miniatura ni versión de pantalla.
  bool get isWeb => kind == AttachmentKind.web;

  /// Directorio del adjunto, relativo al contenedor de adjuntos.
  String get dir => 'attachments/$id';

  /// Prefijo de las teselas de la versión completa (columna `relPath`).
  String get fullPrefix => '$dir/full';

  /// El PDF tal cual (spec 008).
  String get documentPath => '$dir/document.pdf';

  /// Lo que no puede faltar: la versión completa de la imagen o el PDF.
  String get mainPath => isPdf ? documentPath : fullPrefix;

  /// Versión de pantalla (I-2): la imagen al ancho o, en un PDF, la página de
  /// la última posición (CA-008-08).
  String get screenPath => '$dir/screen.jpg';

  /// Miniatura del listado; un PDF ni una web tienen (insignias "PDF",
  /// CA-008-19, y "WEB", CA-009-17).
  String? get thumbPath => isPdf || isWeb ? null : '$dir/thumb.jpg';

  /// Última posición vista de un PDF (CA-008-09).
  String get positionPath => '$dir/position.json';

  /// Teselas de la versión completa.
  ImageTiles get tiles => ImageTiles(width, height);

  bool get isPhoto => origin == AttachmentOrigin.camera;

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.id == id &&
      other.kind == kind &&
      other.origin == origin &&
      other.mime == mime &&
      other.byteSize == byteSize &&
      other.width == width &&
      other.height == height &&
      other.createdAt == createdAt &&
      other.originalName == originalName &&
      other.pageCount == pageCount &&
      other.url == url;

  @override
  int get hashCode => Object.hash(id, origin, width, height);

  @override
  String toString() => 'Attachment($id, ${kind.name}, ${width}x$height)';
}

/// Rejilla de teselas de la versión completa: la GPU no dibuja imágenes de más
/// de ~8 000–16 000 px de lado, así que se guarda en trozos de 4096 px como
/// máximo (spec 007, plan §7). Una foto de 12 MP es una sola tesela.
@immutable
class ImageTiles {
  const ImageTiles(this.width, this.height);

  static const int size = 4096;

  final int width;
  final int height;

  int get columns => (width + size - 1) ~/ size;
  int get rows => (height + size - 1) ~/ size;

  /// Nombre de la tesela (fila, columna), relativo al directorio del adjunto.
  static String fileName(int row, int column) => 'full-$row-$column.jpg';

  /// Rectángulo de la tesela en píxeles de la imagen completa.
  ({int left, int top, int width, int height}) rect(int row, int column) {
    final left = column * size;
    final top = row * size;
    return (
      left: left,
      top: top,
      width: (width - left).clamp(0, size),
      height: (height - top).clamp(0, size),
    );
  }
}
