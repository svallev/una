import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../data/platform/attachment_rotation.dart';
import '../../domain/entities/link_target.dart';
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
import '../attachments/link_confirm_sheet.dart';
import '../attachments/missing_attachment_card.dart';
import '../attachments/pdf_labels.dart';
import '../attachments/pdf_position_controller.dart';
import '../attachments/pdf_strip.dart';
import '../attachments/task_image.dart';
import '../attachments/task_labels.dart';
import '../attachments/task_pdf.dart';
import '../complete/complete_task_action.dart';
import '../complete/completion_controller.dart';
import '../complete/hold_to_complete_button.dart';
import '../delete/delete_task_action.dart';
import '../delete/deletion_controller.dart';
import '../editor/task_editor_screen.dart';
import '../menu/menu_sheet.dart';
import '../task_list/task_list_screen.dart';
import '../web/edit_web_task.dart';
import '../web/task_web.dart';
import 'pdf_face_snapshot.dart';

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
    final isWeb = attachment?.isWeb ?? false;
    // La web no tiene archivos que comprobar (ADR-0016).
    final health =
        attachment != null && !isWeb && !faceOnly && !chromeOnly && !leaving
        ? ref.watch(attachmentHealthProvider(attachment)).health
        : null;
    final missing = health == AttachmentHealth.missing;
    // No gira hasta saber que el adjunto está: con "Adjunto no disponible" no
    // gira nunca, ni un momento (CA-008-18, CA-007-19).
    final canRotate = !faceOnly && health != AttachmentHealth.checking;
    final isPdf = attachment?.isPdf ?? false;
    final showImage = attachment != null && !isPdf && !isWeb && !missing;
    // Con PDF: franja, banda del texto y páginas entre la cabecera y el botón
    // (CA-008-08).
    final showPdf = isPdf && !missing;
    // Web: barra y página en vivo entre la cabecera y el botón (CA-009-06).
    final showWeb = isWeb;
    final withAttachment = showImage || showPdf || showWeb;
    // Con un aviso en lugar de la página, la web no gira (CA-009-15).
    final webNotice =
        showWeb &&
        !faceOnly &&
        !chromeOnly &&
        ref.watch(webNoticeProvider(attachment!.id));
    final pdfTitle = pdfName(l10n, attachment?.originalName);
    final pdfBytes = pdfSize(l10n, attachment?.byteSize ?? 0);
    // En horizontal (solo gira la tarea con imagen, PDF o web), lo mismo con
    // los tres: el adjunto a todo el ancho y el logotipo; sin menú, botón,
    // franja, barra ni texto (CA-008-11, CA-009-15). Se vuelve a vertical
    // girando el móvil (sin botón: propietario, 2026-09-28). La web de pruebas
    // no gira (CL-008-12, CL-009-5).
    final landscape =
        ref.watch(attachmentRotatesProvider) &&
        (showImage || showPdf || (showWeb && !webNotice)) &&
        !faceOnly &&
        !chromeOnly &&
        mq.orientation == Orientation.landscape;
    // Con PDF o web, en horizontal el visor o la página ocupan toda la
    // pantalla y el logotipo va encima, como con la imagen.
    final pdfLandscape = showPdf && landscape;
    final bleed = (showPdf || showWeb) && landscape;

    final kind = isPhoto ? l10n.attachmentPhoto : l10n.attachmentImage;

    /// La tarea es un único nodo del lector; con imagen, imagen y pie juntos
    /// y sin decir "imagen" dos veces (CA-007-21).
    Widget taskNode(
      Widget child, {
      _ImageScroll? scroll,
      String? webHost,
    }) => FocusOnSignal(
      signal: focusSignal,
      child: Semantics(
        // Una imagen más alta que la pantalla se desplaza también con las
        // acciones del lector y de Switch Access (CA-007-09, WCAG 2.1.1).
        onScrollUp: scroll?.canForward ?? false ? scroll!.forward : null,
        onScrollDown: scroll?.canBack ?? false ? scroll!.back : null,
        label: l10n.currentTaskSemantics(switch (attachment) {
          null => text,
          // Web (CA-009-18): "Página web de {dominio}", el de la barra.
          _ when isWeb => l10n.urlA11yBar(webHost ?? taskLabel(l10n, task)),
          _ when missing => l10n.a11yAttachmentMissing(
            text.isNotEmpty
                ? readingText(text)
                : isPdf
                ? pdfTitle
                : kind,
          ),
          // Con PDF (CA-008-20): "{texto}. Con PDF, {nombre}, {tamaño}" o
          // "{nombre}. PDF, {tamaño}".
          _ when isPdf && text.isEmpty => l10n.a11yPdfOnly(pdfTitle, pdfBytes),
          _ when isPdf => l10n.a11yWithPdf(
            readingText(text),
            pdfTitle,
            pdfBytes,
          ),
          _ when text.isEmpty => kind,
          _ =>
            isPhoto
                ? l10n.a11yWithPhoto(readingText(text))
                : l10n.a11yWithImage(readingText(text)),
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
    final headerRow = header(
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
    );
    // Arriba, el margen del prototipo; abajo, ~38.
    const contentPadding = EdgeInsets.only(
      top: UnaSpace.l,
      bottom: UnaSpace.xxl,
    );
    // En horizontal con web, el logotipo encima de la página: es el nodo de
    // la tarea, con el dominio que se ve (plan §3, CA-009-18).
    Widget webLandscapeLogo(String host) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: UnaSpace.l),
        child: Align(
          alignment: Alignment.topCenter,
          child: side(Row(children: [taskNode(wordmark, webHost: host)])),
        ),
      ),
    );
    final content = SafeArea(
      // Con PDF o web en horizontal, el visor o la página llegan a los bordes.
      left: !bleed,
      top: !bleed,
      right: !bleed,
      bottom: !bleed,
      child: Padding(
        padding: bleed ? EdgeInsets.zero : contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!bleed) headerRow,
            Expanded(
              // Con clave: la cabecera va y viene al girar y el visor del PDF
              // no se vuelve a crear (se conservan la posición y el zoom).
              key: const ValueKey('task-body'),
              // Con imagen, la tarea está detrás, a sangre.
              child: showImage
                  ? const SizedBox.shrink()
                  : showWeb
                  ? TaskWeb(
                      // Otra dirección (Editar, CA-009-05): otra página.
                      key: ValueKey('web-${attachment!.id}'),
                      attachmentId: attachment.id,
                      address: attachment.url ?? '',
                      landscapeLogo: landscape ? webLandscapeLogo : null,
                      live: !faceOnly && !chromeOnly,
                      showBar: !chromeOnly,
                      taskNode: (bar, host) =>
                          faceOnly ? bar : taskNode(bar, webHost: host),
                    )
                  : showPdf
                  ? _pdfZone(
                      context,
                      ref,
                      landscape: landscape,
                      taskActions: faceOnly
                          ? const {}
                          : {
                              CustomSemanticsAction(
                                label: l10n.completeA11yAction,
                              ): () =>
                                  unawaited(complete()),
                              CustomSemanticsAction(
                                label: l10n.deleteA11yAction,
                              ): () =>
                                  unawaited(delete()),
                            },
                      taskLabel: l10n.currentTaskSemantics(
                        text.isNotEmpty ? text : pdfTitle,
                      ),
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
            if ((showPdf || showWeb) && !landscape)
              const SizedBox(height: UnaSpace.m),
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
                child: showWeb
                    // Con web, la nota es blanca, como con PDF (prototipo), y
                    // gira salvo con un aviso (CA-009-15).
                    ? _RotatesWithAttachment(
                        enabled: canRotate && !webNotice,
                        fullWidth: landscape,
                        builder: (_) => ColoredBox(
                          color: UnaColors.surface,
                          child: content,
                        ),
                      )
                    : showPdf
                    // Con PDF la nota es blanca; su color queda en la banda
                    // del texto (prototipo `isDoc`).
                    ? _RotatesWithAttachment(
                        enabled: canRotate,
                        fullWidth: landscape,
                        builder: (_) => ColoredBox(
                          color: UnaColors.surface,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              content,
                              // En horizontal, el logotipo encima de las
                              // páginas.
                              if (pdfLandscape)
                                SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: UnaSpace.l,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: headerRow,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : !showImage
                    ? content
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          _Order(
                            0,
                            child: _RotatesWithAttachment(
                              enabled: canRotate,
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
    // Con imagen, PDF o web, en vertical y en horizontal, la pantalla no se
    // apaga mientras se usa (CA-007-12, CA-008-13, CA-009-16).
    return KeepScreenOnWhileVisible(
      enabled: showImage || showPdf || showWeb,
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
    required bool landscape,
    required Map<CustomSemanticsAction, VoidCallback> taskActions,
    required String taskLabel,
  }) {
    final attachment = task.attachment!;
    final images = ref.watch(attachmentImagesProvider);
    final position = pdfPositionProvider(attachment.id);
    // Solo reconstruye al terminar de leer la posición, no al desplazarse.
    final loaded = ref.watch(position.select((s) => s.loaded));
    // Sin `ref` al salir: el almacén y el importador se capturan ahora.
    final store = ref.read(attachmentStoreProvider);
    final importer = ref.read(pdfImporterProvider);
    // La posición de la versión de pantalla que hay ahora en el disco.
    var shown = ref.read(position).position ?? PdfPosition.start;
    final gap = pdfPageGap(MediaQuery.devicePixelRatioOf(context));
    final screen = images.stored(attachment.screenPath);
    final args = TaskPdfArgs(
      source: images.storedPdf(attachment.documentPath),
      screen: screen,
      // En horizontal, sin la banda del texto (CA-008-11).
      caption: landscape ? null : task.text,
      captionColor:
          UnaPalettes.classic[task.colorKey % UnaPalettes.classic.length],
      initialPosition: ref.read(position).position,
      onPosition: ref.read(position.notifier).update,
      onLink: (target) => unawaited(_openLink(context, ref, target)),
      // El PDF también lleva completar y eliminar, en las dos orientaciones;
      // en horizontal es lo único que hay (CA-008-11, CA-008-20).
      actions: taskActions,
      taskLabel: landscape ? taskLabel : null,
      // El motor no lo puede abrir: "Adjunto no disponible" (CA-008-18).
      onUnreadable: () => ref
          .read(attachmentHealthProvider(attachment).notifier)
          .reportUnreadable(),
      onLeave: (left) {
        unawaited(
          persistPdfPosition(
            store: store,
            importer: importer,
            attachment: attachment,
            position: left,
            shown: shown,
            gap: gap,
            screen: screen,
          ),
        );
        shown = left;
      },
    );
    final Widget pages = chromeOnly
        ? const SizedBox.expand()
        : faceOnly
        ? TaskPdfFace(
            args: args,
            // Lo que se veía al empezar a completar o eliminar (CA-008-19).
            snapshot: ref.watch(
              pdfFaceSnapshotProvider.select(
                (s) => s?.attachmentId == attachment.id ? s!.image : null,
              ),
            ),
          )
        : !loaded
        ? const ColoredBox(color: UnaColors.surface)
        : PdfFaceCapture(
            taskId: task.id,
            attachmentId: attachment.id,
            child: ref.watch(taskPdfBuilderProvider)(args),
          );
    // En horizontal, a sangre: sin bordes ni franja (CA-008-11).
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: landscape
          ? const BoxDecoration()
          : const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: UnaColors.ink,
                  width: UnaBorders.strongWidth,
                ),
              ),
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: landscape ? 0 : UnaBorders.strongWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Order(
              0,
              child: chromeOnly || landscape ? const SizedBox.shrink() : strip,
            ),
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
  // Una tarea web se edita en la hoja "Cargar URL", no en el editor
  // (CA-009-05). Al guardar, el foco vuelve a la tarea, como con el editor.
  if (action == MenuAction.edit && (task.attachment?.isWeb ?? false)) {
    return editWebTask(
      context,
      ref,
      task,
      onSaved: ref.read(screenFocusProvider.notifier).signal,
    );
  }
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
      isPdf: task.attachment?.isPdf ?? false,
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

/// Mientras se ve la tarea actual con imagen, PDF o web (y es la pantalla de
/// arriba, no bajo el menú, el editor o el listado; la confirmación de un
/// enlace sí la deja girar), la app gira con el móvil (CA-008-11,
/// CA-009-15); si no,
/// solo en vertical. En horizontal pide todo el ancho aunque el marco de la
/// app lo limite en tablets (CL-001-7). Con imagen, también es la dueña del
/// desplazamiento: acciones del lector y Av Pág / Re Pág con teclado
/// (CA-007-09, WCAG 2.1.1); el PDF y la página web llevan el suyo.
class _RotatesWithAttachment extends StatefulWidget {
  const _RotatesWithAttachment({
    required this.enabled,
    required this.fullWidth,
    required this.builder,
  });

  final bool enabled;
  final bool fullWidth;
  final Widget Function(_ImageScroll scroll) builder;

  @override
  State<_RotatesWithAttachment> createState() => _RotatesWithAttachmentState();
}

class _RotatesWithAttachmentState extends State<_RotatesWithAttachment> {
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
    linkConfirmOpen.addListener(_update);
    // Cuánto se puede desplazar solo se sabe tras la primera medida.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _update() {
    final on =
        widget.enabled &&
        ((ModalRoute.isCurrentOf(context) ?? true) || linkConfirmOpen.value);
    if (on != (_rotating ?? false)) AttachmentRotation.request(on: on);
    _rotating = on;
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
  void didUpdateWidget(_RotatesWithAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _controller.dispose();
    linkConfirmOpen.removeListener(_update);
    if (_rotating ?? false) AttachmentRotation.request(on: false);
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

/// Enlace de un PDF (CA-008-12): se confirma y, si se acepta, se abre fuera;
/// si no hay app, el aviso. El foco vuelve a la tarea.
Future<void> _openLink(
  BuildContext context,
  WidgetRef ref,
  LinkTarget target,
) async {
  final open = await showLinkConfirmSheet(context, target);
  if (open != true || !context.mounted) return;
  final opened = await ref.read(linkOpenerProvider).open(target);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).errNoAppForLink)),
  );
}
