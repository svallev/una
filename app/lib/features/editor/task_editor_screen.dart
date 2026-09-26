import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/queue_position.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';
import '../../ui/wordmark.dart';
import '../current_task/current_task_screen.dart';
import 'placement_sheet.dart';

/// Modos del editor.
enum EditorMode {
  /// Primera tarea o desde "Todo hecho.": sin "Cancelar", "Guardar", sin
  /// preguntar la posición (spec 001, CA-003-10).
  first,

  /// Nueva tarea con otras pendientes: "Cancelar", "Continuar →" y la hoja
  /// "¿Dónde la pones?" (spec 002).
  create,

  /// Editar el texto de una tarea: "Cancelar" y "Guardar cambios" (spec 005).
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

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Al editar, el cursor va al final del texto (CA-005-04).
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _controller.addListener(_onChanged);
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_canSave) {
      // Ningún botón se ve desactivado (DEV-17): sin texto no guarda y
      // devuelve el foco al campo (CL-001-1, CA-002-10, CA-005-06).
      _fieldFocus.requestFocus();
      return;
    }
    switch (widget.mode) {
      case EditorMode.first:
        await _write(
          () => ref
              .read(createTaskProvider)
              .call(_controller.text, colorKey: _colorKey),
        );
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
        await _write(
          () => ref
              .read(updateTaskTextProvider)
              .call(widget.task!, _controller.text),
        );
    }
  }

  /// Escribe en la BD. Si sale bien, cierra el editor (si es una ruta) y la
  /// tarea actual recupera el foco; si falla, se conserva el texto y se
  /// ofrece reintentar (spec 001 §5, spec 002 §5, spec 005 §5).
  Future<bool> _write(Future<Object?> Function() write) async {
    setState(() => _saving = true);
    try {
      final saved = await write();
      if (!mounted) return true;
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
          action: SnackBarAction(label: l10n.retry, onPressed: _save),
          persist: true,
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                      child: SizedBox(
                        height: kMinInteractiveDimension,
                        child: Row(
                          children: [
                            const Wordmark(),
                            const Spacer(),
                            if (widget.mode != EditorMode.first)
                              UnaLinkButton(
                                label: l10n.editorCancel,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                          ],
                        ),
                      ),
                    ),
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
                            child: MergeSemantics(
                              child: Semantics(
                                label: switch (widget.mode) {
                                  EditorMode.first => l10n.editorTagFirst,
                                  EditorMode.create => l10n.editorTagNew,
                                  EditorMode.edit => l10n.editorTagEdit,
                                },
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _fieldFocus,
                                  autofocus: true,
                                  maxLines: null,
                                  maxLength: Task.maxTextLength,
                                  // El teclado no aprende del texto de las tareas
                                  // (MASVS-STORAGE-2, decisión del propietario).
                                  enableIMEPersonalizedLearning: false,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: textStyle,
                                  cursorColor: UnaColors.ink,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.all(
                                      UnaSpace.s,
                                    ),
                                    hintText: l10n.editorPlaceholder,
                                    hintStyle: textStyle.copyWith(
                                      color: UnaColors.placeholder,
                                    ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Adjuntar llega con las specs 007–009.
                          BrutalButton.icon(
                            label: l10n.attachButton,
                            icon: UnaIcons.plus,
                            onPressed: () {},
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
