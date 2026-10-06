# ADR-0024: Adjuntos de 1 a N con orden: una fila por foto, con su posición, y esquema v3

- **Estado:** Aceptado (propietario, 2026-10-06, con la spec 016)
- **Fecha:** 2026-10-06
- **Decisores:** propietario del producto; Claude Code (propuesta técnica)
- **Relacionado:** spec 016 (CA-016-03, 14 a 16, 18a, 18b, 23), D21, P-8 y P-18 del plan F4b, R-24; **enmienda** al ADR-0002 (modelo 0..1 adjunto) y al ADR-0012 (borrado sin histórico, ahora de todo el grupo); ADR-0011 (ningún archivo huérfano), ADR-0021 (deshacer); `docs/architecture.md` §3

## Contexto

- **[Hecho]** Hoy una tarea tiene 0..1 adjuntos (`Task.attachment`), aunque la tabla `attachments` ya admite varias filas por tarea: su índice por `taskId` **no es único** (`idx_attachments_task`). `schemaVersion = 2`.
- **[Hecho]** La spec 016 admite **un grupo de 2 a 10 imágenes** por tarea, en el orden en que las devuelve Android (D21; S8 descartado), que se reemplaza entero y no se edita de una en una. PDF y web siguen siendo un solo adjunto.
- **[Hecho]** Cada imagen conserva sus copias propias (versión completa en teselas, de pantalla y miniatura, `files/attachments/<id>/`) y el borrado es un solo servicio, `AttachmentJanitor`, que borra el directorio entero del adjunto (ADR-0011).
- **[Hecho]** Antes del primer fotograma solo se pinta la versión de pantalla de la primera foto (CA-001-09); el listado usa la miniatura de la primera.
- **[Suposición]** 10 fotos de 24 MP pueden ocupar 100–300 MB por tarea (R-24); se mide en la implementación.

## Opciones consideradas

1. **N filas en `attachments`, con una columna nueva `position`** (orden dentro de la tarea). Esquema v3, captura, paso de migración y test v2→v3. En el dominio, `Task.attachment` pasa a una lista ordenada.
2. Una sola fila con una lista JSON de carpetas: sin migración, pero el orden, los fallos parciales y el barrido quedan fuera de la BD y se rompe la estructura del dominio.
3. Una carpeta por adjunto con N subcarpetas: sin esquema, pero el orden y los fallos parciales tampoco están en la BD.

## Decisión

Opción 1.

- **Modelo:** una fila de `attachments` por foto, con `position` (0 a N-1, sin huecos); `taskId` + `position` identifica la foto. Cada foto es un adjunto con su propia carpeta de archivos, de modo que el barrido, el borrado y la regeneración de derivados siguen siendo por adjunto (`AttachmentJanitor`).
- **Invariantes (en el dominio):** una tarea tiene **ningún adjunto, uno solo de cualquier tipo, o de 2 a 10 imágenes**; PDF y web nunca van en grupo; el texto sigue sin ser obligatorio si hay adjunto. `Task.attachment` pasa a ser una lista ordenada (`attachments`), con un acceso cómodo a la primera.
- **Migración v2 → v3:** se añade `position` con 0 para todas las filas existentes; ninguna tarea cambia (CA-016-15). Test de migración desde v1 y v2, y captura del esquema (`drift_schema_v3.json`).
- **Guardar es todo o nada:** se mueven las N carpetas preparadas a su sitio (si una falla, se devuelven o se descartan las ya movidas) y se insertan las N filas con su `position` **en una sola transacción**; **reemplazar** borra el grupo anterior solo después de confirmarla. Si al guardar faltan fotos preparadas (la zona temporal la vació el sistema), se tratan como fallidas (aviso y se conservan las que quedan): no se ofrece un "Reintentar" que no puede triunfar.
- **Protección del barrido:** los N identificadores del grupo se registran como importación en curso **desde que se prepara la primera hasta que se guarda o se descarta**, también con el editor esperando abierto, y se retienen en conjunto durante el deshacer; el barrido lee los identificadores una sola vez.
- **Lectura tolerante (BD restaurada, T-7):** se ordena por `(position, id)`, se leen **como mucho 10 filas** por tarea, se toleran posiciones repetidas o con huecos y un tipo desconocido o una mezcla no válida se ve como "Adjunto no disponible"; nada lanza ni carga sin tope. La migración asigna posiciones únicas por tarea (orden `createdAt`, `id`); si se añade un índice único, se normaliza antes **en la misma transacción**. Las consultas de lectura (`currentTask`, `watchCurrentTask`, `pendingTasks`, `watchPending`: hoy un `LEFT JOIN` con `limit(1)`) y `EditTask` (que hoy compara con una sola fila) se reescriben para grupos.
- **Borrar, completar y deshacer** actúan sobre el grupo entero: la `Task` completa con todas sus fotos sigue en memoria durante el deshacer y sus archivos, protegidos del barrido (ADR-0021).
- **Listado:** miniatura de la primera foto; sin contador. **Arranque:** solo la versión de pantalla de la primera foto antes del primer fotograma; las demás, después.
- **Foto que falta:** una foto sin archivo no invalida el grupo (CA-016-18a); si faltan todas, la tarjeta "Adjunto no disponible" (CA-016-18b).
- **Tamaño (R-24):** cada foto conserva hasta 24 MP, como la imagen suelta. Si al medir con 10 fotos de 24 MP el espacio supera 150 MB por tarea, o no se cumplen CA-016-08 o CA-016-23, se puede fijar para los grupos una versión completa menor, **no inferior a 12 MP**, sin reabrir la spec (CA-016-14).

