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

/// Lo que el editor avisa tras importar un grupo (spec 016, CA-016-02, 05, 21):
/// se pasó del tope de 10, cuántas fotos se añadieron y cuántas se omitieron.
/// El texto compuesto lo da `importNoticeText`.
@immutable
class ImportNotice {
  const ImportNotice({
    required this.limited,
    required this.added,
    required this.failed,
  });

  /// El sistema devolvió más de [ImageLimits.maxGroup] y se usaron las
  /// primeras.
  final bool limited;

  /// Fotos que han quedado preparadas.
  final int added;

  /// Fotos omitidas (fallidas o que no llegaron a tiempo).
  final int failed;

  /// Hay algo más que "N fotos añadidas": un aviso visible (sin caducidad).
  bool get hasWarnings => limited || failed > 0;

  @override
  bool operator ==(Object other) =>
      other is ImportNotice &&
      other.limited == limited &&
      other.added == added &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(limited, added, failed);

  @override
  String toString() =>
      'ImportNotice(limited: $limited, added: $added, failed: $failed)';
}

/// Adjunto del editor (specs 007, 008 y 016):
/// - [staged]: lo preparado, listo para guardarse con la tarea: nada, una
///   imagen, un PDF o un grupo de 2 a 10 imágenes (en su orden);
/// - [preparing]: hay una importación en curso de tipo [preparingKind]; "+" y
///   "Continuar" no hacen nada (CA-007-15, CA-008-15);
/// - [preparingIndex] / [preparingTotal]: "Preparando foto {i} de {n}…" (con
///   `i` desde 1);
/// - [showPreparing]: "Preparando imagen…" / "Preparando PDF…" con "Cancelar",
///   solo si tarda más de 400 ms;
/// - [error]: el último fallo, un [ImageImportError] o un [PdfImportError]; el
///   editor queda como estaba;
/// - [notice]: el aviso del último grupo (sin caducidad hasta que cambie o se
///   quite el grupo, se guarde o se salga del editor).
@immutable
class AttachmentImportState {
  const AttachmentImportState({
    this.staged = const [],
    this.preparing = false,
    this.preparingKind,
    this.preparingIndex = 0,
    this.preparingTotal = 0,
    this.showPreparing = false,
    this.error,
    this.notice,
  });

  final List<StagedAttachment> staged;
  final bool preparing;
  final AttachmentKind? preparingKind;
  final int preparingIndex;
  final int preparingTotal;
  final bool showPreparing;
  final Enum? error;
  final ImportNotice? notice;

  /// La imagen preparada, si lo preparado es **una sola** imagen.
  StagedImage? get image => switch (staged) {
    [final StagedImage i] => i,
    _ => null,
  };

  /// El PDF preparado, si lo preparado es un PDF.
  StagedPdf? get pdf => switch (staged) {
    [final StagedPdf p] => p,
    _ => null,
  };
}

/// Cómo terminó [AttachmentImportController.pick] (el editor decide el foco y
/// el anuncio, CA-007-22, CA-008-21, CA-016-21).
enum ImportOutcome {
  /// Hay adjunto nuevo (si es un grupo, su aviso está en `state.notice`).
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

/// Lo que sale de una importación: lo preparado y, si es un grupo, su aviso.
typedef _Prepared = ({List<StagedAttachment> staged, ImportNotice? notice});

/// Lo común a una importación de imagen ([ImportJob]), de PDF
/// ([PdfImportJob]) o de un grupo de imágenes ([ImportGroup]).
abstract interface class _Job {
  AttachmentKind get kind;

  /// Cuántas fotos se preparan (1 salvo en un grupo).
  int get total;

  /// [replacedStagedIds]: lo preparado en el editor que este adjunto reemplaza
  /// (cuenta para el espacio libre de un grupo).
  Future<_Prepared> prepare({
    required void Function(int index, int total) onProgress,
    required Iterable<String> replacedStagedIds,
  });

  /// "Cancelar": se borra todo lo copiado.
  Future<void> cancel();

