import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';

/// Hoja del prototipo (`.sheetbg` + `.sheetup`): fondo `scrim`, sube en
/// `sheetIn` con la curva `sheet` y baja en `sheetOut`; color papel, borde
/// superior de 3 px, sin esquinas ni asa. Se cierra con la X, tocando fuera,
/// con el gesto atrás o deslizando hacia abajo (DEV-21). La ruta modal atrapa
/// el foco del lector y del teclado.
Future<T?> showUnaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: UnaColors.paper,
    barrierColor: UnaColors.scrim,
    elevation: 0,
    shape: const Border(
      top: BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
    ),
    // Reducir movimiento: la hoja no se desliza.
    sheetAnimationStyle: reduced
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: UnaMotion.sheetIn,
            reverseDuration: UnaMotion.sheetOut,
            curve: UnaMotion.sheetCurve,
            reverseCurve: UnaMotion.sheetOutCurve,
          ),
    builder: (context) => SingleChildScrollView(child: builder(context)),
  );
}

/// Enlace subrayado en monoespaciada del prototipo ("Cancelar",
/// "Configuración", "Seguir editando").
class UnaLinkButton extends StatelessWidget {
  const UnaLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = UnaSizes.linkButton,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: UnaSizes.minTouchTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: UnaSpace.s),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: UnaFonts.mono,
                  fontSize: UnaFontSizes.link,
                  fontWeight: UnaFontWeights.bold,
                  color: UnaColors.ink,
                  decoration: TextDecoration.underline,
                  decorationThickness: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
