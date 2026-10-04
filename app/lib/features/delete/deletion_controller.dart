import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/delete_current_task.dart';
import '../complete/completion_controller.dart';

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
  Future<DeletionResult?> delete(Task task) async {
    if (state.busy || ref.read(completionProvider).busy) return null;
    final generation = state.generation;
    state = DeletionState(
      DeletionPhase.deleting,
      task: task,
      generation: generation,
    );
    final janitor = ref.read(attachmentJanitorProvider);
    final DeletionResult result;
    try {
      result = await ref.read(deleteCurrentTaskProvider).call(task);
    } on Object {
      state = DeletionState(DeletionPhase.idle, generation: generation);
      rethrow;
    }
    // Provisional hasta que haya card (T-014-06): la eliminación es definitiva
    // al guardarla, como antes (ADR-0021: los archivos, después de la fila).
    if (result.deleted.attachment case final a?) {
      await janitor.discardHeld(a.id);
    }
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

  /// Fin del arrugado: ya se ve la siguiente tarea (o "Todo hecho.").
  void finish() {
    if (!state.busy) return;
    state = DeletionState(DeletionPhase.idle, generation: state.generation);
    // El foco va a la nueva tarea o a "Todo hecho." (CA-004-11).
    ref.read(screenFocusProvider.notifier).signal();
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
