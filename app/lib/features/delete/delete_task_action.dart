import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/complete_current_task.dart' show TaskNotCurrent;
import '../../l10n/generated/app_localizations.dart';
import 'delete_confirm_sheet.dart';
import 'deletion_controller.dart';

/// Pide confirmación y, si se confirma, elimina [task] (menú o acción
/// accesible, CA-004-01/10). Nunca elimina sin la hoja.
Future<void> confirmAndDeleteTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final confirmed = await showDeleteConfirmSheet(
    context,
    label: task.text ?? '',
  );
  if (!context.mounted) return;
  if (confirmed != true) {
    // Al cancelar, el foco vuelve a la tarea, no al botón de menú (CA-004-02).
    ref.read(screenFocusProvider.notifier).signal();
    return;
  }
  await deleteTask(context, ref, task);
}

/// Elimina [task] ya confirmada. Devuelve false si no se pudo guardar: la
/// tarea sigue siendo la actual y se muestra el error con "Reintentar"
/// (CA-004-13).
Future<bool> deleteTask(BuildContext context, WidgetRef ref, Task task) async {
  final l10n = AppLocalizations.of(context);
  final view = View.of(context);
  final direction = Directionality.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final result = await ref.read(deletionProvider.notifier).delete(task);
    if (result == null) return false; // Ya había una en curso: no cuenta.
    // Si quedaba un aviso de un intento fallido, ya no aplica.
    messenger?.hideCurrentSnackBar();
    // Un único anuncio (CA-004-11), cuando la hoja ya ha bajado: el cambio
    // de ventana podría cortarlo.
    final next = result.next;
    Timer(UnaMotion.sheetOut, () {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          next == null
              ? l10n.a11yDeletedAllDone
              : l10n.a11yDeletedNext(next.text ?? ''),
          direction,
        ),
      );
    });
    return true;
  } on TaskNotCurrent {
    // Ya no es la actual (p. ej., "Reintentar" tras cambiar): nada que hacer.
    messenger?.hideCurrentSnackBar();
    return false;
  } on Object catch (e) {
    // El aviso (SnackBar) ya se anuncia solo: no se duplica.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.deleteError,
        ),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            if (context.mounted) unawaited(deleteTask(context, ref, task));
          },
        ),
        persist: true,
      ),
    );
    return false;
  }
}
