import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey;
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/early_tap_guard.dart';
import '../../ui/una_sheet.dart';

/// Abre "¿Eliminar esta tarea?" (spec 004, CA-004-01; prototipo "HOJA:
/// confirmar eliminar"). Devuelve true solo si se pulsa "Eliminar"; cancelar,
/// tocar fuera, el gesto atrás, deslizar hacia abajo o Esc devuelven null
/// (CA-004-02).
///
/// Con [ignoreEarlyTaps] (desde el listado), durante la ventana del doble
/// toque no responde a toques ni se cierra (CL-006-5).
Future<bool?> showDeleteConfirmSheet(
  BuildContext context, {
  required String label,
  bool ignoreEarlyTaps = false,
}) => showUnaSheet<bool>(
  context,
  builder: (_) {
    final sheet = DeleteConfirmSheet(label: label);
    return ignoreEarlyTaps
        ? EarlyTapGuard(duration: UnaMotion.doubleTapWindow, child: sheet)
        : sheet;
  },
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
              _ReadOrder(
                1,
                child: Semantics(
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
              ),
              const SizedBox(height: _gap),
              // Recortado a 3 líneas como en "¿Dónde la pones?" (DEV-23); el
              // lector lee el texto completo.
              _ReadOrder(
                2,
                child: Semantics(
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
              ),
              // Prototipo: el párrafo lleva 8 px de margen inferior.
              const SizedBox(height: _gap + UnaSpace.s),
              _ReadOrder(
                3,
                child: BrutalButton(
                  label: l10n.deleteConfirm,
                  height: UnaSizes.confirmButton,
                  fontSize: UnaFontSizes.option,
                  background: UnaColors.dangerFill,
                  onPressed: () => _close(true),
                ),
              ),
              // Prototipo: "Cancelar" lleva 4 px de margen superior.
              const SizedBox(height: _gap + UnaSpace.xs),
              // La acción segura recibe el foco al abrirse (CA-004-10): la
              // primera para el lector y con el foco del teclado.
              _ReadOrder(
                0,
                child: BrutalButton(
                  label: l10n.editorCancel,
                  height: UnaSizes.ghostButton,
                  fontSize: UnaFontSizes.body,
                  ghost: true,
                  autofocus: true,
                  onPressed: () => _close(null),
                ),
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

/// Orden de lectura del lector de pantalla dentro de la hoja. Al abrirse una
/// ruta con nombre, TalkBack anuncia el nombre y pone el foco en el **primer**
/// elemento: "Cancelar" va primero para que un doble toque por inercia no
/// elimine (CA-004-10). Después: título, texto y "Eliminar".
class _ReadOrder extends StatelessWidget {
  const _ReadOrder(this.order, {required this.child});
  final double order;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, sortKey: OrdinalSortKey(order), child: child);
}
