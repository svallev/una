import 'package:flutter/semantics.dart';

import '../l10n/generated/app_localizations.dart';

/// Flutter ordena las acciones personalizadas del lector por el orden en que
/// se crearon por primera vez en la app, no por el orden en que se declaran.
/// Se registran aquí, antes de pintar ninguna pantalla, en el orden de las
/// specs: la tarea actual (Completar, Eliminar) y las filas del listado
/// (CA-006-16: Hacer actual, Mover arriba, Mover abajo, Editar, Eliminar).
void registerSemanticsActionOrder(AppLocalizations l10n) {
  for (final label in [
    l10n.completeA11yAction,
    l10n.listMakeCurrent,
    l10n.listMoveUp,
    l10n.listMoveDown,
    l10n.listEdit,
    l10n.deleteA11yAction,
  ]) {
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
  }
}
