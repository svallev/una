import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_on_signal.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';
import '../complete/complete_task_action.dart';
import '../complete/completion_controller.dart';
import '../complete/hold_to_complete_button.dart';
import '../delete/delete_task_action.dart';
import '../delete/deletion_controller.dart';
import '../editor/task_editor_screen.dart';
import '../menu/menu_sheet.dart';

/// Pantalla principal: solo la tarea actual, a pantalla completa (R6, CA-001-06/07).
class CurrentTaskScreen extends ConsumerWidget {
  const CurrentTaskScreen({
    super.key,
    required this.task,
    this.faceOnly = false,
    this.chromeOnly = false,
    this.showLogoAndMenu = true,
    this.ctaHide,
    this.focusSignal = 0,
  }) : assert(!(faceOnly && chromeOnly));

  final Task task;

  /// Solo la nota (color y texto), sin logotipo, menú ni botón, que ocupan su
  /// sitio pero no se ven: es lo que se rompe en dos al completar (spec 003).
  final bool faceOnly;

  /// Solo el logotipo, el menú y el botón, sin la nota ni su texto (fondo
  /// transparente): lo que queda encima mientras se arruga (spec 004).
  final bool chromeOnly;

  /// Con [chromeOnly]: false si detrás está "Todo hecho.", que ya lleva su
  /// logotipo y no tiene menú.
  final bool showLogoAndMenu;

  /// Oculta el botón de completar (`.cta.hide`: baja 16 px y se desvanece).
  final Animation<double>? ctaHide;

  /// Al cambiar, el foco va a la tarea (tras completar la anterior, CA-003-07).
  final int focusSignal;

  /// Límite de escala de texto para la nota (docs/design/tokens.md).
  static const maxNoteTextScale = 1.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = task.text ?? '';
    final mq = MediaQuery.of(context);
    Future<bool> complete() => completeTask(context, ref, task);
    Future<void> openMenu() => _openMenu(context, ref);
    Future<void> delete() => confirmAndDeleteTask(context, ref, task);
    Widget hidden(Widget child) => Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: child,
    );
    Widget chrome(Widget child) => faceOnly ? hidden(child) : child;
    final header = chromeOnly && !showLogoAndMenu ? hidden : chrome;
    Widget cta(Widget child) {
      final hide = ctaHide;
      if (hide == null) return chrome(child);
      // Prototipo: `.cta.hide{opacity:0;transform:translateY(16px)}`.
      return AnimatedBuilder(
        animation: hide,
        builder: (context, child) => Opacity(
          opacity: 1 - hide.value,
          child: Transform.translate(
            // Con "reducir movimiento", solo se desvanece (P6).
            offset: Offset(
              0,
              MediaQuery.disableAnimationsOf(context)
                  ? 0
                  : UnaSpace.m * hide.value,
            ),
            child: child,
          ),
        ),
        child: chrome(child),
      );
    }

    final noteText = MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(maxScaleFactor: maxNoteTextScale),
      ),
      child: FocusOnSignal(
        signal: focusSignal,
        child: Semantics(
          label: l10n.currentTaskSemantics(text),
          // También se completa (CA-003-07) y se elimina (CA-004-10) desde la
          // tarea.
          customSemanticsActions: faceOnly
              ? null
              : {
                  CustomSemanticsAction(label: l10n.completeA11yAction):
                      complete,
                  CustomSemanticsAction(label: l10n.deleteA11yAction): delete,
                },
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: double.infinity,
              child: Text(
                text,
                style: UnaTheme.fitNoteText(
                  text,
                  maxWidth: constraints.maxWidth,
                  textScaler: MediaQuery.textScalerOf(context),
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final content = SafeArea(
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
            header(
              Row(
                children: [
                  const Wordmark(),
                  const Spacer(),
                  _Order(
                    1,
                    child: SquareIconButton(
                      icon: UnaIcons.menu,
                      label: l10n.menuButton,
                      fill: UnaPalettes
                          .classic[task.colorKey % UnaPalettes.classic.length],
                      onPressed: openMenu,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // La zona desplazable es su propio nodo: el orden va aquí.
              child: _Order(
                0,
                child: Center(
                  child: SingleChildScrollView(
                    child: chromeOnly ? hidden(noteText) : noteText,
                  ),
                ),
              ),
            ),
            cta(
              _Order(
                2,
                child: HoldToCompleteButton(
                  label: l10n.completeButton,
                  a11yAction: l10n.completeA11yAction,
                  a11yHint: l10n.completeA11yHint,
                  onComplete: complete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final screen = Scaffold(
      backgroundColor: chromeOnly ? Colors.transparent : null,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: chromeOnly
            ? content
            : StickyNote(colorKey: task.colorKey, child: content),
      ),
    );
    return faceOnly || chromeOnly ? ExcludeSemantics(child: screen) : screen;
  }
}

/// Abre el menú (spec 005) y lo que se elija: editar, eliminar o crear.
Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
  // Nunca durante completar o eliminar (CA-003-09, CA-004-05).
  if (ref.read(completionProvider).busy || ref.read(deletionProvider).busy) {
    return;
  }
  final task = ref.read(currentTaskProvider);
  if (task == null) return;
  final pending = await ref.read(taskRepositoryProvider).countPending();
  if (!context.mounted) return;
  final action = await showMenuSheet(context, pendingCount: pending);
  if (!context.mounted || action == null) return;
  final editor = switch (action) {
    MenuAction.edit => TaskEditorScreen(mode: EditorMode.edit, task: task),
    // Color al azar, distinto del de la tarea visible (CA-001-08, CA-002-01).
    MenuAction.newTask => TaskEditorScreen(
      mode: EditorMode.create,
      colorKey: ref
          .read(colorPickerProvider)
          .pick(currentColorKey: task.colorKey),
    ),
    // La confirmación sustituye al menú (CA-004-01).
    MenuAction.delete => null,
  };
  if (editor == null) return confirmAndDeleteTask(context, ref, task);
  await Navigator.of(context).push(TaskEditorScreen.route(context, editor));
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
