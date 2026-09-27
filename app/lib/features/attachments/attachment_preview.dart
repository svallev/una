import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/boxed_icon_button.dart';
import '../../ui/focus_on_signal.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Vista previa del adjunto en el editor (CA-007-04, prototipo `hasDraftAtt`):
/// recuadro blanco con borde y sombra dura, la imagen recortada para llenarlo
/// y "Quitar adjunto" arriba a la derecha (48 dp, DEV-36). Mientras se
/// prepara otra imagen, encima "Preparando imagen…" con "Cancelar"
/// (CA-007-15).
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.image,
    required this.semanticLabel,
    required this.onRemove,
    required this.preparing,
    required this.onCancelPreparing,
    required this.focusSignal,
    required this.cancelFocusSignal,
  });

  /// La versión de pantalla, o null si aún no hay imagen (solo "Preparando").
  final ImageProvider? image;

  /// "Foto" o "Imagen".
  final String semanticLabel;
  final VoidCallback onRemove;
  final bool preparing;
  final VoidCallback onCancelPreparing;

  /// Cambia cuando la vista previa debe tomar el foco (imagen añadida).
  final int focusSignal;

  /// Cambia cuando "Cancelar" debe tomar el foco ("Preparando imagen…").
  final int cancelFocusSignal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = this.image;
    // Llena el hueco que le deja el editor, sin crecer con la imagen: la
    // imagen va posicionada, así que no cuenta en la altura intrínseca con la
    // que SliverFillRemaining mide la columna (una foto vertical empujaba los
    // botones fuera de la pantalla). Como mínimo cabe "Quitar adjunto".
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: UnaSizes.removeAttachment + 2 * (UnaSpace.s - UnaSpace.xxs),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: UnaColors.surface,
          border: Border.fromBorderSide(
            BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
          ),
          boxShadow: [UnaShadows.button],
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Positioned.fill(
                  child: FocusOnSignal(
                    signal: focusSignal,
                    // Tapada por "Preparando imagen…", el lector no la lee.
                    child: ExcludeSemantics(
                      excluding: preparing,
                      child: Semantics(
                        image: true,
                        label: semanticLabel,
                        excludeSemantics: true,
                        child: Image(
                          image: image,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          // Sin la versión de pantalla, el recuadro queda en blanco
                          // (el aviso de adjunto perdido es de la pantalla principal).
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (image != null && !preparing)
                Positioned(
                  top: UnaSpace.s - UnaSpace.xxs,
                  right: UnaSpace.s - UnaSpace.xxs,
                  child: BoxedIconButton(
                    label: l10n.editorRemoveAttachment,
                    icon: UnaIcons.close,
                    dimension: UnaSizes.removeAttachment,
                    iconSize: UnaSizes.removeAttachmentIcon,
                    iconStroke: UnaSizes.removeAttachmentStroke,
                    onPressed: onRemove,
                  ),
                ),
              if (preparing)
                _Preparing(
                  label: l10n.imagePreparing,
                  cancelLabel: l10n.imagePreparingCancel,
                  onCancel: onCancelPreparing,
                  cancelFocusSignal: cancelFocusSignal,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({
    required this.label,
    required this.cancelLabel,
    required this.onCancel,
    required this.cancelFocusSignal,
  });

  final String label;
  final String cancelLabel;
  final VoidCallback onCancel;
  final int cancelFocusSignal;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: UnaColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UnaSpace.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El anuncio lo hace el editor al aparecer (CA-007-22).
              Text(
                label,
                textAlign: TextAlign.center,
                style: UnaTheme.mono.copyWith(
                  color: UnaColors.ink,
                  fontWeight: UnaFontWeights.bold,
                ),
              ),
              const SizedBox(height: UnaSpace.sm),
              // Con reducir movimiento, sin animación (CA-007-23).
              if (!reduced)
                const SizedBox(
                  width: UnaSizes.button * 2,
                  child: LinearProgressIndicator(
                    color: UnaColors.ink,
                    backgroundColor: UnaColors.line,
                    minHeight: UnaBorders.strongWidth,
                  ),
                ),
              const SizedBox(height: UnaSpace.s),
              FocusOnSignal(
                signal: cancelFocusSignal,
                child: UnaLinkButton(
                  label: cancelLabel,
                  height: kMinInteractiveDimension,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
