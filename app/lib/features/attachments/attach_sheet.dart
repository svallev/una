import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Lo que se eligió en "Añadir a la tarea".
enum AttachChoice { camera, gallery, file, url }

/// Abre la hoja "Añadir a la tarea" (CA-007-01). Devuelve la opción elegida,
/// o null si se cierra. Sin [withUrl] (modo editar), no tiene "Cargar URL":
/// una tarea no se convierte en web (CA-009-01).
Future<AttachChoice?> showAttachSheet(
  BuildContext context, {
  required bool withUrl,
}) => showUnaSheet<AttachChoice>(
  context,
  builder: (sheet) => AttachSheet(
    onTakePhoto: () => Navigator.of(sheet).pop(AttachChoice.camera),
    onPickImage: () => Navigator.of(sheet).pop(AttachChoice.gallery),
    onPickFile: () => Navigator.of(sheet).pop(AttachChoice.file),
    onLoadUrl: withUrl ? () => Navigator.of(sheet).pop(AttachChoice.url) : null,
  ),
);

/// Hoja "Añadir a la tarea" (prototipo "HOJA: añadir foto, imagen o
/// archivo"): filas de dos líneas. "Subir archivo" sube un PDF (spec 008);
/// "Cargar URL" abre su hoja (spec 009) y solo está en las tareas nuevas.
class AttachSheet extends StatelessWidget {
  const AttachSheet({
    super.key,
    required this.onTakePhoto,
    required this.onPickImage,
    required this.onPickFile,
    this.onLoadUrl,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  /// "Cargar URL"; sin él, la fila no aparece (modo editar, CA-009-01).
  final VoidCallback? onLoadUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.attachSheetTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.s,
          UnaSpace.l,
          UnaSpace.xl - 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              label: l10n.attachSheetTitle,
              closeLabel: l10n.attachSheetClose,
            ),
            SheetRow(
              icon: UnaIcons.camera,
              label: l10n.attachTakePhoto,
              subtitle: l10n.attachTakePhotoHint,
              onTap: onTakePhoto,
            ),
            SheetRow(
              icon: UnaIcons.image,
              label: l10n.attachPickImage,
              subtitle: l10n.attachPickImageHint,
              divider: true,
              onTap: onPickImage,
            ),
            SheetRow(
              icon: UnaIcons.document,
              label: l10n.attachPickFile,
              subtitle: l10n.attachPickFileHint,
              divider: true,
              onTap: onPickFile,
            ),
            if (onLoadUrl case final onLoadUrl?)
              SheetRow(
                icon: UnaIcons.link,
                label: l10n.attachUrl,
                subtitle: l10n.attachUrlHint,
                divider: true,
                onTap: onLoadUrl,
              ),
          ],
        ),
      ),
    );
  }
}
