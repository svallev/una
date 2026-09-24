import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';
import '../current_task/current_task_screen.dart';

/// Editor en modo "primera tarea" (spec 001, CA-001-02/03/04). Los modos
/// "nueva" y "editar" llegan con las specs 002 y 005.
class FirstTaskEditorScreen extends ConsumerStatefulWidget {
  const FirstTaskEditorScreen({super.key});

  /// El contador de caracteres aparece a partir de aquí (CL-001-2).
  static const counterFrom = 9000;

  @override
  ConsumerState<FirstTaskEditorScreen> createState() =>
      _FirstTaskEditorScreenState();
}

class _FirstTaskEditorScreenState extends ConsumerState<FirstTaskEditorScreen> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  late final int _colorKey = ref.read(firstTaskColorProvider);
  bool _saving = false;

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  int _lastLength = 0;

  void _onChanged() {
    final length = _controller.text.characters.length;
    // El contador es visual: se anuncia al aparecer y al llegar al máximo.
    if ((_lastLength < FirstTaskEditorScreen.counterFrom &&
            length >= FirstTaskEditorScreen.counterFrom) ||
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
      // "Guardar" nunca está desactivado (decisión del propietario): sin texto
      // no guarda y devuelve el foco al campo (CL-001-1).
      _fieldFocus.requestFocus();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(createTaskProvider)
          .call(_controller.text, colorKey: _colorKey);
      // La tarea actual cambia en la BD y el enrutado muestra la pantalla principal.
    } on Object catch (e) {
      // Error de escritura (spec 001 §5): el texto se conserva y se puede reintentar.
      if (!mounted) return;
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
                    // Misma cabecera que la tarea actual. Sin "Cancelar" ni
                    // menú: hasta crear la primera tarea no hay nada más (R2).
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        UnaSpace.l,
                        UnaSpace.l,
                        UnaSpace.l,
                        0,
                      ),
                      child: SizedBox(
                        height: kMinInteractiveDimension,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wordmark(),
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
                                label: l10n.editorTagFirst,
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
                    if (length >= FirstTaskEditorScreen.counterFrom)
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
                              label: l10n.editorSaveFirst,
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
