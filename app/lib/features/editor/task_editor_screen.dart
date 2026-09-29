import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/queue_position.dart';
import '../../domain/entities/task.dart';
import '../../domain/ports/image_importer.dart';
import '../../domain/usecases/edit_task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';
import '../../ui/wordmark.dart';
import '../attachments/attach_sheet.dart';
import '../attachments/attachment_import_controller.dart';
import '../attachments/attachment_preview.dart';
import '../attachments/import_error_text.dart';
import '../attachments/pdf_labels.dart';
import '../attachments/pdf_pages.dart';
import '../attachments/pdf_strip.dart';
import '../current_task/current_task_screen.dart';
import '../web/url_sheet.dart';
import 'placement_sheet.dart';

/// Modos del editor.
enum EditorMode {
  /// Primera tarea o desde "Todo hecho.": sin "Cancelar", "Guardar", sin
  /// preguntar la posición (spec 001, CA-003-10).
  first,

  /// Nueva tarea con otras pendientes: "Cancelar", "Continuar →" y la hoja
  /// "¿Dónde la pones?" (spec 002).
  create,

  /// Editar el texto y la imagen de una tarea: "Cancelar" y "Guardar
  /// cambios" (specs 005 y 007).
  edit,
}

/// Editor de tareas (specs 001, 002 y 005), escrito sobre la nota.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({
    super.key,
    this.mode = EditorMode.first,
    this.colorKey,
    this.task,
    this.fromList = false,
  }) : assert(mode != EditorMode.edit || task != null);

  /// Abierto desde el listado (spec 006): al guardar, la ruta devuelve la
  /// tarea guardada y el listado se encarga del foco y del anuncio
  /// (CA-006-13/15/17).
  final bool fromList;

  final EditorMode mode;

  /// Color de la nota. Sin indicar, el de la primera tarea (amarillo). Al
  /// crear, uno al azar distinto del de la tarea actual (CA-001-08); al
  /// editar, el de la tarea.
  final int? colorKey;

  /// La tarea que se edita (modo [EditorMode.edit]).
  final Task? task;

  /// Abre el editor como ruta con el fundido del prototipo (`.fadein`, 0,8 s).
  static Route<Task?> route(BuildContext context, TaskEditorScreen editor) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? UnaMotion.reducedMotionFade
        : UnaMotion.introFade;
    return PageRouteBuilder<Task?>(
      transitionDuration: duration,
      reverseTransitionDuration: reduced
          ? UnaMotion.reducedMotionFade
          : UnaMotion.sheetOut,
      pageBuilder: (_, _, _) => editor,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: UnaMotion.easeCurve),
        child: child,
      ),
    );
  }

  /// El contador de caracteres aparece a partir de aquí (CL-001-2).
  static const counterFrom = 9000;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late final _controller = TextEditingController(text: widget.task?.text);
  final _fieldFocus = FocusNode();
  late final int _colorKey =
      widget.task?.colorKey ??
      widget.colorKey ??
      ref.read(firstTaskColorProvider);
  bool _saving = false;

  /// Al editar, se quitó el adjunto que ya tenía la tarea (CA-007-06).
  bool _removedExisting = false;

  final _plusFocus = FocusNode();
  final _plusSemantics = GlobalKey();
  final _buttonsKey = GlobalKey();

  /// Cambian para llevar el foco a la vista previa o a "Cancelar" (CA-007-22).
  int _previewSignal = 0;
  int _cancelSignal = 0;

  /// El adjunto recién elegido (imagen o PDF), aún en la preparación.
  StagedAttachment? get _staged => ref.read(attachmentImportProvider).staged;

  /// El adjunto que ya tenía la tarea y sigue en ella.
  Attachment? get _existing =>
      _removedExisting ? null : widget.task?.attachment;

  bool get _hasImage => _staged != null || _existing != null;

  /// Con imagen, el texto es opcional (CA-007-04).
  bool get _canSave =>
      !_saving && (_controller.text.trim().isNotEmpty || _hasImage);

  @override
  void initState() {
    super.initState();
    // Al editar, el cursor va al final del texto (CA-005-04).
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _controller.addListener(_onChanged);
    // Con imagen, el teclado no se abre solo (CA-007-04).
    if (_existing != null) return;
    // `autofocus` no basta: al venir de la bienvenida, esta aún tiene el foco
    // mientras se funde y el campo no lo recibiría (ni se abriría el teclado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  int _lastLength = 0;

  void _onChanged() {
    final length = _controller.text.characters.length;
    // El contador es visual: se anuncia al aparecer y al llegar al máximo.
    if ((_lastLength < TaskEditorScreen.counterFrom &&
            length >= TaskEditorScreen.counterFrom) ||
        (_lastLength < Task.maxTextLength && length >= Task.maxTextLength)) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          AppLocalizations.of(context)
              .editorCharsLeft(Task.maxTextLength - length),
          Directionality.of(context),
        ),
      );
    }
    _lastLength = length;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _plusFocus.dispose();
    super.dispose();
  }

  /// (+): hoja "Añadir a la tarea" (CA-007-01). Con una imagen ya elegida, la
  /// nueva la sustituye (CA-007-04). Mientras se prepara una imagen no hace
  /// nada, sin verse desactivado (CA-007-15, DEV-17).
  Future<void> _attach() async {
    if (_saving || ref.read(attachmentImportProvider).preparing) return;
    final choice = await showAttachSheet(
      context,
      // Una tarea no se convierte en web al editarla (CA-009-01).
      withUrl: widget.mode != EditorMode.edit,
    );
    if (!mounted) return;
    if (choice == null) {
      // Cerrada sin elegir: el foco vuelve a (+) (CA-007-22).
      _focusPlus();
      return;
    }
    // "Cargar URL" no prepara nada: abre su hoja (CA-009-01).
    if (choice == AttachChoice.url) return _loadUrl();
    final origin = switch (choice) {
      AttachChoice.camera => AttachmentOrigin.camera,
      AttachChoice.gallery => AttachmentOrigin.gallery,
      AttachChoice.file || AttachChoice.url => AttachmentOrigin.file,
    };
    final outcome = await ref
        .read(attachmentImportProvider.notifier)
        .pick(origin);
    if (!mounted) return;
    switch (outcome) {
      case ImportOutcome.added:
        // La imagen nueva sustituye a la que tenía la tarea.
        if (widget.task?.attachment != null) _removedExisting = true;
        _fieldFocus.unfocus();
        setState(() => _previewSignal++);
        final l10n = AppLocalizations.of(context);
        _announce(switch (origin) {
          AttachmentOrigin.camera => l10n.a11yPhotoAdded,
          AttachmentOrigin.gallery => l10n.a11yImageAdded,
          AttachmentOrigin.file || AttachmentOrigin.url => l10n.a11yPdfAdded,
        });
      case ImportOutcome.unchanged:
        _focusPlus();
      case ImportOutcome.failed:
        break; // El aviso lo muestra `_onImportChanged`.
    }
  }

  /// "Cargar URL" (CA-009-01): cerrar la hoja deja el editor como estaba, con
  /// el foco en (+); "Abrir" crea la tarea web al momento (CA-009-03).
  Future<void> _loadUrl() async {
    final url = await showUrlSheet(context);
    if (!mounted) return;
    if (url == null) {
      _focusPlus();
      return;
    }
    await _createWeb(url);
  }

  /// Crea la tarea web sin texto, arriba y sin preguntar la posición. El
  /// texto del editor y el adjunto preparado se descartan, sin dejar archivos
  /// (CA-009-03). Se vuelve al origen como con un PDF (CA-008-05).
  Future<void> _createWeb(String url) async {
    if (_saving) return;
    _saving = true;
    await ref.read(attachmentImportProvider.notifier).remove();
    if (!mounted) return;
    final web = StagedWeb(id: ref.read(idGeneratorProvider).newId(), url: url);
    if (await _write(
      () => ref
          .read(createTaskProvider)
          .call('', colorKey: _colorKey, attachment: web),
      retry: () => _createWeb(url),
    )) {
      _created();
    }
  }

  /// "Quitar adjunto" (CA-007-06, CA-007-22).
  Future<void> _removeImage() async {
    if (_saving) return;
    if (_staged != null) {
      await ref.read(attachmentImportProvider.notifier).remove();
    } else {
      _removedExisting = true;
    }
    if (!mounted) return;
    setState(() {});
    _announce(AppLocalizations.of(context).a11yAttachmentRemoved);
    _focusPlus();
  }

  void _onImportChanged(
    AttachmentImportState? before,
    AttachmentImportState now,
  ) {
    if (now.showPreparing && !(before?.showPreparing ?? false)) {
      final l10n = AppLocalizations.of(context);
      _announce(
        now.preparingKind == AttachmentKind.pdf
            ? l10n.pdfPreparing
            : l10n.imagePreparing,
      );
      setState(() => _cancelSignal++);
    }
    final error = now.error;
    if (error != null && before?.error == null) {
      final l10n = AppLocalizations.of(context);
      // El aviso se anuncia solo (spec 007 §5).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importErrorText(l10n, error)),
          // Encima de los botones: no tapa el (+), que recibe el foco
          // (WCAG 2.4.11).
          behavior: SnackBarBehavior.floating,
          margin: _aboveButtons(),
        ),
      );
      ref.read(attachmentImportProvider.notifier).clearError();
      _focusPlus();
    }
  }

  /// Margen de un aviso flotante que queda justo encima de la fila de
  /// botones, mida lo que mida con el texto grande.
  EdgeInsets _aboveButtons() {
    final box = _buttonsKey.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context).height;
    final top = box == null || !box.hasSize
        ? screen
        : box.localToGlobal(Offset.zero).dy;
    return EdgeInsets.fromLTRB(
      UnaSpace.l,
      0,
      UnaSpace.l,
      (screen - top).clamp(0, screen) + UnaSpace.s,
    );
  }

  void _announce(String message) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  void _focusPlus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _plusFocus.requestFocus();
      _plusSemantics.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Ya se ha guardado alguna tarea: sin pendientes, "Todo hecho." y no el
  /// editor de la primera (CA-001-05, ADR-0012). La BD lo guarda en la misma
  /// transacción que la tarea.
  void _created() => ref.read(hasEverHadTasksProvider.notifier).mark();

  Future<void> _save() async {
    if (_saving || ref.read(attachmentImportProvider).preparing) return;
    if (!_canSave) {
      // Ningún botón se ve desactivado (DEV-17): sin texto no guarda y
      // devuelve el foco al campo (CL-001-1, CA-002-10, CA-005-06).
      _fieldFocus.requestFocus();
      return;
    }
    final image = _staged;
    switch (widget.mode) {
      case EditorMode.first:
        if (await _write(
          () => ref
              .read(createTaskProvider)
              .call(_controller.text, colorKey: _colorKey, attachment: image),
        )) {
          _created();
        }
      case EditorMode.create when image != null:
        // Con adjunto (imagen o PDF), siempre arriba y sin preguntar
        // (CA-007-05, CA-008-05).
        if (await _write(
          () => ref
              .read(createTaskProvider)
              .call(_controller.text, colorKey: _colorKey, attachment: image),
        )) {
          _created();
        }
      case EditorMode.create:
        // Sin adjunto se pregunta dónde va (CA-002-02).
        final position = await showPlacementSheet(
          context,
          text: _controller.text.trim(),
          color: UnaPalettes.classic[_colorKey % UnaPalettes.classic.length],
        );
        if (position == null || !mounted) return; // Seguir editando.
        final saved = await _write(
          () => ref
              .read(createTaskProvider)
              .call(_controller.text, position: position, colorKey: _colorKey),
        );
        if (saved) _created();
        if (saved &&
            position == QueuePosition.end &&
            !widget.fromList &&
            mounted) {
          // A la cola: sin aviso visible; solo el lector (CA-002-04).
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              AppLocalizations.of(context).a11yQueued,
              Directionality.of(context),
            ),
          );
        }
      case EditorMode.edit:
        final task = widget.task!;
        final AttachmentEdit edit = image != null
            ? ReplaceAttachment(image)
            : _removedExisting && task.attachment != null
            ? const RemoveAttachment()
            : const KeepAttachment();
        await _write(
          () => ref
              .read(editTaskProvider)
              .call(task, _controller.text, attachment: edit),
        );
    }
  }

  /// Escribe en la BD. Si sale bien, cierra el editor (si es una ruta) y la
  /// tarea actual recupera el foco; si falla, se conserva el texto y se
  /// ofrece reintentar (spec 001 §5, spec 002 §5, spec 005 §5).
  Future<bool> _write(
    Future<Object?> Function() write, {
    VoidCallback? retry,
  }) async {
    setState(() => _saving = true);
    try {
      final saved = await write();
      if (!mounted) return true;
      // El adjunto ya es de la tarea: cerrar el editor no lo borra.
      ref.read(attachmentImportProvider.notifier).saved();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(saved is Task ? saved : widget.task);
      }
      // Desde el listado, el foco lo decide el listado (CA-006-17).
      if (!widget.fromList) ref.read(screenFocusProvider.notifier).signal();
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.editorSaveError,
          ),
          action: SnackBarAction(label: l10n.retry, onPressed: retry ?? _save),
          persist: true,
        ),
      );
      return false;
    }
  }

  /// Campo de texto: la etiqueta del prototipo está oculta y solo da nombre al
  /// campo (spec 001 §6). Un solo nodo.
  Widget _field(AppLocalizations l10n, TextStyle textStyle, String hint) =>
      MergeSemantics(
        child: Semantics(
          label: switch (widget.mode) {
            EditorMode.first => l10n.editorTagFirst,
            EditorMode.create => l10n.editorTagNew,
            EditorMode.edit => l10n.editorTagEdit,
          },
          child: TextField(
            controller: _controller,
            focusNode: _fieldFocus,
            autofocus: _existing == null && _staged == null,
            maxLines: null,
            maxLength: Task.maxTextLength,
            // El teclado no aprende del texto de las tareas
            // (MASVS-STORAGE-2, decisión del propietario).
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.sentences,
            style: textStyle,
            cursorColor: UnaColors.ink,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.all(UnaSpace.s),
              hintText: hint,
              hintStyle: textStyle.copyWith(color: UnaColors.placeholder),
              semanticCounterText: '',
              counterText: '',
            ),
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Mantiene viva la importación mientras el editor está abierto; al
    // cerrarlo se cancela y se borra lo no guardado.
    final import = ref.watch(attachmentImportProvider);
    ref.listen(attachmentImportProvider, _onImportChanged);
    final images = ref.watch(attachmentImagesProvider);
    final staged = import.staged;
    final existing = staged == null ? _existing : null;
    // Una imagen (la nueva o la que ya tenía la tarea): su versión de pantalla.
    final ImageProvider? previewImage = switch (staged) {
      StagedImage(:final id) => images.staged(id, 'screen.jpg'),
      StagedPdf() || StagedWeb() => null,
      null when existing != null && existing.kind == AttachmentKind.image =>
        images.stored(existing.screenPath),
      null => null,
    };
    // Un PDF: franja y páginas (CA-008-04).
    final pdf = switch (staged) {
      StagedPdf(:final id, :final originalName, :final byteSize) => (
        source: images.stagedPdf(id),
        name: pdfName(l10n, originalName),
        size: pdfSize(l10n, byteSize),
      ),
      StagedImage() || StagedWeb() => null,
      null when existing != null && existing.isPdf => (
        source: images.storedPdf(existing.documentPath),
        name: pdfName(l10n, existing.originalName),
        size: pdfSize(l10n, existing.byteSize),
      ),
      null => null,
    };
    final previewIsPhoto = switch (staged) {
      StagedImage(:final origin) => origin == AttachmentOrigin.camera,
      _ => existing?.origin == AttachmentOrigin.camera,
    };
    final Widget? previewDocument = pdf == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PdfStrip(
                type: l10n.attachmentPdf,
                name: pdf.name,
                size: pdf.size,
                // Deja sitio a "Quitar adjunto" (prototipo: 56 px).
                endPadding: UnaSizes.removeAttachment + UnaSpace.s,
              ),
              Expanded(child: ref.watch(pdfPreviewBuilderProvider)(pdf.source)),
            ],
          );
    final withAttachment =
        previewImage != null || pdf != null || import.showPreparing;
    final preparingPdf = import.preparingKind == AttachmentKind.pdf;
    const attachmentTextStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.attachmentText,
      fontWeight: UnaFontWeights.extrabold,
      height: 1.05,
      letterSpacing: UnaLetterSpacing.tighter * UnaFontSizes.attachmentText,
      color: UnaColors.ink,
    );
    final length = _controller.text.characters.length;
    final mq = MediaQuery.of(context);
    const textStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.display,
      fontWeight: UnaFontWeights.extrabold,
      height: 1.05,
      letterSpacing: UnaLetterSpacing.tighter * UnaFontSizes.display,
      color: UnaColors.ink,
    );
    return Scaffold(
      backgroundColor: UnaColors.paper,
      body: StickyNote(
        colorKey: _colorKey,
        child: SafeArea(
          // Ocupa toda la pantalla y, si no cabe (texto al 200 % con el
          // teclado abierto), se desplaza en lugar de cortarse (CL-001-9).
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Misma cabecera que la tarea actual. En la primera tarea,
                    // sin "Cancelar" ni menú (R2); al crear o editar,
                    // "Cancelar" descarta sin preguntar (P-3).
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UnaSpace.l,
                        UnaSpace.l,
                        UnaSpace.m,
                        0,
                      ),
                      // Al menos 48 dp, y más con el texto grande: el
                      // logotipo no se corta (CA-007-23).
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Row(
                          children: [
                            const Wordmark(),
                            const Spacer(),
                            if (widget.mode != EditorMode.first)
                              UnaLinkButton(
                                label: l10n.editorCancel,
                                height: kMinInteractiveDimension,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (withAttachment) ...[
                      // Prototipo `hasDraftAtt`: vista previa y, debajo, el
                      // texto opcional más pequeño.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            UnaSpace.ml,
                            UnaSizes.attachPreviewTop,
                            UnaSpace.l,
                            0,
                          ),
                          child: AttachmentPreview(
                            image: previewImage,
                            document: previewDocument,
                            semanticLabel: pdf != null
                                ? l10n.a11yPdfOnly(pdf.name, pdf.size)
                                : previewIsPhoto
                                ? l10n.attachmentPhoto
                                : l10n.attachmentImage,
                            preparingLabel: preparingPdf
                                ? l10n.pdfPreparing
                                : l10n.imagePreparing,
                            cancelLabel: preparingPdf
                                ? l10n.pdfPreparingCancel
                                : l10n.imagePreparingCancel,
                            onRemove: _removeImage,
                            preparing: import.showPreparing,
                            onCancelPreparing: () => unawaited(
                              ref
                                  .read(attachmentImportProvider.notifier)
                                  .cancel(),
                            ),
                            focusSignal: _previewSignal,
                            cancelFocusSignal: _cancelSignal,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          UnaSpace.m,
                          UnaSpace.s + UnaSpace.xxs,
                          UnaSpace.m,
                          0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: UnaSizes.attachTextField,
                          ),
                          child: _field(
                            l10n,
                            attachmentTextStyle,
                            l10n.editorAttachmentPlaceholder,
                          ),
                        ),
                      ),
                    ] else
                      // Texto centrado en la nota, como en el prototipo.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            UnaSpace.m,
                            0,
                            UnaSpace.m,
                            UnaSpace.l,
                          ),
                          child: Center(
                            child: MediaQuery(
                              // Mismo límite de escala que la nota (CA-001-07, CL-001-9).
                              data: mq.copyWith(
                                textScaler: mq.textScaler.clamp(
                                  maxScaleFactor:
                                      CurrentTaskScreen.maxNoteTextScale,
                                ),
                              ),
                              // La etiqueta del prototipo está oculta: solo da
                              // nombre al campo (spec 001 §6). Un solo nodo.
                              child: _field(
                                l10n,
                                textStyle,
                                l10n.editorPlaceholder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (length >= TaskEditorScreen.counterFrom)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UnaSpace.l,
                        ),
                        child: Text(
                          l10n.editorCharsLeft(Task.maxTextLength - length),
                          style: UnaTheme.mono.copyWith(color: UnaColors.ink),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UnaSpace.l,
                        UnaSpace.sm,
                        UnaSpace.l,
                        UnaSpace.xxl,
                      ),
                      child: Row(
                        key: _buttonsKey,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          BrutalButton.icon(
                            label: l10n.attachButton,
                            icon: UnaIcons.plus,
                            focusNode: _plusFocus,
                            semanticsKey: _plusSemantics,
                            onPressed: _attach,
                          ),
                          const SizedBox(width: UnaSpace.m),
                          Flexible(
                            child: BrutalButton(
                              label: switch (widget.mode) {
                                EditorMode.first => l10n.editorSaveFirst,
                                EditorMode.create => l10n.editorContinue,
                                EditorMode.edit => l10n.editorSaveChanges,
                              },
                              trailingIcon: UnaIcons.arrowRight,
                              iconSize: UnaSizes.iconM,
                              expand: false,
                              singleLine: true,
                              onPressed: _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
