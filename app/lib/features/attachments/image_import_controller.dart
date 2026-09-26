import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/ports/image_importer.dart';
import '../../domain/usecases/import_image.dart';

/// Imagen del editor (spec 007):
/// - [image]: la preparada, lista para guardarse con la tarea;
/// - [preparing]: hay una importación en curso; "+" y "Continuar" no hacen
///   nada (CA-007-15);
/// - [showPreparing]: "Preparando imagen…" con "Cancelar", solo si tarda más
///   de 400 ms;
/// - [error]: el último fallo; el editor queda como estaba (CA-007-13).
@immutable
class ImageImportState {
  const ImageImportState({
    this.image,
    this.preparing = false,
    this.showPreparing = false,
    this.error,
  });

  final StagedImage? image;
  final bool preparing;
  final bool showPreparing;
  final ImageImportError? error;
}

/// Una por editor: al cerrarlo se cancela lo que esté en curso y se borra la
/// imagen preparada que no se haya guardado.
final imageImportProvider =
    NotifierProvider.autoDispose<ImageImportController, ImageImportState>(
      ImageImportController.new,
    );

class ImageImportController extends Notifier<ImageImportState> {
  /// Aumenta con cada importación: el resultado de una cancelada o sustituida
  /// se ignora.
  var _generation = 0;
  var _busy = false;
  ImportJob? _job;
  Timer? _indicator;

  /// Copia de `state.image`: al cerrar el editor ya no se puede leer `state`.
  StagedImage? _image;

  @override
  set state(ImageImportState value) {
    _image = value.image;
    super.state = value;
  }

  @override
  ImageImportState build() {
    final janitor = ref.read(attachmentJanitorProvider);
    ref.onDispose(() {
      _generation++;
      _indicator?.cancel();
      final job = _job;
      final image = _image;
      if (job != null) unawaited(job.cancel());
      if (image != null) unawaited(janitor.discardStaging(image.id));
    });
    _image = null;
    return const ImageImportState();
  }

  ImportImage get _importImage => ref.read(importImageProvider);

  /// Abre la cámara o el selector e importa lo elegido. Solo hay una
  /// importación a la vez: mientras tanto no hace nada. Si el usuario cancela
  /// en el sistema, todo sigue como estaba.
  Future<void> pick(AttachmentOrigin origin) async {
    if (_busy) return;
    _busy = true;
    final generation = ++_generation;
    state = ImageImportState(image: state.image);
    try {
      final job = await _importImage.pick(origin);
      if (!ref.mounted || generation != _generation) {
        if (job != null) await job.cancel();
        return;
      }
      if (job == null) return;
      await _prepare(job, generation);
    } on ImageImportFailure catch (e) {
      if (ref.mounted && generation == _generation) _fail(e.error);
    } on ImageImportCancelled {
      // El sistema lo canceló: como si no se hubiera elegido nada.
    } finally {
      _busy = false;
    }
  }

  Future<void> _prepare(ImportJob job, int generation) async {
    _job = job;
    state = ImageImportState(image: state.image, preparing: true);
    _indicator = Timer(UnaMotion.importIndicatorDelay, () {
      if (state.preparing) {
        state = ImageImportState(
          image: state.image,
          preparing: true,
          showPreparing: true,
        );
      }
    });
    try {
      final staged = await job.prepare();
      if (!ref.mounted || generation != _generation) {
        await ref.read(attachmentJanitorProvider).discardStaging(staged.id);
        return;
      }
      final previous = state.image;
      state = ImageImportState(image: staged);
      // La sustituida no se borra hasta que la nueva está lista.
      if (previous != null) {
        await ref.read(attachmentJanitorProvider).discardStaging(previous.id);
      }
    } on ImageImportFailure catch (e) {
      if (ref.mounted && generation == _generation) _fail(e.error);
    } on ImageImportCancelled {
      if (ref.mounted && generation == _generation) {
        state = ImageImportState(image: state.image);
      }
    } finally {
      _indicator?.cancel();
      if (identical(_job, job)) _job = null;
    }
  }

  void _fail(ImageImportError error) =>
      state = ImageImportState(image: state.image, error: error);

  /// "Cancelar" en "Preparando imagen…" (CA-007-15): se borra lo copiado y el
  /// editor queda como estaba.
  Future<void> cancel() async {
    final job = _job;
    if (job == null) return;
    _generation++;
    _job = null;
    _indicator?.cancel();
    state = ImageImportState(image: state.image);
    await job.cancel();
  }

  /// "Quitar adjunto": se borra la imagen preparada.
  Future<void> remove() async {
    final image = state.image;
    if (image == null) return;
    state = ImageImportState(
      preparing: state.preparing,
      showPreparing: state.showPreparing,
    );
    await ref.read(attachmentJanitorProvider).discardStaging(image.id);
  }

  /// La tarea se ha guardado con la imagen: ya no es de este editor.
  void saved() => state = const ImageImportState();

  /// El aviso de error ya se ha mostrado.
  void clearError() {
    if (state.error == null) return;
    state = ImageImportState(
      image: state.image,
      preparing: state.preparing,
      showPreparing: state.showPreparing,
    );
  }
}
