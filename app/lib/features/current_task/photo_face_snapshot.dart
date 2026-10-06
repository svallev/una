import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/full_width.dart';
import 'pdf_face_snapshot.dart';
import 'photo_group.dart';

/// Lo que se veía de la tarea con un grupo de fotos al empezar a completarla o
/// eliminarla (spec 016, CA-016-13, CL-016-12): la foto que estaba a la vista
/// con su desplazamiento (una imagen en memoria), cuál era (para los puntos) y
/// si se veía en horizontal (sin pie ni puntos). Es la cara de la rotura y del
/// arrugado: sus archivos ya se han borrado (ADR-0012) y la cara **nunca** los
/// lee, ni del disco ni de la caché de imágenes.
@immutable
class PhotoFaceSnapshot {
  const PhotoFaceSnapshot({
    required this.taskId,
    required this.image,
    required this.index,
    required this.landscape,
  });

  final String taskId;
  final ui.Image image;

  /// Posición de la foto que se veía (0 es la primera).
  final int index;

  final bool landscape;
}

final photoFaceSnapshotProvider =
    NotifierProvider<PhotoFaceSnapshotController, PhotoFaceSnapshot?>(
      PhotoFaceSnapshotController.new,
    );

/// Guarda como mucho una captura, solo mientras se completa o se elimina; se
/// libera al terminar.
class PhotoFaceSnapshotController
    extends FaceSnapshotController<PhotoFaceSnapshot> {
  @override
  ui.Image imageOf(PhotoFaceSnapshot snapshot) => snapshot.image;

  void capture(PhotoFaceSnapshot snapshot) => hold(snapshot);
}

/// Envuelve la capa de las fotos de la tarea actual y, cuando esa tarea empieza
/// a completarse o eliminarse, guarda en [photoFaceSnapshotProvider] una imagen
/// de lo que se ve. Se toma **antes** de guardar y de descartar los archivos
/// (`CompleteCurrentTask`, `DeleteCurrentTask`): sus archivos aún están.
class PhotoFaceCapture extends ConsumerStatefulWidget {
  const PhotoFaceCapture({
    super.key,
    required this.taskId,
    required this.host,
    required this.landscape,
    required this.child,
  });

  final String taskId;
  final PhotoGroupHost host;
  final bool landscape;
  final Widget child;

  @override
  ConsumerState<PhotoFaceCapture> createState() => _PhotoFaceCaptureState();
}

class _PhotoFaceCaptureState extends ConsumerState<PhotoFaceCapture> {
  final _boundary = GlobalKey();

  void _capture() {
    // Sin imagen (p. ej., a medias de dibujar), la cara es estática: el color
    // de la nota y el pie.
    final image = captureBoundary(context, _boundary);
    if (image == null) return;
    ref
        .read(photoFaceSnapshotProvider.notifier)
        .capture(
          PhotoFaceSnapshot(
            taskId: widget.taskId,
            image: image,
            index: widget.host.carousel.index,
            landscape: widget.landscape,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    listenTaskLeaving(ref, widget.taskId, _capture);
    return RepaintBoundary(key: _boundary, child: widget.child);
  }
}

/// La capa de las fotos de la cara de la rotura y del arrugado: la imagen
/// capturada, a pantalla completa; sin captura, nada (se ve el color de la
/// nota). Si se veía en horizontal, pide el ancho completo mientras se ve, como
/// la tarea que se dejó (CA-016-12, CL-016-11).
class PhotoFaceLayer extends StatefulWidget {
  const PhotoFaceLayer({super.key, required this.snapshot});

  final PhotoFaceSnapshot? snapshot;

  @override
  State<PhotoFaceLayer> createState() => _PhotoFaceLayerState();
}

class _PhotoFaceLayerState extends State<PhotoFaceLayer> {
  bool _fullWidth = false;

  void _sync() {
    final fullWidth = widget.snapshot?.landscape ?? false;
    if (fullWidth == _fullWidth) return;
    _fullWidth = fullWidth;
    // Fuera de la construcción: el marco de la app lo escucha.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => fullWidthRequests.value += fullWidth ? 1 : -1,
    );
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PhotoFaceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_fullWidth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => fullWidthRequests.value--,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    if (snapshot == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: RawImage(image: snapshot.image, fit: BoxFit.fill),
    );
  }
}
