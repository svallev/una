import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/color_picker.dart';
import '../domain/entities/task.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/id_generator.dart';
import '../domain/ports/task_repository.dart';
import '../domain/usecases/create_task.dart';

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

final createTaskProvider = Provider<CreateTask>(
  (ref) => CreateTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    colors: ref.watch(colorPickerProvider),
  ),
);

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
  const BootState({required this.currentTask, required this.firstRunDone});
  final Task? currentTask;
  final bool firstRunDone;
}

class UuidV7Ids implements IdGenerator {
  const UuidV7Ids();
  static const _uuid = Uuid();
  @override
  String newId() => _uuid.v7();
}
