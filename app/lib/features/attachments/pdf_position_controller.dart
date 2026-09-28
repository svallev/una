import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/attachment_store.dart';
import '../../domain/ports/pdf_importer.dart';
import 'pdf_boot.dart';

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
    // En frío, la ha leído el arranque: el primer fotograma ya la tiene
    // (CA-008-08).
    final boot = ref.read(pdfBootSeedProvider).take(attachmentId);
    if (boot != null) return PdfPositionState(position: boot, loaded: true);
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

/// El borde que dibuja el visor entre páginas (3 dp de tinta), en píxeles
/// físicos, para la versión de pantalla (CA-008-08).
PageGap pdfPageGap(double devicePixelRatio) => (
  px: (UnaBorders.strongWidth * devicePixelRatio).round(),
  argb: UnaColors.ink.toARGB32(),
);

/// [pdfPageGap] con la densidad de la pantalla, fuera de un widget.
PageGap pdfPageGapOfScreen() {
  final views = PlatformDispatcher.instance.views;
  return pdfPageGap(views.isEmpty ? 1 : views.first.devicePixelRatio);
}

/// Guarda la última posición de [attachment] (CA-008-09) y, si no es la de la
/// versión de pantalla que hay en el disco ([shown]), la vuelve a dibujar
/// desde esa posición: el próximo arranque la pinta en el primer fotograma
/// tal cual se veía (CA-008-08). Al redibujarla, saca [screen] (su imagen) de
/// la caché: al volver a la tarea no se pinta la vieja. Nunca lanza: si falla,
/// se empieza por donde se pueda.
Future<void> persistPdfPosition({
  required AttachmentStore store,
  required PdfImporter importer,
  required Attachment attachment,
  required PdfPosition position,
  required PdfPosition shown,
  PageGap gap = noPageGap,
  ImageProvider? screen,
}) async {
  try {
    await store.writePosition(attachment.id, position);
    if (position != shown) {
      await importer.renderScreen(attachment, position, gap: gap);
      await screen?.evict();
    }
  } on Object {
    // Sin registro (CL-008-11).
  }
}
