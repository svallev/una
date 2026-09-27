import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'memory_attachment_store.dart';

/// Un PDF para el visor (spec 008): la ruta en disco (móvil) o los bytes (web
/// de pruebas y tests). [key] identifica el documento: si cambia, se recarga.
typedef PdfSource = ({String? path, Uint8List? bytes, String key});

/// Imágenes de los adjuntos para dibujarlas: de disco en móvil
/// (`FileAttachmentImages`) y de memoria en la web de pruebas y en los tests.
/// También da los PDF al visor (spec 008).
abstract interface class AttachmentImages {
  /// Archivo [name] de la preparación [id] (vista previa antes de guardar).
  ImageProvider staged(String id, String name);

  /// Archivo guardado [relPath] (`Attachment.screenPath`, `thumbPath`…).
  ImageProvider stored(String relPath);

  /// El PDF de la preparación [id] (vista previa en el editor).
  PdfSource stagedPdf(String id);

  /// El PDF guardado [relPath] (`Attachment.documentPath`).
  PdfSource storedPdf(String relPath);
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

  @override
  PdfSource stagedPdf(String id) => (
    path: null,
    bytes: store.stagingBytes(id, 'document.pdf'),
    key: 'staged:$id',
  );

  @override
  PdfSource storedPdf(String relPath) =>
      (path: null, bytes: store.bytes(relPath), key: relPath);
}
