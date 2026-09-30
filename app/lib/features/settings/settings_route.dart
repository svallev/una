import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.g.dart';

/// Duración de la transición de los tres niveles de la Configuración: un fundido
/// de 160 ms, o ninguno con "reducir movimiento" (CA-012-13).
Duration settingsTransition(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : UnaMotion.sheetOut;

/// Ruta de un nivel de la Configuración (spec 012): opaca, a pantalla completa
/// y con fundido. Se empuja desde el contexto de la hoja del menú, así que al
/// cerrar el nivel 1 el menú sigue debajo tal como estaba (CA-012-02).
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
