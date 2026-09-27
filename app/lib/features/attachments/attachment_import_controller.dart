import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/ports/image_importer.dart';
import '../../domain/ports/pdf_importer.dart';
import '../../domain/services/attachment_janitor.dart';
import '../../domain/usecases/import_image.dart';
import '../../domain/usecases/import_pdf.dart';

/// Adjunto del editor (specs 007 y 008):
/// - [staged]: el preparado (imagen o PDF), listo para guardarse con la tarea;
/// - [preparing]: hay una importación en curso de tipo [preparingKind]; "+" y
///   "Continuar" no hacen nada (CA-007-15, CA-008-15);
/// - [showPreparing]: "Preparando imagen…" / "Preparando PDF…" con "Cancelar",
///   solo si tarda más de 400 ms;
/// - [error]: el último fallo, un [ImageImportError] o un [PdfImportError]; el
///   editor queda como estaba.
@immutable
class AttachmentImportState {
  const AttachmentImportState({
    this.staged,
    this.preparing = false,
    this.preparingKind,
    this.showPreparing = false,
    this.error,
  });

  final StagedAttachment? staged;
  final bool preparing;
  final AttachmentKind? preparingKind;
  final bool showPreparing;
  final Enum? error;

  /// La imagen preparada, si lo preparado es una imagen.
  StagedImage? get image => switch (staged) {
    final StagedImage i => i,
    _ => null,
  };

  /// El PDF preparado, si lo preparado es un PDF.
  StagedPdf? get pdf => switch (staged) {
    final StagedPdf p => p,
    _ => null,
  };
}

/// Cómo terminó [AttachmentImportController.pick] (el editor decide el foco y
/// el anuncio, CA-007-22, CA-008-21).
enum ImportOutcome {
  /// Hay adjunto nuevo.
  added,

  /// Canceló el sistema, "Cancelar", o ya había una en curso: nada cambia.
  unchanged,

  /// Error: está en `state.error`.
  failed,
}

/// Una por editor: al cerrarlo se cancela lo que esté en curso y se borra lo
/// preparado que no se haya guardado.
final attachmentImportProvider =
    NotifierProvider.autoDispose<
      AttachmentImportController,
      AttachmentImportState
    >(AttachmentImportController.new);

/// Lo común a una importación de imagen ([ImportJob]) o de PDF
/// ([PdfImportJob]).
abstract interface class _Job {
  AttachmentKind get kind;
  Future<StagedAttachment> prepare();
  Future<void> cancel();
}

class _ImageJob implements _Job {
  _ImageJob(this.job);
  final ImportJob job;
  @override
  AttachmentKind get kind => AttachmentKind.image;
  @override
  Future<StagedAttachment> prepare() => job.prepare();
  @override
  Future<void> cancel() => job.cancel();
}

class _PdfJob implements _Job {
  _PdfJob(this.job);
  final PdfImportJob job;
  @override
  AttachmentKind get kind => AttachmentKind.pdf;
  @override
  Future<StagedAttachment> prepare() => job.prepare();
  @override
  Future<void> cancel() => job.cancel();
}

class AttachmentImportController extends Notifier<AttachmentImportState> {
  /// Aumenta con cada importación: el resultado de una cancelada o sustituida
  /// se ignora.
  var _generation = 0;
  var _busy = false;
  _Job? _job;
  Timer? _indicator;
  late AttachmentJanitor _janitor;

  /// Copia de `state.staged`: al cerrar el editor ya no se puede leer `state`.
  StagedAttachment? _staged;

  @override
  set state(AttachmentImportState value) {
    _staged = value.staged;
    super.state = value;
  }

  @override
  AttachmentImportState build() {
    final janitor = _janitor = ref.read(attachmentJanitorProvider);
    ref.onDispose(() {
      _generation++;
      _indicator?.cancel();
      final job = _job;
      final staged = _staged;
      if (job != null) unawaited(job.cancel());
      if (staged != null) unawaited(janitor.discardStaging(staged.id));
    });
    _staged = null;
    return const AttachmentImportState();
  }

