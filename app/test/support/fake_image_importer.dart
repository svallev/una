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

  /// Por foto del grupo (la clave es su `token`): fallo, tarde en copiar o
  /// cabecera distinta, para probar que cada una falla por separado.
  final copyErrorsByToken = <String, Object>{};
  final copyDelaysByToken = <String, Duration>{};
  final headsByToken = <String, List<int>>{};

  /// Cuánto tarda en terminar una llamada en curso **después** de cancelarla
  /// (el nativo no se puede interrumpir al instante).
  Duration cancelSettleDelay = Duration.zero;

  /// `token` de cada copia empezada, en orden.
  final copiedTokens = <String>[];

  /// Id de preparación de cada copia empezada, en orden (también con el
  /// selector múltiple, que no pasa por `picks`).
  final copiedIds = <String>[];

  /// Llamadas de copia o limpieza en curso a la vez (el máximo visto) y
  /// originales en la preparación a la vez (CA-016-04: nunca más de uno).
  var _active = 0;
  var maxActive = 0;
  final _originals = <String>{};
  var maxOriginals = 0;

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
    copiedTokens.add(picked.token);
    copiedIds.add(id);
    _enter();
    var ok = false;
    try {
      final photoHead = headsByToken[picked.token] ?? head;
      store.putStaging(id, 'original', Uint8List.fromList(photoHead));
      _originals.add(id);
      if (_originals.length > maxOriginals) maxOriginals = _originals.length;
      await _wait(id, copyDelaysByToken[picked.token] ?? copyDelay);
      if (copyErrorsByToken[picked.token] case final e?) throw e;
      if (copyError case final e?) throw e;
      ok = true;
      return (byteSize: photoHead.length, head: photoHead);
    } finally {
      if (!ok) _originals.remove(id);
      _leave();
    }
  }

  void _enter() {
    _active++;
    if (_active > maxActive) maxActive = _active;
  }

  void _leave() => _active--;

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
    _enter();
    try {
      await _wait(id, sanitizeDelay);
      if (sanitizeError case final e?) throw e;
      return stageImage(store, id, origin: origin);
    } finally {
      _originals.remove(id);
      _leave();
    }
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
      if (cancelSettleDelay == Duration.zero) {
        c.completeError(const ImageImportCancelled());
      } else {
        Timer(cancelSettleDelay, () {
          if (!c.isCompleted) c.completeError(const ImageImportCancelled());
        });
      }
    } else {
      // Sin llamada en curso no queda nada que escriba el original.
      _originals.remove(id);
    }
    await store.deleteStaging(id);
  }
}
