# Plan técnico: ADR-0012, sin histórico

- **Origen:** `docs/adr/0012-sin-historico.md` (Aceptado, 2026-09-26) y sus enmiendas, ya escritas y aceptadas:
  - **001:** CA-001-05.
  - **003:** CA-003-06 y CA-003-11.
  - **004:** CA-004-03, CA-004-08 y CA-004-09.
  - **007:** CA-007-16 y CA-007-17.
  - **Documentos:** `docs/PLAN.md` (D7, D8, R14), `architecture.md` y `glossary.md`.

  No hay spec nueva: este plan implementa esas enmiendas.
- **ADR aplicables:** ADR-0012 (sustituye a ADR-0011), ADR-0002 (repositorio, migraciones), ADR-0004 (copias).
- **Cuándo:** después de fusionar la spec 007 en `main`, en la rama `feat/adr-0012-sin-historico` creada desde `main` (decisión del propietario, 2026-09-26).
- **Estado del plan:** **Aprobado** (propietario, 2026-09-27). Viaja en la PR de la spec 007 solo como documentación; se implementa en su propia rama después.

## 1. Resumen del enfoque

1. **Completar y eliminar borran de verdad.**
   - Un solo método del repositorio, `remove(id)`, borra en una transacción las filas de los adjuntos y la de la tarea, solo si está pendiente.
   - Después, el mismo servicio de siempre (`AttachmentJanitor.discard`) borra sus archivos.
   - Los tres casos de uso (`CompleteCurrentTask`, `DeleteCurrentTask` y `DeletePendingTask`) lo usan.
2. **"¿Ya se guardó alguna tarea?" pasa a ser un ajuste.**
   - Es `hasEverHadTasks` en `settings`: JSON, `false` si no existe.
   - Se activa **en la misma transacción** que guarda una tarea (`insert`). Si fuera aparte y la app muriera entre medias, alguien con tareas vería el editor de la primera tarea en lugar de "Todo hecho.".
   - Sustituye a `hasHistory()`.
3. **La migración v1 → v2 borra una sola vez lo que ya no debe existir.**
   - Borra las completadas, las marcas de borrado y sus adjuntos.
   - Activa `hasEverHadTasks` si había **cualquier** tarea (pendiente, completada o marca). Así quien ya usaba la app sigue viendo "Todo hecho." y no el editor de la primera tarea.
   - Los archivos de los adjuntos borrados los recoge el barrido del siguiente arranque, que ya existe.
4. **El esquema no cambia de forma.**
   - `status`, `completedAt` y `deletedAt` se quedan (ADR-0012: dejar de usarlos no obliga a quitarlos). Quitar columnas en SQLite exige recrear la tabla y no aporta nada ahora.
   - La versión sube a 2 porque la migración de datos debe ejecutarse una sola vez, y así lo exige la regla del proyecto.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `ports/task_repository.dart` | `complete(id, at)` y `delete(id, at)` se sustituyen por `remove(String id) → Future<bool>` (false si no existía o no estaba pendiente). Se quitan `hasHistory()` y la mención a completadas y eliminadas en `findById` y `attachmentIds`. `SettingsRepository` gana `hasEverHadTasks()`. `insert` documenta que activa el ajuste en su transacción |
