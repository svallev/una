import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lleva el foco (teclado y lector de pantalla) a [child] cada vez que cambia
/// [signal], y al montarse si ya hubo alguna señal (p. ej., la tarea nueva que
/// aparece al colocarla arriba del todo, spec 002). Si se monta tapada (bajo la
/// enhorabuena, spec 003), está excluida del foco y lo recibe al descubrirse.
class FocusOnSignal extends StatefulWidget {
  const FocusOnSignal({super.key, required this.signal, required this.child});

  final int signal;
  final Widget child;

  @override
  State<FocusOnSignal> createState() => _FocusOnSignalState();
}

class _FocusOnSignalState extends State<FocusOnSignal> {
  // Fuera del recorrido con Tab: solo recibe el foco cuando se pide.
  final _node = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
    if (widget.signal > 0) _requestAfterFrame();
  }

  @override
  void didUpdateWidget(FocusOnSignal old) {
    super.didUpdateWidget(old);
    if (widget.signal != old.signal) _requestAfterFrame();
  }

  void _requestAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _node.requestFocus();
      context.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: widget.child);
}
