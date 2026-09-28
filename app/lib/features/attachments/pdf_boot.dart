import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/attachments/attachment_images.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/entities/task.dart';
import '../../domain/ports/attachment_store.dart';

/// Lo que el arranque en frío ya ha leído del PDF de la tarea actual, antes
/// del primer fotograma (CA-008-08): su última posición. La versión de
/// pantalla queda decodificada en la caché de imágenes, así que el primer
/// fotograma la pinta sin esperar a nada.
class PdfBootSeed {
  PdfBootSeed(this._attachmentId, this._position);

  /// Sin PDF en la tarea actual.
  PdfBootSeed.empty() : _attachmentId = null, _position = null;

  String? _attachmentId;
  PdfPosition? _position;

  /// La posición leída para [attachmentId], una sola vez: después (al volver
  /// a esa tarea) se lee del disco, que puede haber cambiado.
  PdfPosition? take(String attachmentId) {
    if (attachmentId != _attachmentId) return null;
    final position = _position;
    _attachmentId = null;
    _position = null;
    return position;
  }
}

/// Se sustituye en `main.dart` con lo leído en el arranque.
final pdfBootSeedProvider = Provider<PdfBootSeed>((ref) => PdfBootSeed.empty());

/// Si la tarea actual [task] tiene un PDF, lee su última posición y decodifica
/// su versión de pantalla (CA-008-08). Sin PDF no hace nada, así que no
/// retrasa el arranque de las demás tareas (CA-001-09). Nunca lanza.
Future<PdfBootSeed> readPdfBootSeed({
  required Task? task,
  required AttachmentStore store,
  required AttachmentImages images,
}) async {
  final attachment = task?.attachment;
  if (attachment == null || !attachment.isPdf) return PdfBootSeed.empty();
  PdfPosition? position;
  try {
    position = await store.readPosition(attachment.id);
  } on Object {
    position = null; // Ilegible: desde la primera página.
  }
  await _precache(images.stored(attachment.screenPath));
  return PdfBootSeed(attachment.id, position ?? PdfPosition.start);
}

/// Deja [provider] decodificada en la caché de imágenes. Si falla o tarda más
/// de un segundo, se sigue sin ella (se pinta en cuanto llegue).
Future<void> _precache(ImageProvider provider) async {
  final done = Completer<void>();
  void finish() {
    if (!done.isCompleted) done.complete();
  }

  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  try {
    await done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  } finally {
    stream.removeListener(listener);
  }
}
