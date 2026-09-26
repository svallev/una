import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'memory_attachment_store.dart';

/// Imágenes de los adjuntos para dibujarlas: de disco en móvil
/// (`FileAttachmentImages`) y de memoria en la web de pruebas y en los tests.
abstract interface class AttachmentImages {
  /// Archivo [name] de la preparación [id] (vista previa antes de guardar).
  ImageProvider staged(String id, String name);

  /// Archivo guardado [relPath] (`Attachment.screenPath`, `thumbPath`…).
  ImageProvider stored(String relPath);
}

class MemoryAttachmentImages implements AttachmentImages {
  MemoryAttachmentImages(this.store);

  final MemoryAttachmentStore store;

  static final _empty = Uint8List(0);

  // Sin bytes, la imagen no se decodifica y se ve el `errorBuilder`.
  @override
  ImageProvider staged(String id, String name) =>
      MemoryImage(store.stagingBytes(id, name) ?? _empty);

  @override
  ImageProvider stored(String relPath) =>
      MemoryImage(store.bytes(relPath) ?? _empty);
}
