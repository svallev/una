# ADR-0006: Eliminar = borrado lógico con "Deshacer" durante 6 s y purga posterior

- **Estado:** Aceptado (D7)
- **Fecha:** 2026-09-24
- **Relacionado:** spec 004, ADR-0002, tokens `motion.duration.undoWindow`

## Contexto

- **[Hecho]** R10: eliminar pide confirmación ("desaparecerá sin marcarse como hecha") y muestra una animación de papel arrugado.
- **[Hecho]** La sincronización futura necesita saber qué se eliminó (tombstones).
- **[Hecho]** Por privacidad, lo eliminado no debe quedarse para siempre en el dispositivo.

## Opciones consideradas

1. Borrado definitivo
2. Papelera recuperable durante N días
3. **Borrado lógico + "Deshacer" temporal + purga**

## Decisión

1. Al confirmar: la tarea recibe `deletedAt = now`, `updatedAt = now` y **desaparece de la cola**. Se reproduce la animación (solo si era la tarea actual) y después aparece el aviso **"Tarea eliminada · Deshacer"** durante **6 s** (se puede cerrar; con lector de pantalla se anuncia y dura hasta que el usuario actúa o pasan 10 s).
2. **Deshacer:** `deletedAt = null`; vuelve a su `rank` original.
3. **Purga** (al vencer la ventana, o al arrancar la app para las pendientes): se borran los archivos del adjunto y se vacía el contenido de la fila (`text = null`, se borra el adjunto), conservando la **tombstone** mínima (`id`, `deletedAt`, `updatedAt`).
4. Las tombstones se conservan (ocupan pocos bytes) hasta que exista sincronización y se defina su política de compactación.

## Motivos

La confirmación más el deshacer cubren los errores sin añadir una pantalla de papelera (que rompería la simplicidad de P1) ni guardar contenido indefinidamente.

## Consecuencias

- Hay que diseñar el aviso de deshacer (no está en el prototipo; DEV-10).
- Estado vacío: si la eliminada era la última, se muestra "Nada pendiente."; si se deshace, se vuelve a la tarea.
- Tests: deshacer dentro de la ventana, purga tras la ventana, purga al arrancar, animación con "reducir movimiento" activado.