  Future<_Job?> _pick(AttachmentOrigin origin) async {
    if (origin == AttachmentOrigin.file) {
      final job = await ref.read(importPdfProvider).pick();
      return job == null ? null : _PdfJob(job);
    }
    final job = await ref.read(importImageProvider).pick(origin);
    return job == null ? null : _ImageJob(job);
  }

  /// Abre la cámara o el selector (de fotos o, con `file`, de PDF) e importa
  /// lo elegido. Solo hay una importación a la vez: mientras tanto no hace
  /// nada. Si el usuario cancela en el sistema, todo sigue como estaba.
  Future<ImportOutcome> pick(AttachmentOrigin origin) async {
    if (_busy) return ImportOutcome.unchanged;
    _busy = true;
    final generation = ++_generation;
    state = AttachmentImportState(staged: state.staged);
    try {
      final job = await _pick(origin);
      if (!ref.mounted || generation != _generation) {
        if (job != null) await job.cancel();
        return ImportOutcome.unchanged;
      }
      if (job == null) return ImportOutcome.unchanged;
      return await _prepare(job, generation);
    } on ImageImportFailure catch (e) {
      return _failed(e.error, generation);
    } on PdfImportFailure catch (e) {
      return _failed(e.error, generation);
    } on ImageImportCancelled {
      // El sistema lo canceló: como si no se hubiera elegido nada.
      return ImportOutcome.unchanged;
    } finally {
      _busy = false;
    }
  }

  ImportOutcome _failed(Enum error, int generation) {
    if (!ref.mounted || generation != _generation) {
      return ImportOutcome.unchanged;
    }
    state = AttachmentImportState(staged: state.staged, error: error);
    return ImportOutcome.failed;
  }

  Future<ImportOutcome> _prepare(_Job job, int generation) async {
    _job = job;
    state = AttachmentImportState(
      staged: state.staged,
      preparing: true,
      preparingKind: job.kind,
    );
    _indicator = Timer(UnaMotion.importIndicatorDelay, () {
      if (state.preparing) {
        state = AttachmentImportState(
          staged: state.staged,
          preparing: true,
          preparingKind: job.kind,
          showPreparing: true,
        );
      }
    });
    try {
      final staged = await job.prepare();
      if (!ref.mounted || generation != _generation) {
        await _janitor.discardStaging(staged.id);
        return ImportOutcome.unchanged;
      }
      final previous = state.staged;
      state = AttachmentImportState(staged: staged);
      // El sustituido no se borra hasta que el nuevo está listo.
      if (previous != null) await _janitor.discardStaging(previous.id);
      return ImportOutcome.added;
    } on ImageImportFailure catch (e) {
      return _failed(e.error, generation);
    } on PdfImportFailure catch (e) {
      return _failed(e.error, generation);
    } on ImageImportCancelled {
      if (ref.mounted && generation == _generation) {
        state = AttachmentImportState(staged: state.staged);
      }
      return ImportOutcome.unchanged;
    } finally {
      _indicator?.cancel();
      if (identical(_job, job)) _job = null;
    }
  }

  /// "Cancelar" en "Preparando…" (CA-007-15, CA-008-15): se borra lo copiado y
  /// el editor queda como estaba.
  Future<void> cancel() async {
    final job = _job;
    if (job == null) return;
    _generation++;
    _job = null;
    _indicator?.cancel();
    state = AttachmentImportState(staged: state.staged);
    await job.cancel();
  }

  /// "Quitar adjunto": se borra lo preparado.
  Future<void> remove() async {
    final staged = state.staged;
    if (staged == null) return;
    state = AttachmentImportState(
      preparing: state.preparing,
      preparingKind: state.preparingKind,
      showPreparing: state.showPreparing,
    );
    await _janitor.discardStaging(staged.id);
  }

  /// La tarea se ha guardado con el adjunto: ya no es de este editor.
  void saved() => state = const AttachmentImportState();

  /// El aviso de error ya se ha mostrado.
  void clearError() {
    if (state.error == null) return;
    state = AttachmentImportState(
      staged: state.staged,
      preparing: state.preparing,
      preparingKind: state.preparingKind,
      showPreparing: state.showPreparing,
    );
  }
}
