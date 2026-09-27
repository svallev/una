import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/attachments/attachment_images.dart';
import '../data/attachments/memory_attachment_store.dart';
import '../data/links/native_link_opener.dart';
import '../domain/entities/color_picker.dart';
import '../domain/entities/task.dart';
import '../domain/ports/attachment_store.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/id_generator.dart';
import '../domain/ports/image_importer.dart';
import '../domain/ports/link_opener.dart';
import '../domain/ports/pdf_importer.dart';
import '../domain/ports/task_repository.dart';
import '../domain/services/attachment_janitor.dart';
import '../domain/usecases/complete_current_task.dart';
import '../domain/usecases/create_task.dart';
import '../domain/usecases/delete_current_task.dart';
import '../domain/usecases/delete_pending_task.dart';
import '../domain/usecases/edit_task.dart';
import '../domain/usecases/import_image.dart';
import '../domain/usecases/import_pdf.dart';
import '../domain/usecases/reorder_task.dart';

/// Se sobrescriben en `main` (y en los tests) con los repositorios ya abiertos.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => throw UnimplementedError(),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError(),
);

/// Archivos de los adjuntos. En `main` se sobrescribe con el almacén en disco
/// (móvil) o en memoria (web); en los tests, en memoria.
final attachmentStoreProvider = Provider<AttachmentStore>(
  (ref) => MemoryAttachmentStore(),
);

/// Cómo se dibujan los archivos del almacén. En `main` se sobrescribe junto con
/// [attachmentStoreProvider]; por defecto, los del almacén en memoria.
final attachmentImagesProvider = Provider<AttachmentImages>((ref) {
  final store = ref.watch(attachmentStoreProvider);
  if (store is MemoryAttachmentStore) return MemoryAttachmentImages(store);
  throw UnimplementedError();
});

/// Importaciones en curso, que el barrido no toca (CA-007-16).
final importRegistryProvider = Provider<ImportRegistry>(
  (ref) => ImportRegistry(),
);

/// Único servicio de borrado de archivos de adjuntos (CA-007-16).
final attachmentJanitorProvider = Provider<AttachmentJanitor>(
  (ref) => AttachmentJanitor(
    store: ref.watch(attachmentStoreProvider),
    repository: ref.watch(taskRepositoryProvider),
    registry: ref.watch(importRegistryProvider),
  ),
);

/// Cámara, selector y limpieza de imágenes. En `main` se sobrescribe con el
/// canal nativo (Android); en los tests, con uno falso.
final imageImporterProvider = Provider<ImageImporter>(
  (ref) => throw UnimplementedError(),
);

final importImageProvider = Provider<ImportImage>(
  (ref) => ImportImage(
    importer: ref.watch(imageImporterProvider),
    janitor: ref.watch(attachmentJanitorProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

/// Selector y comprobación de PDF (spec 008). En `main` se sobrescribe con el
/// canal nativo y PDFium; en los tests, con uno falso.
final pdfImporterProvider = Provider<PdfImporter>(
  (ref) => throw UnimplementedError(),
);

final importPdfProvider = Provider<ImportPdf>(
  (ref) => ImportPdf(
    importer: ref.watch(pdfImporterProvider),
    janitor: ref.watch(attachmentJanitorProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

/// Abre los enlaces de un PDF (spec 008): el canal nativo; en los tests, uno
/// falso.
final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => const NativeLinkOpener(),
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
    store: ref.watch(attachmentStoreProvider),
    janitor: ref.watch(attachmentJanitorProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    colors: ref.watch(colorPickerProvider),
  ),
);

final editTaskProvider = Provider<EditTask>(
  (ref) => EditTask(
    repository: ref.watch(taskRepositoryProvider),
    store: ref.watch(attachmentStoreProvider),
    janitor: ref.watch(attachmentJanitorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final completeCurrentTaskProvider = Provider<CompleteCurrentTask>(
  (ref) => CompleteCurrentTask(
    repository: ref.watch(taskRepositoryProvider),
    janitor: ref.watch(attachmentJanitorProvider),
  ),
);

final deleteCurrentTaskProvider = Provider<DeleteCurrentTask>(
  (ref) => DeleteCurrentTask(
    repository: ref.watch(taskRepositoryProvider),
    janitor: ref.watch(attachmentJanitorProvider),
  ),
);

final deletePendingTaskProvider = Provider<DeletePendingTask>(
  (ref) => DeletePendingTask(
    repository: ref.watch(taskRepositoryProvider),
    janitor: ref.watch(attachmentJanitorProvider),
  ),
);

final reorderTaskProvider = Provider<ReorderTask>(
  (ref) => ReorderTask(
    repository: ref.watch(taskRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// ¿Se ha guardado alguna tarea alguna vez? Sin pendientes, decide entre
/// "Todo hecho." y el editor de la primera tarea (CA-001-05, CA-003-11,
/// CA-004-08, ADR-0012).
final hasEverHadTasksProvider =
    NotifierProvider<HasEverHadTasksController, bool>(
      HasEverHadTasksController.new,
    );

class HasEverHadTasksController extends Notifier<bool> {
  @override
  bool build() => ref.read(bootStateProvider).hasEverHadTasks;

  /// Tras crear una tarea.
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

/// Lee lo que decide la primera pantalla (CA-001-09). Con una tarea actual,
/// es que ya se guardó alguna; si no, lo dice el ajuste: "Todo hecho." o el
/// editor de la primera tarea (CA-003-11, CA-004-08, ADR-0012).
Future<BootState> readBootState(
  TaskRepository tasks,
  SettingsRepository settings,
) async {
  final current = await tasks.currentTask();
  return BootState(
    currentTask: current,
    firstRunDone: await settings.firstRunDone(),
    hasEverHadTasks: current != null || await settings.hasEverHadTasks(),
    keepScreenOn: await settings.keepScreenOn(),
  );
}

/// Resultado del arranque.
class BootState {
  const BootState({
    required this.currentTask,
    required this.firstRunDone,
    this.hasEverHadTasks = false,
    this.keepScreenOn = true,
  });
  final Task? currentTask;
  final bool firstRunDone;
  final bool hasEverHadTasks;

  /// Ajuste "Mantener la pantalla encendida con adjuntos" (CA-007-12).
  final bool keepScreenOn;
}

class UuidV7Ids implements IdGenerator {
  const UuidV7Ids();
  static const _uuid = Uuid();
  @override
  String newId() => _uuid.v7();
}
