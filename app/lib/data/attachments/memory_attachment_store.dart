import 'dart:typed_data';

import '../../domain/entities/attachment.dart';
import '../../domain/ports/attachment_store.dart';
import '../../domain/ports/image_importer.dart';

/// Adjuntos en memoria: web de pruebas (CL-007-12, ADR-0010) y tests. Se
/// pierden al recargar, como las tareas.
class MemoryAttachmentStore implements AttachmentStore {
  final Map<String, Map<String, Uint8List>> _stored = {};
  final Map<String, Map<String, Uint8List>> _staging = {};

  /// Escribe un archivo de la preparación [id] (lo usa el importador web).
  void putStaging(String id, String name, Uint8List bytes) =>
      (_staging[id] ??= {})[name] = bytes;

  /// Contenido de un archivo guardado ([relPath] de [Attachment]).
  Uint8List? bytes(String relPath) {
    final parts = relPath.split('/');
    if (parts.length != 3 || parts.first != 'attachments') return null;
    return _stored[parts[1]]?[parts[2]];
  }

  /// Contenido de un archivo de la preparación [id].
  Uint8List? stagingBytes(String id, String name) => _staging[id]?[name];

  /// Simula que faltan o se estropean archivos (tests de CA-007-19).
  void removeFile(String id, String name) => _stored[id]?.remove(name);

  @override
  Future<Attachment> commit(StagedImage staged, DateTime at) async {
    final files = _staging.remove(staged.id);
    if (files == null) throw StateError('No hay preparación ${staged.id}');
    _stored[staged.id] = files;
    return Attachment(
      id: staged.id,
      kind: AttachmentKind.image,
      origin: staged.origin,
      mime: 'image/jpeg',
      byteSize: staged.byteSize,
      width: staged.width,
      height: staged.height,
      createdAt: at,
    );
  }

  @override
  Future<void> restage(String id) async {
    final files = _stored.remove(id);
    if (files == null) throw StateError('No existe el adjunto $id');
    _staging[id] = files;
  }

  @override
  Future<void> delete(String id) async => _stored.remove(id);

  @override
  Future<void> deleteStaging(String id) async => _staging.remove(id);

  @override
  Future<Set<String>> storedIds() async => {..._stored.keys};

  @override
  Future<Set<String>> stagingIds() async => {..._staging.keys};

  @override
  Future<AttachmentFiles> check(Attachment attachment) async {
    final files = _stored[attachment.id];
    bool present(String name) => (files?[name]?.length ?? 0) > 0;
    final tiles = attachment.tiles;
    for (var r = 0; r < tiles.rows; r++) {
      for (var c = 0; c < tiles.columns; c++) {
        if (!present(ImageTiles.fileName(r, c))) return AttachmentFiles.missing;
      }
    }
    if (tiles.rows == 0) return AttachmentFiles.missing;
    return present('screen.jpg') && present('thumb.jpg')
        ? AttachmentFiles.ok
        : AttachmentFiles.derivedMissing;
  }
}
