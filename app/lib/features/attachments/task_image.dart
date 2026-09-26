import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';

/// Tarea actual con imagen (CA-007-08, prototipo `cv.isImage`): la versión de
/// pantalla a sangre, recortada para llenarla, y el texto como pie (recuadro
/// negro, 146 px sobre el borde inferior, 3 líneas como máximo).
///
/// Es decorativa para el lector: la pantalla principal pone la imagen y el pie
/// en un único nodo (CA-007-21).
class TaskImage extends ConsumerWidget {
  const TaskImage({super.key, required this.attachment, this.caption});

  final Attachment attachment;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(attachmentImagesProvider);
    final caption = this.caption;
    final mq = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: images.stored(attachment.screenPath),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Sin la versión de pantalla se ve el color de la nota; el aviso de
          // adjunto perdido llega con CA-007-19.
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
        if (caption != null && caption.isNotEmpty)
          Positioned(
            left: UnaSpace.l,
            right: UnaSpace.l,
            bottom: UnaSizes.imageCaptionBottom,
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
                    caption,
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
          ),
      ],
    );
  }
}
