import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/queue_position.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// "¿Dónde la pones?" (spec 002, CA-002-02; prototipo "HOJA: ¿dónde va la
/// nota nueva?"). Devuelve la posición elegida, o null para seguir editando.
Future<QueuePosition?> showPlacementSheet(
  BuildContext context, {
  required String text,
  required Color color,
}) => showUnaSheet<QueuePosition>(
  context,
  builder: (_) => PlacementSheet(text: text, color: color),
);

class PlacementSheet extends StatelessWidget {
  const PlacementSheet({super.key, required this.text, required this.color});

  final String text;

  /// Color de la nueva tarea: fondo de "Arriba del todo".
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void choose(QueuePosition p) => Navigator.of(context).pop(p);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.placementTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.ml + UnaSpace.xxs,
          UnaSpace.l,
          UnaSpace.xxl - UnaSpace.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.placementTitle,
                style: const TextStyle(
                  fontFamily: UnaFonts.display,
                  fontSize: UnaFontSizes.sheetTitle,
                  fontWeight: UnaFontWeights.extrabold,
                  letterSpacing:
                      UnaLetterSpacing.tighter * UnaFontSizes.sheetTitle,
                  color: UnaColors.ink,
                ),
              ),
            ),
            const SizedBox(height: _gap),
            Text(
              l10n.placementQuoted(text),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: UnaFonts.mono,
                fontSize: UnaFontSizes.caption,
                height: 1.45,
                color: UnaColors.ink,
              ),
            ),
            const SizedBox(height: _gap + UnaSpace.xs + 2),
            _Option(
              icon: UnaIcons.arrowUp,
              title: l10n.placementTop,
              hint: l10n.placementTopHint,
              background: color,
              filledIcon: true,
              onTap: () => choose(QueuePosition.top),
            ),
            const SizedBox(height: _gap),
            _Option(
              icon: UnaIcons.arrowDown,
              title: l10n.placementEnd,
              hint: l10n.placementEndHint,
              background: UnaColors.surface,
              filledIcon: false,
              onTap: () => choose(QueuePosition.end),
            ),
            const SizedBox(height: _gap + UnaSpace.xs),
            Center(
              child: UnaLinkButton(
                label: l10n.placementKeepEditing,
                height: kMinInteractiveDimension,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prototipo: `gap: 14px`.
  static const _gap = UnaSpace.sm + UnaSpace.xxs;
}

/// Opción de la hoja (`.bb` con icono cuadrado de 44, título y descripción).
class _Option extends StatefulWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.hint,
    required this.background,
    required this.filledIcon,
    required this.onTap,
  });

  final UnaIconData icon;
  final String title;
  final String hint;
  final Color background;
  final bool filledIcon;
  final VoidCallback onTap;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.hint}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: UnaMotion.press,
          transform: _down
              ? Matrix4.translationValues(4, 4, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(UnaSpace.m),
          decoration: BoxDecoration(
            color: widget.background,
            border: Border.all(
              color: UnaColors.ink,
              width: UnaBorders.strongWidth,
            ),
            boxShadow: [
              if (_down) UnaShadows.buttonPressed else UnaShadows.button,
            ],
          ),
          child: Row(
            children: [
              Container(
                width: UnaSizes.minTouchTarget,
                height: UnaSizes.minTouchTarget,
                decoration: BoxDecoration(
                  color: widget.filledIcon ? UnaColors.ink : null,
                  border: widget.filledIcon
                      ? null
                      : Border.all(
                          color: UnaColors.ink,
                          width: UnaBorders.strongWidth,
                        ),
                ),
                child: Center(
                  child: UnaIcon(
                    widget.icon,
                    strokeWidth: UnaSizes.iconStrokeBold,
                    color: widget.filledIcon ? UnaColors.onInk : UnaColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: UnaSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.option,
                        fontWeight: UnaFontWeights.extrabold,
                        color: UnaColors.ink,
                      ),
                    ),
                    const SizedBox(height: UnaSpace.xs),
                    Text(
                      widget.hint,
                      style: const TextStyle(
                        fontFamily: UnaFonts.mono,
                        fontSize: UnaFontSizes.tag,
                        height: 1.4,
                        color: UnaColors.ink,
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