  /// El editor se cierra con la importación a medias.
  Future<void> dispose();
}

class _ImageJob implements _Job {
  _ImageJob(this.job);
  final ImportJob job;
  @override
  AttachmentKind get kind => AttachmentKind.image;
  @override
  int get total => 1;
  @override
  Future<_Prepared> prepare({
    required void Function(int, int) onProgress,
    required Iterable<String> replacedStagedIds,
  }) async => (staged: [await job.prepare()], notice: null);
  @override
  Future<void> cancel() => job.cancel();
  @override
  Future<void> dispose() => job.cancel();
}

class _PdfJob implements _Job {
  _PdfJob(this.job);
  final PdfImportJob job;
  @override
  AttachmentKind get kind => AttachmentKind.pdf;
  @override
  int get total => 1;
  @override
  Future<_Prepared> prepare({
    required void Function(int, int) onProgress,
    required Iterable<String> replacedStagedIds,
  }) async => (staged: [await job.prepare()], notice: null);
  @override
  Future<void> cancel() => job.cancel();
  @override
  Future<void> dispose() => job.cancel();
}

class _GroupJob implements _Job {
  _GroupJob(this.group, this.reservedBytes);
  final ImportGroup group;

  /// Lo que ya ocupa lo guardado que este grupo reemplaza (al editar).
  final int reservedBytes;
  @override
  AttachmentKind get kind => AttachmentKind.image;
  @override
  int get total => group.length;
  @override
  Future<_Prepared> prepare({
    required void Function(int, int) onProgress,
    required Iterable<String> replacedStagedIds,
  }) async {
    final result = await group.prepareAll(
      onProgress: onProgress,
      reservedBytes: reservedBytes,
      replacedStagedIds: replacedStagedIds,
    );
    return (
      staged: result.staged,
      notice: ImportNotice(
        limited: result.limited,
        added: result.staged.length,
        failed: result.failed.length,
      ),
    );
  }

