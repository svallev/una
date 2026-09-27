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
class AttachmentJanitor {
  AttachmentJanitor({
    required this.store,
    required this.repository,
    required this.registry,
  });

  final AttachmentStore store;
  final TaskRepository repository;
  final ImportRegistry registry;

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
  /// preparaciones, salvo las importaciones en curso (CA-007-16). También los
  /// de una tarea completada o eliminada si la app murió antes de `discard`,
  /// y los que deja la migración a v2 (ADR-0012).
  Future<void> sweep() async {
    final active = registry.active;
    // Primero el disco y después la BD: lo que se guarde entre medias no está
    // en la lista del disco o sigue en `active` hasta estar en la BD.
    final stored = await store.storedIds();
    final staging = await store.stagingIds();
    final known = await repository.attachmentIds();
    // Protegidas: las activas al empezar (que pueden haberse guardado ya y no
    // estar en `known`) y las que empiecen durante el barrido.
    bool protected(String id) =>
        active.contains(id) || registry.active.contains(id);
    for (final id in stored) {
      if (!known.contains(id) && !protected(id)) await discard(id);
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
}
