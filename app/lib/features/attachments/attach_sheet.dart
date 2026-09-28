import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Lo que se eligió en "Añadir a la tarea".
enum AttachChoice { camera, gallery, file }

/// Abre la hoja "Añadir a la tarea" (CA-007-01). Devuelve la opción elegida,
/// o null si se cierra.
Future<AttachChoice?> showAttachSheet(BuildContext context) =>
    showUnaSheet<AttachChoice>(
      context,
      builder: (sheet) => AttachSheet(
        onTakePhoto: () => Navigator.of(sheet).pop(AttachChoice.camera),
        onPickImage: () => Navigator.of(sheet).pop(AttachChoice.gallery),
        onPickFile: () => Navigator.of(sheet).pop(AttachChoice.file),
      ),
    );

/// Hoja "Añadir a la tarea" (prototipo "HOJA: añadir foto, imagen o
/// archivo"): cuatro filas de dos líneas. "Subir archivo" sube un PDF (spec
/// 008); "Cargar URL" se ve activa pero no hace nada hasta la 009 (DEV-18).
class AttachSheet extends StatelessWidget {
  const AttachSheet({
    super.key,
    required this.onTakePhoto,
    required this.onPickImage,
    required this.onPickFile,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  static void _notYet() {}

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
            SheetRow(
              icon: UnaIcons.link,
              label: l10n.attachUrl,
              subtitle: l10n.attachUrlHint,
              divider: true,
              onTap: _notYet,
            ),
          ],
        ),
      ),
    );
  }
}
