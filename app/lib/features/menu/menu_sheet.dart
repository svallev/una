import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Lo que se eligió en el menú (las demás opciones no cierran nada o solo
/// cierran el menú).
enum MenuAction { edit, delete, allTasks, newTask }

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
    onAllTasks: () => Navigator.of(sheet).pop(MenuAction.allTasks),
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
                SheetHeader(
                  label: l10n.menuSectionThisTask,
                  closeLabel: l10n.menuClose,
                ),
                SheetRow(
                  icon: UnaIcons.edit,
                  label: l10n.menuEdit,
                  onTap: onEdit,
                ),
                SheetRow(
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
                SheetRow(
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
