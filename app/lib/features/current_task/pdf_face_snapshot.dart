import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../complete/completion_controller.dart';
import '../delete/deletion_controller.dart';

/// Imagen fija de lo que se veía del PDF (página visible, banda del texto y
/// zoom) al empezar a completar o eliminar la tarea: es la cara de la rotura
/// y del arrugado (CA-008-19, CL-003-4). Sus archivos ya se han borrado
/// (ADR-0012) y la versión de pantalla guardada puede ser de otra página.
@immutable
class PdfFaceSnapshot {
  const PdfFaceSnapshot(this.attachmentId, this.image);

  final String attachmentId;
  final ui.Image image;
}

final pdfFaceSnapshotProvider =
    NotifierProvider<PdfFaceSnapshotController, PdfFaceSnapshot?>(
      PdfFaceSnapshotController.new,
    );

/// Guarda como mucho una imagen, solo mientras se completa o se elimina.
class PdfFaceSnapshotController extends Notifier<PdfFaceSnapshot?> {
  /// La que hay que liberar (igual que el estado; se lee también al
  /// desechar el proveedor, cuando ya no se puede leer el estado).
  PdfFaceSnapshot? _held;

  @override
  PdfFaceSnapshot? build() {
    // Al terminar la animación ya no hace falta: se libera.
    void releaseWhenIdle(bool? _, bool busy) {
      if (!busy &&
          !ref.read(completionProvider).busy &&
          !ref.read(deletionProvider).busy) {
        _release();
      }
    }

    ref
      ..listen(completionProvider.select((c) => c.busy), releaseWhenIdle)
      ..listen(deletionProvider.select((d) => d.busy), releaseWhenIdle)
      ..onDispose(() => _dispose(_held));
    return null;
  }

  void capture(String attachmentId, ui.Image image) {
    _dispose(_held);
    state = _held = PdfFaceSnapshot(attachmentId, image);
  }

  void _release() {
    final old = _held;
    if (old == null) return;
    state = _held = null;
    _dispose(old);
  }

  /// Tras el fotograma: la cara que la pintaba ya no está.
  static void _dispose(PdfFaceSnapshot? snapshot) {
    if (snapshot == null) return;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => snapshot.image.dispose(),
    );
  }
}

/// Envuelve las páginas del PDF de la tarea actual y, cuando esa tarea
/// empieza a completarse o eliminarse, guarda en [pdfFaceSnapshotProvider]
/// una imagen de lo que se ve.
class PdfFaceCapture extends ConsumerStatefulWidget {
  const PdfFaceCapture({
    super.key,
    required this.taskId,
    required this.attachmentId,
    required this.child,
  });

  final String taskId;
  final String attachmentId;
  final Widget child;

  @override
  ConsumerState<PdfFaceCapture> createState() => _PdfFaceCaptureState();
}

class _PdfFaceCaptureState extends ConsumerState<PdfFaceCapture> {
  final _boundary = GlobalKey();

  void _capture() {
    final render = _boundary.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary || !render.hasSize) return;
    try {
      final image = render.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      ref
          .read(pdfFaceSnapshotProvider.notifier)
          .capture(widget.attachmentId, image);
    } on Object {
      // Sin imagen (p. ej., justo a medio dibujar): la cara usa la versión de
      // pantalla guardada.
    }
  }

  @override
  Widget build(BuildContext context) {
    void onBusy(bool? was, bool now) {
      if (now && was != true) _capture();
    }

    ref
      ..listen(
        completionProvider.select((c) => c.busy && c.task?.id == widget.taskId),
        onBusy,
      )
      ..listen(
        deletionProvider.select((d) => d.busy && d.task?.id == widget.taskId),
        onBusy,
      );
    return RepaintBoundary(key: _boundary, child: widget.child);
  }
}
