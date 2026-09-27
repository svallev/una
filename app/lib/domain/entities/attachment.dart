import 'package:flutter/foundation.dart';

/// Tipo de adjunto (docs/architecture.md §3). En la spec 007, solo imagen; PDF,
/// documento y web llegan con las specs 008 y 009.
enum AttachmentKind { image }

/// De dónde vino: decide si se lee "Foto" o "Imagen" (CA-007-20).
enum AttachmentOrigin { camera, gallery }

/// Adjunto de una tarea (v1: 0..1 por tarea). Inmutable. Las rutas son
/// relativas al directorio de adjuntos de la app; nunca se guarda el nombre
/// original del archivo (CA-007-07).
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
  });

  final String id;
  final AttachmentKind kind;
  final AttachmentOrigin origin;

  /// Tipo de lo guardado (siempre `image/jpeg` para imágenes recodificadas).
  final String mime;

  /// Bytes de la versión completa (todas sus teselas).
  final int byteSize;

  /// Dimensiones de la versión completa, ya orientada.
  final int width;
  final int height;
  final DateTime createdAt;

  /// Directorio del adjunto, relativo al contenedor de adjuntos.
  String get dir => 'attachments/$id';

  /// Prefijo de las teselas de la versión completa (columna `relPath`).
  String get fullPrefix => '$dir/full';

  /// Versión de pantalla, recortada al tamaño de la pantalla (I-2).
  String get screenPath => '$dir/screen.jpg';

  /// Miniatura del listado.
  String get thumbPath => '$dir/thumb.jpg';

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
      other.createdAt == createdAt;

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
