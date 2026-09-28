import '../entities/attachment.dart';
import '../entities/pdf_position.dart';
import '../entities/staged_attachment.dart';

/// Estado de los archivos de un adjunto (CA-007-19).
enum AttachmentFiles {
  /// Están todas las versiones.
  ok,

  /// Falta la versión de pantalla o la miniatura: se regeneran sin avisar.
  derivedMissing,

  /// Falta (o está vacía) la versión completa de la imagen o el PDF:
  /// "Adjunto no disponible" (CA-007-19, CA-008-18).
  missing,
}

/// Archivos de los adjuntos en el almacenamiento privado de la app (ADR-0002).
/// La preparación (`import/<id>`) es temporal y se barre; los adjuntos
/// guardados (`attachments/<id>`) pertenecen a una tarea.
abstract interface class AttachmentStore {
  /// Mueve la preparación [staged] a su sitio definitivo, de forma atómica, y
  /// devuelve el adjunto (aún sin guardar en la BD).
  Future<Attachment> commit(StagedAttachment staged, DateTime at);

  /// Deshace [commit]: devuelve el adjunto [id] a la preparación (si falla la
  /// escritura en la BD, para reintentar).
  Future<void> restage(String id);

  /// Borra todos los archivos del adjunto guardado [id]. Si no existe, nada.
  Future<void> delete(String id);

  /// Borra la preparación [id]. Si no existe, nada.
  Future<void> deleteStaging(String id);

  /// Ids de los adjuntos guardados en disco.
  Future<Set<String>> storedIds();

  /// Ids de las preparaciones en disco.
  Future<Set<String>> stagingIds();

  Future<AttachmentFiles> check(Attachment attachment);

  /// Última posición vista del PDF [id] (CA-008-09), o null si no hay o no se
  /// puede leer. Va en su carpeta: se borra con el adjunto (CA-008-16).
  Future<PdfPosition?> readPosition(String id);

  /// Guarda la última posición del PDF [id]. Si el adjunto ya no existe (se
  /// completó o eliminó mientras tanto), no hace nada.
  Future<void> writePosition(String id, PdfPosition position);
}

/// El adjunto que corresponde a [staged], ya guardado en [at].
Attachment attachmentFrom(StagedAttachment staged, DateTime at) =>
    switch (staged) {
      StagedImage() => Attachment(
        id: staged.id,
        kind: AttachmentKind.image,
        origin: staged.origin,
        mime: 'image/jpeg',
        byteSize: staged.byteSize,
        width: staged.width,
        height: staged.height,
        createdAt: at,
      ),
      StagedPdf() => Attachment(
        id: staged.id,
        kind: AttachmentKind.pdf,
        origin: AttachmentOrigin.file,
        mime: 'application/pdf',
        byteSize: staged.byteSize,
        width: staged.width,
        height: staged.height,
        createdAt: at,
        originalName: staged.originalName,
        pageCount: staged.pageCount,
      ),
      // Sin archivos ni medidas: solo la dirección (plan §3, ADR-0016).
      StagedWeb() => Attachment(
        id: staged.id,
        kind: AttachmentKind.web,
        origin: AttachmentOrigin.url,
        mime: 'text/html',
        byteSize: 0,
        width: 0,
        height: 0,
        createdAt: at,
        url: staged.url,
      ),
    };
