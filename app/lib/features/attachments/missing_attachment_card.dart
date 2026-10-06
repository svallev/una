import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_icons.dart';

/// "Adjunto no disponible" (CA-007-19, DEV-40): recuadro blanco con el texto
/// de la tarea (si lo tiene), el aviso y una sola acción: "Quitar adjunto"
/// (con texto) o "Eliminar tarea" (sin texto). Nunca cierra la app. Con PDF,
/// el icono de documento (CA-008-18). Con un grupo de fotos (spec 016) sale
/// cuando faltan **todas** o el grupo no es válido (CA-016-18b, CA-016-25), y
/// "Quitar adjunto" quita el grupo entero.
class MissingAttachmentCard extends StatelessWidget {
  const MissingAttachmentCard({
    super.key,
    required this.text,
    required this.header,
    required this.onRemove,
    required this.onDelete,
    this.isPdf = false,
  });

  /// Texto de la tarea, o vacío.
  final String text;

  /// Envuelve el texto y el aviso en el nodo de la tarea (lectura, foco y
  /// acciones de la pantalla principal).
  final Widget Function(Widget child) header;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  /// El adjunto que falta es un PDF: icono de documento en vez del de imagen.
  final bool isPdf;

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
                      UnaIcon(
                        isPdf ? UnaIcons.document : UnaIcons.image,
                        color: UnaColors.error,
                      ),
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
            BrutalButton(
              label: text.isNotEmpty
                  ? l10n.editorRemoveAttachment
                  : l10n.deleteA11yAction,
              iconSize: UnaSizes.icon,
              iconStroke: UnaSizes.iconStroke,
              onPressed: text.isNotEmpty ? onRemove : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
