import 'package:flutter/widgets.dart';

import '../app/theme/tokens.g.dart';

/// Duración del hundido de los controles que se desplazan al pulsarse
/// (`BrutalButton`, `SquareIconButton`, las opciones de "¿Dónde la pones?" y
/// el botón de completar).
///
/// Con "reducir movimiento" en el sistema, el cambio de posición y de sombra
/// es instantáneo: el hundido sigue indicando que se ha pulsado, pero como
/// cambio de estado, no como movimiento (CA-013-03). Sin él, los 80 ms de
/// `motion.duration.press`. Se lee en `build`, así que un cambio del ajuste con
/// la app abierta vale desde la siguiente pulsación.
Duration pressDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : UnaMotion.press;
