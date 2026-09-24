import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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

final createTaskProvider = Provider<CreateTask>(
  (ref) => CreateTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
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
    _sub = repo.watchCurrentTask().listen((t) => state = t);
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

  Future<void> markDone() async {
    await ref.read(settingsRepositoryProvider).setFirstRunDone();
    state = true;
  }
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
