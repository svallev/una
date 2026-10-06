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
import '../../domain/entities/attachment.dart';
import '../../domain/entities/link_target.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/edit_task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_on_signal.dart';
import '../../ui/full_width.dart';
import '../../ui/request_focus.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';
import '../attachments/attachment_health.dart';
import '../attachments/group_health.dart';
import '../attachments/keep_screen_on_controller.dart';
import '../attachments/link_confirm_sheet.dart';
import '../attachments/missing_attachment_card.dart';
import '../attachments/pdf_labels.dart';
import '../attachments/pdf_position_controller.dart';
import '../attachments/pdf_strip.dart';
import '../attachments/photo_announcer.dart';
import '../attachments/photo_carousel.dart';
import '../attachments/task_image.dart';
import '../attachments/task_labels.dart';
import '../attachments/task_pdf.dart';
import '../complete/complete_task_action.dart';
import '../complete/completion_controller.dart';
import '../complete/hold_to_complete_button.dart';
import '../delete/delete_task_action.dart';
import '../delete/deletion_controller.dart';
import '../delete/undo_card_host.dart';
import '../delete/undo_controller.dart';
import '../editor/task_editor_screen.dart';
import '../menu/menu_sheet.dart';
import '../settings/settings_route.dart';
import '../settings/settings_screen.dart';
import '../task_list/task_list_screen.dart';
import '../web/edit_web_task.dart';
import '../web/task_web.dart';
import 'image_scroll.dart';
import 'pdf_face_snapshot.dart';
import 'photo_face_snapshot.dart';
import 'photo_group.dart';

/// Pantalla principal: solo la tarea actual, a pantalla completa (R6, CA-001-06/07).
///
/// Con un grupo de fotos (spec 016) lleva el estado del carrusel: qué foto se
/// ve y el margen que el pie y los puntos dejan a las fotos ([PhotoGroupHost]).
/// Nace con la tarea y muere con ella: con otra tarea, o al volver tras 10
/// minutos (la pantalla se recrea), vuelve a la primera foto (CA-016-08).
class CurrentTaskScreen extends StatefulWidget {
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
  State<CurrentTaskScreen> createState() => _CurrentTaskScreenState();
}

class _CurrentTaskScreenState extends State<CurrentTaskScreen> {
  PhotoGroupHost? _host;

  /// Las copias de la rotura y el arrugado (`faceOnly`, `chromeOnly`) no llevan
  /// carrusel.
  bool _hasGroup(CurrentTaskScreen w) =>
      !w.faceOnly &&
      !w.chromeOnly &&
      w.task.attachments.length >= 2 &&
      w.task.attachments.isValidGroup;

  @override
  void didUpdateWidget(CurrentTaskScreen old) {
    super.didUpdateWidget(old);
    // Otra tarea o ya sin grupo: el estado se suelta (tras este fotograma, que
    // aún lo usa el carrusel que se va).
    if (old.task.id != widget.task.id || !_hasGroup(widget)) _dropHost();
  }

  void _dropHost() {
    final host = _host;
    if (host == null) return;
    _host = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => host.dispose());
  }

  @override
  void dispose() {
    _host?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = _hasGroup(widget) ? (_host ??= PhotoGroupHost()) : null;
    return _TaskView(
      task: widget.task,
      faceOnly: widget.faceOnly,
      chromeOnly: widget.chromeOnly,
      showLogoAndMenu: widget.showLogoAndMenu,
      ctaHide: widget.ctaHide,
      focusSignal: widget.focusSignal,
      host: host,
    );
  }
}

/// La pantalla principal propiamente dicha (la que dibuja [CurrentTaskScreen]).
class _TaskView extends ConsumerWidget {
  const _TaskView({
    required this.task,
    required this.faceOnly,
    required this.chromeOnly,
    required this.showLogoAndMenu,
    required this.ctaHide,
    required this.focusSignal,
    required this.host,
  });

  final Task task;
  final bool faceOnly;
  final bool chromeOnly;
  final bool showLogoAndMenu;
  final Animation<double>? ctaHide;
  final int focusSignal;

