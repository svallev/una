import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../data/platform/viewer_rotation.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/edit_task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_on_signal.dart';
import '../../ui/focus_ring.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';
import '../attachments/attachment_health.dart';
import '../attachments/image_viewer_screen.dart';
import '../attachments/keep_screen_on_controller.dart';
import '../attachments/missing_attachment_card.dart';
import '../attachments/task_image.dart';
import '../complete/complete_task_action.dart';
import '../complete/completion_controller.dart';
import '../complete/hold_to_complete_button.dart';
import '../delete/delete_task_action.dart';
import '../delete/deletion_controller.dart';
import '../editor/task_editor_screen.dart';
import '../menu/menu_sheet.dart';
import '../task_list/task_list_screen.dart';

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
    Future<void> openViewer() => _openViewer(context, ref, task);
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

    final attachment = task.attachment;
    final isPhoto = attachment?.isPhoto ?? false;
    // Falta la versión completa: "Adjunto no disponible" (CA-007-19).
    // La cara de completar y eliminar (faceOnly) no comprueba: al eliminar,
    // los archivos ya se han borrado y se ve la imagen que ya estaba cargada.
    final missing =
        attachment != null &&
        !faceOnly &&
        !chromeOnly &&
        ref.watch(attachmentHealthProvider(attachment)).health ==
            AttachmentHealth.missing;
    final showImage = attachment != null && !missing;
    final kind = isPhoto ? l10n.attachmentPhoto : l10n.attachmentImage;

    /// La tarea es un único nodo del lector; con imagen, imagen y pie juntos
    /// y sin decir "imagen" dos veces (CA-007-21).
    Widget taskNode(Widget child) => FocusOnSignal(
      signal: focusSignal,
      child: Semantics(
        label: l10n.currentTaskSemantics(switch (attachment) {
          null => text,
          _ when missing => l10n.a11yAttachmentMissing(
            text.isEmpty ? kind : text,
          ),
          _ when text.isEmpty => kind,
          _ => isPhoto ? l10n.a11yWithPhoto(text) : l10n.a11yWithImage(text),
        }),
        // Papel de imagen, salvo si la lectura ya acaba en "imagen".
        image: isPhoto && showImage,
        // Activarla abre el visor (CA-007-09/21).
        hint: showImage && !faceOnly ? l10n.imageOpenHint : null,
        onTap: showImage && !faceOnly ? openViewer : null,
        // También se completa (CA-003-07) y se elimina (CA-004-10) desde la
        // tarea.
        customSemanticsActions: faceOnly
            ? null
            : {
                CustomSemanticsAction(label: l10n.completeA11yAction): complete,
                CustomSemanticsAction(label: l10n.deleteA11yAction): delete,
              },
        excludeSemantics: true,
        child: child,
      ),
    );

    final noteText = MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(maxScaleFactor: maxNoteTextScale),
      ),
      child: taskNode(
        LayoutBuilder(
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
    );

    // Con imagen, logotipo y menú llevan fondo blanco (CA-007-08, prototipo
    // `chromeBg`); el logotipo, con 8 px a cada lado sin moverse.
    const logoPad = UnaSpace.s;
    final Widget wordmark = !showImage
        ? const Wordmark()
        : Transform.translate(
            offset: const Offset(-logoPad, 0),
            child: const ColoredBox(
              color: UnaColors.surface,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: logoPad),
                child: Wordmark(),
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
                  wordmark,
                  const Spacer(),
                  _Order(
                    1,
                    child: SquareIconButton(
                      icon: UnaIcons.menu,
                      label: l10n.menuButton,
                      fill: showImage
                          ? UnaColors.surface
                          : UnaPalettes.classic[task.colorKey %
                                UnaPalettes.classic.length],
                      onPressed: openMenu,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // Con imagen, la tarea está detrás, a sangre.
              child: showImage
                  ? const SizedBox.shrink()
                  : missing
                  ? _Order(
                      0,
                      child: Center(
                        child: SingleChildScrollView(
                          child: chromeOnly
                              ? const SizedBox.shrink()
                              : _MissingAttachment(
                                  task: task,
                                  header: faceOnly
                                      ? (c) => c
                                      : (c) => taskNode(c),
                                  interactive: !faceOnly,
                                ),
                        ),
                      ),
                    )
                  // La zona desplazable es su propio nodo: el orden va aquí.
                  : _Order(
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
            : StickyNote(
                colorKey: task.colorKey,
                child: !showImage
                    ? content
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          _Order(
                            0,
                            child: taskNode(
                              _ImageLayer(
                                onOpen: faceOnly ? null : openViewer,
                                child: TaskImage(
                                  attachment: attachment,
                                  caption: text,
                                ),
                              ),
                            ),
                          ),
                          content,
                        ],
                      ),
              ),
      ),
    );
    if (faceOnly || chromeOnly) return ExcludeSemantics(child: screen);
    // Con imagen, la pantalla no se apaga mientras se usa (CA-007-12).
    return KeepScreenOnWhileVisible(enabled: showImage, child: screen);
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
    MenuAction.delete || MenuAction.allTasks => null,
  };
  if (action == MenuAction.allTasks) return openTaskList(context, ref);
  if (editor == null) return confirmAndDeleteTask(context, ref, task);
  await Navigator.of(context).push(TaskEditorScreen.route(context, editor));
}

