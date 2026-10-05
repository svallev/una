# ADR-0012: Sin histórico: completar y eliminar borran la tarea del todo

- **Estado:** Aceptado (propietario, 2026-09-26). Sustituido en parte por ADR-0021 (2026-10-04): solo el momento del borrado (deshacer de 4 s); lo demás sigue vigente
- **Fecha:** 2026-09-26
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** sustituye a ADR-0011 (la marca de borrado) y a las decisiones D7 (en parte) y D8, y a la regla R14; specs 001, 003, 004 y 007; ADR-0002; ADR-0004

## Contexto

- **[Hecho]** El propietario cambia el propósito de lo hecho (2026-09-26): «No vamos a guardar histórico de las tareas completas. Se borra del todo una vez completada. El objetivo de la aplicación es centrarnos en lo que está pendiente y olvidarnos de lo hecho».
- **[Hecho]** Hasta ahora:
  - R14 y D8: las completadas se guardan con su texto, su adjunto y su fecha, aunque la v1 no las muestre (CA-003-06, CA-007-17). La hoja de ruta preveía un "histórico visible y borrable" en una versión posterior.
  - ADR-0011: eliminar deja una **marca de borrado sin contenido** (`deletedAt`, sin texto ni adjunto), pensada para una sincronización futura. No hay sincronización en la hoja de ruta de la v1.
  - Las completadas y las marcas sirven también para decidir, sin tareas pendientes, entre "Todo hecho." (ya hubo tareas) y el editor de la primera tarea (nunca hubo ninguna) (CA-001-05, CA-003-11, CA-004-08).
- **[Hecho]** El propietario ha decidido (2026-09-26):
  1. eliminar también borra la tarea del todo, sin marca;
  2. sin pendientes, "Todo hecho." si alguna vez hubo tareas, con un ajuste que solo dice eso (sí/no);
  3. las completadas y las marcas que ya existan se borran al actualizar la app;
  4. se documenta ahora y se implementa después de cerrar la spec 007, en su propia rama.
- **[Hecho]** `PRAGMA secure_delete = ON` ya está activo en cada conexión (plan de la 004): lo borrado no queda en el archivo de la BD.
- **[Hecho]** El esquema v1 tiene `status`, `completedAt` y `deletedAt`. Dejar de usarlos no obliga a quitarlos.

## Opciones consideradas

1. **Borrado físico al completar y al eliminar**, con un ajuste `hasEverHadTasks` para "Todo hecho.".
2. **Borrado físico al completar; eliminar deja la marca** (ADR-0011).
3. **Marca sin contenido también al completar** (`status = completed`, sin texto ni adjunto).

## Decisión

Opción 1. Al completar o al eliminar, la tarea se borra de la BD en una transacción (fila y filas de adjuntos) y, justo después, sus archivos, con el mismo servicio de borrado (`AttachmentJanitor`). Un ajuste `hasEverHadTasks` (en `settings`) se activa al guardar la primera tarea y decide entre "Todo hecho." y el editor de la primera tarea. Una migración borra, una sola vez, las completadas y las marcas que ya existan; sus archivos los recoge el barrido.

Se revisará si se añade sincronización entre dispositivos (necesitaría marcas de borrado) o si el propietario pide ver lo hecho.

## Motivos

Criterios (peso): coherencia con el propósito, "olvidarnos de lo hecho" (3), privacidad y espacio (3), simplicidad (2), sincronización futura (1).

| Opción | Propósito ×3 | Privacidad ×3 | Simplicidad ×2 | Sincronización ×1 | Total |
|---|---|---|---|---|---|
| 1. Todo físico + ajuste | 5 → 15 | 5 → 15 | 5 → 10 | 1 → 1 | **41** |
| 2. Completar físico, eliminar con marca | 4 → 12 | 4 → 12 | 3 → 6 | 3 → 3 | **33** |
| 3. Marcas en los dos | 3 → 9 | 4 → 12 | 3 → 6 | 5 → 5 | **32** |

La opción 1 no deja nada de lo hecho ni de lo eliminado, trata igual los dos caminos y solo necesita un ajuste de sí/no para "Todo hecho.". La sincronización no está prevista: si llegara, se decidiría entonces cómo propagar los borrados.

## Consecuencias

- **Positivas:**
  - Nada de lo hecho se queda en el dispositivo, ni en las copias de seguridad: menos datos personales y menos espacio (sobre todo con imágenes).
  - Completar y eliminar comparten el borrado: un solo camino que probar.
  - Desaparecen el histórico (R14), su futura pantalla y el pendiente "Borrar archivos de tareas completadas" de la spec 010.
- **Negativas y mitigación:**
  - Una tarea completada por error no se puede recuperar. Ya era así (sin deshacer, P-4 de la spec 003): la mitigación sigue siendo mantener pulsado 1,2 s.
  - Una sincronización futura no sabría qué se borró. Mitigación: no hay sincronización prevista; se revisaría este ADR.
  - La migración borra datos. Mitigación: test de migración con una BD v1 que tenga completadas, marcas y pendientes (solo quedan las pendientes).
- **Cambios en otros documentos** (enmiendas aceptadas con este ADR, 2026-09-26):
  - `docs/PLAN.md`: D7 y D8, R14 en la trazabilidad y la hoja de ruta (sin "histórico visible y borrable").
  - Specs: CA-001-05, CA-003-06 y CA-003-11 (003), CA-004-03 y CA-004-08 (004), CA-007-16 y CA-007-17 (007).
  - `docs/architecture.md` (`CompleteTask`, `DeleteTask`, índices), `docs/glossary.md` ("Histórico", "Completar").
  - ADR-0011 pasa a "Sustituido por ADR-0012".
- **Implementación** (rama propia tras la 007): `schemaVersion` 2 con la migración y su captura; `CompleteCurrentTask` y los dos casos de uso de eliminar borran físicamente; `hasHistory` pasa a leerse del ajuste; el barrido ya no respeta completadas.