  /// El estado del carrusel, si la tarea tiene un grupo de fotos.
  final PhotoGroupHost? host;

  static const maxNoteTextScale = CurrentTaskScreen.maxNoteTextScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = task.text ?? '';
    final mq = MediaQuery.of(context);
    // Con la card de deshacer a la vista, el botón de completar no se ve y su
    // sitio crece lo que haga falta para que nada quede tapado (CA-014-05).
    final undoCard = faceOnly || chromeOnly
        ? (visible: false, height: 0.0)
        : UndoCardScope.of(context);
    Future<bool> complete() => completeTask(context, ref, task);
    Future<void> openMenu() => _openMenu(context, ref);
    Future<void> delete() => deleteTask(context, ref, task);
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
    // Un grupo no válido (tipo desconocido, mezcla, medidas raras: CA-016-25)
    // es "Adjunto no disponible" desde el primer fotograma, antes de dibujar
    // nada ni mirar el disco.
    final invalidGroup = !task.attachments.isValidGroup;
    final isPhoto = attachment?.isPhoto ?? false;
    // Falta la versión completa: "Adjunto no disponible" (CA-007-19).
    // La tarea que se completa o se elimina no comprueba: sus archivos ya se
    // han borrado (ADR-0012) y se ve la imagen que ya estaba cargada, también
    // en la pausa antes de romperse.
    final leaving = ref.watch(
      completionProvider.select((c) => c.busy && c.task?.id == task.id),
    );
    final isWeb = !invalidGroup && (attachment?.isWeb ?? false);
    // La web no tiene archivos que comprobar (ADR-0016). Con varias fotos, la
    // salud del grupo: solo faltan todas = tarjeta (CA-016-18b).
    final health =
        attachment != null &&
            !isWeb &&
            !invalidGroup &&
            !faceOnly &&
            !chromeOnly &&
            !leaving
        ? ref
              .watch(groupHealthProvider(AttachmentGroupKey(task.attachments)))
              .health
        : null;
    final missing = invalidGroup || health == AttachmentHealth.missing;
    // No gira hasta saber que el adjunto está: con "Adjunto no disponible" no
    // gira nunca, ni un momento (CA-008-18, CA-007-19).
    final canRotate = !faceOnly && health != AttachmentHealth.checking;
    final isPdf = !invalidGroup && (attachment?.isPdf ?? false);
    final showImage = attachment != null && !isPdf && !isWeb && !missing;
    // Con PDF: franja, banda del texto y páginas entre la cabecera y el botón
    // (CA-008-08).
    final showPdf = isPdf && !missing;
    // Web: barra y página en vivo entre la cabecera y el botón (CA-009-06).
    final showWeb = isWeb;
    final withAttachment = showImage || showPdf || showWeb;
    // Con un grupo de fotos a la vista: el carrusel en lugar de la imagen, y el
    // pie con los puntos en su sitio (spec 016).
    final photoGroup = showImage ? host : null;
    // La cara de la rotura y del arrugado de un grupo: la foto que se veía,
    // capturada en memoria (sus archivos ya no están), y el pie; sin captura,
    // solo el color de la nota y el pie. Nunca lee el disco (CA-016-13).
    final groupFace = faceOnly && showImage && task.attachments.length >= 2;
    final faceSnapshot = groupFace
        ? ref.watch(
            photoFaceSnapshotProvider.select(
              (s) => s?.taskId == task.id ? s : null,
            ),
          )
        : null;
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

    // Fotos del grupo cuyo archivo falta: su lectura y su anuncio dicen "Foto no
    // disponible" (CA-016-18a, CA-016-20).
    final missingPhotos = photoGroup == null
        ? const <String>{}
        : ref.watch(
            groupHealthProvider(AttachmentGroupKey(task.attachments))
                .select((state) => state.missingIds),
          );
    String photoStateOf(PhotoGroupHost host) {
      final index = host.carousel.index.clamp(0, task.attachments.length - 1);
      return photoState(
        l10n,
        index + 1,
        task.attachments.length,
        missing: missingPhotos.contains(task.attachments[index].id),
      );
    }

