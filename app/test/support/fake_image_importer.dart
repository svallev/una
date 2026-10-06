import 'dart:async';
import 'dart:typed_data';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/image_importer.dart';

import 'attachments.dart';

/// Cabecera de un JPEG.
const jpegHead = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

/// Importador falso: escribe en la preparación como el nativo y se puede
/// retrasar, hacer fallar o cancelar paso a paso.
class FakeImageImporter implements ImageImporter {
  FakeImageImporter(this.store);

  final MemoryAttachmentStore store;

  @override
  bool heicSupported = true;

  bool userCancelsPicker = false;
  Object? pickError;
  List<int> head = jpegHead;
  Object? copyError;
  Object? sanitizeError;

  /// Lo que tarda el usuario en la cámara o el selector del sistema.
  Duration pickDelay = Duration.zero;
  Duration copyDelay = Duration.zero;
  Duration sanitizeDelay = Duration.zero;

  /// Lo que devuelve el selector múltiple: [manyTotal] elegidas (el falso
  /// entrega como mucho `max`, como el sistema tras el tope).
  int manyTotal = 3;
  final pickManyMax = <int>[];

  /// Bytes libres; null = desconocido.
  int? freeSpaceBytes;
  Object? freeSpaceError;

  final picks = <String>[];
  final origins = <AttachmentOrigin>[];
  final limits = <int>[];
  final cancelled = <String>[];
  final sniffedTypes = <ImageType>[];
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
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async {
    picks.add(id);
    origins.add(origin);
    if (pickDelay > Duration.zero) await Future<void>.delayed(pickDelay);
    if (pickError case final e?) throw e;
    if (userCancelsPicker) return null;
    return (token: 'content://$id', origin: origin);
  }

  @override
  Future<PickedImages?> pickMany({required int max}) async {
    pickManyMax.add(max);
    if (pickDelay > Duration.zero) await Future<void>.delayed(pickDelay);
    if (pickError case final e?) throw e;
    if (userCancelsPicker) return null;
    final count = manyTotal < max ? manyTotal : max;
    return (
      items: [
        for (var i = 0; i < count; i++)
          (token: 'content://many-$i', origin: AttachmentOrigin.gallery),
      ],
      total: manyTotal,
    );
  }

  @override
  Future<int?> freeSpace() async {
    if (freeSpaceError case final e?) throw e;
    return freeSpaceBytes;
  }

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) async {
    limits.add(maxBytes);
    store.putStaging(id, 'original', Uint8List.fromList(head));
    await _wait(id, copyDelay);
    if (copyError case final e?) throw e;
    return (byteSize: head.length, head: head);
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) async {
    limits
      ..add(maxPixels)
      ..add(storedMaxPixels);
    sniffedTypes.add(type);
    await _wait(id, sanitizeDelay);
    if (sanitizeError case final e?) throw e;
    return stageImage(store, id, origin: origin);
  }

  /// Adjuntos cuyas derivadas se han regenerado.
  final regenerated = <String>[];

  /// Si no es null, regenerar falla con este error.
  Object? regenerateError;

  @override
  Future<void> regenerateDerived(Attachment attachment) async {
    regenerated.add(attachment.id);
    if (regenerateError case final e?) throw e;
    if (await store.check(attachment) == AttachmentFiles.missing) {
      throw const ImageImportFailure(ImageImportError.unreadable);
    }
    store
      ..putStored(attachment.id, 'screen.jpg', tinyImage)
      ..putStored(attachment.id, 'thumb.jpg', tinyImage);
  }

  /// Simula un proveedor colgado: cancelar no responde nunca (M1 de la
  /// revisión de seguridad de T-007-25).
  bool cancelHangs = false;

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    if (cancelHangs) return Completer<void>().future;
    final c = _waits[id];
    if (c != null && !c.isCompleted) {
      c.completeError(const ImageImportCancelled());
    }
    await store.deleteStaging(id);
  }
}
