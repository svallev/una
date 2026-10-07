import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/una_icons.dart';

/// "Foto no disponible" (CA-016-18a, DEV-53): el recuadro que ocupa el sitio de
/// una foto del grupo cuyo archivo falta o está corrupto. Recuadro blanco con
/// borde y sombra, el aviso en rojo con el icono de imagen y **ninguna acción**
/// (no hay nada que reponer foto a foto: "Quitar adjunto" quita todo el grupo).
///
/// Llena el hueco que le dan; con [framed] a false (dentro de una foto de la
/// pila, que ya trae su borde y su sombra) solo pinta el fondo y el aviso. El
/// texto se lee tal cual (`photoMissing`); quien lo pone en un nodo mayor (el
/// carrusel, la pila) decide qué lee el lector.
class PhotoMissingBox extends StatelessWidget {
  const PhotoMissingBox({super.key, this.framed = true});

  /// Con borde y sombra propios.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Centrado y desplazable: con el texto al 200 % en un recuadro pequeño,
    // se puede llegar a todo en lugar de cortarse.
    final body = ColoredBox(
      color: UnaColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(UnaSpace.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UnaIcon(UnaIcons.image, color: UnaColors.error),
              const SizedBox(height: UnaSpace.s),
              Text(
                l10n.photoMissing,
                textAlign: TextAlign.center,
                style: UnaTheme.mono.copyWith(
                  color: UnaColors.error,
                  fontWeight: UnaFontWeights.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!framed) return body;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: UnaColors.surface,
        border: Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
        ),
        boxShadow: [UnaShadows.button],
      ),
      child: body,
    );
  }
}