    /// El elemento de la tarea con un grupo de fotos (spec 016, CA-016-20): un
    /// solo nodo para fotos y pie, con la etiqueta al día ("Foto 2 de 5") y
    /// **sin recrearse** al cambiar de foto, las acciones de foto antes que
    /// Completar y Eliminar, las de desplazamiento de la foto que se ve y las
    /// estándar de desplazar a izquierda y derecha (control por voz y Switch
    /// Access). Es un punto de foco del teclado con anillo y flechas.
    Widget photoNode(Widget child, {required ImageScroll scroll}) {
      final host = photoGroup!;
      final carousel = host.carousel;
      return FocusOnSignal(
        signal: focusSignal,
        suspended: undoCard.visible,
        traversable: true,
        autofocus: true,
        ring: mq.padding,
        onKeyEvent: (_, event) => carousel.handleKey(event),
        child: ListenableBuilder(
          listenable: carousel,
          builder: (context, _) {
            final index = carousel.index.clamp(0, task.attachments.length - 1);
            return Semantics(
              onScrollUp: scroll.canForward ? scroll.forward : null,
              onScrollDown: scroll.canBack ? scroll.back : null,
              onScrollLeft: carousel.next,
              onScrollRight: carousel.previous,
              label: photoGroupReading(
                l10n,
                text: text,
                count: task.attachments.length,
                position: index + 1,
                missing: missingPhotos.contains(task.attachments[index].id),
                landscape: landscape,
              ),
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.a11yPhotoNext): carousel.next,
                CustomSemanticsAction(label: l10n.a11yPhotoPrevious):
                    carousel.previous,
                CustomSemanticsAction(label: l10n.completeA11yAction): complete,
                CustomSemanticsAction(label: l10n.deleteA11yAction): delete,
              },
              excludeSemantics: true,
              child: child,
            );
          },
        ),
      );
    }

    /// La tarea es un único nodo del lector; con imagen, imagen y pie juntos
    /// y sin decir "imagen" dos veces (CA-007-21).
    Widget taskNode(
      Widget child, {
      ImageScroll? scroll,
      String? webHost,
    }) => FocusOnSignal(
      signal: focusSignal,
      suspended: undoCard.visible,
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
                child: _MenuButton(
                  label: l10n.menuButton,
                  fill: withAttachment
                      ? UnaColors.surface
                      : UnaPalettes.classic[task.colorKey %
                            UnaPalettes.classic.length],
                  onPressed: openMenu,
                  // Las copias que se ven mientras se arruga o se completa no
                  // reciben el foco.
                  takesFocus: !faceOnly && !chromeOnly,
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
          child: side(
            Row(
              children: [
                Semantics(
                  container: true,
                  child: taskNode(wordmark, webHost: host),
                ),
              ],
            ),
          ),
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
        // En horizontal, el PDF y la web acaban encima de la card de deshacer;
        // la imagen, que es un solo elemento, queda debajo (plan 014 §3).
        padding: bleed
            ? EdgeInsets.only(bottom: undoCard.visible ? undoCard.height : 0)
            : contentPadding,
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
                  ? (photoGroup != null && !landscape
                        // El pie y, bajo él, los puntos, justo encima del botón
                        // de completar (CA-016-09 y 11).
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: side(
                              PhotoGroupFooter(
                                host: photoGroup,
                                count: task.attachments.length,
                                caption: text,
                              ),
                            ),
                          )
                        : groupFace && !(faceSnapshot?.landscape ?? false)
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: side(
                              PhotoFaceFooter(
                                count: task.attachments.length,
                                index: faceSnapshot?.index,
                                caption: text,
                              ),
                            ),
                          )
                        : const SizedBox.shrink())
                  : showWeb
                  // La tarea (la barra), la página o su aviso, antes que el
                  // menú: TalkBack empieza por el primero (CA-009-18).
                  ? _Order(
                      0,
                      child: TaskWeb(
                        // Otra dirección (Editar, CA-009-05): otra página.
                        key: ValueKey('web-${attachment!.id}'),
                        attachmentId: attachment.id,
                        address: attachment.url ?? '',
                        landscapeLogo: landscape ? webLandscapeLogo : null,
                        // Al empezar a guardar la completada, la página se
                        // suelta (CL-009-11).
                        live: !faceOnly && !chromeOnly && !leaving,
                        showBar: !chromeOnly,
                        // Su propio nodo, no el de toda la zona (CA-009-18).
                        taskNode: (bar, host) => faceOnly
                            ? bar
                            : Semantics(
                                container: true,
                                child: taskNode(bar, webHost: host),
                              ),
                      ),
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
                  // Con la card, el botón se oculta (también al lector y al
                  // teclado) y su sitio crece hasta cubrir la card (CA-014-05).
                  _UndoCardSpace(
                    card: undoCard,
                    // Lo que ya hay bajo el botón: el margen del sistema, el
                    // de abajo y la separación del PDF o la web.
                    below:
                        mq.padding.bottom +
                        contentPadding.bottom +
                        ((showPdf || showWeb) ? UnaSpace.m : 0),
                    child: _Order(
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
                            child: groupFace
                                ? PhotoFaceLayer(snapshot: faceSnapshot)
                                : _RotatesWithAttachment(
                                    enabled: canRotate,
                                    fullWidth: landscape,
                                    carousel: photoGroup?.carousel,
                                    builder: (scroll) => photoGroup != null
                                        ? photoNode(
                                            PhotoFaceCapture(
                                              taskId: task.id,
                                              host: photoGroup,
                                              landscape: landscape,
                                              child: PhotoGroupLayer(
                                                host: photoGroup,
                                                photos: task.attachments,
                                                landscape: landscape,
                                              ),
                                            ),
                                            scroll: scroll,
                                          )
                                        : taskNode(
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
                          // "Foto {i} de {n}" al cambiar de foto: su región
                          // viva (o el anuncio del sistema), fuera del recorrido
                          // (CA-016-20).
                          if (photoGroup != null)
                            Positioned(
                              left: 0,
                              top: 0,
                              child: PhotoAnnouncements(
                                carousel: photoGroup.carousel,
                                message: () => photoStateOf(photoGroup),
                              ),
                            ),
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
    // Elimina directamente, sin confirmación (CA-014-01).
    MenuAction.delete || MenuAction.allTasks || MenuAction.settings => null,
  };
  if (action == MenuAction.allTasks) return openTaskList(context, ref);
  if (action == MenuAction.settings) return _openSettings(context, ref);
  if (editor == null) {
    await deleteTask(context, ref, task);
    return;
  }
  await Navigator.of(context).push(TaskEditorScreen.route(context, editor));
}

/// "Ajustes" (spec 015, CA-015-01a): el menú ya se cierra y Ajustes sube a la
/// vez (P-015-1). Una eliminación pendiente pasa a ser definitiva **antes** de
/// empujar la ruta (CA-015-24; el observador de navegación lo repetiría).
/// Al cerrarla (Cerrar, atrás o Escape) se vuelve a la tarea y el foco va al
/// botón de menú (CA-015-02).
Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
  ref.read(undoProvider.notifier).commit();
  await openSettings(context);
  // Si la tarea ya no está (volvió tras 10 minutos o más), el botón nuevo toma
  // el foco al crearse (CA-015-16).
  if (!context.mounted) return;
  ref.read(menuFocusProvider.notifier).request();
}

/// Botón de menú de la tarea: posee su `FocusNode` y su clave para que, al
/// volver de Ajustes, el foco del teclado y del lector de pantalla vuelva a él
/// (CA-015-02, CA-015-16). Toma la petición de [menuFocusProvider] en cuanto se
/// pide o, si se monta con ella pendiente, al crearse.
class _MenuButton extends ConsumerStatefulWidget {
  const _MenuButton({
    required this.label,
    required this.fill,
    required this.onPressed,
    required this.takesFocus,
  });

  final String label;
  final Color fill;
  final VoidCallback onPressed;
  final bool takesFocus;

  @override
  ConsumerState<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends ConsumerState<_MenuButton> {
  final _focus = FocusNode(debugLabel: 'task menu');
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.takesFocus && ref.read(menuFocusProvider)) _take();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Pide el foco cuando termina la transición de vuelta y retira la
  /// petición. Va tras el primer fotograma: aquí aún no se puede leer el
  /// contexto ni cambiar un proveedor.
  void _take() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      requestFocusAfter(
        after: settingsTransition(context),
        isMounted: () => mounted,
        node: _focus,
        semantics: _key,
      );
      ref.read(menuFocusProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(menuFocusProvider, (_, pending) {
      if (pending && widget.takesFocus) _take();
    });
    return SquareIconButton(
      icon: UnaIcons.menu,
      label: widget.label,
      fill: widget.fill,
      onPressed: widget.onPressed,
      focusNode: _focus,
      semanticsKey: _key,
    );
  }
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
      isPdf: task.attachments.isValidGroup && (task.attachment?.isPdf ?? false),
      header: header,
      onRemove: interactive ? () => _remove(context, ref) : () {},
      onDelete: interactive ? () => deleteTask(context, ref, task) : () {},
    );
  }

  bool _busy(WidgetRef ref) =>
      ref.read(completionProvider).busy || ref.read(deletionProvider).busy;

  /// "Quitar adjunto" (con texto).
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    if (_busy(ref)) return;
    // Editar hace definitiva una eliminación que aún se podía deshacer
    // (CA-014-11), antes de escribir.
    ref.read(undoProvider.notifier).commit();
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
    this.carousel,
  });

  final bool enabled;
  final bool fullWidth;
  final Widget Function(ImageScroll scroll) builder;

  /// Con un grupo de fotos, el desplazamiento es el de la foto que se ve y
  /// cambia con ella (CA-016-20).
  final PhotoCarouselController? carousel;

  @override
  State<_RotatesWithAttachment> createState() => _RotatesWithAttachmentState();
}

