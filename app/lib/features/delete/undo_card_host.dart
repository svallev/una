import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'delete_task_action.dart';
import 'undo_card.dart';
import 'undo_controller.dart';

/// Sitio de la card de deshacer en una pantalla (plan 014 §3): la pantalla
/// ([child]) y, encima y abajo, la card cuando la eliminación es de esta
/// pantalla ([host]).
///
/// Para el lector, la pantalla va en su propio nodo con la clave de orden 1 y
/// la card, con la 0: mientras se ve, la card es lo primero que se lee y el
/// orden del resto no cambia (CA-014-16). La pantalla nunca se vuelve a
/// montar al aparecer o desaparecer la card, y la card no depende de la
/// orientación: al girar conserva su nodo, su foco y la pausa (CL-014-8).
///
/// Solo dibuja la card si su `TickerMode` está activo: la pantalla que sale
/// de un `AnimatedSwitcher` no la repite. Publica con [UndoCardScope] si hay
/// card y cuánto mide, para que la pantalla oculte su botón y deje el sitio
/// (CA-014-05).
class UndoCardHost extends ConsumerStatefulWidget {
  const UndoCardHost({
    super.key,
    required this.host,
    required this.child,
    this.onUndo,
  });

  final UndoHost host;
  final Widget child;

  /// "Deshacer". Por defecto, `undoDeletion`: recupera la tarea y lleva el foco
  /// a ella.
  final VoidCallback? onUndo;

  @override
  ConsumerState<UndoCardHost> createState() => _UndoCardHostState();
}

class _UndoCardHostState extends ConsumerState<UndoCardHost> {
  /// Foco de teclado de "Deshacer": vive aquí, no en la card.
  final _focusNode = FocusNode(debugLabel: 'undo');

  /// Alto de la card, medido tras dibujarla.
  double _height = 0;

  void _onHeight(double height) {
    if (!mounted || height == _height) return;
    setState(() => _height = height);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(undoProvider);
    final task = state.task;
    final shown =
        task != null &&
        state.cardVisible &&
        state.host == widget.host &&
        TickerMode.valuesOf(context).enabled;
    final undo = ref.read(undoProvider.notifier);
    // La card desaparece sin deshacer con el foco del teclado en ella (tiempo,
    // otra acción): el foco va a la tarea o al título (CA-014-20). Al deshacer
    // no: allí el foco lo lleva `undoDeletion` a la tarea recuperada.
    ref.listen(undoProvider, (previous, next) {
      if (previous != null &&
          previous.cardVisible &&
          previous.host == widget.host &&
          next.phase == UndoPhase.none &&
          _focusNode.hasFocus) {
        ref.read(screenFocusProvider.notifier).signal();
      }
    });
    return UndoCardScope(
      visible: shown,
      height: shown ? _height : 0,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: const OrdinalSortKey(1),
            child: widget.child,
          ),
          if (shown)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _HeightReporter(
                onHeight: _onHeight,
                child: UndoCard(
                  task: task,
                  serial: state.serial,
                  fraction: () => undo.fraction,
                  onUndo:
                      widget.onUndo ??
                      () => unawaited(undoDeletion(context, ref)),
                  onShown: undo.cardShown,
                  onFocusChanged: undo.focusChanged,
                  onScreenReaderChanged: undo.screenReaderChanged,
                  focusNode: _focusNode,
                  sortKey: const OrdinalSortKey(0),
                  requestsFocus: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Si hay card de deshacer sobre la pantalla y cuánto mide (con el margen
/// inferior del sistema que cubre): la pantalla oculta el botón de ese sitio
/// y deja que lo desplazable acabe encima de la card (CA-014-05).
class UndoCardScope extends InheritedWidget {
  const UndoCardScope({
    super.key,
    required this.visible,
    required this.height,
    required super.child,
  });

  final bool visible;
  final double height;

  /// Sin `UndoCardHost` encima: sin card.
  static ({bool visible, double height}) of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UndoCardScope>();
    return (visible: scope?.visible ?? false, height: scope?.height ?? 0);
  }

  @override
  bool updateShouldNotify(UndoCardScope old) =>
      old.visible != visible || old.height != height;
}

/// Avisa del alto de su hijo cuando cambia, después del fotograma.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
