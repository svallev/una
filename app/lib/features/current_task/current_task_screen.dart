import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../data/platform/image_rotation.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/edit_task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_on_signal.dart';
import '../../ui/full_width.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';
import '../attachments/attachment_health.dart';
import '../attachments/keep_screen_on_controller.dart';
import '../attachments/missing_attachment_card.dart';
import '../attachments/pdf_labels.dart';
import '../attachments/pdf_position_controller.dart';
import '../attachments/pdf_strip.dart';
import '../attachments/task_image.dart';
import '../attachments/task_pdf.dart';
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
    // La tarea que se completa o se elimina no comprueba: sus archivos ya se
    // han borrado (ADR-0012) y se ve la imagen que ya estaba cargada, también
    // en la pausa antes de romperse.
    final leaving = ref.watch(
      completionProvider.select((c) => c.busy && c.task?.id == task.id),
    );
    final missing =
        attachment != null &&
        !faceOnly &&
        !chromeOnly &&
        !leaving &&
        ref.watch(attachmentHealthProvider(attachment)).health ==
            AttachmentHealth.missing;
    final isPdf = attachment?.isPdf ?? false;
    final showImage = attachment != null && !isPdf && !missing;
    // Con PDF: franja, banda del texto y páginas entre la cabecera y el botón
    // (CA-008-08).
    final showPdf = isPdf && !missing;
    final withAttachment = showImage || showPdf;
    final pdfTitle = pdfName(l10n, attachment?.originalName);
    final pdfBytes = pdfSize(l10n, attachment?.byteSize ?? 0);
    // En horizontal (solo gira la tarea con imagen), solo la imagen y el
    // logotipo: sin menú, botón ni pie (CA-007-11, propietario 2026-09-27).
    final landscape =
        showImage &&
        !faceOnly &&
        !chromeOnly &&
        mq.orientation == Orientation.landscape;
    final kind = isPhoto ? l10n.attachmentPhoto : l10n.attachmentImage;

    /// La tarea es un único nodo del lector; con imagen, imagen y pie juntos
    /// y sin decir "imagen" dos veces (CA-007-21).
    Widget taskNode(Widget child, {_ImageScroll? scroll}) => FocusOnSignal(
      signal: focusSignal,
      child: Semantics(
        // Una imagen más alta que la pantalla se desplaza también con las
        // acciones del lector y de Switch Access (CA-007-09, WCAG 2.1.1).
        onScrollUp: scroll?.canForward ?? false ? scroll!.forward : null,
        onScrollDown: scroll?.canBack ?? false ? scroll!.back : null,
        label: l10n.currentTaskSemantics(switch (attachment) {
          null => text,
          _ when missing => l10n.a11yAttachmentMissing(
            text.isNotEmpty
                ? text
                : isPdf
                ? pdfTitle
                : kind,
          ),
          // Con PDF (CA-008-20): "{texto}. Con PDF, {nombre}, {tamaño}" o
          // "{nombre}. PDF, {tamaño}".
          _ when isPdf && text.isEmpty => l10n.a11yPdfOnly(pdfTitle, pdfBytes),
          _ when isPdf => l10n.a11yWithPdf(text, pdfTitle, pdfBytes),
          _ when text.isEmpty => kind,
          _ => isPhoto ? l10n.a11yWithPhoto(text) : l10n.a11yWithImage(text),
        }),
        // Papel de imagen, salvo si la lectura ya acaba en "imagen".
        image: isPhoto && showImage,
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
    final Widget wordmark = !withAttachment
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

    // Márgenes laterales por fila: el PDF ocupa todo el ancho (prototipo:
    // `left: 0; right: 0`), la cabecera y el botón no.
    Widget side(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: UnaSpace.l),
      child: child,
    );
    final content = SafeArea(
      child: Padding(
        // Abajo, el margen del prototipo (~38).
        padding: const EdgeInsets.only(top: UnaSpace.l, bottom: UnaSpace.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(
              side(
                Row(
                  children: [
                    wordmark,
                    const Spacer(),
                    if (!landscape)
                      _Order(
                        1,
                        child: SquareIconButton(
                          icon: UnaIcons.menu,
                          label: l10n.menuButton,
                          fill: withAttachment
                              ? UnaColors.surface
                              : UnaPalettes.classic[task.colorKey %
                                    UnaPalettes.classic.length],
                          onPressed: openMenu,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              // Con imagen, la tarea está detrás, a sangre.
              child: showImage
                  ? const SizedBox.shrink()
                  : showPdf
                  ? _pdfZone(
                      context,
                      ref,
                      strip: taskNode(
                        PdfStrip(
                          type: l10n.attachmentPdf,
                          name: pdfTitle,
                          size: pdfBytes,
                        ),
                      ),
                    )
                  : side(
                      missing
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
                                  child: chromeOnly
                                      ? hidden(noteText)
                                      : noteText,
                                ),
                              ),
                            ),
                    ),
            ),
            // Separación entre el PDF y el botón (prototipo: ~18 px).
            if (showPdf && !landscape) const SizedBox(height: UnaSpace.m),
            // En horizontal se completa con la acción del lector (CA-003-07).
            if (!landscape)
              cta(
                side(
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
                child: showPdf
                    // Con PDF la nota es blanca; su color queda en la banda
                    // del texto (prototipo `isDoc`).
                    ? ColoredBox(color: UnaColors.surface, child: content)
                    : !showImage
                    ? content
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          _Order(
                            0,
                            child: _RotatesWithImage(
                              enabled: !faceOnly,
                              fullWidth: landscape,
                              builder: (scroll) => taskNode(
                                TaskImage(
                                  attachment: attachment,
                                  caption: landscape ? null : text,
                                  scroll: scroll.controller,
                                ),
                                scroll: scroll,
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
    return KeepScreenOnWhileVisible(
      enabled: showImage || showPdf,
      child: screen,
    );
  }

  /// La zona del PDF (CA-008-08): borde negro arriba y abajo, la franja fija
  /// ([strip], que es el nodo de la tarea para el lector) y debajo las
  /// páginas, con la banda del texto. Al completar o eliminar, una imagen
  /// fija de lo que se ve.
  Widget _pdfZone(
    BuildContext context,
    WidgetRef ref, {
    required Widget strip,
  }) {
    final attachment = task.attachment!;
    final images = ref.watch(attachmentImagesProvider);
    final position = pdfPositionProvider(attachment.id);
    // Solo reconstruye al terminar de leer la posición, no al desplazarse.
    final loaded = ref.watch(position.select((s) => s.loaded));
    // Sin `ref` al salir: el almacén y el importador se capturan ahora.
    final store = ref.read(attachmentStoreProvider);
    final importer = ref.read(pdfImporterProvider);
    // La página de la versión de pantalla que hay ahora en el disco.
    var shownPage = (ref.read(position).position ?? PdfPosition.start).page;
    final args = TaskPdfArgs(
      source: images.storedPdf(attachment.documentPath),
      screen: images.stored(attachment.screenPath),
      caption: task.text,
      captionColor:
          UnaPalettes.classic[task.colorKey % UnaPalettes.classic.length],
      initialPosition: ref.read(position).position,
      onPosition: ref.read(position.notifier).update,
      onLeave: (left) {
        unawaited(
          persistPdfPosition(
            store: store,
            importer: importer,
            attachment: attachment,
            position: left,
            shownPage: shownPage,
          ),
        );
        shownPage = left.page;
      },
    );
    final Widget pages = chromeOnly
        ? const SizedBox.expand()
        : faceOnly
        ? TaskPdfFace(args: args)
        : !loaded
        ? const ColoredBox(color: UnaColors.surface)
        : ref.watch(taskPdfBuilderProvider)(args);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: UnaColors.ink,
            width: UnaBorders.strongWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UnaBorders.strongWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Order(0, child: chromeOnly ? const SizedBox.shrink() : strip),
            Expanded(child: pages),
          ],
        ),
      ),
    );
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

/// Orden de foco de la spec 001 §6: tarea → menú → completar (lector de
/// pantalla y teclado), aunque el menú esté arriba en pantalla.
/// Desplazamiento de la imagen de la tarea actual: por pasos del 80 % de la
/// pantalla, sin animar con reducir movimiento.
class _ImageScroll {
  _ImageScroll(this.controller, this._reduced);

  final ScrollController controller;
  final bool Function() _reduced;

  ScrollPosition? get _position =>
      controller.hasClients ? controller.position : null;
  bool get canForward {
    final p = _position;
    return p != null && p.pixels < p.maxScrollExtent - 0.5;
  }

  bool get canBack {
    final p = _position;
    return p != null && p.pixels > p.minScrollExtent + 0.5;
  }

  void forward() => _by(1);
  void back() => _by(-1);

  void _by(int direction) {
    final p = _position;
    if (p == null) return;
    final to = (p.pixels + direction * p.viewportDimension * 0.8).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (_reduced()) {
      p.jumpTo(to);
    } else {
      unawaited(
        p.animateTo(
          to,
          duration: UnaMotion.imageZoomBack,
          curve: UnaMotion.standardCurve,
        ),
      );
    }
  }
}

/// Mientras se ve la tarea actual con imagen (y es la pantalla de arriba, no
/// bajo el menú, el editor o el listado), la app gira con el móvil
/// (CA-007-11); si no, solo en vertical. En horizontal pide todo el ancho
/// aunque el marco de la app lo limite en tablets (CL-001-7). También es la
/// dueña del desplazamiento de la imagen: acciones del lector y Av Pág / Re Pág
/// con teclado (CA-007-09, WCAG 2.1.1).
class _RotatesWithImage extends StatefulWidget {
  const _RotatesWithImage({
    required this.enabled,
    required this.fullWidth,
    required this.builder,
  });

  final bool enabled;
  final bool fullWidth;
  final Widget Function(_ImageScroll scroll) builder;

  @override
  State<_RotatesWithImage> createState() => _RotatesWithImageState();
}

class _RotatesWithImageState extends State<_RotatesWithImage> {
  bool? _rotating;
  bool _fullWidth = false;
  final _controller = ScrollController();
  late final _scroll = _ImageScroll(
    _controller,
    () => mounted && MediaQuery.disableAnimationsOf(context),
  );
  (bool, bool)? _can;

  /// Las acciones del lector cambian al llegar arriba o abajo del todo.
  void _onScroll() {
    final can = (_scroll.canForward, _scroll.canBack);
    if (can != _can && mounted) setState(() => _can = can);
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !(_rotating ?? false)) return false;
    if (event.logicalKey == LogicalKeyboardKey.pageDown && _scroll.canForward) {
      _scroll.forward();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp && _scroll.canBack) {
      _scroll.back();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    HardwareKeyboard.instance.addHandler(_onKey);
    // Cuánto se puede desplazar solo se sabe tras la primera medida.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _update() {
    final on = widget.enabled && (ModalRoute.isCurrentOf(context) ?? true);
    if (on != _rotating) {
      _rotating = on;
      unawaited(ImageRotation.follow(on));
    }
    final fullWidth = on && widget.fullWidth;
    if (fullWidth != _fullWidth) {
      _fullWidth = fullWidth;
      // Fuera de la construcción: el marco de la app lo escucha.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => fullWidthRequests.value += fullWidth ? 1 : -1,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
    // Al girar cambia la altura de la imagen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(_RotatesWithImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller.dispose();
    if (_rotating ?? false) unawaited(ImageRotation.follow(false));
    if (_fullWidth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => fullWidthRequests.value--,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_scroll);
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
