import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../domain/entities/staged_attachment.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/edit_task.dart';
import '../../l10n/generated/app_localizations.dart';
import '../delete/undo_controller.dart';
import 'url_sheet.dart';

/// Editar una tarea web, desde el menú o desde el listado (CA-009-05): en
/// lugar del editor, la hoja "Cargar URL" con la dirección que tiene.
///
/// - "Abrir" con una dirección válida la sustituye; `EditTask` conserva la
///   posición y el color, y con la misma dirección no cambia nada. Después se
///   llama a [onSaved] (el foco vuelve a la tarea o a la fila, como al guardar
///   el editor; spec 005 §5b, CA-006-13), sin anuncios.
/// - Cerrar la hoja la deja como estaba y llama a [onClosed].
/// - Si no se puede guardar, el aviso del editor (o el de falta de espacio)
///   con "Reintentar", que vuelve a guardar la misma dirección (spec 005 §5).
Future<void> editWebTask(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  required VoidCallback onSaved,
  VoidCallback? onClosed,
}) async {
  assert(task.attachment?.isWeb ?? false);
  final url = await showUrlSheet(context, initialUrl: task.attachment?.url);
  if (!context.mounted) return;
  if (url == null) {
    onClosed?.call();
    return;
  }
  await _save(context, ref, task, url, onSaved);
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  Task task,
  String url,
  VoidCallback onSaved,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  final web = StagedWeb(id: ref.read(idGeneratorProvider).newId(), url: url);
  // Guardar hace definitiva una eliminación que aún se podía deshacer; abrir la
  // hoja o cerrarla sin guardar, no (CA-014-11, CA-014-12).
  ref.read(undoProvider.notifier).commit();
  try {
    await ref
        .read(editTaskProvider)
        .call(task, '', attachment: ReplaceAttachment(web));
  } on Object catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.editorSaveError,
        ),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            if (context.mounted) _save(context, ref, task, url, onSaved);
          },
        ),
        persist: true,
      ),
    );
    return;
  }
  // Un aviso de un intento anterior ya no tiene sentido.
  messenger?.hideCurrentSnackBar();
  if (context.mounted) onSaved();
}
