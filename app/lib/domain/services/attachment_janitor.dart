import '../ports/attachment_store.dart';
import '../ports/task_repository.dart';

/// Importaciones en curso (de elegir la imagen a guardar la tarea): el
/// barrido nunca las toca (CA-007-16).
class ImportRegistry {
  final Set<String> _active = {};

  Set<String> get active => {..._active};

  void add(String id) => _active.add(id);

  void remove(String id) => _active.remove(id);
}

/// **Único** servicio que borra archivos de adjuntos (CA-007-16, cierra el
/// pendiente de la spec 006): eliminar desde la pantalla principal o desde el
/// listado, quitar o sustituir al editar, cancelar, errores y el barrido.
///
/// Los borrados no lanzan: si fallan, el barrido del siguiente arranque los
/// recoge. Nunca borra filas de la BD, solo archivos sin fila.
///
/// Eliminar es en dos tiempos (ADR-0021): la fila sale de la BD al momento y
/// los archivos se **retienen** ([hold]) mientras se puede deshacer; cuando la
/// eliminación es definitiva, [discardHeld] los borra (CA-014-15) y, si se
/// deshace, [releaseHeld] los suelta ya con su fila de vuelta. La retención
/// vive solo en memoria: si la app muere, el barrido del siguiente arranque
/// los recoge (CA-014-13).
class AttachmentJanitor {
  AttachmentJanitor({
    required this.store,
    required this.repository,
    required this.registry,
  });

  final AttachmentStore store;
  final TaskRepository repository;
  final ImportRegistry registry;

  /// Adjuntos de una eliminación que aún se puede deshacer: el barrido no los
  /// toca. Aparte de las importaciones ([registry]): que termine una no suelta
  /// la otra.
  final Set<String> _held = {};

  /// Copia de los adjuntos retenidos.
  Set<String> get held => {..._held};

  /// Retiene los archivos del adjunto [id] (antes de quitar su fila). Devuelve
  /// si lo ha añadido: solo suelta quien lo retuvo, así dos eliminaciones a la
  /// vez de la misma tarea no se quitan la protección.
  bool hold(String id) => _held.add(id);

  /// Deja de retener el adjunto [id] sin borrar nada: su fila ha vuelto a la BD
  /// (deshacer) o no se llegó a quitar (fallo al eliminar).
  void releaseHeld(String id) => _held.remove(id);

  /// La eliminación del adjunto retenido [id] es definitiva: deja de retenerlo
  /// y borra sus archivos. No lanza (CA-014-15).
  Future<void> discardHeld(String id) {
    _held.remove(id);
    return discard(id);
  }

  /// Borra los archivos del adjunto guardado [id], que ya no tiene tarea.
  Future<void> discard(String id) async {
    try {
      await store.delete(id);
    } on Object {
      // Sin registro (CL-007-10): lo recoge el barrido.
    }
  }

  /// Borra la preparación [id] y deja de protegerla.
  Future<void> discardStaging(String id) async {
    registry.remove(id);
    try {
      await store.deleteStaging(id);
    } on Object {
      // Ídem.
    }
  }

  /// Devuelve a la preparación el adjunto [id] que no se pudo guardar en la BD,
  /// para reintentar. Si tampoco se puede, se borra.
  Future<void> restage(String id) async {
    try {
      await store.restage(id);
    } on Object {
      await discard(id);
    }
  }

  /// La importación [id] ha terminado (guardada o descartada).
  void release(String id) => registry.remove(id);

  /// Borra los adjuntos que no pertenecen a ninguna tarea y todas las
  /// preparaciones, salvo las importaciones en curso (CA-007-16) y las
  /// eliminaciones que aún se pueden deshacer (ADR-0021). También los de una
  /// tarea completada o eliminada si la app murió antes de `discard` o de
  /// `discardHeld` (CA-014-13), y los que deja la migración a v2 (ADR-0012).
  Future<void> sweep() async {
    final active = registry.active;
    // Primero el disco y después la BD: lo que se guarde entre medias no está
    // en la lista del disco o sigue en `active` hasta estar en la BD.
    final stored = await store.storedIds();
    final staging = await store.stagingIds();
    final known = await repository.attachmentIds();
    // Protegidas: las activas al empezar (que pueden haberse guardado ya y no
    // estar en `known`), las que empiecen durante el barrido y las retenidas.
    bool protected(String id) =>
        active.contains(id) ||
        registry.active.contains(id) ||
        _held.contains(id);
    for (final id in stored) {
      if (known.contains(id) || protected(id)) continue;
      // Justo antes de borrar, otra vez la BD: una tarea eliminada y recuperada
      // mientras el barrido avanza ya no está retenida, pero sí en la BD
      // (deshacer guarda antes de soltar). Por eso, la protección primero y la
      // BD después: al revés, una recuperación entre las dos se perdería.
      if (await _inDatabase(id)) continue;
      await discard(id);
    }
    for (final name in staging) {
      // La cámara escribe `<id>.camera` junto a la preparación `<id>`.
      if (!protected(name.split('.').first)) {
        try {
          await store.deleteStaging(name);
        } on Object {
          // Ídem.
        }
      }
    }
  }

  /// ¿Tiene fila el adjunto [id]? Una consulta por candidato (son pocos). Si
  /// no se puede leer, se deja para otro barrido.
  Future<bool> _inDatabase(String id) async {
    try {
      return (await repository.attachmentIds()).contains(id);
    } on Object {
      return true;
    }
  }
}
