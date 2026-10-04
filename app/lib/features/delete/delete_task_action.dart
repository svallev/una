import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/storage_errors.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/complete_current_task.dart' show TaskNotCurrent;
import '../../l10n/generated/app_localizations.dart';
import 'deletion_controller.dart';

/// Elimina [task], sin confirmación (menú, acción accesible o "Adjunto no
/// disponible", CA-014-01, CA-014-19). Devuelve false si no se pudo guardar:
/// la tarea sigue siendo la actual y se muestra el error con "Reintentar"
/// (CA-014-22).
///
/// No anuncia nada: la card de deshacer se lee sola al recibir el foco
/// (CA-014-16).
Future<bool> deleteTask(BuildContext context, WidgetRef ref, Task task) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final result = await ref.read(deletionProvider.notifier).delete(task);
    if (result == null) return false; // Ya había una en curso: no cuenta.
    // Si quedaba un aviso de un intento fallido, ya no aplica.
    messenger?.hideCurrentSnackBar();
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
