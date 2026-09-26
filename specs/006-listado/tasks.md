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
| T-006-08 | Reordenado propio: arrastre desde el asa (6 px) y desde toda la fila tras 150 ms, desplazamientos, soltar, cancelación, desplazamiento automático, reducir movimiento | 06 | `reorder_gestures_test` | CA-006-04/05/06/07/11/12/19, CL-006-4/7 |
| T-006-09 | Doble toque para editar y editor desde el listado (`fromList`): volver al listado con el foco y el desplazamiento | 06 | `task_list_flow_test` | CA-006-13, CL-006-5/6 |
| T-006-10 | Eliminar desde el listado: `DeletePendingTask`, foco de vuelta, toques ignorados 350 ms en la hoja, última → "Todo hecho." sin volver atrás, error | 04, 06 | `task_list_flow_test` | CA-006-14, CL-006-3/5 |
| T-006-11 | Crear desde el listado: desplazamiento, resaltado (y fijo con reducir movimiento), foco y anuncio | 09 | `task_list_flow_test` | CA-006-15/17/19 |
| T-006-12 | Anuncios y foco de toda la tabla de CA-006-17; `meetsGuideline` con todos los colores | 07–11 | `task_list_a11y_test` | CA-006-17 |
| T-006-13 | Enmiendas: `DEV-18` (ya hecha en la spec), comentario de `menu_sheet.dart`, tests de la 005 que esperaban que "Todas mis tareas" no hiciera nada | 06 | Tests de la 005 en verde | CA-005-11 |
| T-006-14 | *Goldens* (listado es/en ×1 y ×2, fila levantada, resaltado, hoja "Mover") en Linux con la etiqueta `actualizar-goldens` | 08, 11 | CI | Aspecto |
| T-006-15 | Integración en el emulador (flujo) y rendimiento con 500 tareas en el Xiaomi (con tu permiso; perfilador) | 08 | `integration_test`; `docs/perf/baseline.md` | CA-006-20, CL-006-1 |
| T-006-16 | TalkBack, Switch Access y teclado en el emulador (foco inicial, foco tras mover, eliminar y crear) | 12 | Lista de §5 de la revisión de accesibilidad | CA-006-16/17/18 |
| T-006-17 | Revisiones: `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check`, `/tokens-validate`; desviaciones nuevas si aparecen | 14–16 | Hallazgos resueltos o registrados | DoD |

## Estado (2026-09-26)

| Tarea | Estado |
|---|---|
| T-006-01 … T-006-13 | ✅ (281 tests en verde; `analyze --fatal-infos` limpio) |
| T-006-14 *Goldens* | Test escrito y revisado a ojo con una generación local en macOS; las imágenes de referencia se generan en Linux (CI) con la etiqueta `actualizar-goldens` al abrir la PR |
| T-006-15 Integración y rendimiento | ✅ Integración en el emulador (arrastrar, volver, rearrancar). Rendimiento en el Xiaomi (*profile*, 500 tareas): abrir en 40 ms, 0 fotogramas fuera de presupuesto al desplazar y al arrastrar (`docs/perf/baseline.md`). Versión *release* instalada en el móvil del propietario (`install -r`, conserva sus datos) para las pruebas a mano |
| T-006-16 TalkBack real (emulador) | ✅ Foco inicial en el título y ayuda para el lector. ⚠️ No se puede mover el foco de TalkBack con `adb` (TalkBack ignora los toques inyectados): se prueba en su lugar que la fila movida conserva su nodo semántico (test). Switch Access y el foco tras editar, eliminar o crear quedan para la prueba a mano |
| T-006-17 Revisiones | `/i18n-check` ✅, `/tokens-validate` ✅ (4 tokens nuevos), `/security-check` ✅. `security-reviewer` ✅: corregidos los movimientos en serie, el desempate por id y las lecturas capturadas (resto en `plan.md` §7). `a11y-reviewer`: corregidos todos los hallazgos (abajo), con dos comprobaciones pendientes |

**Revisión de accesibilidad: corregido (2026-09-26)**
- **H1 (código):**
  - el aviso de foco sale del nodo de la fila (`GlobalKey` en su `Semantics`) y del de "Nueva tarea" (`BrutalButton.semanticsKey`);
  - se pide cuando la hoja o el editor ya se han cerrado (tests: "el aviso de foco sale del nodo de la fila" y los de foco de CA-006-17).
  - ⚠️ Queda comprobar con TalkBack real dónde queda el foco tras editar, eliminar y crear. En el emulador no se puede provocar con `adb`.
- **M1:** el foco del teclado va al asa (o a "Editar" en la primera fila), con anillo visible e Intro; "Nueva tarea" recibe el foco en su propio botón. Ya no hay `Focus` invisibles.
- **M2:** el orden de lectura se fija en el nodo que la lista crea para cada fila. Con texto grande, la flecha y el título se quedan fijos y solo la ayuda se desplaza (decisión del propietario: CL-006-10 y DEV-34 enmendados). El orden es el de CA-006-18 a cualquier escala (test a 2,0).
- **B1:** la protección de 350 ms solo se aplica al tocar con el dedo el botón Eliminar de la fila; con el lector o el teclado, la hoja responde enseguida (test).
- **B4:** `meetsGuideline` con texto al 200 % y con la hoja "Mover" abierta.

**CA → test:** CA-006-01/02/03, CL-006-9/10/11 → `test/features/task_list/task_list_screen_test.dart` · CA-006-04/05/06/07/11/12/19, CL-006-4/7 → `reorder_gestures_test.dart` · CA-006-08/09/16 → `move_actions_test.dart` · CA-006-10, CL-006-8 → `test/domain/reorder_task_test.dart`, `rank_test.dart`, `test/data/repository_contract_test.dart` · CA-006-13/14/15/19, CL-006-2/3/5/6, §5 → `task_list_flow_test.dart` · CA-006-17/18 → `task_list_a11y_test.dart` · CA-006-14 (datos) → `test/domain/delete_pending_task_test.dart` · controlador → `task_list_controller_test.dart` · CL-002-1 → `test/domain/create_task_test.dart` · CA-006-20, CL-006-1 → `integration_test/task_list_perf_test.dart` · integración → `integration_test/task_list_flow_test.dart` · aspecto → `test/goldens/task_list_golden_test.dart`.

**Pruebas a mano pendientes (propietario, en el Xiaomi):** arrastrar (asa y mantener pulsado 150 ms en cualquier punto de la tarjeta; comprobar que deslizar deprisa sigue desplazando la lista) y el aspecto frente al prototipo; hoja "Mover"; doble toque; eliminar y crear desde el listado; "Quitar animaciones"; TalkBack (foco tras mover, editar, eliminar y crear; acciones de la fila; arrastrar con doble toque mantenido); texto grande.

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.
