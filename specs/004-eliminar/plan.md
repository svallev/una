# Plan técnico — Spec 004: Eliminar una tarea

- **Spec:** `specs/004-eliminar/spec.md` (estado: Aprobada, 2026-09-26)
- **ADR aplicables:** ADR-0011 (eliminar sin deshacer), ADR-0002 (repositorio, esquema v1)
- **Estado del plan:** Implementado (2026-09-26) · Aprobado (propietario, 2026-09-26): primero sin textura de ruido; detrás de la última, la pantalla "Todo hecho." completa
- **Rama:** `feat/004-eliminar`, sobre `feat/002-005-crear-menu-editar` (PR #8), porque el menú de la 005 es el punto de entrada. Cuando se fusione la PR #8, se rebasa sobre `main`.

## 1. Resumen del enfoque

La eliminación sigue el patrón de completar (spec 003): **se guarda primero y después se anima**.

- **Dominio:** `DeleteCurrentTask` (similar a `CompleteCurrentTask`) comprueba que la tarea sigue siendo la actual, llama a `TaskRepository.delete(id, at)` y devuelve la siguiente (o null).
- **Datos:** `delete` hace una transacción que pone `deletedAt = updatedAt = now` y `body = null` y borra las filas de `Attachments`. Solo afecta a tareas no eliminadas y devuelve false si no había nada que eliminar. Se activa `PRAGMA secure_delete = ON` al abrir la BD para que el texto borrado no quede en páginas libres (ADR-0011).
- **"Todo hecho." también tras eliminar:** `hasCompleted()` pasa a ser `hasHistory()`: "hay alguna tarea completada o eliminada". `hasCompletedProvider` pasa a ser `hasHistoryProvider`. Enmiendas CA-001-05, CA-003-11 y CA-004-08.
- **Estado:** `DeletionController` con fases `idle → deleting → crumpling`, con `busy` igual que `CompletionController`. `HomeRouter` bloquea toques, foco, lector y gesto atrás si cualquiera de los dos está ocupado (CA-004-05).
- **Presentación:**
  - `DeleteConfirmSheet` sobre `showUnaSheet`: título, cuerpo en Space Mono con “{label}” recortado a 3 líneas, "Eliminar" con `BrutalButton` `danger` y "Cancelar" con `ghost`. El foco inicial va a "Cancelar"; Esc cierra.
  - El menú devuelve `MenuAction.delete` y `CurrentTaskScreen` abre la confirmación. La acción accesible "Eliminar tarea" se añade junto a "Completar tarea".
  - `CrumpleOverlay` reproduce el `@keyframes crumple` del prototipo:
    - el polígono de recorte de 12 puntos y la transformación (traslación, giro y escala) se interpolan entre los fotogramas clave con sus curvas;
    - la malla de facetas (6×11, misma semilla que el prototipo) aparece con `facetsIn`, y el sombreado de bola (dos degradados radiales) con `shadeIn`;
    - la sombra dura de la nota sigue a `lift`;
    - la papelera se dibuja con `CustomPainter` (tapa y cubo: `trashIn`, `lid`, `thud`, 64×76, trazo 3,2);
    - el botón de completar se oculta con el `.cta.hide` del prototipo; el logotipo y el menú se quedan;
    - debajo se ve la siguiente tarea sin sus controles, o "Todo hecho.".
  - Con "reducir movimiento", fundido de 600 ms sin papelera (CA-004-12).
- **Anuncio y foco:** un único anuncio (`a11yDeletedNext` / `a11yDeletedAllDone`) y `screenFocusProvider.signal()` al terminar, como en la 003.
- **Error:** SnackBar `deleteError` (o falta de espacio) con "Reintentar", igual que `completeTask`.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `domain/usecases/delete_current_task.dart`, `ports/task_repository.dart` | Caso de uso nuevo; puertos `delete` y `hasHistory` (sustituye a `hasCompleted`) |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart`, `db/app_database.dart` | `delete` transaccional; `hasHistory`; `PRAGMA secure_delete = ON` en `beforeOpen` |
| Estado | `features/delete/deletion_controller.dart`, `app/providers.dart` | Controlador y proveedores; `hasHistoryProvider` |
| Presentación | `features/delete/delete_confirm_sheet.dart`, `crumple_overlay.dart`, `crumple_keyframes.dart`, `trash_can.dart`, `delete_task_action.dart`; `menu_sheet.dart`, `current_task_screen.dart`, `una_app.dart` | Confirmación, animación, papelera, acción accesible, enrutado |
| Nativo | — | Nada |
| l10n | `app_es.arb`, `app_en.arb` | Claves de la §7 de la spec; se amplía la descripción de `editorCancel` |
| Tokens | `design/tokens.json` → `tokens.g.dart` | Se añade `motion.duration.crumpleReducedFade` (600 ms); se quita `undoWindow` |

## 3. Modelo de datos y migraciones

**Sin cambios de esquema** (v1 ya tiene `deletedAt`, `body` nulo y `Attachments`). `secure_delete` es un PRAGMA de conexión, no de esquema. Los archivos de adjuntos no existen hasta la 007: el borrado de archivos y el barrido de huérfanos al arrancar (CL-004-3) se implementan con `AttachmentStore` en la 007. Aquí queda un test de contrato que comprueba que se borran las filas.

## 4. Dependencias nuevas

Ninguna.

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-004-09, CA-004-08 (datos) | Contrato del repositorio (memoria y drift): quita de la cola, `body` nulo, sin adjuntos, no completada, `hasHistory`; `secure_delete` activo | `test/data/repository_contract_test.dart` |
| CA-004-03 | Unitario del caso de uso (guarda antes; tarea que ya no es la actual) | `test/domain/delete_current_task_test.dart` |
| Curvas del arrugado | Unitario de la interpolación de fotogramas clave (valores en 0 %, 22 %, 55 % y 100 %) | `test/features/delete/crumple_keyframes_test.dart` |
| CA-004-01/02/10, CL-004-1/4 | Widget: menú → hoja, etiqueta recortada, Cancelar / fuera / atrás / deslizar / Esc, foco inicial, doble pulsación, texto al 200 % | `test/features/delete/delete_confirm_test.dart` |
| CA-004-03/04/05/06/07/11/12/13 | Widget, flujo con repositorio en memoria y reloj falso: animación y siguiente tarea, bloqueo, sin aviso, última → "Todo hecho.", anuncio y foco, reducir movimiento, error y reintentar, segundo plano a mitad | `test/features/delete/deletion_flow_test.dart` |
| CA-004-08 | Widget del enrutado: reabrir con solo eliminadas → "Todo hecho." | `test/app/home_router_test.dart` |
| Aspecto | *Goldens* de la hoja de confirmación (es/en, texto ×1 y ×2) y del arrugado en 3 puntos de control (14 %, 43 % y 70 %) frente al prototipo | `test/goldens/delete_golden_test.dart` |
| CL-004-2 | Widget: la hoja sobrevive a segundo plano < 10 min | `deletion_flow_test.dart` |
| Integración | Eliminar en el emulador y reabrir | `integration_test/` (flujo existente ampliado) |

## 6. Seguridad, accesibilidad y rendimiento

- **Privacidad (P4):** el contenido se borra en la misma transacción que marca la eliminación, con `secure_delete` activado al abrir **cada conexión** (también cubre lo que borren las migraciones futuras). Un test sobre archivo comprueba que el texto no queda ni en la BD ni en su journal. No hay registros ni analítica.
- **Riesgos residuales aceptados (revisión de seguridad, 2026-09-26):**
  - **[Hecho]** El journal de SQLite (modo DELETE) se desvincula sin sobrescribirse: el texto puede quedar en bloques libres del sistema de archivos, recuperable solo con root y análisis forense (FBE + TRIM). No usar `journal_mode=PERSIST`; si se pasa a WAL, añadir `wal_checkpoint(TRUNCATE)` tras eliminar.
  - **[Hecho]** Copias de seguridad (ADR-0004): la última copia conserva el texto hasta la siguiente (≈ 24 h), y restaurar una copia anterior a la eliminación hace que la tarea **vuelva como pendiente**. Se explicará en "Acerca de" (spec 010) y figura en el modelo de amenazas (T-7).
  - **[Hecho]** Las páginas liberadas antes de la 004 (ediciones de la 005) no se limpian; solo afecta al móvil del propietario antes del lanzamiento.
  - **[Hecho]** Si la app pasa a segundo plano durante el arrugado, la captura de Recientes puede mostrar la nota eliminada hasta que se vuelve a abrir (la app no usa `FLAG_SECURE`).
  - **[Pendiente, bloques 1–3]** Decidir qué campos se vacían en la marca de borrado cuando existan `dueDate`, `parentId`, `source` y `externalId` con contenido.
- **Accesibilidad:** confirmación modal con foco en "Cancelar", acción personalizada, un único anuncio, foco al terminar, reducir movimiento, texto al 200 %.
- **Rendimiento:** la animación usa recorte y transformaciones (sin capas fuera de pantalla salvo la sombra) y se medirá en el Xiaomi con el perfilador (objetivo: sin fotogramas perdidos a 120 Hz, como S2). `secure_delete` añade escritura solo al borrar. El arranque no cambia.

## 7. Riesgos y alternativas

- **El filtro de ruido del prototipo** (`feTurbulence` + luz difusa + desplazamiento) no tiene equivalente directo en Flutter. **Propuesta:** v1 con recorte, facetas, sombreado y sombra, que dan la forma y los pliegues. Si en el móvil se nota la falta de la textura, se añade un `FragmentShader` con ruido fractal (funciona con Impeller en Android; la web de pruebas usaría la versión sin shader). Si se queda sin shader, se registra como **DEV-25**.
- **La tarea de detrás cuando era la última:** se muestra la pantalla "Todo hecho." completa, en lugar del título suelto del prototipo, para que no haya un salto al terminar (DEV-26, a confirmar en el móvil).
- **La rama depende de la PR #8:** si cambia en la revisión, hay que rebasar.
