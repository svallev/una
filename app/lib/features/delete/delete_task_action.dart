import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/complete_current_task.dart' show TaskNotCurrent;
import '../../l10n/generated/app_localizations.dart';
import 'deletion_controller.dart';
import 'undo_controller.dart';

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

/// "Deshacer" de la card (CA-014-09, CA-014-18, CA-014-23): recupera la tarea
/// eliminada, en su sitio, y lleva allí el foco. Las guardas (350 ms desde que
/// aparece la card, una sola petición) son de `UndoController.undo`.
///
/// La pantalla que la lanza puede desaparecer al recuperar (la principal se
/// monta de nuevo sin fundido): todo lo que hace falta después se guarda antes.
Future<void> undoDeletion(BuildContext context, WidgetRef ref) =>
    _Restoration.of(context, ref).run();

/// Cuánto se espera, como mucho, a que la BD dé por actual la tarea recuperada
/// antes de mostrarla (la recuperada es siempre la actual en la pantalla
/// principal; si el aviso no llega, se sigue).
const _catchUpLimit = Duration(seconds: 1);

/// Una recuperación y, si falla, su aviso con "Reintentar".
class _Restoration {
  _Restoration({
    required this.container,
    required this.messenger,
    required this.l10n,
    required this.view,
    required this.direction,
    required this.theme,
    required this.bottom,
  });

  factory _Restoration.of(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    return _Restoration(
      container: ProviderScope.containerOf(context),
      messenger: ScaffoldMessenger.maybeOf(context),
      l10n: AppLocalizations.of(context),
      view: View.of(context),
      direction: Directionality.of(context),
      theme: Theme.of(context),
      // El aviso flota por encima de la zona de abajo, donde vuelve a verse el
      // botón: nunca lo tapa (CA-014-23, WCAG 2.4.11).
      bottom: mq.padding.bottom + UnaSizes.undoCard + UnaSizes.undoBar,
    );
  }

  final ProviderContainer container;
  final ScaffoldMessengerState? messenger;
  final AppLocalizations l10n;
  final FlutterView view;
  final TextDirection direction;
  final ThemeData theme;
  final double bottom;

  UndoController get _undo => container.read(undoProvider.notifier);

  Future<void> run() async {
    final outcome = await _undo.undo();
    switch (outcome) {
      case null:
        return;
      case Restored():
        await _restored(outcome);
      case UndoFailed(:final noSpace):
        _showError(noSpace);
    }
  }

  Future<void> _restored(Restored restored) async {
    // El listado y "Todo hecho." que vuelve a él son de T-014-08.
    if (restored.host != UndoHost.home || restored.returnTo != null) return;
    await _untilCurrent(restored.task.id);
    // Otra eliminación en marcha lleva su propio foco.
    if (container.read(deletionProvider).busy) return;
    // Sin fundido y con el foco en la tarea (también para el lector: no se
    // cuenta con el cambio de ventana, plan 014 §3). Un anuncio único cuando
    // ya se ve, para que el cambio de pantalla no lo corte (CA-014-18).
    container.read(undoRestorationsProvider.notifier).bump();
    container.read(screenFocusProvider.notifier).signal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(
        UnaMotion.sheetOut,
        () => unawaited(
          SemanticsService.sendAnnouncement(view, l10n.a11yUndone, direction),
        ),
      );
    });
  }

  /// La BD avisa un instante después de insertar: hasta que la recuperada es
  /// la actual, la pantalla de detrás sigue siendo la anterior.
  Future<void> _untilCurrent(String id) async {
    if (container.read(currentTaskProvider)?.id == id) return;
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final sub = container.listen(currentTaskProvider, (_, task) {
      if (task?.id == id) finish();
    });
    final timer = Timer(_catchUpLimit, finish);
    try {
      await done.future;
    } finally {
      sub.close();
      timer.cancel();
    }
  }

  /// "No hemos podido recuperar la tarea" con "Reintentar" (CA-014-23): el foco
  /// del lector y el del teclado van a "Reintentar". Un `commit` quita el aviso
  /// sin animación (ya no se puede recuperar); descartarlo, también hace
  /// definitiva la eliminación.
  void _showError(bool noSpace) {
    final messenger = this.messenger;
    if (messenger == null) {
      // Sin dónde avisar no se puede reintentar: es definitiva.
      _undo.commit();
      return;
    }
    final retry = FocusNode(debugLabel: 'undo-retry');
    final retrySemantics = GlobalKey();
    ProviderSubscription<UndoState>? sub;
    var handled = false;
    // Cierra el aviso solo una vez (un toque en "Reintentar" ya lo cierra).
    void release() {
      handled = true;
      sub?.close();
      sub = null;
    }

    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: UnaSpace.l,
          right: UnaSpace.l,
          bottom: bottom,
        ),
        persist: true,
        content: Row(
          children: [
            Expanded(
              child: Text(noSpace ? l10n.storageErrorNoSpace : l10n.undoError),
            ),
            TextButton(
              focusNode: retry,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.inversePrimary,
              ),
              onPressed: () {
                // Solo vuelve a pedir la recuperación: no guarda la tarea.
                release();
                messenger.hideCurrentSnackBar();
                unawaited(run());
              },
              child: Semantics(key: retrySemantics, child: Text(l10n.retry)),
            ),
          ],
        ),
      ),
    );
    sub = container.listen(undoProvider, (_, next) {
      // Lo que la hace definitiva (CA-014-11) cierra el aviso, sin animación.
      if (handled || next.phase == UndoPhase.failed) return;
      if (next.phase == UndoPhase.restoring) return;
      release();
      messenger.removeCurrentSnackBar();
    });
    unawaited(
      controller.closed.then((reason) {
        final wasHandled = handled;
        release();
        retry.dispose();
        // Deslizarlo o "Descartar": ya no se quiere recuperar.
        if (!wasHandled &&
            (reason == SnackBarClosedReason.dismiss ||
                reason == SnackBarClosedReason.swipe)) {
          _undo.commit();
        }
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (handled) return;
      final keyboard =
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
      if (retry.context != null &&
          (keyboard || MediaQuery.accessibleNavigationOf(retry.context!))) {
        retry.requestFocus();
      }
      retrySemantics.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }
}
