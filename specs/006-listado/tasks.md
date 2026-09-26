# Tareas — Spec 006: Todas las tareas (listado)

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR puede agrupar varias tareas consecutivas.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-006-01 | Tokens: `listShift`, `listLift`, `listDropFreeze`, `dragTilt` (el generador emite los valores sueltos de `motion`); regenerar `tokens.g.dart` | — | `node tools/validate-tokens.mjs`, analyze | CA-006-04/12 |
| T-006-02 [P] | Textos ES/EN de la §7 (`/strings-add`) | — | `gen-l10n`, `/i18n-check` | §7 |
| T-006-03 | `Rank.evenlySpaced` y puertos `watchPending`, `pendingTasks`, `reorder`, `renumberPending` (memoria y drift) | — | Tests de contrato | CA-006-10, CL-006-8 |
| T-006-04 | Casos de uso `ReorderTask` (con renumeración) y `DeletePendingTask`; renumeración en `CreateTask` | 03 | Unitarios | CA-006-06/10/14, CL-006-4/8, CL-002-1 |
| T-006-05 | `TaskListController` y proveedores: lista optimista, error y reintentar, destino del foco, resaltado | 04 | Unitarios del controlador | CA-006-10/17, §5 |
| T-006-06 | `TaskListScreen` estática: cabecera, ayuda (con variante para el lector), filas (primera y resto, 3 líneas), "Nueva tarea"; ruta sin transición; menú → listado; volver; texto grande (cabecera desplazable ≥ 1,3) | 02, 05 | `task_list_screen_test` | CA-006-01/02/03, CL-006-2/9/10/11 |
| T-006-07 | Semántica de la fila (un nodo, etiquetas, pista, acciones por posición), orden de lectura, foco inicial; hoja "Mover" (con la fila extraída del menú a `ui/`) | 06 | `move_actions_test`, `task_list_a11y_test` | CA-006-08/09/16/18 |
| T-006-08 | Reordenado propio: arrastre desde el asa (6 px) y con pulsación larga, desplazamientos, soltar, cancelación, desplazamiento automático, reducir movimiento | 06 | `reorder_gestures_test` | CA-006-04/05/06/07/11/12/19, CL-006-4/7 |
| T-006-09 | Doble toque para editar y editor desde el listado (`fromList`): volver al listado con el foco y el desplazamiento | 06 | `task_list_flow_test` | CA-006-13, CL-006-5/6 |
| T-006-10 | Eliminar desde el listado: `DeletePendingTask`, foco de vuelta, toques ignorados 350 ms en la hoja, última → "Todo hecho." sin volver atrás, error | 04, 06 | `task_list_flow_test` | CA-006-14, CL-006-3/5 |
| T-006-11 | Crear desde el listado: desplazamiento, resaltado (y fijo con reducir movimiento), foco y anuncio | 09 | `task_list_flow_test` | CA-006-15/17/19 |
| T-006-12 | Anuncios y foco de toda la tabla de CA-006-17; `meetsGuideline` con todos los colores | 07–11 | `task_list_a11y_test` | CA-006-17 |
| T-006-13 | Enmiendas: `DEV-18` (ya hecha en la spec), comentario de `menu_sheet.dart`, tests de la 005 que esperaban que "Todas mis tareas" no hiciera nada | 06 | Tests de la 005 en verde | CA-005-11 |
| T-006-14 | *Goldens* (listado es/en ×1 y ×2, fila levantada, resaltado, hoja "Mover") en Linux con la etiqueta `actualizar-goldens` | 08, 11 | CI | Aspecto |
| T-006-15 | Integración en el emulador (flujo) y rendimiento con 500 tareas en el Xiaomi (con tu permiso; perfilador) | 08 | `integration_test`; `docs/perf/baseline.md` | CA-006-20, CL-006-1 |
| T-006-16 | TalkBack, Switch Access y teclado en el emulador (foco inicial, foco tras mover, eliminar y crear) | 12 | Lista de §5 de la revisión de accesibilidad | CA-006-16/17/18 |
| T-006-17 | Revisiones: `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check`, `/tokens-validate`; desviaciones nuevas si aparecen | 14–16 | Hallazgos resueltos o registrados | DoD |

## Estado

En curso (plan aprobado el 2026-09-26).

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.
