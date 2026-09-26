import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../ui/focus_ring.dart';
import '../../ui/una_icons.dart';

/// Callbacks del arrastre de una fila (spec 006, CA-006-04/05/11).
class RowDragCallbacks {
  const RowDragCallbacks({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// [context] es el de la fila (su posición en la lista); [global], el punto
  /// donde se puso el dedo.
  final void Function(BuildContext context, Offset global) onStart;
  final void Function(Offset global) onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// Una fila del listado, como `.li` del prototipo: nota del color de la
/// tarea, borde de 3 px, sombra dura; asa (salvo la primera), texto y los
/// botones Editar y Eliminar.
///
/// Para el lector de pantalla es **un único elemento** (CA-006-18): el texto
/// de [semanticsLabel], activar = editar y las acciones de [actions]. Los
/// botones no se leen por separado.
class TaskListRow extends StatelessWidget {
  const TaskListRow({
    super.key,
    required this.task,
    required this.first,
    required this.palette,
    this.semanticsLabel,
    this.editHint,
    this.actions = const {},
    this.onEdit,
    this.onDelete,
    this.onMove,
    this.onRowTap,
    this.drag,
    this.lifted = false,
    this.reduced = false,
    this.shadow = UnaShadows.listItem,
  });

  final Task task;

  /// La tarea actual: texto más grande y sin asa (CA-006-02).
  final bool first;
  final List<Color> palette;

  final String? semanticsLabel;
  final String? editHint;
  final Map<CustomSemanticsAction, VoidCallback> actions;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Tocar el asa (sin arrastrar) o activarla con el teclado (DEV-28).
  final VoidCallback? onMove;

  /// Cada toque sobre la fila fuera de los botones (doble toque, CA-006-13).
  final VoidCallback? onRowTap;
  final RowDragCallbacks? drag;

  /// La fila levantada: inclinada (salvo con [reduced]) y con más sombra.
  final bool lifted;
  final bool reduced;

  /// Sombra actual (la anima quien la pinta: levantar y resaltar).
  final BoxShadow shadow;

  static const _gap = UnaSpace.xxs;

  @override
  Widget build(BuildContext context) {
    final given = this.drag;
    // El arrastre siempre se mide con la fila entera, también desde el asa.
    final drag = given == null
        ? null
        : RowDragCallbacks(
            onStart: (_, global) => given.onStart(context, global),
            onUpdate: given.onUpdate,
            onEnd: given.onEnd,
            onCancel: given.onCancel,
          );
    final text = Text(
      task.text ?? '',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: first
          ? const TextStyle(
              fontFamily: UnaFonts.display,
              fontSize: UnaFontSizes.listFirst,
              fontWeight: UnaFontWeights.extrabold,
              height: 1.1,
              letterSpacing: UnaLetterSpacing.tight * UnaFontSizes.listFirst,
              color: UnaColors.ink,
            )
          : const TextStyle(
              fontFamily: UnaFonts.display,
              fontSize: UnaFontSizes.listItem,
              fontWeight: UnaFontWeights.semibold,
              height: 1.3,
              color: UnaColors.ink,
            ),
    );
    Widget body = Container(
      decoration: BoxDecoration(
        color: palette[task.colorKey % palette.length],
        border: const Border.fromBorderSide(
          BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
        ),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(UnaSpace.xs),
      child: Row(
        children: [
          if (!first)
            _RowButton(onPressed: onMove, drag: drag, child: const _Grip()),
          if (!first) const SizedBox(width: _gap),
          Expanded(
            child: Padding(
              padding: first
                  ? const EdgeInsets.fromLTRB(
                      UnaSpace.sm + 1,
                      UnaSpace.sm,
                      UnaSpace.xs,
                      UnaSpace.sm,
                    )
                  : const EdgeInsets.symmetric(
                      vertical: UnaSpace.sm,
                      horizontal: UnaSpace.xs,
                    ),
              child: text,
            ),
          ),
          const SizedBox(width: _gap),
          _RowButton(
            onPressed: onEdit,
            child: const UnaIcon(UnaIcons.edit, size: UnaSizes.listIcon),
          ),
          const SizedBox(width: _gap),
          _RowButton(
            onPressed: onDelete,
            child: const UnaIcon(UnaIcons.trash, size: UnaSizes.listIcon),
          ),
        ],
      ),
    );
    if (lifted && !reduced) {
      body = Transform.rotate(
        angle: UnaMotion.dragTilt * math.pi / 180,
        child: body,
      );
    }
    // Toques y pulsación larga en el resto de la fila (CA-006-05, CA-006-13).
    // Fuera de la semántica: el lector usa las acciones de la fila.
    if (drag != null && !first) {
      body = GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapUp: onRowTap == null ? null : (_) => onRowTap!(),
        onLongPressStart: (d) => drag.onStart(context, d.globalPosition),
        onLongPressMoveUpdate: (d) => drag.onUpdate(d.globalPosition),
        onLongPressEnd: (_) => drag.onEnd(),
        child: body,
      );
    } else if (onRowTap != null) {
      body = GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapUp: (_) => onRowTap!(),
        child: body,
      );
    }
    if (drag != null) {
      // Si el sistema cancela el gesto (llamada, aviso), no se guarda nada
      // (CA-006-11): se ve antes que el final que dan los reconocedores.
      body = Listener(onPointerCancel: (_) => drag.onCancel(), child: body);
    }
    final label = semanticsLabel;
    if (label == null) return ExcludeSemantics(child: body);
    return Semantics(
      container: true,
      label: label,
      onTap: onEdit,
      onTapHint: editHint,
      customSemanticsActions: actions,
      excludeSemantics: true,
      child: body,
    );
  }
}

/// Botón cuadrado de la fila (asa, Editar, Eliminar): 48 dp, transparente, con
/// el anillo de foco del teclado. Sin nodo propio para el lector: sus funciones
/// son acciones de la fila (CA-006-18). El asa además se arrastra (6 px, al
/// instante, CA-006-04) y compite con su propio toque (abre "Mover").
class _RowButton extends StatefulWidget {
  const _RowButton({required this.onPressed, required this.child, this.drag});

  final VoidCallback? onPressed;
  final Widget child;
  final RowDragCallbacks? drag;

  @override
  State<_RowButton> createState() => _RowButtonState();
}

class _RowButtonState extends State<_RowButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final drag = widget.drag;
    final onPressed = widget.onPressed;
    Widget button = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: drag == null
          ? null
          : (d) => drag.onStart(context, d.globalPosition),
      onVerticalDragUpdate: drag == null
          ? null
          : (d) => drag.onUpdate(d.globalPosition),
      onVerticalDragEnd: drag == null ? null : (_) => drag.onEnd(),
      onVerticalDragCancel: drag?.onCancel,
      child: SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: Center(
          child: FocusRing(visible: _focused, child: widget.child),
        ),
      ),
    );
    if (drag != null) {
      // Umbral del prototipo (6 px) en lugar del de desplazamiento (18).
      final mq = MediaQuery.of(context);
      button = MediaQuery(
        data: mq.copyWith(
          gestureSettings: const DeviceGestureSettings(
            touchSlop: UnaMotion.dragThreshold,
          ),
        ),
        child: button,
      );
    }
    return FocusableActionDetector(
      enabled: onPressed != null,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed?.call();
            return null;
          },
        ),
      },
      child: button,
    );
  }
}

/// Asa de arrastre del prototipo: 2 × 3 cuadrados de 3,4 en una caja de 24.
class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: UnaSizes.listGrip,
    child: CustomPaint(painter: _GripPainter()),
  );
}

class _GripPainter extends CustomPainter {
  const _GripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.shortestSide / 24);
    final paint = Paint()..color = UnaColors.ink;
    for (final x in const [7.0, 13.6]) {
      for (final y in const [4.0, 10.3, 16.6]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 3.4, 3.4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) => false;
}
