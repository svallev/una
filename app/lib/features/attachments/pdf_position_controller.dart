import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/attachment_store.dart';
import '../../domain/ports/pdf_importer.dart';

/// Última posición de un PDF (CA-008-09): [position] es null hasta que se lee
/// del disco ([loaded]); sin archivo, el principio.
@immutable
class PdfPositionState {
  const PdfPositionState({this.position, this.loaded = false});

  final PdfPosition? position;
  final bool loaded;
}

/// Una por PDF que se ve (clave: el id del adjunto). Lee la posición guardada
/// y recuerda la que se ve ahora.
final pdfPositionProvider = NotifierProvider.autoDispose
    .family<PdfPositionController, PdfPositionState, String>(
      PdfPositionController.new,
    );

class PdfPositionController extends Notifier<PdfPositionState> {
  PdfPositionController(this.attachmentId);

  final String attachmentId;

  @override
  PdfPositionState build() {
    unawaited(_load());
    return const PdfPositionState();
  }

  Future<void> _load() async {
    PdfPosition? saved;
    try {
      saved = await ref
          .read(attachmentStoreProvider)
          .readPosition(attachmentId);
    } on Object {
      saved = null; // Ilegible: se empieza por la primera página.
    }
    if (!ref.mounted || state.loaded) return;
    state = PdfPositionState(
      position: saved ?? PdfPosition.start,
      loaded: true,
    );
  }

  /// La posición visible ha cambiado (aún no se guarda en el disco).
  void update(PdfPosition position) {
    if (position == state.position) return;
    state = PdfPositionState(position: position, loaded: true);
  }
}

/// Guarda la última posición de [attachment] (CA-008-09) y, si cambia de
/// página respecto a [shownPage], vuelve a dibujar la versión de pantalla con
/// esa página: el próximo arranque la pinta en el primer fotograma (CA-008-08).
/// Nunca lanza: si falla, se empieza por donde se pueda.
Future<void> persistPdfPosition({
  required AttachmentStore store,
  required PdfImporter importer,
  required Attachment attachment,
  required PdfPosition position,
  required int shownPage,
}) async {
  try {
    await store.writePosition(attachment.id, position);
    if (position.page != shownPage) {
      await importer.renderScreen(attachment, position);
    }
  } on Object {
    // Sin registro (CL-008-11).
  }
}
