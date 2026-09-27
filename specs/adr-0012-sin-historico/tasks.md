# Tareas: ADR-0012, sin histórico

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR agrupa todas (es un cambio pequeño).

**Requisito previo:** spec 007 fusionada en `main`. Rama `feat/adr-0012-sin-historico` desde `main`.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-0012-01 | **Test de migración primero** (en rojo): BD v1 con pendientes, completadas y marcas, con y sin imagen; v1 vacía; v1 solo con una marca (plan §5) | — | Falla hasta T-0012-02 | Migración |
| T-0012-02 | `schemaVersion = 2`, `from1To2` (plan §3) en una transacción; `make-migrations` (captura v2 y `schema_v2.dart`) | 01 | `migration_test` en verde; validación del esquema v2 | Migración |
| T-0012-03 | Contrato del repositorio (en rojo): `remove` borra la tarea y sus adjuntos y solo si está pendiente; `insert` activa `hasEverHadTasks` en la misma transacción; `remove` no lo desactiva | 02 | Falla hasta T-0012-04 | CA-003-06, CA-004-09, CA-001-05 |
| T-0012-04 | Puertos y repositorios (drift y memoria): `remove`, `hasEverHadTasks`; fuera `complete`, `delete` y `hasHistory`; consultas sin `deletedAt` | 03 | `repository_contract_test` en verde; `flutter analyze` | CA-003-06, CA-004-09 |
| T-0012-05 | Casos de uso: `CompleteCurrentTask` con `janitor` y `remove` + `discard`; `DeleteCurrentTask` y `DeletePendingTask` con `remove`; reescribir sus tests | 04 | Tests de dominio; completar con imagen borra sus archivos | CA-003-06, CA-004-03, CA-007-17 (enm.) |
| T-0012-06 | Estado y arranque: `BootState.hasEverHadTasks`, `hasEverHadTasksProvider`, `mark()` al crear; quitar las marcas al completar y eliminar; `HomeRouter` | 05 | `home_router_test`, `completion_flow_test`, `deletion_flow_test` | CA-001-05, CA-003-11, CA-004-08 |
| T-0012-07 [P] | Barrido: comentarios y tests (sin excepción para completadas; muerte entre `remove` y `discard` → el barrido recoge los archivos); `image_elsewhere_test` (la rotura muestra la imagen aunque ya no esté en disco) | 05 | `attachment_janitor_test`, `image_elsewhere_test`, `missing_attachment_test` | CA-007-16/17 (enm.) |
| T-0012-08 | Integración: `complete_flow_test` y `delete_flow_test` (sin fila tras completar o eliminar; "Todo hecho." al rearrancar); ejecutar en el emulador | 06 | Emulador | CA-003-06, CA-004-08/09 |
| T-0012-09 [P] | Actualizar en el dispositivo desde una build v1 con completadas: al abrir, siguen las pendientes, "Todo hecho." si no hay, sin imágenes huérfanas tras el barrido | 08 | A mano en el emulador (instalar la v1, crear datos, instalar encima la v2) | Migración |
| T-0012-10 | Documentos (plan §8): `architecture.md`, `threat-model.md` T-7, enmiendas marcadas como implementadas | 08 | Revisión | — |
| T-0012-11 | Revisiones: `security-reviewer` (borra datos: migración y borrado), `/security-check` | 10 | Hallazgos resueltos o registrados | DoD |

## Cierre

- [ ] Tests de migración, contrato, dominio, widgets y goldens en verde (los goldens no deberían cambiar).
- [ ] Integración y actualización desde v1 comprobadas en el emulador.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Enmiendas del ADR-0012 en las specs 001, 003, 004 y 007 marcadas como **implementadas**.
