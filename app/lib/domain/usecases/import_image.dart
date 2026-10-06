import 'dart:async';

import '../entities/attachment.dart';
import '../entities/image_type.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart';
import '../services/attachment_janitor.dart';
import '../services/import_budget.dart';

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
    this.clock = const SystemClock(),
    this.periodic,
  });

  final ImageImporter importer;
  final AttachmentJanitor janitor;
  final IdGenerator ids;

  /// Reloj y temporizador del [ImportBudget] (se inyectan en los tests).
  final Clock clock;
  final PeriodicTimerFactory? periodic;

  /// Un presupuesto nuevo: 20 s por foto y 2 minutos en total (CA-007-14,
  /// CA-016-04). Una foto suelta usa uno propio; un grupo, uno para todas.
  ImportBudget newBudget() => ImportBudget(clock: clock, periodic: periodic);

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
  /// con 20 s como máximo de tiempo activo ([ImportBudget]; el del grupo, si se
  /// da [budget]). Si falla o se cancela, no queda nada: lanza
  /// [ImageImportFailure] o [ImageImportCancelled].
  ///
  /// **Nunca deja salir el texto de otra excepción** (ruta, nombre, URI):
  /// cualquier fallo inesperado es `unreadable` (CL-016-16).
  Future<StagedImage> prepare({ImportBudget? budget}) async {
    final importer = _owner.importer;
    try {
      return await (budget ?? _owner.newBudget()).runPhoto(
        () => _run(importer),
        onExpired: (_) {
          _cancelled = true;
          // No se espera: si la copia está colgada, el aviso sale igual.
          unawaited(_cancelNative(importer));
          throw const ImageImportFailure(ImageImportError.unreadable);
        },
      );
    } on ImageImportFailure {
      await _owner.janitor.discardStaging(id);
      rethrow;
    } on ImageImportCancelled {
      await _owner.janitor.discardStaging(id);
      rethrow;
    } on Object {
      await _owner.janitor.discardStaging(id);
      throw const ImageImportFailure(ImageImportError.unreadable);
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
    await _cancelNative(_owner.importer);
    await _owner.janitor.discardStaging(id);
  }

  /// Cancelar nunca deja el editor esperando: como mucho [cancelTimeout]; lo
  /// que quede en la preparación lo borra `discardStaging` o el barrido.
  Future<void> _cancelNative(ImageImporter importer) => importer
      .cancel(id)
      .timeout(cancelTimeout, onTimeout: () {})
      .catchError((Object _) {});

  static const cancelTimeout = Duration(seconds: 2);
}