| Dominio | `usecases/complete_current_task.dart` | Recibe `janitor`; tras `remove`, `janitor.discard(adjunto)`. `CompletionResult.completed` sigue siendo la tarea tal como se veía (la animación la necesita) |
| Dominio | `usecases/delete_current_task.dart`, `delete_pending_task.dart` | `delete` → `remove`; lo demás igual (ya descartan los archivos) |
| Dominio | `entities/task.dart` | Sin cambios de forma. `complete()` y `deletedAt` dejan de usarse para guardar; se revisa si siguen haciendo falta (se quitan si no los usa nada) |
| Dominio | `services/attachment_janitor.dart` | Solo comentarios: el barrido ya no "respeta completadas" (no hay); `attachmentIds` son las de las pendientes |
| Datos | `db/app_database.dart` | `schemaVersion = 2`; `onUpgrade` con `stepByStep` (from1To2), en una transacción **explícita** (drift no la abre; §3) |
| Datos | `drift_task_repository.dart` | `remove` (transacción: `DELETE attachments WHERE taskId`, `DELETE tasks WHERE id AND pending`); `insert` escribe también `hasEverHadTasks = true`; `hasEverHadTasks()` lee el ajuste; se quita `hasHistory`, `complete` y `delete`. Las consultas dejan de filtrar por `deletedAt` (siguen filtrando por `status = pending`, que vale igual y usa el índice) |
| Datos | `in_memory_task_repository.dart` | Lo mismo en memoria (web de pruebas y tests) |
| Estado | `app/providers.dart`, `main.dart` | `BootState.hasHistory` → `hasEverHadTasks` (leído del ajuste); `hasHistoryProvider` → `hasEverHadTasksProvider`; `mark()` se llama al **crear** (y ya no al completar o eliminar, aunque no estorba) |
| Estado | `completion_controller.dart`, `deletion_controller.dart`, `task_list_screen.dart` | Quitar `hasHistoryProvider.mark()` (ya es true desde que se creó la tarea) |
| Presentación | `una_app.dart` (`HomeRouter`) | `hasHistory` → `hasEverHadTasks`; la lógica ("Todo hecho." / editor de la primera tarea) no cambia |
| Presentación | Caras de completar y eliminar | Sin cambios: ya usan la imagen decodificada y no comprueban los archivos (plan de la 007 §8). Ahora completar también borra los archivos antes de la rotura, igual que eliminar |
| l10n | — | Sin textos nuevos |
| Nativo | — | Sin cambios |

## 3. Modelo de datos y migraciones

**`schemaVersion` 2.** Solo datos; mismas tablas, columnas e índices. Captura `drift_schemas/app/drift_schema_v2.json` y test generado con `dart run drift_dev make-migrations`.

```sql
-- from1To2, dentro de una transacción explícita (drift no la abre); PRAGMA secure_delete = ON (ya activo)
INSERT OR REPLACE INTO settings (key, value, updated_at)
  SELECT 'hasEverHadTasks', 'true', <ahora>
  WHERE EXISTS (SELECT 1 FROM tasks);
DELETE FROM attachments
  WHERE task_id IN (SELECT id FROM tasks
                    WHERE status <> 'pending' OR deleted_at IS NOT NULL);
DELETE FROM tasks WHERE status <> 'pending' OR deleted_at IS NOT NULL;
```

- **Orden:** primero el ajuste (necesita ver las filas), después los adjuntos (clave foránea) y por último las tareas.
- **Archivos:** no se tocan en la migración, que no conoce el almacén. Los de los adjuntos borrados quedan huérfanos y los borra el barrido 2 s después del primer fotograma (CA-007-16). **[Suposición]** Hoy nadie tiene completadas con imagen salvo el propietario en pruebas; aun así se cubre.
- **`parentId`:** en la v1 siempre es nulo (Bloque 2); no hay subtareas que queden colgando.
- **Copias de seguridad (ADR-0004):** restaurar una copia v1 hecha antes de actualizar trae completadas y marcas, pero la migración se ejecuta al abrirla y las borra. Una copia v2 ya no las tiene.
- **Si la migración falla:** la transacción (abierta a mano en `onUpgrade`: drift no la abre) se deshace, `user_version` sigue en 1 y la migración se repite en el siguiente arranque y la app muestra la pantalla de error de almacenamiento (spec 001, "Reintentar"), como cualquier fallo al abrir la BD. No se pierde nada.

## 4. Dependencias nuevas

Ninguna.

## 5. Estrategia de tests

