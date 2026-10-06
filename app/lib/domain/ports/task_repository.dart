import '../entities/attachment.dart';
import '../entities/locale_choice.dart';
import '../entities/task.dart';

/// Puerto de persistencia de tareas (ADR-0002). La UI y los casos de uso
/// nunca tocan la base de datos directamente.
abstract interface class TaskRepository {
  /// La primera tarea pendiente según `rank`, o null si no hay ninguna. Sus
  /// adjuntos vienen ordenados por `(position, id)` y **como mucho 10**; un
  /// tipo, origen o medidas que no se conocen no lanzan: la fila se lee con la
  /// marca `unreadable` (spec 016, CA-016-25). Igual en todas las lecturas.
  Future<Task?> currentTask();

  /// Emite la tarea actual cada vez que cambia.
  Stream<Task?> watchCurrentTask();

  /// Clave de orden de la primera y la última tarea pendiente.
  Future<String?> firstPendingRank();
  Future<String?> lastPendingRank();

  Future<int> countPending();

  /// Las tareas pendientes en orden (listado, spec 006).
  Future<List<Task>> pendingTasks();

  /// Emite las tareas pendientes en orden cada vez que cambia la cola.
  Stream<List<Task>> watchPending();

  /// Cambia la posición de la tarea pendiente [id] (spec 006, CA-006-10): solo
  /// su `rank` y su `updatedAt`. Devuelve false si ya no está pendiente.
  Future<bool> reorder(String id, String rank, DateTime at);

  /// Da claves nuevas y cortas a toda la cola, en el mismo orden, en una sola
  /// transacción (ADR-0002, CL-006-8). `updatedAt = at` en las renumeradas.
  Future<void> renumberPending(DateTime at);

  /// La tarea [id], o null si no existe (completar y eliminar la borran,
  /// ADR-0012).
  Future<Task?> findById(String id);

  /// Guarda la tarea y sus adjuntos (una fila por adjunto, con `position` = su
  /// índice) en una transacción, y en la misma activa `hasEverHadTasks`
  /// (CA-001-05, ADR-0012): si fuera aparte y la app muriera entre medias,
  /// alguien con tareas vería el editor de la primera tarea en lugar de
  /// "Todo hecho.". Si falla algo a mitad, no queda ninguna fila.
  Future<void> insert(Task task);

  /// Cambia el texto y los adjuntos de la tarea [id] sin tocar su posición ni
  /// su color (specs 005, 007 y 016), en una transacción. [attachments]:
  /// `null` = **no tocar las filas** (solo el texto: así editar una tarea con
  /// 11 filas restauradas o con una mezcla rara no borra nada que el usuario
  /// no haya tocado, CA-016-25); lista vacía = quitarlas todas; lista =
  /// reemplazar las actuales por estas, en ese orden. Devuelve false (y no
  /// cambia nada) si no existe o está eliminada.
  Future<bool> updateContent(
    String id,
    String? text,
    DateTime at, {
    List<Attachment>? attachments,
  });

  /// Ids de todos los adjuntos guardados en la BD (todos son de tareas
  /// pendientes), para el barrido de archivos huérfanos (CA-007-16). **Sin
  /// tope**: la lectura de una tarea muestra como mucho 10 fotos, pero los
  /// archivos de las demás filas no se barren (spec 016, CA-016-25).
  Future<Set<String>> attachmentIds();

  /// De los [ids] dados, los que tienen fila en la BD, en una sola consulta
  /// por lote (spec 016, plan §4): el barrido pregunta por sus candidatos sin
  /// cargar [attachmentIds] entero por cada uno.
  Future<Set<String>> existingAttachmentIds(Iterable<String> ids);

  /// Borra de la BD la tarea pendiente [id] y las filas de sus adjuntos, en
  /// una transacción: completar y eliminar (specs 003 y 004, ADR-0012). Los
  /// archivos los borra después `AttachmentJanitor`. Devuelve false (y no
  /// cambia nada) si no existe.
  Future<bool> remove(String id);
}

/// Ajustes simples (docs/architecture.md §3).
abstract interface class SettingsRepository {
  Future<bool> firstRunDone();
  Future<void> setFirstRunDone();

  /// ¿Se ha guardado alguna tarea alguna vez? Sin pendientes, decide entre
  /// "Todo hecho." y el editor de la primera tarea (CA-001-05, CA-003-11,
  /// CA-004-08, ADR-0012). Lo activa `TaskRepository.insert`.
  Future<bool> hasEverHadTasks();

  /// "Pantalla siempre activa" (CA-015-04, CA-015-05): **apagada por
  /// defecto**. Solo es `true` si el valor guardado es exactamente `true`; un
  /// valor ilegible da `false` sin lanzar (CA-015-26).
  Future<bool> keepScreenOn();
  Future<void> setKeepScreenOn(bool value);

  /// Idioma elegido en Ajustes (CA-015-06, ADR-0023). Por defecto, "Como el
  /// sistema"; un valor que no sea exactamente `system|es|en` también lo da
  /// (CA-015-26).
  Future<LocaleChoice> locale();
  Future<void> setLocale(LocaleChoice choice);
}
