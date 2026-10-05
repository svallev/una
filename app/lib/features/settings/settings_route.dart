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
/// nivel que la abre. (La subida del nivel 1, `settingsSheetRoute`, es de
/// T-015-09.)
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