/// "Adjunto no disponible" en la pantalla principal, con su única acción
/// (CA-007-19).
class _MissingAttachment extends ConsumerWidget {
  const _MissingAttachment({
    required this.task,
    required this.header,
    required this.interactive,
  });

  final Task task;
  final Widget Function(Widget) header;
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MissingAttachmentCard(
      text: task.text ?? '',
      header: header,
      onRemove: interactive ? () => _remove(context, ref) : () {},
      onDelete: interactive
          ? () => confirmAndDeleteTask(context, ref, task)
          : () {},
    );
  }

  bool _busy(WidgetRef ref) =>
      ref.read(completionProvider).busy || ref.read(deletionProvider).busy;

  /// "Quitar adjunto" (con texto).
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    if (_busy(ref)) return;
    final l10n = AppLocalizations.of(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    final saved = await _save(
      context,
      ref,
      () => ref
          .read(editTaskProvider)
          .call(task, task.text ?? '', attachment: const RemoveAttachment()),
    );
    if (!saved) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        l10n.a11yAttachmentRemoved,
        direction,
      ),
    );
  }

  Future<bool> _save(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() write,
  ) async {
    try {
      await write();
      // El foco vuelve a la tarea, ya sin la tarjeta.
      ref.read(screenFocusProvider.notifier).signal();
      return true;
    } on Object catch (e) {
      if (!context.mounted) return false;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.editorSaveError,
          ),
        ),
      );
      return false;
    }
  }
}

/// Visor de la imagen (CA-007-09); al cerrarlo, el foco vuelve a la tarea.
Future<void> _openViewer(BuildContext context, WidgetRef ref, Task task) async {
  final attachment = task.attachment;
  // Nunca durante completar o eliminar (CA-003-09, CA-004-05), ni con otra
  // pantalla encima: un toque o un giro más no abre un segundo visor.
  // `isCurrent` se consulta al navegador en el momento, no en la última
  // construcción.
  if (attachment == null ||
      !(ModalRoute.of(context)?.isCurrent ?? true) ||
      ref.read(completionProvider).busy ||
      ref.read(deletionProvider).busy) {
    return;
  }
  await Navigator.of(context)
      .push(ImageViewerScreen.route(context, attachment));
  if (!context.mounted) return;
  ref.read(screenFocusProvider.notifier).signal();
}

/// Orden de foco de la spec 001 §6: tarea → menú → completar (lector de
/// pantalla y teclado), aunque el menú esté arriba en pantalla.
/// La imagen de la tarea actual: tocarla, o poner el móvil en horizontal
/// mientras se ve, abre el visor (CA-007-09 y CA-007-11). Con
/// teclado o interruptores se llega con Tab y se abre con Intro o Espacio, con
/// el anillo por dentro del borde (WCAG 2.1.1 y 2.4.7). La lectura y las
/// acciones del lector son las del nodo de la tarea, sin añadir nada.
class _ImageLayer extends StatefulWidget {
  const _ImageLayer({required this.onOpen, required this.child});

  final VoidCallback? onOpen;
  final Widget child;

  @override
  State<_ImageLayer> createState() => _ImageLayerState();
}

class _ImageLayerState extends State<_ImageLayer> {
  bool _focused = false;
  bool? _watching;
  late final StreamSubscription<void> _landscape = ViewerRotation.landscape
      .listen((_) {
        if (mounted && _watching == true) widget.onOpen?.call();
      });

  /// Solo se vigila el giro con la tarea a la vista (no bajo el editor, el
  /// menú o el visor).
  void _updateWatch() {
    final on =
        widget.onOpen != null && (ModalRoute.isCurrentOf(context) ?? true);
    if (on == _watching) return;
    _watching = on;
    unawaited(ViewerRotation.watchLandscape(on));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _landscape; // Se suscribe al montarse.
    _updateWatch();
  }

  @override
  void didUpdateWidget(_ImageLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateWatch();
  }

  @override
  void dispose() {
    unawaited(_landscape.cancel());
    if (_watching == true) unawaited(ViewerRotation.watchLandscape(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onOpen = widget.onOpen;
    return FocusableActionDetector(
      enabled: onOpen != null,
      includeFocusSemantics: false,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onOpen?.call();
            return null;
          },
        ),
      },
      child: FocusRing(
        visible: _focused,
        inside: true,
        child: GestureDetector(
          // Toda la imagen, cargada o no.
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: widget.child,
        ),
      ),
    );
  }
}

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
