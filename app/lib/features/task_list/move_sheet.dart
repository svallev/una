import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Formas de mover una tarea sin arrastrarla (spec 006, CA-006-09).
enum MoveChoice { makeCurrent, up, down }

/// Opciones que tienen sentido en la posición [position] (1…[total]), en el
/// orden fijo de CA-006-09: "Hacer actual" desde la 2.ª; "Mover arriba" desde
/// la 3.ª (en la 2.ª sería lo mismo que "Hacer actual"); "Mover abajo" salvo en
/// la última. La primera no tiene ninguna.
List<MoveChoice> moveChoicesFor(int position, int total) => [
  if (position >= 2) MoveChoice.makeCurrent,
  if (position >= 3) MoveChoice.up,
  if (position >= 2 && position < total) MoveChoice.down,
];

/// Índice de destino (0 = tarea actual) de [choice] desde [position] (1…N).
int moveTargetIndex(MoveChoice choice, int position) => switch (choice) {
  MoveChoice.makeCurrent => 0,
  MoveChoice.up => position - 2,
  MoveChoice.down => position,
};

String moveChoiceLabel(AppLocalizations l10n, MoveChoice choice) =>
    switch (choice) {
      MoveChoice.makeCurrent => l10n.listMakeCurrent,
      MoveChoice.up => l10n.listMoveUp,
      MoveChoice.down => l10n.listMoveDown,
    };

/// Hoja "Mover tarea" (DEV-28): se abre al tocar el asa. Devuelve lo elegido,
/// o null si se cierra sin elegir.
Future<MoveChoice?> showMoveSheet(
  BuildContext context, {
  required int position,
  required int total,
}) => showUnaSheet<MoveChoice>(
  context,
  builder: (sheet) => MoveSheet(
    choices: moveChoicesFor(position, total),
    onChoice: (c) => Navigator.of(sheet).pop(c),
  ),
);

class MoveSheet extends StatelessWidget {
  const MoveSheet({super.key, required this.choices, required this.onChoice});

  final List<MoveChoice> choices;
  final ValueChanged<MoveChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.listMove,
      child: Padding(
        // Mismo relleno que el bloque "Esta tarea" del menú.
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.s,
          UnaSpace.l,
          UnaSpace.xl - 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(label: l10n.listMove, closeLabel: l10n.menuClose),
            for (final (i, c) in choices.indexed)
              SheetRow(
                icon: switch (c) {
                  MoveChoice.makeCurrent => UnaIcons.arrowToTop,
                  MoveChoice.up => UnaIcons.arrowUp,
                  MoveChoice.down => UnaIcons.arrowDown,
                },
                label: moveChoiceLabel(l10n, c),
                divider: i > 0,
                onTap: () => onChoice(c),
              ),
          ],
        ),
      ),
    );
  }
}
