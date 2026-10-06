import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import '../attachments/photo_carousel.dart';
import '../attachments/photo_dots.dart';
import '../attachments/task_image.dart';

/// Lo que comparten la capa de las fotos (detrás) y el pie con los puntos
/// (encima) en la pantalla principal con un grupo (spec 016): el controlador
/// del carrusel (qué foto se ve) y el margen inferior que dejan las fotos.
/// Vive lo que la pantalla de esa tarea: con otra tarea o al volver tras 10
/// minutos se crea de nuevo y se ve la primera foto (CA-016-08).
class PhotoGroupHost {
  /// El carrusel: foto que se ve, desplazamiento de esa foto, siguiente y
  /// anterior.
  final carousel = PhotoCarouselController();

  /// Lo que hay entre el borde inferior de la capa de las fotos y lo alto del
  /// pie (o de los puntos, sin pie): el desplazamiento vertical de cada foto
  /// deja ese margen para poder ver su final (CA-016-11). Lo escribe
  /// [PhotoGroupFooter] desde su caja real.
  final inset = ValueNotifier<double>(0);

  /// La capa de las fotos, de la que se mide el borde inferior.
  final layerKey = GlobalKey(debugLabel: 'photo layer');

  void dispose() {
    carousel.dispose();
    inset.dispose();
  }
}

/// El pie de la tarea y, **bajo él y encima del botón de completar**, los
/// puntos del carrusel (CA-016-09 y 11, P-016-1). Va en el hueco de arriba del
/// botón, de modo que se coloca desde la **caja real** del botón (también con
/// el texto al 200 % y con la card de deshacer) y no desde una posición fija
/// del prototipo. Es **fijo**: no se mueve al cambiar de foto.
///
/// Mide su propia caja y avisa de ella a la capa de las fotos
/// ([PhotoGroupHost.inset]): su margen inferior. Transparente a los toques (un
/// swipe o un pellizco que empieza encima llega al carrusel) y fuera de la
/// lectura: la tarea ya dice su texto y su foto (CA-007-21).
class PhotoGroupFooter extends StatefulWidget {
  const PhotoGroupFooter({
    super.key,
    required this.host,
    required this.count,
    this.caption,
  });

  final PhotoGroupHost host;
  final int count;

  /// El texto de la tarea; sin él (o vacío) solo van los puntos.
  final String? caption;

  @override
  State<PhotoGroupFooter> createState() => _PhotoGroupFooterState();
}

class _PhotoGroupFooterState extends State<PhotoGroupFooter> {
  final _box = GlobalKey(debugLabel: 'photo footer');

  /// Mide tras el fotograma: aquí aún no hay layout, y avisar durante la
  /// construcción reconstruiría el carrusel a mitad de un fotograma.
  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    final footer = _box.currentContext?.findRenderObject();
    final layer = widget.host.layerKey.currentContext?.findRenderObject();
    if (footer is! RenderBox || layer is! RenderBox) return;
    if (!footer.attached || !footer.hasSize || !layer.attached) return;
    if (!layer.hasSize) return;
    final layerBottom = layer.localToGlobal(Offset(0, layer.size.height)).dy;
    final footerTop = footer.localToGlobal(Offset.zero).dy;
    final inset = (layerBottom - footerTop).clamp(0.0, double.infinity);
    if ((inset - widget.host.inset.value).abs() > 0.5) {
      widget.host.inset.value = inset;
    }
  }

  @override
  Widget build(BuildContext context) {
    _measureAfterFrame();
    final caption = widget.caption;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _measureAfterFrame();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: PhotoFooterColumn(
          key: _box,
          caption: caption,
          dots: ListenableBuilder(
            listenable: widget.host.carousel,
            builder: (context, _) => PhotoDots(
              count: widget.count,
              index: widget.host.carousel.index,
            ),
          ),
        ),
      ),
    );
  }
}

/// El pie y, bajo él, los puntos, con el hueco de arriba del botón: lo que
/// comparten el pie de la pantalla ([PhotoGroupFooter]) y el de la cara de la
/// rotura y el arrugado ([PhotoFaceFooter]), para que ocupen el mismo sitio.
class PhotoFooterColumn extends StatelessWidget {
  const PhotoFooterColumn({super.key, this.caption, required this.dots});

  /// El texto de la tarea; sin él (o vacío) solo van los puntos.
  final String? caption;
  final Widget dots;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null && caption.isNotEmpty) ...[
          // Decorativo: el nodo de la tarea ya lo lee.
          ExcludeSemantics(child: ImageCaption(caption)),
          const SizedBox(height: UnaSpace.sm),
        ],
        Center(child: dots),
        // Entre los puntos y el botón de completar (prototipo: ~12).
        const SizedBox(height: UnaSpace.sm),
      ],
    );
  }
}

/// El pie de la cara de la rotura y del arrugado (spec 016, CA-016-13): el
/// texto y los puntos con la foto que se veía ([index]), sin medir nada ni
/// escuchar al carrusel. Sin captura ([index] nulo), solo el pie, sin puntos:
/// no se sabe qué foto se veía.
class PhotoFaceFooter extends StatelessWidget {
  const PhotoFaceFooter({
    super.key,
    required this.count,
    required this.index,
    this.caption,
  });

  final int count;
  final int? index;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final index = this.index;
    return PhotoFooterColumn(
      caption: caption,
      dots: index == null
          ? const SizedBox.shrink()
          : PhotoDots(count: count, index: index),
    );
  }
}

/// La capa de las fotos, detrás de todo y a pantalla completa: el carrusel con
/// el margen inferior que miden el pie y los puntos (CA-016-11). En horizontal
/// no hay ni pie ni puntos: sin margen.
class PhotoGroupLayer extends StatelessWidget {
  const PhotoGroupLayer({
    super.key,
    required this.host,
    required this.photos,
    required this.landscape,
  });

  final PhotoGroupHost host;
  final List<Attachment> photos;
  final bool landscape;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: host.inset,
    builder: (_, inset, _) => SizedBox.expand(
      key: host.layerKey,
      child: PhotoCarousel(
        photos: photos,
        controller: host.carousel,
        bottomInset: landscape ? 0 : inset,
      ),
    ),
  );
}
