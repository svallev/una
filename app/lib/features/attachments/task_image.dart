import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import 'zoomable_photo.dart';

/// Tarea actual con imagen (CA-007-08/09/10, DEV-41/43): la imagen a todo el
/// ancho, sin perder nada por los lados. Si es más baja que la pantalla, queda
/// el color de la nota arriba y abajo; si es más alta, se desplaza en vertical.
/// Pellizcar la amplía ahí mismo y, al soltar, vuelve al 100 %. No hay visor
/// (propietario, 2026-09-27). El texto va como pie (recuadro negro, 146 px
/// sobre el borde inferior, 3 líneas como máximo) si se pasa [caption].
///
/// Es decorativa para el lector: la pantalla principal pone la imagen y el pie
/// en un único nodo (CA-007-21).
class TaskImage extends StatelessWidget {
  const TaskImage({
    super.key,
    required this.attachment,
    this.caption,
    this.scroll,
  });

  final Attachment attachment;
  final String? caption;

  /// Desplazamiento de la imagen alta, para moverla también con las acciones
  /// del lector y con el teclado (CA-007-09, WCAG 2.1.1).
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Stack(
      fit: StackFit.expand,
      children: [
        ZoomablePhoto(attachment: attachment, scroll: scroll),
        if (caption != null && caption.isNotEmpty)
          Positioned(
            left: UnaSpace.l,
            right: UnaSpace.l,
            bottom: UnaSizes.imageCaptionBottom,
            child: ImageCaption(caption),
          ),
      ],
    );
  }
}

/// El pie de la tarea con imagen (prototipo `bottom: 146px`): recuadro negro,
/// texto blanco de 22 px y 800, 3 líneas como máximo y escala de texto de hasta
/// ×1,6. Transparente a los toques: un swipe o un pellizco que empieza sobre él
/// llega a la imagen. Para el lector es decorativo: la pantalla principal lo
/// lee dentro del nodo de la tarea (CA-007-21).
class ImageCaption extends StatelessWidget {
  const ImageCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return IgnorePointer(
      child: MediaQuery(
        data: mq.copyWith(
          textScaler: mq.textScaler.clamp(
            maxScaleFactor: UnaSizes.imageCaptionMaxTextScale,
          ),
        ),
        child: ColoredBox(
          color: UnaColors.ink,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UnaSizes.imageCaptionPadX,
              vertical: UnaSpace.sm,
            ),
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: UnaFonts.display,
                fontSize: UnaFontSizes.imageCaption,
                fontWeight: UnaFontWeights.extrabold,
                height: 1.1,
                letterSpacing:
                    UnaLetterSpacing.tight * UnaFontSizes.imageCaption,
                color: UnaColors.onInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
