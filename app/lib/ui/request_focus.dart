import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Devuelve el foco (teclado y lector de pantalla) a un control cuando termina
/// la transición de vuelta: pasado [after] (lo que dura la transición, o cero
/// con "reducir movimiento") y ya dibujado un fotograma más.
///
/// El foco de teclado va a [node]; el del lector, al nodo accesible de
/// [semantics] (el del propio control, no el de un antecesor). [isMounted]
/// evita pedirlo si el control ya no existe.
void requestFocusAfter({
  required Duration after,
  required bool Function() isMounted,
  required FocusNode node,
  GlobalKey? semantics,
}) {
  Timer(after, () {
    if (!isMounted()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      node.requestFocus();
      semantics?.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  });
}
