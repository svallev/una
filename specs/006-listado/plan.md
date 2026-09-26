# Plan técnico — Spec 006: Todas las tareas (listado)

- **Spec:** `specs/006-listado/spec.md` (estado: Aprobada, 2026-09-26)
- **ADR aplicables:** ADR-0002 (repositorio, `rank` fraccional y renumeración), ADR-0011 (eliminar sin deshacer)
- **Estado del plan:** Aprobado (propietario, 2026-09-26)
- **Rama:** `feat/006-listado`, sobre `feat/004-eliminar` (PR #9), que a su vez va sobre la PR #8. Cuando se fusionen, se rebasa sobre `main`.

## 1. Resumen del enfoque

- **Dominio:**
  - `ReorderTask(taskId, toIndex)` calcula la nueva clave entre las vecinas de destino (`Rank.between`) y cambia **una sola fila** (CA-006-10). Si la clave pasa de 50 caracteres, primero renumera toda la cola en una transacción (CL-006-8, ADR-0002) y después la calcula.
  - `DeletePendingTask` elimina **cualquier** tarea pendiente (hoy `DeleteCurrentTask` solo acepta la actual). Devuelve la eliminada, la nueva actual y cuántas quedan.
  - `Rank.evenlySpaced(n)` genera *n* claves de la misma longitud, repartidas de forma uniforme, para renumerar.
  - `CreateTask` también renumera si su clave pasa de 50 caracteres. Hoy, 1 000 inserciones "arriba del todo" (CL-002-1) dejan claves de unos 170 caracteres; ADR-0002 lo exigía y no estaba hecho.
- **Datos:** el puerto `TaskRepository` suma:
  - `watchPending()`: lista ordenada que se emite con cada cambio;
  - `pendingTasks()`: lectura única, para abrir el listado sin pantalla de carga;
  - `reorder(id, rank, at)`: cambia `rank` y `updatedAt` solo si la tarea sigue pendiente;
  - `renumberPending(at)`: transacción que asigna claves nuevas en el mismo orden y actualiza `updatedAt`, para una futura sincronización.

  Se implementa en memoria y en drift. **Sin cambios de esquema:** el índice `idx_tasks_current (status, deletedAt, rank)` ya cubre la consulta.
- **Estado:** `TaskListController` (Riverpod) mantiene la lista que se ve: la de la BD más el cambio optimista mientras se guarda un movimiento. También guarda el destino del foco (id de la tarea y un contador), el id resaltado y los errores. Si falla una escritura, vuelve a la lista de la BD y muestra el aviso.
- **Presentación:**
  - `TaskListScreen` es una ruta sin transición (como el prototipo). Se abre con los datos ya leídos (CA-006-20).
    - Arriba, la cabecera y la ayuda: fijas o, con la escala de texto ≥ 1,3, como slivers que se desplazan (DEV-34).
    - Una lista **perezosa** de filas (`SliverList`).
    - "Nueva tarea", fijo abajo.
  - **Lista reordenable propia** (ver §7): reproduce el modelo del prototipo.
    - La fila arrastrada se dibuja por encima de las demás (`OverlayPortal` enlazado a su sitio) con la inclinación y la sombra `listItemDragging`.
    - Las demás se desplazan con `Transform` (0,2 s). El destino se calcula comparando los centros de las filas.
    - Al soltar se coloca sin animación, como el `.still` del prototipo.
    - El desplazamiento automático en los bordes usa `EdgeDraggingAutoScroller`, de la API pública de Flutter.
    - Un arrastre cancelado (`pointercancel` o la app que se oculta) no guarda nada.
  - **Gestos de la fila:**
    - asa: un reconocedor de arrastre que se activa a los 6 px y compite con su toque (el toque abre "Mover");
    - resto de la fila: arrastre tras pulsación larga;
    - doble toque: se cuentan los toques de la misma fila, como el prototipo (350 ms, la misma fila, ignorando los botones);
    - todos los reconocedores quedan fuera de la semántica (`excludeFromSemantics`).
  - **Semántica de la fila:** un solo nodo, que no incluye los botones. Tiene:
    - la etiqueta `a11yRowPosition` o `a11yRowCurrent`;
    - `onTap` = editar, con la pista `listEditHint`;
    - las acciones de CA-006-09 y CA-006-16.

    Orden de lectura con `OrdinalSortKey`: título, ayuda, filas, "Nueva tarea", "Volver". El foco inicial va al título porque es el primer nodo (lo que aprendimos en la 004).
  - **Hoja "Mover":** `showUnaSheet` con las filas del menú (se extrae el widget de fila de `menu_sheet.dart` a `ui/`).
  - **Editor desde el listado:** `TaskEditorScreen` recibe `fromList: true`. Al guardar, cierra la ruta devolviendo la tarea, sin tocar `screenFocusProvider` y sin el anuncio `a11yQueued`. El listado se desplaza hasta ella (a la primera o a la última: nunca hace falta saltar a una posición intermedia), la resalta, le da el foco y hace el anuncio (CA-006-15, CA-006-17).
  - **Eliminar desde el listado:** `confirmAndDeleteTask` recibe a quién devolver el foco. Desde el listado usa `DeletePendingTask` y no hay arrugado. Si no queda ninguna, marca `hasHistory`, cierra el listado (`popUntil`) y "Todo hecho." recibe el foco y el anuncio. La hoja de confirmación ignora los toques (contenido y fondo) durante 350 ms tras abrirse, para que el segundo toque de un doble toque no la cierre ni la active (CL-006-5).
  - **Menú:** `MenuAction.allTasks`. La pantalla principal abre el listado al elegirlo. Al volver del listado, `screenFocusProvider.signal()`.
- **Anuncios:** `SemanticsService.sendAnnouncement`, un único anuncio por acción. Si hay una hoja, se espera a `sheetOut`, como en la 004.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `entities/rank.dart`, `usecases/reorder_task.dart`, `usecases/delete_pending_task.dart`, `usecases/create_task.dart`, `ports/task_repository.dart` | `Rank.evenlySpaced`; casos de uso nuevos; renumeración al crear; puertos nuevos |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart` | `watchPending`, `pendingTasks`, `reorder`, `renumberPending` |
| Estado | `features/task_list/task_list_controller.dart`, `app/providers.dart` | Controlador, proveedores de los casos de uso |
| Presentación | `features/task_list/` (`task_list_screen.dart`, `task_list_row.dart`, `reorderable_rows.dart`, `move_sheet.dart`, `row_gestures.dart`); `menu_sheet.dart`, `current_task_screen.dart`, `task_editor_screen.dart`, `delete_task_action.dart`, `delete_confirm_sheet.dart`; `ui/sheet_row.dart` | Pantalla, filas, reordenado, hoja "Mover", enganches con el menú, el editor y la eliminación |
| Nativo | — | Nada |
| l10n | `app_es.arb`, `app_en.arb` | Claves de la §7 de la spec |
| Tokens | `design/tokens.json` → `tokens.g.dart` | `motion.duration.listShift` (200 ms), `motion.duration.listLift` (150 ms), `motion.duration.listDropFreeze` (60 ms) y `motion.dragTilt` (−1,5°) |

## 3. Modelo de datos y migraciones

**Sin cambios de esquema.** La renumeración es una transacción de datos sobre las tareas pendientes: no toca las completadas ni las eliminadas, que no se ordenan. `updatedAt` cambia en las filas renumeradas.

## 4. Dependencias nuevas

Ninguna. Se descartan `reorderables` y `scrollable_positioned_list`: no hacen falta (ver §7) y añadirían código de terceros (threat-model §5).

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-006-10, CL-006-8 | Unitarios de `ReorderTask` (a la 1, arriba, abajo, misma posición = sin escritura, tarea ya no pendiente) y de la renumeración (1 000 movimientos alternos, claves ≤ 50, orden intacto); `Rank.evenlySpaced` | `test/domain/reorder_task_test.dart`, `rank_test.dart` |
| CL-002-1 (enmienda) | 1 000 inserciones arriba: orden inverso y claves ≤ 50 | `test/domain/create_task_test.dart` |
| CA-006-14 (datos) | Unitario de `DeletePendingTask` (primera, intermedia, última, no pendiente) | `test/domain/delete_pending_task_test.dart` |
| Datos | Contrato del repositorio (memoria y drift): `watchPending` en orden, `reorder` solo cambia una fila, `renumberPending` en una transacción | `test/data/repository_contract_test.dart` |
| CA-006-01/02/03, CL-006-2/9/10/11 | Widget: menú → listado, contenido y aspecto de la primera fila, recorte a 3 líneas, volver con botón y atrás, segundo plano, texto al 200 % | `test/features/task_list/task_list_screen_test.dart` |
| CA-006-04/05/06/07/11/12, CL-006-4/7 | Widget con gestos simulados: arrastre desde el asa a los 6 px, pulsación larga, deslizar desplaza la lista, soltar arriba del todo, la primera no se mueve, cancelación, desplazamiento automático, soltar en el mismo sitio | `test/features/task_list/reorder_gestures_test.dart` |
| CA-006-08/09, CA-006-16 | Widget: tocar el asa abre "Mover" con las opciones según la posición; acciones del lector por fila (primera, segunda, última) y ninguna acción duplicada | `test/features/task_list/move_actions_test.dart` |
| CA-006-13/14/15, CL-006-3/5/6 | Widget de flujo con repositorio en memoria: doble toque (misma fila, filas distintas, sobre botones), editar y volver, eliminar (intermedia, primera, última → "Todo hecho." sin volver atrás), error y reintentar, crear arriba y a la cola con desplazamiento y resaltado | `test/features/task_list/task_list_flow_test.dart` |
| CA-006-17/18 | Widget de semántica: etiquetas, pista, orden de lectura, anuncios y foco de cada fila de la tabla; `meetsGuideline` (tamaño y etiqueta de los objetivos, contraste) con todos los colores | `test/features/task_list/task_list_a11y_test.dart` |
| CA-006-19 | Widget con "reducir movimiento": sin inclinación, sin desplazamientos animados, resaltado fijo | `reorder_gestures_test.dart`, `task_list_flow_test.dart` |
| Aspecto | *Goldens* frente al prototipo: listado es/en ×1 y ×2, fila levantada a mitad de arrastre, resaltado, hoja "Mover" | `test/goldens/task_list_golden_test.dart` |
| CA-006-20 | Integración de rendimiento con 500 tareas (perfil, en el Xiaomi): tiempo hasta ver el listado y p90 de fotograma al desplazar y arrastrar | `integration_test/task_list_perf_test.dart` |
| Integración | Abrir el listado, reordenar arrastrando, volver y reabrir la app | `integration_test/task_list_flow_test.dart` |

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad y privacidad:** no hay superficie nueva (ni red, ni archivos, ni permisos). La eliminación desde el listado reutiliza `delete` con `secure_delete`. Los errores de escritura no se registran (como en 003 y 004).
- **Accesibilidad:** CA-006-16 a CA-006-19. El foco de TalkBack se comprobará **en el emulador y en el Xiaomi**, no solo con tests de eventos de foco (lección de la 004): foco inicial en el título, el foco que sigue a la tarea movida, tras eliminar y tras crear. Switch Access y teclado físico, en el emulador.
- **Rendimiento:** la lista es perezosa y cada fila recorta su texto a 3 líneas. La lista se lee una vez al abrir y después sigue a `watchPending`. El arranque no cambia (P2): el listado solo se lee al abrirlo. Objetivos de CA-006-20, medidos en el Xiaomi en modo *profile* y anotados en `docs/perf/baseline.md`.

## 7. Riesgos y alternativas

- **Lista reordenable propia en vez de la de Flutter.** [Hecho] `SliverReorderableList` (capa `widgets`, Flutter 3.47.5, `reorderable_list.dart:1157`) envuelve cada elemento con sus propias acciones del lector, sin opción para quitarlas: "Mover al principio", "Mover arriba", "Mover abajo" y "Mover al final". Duplicarían las nuestras y dejarían mover la primera fila hacia abajo, lo que contradice CA-006-07/09. `ReorderableListView` (Material) las usa también.
  - **Propuesta:** una implementación pequeña que reproduce el modelo del prototipo (desplazamientos con `Transform`, destino por centros, sin animación al soltar), con la semántica totalmente nuestra.
  - **Coste:** unas 300–400 líneas y sus tests de gestos.
  - **Alternativa si se complica:** copiar `SliverReorderableList` a la app sin `_wrapWithSemantics` (licencia BSD de Flutter; habría que mantener la copia).
- **Filas de altura variable en una lista perezosa.** Para calcular el destino se usan las filas ya construidas y las alturas medidas, que se guardan. Las que no se han construido nunca están fuera de la pantalla y se estiman con la altura media: solo afectan a filas que no se ven.
  - Nunca hace falta saltar a una posición intermedia: tras "Hacer actual" o "Arriba del todo" la tarea está arriba; tras "A la cola", abajo; "Mover arriba/abajo" y soltar la dejan a la vista.
- **Foco de TalkBack dentro de la misma ruta.** Tras mover una fila, el foco se lleva con `FocusOnSignal` (el mismo mecanismo que funcionó en la 004 para el foco final). Si TalkBack no lo siguiera al reordenar, el anuncio de la posición sigue informando. Lo comprobamos en el emulador antes de dar la tarea por hecha.
- **Renumerar cambia muchas filas.** Es raro (hacen falta muchos movimientos en el mismo hueco) y va en una transacción. La excepción a "una sola fila" está en ADR-0002 y en CL-006-8.
- **Revisión de seguridad (2026-09-26):** sin hallazgos altos.
  - **Corregido:**
    - los movimientos se guardan en serie;
    - el id desempata si dos claves coincidieran;
    - `ReorderTask` renumera si las vecinas no dejan hueco;
    - las lecturas de la cola al abrir el listado y tras crear capturan el error sin registrarlo;
    - el test de integración recuerda `--keep-app-running`.
  - **[Pendiente, spec 007]** Hay dos caminos de borrado (`DeleteCurrentTask` y `DeletePendingTask`). Cuando `AttachmentStore` borre archivos, debe hacerse en un único servicio que usen los dos; si no, eliminar desde el listado dejaría archivos en el sandbox.
  - **[Riesgo aceptado]** Si falla una lectura justo **después** de eliminar desde el listado, se ve el aviso de error aunque la tarea ya está eliminada; "Reintentar" no hace nada. No se pierden ni se filtran datos.
- **La rama depende de las PR #8 y #9:** si cambian en la revisión, hay que rebasar.
