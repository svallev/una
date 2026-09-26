# Tareas — Spec 004: Eliminar una tarea

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR puede agrupar varias tareas consecutivas.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-004-01 | Tokens: `crumpleReducedFade` (600 ms), quitar `undoWindow`; regenerar `tokens.g.dart` | — | `node tools/validate-tokens.mjs`, analyze | CA-004-12 |
| T-004-02 | Textos ES/EN de la §7 (`/strings-add`) | — | `gen-l10n`, `/i18n-check` | §7 |
| T-004-03 | Puerto `delete` y `hasHistory` (sustituye a `hasCompleted`) en memoria y drift; `secure_delete` | — | Tests de contrato | CA-004-08, CA-004-09 |
| T-004-04 | Caso de uso `DeleteCurrentTask` | 03 | Unitarios | CA-004-03 |
| T-004-05 | `hasHistoryProvider` y enrutado: "Todo hecho." con eliminadas | 03 | `home_router_test` | CA-004-07, CA-004-08 |
| T-004-06 | `DeletionController` y `deleteTask` (anuncio, error, reintentar); bloqueo en `HomeRouter` | 04, 05 | Tests de flujo sin animación | CA-004-03/05/06/11/13 |
| T-004-07 | `DeleteConfirmSheet` + `MenuAction.delete` + acción accesible | 02, 06 | `delete_confirm_test` | CA-004-01/02/10, CL-004-1/2/4 |
| T-004-08 | Fotogramas clave del arrugado (recorte, transformación, `lift`, facetas, sombreado) | 01 | `crumple_keyframes_test` | CA-004-04 |
| T-004-09 | `CrumpleOverlay` + `TrashCan` + botón que se oculta + tarea de detrás; reducir movimiento | 06, 08 | Tests de flujo con animación | CA-004-04, CA-004-12 |
| T-004-10 | *Goldens* (hoja y arrugado) en Linux con la etiqueta `actualizar-goldens` | 07, 09 | CI | Aspecto |
| T-004-11 | Integración en el emulador y prueba en el Xiaomi (con tu permiso; perfilador a 120 Hz) | 09 | `integration_test`; DevTools | CA-004-04, P2 |
| T-004-12 | Revisiones: `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check`, `/tokens-validate`; desviaciones DEV-25/26 si aplican | 10 | Hallazgos resueltos o registrados | DoD |

## Estado (2026-09-26)

| Tarea | Estado |
|---|---|
| T-004-01 … T-004-09 | ✅ (195 tests en verde; `analyze --fatal-infos` limpio) |
| T-004-10 *Goldens* | Test escrito y revisado en macOS; falta generarlos en Linux (etiqueta `actualizar-goldens` en la PR) |
| T-004-11 Integración | ✅ en el emulador (eliminar + rearrancar, y la 003 sigue verde). Pendiente: rendimiento en el Xiaomi (con permiso del propietario) |
| T-004-12 Revisiones | ✅ `a11y-reviewer` (4 altos y 3 medios corregidos, con tests), `security-reviewer` (sin altos; `secure_delete` por conexión, test sobre archivo, riesgos residuales en `plan.md` §6), `/i18n-check`, `/tokens-validate` |

**CA → test:** CA-004-01/02/10, CL-004-1/4 → `test/features/delete/delete_confirm_test.dart` · CA-004-03/04/05/06/07/11/12/13, CL-004-2 → `deletion_flow_test.dart` · CA-004-08 → `test/app/home_router_test.dart` e `integration_test/delete_flow_test.dart` · CA-004-09 → `test/data/repository_contract_test.dart` · CA-004-03 → `test/domain/delete_current_task_test.dart` · arrugado → `crumple_keyframes_test.dart` y `test/goldens/delete_golden_test.dart` · CL-004-3 → spec 007 (CA-007-12).

**Pruebas a mano pendientes (propietario, en el móvil):** TalkBack (foco en "Cancelar", un único anuncio, foco final), teclado físico, "Quitar animaciones" y aspecto del arrugado frente al prototipo (DEV-25).

## Cierre

- [x] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa: faltan los *goldens* de Linux y la prueba en el móvil.
- [ ] Spec marcada como **Implementada** (tras la prueba del propietario en el móvil).
