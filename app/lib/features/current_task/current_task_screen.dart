import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sticky_note.dart';
import '../../ui/wordmark.dart';

/// Pantalla principal: solo la tarea actual, a pantalla completa (R6, CA-001-06/07).
class CurrentTaskScreen extends StatelessWidget {
  const CurrentTaskScreen({super.key, required this.task});

  final Task task;

  /// Límite de escala de texto para la nota (docs/design/tokens.md).
  static const maxNoteTextScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = task.text ?? '';
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: StickyNote(
        colorKey: task.colorKey,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(UnaSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Wordmark(),
                    const Spacer(),
                    // El menú llega con la spec 005.
                    _SquareIconButton(
                      icon: Icons.menu,
                      label: l10n.menuButton,
                      fill: UnaPalettes
                          .classic[task.colorKey % UnaPalettes.classic.length],
                      onPressed: null,
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: MediaQuery(
                        data: mq.copyWith(
                          textScaler: mq.textScaler.clamp(
                            maxScaleFactor: maxNoteTextScale,
                          ),
                        ),
                        child: Semantics(
                          label: l10n.currentTaskSemantics(text),
                          excludeSemantics: true,
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(text, style: UnaTheme.noteText(text)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Completar (mantener pulsado) llega con la spec 003.
                BrutalButton(
                  label: l10n.completeButton,
                  icon: Icons.check,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.label,
    required this.fill,
    required this.onPressed,
  });
  final IconData icon;
  final String label;

  /// En Flutter la sombra también se pinta bajo la caja: sin relleno se vería
  /// un cuadrado negro (en el CSS del prototipo, la sombra solo va por fuera).
  final Color fill;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        child: Container(
          width: UnaSizes.minTouchTarget,
          height: UnaSizes.minTouchTarget,
          decoration: BoxDecoration(
            border: const Border.fromBorderSide(
              BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
            ),
            boxShadow: const [UnaShadows.iconButton],
            color: fill,
          ),
          child: Icon(icon, size: UnaSizes.icon, color: UnaColors.ink),
        ),
      ),
    );
  }
}
