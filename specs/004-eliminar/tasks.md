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

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.
