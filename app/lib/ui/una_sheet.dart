import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';

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
    // La hoja sube sobre el teclado: la ruta no lo hace sola, y con Android 15+
    // (a pantalla completa) `adjustResize` tampoco redimensiona la ventana.
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(child: builder(context)),
    ),
  );
}

/// Enlace subrayado en monoespaciada del prototipo ("Cancelar",
/// "Seguir editando"). Con el foco del teclado o de un
/// interruptor, anillo de foco (WCAG 2.4.7).
class UnaLinkButton extends StatefulWidget {
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
  State<UnaLinkButton> createState() => _UnaLinkButtonState();
}

class _UnaLinkButtonState extends State<UnaLinkButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: InkWell(
        onTap: widget.onPressed,
        onFocusChange: (v) => setState(() => _focused = v),
        splashFactory: NoSplash.splashFactory,
        child: FocusRing(
          visible: _focused && showsFocusHighlight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.height,
              minWidth: UnaSizes.minTouchTarget,
            ),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UnaSpace.s),
                child: Text(
                  widget.label,
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
      ),
    );
  }
}