class _RotatesWithAttachmentState extends State<_RotatesWithAttachment> {
  bool? _rotating;
  bool _fullWidth = false;
  final _controller = ScrollController();
  late final _scroll = ImageScroll(
    _controller,
    () => mounted && MediaQuery.disableAnimationsOf(context),
  );
  (bool, bool)? _can;

  /// El controlador cuyos cambios se vigilan: el propio o, con un grupo, el de
  /// la foto que se ve.
  late ScrollController _watched = _controller;

  void _watch(ScrollController controller) {
    if (controller == _watched) return;
    _watched.removeListener(_onScroll);
    _watched = controller;
    controller.addListener(_onScroll);
    _scroll.controller = controller;
  }

  /// Cambió la foto que se ve: su desplazamiento pasa a ser el de las acciones
  /// y de Av Pág / Re Pág, y cuánto se puede desplazar se mide tras el
  /// fotograma.
  void _onPhoto() {
    final carousel = widget.carousel;
    if (carousel == null) return;
    _watch(carousel.scroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  /// Las acciones del lector cambian al llegar arriba o abajo del todo.
  void _onScroll() {
    // Con un grupo, el carrusel solo conoce sus fotos tras montarse: la
    // primera vez que se mide ya está.
    final carousel = widget.carousel;
    if (carousel != null) _watch(carousel.scroll);
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
    widget.carousel?.addListener(_onPhoto);
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
    if (oldWidget.carousel != widget.carousel) {
      oldWidget.carousel?.removeListener(_onPhoto);
      widget.carousel?.addListener(_onPhoto);
      _watch(widget.carousel?.scroll ?? _controller);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
    _update();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.carousel?.removeListener(_onPhoto);
    _watched.removeListener(_onScroll);
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

/// El sitio del botón de abajo mientras se ve la card de deshacer (CA-014-05):
/// el botón sigue ocupando su sitio, pero no se ve ni se puede enfocar, y el
/// sitio crece hasta que lo desplazable de arriba acaba encima de la card.
/// [below] es lo que hay entre este sitio y el borde de la pantalla.
class _UndoCardSpace extends StatelessWidget {
  const _UndoCardSpace({
    required this.card,
    required this.below,
    required this.child,
  });

  final ({bool visible, double height}) card;
  final double below;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!card.visible) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (card.height - below).clamp(0, double.infinity),
      ),
      child: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: ExcludeFocus(child: child),
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
