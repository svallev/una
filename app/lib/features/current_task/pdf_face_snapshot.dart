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
class PdfFaceSnapshotController
    extends FaceSnapshotController<PdfFaceSnapshot> {
  @override
  ui.Image imageOf(PdfFaceSnapshot snapshot) => snapshot.image;

  void capture(String attachmentId, ui.Image image) =>
      hold(PdfFaceSnapshot(attachmentId, image));
}

/// Lo común de las capturas de la cara de la tarea (PDF y fotos): guarda como
/// mucho una, solo mientras se completa o se elimina, y la libera (también su
/// [ui.Image]) cuando termina.
abstract class FaceSnapshotController<S extends Object> extends Notifier<S?> {
  /// La que hay que liberar (igual que el estado; se lee también al
  /// desechar el proveedor, cuando ya no se puede leer el estado).
  S? _held;

  /// La imagen que hay que liberar de [snapshot].
  ui.Image imageOf(S snapshot);

  @override
  S? build() {
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

  @protected
  void hold(S snapshot) {
    _dispose(_held);
    state = _held = snapshot;
  }

  void _release() {
    final old = _held;
    if (old == null) return;
    state = _held = null;
    _dispose(old);
  }

  /// Tras el fotograma: la cara que la pintaba ya no está.
  void _dispose(S? snapshot) {
    if (snapshot == null) return;
    final image = imageOf(snapshot);
    SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
  }
}

/// Imagen de lo que se ve dentro de [boundary] (un `RepaintBoundary`), o null
/// si aún no se ha dibujado (p. ej., justo a medias de dibujar): la cara usa
/// entonces su alternativa sin imagen.
ui.Image? captureBoundary(BuildContext context, GlobalKey boundary) {
  final render = boundary.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary || !render.hasSize) return null;
  try {
    return render.toImageSync(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  } on Object {
    return null;
  }
}

/// Llama a [onBusy] cuando la tarea [taskId] empieza a completarse o a
/// eliminarse (antes de guardar: sus archivos aún están). Se llama desde
/// `build`.
void listenTaskLeaving(WidgetRef ref, String taskId, VoidCallback onBusy) {
  void onChange(bool? was, bool now) {
    if (now && was != true) onBusy();
  }

  ref
    ..listen(
      completionProvider.select((c) => c.busy && c.task?.id == taskId),
      onChange,
    )
    ..listen(
      deletionProvider.select((d) => d.busy && d.task?.id == taskId),
      onChange,
    );
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
    // Sin imagen, la cara usa la versión de pantalla guardada.
    final image = captureBoundary(context, _boundary);
    if (image == null) return;
    ref
        .read(pdfFaceSnapshotProvider.notifier)
        .capture(widget.attachmentId, image);
  }

  @override
  Widget build(BuildContext context) {
    listenTaskLeaving(ref, widget.taskId, _capture);
    return RepaintBoundary(key: _boundary, child: widget.child);
  }
}
