import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/delete_pending_task.dart';

/// Lo que se ve en el listado (spec 006).
@immutable
class TaskListState {
  const TaskListState({
    this.tasks,
    this.focus = const (id: null, serial: 0),
    this.flash = const (id: null, serial: 0),
  });

  /// Cola en el orden que se ve; null hasta que llega de la BD (mientras, la
  /// pantalla usa la que se leyó al abrirla, CA-006-20).
  final List<Task>? tasks;

  /// Fila que debe recibir el foco. El contador cambia en cada petición
  /// (CA-006-17).
  final ({String? id, int serial}) focus;

  /// Fila resaltada al crearla desde el listado (CA-006-15).
  final ({String? id, int serial}) flash;

  TaskListState copyWith({
    List<Task>? tasks,
    ({String? id, int serial})? focus,
    ({String? id, int serial})? flash,
  }) => TaskListState(
    tasks: tasks ?? this.tasks,
    focus: focus ?? this.focus,
    flash: flash ?? this.flash,
  );
}

/// Resultado de mover una tarea desde el listado.
sealed class MoveOutcome {
  const MoveOutcome();
}

/// Se guardó; [position] es 1…[total] (1 = tarea actual).
final class Moved extends MoveOutcome {
  const Moved(this.position, this.total);
  final int position;
  final int total;
}

/// Ya estaba ahí, o ya no está pendiente: no se escribió nada (CL-006-4).
final class NotMoved extends MoveOutcome {
  const NotMoved();
}

/// Falló la escritura: la fila vuelve a su sitio (spec 006 §5).
final class MoveFailed extends MoveOutcome {
  const MoveFailed(this.error);
  final Object error;
}

/// Estado del listado. Sigue la cola de la BD mientras la pantalla está
/// abierta y aplica los movimientos al instante, antes de guardarlos.
final taskListProvider =
    NotifierProvider.autoDispose<TaskListController, TaskListState>(
      TaskListController.new,
    );

class TaskListController extends Notifier<TaskListState> {
  StreamSubscription<List<Task>>? _sub;

  /// Movimientos que se están guardando: mientras tanto, lo que llega de la
  /// BD puede ser anterior al movimiento y no se pinta.
  int _saving = 0;
  List<Task>? _fromDb;

  /// Los movimientos se guardan de uno en uno: cada uno calcula su posición
  /// con la cola que dejó el anterior (dos a la vez podrían chocar).
  Future<void> _writes = Future.value();

  @override
  TaskListState build() {
    _sub = ref.watch(taskRepositoryProvider).watchPending().listen(
      (tasks) {
        _fromDb = tasks;
        if (_saving == 0) state = state.copyWith(tasks: tasks);
      },
      // No se registra: el error de SQLite puede incluir datos del usuario.
      onError: (Object _) {},
    );
    ref.onDispose(() => _sub?.cancel());
    return const TaskListState();
  }

  /// Lleva la tarea [id] a [toIndex] (0 = actual) de [current], la cola que
  /// se ve: se pinta al instante y después se guarda (CA-006-04/08/16).
  Future<MoveOutcome> move(List<Task> current, String id, int toIndex) async {
    final from = current.indexWhere((t) => t.id == id);
    if (from < 0) return const NotMoved();
    final to = toIndex.clamp(0, current.length - 1);
    if (to == from) return const NotMoved();
    final moved = [...current]..removeAt(from);
    moved.insert(to, current[from]);
    state = state.copyWith(tasks: moved);
    _saving++;
    final reorder = ref.read(reorderTaskProvider);
    final write = _writes.then((_) => reorder.call(id, to));
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    try {
      final result = await write;
      if (result == null) return const NotMoved();
      return Moved(result.position, result.total);
    } on TaskNotPending {
      return const NotMoved();
    } on Object catch (e) {
      return MoveFailed(e);
    } finally {
      _saving--;
      // Se vuelve a lo que diga la BD (leída ahora: lo último emitido podría
      // ser anterior a la escritura): el orden guardado o, si falló, el de
      // antes del movimiento.
      if (_saving == 0 && ref.mounted) {
        try {
          final db = await ref.read(taskRepositoryProvider).pendingTasks();
          if (ref.mounted && _saving == 0) state = state.copyWith(tasks: db);
        } on Object {
          if (ref.mounted && _fromDb != null) {
            state = state.copyWith(tasks: _fromDb);
          }
        }
      }
    }
  }

  /// Elimina la tarea pendiente [id] (CA-006-14). Relanza los errores de
  /// escritura; [TaskNotPending] si ya no estaba.
  Future<PendingDeletionResult> delete(String id) =>
      ref.read(deletePendingTaskProvider).call(id);

  /// Pide el foco para la fila [id] (CA-006-17).
  void focus(String id) =>
      state = state.copyWith(focus: (id: id, serial: state.focus.serial + 1));

  /// Resalta la fila [id] y le da el foco (CA-006-15).
  void flashAndFocus(String id) => state = state.copyWith(
    focus: (id: id, serial: state.focus.serial + 1),
    flash: (id: id, serial: state.flash.serial + 1),
  );
}
