# ADR-0002: SQLite (drift) detrás de un repositorio, con migraciones comprobadas y archivos en el sandbox

- **Estado:** Aceptado (la implementación concreta depende de ADR-0001)
- **Fecha:** 2026-09-24
- **Relacionado:** `docs/architecture.md` (esquema completo), ADR-0004, 0005, 0006; riesgo R-06

## Contexto

- **[Hecho]** Hay que guardar tareas, adjuntos (archivos grandes: fotos, PDF de hasta 50 MB, capturas de URL) y ajustes durante años, sin conexión.
- **[Hecho]** La hoja de ruta incluye fechas límite, subtareas, importación desde otras apps y, mucho más adelante, sincronización en la nube. El modelo no debe impedirlo (P10).
- **[Hecho]** El arranque debe leer **solo** la tarea actual lo antes posible (P2).

## Opciones consideradas

1. **drift** (SQLite, SQL tipado, migraciones con capturas del esquema y tests generados)
2. sqflite (SQLite con SQL a mano y migraciones manuales)
3. Isar / Hive / ObjectBox (almacenes NoSQL embebidos)
4. Archivos JSON

## Decisión

- **drift** sobre SQLite (en web: `sqlite3.wasm` + OPFS, solo para pruebas), con `schemaVersion` desde la v1 y **`drift_dev make-migrations`**: captura de cada versión del esquema en `app/drift_schemas/` y tests de migración generados y ejecutados en CI.
- **`TaskRepository`** como interfaz de dominio. La UI y los casos de uso **nunca** tocan drift directamente. Implementaciones: `DriftTaskRepository` y `InMemoryTaskRepository` (para tests).
- **`AttachmentStore`** como interfaz para los archivos: `Application Support/attachments/<uuid>/{original,thumb,snapshot}` (iOS) y `filesDir/attachments/...` (Android). En la BD solo se guardan **rutas relativas** al contenedor (el UUID del contenedor de iOS cambia entre instalaciones y restauraciones).
- Identificadores **UUIDv7** (ordenables, sin colisiones entre dispositivos).
- Orden con ***fractional indexing*** (`rank` TEXT, alfabeto base-62): "arriba del todo" genera una clave anterior a la primera y "a la cola", una posterior a la última. Reordenar actualiza **una sola fila**. Cuando las claves crecen demasiado (> 50 caracteres) se renumeran en una transacción.
- `colorKey` (0–4) se guarda en la tarea.
- **Marcas de borrado:** `deletedAt` en la tarea (ADR-0006). Las consultas de pendientes excluyen las borradas.
- Ajustes en una tabla `settings` (clave → valor JSON tipado), con migraciones igual que el resto.
- *Feature flags* locales en código (`FeatureFlags`), sobrescribibles en builds de desarrollo. No se guardan en la BD de producción.

## Motivos

- SQLite es el formato más duradero y portable (se puede exportar e inspeccionar). drift añade seguridad de tipos, *streams* reactivos y la herramienta de migraciones más completa del ecosistema Flutter.
- Isar tuvo un periodo de mantenimiento incierto y Hive no es relacional (las subtareas y las importaciones lo necesitarán). Los JSON no aguantan escrituras concurrentes ni crecen bien.
- *Fractional indexing* + UUID + `updatedAt` + tombstones es el patrón habitual para sincronizar después con CRDT/LWW sin reescribir el modelo.

## Consecuencias

- Generación de código (`build_runner`) en el flujo de desarrollo: CI verifica que el código generado está al día.
- Cualquier cambio de esquema = nueva `schemaVersion` + captura + test de migración (lo recuerda la checklist de PR).
- Consulta de arranque dedicada (`watchCurrentTask`) con índice `(status, deletedAt, rank)`.