| Criterio | Tipo de test | Archivo |
|---|---|---|
| Migración v1 → v2 | **Test de migración** con una BD v1 real: 2 pendientes (una con imagen), 2 completadas (una con imagen), 1 marca de borrado → quedan solo las 2 pendientes y su adjunto; `hasEverHadTasks = true`. Además: v1 vacía (con `firstRunDone`) → sin tareas y `hasEverHadTasks` sin activar; v1 solo con una marca → sin tareas y `hasEverHadTasks = true`. Validación del esquema v2 | `test/drift/app/migration_test.dart` |
| CA-003-06 (enmendado) | Contrato del repositorio (memoria y drift): `remove` de una pendiente → `findById` null y sin filas de adjuntos; `remove` de una inexistente → false | `test/data/repository_contract_test.dart` |
| CA-004-09 (enmendado) | Ídem para eliminar; ya no existe `deletedAt` en ninguna fila | ídem |
| CA-001-05, CA-003-11, CA-004-08 | Contrato: `insert` activa `hasEverHadTasks`; `remove` no lo desactiva. `HomeRouter`: sin pendientes y con el ajuste → "Todo hecho."; sin el ajuste → editor | `repository_contract_test.dart`, `test/app/home_router_test.dart` |
| CA-007-16/17 (enmendado) | Completar una tarea con imagen borra sus archivos; la rotura sigue mostrando la imagen (sin "Adjunto no disponible"); el barrido ya no tiene excepción para completadas | `test/domain/complete_current_task_test.dart`, `test/features/attachments/image_elsewhere_test.dart`, `test/domain/attachment_janitor_test.dart` |
| CL-003-1 / CA-004-03 | Si la app muere tras guardar y antes de borrar los archivos: la tarea ya no está y el barrido recoge los archivos | `attachment_janitor_test.dart` |
| Integración | `complete_flow_test` y `delete_flow_test`: tras completar o eliminar, `findById` → null y, al rearrancar, "Todo hecho." | `integration_test/` |

Tests que cambian porque comprobaban el histórico (se reescriben, no se borran): `complete_current_task_test`, `delete_current_task_test`, `delete_pending_task_test`, `reorder_task_test`, `repository_contract_test`, `home_router_test`, `completion_flow_test`, `deletion_flow_test`, `attachment_janitor_test`, `image_elsewhere_test` (CA-007-17 → se borran), `missing_attachment_test` (barrido), `keep_screen_on_test`, y los de integración `complete_flow_test`/`delete_flow_test`.

## 6. Seguridad, accesibilidad y rendimiento

- **Privacidad (T-7, P-privacidad):** lo completado ya no queda en el dispositivo ni en las copias. `secure_delete` ya está activo, así que lo borrado no queda en el archivo de la BD. El residual de T-7 ("una copia anterior a una eliminación conserva la tarea") queda igual para copias hechas **antes** de eliminar, pero al restaurarlas la tarea vuelve como pendiente, no como histórico. Se actualiza el texto de T-7.
- **Accesibilidad:** sin cambios (mismas pantallas, anuncios y foco).
- **Rendimiento:** borrar una fila es tan barato como marcarla. La migración recorre una vez tablas pequeñas y no afecta al arranque de quien ya está en v2.

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| Completar por error ya no se puede recuperar ni siquiera "en teoría" | Ya era así en la interfaz (sin deshacer, P-4 de la 003). La mitigación sigue siendo mantener pulsado 1,2 s |
| La migración borra datos | Test de migración con datos reales; transacción explícita, con un test que la hace fallar a mitad; `hasEverHadTasks` antes de borrar; la migración es idempotente |
| La cara de la rotura necesita la imagen, que ya se ha borrado del disco | Igual que en eliminar (007): la cara usa la imagen ya decodificada y no comprueba los archivos. Test: sin "Adjunto no disponible" durante la rotura |
| Si la app muere entre `remove` y `discard` | El barrido del siguiente arranque borra los archivos huérfanos (ya probado) |
| Sincronización futura sin marcas | Fuera de la hoja de ruta; ADR-0012 se revisaría |

## 8. Documentos que se actualizan al implementar

