import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import 'attachment_health.dart';

/// Una foto a pantalla completa, lo que comparten la imagen suelta
/// ([TaskImage]) y cada página del carrusel (CA-007-08/09/10, spec 016):
/// la versión de pantalla en el primer fotograma y, encima, las teselas;
/// desplazamiento vertical con su [scroll]; pellizco hasta ×8 que ocurre ahí
/// mismo y, al soltar, vuelve al 100 %. El zoom nunca se conserva. Con dos
/// dedos no se desplaza. No lleva pie ni semántica: la pantalla principal
/// pone la foto y el pie en un único nodo (CA-007-21).
class ZoomablePhoto extends ConsumerStatefulWidget {
  const ZoomablePhoto({super.key, required this.attachment, this.scroll});

  final Attachment attachment;

  /// Desplazamiento de la foto alta, para moverla también con las acciones
  /// del lector y con el teclado (CA-007-09, WCAG 2.1.1).
  final ScrollController? scroll;

  @override
  ConsumerState<ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  /// Zoom del pellizco: sigue a los dedos y vuelve al 100 % al soltar.
  final _zoom = ValueNotifier<Matrix4>(Matrix4.identity());
  final _pointers = <int, Offset>{};
  double? _startSpan;
  Offset? _startFocal;
  late final _back = AnimationController(
    vsync: this,
    duration: UnaMotion.imageZoomBack,
  );
  Animation<Matrix4>? _backTween;

  /// Con dos dedos no se desplaza: solo amplía.
  bool _pinching = false;

  @override
  void initState() {
    super.initState();
    _back.addListener(() {
      final tween = _backTween;
      if (tween != null) _zoom.value = tween.value;
    });
  }

  @override
  void dispose() {
    _back.dispose();
    _zoom.dispose();
    super.dispose();
  }

  (Offset, double) _focalAndSpan() {
    final points = _pointers.values.take(2).toList();
    return ((points[0] + points[1]) / 2, (points[0] - points[1]).distance);
  }

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _back.stop();
      final (focal, span) = _focalAndSpan();
      _startFocal = focal;
      _startSpan = math.max(span, 1);
      setState(() => _pinching = true);
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final start = _startFocal;
    final startSpan = _startSpan;
    if (_pointers.length < 2 || start == null || startSpan == null) return;
    final (focal, span) = _focalAndSpan();
    final scale = (span / startSpan).clamp(1.0, UnaMotion.imageZoomMax);
    // El punto que estaba bajo los dedos sigue bajo ellos.
    _zoom.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-start.dx, -start.dy, 0, 1);
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (!_pinching || _pointers.length >= 2) return;
    _startFocal = null;
    _startSpan = null;
    setState(() => _pinching = false);
    if (_zoom.value.isIdentity()) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _zoom.value = Matrix4.identity();
      return;
    }
    _backTween = Matrix4Tween(
      begin: _zoom.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _back, curve: UnaMotion.standardCurve));
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final images = ref.watch(attachmentImagesProvider);
    final health = ref.watch(attachmentHealthProvider(attachment));
    final mq = MediaQuery.of(context);
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: _zoom,
        builder: (_, zoom, child) => Transform(transform: zoom, child: child),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height =
                width * attachment.height / math.max(1, attachment.width);
            return SingleChildScrollView(
              controller: widget.scroll,
              physics: _pinching
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: SizedBox(
                width: width,
                height: math.max(height, constraints.maxHeight),
                child: Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // La versión de pantalla sale en el primer
                        // fotograma (CA-007-08); encima, las teselas.
                        Image(
                          // Tras regenerarla, se vuelve a leer (CA-007-19).
                          key: ValueKey(health.generation),
                          image: images.stored(attachment.screenPath),
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                          // No se puede decodificar: se regenera desde la
                          // completa y, si tampoco sirve, se ve "Adjunto no
                          // disponible". Mientras, el color de la nota.
                          errorBuilder: (context, _, _) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                ref
                                    .read(
                                      attachmentHealthProvider(attachment)
                                          .notifier,
                                    )
                                    .reportBroken();
                              }
                            });
                            return const SizedBox.expand();
                          },
                        ),
                        AttachmentTiles(
                          attachment: attachment,
                          width: width,
                          height: height,
                          decodeScale: mq.devicePixelRatio,
                          image: images.stored,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// La imagen guardada por teselas de 4096 px (CA-007-06), colocadas a
/// [width] × [height] y decodificadas a [decodeScale] píxeles por punto: la
/// memoria depende del tamaño en pantalla, no del original.
class AttachmentTiles extends StatelessWidget {
  const AttachmentTiles({
    super.key,
    required this.attachment,
    required this.width,
    required this.height,
    required this.decodeScale,
    required this.image,
  });

  final Attachment attachment;
  final double width;
  final double height;
  final double decodeScale;
  final ImageProvider Function(String relPath) image;

  @override
  Widget build(BuildContext context) {
    final tiles = attachment.tiles;
    final k = width / attachment.width;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var r = 0; r < tiles.rows; r++)
            for (var c = 0; c < tiles.columns; c++)
              Builder(
                builder: (context) {
                  final rect = tiles.rect(r, c);
                  final w = rect.width * k;
                  // Nunca por encima del tamaño real de la tesela.
                  final cacheWidth = math.min(
                    rect.width,
                    (w * decodeScale).ceil(),
                  );
                  return Positioned(
                    left: rect.left * k,
                    top: rect.top * k,
                    width: w,
                    height: rect.height * k,
                    child: Image(
                      image: ResizeImage(
                        image('${attachment.dir}/${ImageTiles.fileName(r, c)}'),
                        width: math.max(1, cacheWidth),
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      // Sin la tesela, se ve la versión de pantalla debajo.
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
