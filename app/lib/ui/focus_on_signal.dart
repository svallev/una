import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'focus_ring.dart';

/// Lleva el foco (teclado y lector de pantalla) a [child] cada vez que cambia
/// [signal], y al montarse si ya hubo alguna señal (p. ej., la tarea nueva que
/// aparece al colocarla arriba del todo, spec 002). Si se monta tapada (bajo la
/// enhorabuena, spec 003), está excluida del foco y lo recibe al descubrirse.
///
/// Con [suspended] no pide el foco, ni al montarse ni con una señal nueva: la
/// card de deshacer se lo lleva y nada puede competir con ella (CA-014-16).
///
/// Por defecto queda **fuera del recorrido con Tab**: solo recibe el foco
/// cuando se pide. La tarea con un grupo de fotos es distinta (spec 016,
/// CA-016-20): es un punto de foco del teclado ([traversable]), lo recibe al
/// abrir en frío ([autofocus]), maneja sus propias teclas ([onKeyEvent]) y
/// dibuja su anillo de foco por dentro de [ring] (blanco y negro, para verse
/// sobre cualquier foto).
class FocusOnSignal extends StatefulWidget {
  const FocusOnSignal({
    super.key,
    required this.signal,
    required this.child,
    this.suspended = false,
    this.traversable = false,
    this.autofocus = false,
    this.onKeyEvent,
    this.ring,
  });

  final int signal;
  final Widget child;

  /// Mientras es true, no pide el foco.
  final bool suspended;

  /// Entra en el recorrido con Tab y las flechas del foco.
  final bool traversable;

  /// Pide el foco al montarse aunque no haya señal (abrir en frío con teclado
  /// físico). No lo pide con [suspended].
  final bool autofocus;

  /// Teclas que maneja el elemento con el foco puesto en él.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Si no es null, el anillo de foco por dentro de este margen (el del
  /// sistema: recortes y barras no lo tapan) mientras el foco se muestra.
  final EdgeInsets? ring;

  @override
  State<FocusOnSignal> createState() => _FocusOnSignalState();
}

class _FocusOnSignalState extends State<FocusOnSignal> {
  late final _node = FocusNode(
    skipTraversal: !widget.traversable,
    debugLabel: 'task',
  );

  @override
  void initState() {
    super.initState();
    if (widget.signal > 0 && !widget.suspended) _requestAfterFrame();
    if (widget.ring != null) _watchRing();
  }

  @override
  void didUpdateWidget(FocusOnSignal old) {
    super.didUpdateWidget(old);
    _node.skipTraversal = !widget.traversable;
    if (widget.signal != old.signal && !widget.suspended) _requestAfterFrame();
    if ((old.ring != null) != (widget.ring != null)) {
      widget.ring != null ? _watchRing() : _unwatchRing();
    }
  }

  void _watchRing() {
    _node.addListener(_rebuild);
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  void _unwatchRing() {
    _node.removeListener(_rebuild);
    FocusManager.instance.removeHighlightModeListener(_onMode);
  }

  void _onMode(FocusHighlightMode _) => _rebuild();

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _requestAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.suspended) return;
      _node.requestFocus();
      context.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  void dispose() {
    if (widget.ring != null) _unwatchRing();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.ring;
    final child = ring == null
        ? widget.child
        : Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_node.hasFocus && showsFocusHighlight)
                Padding(
                  padding: ring,
                  child: const IgnorePointer(
                    child: FocusRing(
                      visible: true,
                      inside: true,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          );
    // Con un nodo propio, `Focus` no copia su `onKeyEvent` al nodo.
    _node.onKeyEvent = widget.onKeyEvent;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus && !widget.suspended,
      child: child,
    );
  }
}
