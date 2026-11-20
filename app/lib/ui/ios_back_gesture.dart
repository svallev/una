import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';

/// El gesto atrás de iOS (spec 028, CA-028-09): deslizar desde el borde
/// izquierdo vuelve a la pantalla anterior.
///
/// **Lo visual es el de Android:** la ruta no cambia de transición (el fundido,
/// la hoja que sube, ninguna…); el dedo solo mueve su animación, y al soltar
/// **decide únicamente la mitad** (sin regla de velocidad): más allá de la
/// mitad vuelve, antes de ella se queda. Se respeta lo que respeta el atrás de
/// Android: la primera ruta (la tarea actual) y las que un `PopScope` no deja
/// cerrar no tienen gesto. En Android no se añade nada.
///
/// El de `CupertinoPageRoute` es privado y viene con su propia transición, así
/// que esta es una versión mínima del mismo mecanismo: la franja de 20 pt
/// ([UnaSizes.backGestureEdge]), el controlador de la ruta movido con el dedo y
/// el aviso al `Navigator` de que hay un gesto en curso.
mixin IosBackGestureRoute<T> on PageRoute<T> {
  /// Lo llama la franja del borde al empezar el arrastre. Con
  /// [reduceMotion] ("reducir movimiento"), al soltar la vuelta es inmediata.
  IosBackGestureController startBackGesture({required bool reduceMotion}) {
    return IosBackGestureController(
      navigator: navigator!,
      controller: controller!, // acceso protegido, como en CupertinoPageRoute
      getIsCurrent: () => isCurrent,
      getIsActive: () => isActive,
      settle: reduceMotion ? Duration.zero : UnaMotion.backGestureSettle,
    );
  }

  /// [transitions] (lo que construye la propia ruta) con la franja del borde
  /// encima. La franja no se mueve con la pantalla.
  Widget withBackGesture(Widget transitions) =>
      IosBackSwipe(route: this, child: transitions);
}

/// Ruta de página con transición propia y el gesto atrás de iOS: un
/// [PageRouteBuilder] sin más cambios. [transitionsBuilder] por defecto no
/// anima nada (como el de `PageRouteBuilder`).
class UnaPageRoute<T> extends PageRouteBuilder<T> with IosBackGestureRoute<T> {
  UnaPageRoute({
    required super.pageBuilder,
    super.transitionsBuilder = _noTransition,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.settings,
  });

  static Widget _noTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => withBackGesture(
    super.buildTransitions(context, animation, secondaryAnimation, child),
  );
}

/// Ruta de Material (la transición la da el tema: `UnaTheme`, que en iOS usa
/// la misma que Android) con el gesto atrás de iOS.
class UnaMaterialPageRoute<T> extends MaterialPageRoute<T>
    with IosBackGestureRoute<T> {
  UnaMaterialPageRoute({required super.builder, super.settings});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => withBackGesture(
    super.buildTransitions(context, animation, secondaryAnimation, child),
  );
}

/// La franja del borde izquierdo con su reconocedor. Solo hace algo en iOS y
/// cuando la ruta puede volver ([PageRoute.popGestureEnabled]: no la primera,
/// ni una que un `PopScope` no deje cerrar, ni mientras se anima).
class IosBackSwipe extends StatefulWidget {
  const IosBackSwipe({super.key, required this.route, required this.child});

  /// Clave de la franja (para los tests).
  static const edgeKey = ValueKey<String>('ios-back-edge');

  final IosBackGestureRoute<Object?> route;
  final Widget child;

  @override
  State<IosBackSwipe> createState() => _IosBackSwipeState();
}

class _IosBackSwipeState extends State<IosBackSwipe> {
  IosBackGestureController? _controller;
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _start
        ..onUpdate = _update
        ..onEnd = _end
        ..onCancel = _cancel;

  @override
  void dispose() {
    _recognizer.dispose();
    // Si se destruye en pleno arrastre, el Navigator no se queda esperando.
    final controller = _controller;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.navigator.mounted) {
          controller.navigator.didStopUserGesture();
        }
      });
      _controller = null;
    }
    super.dispose();
  }

  void _start(DragStartDetails details) {
    if (!widget.route.popGestureEnabled) return;
    _controller = widget.route.startBackGesture(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  void _update(DragUpdateDetails details) {
    _controller?.dragUpdate(details.primaryDelta! / context.size!.width);
  }

  void _end(DragEndDetails details) {
    _controller?.dragEnd();
    _controller = null;
  }

  void _cancel() {
    // Puede llegar sin `_start`, emparejado con el "down" que no miramos.
    _controller?.dragEnd();
    _controller = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.route.popGestureEnabled) _recognizer.addPointer(event);
  }

  @override
  Widget build(BuildContext context) {
    // Solo iOS: en Android no se añade nada (ni franja ni capa).
    if (Theme.of(context).platform != TargetPlatform.iOS) return widget.child;
    // En un móvil con muesca, la franja cubre también el margen de ese lado.
    final inset = MediaQuery.paddingOf(context).left;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 0,
          width: math.max(inset, UnaSizes.backGestureEdge),
          top: 0,
          bottom: 0,
          child: Listener(
            key: IosBackSwipe.edgeKey,
            onPointerDown: _onPointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Mueve la animación de la ruta con el dedo (0 = pantalla quitada, 1 = puesta)
/// y, al soltar, la termina en un sentido u otro según la mitad. Va en
/// coordenadas lógicas: 1 = el ancho de la pantalla.
class IosBackGestureController {
  IosBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
    required this.settle,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final bool Function() getIsActive;
  final bool Function() getIsCurrent;

  /// Lo que tarda en terminar al soltar (0 con reducir movimiento).
  final Duration settle;

  /// El dedo se ha movido [delta] (fracción del ancho; positivo = hacia la
  /// derecha, que quita la pantalla).
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// El dedo se suelta. **Solo cuenta la mitad:** pasada, la pantalla vuelve;
  /// antes, se queda. Si mientras tanto la ruta ya se ha quitado por otro
  /// camino, termina de irse; si sigue en la pila, se queda.
  void dragEnd() {
    final isCurrent = getIsCurrent();
    final bool stay = isCurrent ? controller.value > 0.5 : getIsActive();

    if (stay) {
      controller.animateTo(
        1.0,
        duration: settle,
        curve: UnaMotion.standardCurve,
      );
    } else {
      // Quita la ruta por el camino de siempre (observadores, resultado…).
      if (isCurrent) navigator.pop();
      // El `pop` puede haber terminado en el acto si ya estaba en su destino.
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: settle,
          curve: UnaMotion.standardCurve,
        );
      }
    }

    if (controller.isAnimating) {
      // El gesto sigue "en curso" hasta que termina el movimiento, para que la
      // transición no cambie de curva a medio camino.
      late AnimationStatusListener onStatus;
      onStatus = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(onStatus);
      };
      controller.addStatusListener(onStatus);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
