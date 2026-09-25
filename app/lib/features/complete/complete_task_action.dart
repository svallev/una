import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/storage_errors.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/complete_current_task.dart';
import '../../l10n/generated/app_localizations.dart';
import 'completion_controller.dart';

/// Completa [task] desde la pantalla principal (gesto, teclado o acción
/// accesible). Devuelve false si no se pudo guardar: el botón retrocede y se
/// muestra el error con "Reintentar" (CA-003-12).
Future<bool> completeTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final l10n = AppLocalizations.of(context);
  final view = View.of(context);
  final direction = Directionality.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final result = await ref.read(completionProvider.notifier).complete(task);
    if (result == null) return true; // Ya había una en curso.
    // Un único anuncio (CA-003-07); la enhorabuena no se anuncia aparte.
    final next = result.next;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        next == null
            ? l10n.a11yCompletedAllDone
            : l10n.a11yCompletedNext(next.text ?? ''),
        direction,
      ),
    );
    return true;
  } on TaskNotCurrent {
    // La tarea ya no es la actual (p. ej., "Reintentar" tras cambiar): no
    // hay nada que completar ni que reintentar.
    messenger?.hideCurrentSnackBar();
    return false;
  } on Object catch (e) {
    // El aviso (SnackBar) ya se anuncia solo: no se duplica.
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.completeError,
        ),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            if (context.mounted) unawaited(completeTask(context, ref, task));
          },
        ),
        persist: true,
      ),
    );
    return false;
  }
}
