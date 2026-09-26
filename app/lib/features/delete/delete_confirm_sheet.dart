import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_sheet.dart';

/// Abre "¿Eliminar esta tarea?" (spec 004, CA-004-01; prototipo "HOJA:
/// confirmar eliminar"). Devuelve true solo si se pulsa "Eliminar"; cancelar,
/// tocar fuera, el gesto atrás, deslizar hacia abajo o Esc devuelven null
/// (CA-004-02).
Future<bool?> showDeleteConfirmSheet(
  BuildContext context, {
  required String label,
}) => showUnaSheet<bool>(
  context,
  builder: (_) => DeleteConfirmSheet(label: label),
);

class DeleteConfirmSheet extends StatefulWidget {
  const DeleteConfirmSheet({super.key, required this.label});

  /// Texto de la tarea (o, con 007–009, el nombre del archivo o el dominio).
  final String label;

  @override
  State<DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<DeleteConfirmSheet> {
  // Una doble pulsación rápida elimina una sola vez (CL-004-1).
  bool _chosen = false;

  void _close(bool? confirmed) {
    if (_chosen) return;
    _chosen = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _close(null),
      },
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.deleteTitle,
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
                  l10n.deleteTitle,
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
              // Recortado a 3 líneas como en "¿Dónde la pones?" (DEV-23); el
              // lector lee el texto completo.
              Semantics(
                label: l10n.deleteBody(widget.label),
                excludeSemantics: true,
                child: Text(
                  l10n.deleteBody(widget.label),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: UnaFonts.mono,
                    fontSize: UnaFontSizes.caption,
                    height: 1.45,
                    color: UnaColors.ink,
                  ),
                ),
              ),
              // Prototipo: el párrafo lleva 8 px de margen inferior.
              const SizedBox(height: _gap + UnaSpace.s),
              BrutalButton(
                label: l10n.deleteConfirm,
                height: UnaSizes.confirmButton,
                fontSize: UnaFontSizes.option,
                background: UnaColors.dangerFill,
                onPressed: () => _close(true),
              ),
              // Prototipo: "Cancelar" lleva 4 px de margen superior.
              const SizedBox(height: _gap + UnaSpace.xs),
              // La acción segura recibe el foco al abrirse (CA-004-10).
              BrutalButton(
                label: l10n.editorCancel,
                height: UnaSizes.ghostButton,
                fontSize: UnaFontSizes.body,
                ghost: true,
                autofocus: true,
                onPressed: () => _close(null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prototipo: `gap: 14px`.
  static const _gap = UnaSpace.sm + UnaSpace.xxs;
}
