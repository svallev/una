import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import 'attachment_health.dart';

/// Miniatura de 44 px del listado, recortada y con borde de 2 px (prototipo
/// `item.isImg`, CA-007-20). Si falta o no se puede leer, la insignia
/// "FOTO"/"IMAGEN" (CA-007-19). Decorativa para el lector.
class TaskThumbnail extends ConsumerWidget {
  const TaskThumbnail({
    super.key,
    required this.attachment,
    required this.kindLabel,
  });

  final Attachment attachment;

  /// "Foto" o "Imagen" (la insignia va en mayúsculas).
  final String kindLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(attachmentHealthProvider(attachment));
    final badge = _Badge(kindLabel);
    final thumb = attachment.thumbPath;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: UnaSizes.listThumb,
        // Sin miniatura (un PDF, CA-008-19) o si falta: la insignia.
        child: thumb == null || health.health == AttachmentHealth.missing
            ? badge
            : DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: const BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: UnaColors.ink,
                      width: UnaSizes.listThumbBorder,
                    ),
                  ),
                ),
                child: Image(
                  key: ValueKey(health.generation),
                  image: ref.watch(attachmentImagesProvider).stored(thumb),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, _, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ref
                            .read(attachmentHealthProvider(attachment).notifier)
                            .reportBroken();
                      }
                    });
                    return badge;
                  },
                ),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UnaColors.ink,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UnaSpace.xxs),
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                fontFamily: UnaFonts.mono,
                fontSize: UnaFontSizes.badge,
                fontWeight: UnaFontWeights.bold,
                color: UnaColors.onInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
