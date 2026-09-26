import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/color_picker.dart';
import '../domain/entities/task.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/id_generator.dart';
import '../domain/ports/task_repository.dart';
import '../domain/usecases/complete_current_task.dart';
import '../domain/usecases/create_task.dart';
import '../domain/usecases/delete_current_task.dart';
import '../domain/usecases/delete_pending_task.dart';
import '../domain/usecases/reorder_task.dart';
import '../domain/usecases/update_task_text.dart';

/// Se sobrescriben en `main` (y en los tests) con los repositorios ya abiertos.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => throw UnimplementedError(),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError(),
);

/// Estado leído antes del primer fotograma (P2): se inyecta para no pintar un "cargando".
final bootStateProvider = Provider<BootState>(
  (ref) => throw UnimplementedError(),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>((ref) => const UuidV7Ids());

/// Colores de las tareas nuevas; en los tests, con semilla fija.
final colorPickerProvider = Provider<ColorPicker>((ref) => ColorPicker());

/// Color de la primera tarea (amarillo, CA-001-08): lo comparten la bienvenida
/// y el editor, que se funden en el mismo color (prototipo, `introColor`).
final firstTaskColorProvider = Provider<int>(
  (ref) => ColorPicker.firstTaskColorKey,
);

final createTaskProvider = Provider<CreateTask>(
  (ref) => CreateTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    colors: ref.watch(colorPickerProvider),
  ),
);

final updateTaskTextProvider = Provider<UpdateTaskText>(
  (ref) => UpdateTaskText(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final completeCurrentTaskProvider = Provider<CompleteCurrentTask>(
  (ref) => CompleteCurrentTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deleteCurrentTaskProvider = Provider<DeleteCurrentTask>(
  (ref) => DeleteCurrentTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deletePendingTaskProvider = Provider<DeletePendingTask>(
  (ref) => DeletePendingTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final reorderTaskProvider = Provider<ReorderTask>(
  (ref) => ReorderTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// ¿Hay tareas completadas o eliminadas? Sin pendientes, decide entre
/// "Todo hecho." y el editor de la primera tarea (CA-003-11, CA-004-08).
final hasHistoryProvider = NotifierProvider<HasHistoryController, bool>(
  HasHistoryController.new,
);

class HasHistoryController extends Notifier<bool> {
  @override
  bool build() => ref.read(bootStateProvider).hasHistory;

  /// Tras completar o eliminar una tarea.
  void mark() => state = true;
}

/// Aumenta cada vez que la pantalla principal debe recuperar el foco (tras
/// completar, crear o editar): la tarea actual o "Todo hecho." lo toman
/// (CA-003-07, spec 002 §6).
final screenFocusProvider = NotifierProvider<ScreenFocus, int>(ScreenFocus.new);

class ScreenFocus extends Notifier<int> {
  @override
  int build() => 0;

  void signal() => state++;
}

/// Tarea actual: arranca con la leída en el arranque y sigue los cambios de la BD.
final currentTaskProvider = NotifierProvider<CurrentTaskController, Task?>(
  CurrentTaskController.new,
);

class CurrentTaskController extends Notifier<Task?> {
  StreamSubscription<Task?>? _sub;

  @override
  Task? build() {
    final repo = ref.watch(taskRepositoryProvider);
    _sub = repo.watchCurrentTask().listen(
      (t) => state = t,
      // Se conserva la última tarea conocida. No se registra el error: el de
      // SQLite puede incluir la sentencia y datos del usuario (MASVS-STORAGE).
      onError: (Object _) {},
    );
    ref.onDispose(() => _sub?.cancel());
    return ref.read(bootStateProvider).currentTask;
  }
}

/// ¿Se vio ya la bienvenida? (CA-001-05)
final firstRunDoneProvider = NotifierProvider<FirstRunController, bool>(
  FirstRunController.new,
);

class FirstRunController extends Notifier<bool> {
  @override
  bool build() => ref.read(bootStateProvider).firstRunDone;

  /// Se llama en cuanto se muestra la bienvenida: si la app se mata a mitad de
  /// la animación, al reabrir se va al editor (CL-001-4). No cambia el estado en
  /// memoria para no cortar la animación. Si no se puede escribir, la bienvenida
  /// se repetirá una vez más: es inocuo y el error de escritura real se muestra
  /// al guardar la tarea.
  Future<void> persistSeen() async {
    try {
      await ref.read(settingsRepositoryProvider).setFirstRunDone();
    } on Object {
      // Ver arriba: best effort.
    }
  }

  /// Fin de la bienvenida: se pasa al editor.
  void markDone() => state = true;
}

/// Resultado del arranque.
class BootState {
  const BootState({
    required this.currentTask,
    required this.firstRunDone,
    this.hasHistory = false,
  });
  final Task? currentTask;
  final bool firstRunDone;
  final bool hasHistory;
}

class UuidV7Ids implements IdGenerator {
  const UuidV7Ids();
  static const _uuid = Uuid();
  @override
  String newId() => _uuid.v7();
}