## Motivos

- La BD ya admite varias filas por tarea: no hay que rehacer tablas ni índices, solo añadir el orden.
- El orden y los fallos parciales viven en la BD, con transacciones, no en carpetas ni en JSON.
- El borrado y el barrido por adjunto no cambian, y es lo que ya está probado (ADR-0011).
- Permite el futuro (P10) sin construirlo: otros grupos o reordenar solo tocarían `position`.

## Consecuencias

- **Positivas:** modelo claro; migración sin pérdida; el resto de los servicios casi no cambia.
- **Negativas y riesgos:**
  - **Esquema v3:** migración, captura y tests (P9, R-06): v1→v3 y v2→v3 con una tarea de dos filas, una con PDF y otra con web. Mitigación: solo una columna con valor por defecto.
  - **Disco y memoria** (R-24): hasta 10 fotos por tarea. Mitigación: tope de 10, 3 decodificadas a la vez, versión de pantalla de una sola foto al arrancar, y la regla de tamaño de arriba.
  - **Rebajar** el invariante "una tarea, un adjunto" toca el dominio, los repositorios (`DriftTaskRepository`, `InMemoryTaskRepository`), la entidad `Task` y los servicios de importación y borrado. Mitigación: el contrato común de los repositorios (`repository_contract_test`) se amplía a grupos.
  - La copia de seguridad: sin cambio (las imágenes quedan fuera de la copia en la nube, ADR-0004).
- **Qué hay que hacer al aceptarlo:**
  - `docs/architecture.md` §3 (ER, invariantes, versionado v3, "Imágenes") y `docs/glossary.md` (Adjunto, Grupo de imágenes);
  - `docs/security/threat-model.md` (T-3, T-7, T-2 y el riesgo de denegación de servicio por N) y `docs/security/checklist.md` (CA-016-24), sin cambios en `data_extraction_rules.xml` ni `backup_rules.xml` (las rutas son las mismas);
  - tests: `repository_contract_test` con grupo, orden, `limit(1)` y edición; fallo inyectado al guardar en la foto 1, la 5 y la 10; barrido durante la importación y durante el deshacer con un grupo de 10;
  - ADR-0002 y ADR-0012: nota "ampliado por el ADR-0024 (adjuntos de 1 a N)" y la misma en `docs/adr/README.md`;
  - spec 007 §8 y §9 (ya enmendados en el §10 de la spec 016).
- **Qué dispararía revisarlo:** el tamaño medido (R-24), la necesidad de reordenar o de mezclar tipos en un grupo, o la sincronización (Bloque 4).
