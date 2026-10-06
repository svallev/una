import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Reglas del gesto del carrusel de fotos (plan 016 §5, CA-016-09/10).
///
/// Los números **no** son tokens: son del comportamiento del gesto, no del
/// diseño, y los comparten el reconocedor y sus tests.
abstract final class PhotoSwipe {
  /// Recorrido (en dp) tras el cual se decide el eje del gesto. Nunca pasa del
  /// `touchSlop` del sistema: el `Scrollable` de la foto acepta su arrastre
  /// vertical al pasar ese umbral y la decisión nunca puede llegar después.
  static const double axisSlop = 16;

  /// El gesto es horizontal si `|dx| > axisRatio · |dy|` al decidir el eje.
  static const double axisRatio = 1.5;

  /// Parte del ancho que hay que recorrer para cambiar de foto.
  static const double changeFraction = 0.18;

  /// Velocidad (dp/s) que cambia de foto aunque no se llegue a [changeFraction].
  static const double flickVelocity = 700;

  /// Recorrido mínimo (dp) para que valga un gesto rápido.
  static const double flickMinDistance = 16;

  /// Recorrido tras el que se decide el eje con este `touchSlop` efectivo.
  static double decisionSlop(double touchSlop) => math.min(axisSlop, touchSlop);

  /// `touchSlop` efectivo de [context]: el del sistema o el de Flutter.
  static double touchSlopOf(BuildContext context) =>
      MediaQuery.gestureSettingsOf(context).touchSlop ?? kTouchSlop;

  /// Eje de un gesto que ya ha recorrido [dx], [dy] (se llama al decidir).
  static Axis axisFor(double dx, double dy) =>
      dx.abs() > axisRatio * dy.abs() ? Axis.horizontal : Axis.vertical;

  /// Qué hace un swipe horizontal al soltarlo: [dx] es el recorrido total
  /// desde que se puso el dedo, [velocity] la velocidad horizontal al soltar y
  /// [width] el ancho del carrusel. `null`: la foto vuelve a su sitio. Un
  /// gesto a la izquierda (dx negativo) es la foto siguiente.
  static PhotoSwipeChange? outcome({
    required double dx,
    required double velocity,
    required double width,
  }) {
    final far = dx.abs() > changeFraction * width;
    final fast =
        velocity.abs() >= flickVelocity &&
        dx.abs() >= flickMinDistance &&
        // En el sentido del gesto: un tirón hacia atrás al final no cuenta.
        velocity.sign == dx.sign;
    if (!far && !fast) return null;
    return dx < 0 ? PhotoSwipeChange.next : PhotoSwipeChange.previous;
  }
}

/// Foto a la que lleva un swipe.
enum PhotoSwipeChange { next, previous }

/// Reconocedor propio del swipe horizontal del carrusel (plan 016 §5).
///
/// Sigue **todos** los dedos y reparte el gesto por su dirección: si es
/// horizontal con un dedo, **acepta** y avisa del desplazamiento; si es
/// vertical, **se rechaza** y el `Scrollable` de la foto gana por su cuenta.
/// El eje decidido no cambia hasta que se levantan todos los dedos, con dos
/// dedos nunca cambia de foto (un segundo dedo cancela el swipe en curso y el
/// que queda tras un pellizco no inicia nada) y un gesto que empieza en la
/// zona de borde que reserva el sistema para "volver" no es suyo.
class PhotoSwipeRecognizer extends OneSequenceGestureRecognizer {
  PhotoSwipeRecognizer({super.debugOwner, super.supportedDevices});

  /// Un swipe horizontal ha sido aceptado.
  VoidCallback? onStart;

  /// Desplazamiento horizontal (dp) desde que se aceptó: negativo hacia la
  /// izquierda. La foto sigue al dedo con él.
  ValueChanged<double>? onUpdate;

  /// Se suelta el dedo: [change] es la foto a la que se va o `null` si vuelve
  /// a su sitio; [velocity] es la velocidad horizontal (dp/s) al soltar.
  void Function(PhotoSwipeChange? change, double velocity)? onEnd;

  /// El swipe se cancela (segundo dedo o cancelación del sistema): la foto
  /// vuelve a su sitio.
  VoidCallback? onCancel;

  /// Ancho del carrusel (dp), para el umbral del 18 %.
  double width = 0;

  /// `touchSlop` efectivo, ver [PhotoSwipe.decisionSlop].
  double touchSlop = kTouchSlop;

  /// Zonas que el sistema reserva para el gesto de volver (`systemGestureInsets`
  /// de la ventana).
  EdgeInsets systemGestureInsets = EdgeInsets.zero;

  /// Ancho de la **ventana** (dp). El borde se mide con la posición global
  /// frente a él y no frente al carrusel: en tablets el marco se limita a
  /// 600 dp y se centra (DEV-51).
  double windowWidth = double.infinity;

  final Set<int> _pointers = <int>{};
  Offset _down = Offset.zero;
  Offset _last = Offset.zero;
  VelocityTracker? _tracker;

