import 'dart:async';

import '../entities/attachment.dart';
import '../entities/image_type.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart';
import '../services/attachment_janitor.dart';

/// Importa una foto de la cámara o una imagen de la galería (spec 007) en dos
/// pasos: [pick] abre el sistema y, si el usuario elige algo, devuelve un
/// [ImportJob] que la copia y la limpia.
///
/// La preparación queda protegida del barrido (CA-007-16) desde que se abre la
/// cámara hasta que la tarea se guarda (`CreateTask`/`EditTask` la liberan) o
/// se descarta.
class ImportImage {
  ImportImage({
    required this.importer,
    required this.janitor,
    required this.ids,
    this.timeout = ImageLimits.timeout,
  });

  final ImageImporter importer;
  final AttachmentJanitor janitor;
  final IdGenerator ids;
  final Duration timeout;

  /// Devuelve null si el usuario cancela la cámara o el selector. Lanza
  /// [ImageImportFailure] (`noCamera`).
  Future<ImportJob?> pick(AttachmentOrigin origin) async {
    final id = ids.newId();
    janitor.registry.add(id);
    try {
      final picked = await importer.pick(origin, id);
      if (picked == null) {
        await janitor.discardStaging(id);
        return null;
      }
      return ImportJob._(this, id, picked);
    } on Object {
      await janitor.discardStaging(id);
      rethrow;
    }
  }
}

/// Una imagen elegida que se está preparando.
class ImportJob {
  ImportJob._(this._owner, this.id, this.picked);

  final ImportImage _owner;
  final String id;
  final PickedImage picked;
  var _cancelled = false;

  AttachmentOrigin get origin => picked.origin;

  /// Copia, decide el tipo **por el contenido** y limpia (CA-007-07/13/14),
  /// en 20 s como máximo. Si falla o se cancela, no queda nada: lanza
  /// [ImageImportFailure] o [ImageImportCancelled].
  Future<StagedImage> prepare() async {
    final importer = _owner.importer;
    try {
      return await _run(importer).timeout(
        _owner.timeout,
        onTimeout: () async {
          _cancelled = true;
          await importer.cancel(id);
          throw const ImageImportFailure(ImageImportError.unreadable);
        },
      );
    } on Object {
      await _owner.janitor.discardStaging(id);
      rethrow;
    }
  }

  Future<StagedImage> _run(ImageImporter importer) async {
    final copied = await importer.copy(
      picked,
      id,
      maxBytes: ImageLimits.maxBytes,
    );
    _checkCancelled();
    final type = sniffImageType(
      copied.head,
      heicSupported: importer.heicSupported,
    );
    if (type == null) {
      throw const ImageImportFailure(ImageImportError.unsupportedType);
    }
    final staged = await importer.sanitize(
      id,
      type,
      picked.origin,
      maxPixels: ImageLimits.maxPixels,
      storedMaxPixels: ImageLimits.storedMaxPixels,
    );
    _checkCancelled();
    return staged;
  }

  void _checkCancelled() {
    if (_cancelled) throw const ImageImportCancelled();
  }

  /// Cancela la preparación y la borra (CA-007-15).
  Future<void> cancel() async {
    _cancelled = true;
    await _owner.importer.cancel(id);
    await _owner.janitor.discardStaging(id);
  }
}
