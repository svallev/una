import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';

/// "Volver a vertical" (CA-008-11): en horizontal, con imagen o con PDF, pone
/// la app en vertical aunque el móvil siga en horizontal. Botón con fondo
/// propio (se ve sobre cualquier imagen o página), de 48 dp como mínimo y con
/// el texto en una línea que se reduce si no cabe (texto al 200 %).
class BackToPortraitButton extends StatelessWidget {
  const BackToPortraitButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BrutalButton(
    label: AppLocalizations.of(context).backToPortrait,
    height: UnaSizes.backToPortrait,
    fontSize: UnaFontSizes.body,
    expand: false,
    singleLine: true,
    onPressed: onPressed,
  );
}
