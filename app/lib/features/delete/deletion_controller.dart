import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/delete_current_task.dart';
import '../complete/completion_controller.dart';
import 'undo_controller.dart';

/// Fases de eliminar la tarea actual (spec 004):
/// - `deleting`: se guarda y la tarea sigue en pantalla;
/// - `crumpling`: la nota se arruga y cae en la papelera; detrás ya se ve la
///   siguiente (o "Todo hecho.").
enum DeletionPhase { idle, deleting, crumpling }

@immutable
class DeletionState {
  const DeletionState(this.phase, {this.task, this.next, this.generation = 0});
  const DeletionState.idle() : this(DeletionPhase.idle);

  final DeletionPhase phase;

  /// La tarea que se elimina, tal como se veía (para la animación).
  final Task? task;

  /// La nueva tarea actual, o null si era la última.
  final Task? next;

  /// Aumenta con cada arrugado: la pantalla de detrás se monta de nuevo, sin
  /// el fundido de la eliminada (CA-004-04).
  final int generation;

  /// Mientras no es `idle`, la pantalla ignora toques, acciones y el gesto
  /// atrás sin cambiar de aspecto (CA-004-05).
  bool get busy => phase != DeletionPhase.idle;
}

final deletionProvider = NotifierProvider<DeletionController, DeletionState>(
  DeletionController.new,
);

class DeletionController extends Notifier<DeletionState> {
  @override
  DeletionState build() => const DeletionState.idle();

  /// Elimina [task]: guarda **antes** de animar (CA-004-03) y empieza el
  /// arrugado. Devuelve null si ya había una eliminación o una compleción en
  /// curso. Si falla al guardar, vuelve a `idle` y relanza el error
  /// (CA-004-13).
  ///
  /// La eliminación anterior, si aún se podía deshacer, pasa a ser definitiva
  /// **antes** de escribir, también si luego falla (CA-014-08, CA-014-22). La
  /// de [task] queda retenida en [UndoController] hasta que la card
  /// desaparezca (ADR-0021).
  Future<DeletionResult?> delete(Task task) async {
    if (state.busy || ref.read(completionProvider).busy) return null;
    final undo = ref.read(undoProvider.notifier);
    undo.commit();
    final epoch = undo.epoch;
    final generation = state.generation;
    state = DeletionState(
      DeletionPhase.deleting,
      task: task,
      generation: generation,
    );
    final DeletionResult result;
    try {
      result = await ref.read(deleteCurrentTaskProvider).call(task);
    } on Object {
      state = DeletionState(DeletionPhase.idle, generation: generation);
      rethrow;
    }
    // La card espera al final del arrugado; si la app pasó a segundo plano
    // mientras se guardaba, la eliminación ya es definitiva y no hay card.
    undo.hold(result.deleted, host: UndoHost.home, epoch: epoch);
    state = DeletionState(
      DeletionPhase.crumpling,
      task: result.deleted,
      next: result.next,
      generation: generation + 1,
    );
    // En segundo plano no se anima: al volver se ve la siguiente (CA-004-03).
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) finish();
    return result;
  }

  /// Fin del arrugado: ya se ve la siguiente tarea (o "Todo hecho.") y,
  /// encima, la card de deshacer, a la que va el foco (CA-014-01, CA-014-16).
  /// Si la eliminación ya es definitiva (segundo plano, otra acción), no hay
  /// card y el foco va a la tarea o al título, como antes.
  void finish() {
    if (!state.busy) return;
    state = DeletionState(DeletionPhase.idle, generation: state.generation);
    _showCardOrFocus();
  }

  void _showCardOrFocus() {
    final undo = ref.read(undoProvider.notifier);
    if (ref.read(undoProvider).phase == UndoPhase.crumpling) {
      undo.show();
    } else {
      ref.read(screenFocusProvider.notifier).signal();
    }
  }

  /// La app pasa a segundo plano durante el arrugado: termina ya, sin card
  /// (pasar a segundo plano hace definitiva la eliminación, CA-014-11); al
  /// volver se ve la siguiente sin repetir la animación (CA-004-03,
  /// CL-014-15). Mientras aún se guarda no hace nada: `delete` lo termina al
  /// acabar, y así no se puede empezar otra eliminación entre medias.
  void finishNow() {
    if (state.phase != DeletionPhase.crumpling) return;
    state = DeletionState(DeletionPhase.idle, generation: state.generation);
    ref.read(screenFocusProvider.notifier).signal();
  }
}
