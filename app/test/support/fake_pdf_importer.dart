import 'dart:async';
import 'dart:typed_data';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/ports/image_importer.dart'
    show CopiedImage, ImageImportCancelled;
import 'package:app/domain/ports/pdf_importer.dart';

import 'attachments.dart';

/// Cabecera de un PDF.
final pdfHead = '%PDF-1.7\n'.codeUnits;

/// Importador de PDF falso: escribe en la preparación como el real y se puede
/// retrasar, hacer fallar o cancelar paso a paso.
class FakePdfImporter implements PdfImporter {
  FakePdfImporter(this.store);

  final MemoryAttachmentStore store;

  bool userCancelsPicker = false;
  String? pickedName = 'Programa.pdf';
  List<int> head = pdfHead;
  int byteSize = 2400000;
  PdfInfo info = (pageCount: 3, width: 595, height: 842);
  Object? copyError;
  Object? inspectError;
  Duration copyDelay = Duration.zero;
  Duration inspectDelay = Duration.zero;

  final picks = <String>[];
  final copyLimits = <({int maxBytes, int headBytes})>[];
  final pageLimits = <int>[];
  final cancelled = <String>[];
  final rendered = <(String, PdfPosition)>[];
  final _waits = <String, Completer<void>>{};

  Future<void> _wait(String id, Duration d) async {
    if (d == Duration.zero) return;
    final c = Completer<void>();
    _waits[id] = c;
    final t = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    try {
      await c.future;
    } finally {
      t.cancel();
      _waits.remove(id);
    }
  }

  @override
  Future<PickedPdf?> pick(String id) async {
    picks.add(id);
    if (userCancelsPicker) return null;
    return (token: 'content://$id', name: pickedName);
  }

  @override
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) async {
    copyLimits.add((maxBytes: maxBytes, headBytes: headBytes));
    store.putStaging(id, 'source', Uint8List.fromList(head));
    await _wait(id, copyDelay);
    if (copyError case final e?) throw e;
    return (byteSize: byteSize, head: head);
  }

  @override
  Future<PdfInfo> inspect(String id, {required int maxPages}) async {
    pageLimits.add(maxPages);
    await _wait(id, inspectDelay);
    if (inspectError case final e?) throw e;
    store
      ..removeStaging(id, 'source')
      ..putStaging(id, 'document.pdf', Uint8List.fromList(head))
      ..putStaging(id, 'screen.jpg', tinyImage);
    return info;
  }

  @override
  Future<void> renderScreen(Attachment attachment, PdfPosition position) async {
    // Como el real: si el PDF ya no existe, no hace nada.
    if (store.bytes(attachment.documentPath) == null) return;
    rendered.add((attachment.id, position));
    store.putStored(attachment.id, 'screen.jpg', tinyImage);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    final c = _waits[id];
    if (c != null && !c.isCompleted) {
      c.completeError(const ImageImportCancelled());
    }
    await store.deleteStaging(id);
  }
}
