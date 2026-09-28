import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/image_importer.dart'
    show CopiedImage, ImageImportCancelled;
import '../../domain/ports/pdf_importer.dart';
import '../attachments/memory_attachment_store.dart';
import 'pdf_engine.dart';

/// Un archivo elegido que aún no se ha leído: su nombre visible (sin sanear),
/// su tamaño declarado y cómo leerlo.
typedef PickedBytes = ({
  String? name,
  int size,
  Future<Uint8List> Function() read,
});

/// Importador de PDF en memoria (CL-008-12, ADR-0010): la base de la web de
/// pruebas (`WebPdfImporter`), que pone el selector del navegador y el JPEG del
/// `canvas`. Igual que en Android: el tamaño se comprueba antes y después de
/// leer, el tipo lo decide `ImportPdf` por el contenido y PDFium lo abre sin
/// contraseña; todo queda en [store], como las tareas. No registra nada
/// (CL-008-11).
class MemoryPdfImporter implements PdfImporter {
  MemoryPdfImporter(
    this.store, {
    required this.pickFile,
    required this.encodeJpeg,
    required this.screenWidthPx,
  });

  final MemoryAttachmentStore store;

  /// Abre el selector, solo PDF; null si se cancela.
  final Future<PickedBytes?> Function() pickFile;

  /// Codifica una página dibujada a JPEG, sin metadatos.
  final Future<Uint8List> Function(RenderedPage page) encodeJpeg;

  /// Ancho de la pantalla en vertical, en píxeles físicos (I-2).
  final int Function() screenWidthPx;

  static const _source = 'source';
  static const _document = 'document.pdf';
  static const _screen = 'screen.jpg';

  final _files = <String, PickedBytes>{};
  final _cancelled = <String>{};
  var _nextToken = 0;

  @override
  Future<PickedPdf?> pick(String id) async {
    final file = await pickFile();
    if (file == null) return null;
    final token = 'memory:${_nextToken++}';
    _files[token] = file;
    return (token: token, name: file.name);
  }

  @override
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) async {
    final file = _files.remove(picked.token);
    if (file == null) throw const PdfImportFailure(PdfImportError.unreadable);
    // Sin leerlo si ya se sabe que es demasiado grande (CA-008-14).
    if (file.size > maxBytes) {
      throw const PdfImportFailure(PdfImportError.tooLarge);
    }
    final Uint8List bytes;
    try {
      bytes = await file.read();
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
    _checkCancelled(id);
    if (bytes.length > maxBytes) {
      throw const PdfImportFailure(PdfImportError.tooLarge);
    }
    store.putStaging(id, _source, bytes);
    return (
      byteSize: bytes.length,
      head: bytes.sublist(0, math.min(bytes.length, headBytes)),
    );
  }

  @override
  Future<PdfInfo> inspect(String id, {required int maxPages}) async {
    final bytes = store.stagingBytes(id, _source);
    if (bytes == null) throw const PdfImportFailure(PdfImportError.unreadable);
    final (info, page) = await PdfEngine.inspect(
      PdfEngine.data(bytes),
      maxPages: maxPages,
      renderWidth: screenWidthPx(),
    );
    _checkCancelled(id);
    final jpeg = await _encode(page);
    _checkCancelled(id);
    store
      ..removeStaging(id, _source)
      ..putStaging(id, _document, bytes)
      ..putStaging(id, _screen, jpeg);
    return info;
  }

  @override
  Future<void> renderScreen(Attachment attachment, PdfPosition position) async {
    final bytes = store.bytes(attachment.documentPath);
    if (bytes == null) return;
    final page = await PdfEngine.renderPage(
      PdfEngine.data(bytes),
      position.clampTo(attachment.pageCount ?? 1).page,
      width: screenWidthPx(),
    );
    final jpeg = await _encode(page);
    // Si se ha borrado mientras tanto, no se resucita.
    if (store.bytes(attachment.documentPath) == null) return;
    store.putStored(attachment.id, _screen, jpeg);
  }

  @override
  Future<void> cancel(String id) async {
    _cancelled.add(id);
    await store.deleteStaging(id);
  }

  void _checkCancelled(String id) {
    if (_cancelled.remove(id)) {
      store.removeStaging(id, _source);
      throw const ImageImportCancelled();
    }
  }

  Future<Uint8List> _encode(RenderedPage page) async {
    try {
      return await encodeJpeg(page);
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
  }
}
