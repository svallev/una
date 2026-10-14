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
  /// y borra sus archivos. No lanza (CA-014-15). Si la fila existe (una
  /// recuperación que falló al confirmar pero sí llegó a escribirse), no borra.
  Future<void> discardHeld(String id) async {
    _held.remove(id);
    // Protección primero y BD después, como el barrido.
    if (await _inDatabase(id)) return;
    await discard(id);
  }

  /// Lotes de un grupo de fotos (spec 016, plan §4): una tarea tiene hasta 10
  /// adjuntos y todos los caminos (eliminar, completar, deshacer, editar,
  /// cancelar, barrido) pasan por estas operaciones. Ninguna lanza y todas
  /// hacen la protección primero y la BD después, como el barrido.

  /// Retiene los archivos de [ids] (antes de quitar sus filas). Devuelve los
  /// que ha añadido **esta llamada**: solo esos los suelta quien retiene, así
  /// dos eliminaciones a la vez de la misma tarea no se quitan la protección.
  Set<String> holdAll(Iterable<String> ids) => {
    for (final id in ids)
      if (hold(id)) id,
  };

  /// Deja de retener [ids] sin borrar nada: sus filas han vuelto a la BD
  /// (deshacer) o no se llegaron a quitar (fallo al eliminar).
  void releaseHeldAll(Iterable<String> ids) => _held.removeAll(ids);

  /// La eliminación de los adjuntos retenidos [ids] es definitiva: deja de
  /// retenerlos y borra los archivos de los que **no** tienen fila (una sola
  /// consulta por lote; CA-014-15, CA-016-16).
  Future<void> discardHeldAll(Iterable<String> ids) async {
    final all = ids.toList();
    _held.removeAll(all);
    final inDatabase = await _existing(all);
    await discardAll(all.where((id) => !inDatabase.contains(id)));
  }

  /// Borra los archivos de los adjuntos guardados [ids], que ya no tienen
  /// tarea. Un fallo con uno no impide borrar los demás.
  Future<void> discardAll(Iterable<String> ids) async {
    for (final id in ids.toList()) {
      await discard(id);
    }
  }

  /// Devuelve a la preparación los adjuntos [ids] que no se pudieron guardar
  /// en la BD, para reintentar. Los que no se puedan devolver, se borran.
  Future<void> restageAll(Iterable<String> ids) async {
    for (final id in ids.toList()) {
      await restage(id);
    }
  }

  /// Las importaciones [ids] han terminado (guardadas o descartadas).
  void releaseAll(Iterable<String> ids) =>
      ids.toList().forEach(registry.remove);

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

  /// Ids por consulta del barrido (CA-020-19): los mismos que un trozo de
  /// `existingAttachmentIds`. Ninguna consulta del barrido lleva más.
  static const int sweepBatchSize = 500;

  /// Borra los adjuntos que no pertenecen a ninguna tarea y todas las
  /// preparaciones, salvo las importaciones en curso (CA-007-16) y las
  /// eliminaciones que aún se pueden deshacer (ADR-0021). También los de una
  /// tarea completada o eliminada si la app murió antes de `discard` o de
  /// `discardHeld` (CA-014-13), y los que deja la migración a v2 (ADR-0012).
  ///
  /// La BD se consulta por **lotes** de [sweepBatchSize] ids del disco
  /// (`existingAttachmentIds`): nunca se carga la lista de todas las filas, así
  /// que la memoria no crece con ellas (CA-020-19). Si una consulta falla, el
  /// barrido **se corta sin borrar nada más**: «no se pudo leer» nunca es «no
  /// existe». Lo recoge el siguiente arranque.
  Future<void> sweep() async {
    final active = registry.active;
    // Primero el disco y después la BD: lo que se guarde entre medias no está
    // en la lista del disco o sigue en `active` hasta estar en la BD.
    final stored = (await store.storedIds()).toList();
    final staging = await store.stagingIds();
    // Protegidas: las activas al empezar (que pueden haberse guardado ya y no
    // estar en la BD), las que empiecen durante el barrido y las retenidas.
    bool protected(String id) =>
        active.contains(id) ||
        registry.active.contains(id) ||
        _held.contains(id);
    for (var i = 0; i < stored.length; i += sweepBatchSize) {
      final batch = [
        for (final id in stored.skip(i).take(sweepBatchSize))
          if (!protected(id)) id,
      ];
      if (batch.isEmpty) continue;
      final known = await _existingOrNull(batch);
      if (known == null) return;
      for (final id in batch) {
        if (known.contains(id)) continue;
        // Justo antes de borrar, otra vez la protección y la BD: una tarea
        // eliminada y recuperada mientras el barrido avanza ya no está
        // retenida, pero sí en la BD (deshacer guarda antes de soltar). Por
        // eso, la protección primero y la BD después: al revés, una
        // recuperación entre las dos se perdería.
        if (protected(id)) continue;
        final now = await _existingOrNull([id]);
        if (now == null) return;
        if (now.contains(id)) continue;
        await discard(id);
      }
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

  /// [existingAttachmentIds] de un lote del barrido; `null` si no se puede
  /// leer (el barrido se corta).
  Future<Set<String>?> _existingOrNull(List<String> ids) async {
    try {
      return await repository.existingAttachmentIds(ids);
    } on Object {
      return null;
    }
  }

  /// De [ids], los que tienen fila: **una** consulta por lote. Si no se puede
  /// leer, se consideran todos con fila (se dejan para otro barrido).
  Future<Set<String>> _existing(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      return await repository.existingAttachmentIds(ids);
    } on Object {
      return ids.toSet();
    }
  }

  /// ¿Tiene fila el adjunto [id]? Una consulta por id, sin cargar la lista
  /// entera (CA-020-19). Si no se puede leer, se deja para otro barrido.
  Future<bool> _inDatabase(String id) async {
    try {
      return (await repository.existingAttachmentIds([id])).contains(id);
    } on Object {
      return true;
    }
  }
}
