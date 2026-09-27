import 'dart:async';

import '../entities/staged_attachment.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart' show ImageImportCancelled;
import '../ports/pdf_importer.dart';
import '../services/attachment_janitor.dart';
import '../services/file_name.dart';
import '../services/pdf_sniffer.dart';

/// Importa un PDF (spec 008) en dos pasos, como `ImportImage`: [pick] abre el
/// selector y, si el usuario elige algo, devuelve un [PdfImportJob] que lo
/// copia y lo comprueba. La preparación queda protegida del barrido hasta que
/// la tarea se guarda o se descarta (CA-008-16).
class ImportPdf {
  ImportPdf({
    required this.importer,
    required this.janitor,
    required this.ids,
    this.timeout = PdfLimits.timeout,
  });

  final PdfImporter importer;
  final AttachmentJanitor janitor;
  final IdGenerator ids;
  final Duration timeout;

  /// Devuelve null si el usuario cancela el selector.
  Future<PdfImportJob?> pick() async {
    final id = ids.newId();
    janitor.registry.add(id);
    try {
      final picked = await importer.pick(id);
      if (picked == null) {
        await janitor.discardStaging(id);
        return null;
      }
      return PdfImportJob._(this, id, picked);
    } on Object {
      await janitor.discardStaging(id);
      rethrow;
    }
  }
}

/// Un PDF elegido que se está preparando.
class PdfImportJob {
  PdfImportJob._(this._owner, this.id, this.picked);

  final ImportPdf _owner;
  final String id;
  final PickedPdf picked;
  var _cancelled = false;

  /// Copia (10 MB), decide el tipo **por el contenido**, lo abre sin
  /// contraseña y cuenta sus páginas (20), en 20 s como máximo (CA-008-02/03/
  /// 14). Si falla o se cancela, no queda nada: lanza [PdfImportFailure] o
  /// [ImageImportCancelled]. Cualquier otro error cuenta como ilegible.
  Future<StagedPdf> prepare() async {
    final importer = _owner.importer;
    try {
      return await _run(importer).timeout(
        _owner.timeout,
        onTimeout: () async {
          _cancelled = true;
          unawaited(_cancelNative(importer));
          throw const PdfImportFailure(PdfImportError.unreadable);
        },
      );
    } on Object catch (e) {
      await _owner.janitor.discardStaging(id);
      if (e is PdfImportFailure || e is ImageImportCancelled) rethrow;
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
  }

  Future<StagedPdf> _run(PdfImporter importer) async {
    final copied = await importer.copy(
      picked,
      id,
      maxBytes: PdfLimits.maxBytes,
      headBytes: PdfLimits.headBytes,
    );
    _checkCancelled();
    if (!isPdf(copied.head)) {
      throw const PdfImportFailure(PdfImportError.notPdf);
    }
    final info = await importer.inspect(id, maxPages: PdfLimits.maxPages);
    _checkCancelled();
    return StagedPdf(
      id: id,
      byteSize: copied.byteSize,
      pageCount: info.pageCount,
      width: info.width,
      height: info.height,
      originalName: sanitizeFileName(picked.name),
    );
  }

  void _checkCancelled() {
    if (_cancelled) throw const ImageImportCancelled();
  }

  /// Cancela la preparación y la borra (CA-008-15).
  Future<void> cancel() async {
    _cancelled = true;
    await _cancelNative(_owner.importer);
    await _owner.janitor.discardStaging(id);
  }

  Future<void> _cancelNative(PdfImporter importer) => importer
      .cancel(id)
      .timeout(cancelTimeout, onTimeout: () {})
      .catchError((Object _) {});

  static const cancelTimeout = Duration(seconds: 2);
}
