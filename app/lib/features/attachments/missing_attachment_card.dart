import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// "Adjunto no disponible" (CA-007-19, DEV-40): recuadro blanco con el texto
/// de la tarea (si lo tiene), el aviso y sus acciones: "Sustituir" y "Quitar
/// adjunto" (con texto) o "Eliminar tarea" (sin texto). Nunca cierra la app.
class MissingAttachmentCard extends StatelessWidget {
  const MissingAttachmentCard({
    super.key,
    required this.text,
    required this.header,
    required this.onReplace,
    required this.onRemove,
    required this.onDelete,
    this.preparing = false,
    this.onCancelPreparing,
  });

  /// Texto de la tarea, o vacío.
  final String text;

  /// Envuelve el texto y el aviso en el nodo de la tarea (lectura, foco y
  /// acciones de la pantalla principal).
  final Widget Function(Widget child) header;
  final VoidCallback onReplace;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  /// "Preparando imagen…" al sustituir (CA-007-15).
  final bool preparing;
  final VoidCallback? onCancelPreparing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: UnaColors.surface,
        border: Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
        ),
        boxShadow: [UnaShadows.button],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnaSpace.ml),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (text.isNotEmpty) ...[
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.attachmentText,
                        fontWeight: UnaFontWeights.extrabold,
                        height: 1.05,
                        letterSpacing:
                            UnaLetterSpacing.tighter *
                            UnaFontSizes.attachmentText,
                        color: UnaColors.ink,
                      ),
                    ),
                    const SizedBox(height: UnaSpace.sm),
                  ],
                  Row(
                    children: [
                      const UnaIcon(UnaIcons.image, color: UnaColors.error),
                      const SizedBox(width: UnaSpace.s),
                      Expanded(
                        child: Text(
                          l10n.attachmentMissing,
                          style: UnaTheme.mono.copyWith(
                            color: UnaColors.error,
                            fontWeight: UnaFontWeights.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnaSpace.ml),
            if (preparing) ...[
              Text(
                l10n.imagePreparing,
                textAlign: TextAlign.center,
                style: UnaTheme.mono.copyWith(color: UnaColors.ink),
              ),
              Center(
                child: UnaLinkButton(
                  label: l10n.imagePreparingCancel,
                  height: kMinInteractiveDimension,
                  onPressed: onCancelPreparing ?? () {},
                ),
              ),
            ] else ...[
              BrutalButton(
                label: l10n.attachmentReplace,
                icon: UnaIcons.image,
                iconSize: UnaSizes.icon,
                iconStroke: UnaSizes.iconStroke,
                onPressed: onReplace,
              ),
              const SizedBox(height: UnaSpace.sm),
              Center(
                child: UnaLinkButton(
                  label: text.isNotEmpty
                      ? l10n.editorRemoveAttachment
                      : l10n.deleteA11yAction,
                  height: kMinInteractiveDimension,
                  onPressed: text.isNotEmpty ? onRemove : onDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
