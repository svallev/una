import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import 'attachment_health.dart';

/// Tarea actual con imagen (CA-007-08, prototipo `cv.isImage`, DEV-41): la
/// versión de pantalla a todo el ancho, sin perder los lados; si es más baja
/// que la pantalla, queda el color de la nota arriba y abajo. El texto va como
/// pie (recuadro negro, 146 px sobre el borde inferior, 3 líneas como máximo).
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
    final health = ref.watch(attachmentHealthProvider(attachment));
    final caption = this.caption;
    final mq = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          // Tras regenerarla, se vuelve a leer (CA-007-19).
          key: ValueKey(health.generation),
          image: images.stored(attachment.screenPath),
          // Al ancho (propietario, 2026-09-27): la versión de pantalla ya
          // viene al ancho y, si es alta, recortada por abajo.
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
          // No se puede decodificar: se regenera desde la completa y, si
          // tampoco sirve, se ve "Adjunto no disponible". Mientras, el color
          // de la nota.
          errorBuilder: (context, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ref
                    .read(attachmentHealthProvider(attachment).notifier)
                    .reportBroken();
              }
            });
            return const SizedBox.expand();
          },
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
