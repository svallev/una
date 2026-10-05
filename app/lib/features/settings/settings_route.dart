import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.g.dart';

/// Duración de la transición entre niveles de Ajustes (spec 015, CA-015-01d;
/// antes, de la 012): un fundido de 160 ms, o ninguno con "reducir movimiento"
/// (CA-012-13). Es la de la página de Idioma (nivel 2) al abrirse y al cerrarse.
Duration settingsTransition(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : UnaMotion.sheetOut;

/// Ruta de un nivel de Ajustes (spec 012; en la 015, la página de Idioma):
/// opaca, a pantalla completa y con fundido. Se empuja desde el contexto del
/// nivel que la abre.
Route<T> settingsRoute<T>(BuildContext context, WidgetBuilder builder) {
  final duration = settingsTransition(context);
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Ruta del nivel 1 de Ajustes (spec 015, CA-015-01a y 01d): a pantalla
/// completa, **sube desde abajo en 200 ms** (`sheetIn`) y **baja en 160 ms**
/// (`sheetOut`), con las curvas de las hojas; con "reducir movimiento", en el
/// mismo fotograma (0 ms). Opaca: cuando termina de subir, lo que hay debajo
/// deja de dibujarse.
Route<T> settingsSheetRoute<T>(BuildContext context, WidgetBuilder builder) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return PageRouteBuilder<T>(
    transitionDuration: reduced ? Duration.zero : UnaMotion.sheetIn,
    reverseTransitionDuration: reduced ? Duration.zero : UnaMotion.sheetOut,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: UnaMotion.sheetCurve,
              reverseCurve: UnaMotion.sheetOutCurve,
            ),
          ),
      child: child,
    ),
  );
}
