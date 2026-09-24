import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey;

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/focus_ring.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';

/// Pantalla principal: solo la tarea actual, a pantalla completa (R6, CA-001-06/07).
class CurrentTaskScreen extends StatelessWidget {
  const CurrentTaskScreen({super.key, required this.task});

  final Task task;

  /// Límite de escala de texto para la nota (docs/design/tokens.md).
  static const maxNoteTextScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = task.text ?? '';
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: StickyNote(
          colorKey: task.colorKey,
          child: SafeArea(
            child: Padding(
              // Abajo, el margen del prototipo (~38).
              padding: const EdgeInsets.fromLTRB(
                UnaSpace.l,
                UnaSpace.l,
                UnaSpace.l,
                UnaSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Wordmark(),
                      const Spacer(),
                      // Abre el menú a partir de la spec 005.
                      _Order(
                        1,
                        child: _SquareIconButton(
                          icon: UnaIcons.menu,
                          label: l10n.menuButton,
                          fill:
                              UnaPalettes.classic[task.colorKey %
                                  UnaPalettes.classic.length],
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    // La zona desplazable es su propio nodo: el orden va aquí.
                    child: _Order(
                      0,
                      child: Center(
                        child: SingleChildScrollView(
                          child: MediaQuery(
                            data: mq.copyWith(
                              textScaler: mq.textScaler.clamp(
                                maxScaleFactor: maxNoteTextScale,
                              ),
                            ),
                            child: Semantics(
                              label: l10n.currentTaskSemantics(text),
                              excludeSemantics: true,
                              child: LayoutBuilder(
                                builder: (context, constraints) => SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    text,
                                    style: UnaTheme.fitNoteText(
                                      text,
                                      maxWidth: constraints.maxWidth,
                                      textScaler: MediaQuery.textScalerOf(
                                        context,
                                      ),
                                      textDirection: Directionality.of(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Completar (mantener pulsado) llega con la spec 003.
                  _Order(
                    2,
                    child: BrutalButton(
                      label: l10n.completeButton,
                      icon: UnaIcons.check,
                      height: UnaSizes.holdButton,
                      fontSize: UnaFontSizes.button,
                      singleLine: true,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Orden de foco de la spec 001 §6: tarea → menú → completar (lector de
/// pantalla y teclado), aunque el menú esté arriba en pantalla.
class _Order extends StatelessWidget {
  const _Order(this.order, {required this.child});
  final double order;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    sortKey: OrdinalSortKey(order),
    child: FocusTraversalOrder(order: NumericFocusOrder(order), child: child),
  );
}

/// Botón cuadrado de barra del prototipo (`.sq`): 46 px, sombra de 3 px y
/// hundimiento al pulsar. Zona táctil de 48 dp (Android).
class _SquareIconButton extends StatefulWidget {
  const _SquareIconButton({
    required this.icon,
    required this.label,
    required this.fill,
    required this.onPressed,
  });
  final UnaIconData icon;
  final String label;

  /// En Flutter la sombra también se pinta bajo la caja: sin relleno se vería
  /// un cuadrado negro (en el CSS del prototipo, la sombra solo va por fuera).
  final Color fill;
  final VoidCallback onPressed;

  @override
  State<_SquareIconButton> createState() => _SquareIconButtonState();
}

class _SquareIconButtonState extends State<_SquareIconButton> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const sink = UnaShadows.iconButton;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Center(
              child: FocusRing(
                visible: _focused,
                child: AnimatedContainer(
                  duration: UnaMotion.press,
                  transform: _down
                      ? Matrix4.translationValues(
                          sink.offset.dx,
                          sink.offset.dy,
                          0,
                        )
                      : Matrix4.identity(),
                  width: UnaSizes.iconButton,
                  height: UnaSizes.iconButton,
                  decoration: BoxDecoration(
                    border: const Border.fromBorderSide(
                      BorderSide(
                        color: UnaColors.ink,
                        width: UnaBorders.strongWidth,
                      ),
                    ),
                    boxShadow: [if (!_down) sink],
                    color: widget.fill,
                  ),
                  child: Center(child: UnaIcon(widget.icon)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
