# ADR-0011: Eliminar es definitivo (sin deshacer), con marca de borrado sin contenido

- **Estado:** Aceptado (propietario, 2026-09-26)
- **Fecha:** 2026-09-26
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** sustituye a ADR-0006; spec 004; ADR-0002; D7 en `docs/PLAN.md`; DEV-09, DEV-10

## Contexto

- **[Hecho]** El propietario no quiere deshacer tras eliminar ni la pantalla "Nada pendiente." (2026-09-26). Al eliminar la última tarea pendiente, la app queda igual que al completar la última: "Todo hecho.". También descartó deshacer al completar (P-4, spec 003).
- **[Hecho]** R10: eliminar pide confirmación ("desaparecerá sin marcarse como hecha") y muestra el papel arrugado. La confirmación es la única red de seguridad.
- **[Hecho]** El esquema v1 ya tiene `deletedAt` (nulo), `text` nulo y la tabla `Attachments` con filas borrables. Todas las consultas del repositorio excluyen las filas con `deletedAt`.
- **[Hecho]** La sincronización futura necesitará saber qué se eliminó (marcas de borrado).
- **[Hecho]** Por privacidad (P4), lo eliminado no debe quedarse en el dispositivo.
- **[Suposición]** SQLite puede dejar restos del texto borrado en páginas libres o en el WAL hasta que se reutilizan. `PRAGMA secure_delete` lo evita a cambio de algo más de escritura. Se decide en el plan de la 004.

## Opciones consideradas

1. **Borrado físico inmediato:** se borran la fila, sus adjuntos y sus archivos.
2. **Marca de borrado sin contenido:** en una transacción, `deletedAt = now`, `updatedAt = now`, `text = null` y se borran las filas de adjuntos. Los archivos se borran justo después.
3. **Mantener ADR-0006:** borrado lógico, "Deshacer" durante 6 s y purga posterior. Vetada por el propietario.

## Decisión

Opción 2. Al confirmar la eliminación, la tarea pasa a ser una marca de borrado sin contenido del usuario, antes de que empiece la animación. Los archivos de sus adjuntos se borran después de la transacción, y los huérfanos que queden (por ejemplo, si la app se mata) se barren al arrancar, después del primer fotograma. No hay ventana de deshacer ni aviso.

Se revisará si se añade sincronización (política de compactación de las marcas) o si el propietario pide recuperar lo eliminado.

## Motivos

Criterios (peso): privacidad (3), sincronización futura (2), simplicidad (2), saber que el usuario ya tuvo tareas para mostrar "Todo hecho." (1).

| Opción | Privacidad ×3 | Sincronización ×2 | Simplicidad ×2 | "Todo hecho." ×1 | Total |
|---|---|---|---|---|---|
| 1. Borrado físico | 5 → 15 | 1 → 2 | 5 → 10 | 2 → 2 | **29** |
| 2. Marca sin contenido | 4 → 12 | 5 → 10 | 4 → 8 | 5 → 5 | **35** |
| 3. ADR-0006 (deshacer) | 3 → 9 | 5 → 10 | 2 → 4 | 5 → 5 | **28** (vetada) |

La opción 2 quita el contenido al instante, como la 1, y conserva la marca que necesitará la sincronización. Además, la marca permite distinguir "nunca ha habido tareas" (editor de la primera tarea) de "ya no queda ninguna pendiente" ("Todo hecho.") sin guardar ningún ajuste nuevo.

## Consecuencias

- **Positivas:**
  - Desaparecen el aviso de deshacer (sin diseñar, R-17), el temporizador, la purga diferida y el token `motion.duration.undoWindow`.
  - Se evita el conflicto de posiciones al deshacer (dos tareas con el mismo `rank`).
  - Un solo estado vacío: "Todo hecho.".
- **Negativas y mitigación:**
  - Un error no se puede recuperar. Mitigación: la hoja de confirmación con el foco inicial en "Cancelar" y el texto de la tarea.
  - Pueden quedar restos del texto en páginas libres de SQLite. Mitigación: decidir `secure_delete` en el plan de la 004.
- **Cambios en otros documentos:**
  - "Todo hecho." se muestra siempre que no hay tareas pendientes y existe al menos una tarea completada o eliminada. Enmienda CA-001-05 y CA-003-11.
  - Se retiran DEV-09 y DEV-10. Hay una desviación nueva: el prototipo muestra "Nada pendiente." tras eliminar la última, y la app muestra "Todo hecho.".
  - Se actualizan D7, `architecture.md` (sin `UndoDelete` ni `undoController`), el glosario, `screen-map.md`, `testing.md` y los tokens.
- **Pendiente:** política de compactación de las marcas cuando exista sincronización.
