import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/attachments/attachment_images.dart';
import '../data/attachments/memory_attachment_store.dart';
import '../data/licenses/flutter_license_source.dart';
import '../data/links/native_link_opener.dart';
import '../data/links/new_tab.dart';
import '../data/platform/accessibility_timeouts.dart';
import '../data/web/web_data_janitor.dart';
import '../data/web/webview_hardening.dart';
import '../domain/entities/color_picker.dart';
import '../domain/entities/license_package.dart';
import '../domain/entities/locale_choice.dart';
import '../domain/entities/task.dart';
import '../domain/ports/accessibility_timeouts.dart';
import '../domain/ports/attachment_store.dart';
import '../domain/ports/clock.dart';
import '../domain/ports/id_generator.dart';
import '../domain/ports/image_importer.dart';
import '../domain/ports/license_source.dart';
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
import '../domain/usecases/restore_deleted_task.dart';

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

/// Único servicio de borrado de archivos de adjuntos (CA-007-16). Uno por
/// app: guarda en memoria qué adjuntos de eliminaciones se pueden deshacer
/// (ADR-0021).
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

/// De dónde salen las licencias (spec 012): el registro de Flutter; en los
/// tests, una fuente falsa. No lee nada hasta que se pide [licensesProvider].
final licenseSourceProvider = Provider<LicenseSource>(
  (ref) => FlutterLicenseSource(),
);

/// Las licencias de lo de terceros (CA-012-03). Se leen solo al abrir el nivel 2
/// (CA-012-16) y se sueltan al salir. Una lista vacía es un error (spec 012 §5).
/// Sin reintento automático (el de Riverpod 3 taparía el error): "Reintentar"
/// invalida el proveedor (CA-012-15).
final licensesProvider = FutureProvider.autoDispose<List<LicensePackage>>((
  ref,
) async {
  final packages = await ref.watch(licenseSourceProvider).load();
  if (packages.isEmpty) throw const LicensesUnavailable();
  return packages;
}, retry: (_, _) => null);

/// Web de pruebas (ADR-0010): la tarea web no tiene WebView; se ve como la
/// tarjeta del prototipo, con "Abrir página →" (CL-009-5).
final webPreviewProvider = Provider<bool>((ref) => kIsWeb);

/// Abre una dirección en una pestaña nueva, con `noopener` (solo la web de
/// pruebas, CL-009-5); en los tests, uno falso.
final newTabOpenerProvider = Provider<void Function(Uri address)>(
  (ref) => openInNewTab,
);

/// Borrado de los datos de la WebView de la tarea web (CA-009-13): al salir y,
/// con la marca `files/web_used`, después del primer fotograma del arranque.
/// La web de pruebas no tiene WebView (CL-009-5).
final webDataJanitorProvider = Provider<WebDataJanitor>(
  (ref) => kIsWeb
      ? WebDataJanitor.inactive()
      : WebDataJanitor(
          filesDir: getApplicationSupportDirectory,
          cleaner: const ChannelWebViewHardening(),
        ),
);

/// Si la tarea con imagen, PDF o web gira a horizontal (CA-008-11,
/// CA-009-15). La web de pruebas no gira (CL-008-12, CL-009-5): con la ventana
/// apaisada se ve como en vertical.
final attachmentRotatesProvider = Provider<bool>((ref) => !kIsWeb);

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

/// Deshacer una eliminación (CA-014-09, ADR-0021).
final restoreDeletedTaskProvider = Provider<RestoreDeletedTask>(
  (ref) => RestoreDeletedTask(
    repository: ref.watch(taskRepositoryProvider),
    janitor: ref.watch(attachmentJanitorProvider),
  ),
);

/// "Tiempo para actuar" del sistema (CA-014-06): el canal `una/a11y` de
/// Android, consultado al empezar cada eliminación (nunca antes del primer
/// fotograma, P2). Sin canal (iOS, web de pruebas, tests) o con un error, 4 s.
final accessibilityTimeoutsProvider = Provider<AccessibilityTimeouts>(
  (ref) => const ChannelAccessibilityTimeouts(),
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

/// El botón de menú de la tarea debe recuperar el foco (teclado y lector de
/// pantalla): al cerrar Ajustes (spec 015, CA-015-02) y al volver a la tarea
/// tras 10 minutos o más en segundo plano con alguna pantalla encima
/// (CA-015-16). Es una petición pendiente, no un contador: si el botón existe
/// la toma en cuanto se pide; si se monta después (la tarea se vuelve a crear
/// al volver de los 10 minutos), la toma al crearse; y quien la pide la retira
/// en cuanto ha pasado el fotograma (sin botón, p. ej. la tarea con imagen en
/// horizontal, no queda nada pendiente que se lleve el foco más tarde).
final menuFocusProvider = NotifierProvider<MenuFocus, bool>(MenuFocus.new);

class MenuFocus extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() {
    if (state) state = false;
  }
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
///
/// La tarea actual se lee **primero**: una base de datos inaccesible
/// falla ahí y sale la pantalla de error de almacenamiento (CL-015-16). Los
/// dos ajustes de Ajustes (idioma y pantalla siempre activa) se leen después,
/// cada uno en su propio `try/catch`: si no se puede leer, vale su valor por
/// defecto y el arranque sigue (CA-015-26).
Future<BootState> readBootState(
  TaskRepository tasks,
  SettingsRepository settings,
) async {
  final current = await tasks.currentTask();
  return BootState(
    currentTask: current,
    firstRunDone: await settings.firstRunDone(),
    hasEverHadTasks: current != null || await settings.hasEverHadTasks(),
    keepScreenOn: await _orDefault(settings.keepScreenOn, false),
    locale: await _orDefault(settings.locale, LocaleChoice.system),
  );
}

/// El valor de [read], o [fallback] ante **cualquier** fallo. No se registra
/// el error (MASVS-STORAGE: el de SQLite puede llevar datos del usuario).
Future<T> _orDefault<T>(Future<T> Function() read, T fallback) async {
  try {
    return await read();
  } on Object {
    return fallback;
  }
}

/// Resultado del arranque.
class BootState {
  const BootState({
    required this.currentTask,
    required this.firstRunDone,
    this.hasEverHadTasks = false,
    this.keepScreenOn = false,
    this.locale = LocaleChoice.system,
  });
  final Task? currentTask;
  final bool firstRunDone;
  final bool hasEverHadTasks;

  /// Ajuste "Pantalla siempre activa" (CA-015-04): apagado por defecto.
  final bool keepScreenOn;

  /// Idioma elegido en Ajustes (CA-015-10): ya leído para que el primer
  /// fotograma salga en ese idioma.
  final LocaleChoice locale;
}

class UuidV7Ids implements IdGenerator {
  const UuidV7Ids();
  static const _uuid = Uuid();
  @override
  String newId() => _uuid.v7();
}