- `docs/architecture.md` §3:
  - quitar el invariante "`completedAt` ⇔ `completed`";
  - la tabla de casos de uso ya lo dice (enmienda);
  - añadir `hasEverHadTasks` a los ajustes;
  - pasar de `schemaVersion = 1` a 2.
- `docs/security/threat-model.md` T-7: el residual, como en §6.
- Specs: marcar las enmiendas del ADR-0012 como **implementadas** (con el commit).
- `specs/007-adjunto-imagen/tasks.md`: nota de que CA-007-17 queda sustituido.
- `docs/testing.md`: nada.

## 9. Cambios durante la implementación (2026-09-27)

- **Consultas de pendientes:** se mantiene el filtro `deletedAt IS NULL` (el plan decía quitarlo). No cambia el resultado, porque tras la migración no queda ninguna marca, y así el índice `(status, deletedAt, rank)` sigue dando el orden sin ordenar en memoria.
- **Fallo encontrado y corregido: `hasEverHadTasks` en el arranque.** `main.dart` solo leía el ajuste si no había tarea actual, como hacía con `hasHistory`. Con tareas pendientes al abrir, quedaba en falso y, al completar la última, se habría visto el editor de la primera tarea en lugar de "Todo hecho." (antes lo tapaba `mark()` al completar). Ahora `readBootState` (en `providers.dart`) lo calcula igual para `main.dart` y para los arneses de test: con una tarea actual, `true`; si no, el ajuste. Lo cubre CA-003-05 en `completion_flow_test`, que fallaba con el cálculo antiguo.
- **La rotura de una tarea con imagen:** completar ya borra sus archivos, y en la pausa antes de romperse la tarea se ve en la pantalla normal. Si su comprobación de archivos se volvía a lanzar, aparecía "Adjunto no disponible". La tarea que se está completando no comprueba sus archivos (`CurrentTaskScreen`, `completionProvider`), igual que la cara de la rotura. Lo cubre `image_elsewhere_test`.
- **Limpieza:** `Task.complete()` y `Task.tombstone()` se quitan (nada los usa); los tres casos de uso ya no reciben el reloj.
- **T-0012-09, en el emulador:**
  - con una build de `main` (v1) se crearon 2 pendientes (una con foto) y se completó una con foto, que en v1 conservaba su imagen;
  - al instalar encima la v2, siguen las 2 pendientes, la completada desaparece y el barrido borra su imagen;
  - al completar las dos se ve "Todo hecho.", también tras volver a abrir, y completar una tarea con foto borra sus archivos.
- **Revisión de `security-reviewer` (T-0012-11):**
  - **H-1, corregido:** drift **no** abre una transacción para las migraciones (`_runMigrations` en `engines.dart` de drift 2.35.0). Las tres sentencias se confirmaban por separado; no se perdían pendientes (la migración es idempotente), pero la garantía de "si falla, no cambia nada" era falsa. Ahora `onUpgrade` abre la transacción. El test "si falla a mitad…" de `migration_test.dart` pone un disparador que hace fallar el último paso: falla sin la transacción y pasa con ella (nada borrado, `user_version` = 1, y se completa al reintentar).
  - **H-2 y H-3, registrados** en T-7 (`threat-model.md`): el borrado es lógico en el diario desvinculado y en la memoria flash; las imágenes huérfanas viven hasta el barrido y sí entran en la transferencia entre móviles.
  - **H-4, corregido:** el activo A-1 ya no dice "histórico" (modelo de amenazas v1.1).
  - **[Pendiente] H-5:** un test que abra un archivo v1 real con `openAppDatabaseFile` y compruebe que lo que borra la migración no queda en los bytes del archivo (hoy lo garantiza `secure_delete` activo antes de migrar, sin test propio).
  - **[Pendiente, Bloque 2] H-6:** `remove` no tiene en cuenta `parentId`; con subtareas y `foreign_keys = ON`, borrar una tarea madre fallaría. Se anota para el plan del Bloque 2.
