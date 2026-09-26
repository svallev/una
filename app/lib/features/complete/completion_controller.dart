import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/complete_current_task.dart';

/// Fases de completar (spec 003):
/// - `completing`: se guarda y la tarea sigue en pantalla con el relleno lleno;
/// - `celebrating`: la nota se rompe y se ve la enhorabuena;
/// - `fading`: la enhorabuena se desvanece y aparece la siguiente.
enum CompletionPhase { idle, completing, celebrating, fading }

@immutable
class CompletionState {
  const CompletionState(this.phase, {this.task, this.hasNext = false});
  const CompletionState.idle() : this(CompletionPhase.idle);

  final CompletionPhase phase;

  /// La tarea que se completa (congelada en pantalla mientras dura).
  final Task? task;

  /// ¿Queda otra pendiente? ("Ahora a por la siguiente →")
  final bool hasNext;

  /// Mientras no es `idle`, la pantalla ignora toques, acciones y el gesto
  /// atrás sin cambiar de aspecto (CA-003-09, DEV-17).
  bool get busy => phase != CompletionPhase.idle;

  CompletionState copyWith(CompletionPhase phase) =>
      CompletionState(phase, task: task, hasNext: hasNext);
}

final completionProvider =
    NotifierProvider<CompletionController, CompletionState>(
      CompletionController.new,
    );

class CompletionController extends Notifier<CompletionState> {
  Timer? _pause;

  @override
  CompletionState build() {
    ref.onDispose(() => _pause?.cancel());
    return const CompletionState.idle();
  }

  /// Completa [task]: guarda **antes** de animar (CA-003-03a, CL-003-1), vibra
  /// y, tras `holdDonePause`, empieza la enhorabuena. Devuelve null si ya había
  /// una en curso. Si falla al guardar, vuelve a `idle` y relanza el error
  /// (CA-003-12).
  Future<CompletionResult?> complete(Task task) async {
    if (state.busy) return null;
    state = CompletionState(CompletionPhase.completing, task: task);
    final CompletionResult result;
    try {
      result = await ref.read(completeCurrentTaskProvider).call(task);
    } on Object {
      state = const CompletionState.idle();
      rethrow;
    }
    ref.read(hasHistoryProvider.notifier).mark();
    // Respeta el ajuste del sistema y no necesita el permiso VIBRATE (DEV-19).
    unawaited(HapticFeedback.lightImpact());
    state = CompletionState(
      CompletionPhase.completing,
      task: result.completed,
      hasNext: result.next != null,
    );
    _pause = Timer(UnaMotion.holdDonePause, () {
      if (state.phase != CompletionPhase.completing) return;
      // En segundo plano no se celebra: al volver se ve la siguiente (CL-003-7).
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        finish();
      } else {
        state = state.copyWith(CompletionPhase.celebrating);
      }
    });
    return result;
  }

  /// Fin de `successHold`: la enhorabuena empieza a desvanecerse.
  void startFade() {
    if (state.phase == CompletionPhase.celebrating) {
      state = state.copyWith(CompletionPhase.fading);
    }
  }

  /// Fin del fundido: ya se ve la siguiente tarea (o "Todo hecho.").
  void finish() {
    _pause?.cancel();
    state = const CompletionState.idle();
    // El foco va a la nueva tarea o a "Todo hecho." (CA-003-07).
    ref.read(screenFocusProvider.notifier).signal();
  }
}
