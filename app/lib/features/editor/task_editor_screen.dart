import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/color_picker.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/wordmark.dart';

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
  late final int _colorKey = ColorPicker().pick();
  bool _saving = false;

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
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
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).storageErrorTitle)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final length = _controller.text.characters.length;
    return Scaffold(
      backgroundColor: UnaColors.paper,
      body: StickyNote(
        colorKey: _colorKey,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(UnaSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sin "Cancelar" ni menú: hasta crear la primera tarea no se puede hacer nada más (R2).
                const Wordmark(),
                const SizedBox(height: UnaSpace.xl),
                _Tag(text: l10n.editorTagFirst),
                const SizedBox(height: UnaSpace.sm),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    maxLength: Task.maxTextLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: UnaTheme.noteText(_controller.text),
                    cursorColor: UnaColors.ink,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.editorPlaceholder,
                      hintStyle: UnaTheme.noteText(l10n.editorPlaceholder)
                          .copyWith(color: UnaColors.placeholder),
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
