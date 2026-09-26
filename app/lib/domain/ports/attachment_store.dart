import '../entities/attachment.dart';
import 'image_importer.dart';

/// Estado de los archivos de un adjunto (CA-007-19).
enum AttachmentFiles {
  /// Están todas las versiones.
  ok,

  /// Falta la versión de pantalla o la miniatura: se regeneran sin avisar.
  derivedMissing,

  /// Falta (o está vacía) la versión completa: "Adjunto no disponible".
  missing,
}

/// Archivos de los adjuntos en el almacenamiento privado de la app (ADR-0002).
/// La preparación (`import/<id>`) es temporal y se barre; los adjuntos
/// guardados (`attachments/<id>`) pertenecen a una tarea.
abstract interface class AttachmentStore {
  /// Mueve la preparación [staged] a su sitio definitivo, de forma atómica, y
  /// devuelve el adjunto (aún sin guardar en la BD).
  Future<Attachment> commit(StagedImage staged, DateTime at);

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
}
