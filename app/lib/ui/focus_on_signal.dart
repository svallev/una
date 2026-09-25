import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lleva el foco (teclado y lector de pantalla) a [child] cada vez que cambia
/// [signal]. No al montarse: la pantalla puede montarse tapada (spec 003, la
/// siguiente tarea aparece bajo la enhorabuena) y el foco se pide al descubrirla.
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
  void didUpdateWidget(FocusOnSignal old) {
    super.didUpdateWidget(old);
    if (widget.signal == old.signal) return;
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
