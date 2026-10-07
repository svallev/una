import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';

/// El aviso visible del editor tras importar un grupo con avisos (más de 10 o
/// fotos omitidas; CA-016-05 y 21): un recuadro encima de los botones, con
/// **el mismo texto** que el anuncio.
///
/// No es un `SnackBar` (caduca, WCAG 2.2.1) ni una región viva (el editor ya lo
/// anuncia **una vez**: otra lectura haría eco). Es un texto normal que el
/// lector puede enfocar. No caduca, crece con el texto grande (CA-016-22) y lo
/// quita quien lo pone: al cambiar o quitar el grupo, al guardar o al salir.
class ImportNoticeBanner extends StatelessWidget {
  const ImportNoticeBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: UnaColors.surface,
        border: Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnaSpace.s),
        child: Text(text, style: UnaTheme.mono.copyWith(color: UnaColors.ink)),
      ),
    );
  }
}