  /// Eje decidido; no cambia hasta que no queda ningún dedo.
  Axis? _axis;

  /// Con dos dedos o desde el borde del sistema: no inicia nada hasta que no
  /// haya ninguno.
  bool _blocked = false;
  bool _swiping = false;
  double _origin = 0;

  @override
  String get debugDescription => 'photo swipe';

  bool _startsInSystemEdge(Offset position) =>
      position.dx < systemGestureInsets.left ||
      position.dx > windowWidth - systemGestureInsets.right;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _axis = null;
      _blocked = false;
      _swiping = false;
      _down = event.position;
      _last = event.position;
      _tracker = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
      if (_startsInSystemEdge(event.position)) {
        _blocked = true;
        resolve(GestureDisposition.rejected);
      }
      return;
    }
    // Un segundo dedo: nunca se cambia de foto; si había un swipe en curso se
    // cancela y empieza el pellizco (que ve los dedos por su cuenta).
    _block();
    resolve(GestureDisposition.rejected);
  }

  void _block() {
    _blocked = true;
    if (_swiping) {
      _swiping = false;
      onCancel?.call();
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_pointers.contains(event.pointer)) return;
    if (event is PointerMoveEvent) {
      _move(event);
    } else if (event is PointerUpEvent) {
      _up(event);
    } else if (event is PointerCancelEvent) {
      _block();
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _move(PointerMoveEvent event) {
    if (_blocked || _pointers.length != 1) return;
    _last = event.position;
    _tracker?.addPosition(event.timeStamp, event.position);
    final moved = _last - _down;
    if (_axis == null &&
        moved.distance >= PhotoSwipe.decisionSlop(touchSlop) &&
        moved.distance > 0) {
      _axis = PhotoSwipe.axisFor(moved.dx, moved.dy);
      if (_axis == Axis.horizontal) {
        resolve(GestureDisposition.accepted);
        // Sin otro reconocedor en la arena (una foto más baja que la pantalla
        // no se desplaza) ya ganó por defecto al poner el dedo y no habrá
        // `acceptGesture`: se empieza aquí.
        _beginSwipe();
      } else {
        // El desplazamiento vertical es del `Scrollable` de la foto.
        resolve(GestureDisposition.rejected);
      }
    }
    if (_swiping) onUpdate?.call(_last.dx - _origin);
  }

  void _up(PointerUpEvent event) {
    if (_swiping && !_blocked && _pointers.length == 1) {
      _swiping = false;
      final velocity = _tracker?.getVelocity().pixelsPerSecond.dx ?? 0;
      onEnd?.call(
        PhotoSwipe.outcome(
          dx: _last.dx - _down.dx,
          velocity: velocity,
          width: width,
        ),
        velocity,
      );
    }
  }

  @override
  void acceptGesture(int pointer) {
    // También se llama al ganar por defecto (un toque sin eje decidido): ahí
    // no hay swipe, tocar una foto no hace nada.
    _beginSwipe();
  }

  void _beginSwipe() {
    if (_axis != Axis.horizontal || _blocked || _pointers.length != 1) return;
    if (_swiping) return;
    _swiping = true;
    _origin = _last.dx;
    onStart?.call();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // Se levantaron todos los dedos: el próximo gesto empieza de cero.
    _pointers.clear();
    _axis = null;
    _blocked = false;
    _swiping = false;
    _tracker = null;
  }

  @override
  void stopTrackingPointer(int pointer) {
    _pointers.remove(pointer);
    super.stopTrackingPointer(pointer);
  }
}

/// Envuelve el carrusel con el [PhotoSwipeRecognizer] ya configurado con el
/// `touchSlop`, los márgenes de gestos y el ancho de ventana de la pantalla.
/// Cubre **todo** el carrusel, también bajo el pie y los puntos (que van en
/// `IgnorePointer`).
class PhotoSwipeDetector extends StatelessWidget {
  const PhotoSwipeDetector({
    super.key,
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
  });

  final Widget child;
  final VoidCallback? onStart;
  final ValueChanged<double>? onUpdate;
  final void Function(PhotoSwipeChange? change, double velocity)? onEnd;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final touchSlop = PhotoSwipe.touchSlopOf(context);
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final view = View.of(context);
    final windowWidth = view.physicalSize.width / view.devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) => RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          PhotoSwipeRecognizer:
              GestureRecognizerFactoryWithHandlers<PhotoSwipeRecognizer>(
                PhotoSwipeRecognizer.new,
                (recognizer) {
                  recognizer
                    ..touchSlop = touchSlop
                    ..systemGestureInsets = insets
                    ..windowWidth = windowWidth
                    ..width = constraints.maxWidth
                    ..onStart = onStart
                    ..onUpdate = onUpdate
                    ..onEnd = onEnd
                    ..onCancel = onCancel;
                },
              ),
        },
        child: child,
      ),
    );
  }
}
