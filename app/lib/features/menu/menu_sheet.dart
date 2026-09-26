import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Lo que se eligió en el menú (las demás opciones no cierran nada o solo
/// cierran el menú).
enum MenuAction { edit, delete, newTask }

/// Abre el menú de la tarea actual (spec 005). Devuelve la acción elegida, o null.
Future<MenuAction?> showMenuSheet(
  BuildContext context, {
  required int pendingCount,
}) => showUnaSheet<MenuAction>(
  context,
  builder: (sheet) => MenuSheet(
    pendingCount: pendingCount,
    onEdit: () => Navigator.of(sheet).pop(MenuAction.edit),
    onDelete: () => Navigator.of(sheet).pop(MenuAction.delete),
    // Llega con la spec 006: se ve activo y no hace nada (DEV-18).
    onAllTasks: () {},
    onNewTask: () => Navigator.of(sheet).pop(MenuAction.newTask),
    // Como el prototipo: cierra el menú (hasta la spec 010).
    onSettings: () => Navigator.of(sheet).pop(),
  ),
);

/// Menú de la tarea (spec 005, prototipo "HOJA: menú de la nota"): bloque
/// "Esta tarea" (Editar, Eliminar) y bloque general (Todas mis tareas, Nueva
/// tarea, Configuración).
class MenuSheet extends StatelessWidget {
  const MenuSheet({
    super.key,
    required this.pendingCount,
    required this.onEdit,
    required this.onDelete,
    required this.onAllTasks,
    required this.onNewTask,
    required this.onSettings,
  });

  /// Tareas pendientes. Con una sola, "Todas mis tareas" se ve desactivado
  /// (DEV-11); con más, muestra el total a la derecha (CA-005-12, DEV-22).
  final int pendingCount;

  bool get onlyOne => pendingCount <= 1;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAllTasks;
  final VoidCallback onNewTask;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.menuButton,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parte 1: acciones de esta tarea.
          Container(
            padding: const EdgeInsets.fromLTRB(
              UnaSpace.l,
              UnaSpace.s,
              UnaSpace.l,
              UnaSpace.ml / 2,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: UnaColors.disabled,
                  width: UnaBorders.sectionWidth,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.menuSectionThisTask.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: UnaFonts.mono,
                            fontSize: UnaFontSizes.tag,
                            fontWeight: UnaFontWeights.bold,
                            letterSpacing:
                                UnaLetterSpacing.tagWide * UnaFontSizes.tag,
                            color: UnaColors.ink,
                          ),
                        ),
                      ),
                    ),
                    // Prototipo: botón de 44 con margen derecho de -14.
                    Transform.translate(
                      offset: const Offset(UnaSpace.m - 2, 0),
                      child: Semantics(
                        button: true,
                        label: l10n.menuClose,
                        excludeSemantics: true,
                        onTap: () => Navigator.of(context).pop(),
                        child: InkResponse(
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox.square(
                            dimension: kMinInteractiveDimension,
                            child: Center(
                              child: UnaIcon(
                                UnaIcons.close,
                                size: UnaSizes.iconS,
                                strokeWidth: UnaSizes.iconStrokeBold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _MenuRow(
                  icon: UnaIcons.edit,
                  label: l10n.menuEdit,
                  onTap: onEdit,
                ),
                _MenuRow(
                  icon: UnaIcons.trash,
                  label: l10n.menuDelete,
                  color: UnaColors.error,
                  divider: true,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
          // Parte 2: acciones generales.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UnaSpace.l,
              UnaSpace.ml / 2,
              UnaSpace.l,
              UnaSpace.xl - 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MenuRow(
                  icon: UnaIcons.list,
                  label: l10n.menuAllTasks,
                  enabled: !onlyOne,
                  disabledHint: l10n.menuAllTasksOnlyOne,
                  trailing: onlyOne ? null : '$pendingCount',
                  trailingSemantics: onlyOne
                      ? null
                      : l10n.menuAllTasksCount(pendingCount),
                  onTap: onAllTasks,
                ),
                const SizedBox(height: UnaSpace.m),
                BrutalButton(
                  label: l10n.menuNewTask,
                  icon: UnaIcons.plus,
                  iconSize: UnaSizes.icon,
                  iconStroke: UnaSizes.iconStroke,
                  onPressed: onNewTask,
                ),
                const SizedBox(height: UnaSpace.sm + 2),
                Center(
                  child: UnaLinkButton(
                    label: l10n.menuSettings,
                    onPressed: onSettings,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del menú (`.mrow`): 58 px, icono de 22, texto de 19 en negrita.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = UnaColors.ink,
    this.divider = false,
    this.enabled = true,
    this.disabledHint,
    this.trailing,
    this.trailingSemantics,
  });

  /// Texto pequeño alineado a la derecha (el total de tareas, CA-005-12).
  final String? trailing;

  /// Cómo lo lee el lector de pantalla ("3 tareas").
  final String? trailingSemantics;

  final UnaIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool divider;
  final bool enabled;
  final String? disabledHint;

  /// Prototipo: `.mrow:disabled { opacity: .35 }`.
  static const _disabledOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: trailingSemantics == null ? label : '$label, $trailingSemantics',
      hint: enabled ? null : disabledHint,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            highlightColor: UnaColors.pressed,
            splashFactory: NoSplash.splashFactory,
            child: Container(
              height: UnaSizes.menuRow,
              // A la derecha, sin margen: el total queda alineado con el borde
              // del botón "Nueva tarea".
              padding: const EdgeInsets.only(left: UnaSpace.xs),
              decoration: divider
                  ? const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: UnaColors.disabled,
                          width: UnaBorders.hairlineWidth,
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  UnaIcon(icon, color: color),
                  const SizedBox(width: UnaSpace.m),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.bodyL,
                        fontWeight: UnaFontWeights.bold,
                        color: color,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: TextStyle(
                        fontFamily: UnaFonts.mono,
                        fontSize: UnaFontSizes.link,
                        fontWeight: UnaFontWeights.bold,
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
