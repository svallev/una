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
  late final int _colorKey = ref.read(colorPickerProvider).pick();
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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
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
    return Scaffold(
      backgroundColor: UnaColors.paper,
      body: StickyNote(
        colorKey: _colorKey,
        child: SafeArea(
          // Ocupa toda la pantalla y, si no cabe (texto al 200 % con el
          // teclado abierto), se desplaza en lugar de cortarse (CL-001-9).
          child: CustomScrollView(
            slivers: [
              // El margen va dentro: con SliverPadding, SliverFillRemaining
              // ocupa la pantalla entera y el margen inferior la desborda.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(UnaSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sin "Cancelar" ni menú: hasta crear la primera tarea no se puede hacer nada más (R2).
                      const Wordmark(),
                      const SizedBox(height: UnaSpace.xl),
                      // La etiqueta visual se anuncia como nombre del campo (§6).
                      ExcludeSemantics(child: _Tag(text: l10n.editorTagFirst)),
                      const SizedBox(height: UnaSpace.sm),
                      Expanded(
                        child: MediaQuery(
                          // Mismo límite de escala que la nota (CA-001-07, CL-001-9).
                          data: mq.copyWith(
                            textScaler: mq.textScaler.clamp(
                              maxScaleFactor:
                                  CurrentTaskScreen.maxNoteTextScale,
                            ),
                          ),
                          // Un solo nodo: campo de texto con la etiqueta como nombre.
                          child: MergeSemantics(
                            child: Semantics(
                              label: l10n.editorTagFirst,
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                maxLines: null,
                                maxLength: Task.maxTextLength,
                                // El teclado no aprende del texto de las tareas
                                // (MASVS-STORAGE-2, decisión del propietario).
                                enableIMEPersonalizedLearning: false,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: UnaTheme.noteText(_controller.text),
                                cursorColor: UnaColors.ink,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: l10n.editorPlaceholder,
                                  hintStyle: UnaTheme.noteText(
                                    l10n.editorPlaceholder,
                                  ).copyWith(color: UnaColors.placeholder),
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
                      if (length >= FirstTaskEditorScreen.counterFrom)
                        Padding(
                          padding: const EdgeInsets.only(bottom: UnaSpace.s),
                          child: Text(
                            l10n.editorCharsLeft(Task.maxTextLength - length),
                            style: UnaTheme.mono.copyWith(color: UnaColors.ink),
                          ),
                        ),
                      BrutalButton(
                        label: l10n.editorSaveFirst,
                        onPressed: _canSave ? _save : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta negra en mayúsculas del prototipo (`.tag`).
class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        color: UnaColors.ink,
        padding: const EdgeInsets.symmetric(
          horizontal: UnaSpace.s,
          vertical: UnaSpace.xs,
        ),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: UnaFonts.mono,
            fontSize: UnaFontSizes.tag,
            fontWeight: UnaFontWeights.bold,
            letterSpacing: UnaLetterSpacing.tagWide * UnaFontSizes.tag,
            color: UnaColors.onInk,
          ),
        ),
      ),
    );
  }
}