  @override
  Future<void> cancel() => group.cancel();
  @override
  Future<void> dispose() => group.dispose();
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
  List<StagedAttachment> _staged = const [];

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
      if (job != null) unawaited(job.dispose());
      for (final s in staged) {
        unawaited(janitor.discardStaging(s.id));
      }
    });
    _staged = const [];
    return const AttachmentImportState();
  }

  /// El estado sin importación ni error: lo preparado y su aviso se conservan.
  AttachmentImportState _idle({Enum? error}) => AttachmentImportState(
    staged: state.staged,
    notice: state.notice,
    error: error,
  );

  /// Abre la cámara o el selector (de fotos o, con `file`, de PDF) e importa
  /// lo elegido, **de una en una**. Solo hay una importación a la vez:
  /// mientras tanto no hace nada. Si el usuario cancela en el sistema, todo
  /// sigue como estaba.
  Future<ImportOutcome> pick(AttachmentOrigin origin) => _run(() async {
    if (origin == AttachmentOrigin.file) {
      final job = await ref.read(importPdfProvider).pick();
      return job == null ? null : _PdfJob(job);
    }
    final job = await ref.read(importImageProvider).pick(origin);
    return job == null ? null : _ImageJob(job);
  });

  /// "Subir imágenes" (CA-016-02): abre el selector múltiple e importa hasta
  /// 10 fotos, una tras otra. [reservedBytes] es lo que ya ocupa lo **guardado**
  /// que el grupo reemplaza (al editar una tarea); lo preparado en el editor lo
  /// sabe el controlador. Lo nuevo reemplaza a lo anterior solo si al menos una
  /// foto sale bien; si se cancela o fallan todas, se conserva.
  Future<ImportOutcome> pickMany({int reservedBytes = 0}) => _run(() async {
    final group = await ref.read(importImageProvider).pickMany();
    return group == null ? null : _GroupJob(group, reservedBytes);
  });

  Future<ImportOutcome> _run(Future<_Job?> Function() open) async {
    if (_busy) return ImportOutcome.unchanged;
    _busy = true;
    final generation = ++_generation;
    state = _idle();
    try {
      final job = await open();
      if (!ref.mounted || generation != _generation) {
        // El editor se cerró (o se canceló) con el selector abierto.
        if (job != null) await job.dispose();
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
    } on Object {
      // Un fallo sin tipo, del selector o de la preparación (un canal que
      // contesta mal, una excepción de plataforma): "no se pudo leer", sin su
      // texto, que puede llevar una URI (CA-016-24, CL-016-16). `_prepare` lo
      // deja subir hasta aquí; los trabajos ya borran lo suyo al fallar.
      return _failed(ImageImportError.unreadable, generation);
    } finally {
      _busy = false;
    }
  }

  ImportOutcome _failed(Enum error, int generation) {
    if (!ref.mounted || generation != _generation) {
      return ImportOutcome.unchanged;
    }
    state = _idle(error: error);
    return ImportOutcome.failed;
  }

  AttachmentImportState _preparing(
    _Job job, {
    required int index,
    required int total,
    bool show = false,
  }) => AttachmentImportState(
    staged: state.staged,
    notice: state.notice,
    preparing: true,
    preparingKind: job.kind,
    preparingIndex: index,
    preparingTotal: total,
    showPreparing: show,
  );

  Future<ImportOutcome> _prepare(_Job job, int generation) async {
    _job = job;
    state = _preparing(job, index: 1, total: job.total);
    _indicator = Timer(UnaMotion.importIndicatorDelay, () {
      if (state.preparing) {
        state = _preparing(
          job,
          index: state.preparingIndex,
          total: state.preparingTotal,
          show: true,
        );
      }
    });
    try {
      final prepared = await job.prepare(
        onProgress: (index, total) {
          if (!ref.mounted || generation != _generation) return;
          state = _preparing(
            job,
            index: index,
            total: total,
            show: state.showPreparing,
          );
        },
        replacedStagedIds: [for (final s in state.staged) s.id],
      );
      if (!ref.mounted || generation != _generation) {
        for (final s in prepared.staged) {
          await _janitor.discardStaging(s.id);
        }
        return ImportOutcome.unchanged;
      }
      final previous = state.staged;
      state = AttachmentImportState(
        staged: prepared.staged,
        notice: prepared.notice,
      );
      // Lo sustituido (una imagen, un PDF o un grupo entero) no se borra hasta
      // que lo nuevo está listo; nunca se suman (CA-016-06).
      for (final s in previous) {
        await _janitor.discardStaging(s.id);
      }
      return ImportOutcome.added;
    } on ImageImportFailure catch (e) {
      return _failed(e.error, generation);
    } on PdfImportFailure catch (e) {
      return _failed(e.error, generation);
    } on ImageImportCancelled {
      if (ref.mounted && generation == _generation) state = _idle();
      return ImportOutcome.unchanged;
    } finally {
      _indicator?.cancel();
      if (identical(_job, job)) _job = null;
    }
  }

  /// "Cancelar" en "Preparando…" (CA-007-15, CA-008-15, CA-016-04): se borra
  /// todo lo copiado (el grupo entero) y el editor queda como estaba.
  Future<void> cancel() async {
    final job = _job;
    if (job == null) return;
    _generation++;
    _job = null;
    _indicator?.cancel();
    state = _idle();
    await job.cancel();
  }

  /// "Quitar adjunto": se borra todo lo preparado (el grupo entero).
  Future<void> remove() async {
    final staged = state.staged;
    if (staged.isEmpty) return;
    state = AttachmentImportState(
      preparing: state.preparing,
      preparingKind: state.preparingKind,
      preparingIndex: state.preparingIndex,
      preparingTotal: state.preparingTotal,
      showPreparing: state.showPreparing,
    );
    for (final s in staged) {
      await _janitor.discardStaging(s.id);
    }
  }

  /// `StagedPhotosLost` al guardar (CL-016-6b): el sistema vació la zona
  /// temporal. Quita de lo preparado las fotos perdidas [ids] (en su orden) y
  /// deja el aviso "No se pudo añadir…" con cuántas faltaban.
  Future<void> dropLost(Iterable<String> ids) async {
    final lost = ids.toSet();
    final kept = [
      for (final s in state.staged)
        if (!lost.contains(s.id)) s,
    ];
    final dropped = state.staged.length - kept.length;
    if (dropped == 0) return;
    state = AttachmentImportState(
      staged: kept,
      preparing: state.preparing,
      preparingKind: state.preparingKind,
      preparingIndex: state.preparingIndex,
      preparingTotal: state.preparingTotal,
      showPreparing: state.showPreparing,
      notice: ImportNotice(limited: false, added: 0, failed: dropped),
    );
    for (final id in lost) {
      await _janitor.discardStaging(id);
    }
  }

  /// La tarea se ha guardado con el adjunto: ya no es de este editor.
  void saved() => state = const AttachmentImportState();

  /// El aviso de error ya se ha mostrado.
  void clearError() {
    if (state.error == null) return;
    state = AttachmentImportState(
      staged: state.staged,
      notice: state.notice,
      preparing: state.preparing,
      preparingKind: state.preparingKind,
      preparingIndex: state.preparingIndex,
      preparingTotal: state.preparingTotal,
      showPreparing: state.showPreparing,
    );
  }
}
