# ADR-0021: Eliminar con deshacer: la tarea sale de la BD al instante y sus archivos esperan a que el borrado sea definitivo

- **Estado:** Aceptado (propietario, 2026-10-04, con la spec 014); incluye una excepción a P6 (ver Consecuencias)
- **Fecha:** 2026-10-04
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** constitución P6 (excepción, en Consecuencias); sustituye en parte al ADR-0012 (solo el momento del borrado); spec 014 (y 004, 006, 007); D7 y D20 en `docs/PLAN.md`; ADR-0002 (`rank`); ADR-0004 (copias de seguridad); ADR-0006 y ADR-0011 (antecedentes)

## Contexto

- **[Hecho]** El propietario quiere eliminar **sin confirmación** y con **deshacer durante 4 s** (D20, plan F4b, 2026-10-04). Pasado ese tiempo, la eliminación es definitiva y no queda nada. La hacen definitiva antes otro borrado, completar, crear o editar, abrir Ajustes, ir a otra pantalla (también el listado), reordenar y pasar a segundo plano. Abrir el menú, no (spec 014, CA-014-07 y CA-014-11).
- **[Hecho]** Hoy (ADR-0012), al confirmar la hoja, `DeleteCurrentTask` y `DeletePendingTask` borran la fila y la de su adjunto en una transacción y, justo después, sus archivos (`AttachmentJanitor.discard`). `PRAGMA secure_delete = ON` está activo.
- **[Hecho]** El barrido (`AttachmentJanitor.sweep`) solo corre al arrancar, tras el primer fotograma. Borra los adjuntos que no tienen fila en la BD, salvo las importaciones en curso (`ImportRegistry`).
- **[Hecho]** El orden de la cola es un `rank` fraccional en texto (ADR-0002). Reordenar, crear, editar, eliminar y completar hacen definitiva la eliminación (spec 014, CA-014-11): mientras se puede deshacer, la cola no cambia.
- **[Hecho]** La spec 014 pide que, si la app muere mientras se podía deshacer, la eliminación sea **definitiva** (CA-014-13): al abrir no vuelve la tarea ni aparece la card.
- **[Hecho]** Antecedentes: el ADR-0006 proponía borrado lógico, deshacer de 6 s y purga; el propietario lo vetó (ADR-0011) y después pidió que no quedara nada (ADR-0012). D20 recupera el deshacer, pero no el borrado lógico.

## Opciones consideradas

1. **Borrar la fila al instante y aplazar los archivos.** Como hoy, la fila y la de su adjunto salen de la BD en una transacción antes de la animación. La tarea (con su adjunto) se queda en la **memoria** de la app y sus archivos siguen en el disco, protegidos del barrido, hasta que la eliminación es definitiva; entonces se borran con el mismo `discard`. Deshacer vuelve a insertar la tarea con el mismo id y el mismo `rank`.
2. **Marca de borrado pendiente en la BD.** Una columna nueva `pendingDeleteAt` (esquema v3): la fila se queda oculta para todas las consultas y se purga al caducar, al hacerse definitiva o en el siguiente arranque.
3. **Retrasar la escritura.** La tarea se quita solo de la interfaz y se borra de la BD al terminar los 4 s.

## Decisión

Opción 1: la tarea sale de la BD al instante y solo sus archivos esperan, en el disco, a que la eliminación sea definitiva; si la app muere antes, el barrido del siguiente arranque los borra. Se revisará si el propietario pide deshacer tras reabrir la app o una papelera, o si se añade sincronización (necesitaría marcas de borrado).

## Motivos

Criterios (peso): coherencia con D20 y con "no queda nada" (3), comportamiento si la app muere (3), simplicidad y sin esquema nuevo (2), privacidad (2).

| Opción | Coherencia ×3 | App muere ×3 | Simplicidad ×2 | Privacidad ×2 | Total |
|---|---|---|---|---|---|
| 1. Fila al instante, archivos aplazados | 5 → 15 | 4 → 12 | 4 → 8 | 4 → 8 | **43** |
| 2. Marca `pendingDeleteAt` (v3) | 3 → 9 | 4 → 12 | 2 → 4 | 3 → 6 | **31** |
| 3. Escritura retrasada | 1 → 3 | 2 → 6 | 4 → 8 | 3 → 6 | **23** |

- **Opción 1:** si la app muere, la tarea ya no está en la BD y sus archivos los recoge el barrido que ya existe: definitiva, sin código nuevo para ese camino. Mantiene el borrado antes de la animación (CA-004-03) y no toca el esquema. Lo único que queda unos segundos son los archivos del adjunto (las imágenes no van a la copia en la nube, ADR-0004) y la tarea en la memoria.
- **Opción 2:** una migración, un filtro en todas las consultas y una purga más, para un estado que dura 4 s. El texto se queda en la BD (y en una posible copia de seguridad) hasta la purga, en contra de "no queda nada".
- **Opción 3:** si la app muere durante los 4 s, **la tarea vuelve**, en contra de CA-014-13; además, todo lo que la hace definitiva antes de tiempo tendría que esperar a esa escritura.

## Consecuencias

- **Positivas:**
  - Sin esquema nuevo ni migración; el borrado sigue antes de la animación y en una transacción.
  - El camino "la app muere" ya está cubierto por el barrido (CA-007-16).
  - Completar no cambia (sigue sin deshacer, P-4).
- **Negativas y mitigación:**
  - **Choque de `rank` al deshacer** (el riesgo que ya vio el ADR-0011): no puede ocurrir, porque todo lo que cambia la cola hace antes definitiva la eliminación. Mitigación: un test por cada una de esas acciones, que comprueba que la card desaparece antes del cambio.
  - **Fallo al volver a insertar** (p. ej. sin espacio): la tarea seguiría en memoria. Mitigación: aviso con "Reintentar" mientras sea posible (CA-014-23); después, definitiva.
  - **Barrido concurrente:** hoy no ocurre (solo al arrancar), pero un adjunto que se puede deshacer se registra como protegido, como las importaciones en curso, por si el barrido se lanza en otro momento.
  - **Datos en memoria:** el texto de la tarea sigue en la memoria del proceso unos segundos; ya lo estaba mientras se mostraba. "Recientes" no lo enseña (spec 011) y pasar a segundo plano lo hace definitivo.
  - **`updatedAt` y `createdAt`** de la tarea recuperada: los decide el plan (se recomienda conservarlos).
  - **Excepción a P6 (WCAG 2.2.1), decidida por el propietario el 2026-10-04:** en Android 8 y 9, que no tienen "Tiempo para actuar", la card dura 10 s con un servicio de accesibilidad activo. Con Switch Access no llega a las diez veces del tiempo por defecto (40 s). Mitigación: con TalkBack y con teclado el tiempo se detiene mientras la card tiene el foco, y en Android 10 o posterior manda el ajuste del sistema. Se revisa si la beta lo señala. Al aceptar este ADR, se añade a las excepciones de P6 en la constitución.
- **Cambios en otros documentos** (al aceptarlo):
  - ADR-0012: "Sustituido en parte por ADR-0021 (momento del borrado)"; el resto sigue vigente.
  - `docs/architecture.md` (`DeleteCurrentTask`, `DeletePendingTask`, un caso de uso de deshacer y quién hace definitiva la eliminación), `docs/glossary.md`, `docs/testing.md` y `docs/adr/README.md`.
  - Specs 004, 005, 006, 007, 008, 009 y 001: las enmiendas del §10 de la spec 014.
- **Sin riesgos nuevos para el registro de `docs/PLAN.md`.** El residual de T-7 (archivos que quedan si la app muere hasta el siguiente arranque) no cambia.
