# Spec 004: Eliminar una tarea

- **Estado:** Implementada (2026-09-26; aprobada por el propietario tras probarla en el móvil, TalkBack incluido) · Aprobada (2026-09-26, propietario). Reescrita ese día con sus decisiones: sin deshacer y sin "Nada pendiente.". Partes diferidas marcadas en los CA (listado 006, adjuntos 007–009)
- **Reglas de producto:** R10, R12 (estado vacío "Todo hecho."), R13 (eliminar desde el listado)
- **Pantallas del prototipo:** 6 "Eliminar", 8 "Eliminar (se arruga)"
- **Decisiones y ADR:** D7, ADR-0011 (sustituye a ADR-0006), DEV-18, DEV-21, DEV-23, DEV-24, DEV-25, DEV-26
- **Dependencias:** 001, 003 (animación, "Todo hecho." y bloqueo de interacciones), 005 (menú); 006 (listado) para el segundo punto de entrada

## 1. Objetivo

Quitar una tarea que ya no tiene sentido **sin** que cuente como hecha, con un gesto que se siente definitivo (el papel se arruga y va a la papelera). **Es definitivo:** la única red de seguridad es la confirmación.

## 2. Historias de usuario

- **HU-004-1** Como usuario, quiero eliminar una tarea que ya no aplica sin marcarla como hecha.
- **HU-004-2** Como usuario, quiero que me pregunten antes de eliminar, porque no se puede deshacer.

## 3. Criterios de aceptación

**Confirmación**

- **CA-004-01 Hoja de confirmación**
  - **Dado** la tarea actual
  - **Cuando** el usuario elige "Eliminar" en el menú (o la acción accesible "Eliminar tarea", CA-004-10)
  - **Entonces**:
    - se cierra el menú y se abre la hoja "¿Eliminar esta tarea?" con el texto “{etiqueta}” desaparecerá sin marcarse como hecha. y los botones "Eliminar" (`dangerFill`, texto `ink`) y "Cancelar" (estilo `ghost`), como en el prototipo;
    - la etiqueta es el texto de la tarea, recortado a 3 líneas con "…" (mismo criterio que "¿Dónde la pones?", DEV-23); el lector de pantalla lee el texto completo;
    - desde el listado (botón eliminar de cada fila) se abre la misma hoja *[Diferido a 006]*;
    - si la tarea no tiene texto, la etiqueta es el nombre del archivo o el dominio *[Diferido a 007–009]*.
- **CA-004-02 Cancelar**
  - **Dado** la hoja de confirmación
  - **Cuando** pulsa "Cancelar", toca fuera, usa el gesto atrás o la desliza hacia abajo (DEV-21)
  - **Entonces** no cambia nada, se vuelve a la tarea actual (no al menú) y el foco queda en la tarea.

**Eliminar la tarea actual**

- **CA-004-03 Los datos, antes de la animación**
  - **Dado** la confirmación
  - **Cuando** pulsa "Eliminar"
  - **Entonces** la eliminación se guarda **antes** de empezar la animación (ADR-0011): la tarea deja de estar en la cola y ya no tiene contenido. Si la app se mata o pasa a segundo plano durante la animación, al volver se ve la siguiente tarea o "Todo hecho.", sin repetir la animación.
- **CA-004-04 Animación de arrugado**
  - **Dado** la eliminación guardada
  - **Cuando** empieza la animación
  - **Entonces**, como en el prototipo:
    - la hoja se cierra y después la nota se arruga hasta formar una bola que cae en una papelera animada (`motion.duration.crumple`, 2,2 s);
    - detrás ya se ve la siguiente tarea, con su color y su texto, o "Todo hecho." si era la última;
    - el logotipo y el botón de menú se quedan (el menú no responde, CA-005-10); el botón "Pulsa para completar" se oculta y la papelera aparece en su lugar.
  - Al terminar, la siguiente tarea es la actual.
- **CA-004-05 Bloqueo durante la animación**
  - **Dado** la animación en curso
  - **Cuando** el usuario toca el menú o el botón de completar, usa las acciones del lector de pantalla o hace el gesto atrás
  - **Entonces** no pasa nada (como en la spec 003).
- **CA-004-06 Sin deshacer**
  - **Dado** que se ha eliminado una tarea
  - **Cuando** termina la animación
  - **Entonces** no aparece ningún aviso ni opción de deshacer: la eliminación es definitiva (decisión del propietario, ADR-0011).

**Estado vacío**

- **CA-004-07 Eliminar la última → "Todo hecho." (R12)**
  - **Dado** que se elimina la última tarea pendiente
  - **Cuando** termina la animación
  - **Entonces** se ve el mismo "Todo hecho." que al completar la última (CA-003-05): los mismos textos, el botón "Crear una tarea" y el mismo comportamiento (CA-003-10). **No existe** la pantalla "Nada pendiente." del prototipo (DEV-24).
- **CA-004-08 Reabrir sin pendientes**
  - **Dado** que no queda ninguna tarea pendiente y hay al menos una completada **o eliminada**
  - **Cuando** se abre la app en frío (o vuelve de segundo plano tras 10 min, CA-001-12)
  - **Entonces** se ve "Todo hecho.". Enmienda CA-003-11 y CA-001-05: el editor de la primera tarea solo se abre si nunca se ha guardado ninguna tarea.

**Datos**

- **CA-004-09 No cuenta como hecha y no queda contenido**
  - **Dado** una tarea eliminada
  - **Cuando** se consulta la BD
  - **Entonces**:
    - no está completada ni aparece en el histórico ni en la cola;
    - tiene `deletedAt` y `updatedAt` con la hora de la eliminación y `text` nulo;
    - no quedan filas de adjuntos ni archivos suyos (en cuanto haya adjuntos, 007–009);
    - solo queda la marca de borrado (ADR-0011).

**Accesibilidad**

- **CA-004-10 Acción accesible**
  - **Dado** un lector de pantalla o acceso por switch
  - **Cuando** invoca la acción personalizada "Eliminar tarea" sobre la tarea actual
  - **Entonces** se abre la hoja de confirmación (nunca elimina directamente), con el foco inicial en "Cancelar". Con teclado, Esc equivale a "Cancelar".
- **CA-004-11 Anuncio y foco**
  - **Dado** un lector de pantalla activo
  - **Cuando** se elimina la tarea actual
  - **Entonces** se hace **un único anuncio**, "Tarea eliminada. Siguiente: {texto}" (o "Tarea eliminada. Todo hecho."), y al terminar el foco pasa a la nueva tarea actual (o al título "Todo hecho.", leído como un solo texto), como en CA-003-07.
- **CA-004-12 Reducir movimiento**
  - **Dado** "reducir movimiento" activado
  - **Cuando** se elimina la tarea actual
  - **Entonces** la nota se desvanece en 0,6 s (`motion.duration.crumpleReducedFade`, como el prototipo), sin arrugado ni papelera.

**Errores**

- **CA-004-13 Fallo al eliminar**
  - **Dado** un fallo de escritura al confirmar
  - **Cuando** pulsa "Eliminar"
  - **Entonces** la hoja se cierra, no hay animación, la tarea sigue siendo la actual y aparece el aviso "No hemos podido eliminar la tarea" con "Reintentar" (mismo estilo que `completeError`).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-004-1 | Doble pulsación rápida en "Eliminar" | Se elimina una sola vez; la hoja no responde a la segunda pulsación |
| CL-004-2 | Pasar a segundo plano con la hoja de confirmación abierta | Al volver (< 10 min), la hoja sigue abierta; tras 10 min, la tarea actual sin hoja (CA-001-12) |
| CL-004-3 | Falla el borrado de los archivos de un adjunto | No se avisa: los archivos huérfanos se borran en el siguiente arranque, después del primer fotograma (no retrasa CA-001-09) *[Adjuntos: 007–009]* |
| CL-004-4 | Texto grande (200 %) | La hoja hace scroll si no cabe; "Eliminar" y "Cancelar" siempre alcanzables y de al menos 44 pt |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Todo hecho." | Se eliminó la última pendiente, o se reabre sin pendientes | CA-004-07, CA-004-08 |
| Error al eliminar | Fallo de escritura | CA-004-13 |

## 6. Accesibilidad

- Confirmación modal con el foco inicial en "Cancelar", la acción segura (CA-004-10).
- "Eliminar" en rojo **y** con texto; el color no es la única señal. Contraste `ink` sobre `dangerFill`: 6,1:1.
- Acción personalizada "Eliminar tarea" en la tarea actual (CA-004-10) y en cada fila del listado *[006]*.
- Un único anuncio y el foco en la nueva tarea actual o en "Todo hecho." (CA-004-11).
- Reducir movimiento: fundido de 0,6 s (CA-004-12). Texto grande: CL-004-4.

## 7. Textos (ES / EN)

| Clave | ES | EN | Nota |
|---|---|---|---|
| `deleteTitle` | ¿Eliminar esta tarea? | Delete this task? | |
| `deleteBody` | “{label}” desaparecerá sin marcarse como hecha. | “{label}” will disappear without being marked as done. | Comillas “” del prototipo |
| `deleteConfirm` | Eliminar | Delete | Clave propia (contexto distinto de `menuDelete`) |
| `deleteA11yAction` | Eliminar tarea | Delete task | La reutiliza el listado (006) |
| `a11yDeletedNext` | Tarea eliminada. Siguiente: {text} | Task deleted. Next: {text} | |
| `a11yDeletedAllDone` | Tarea eliminada. Todo hecho. | Task deleted. All done. | |
| `deleteError` | No hemos podido eliminar la tarea | We couldn't delete the task | Con `retry` |

Se reutilizan `editorCancel` ("Cancelar", se amplía su descripción), `retry`, `emptyDoneTitle*`, `emptyDoneBody` y `emptyCreate`. **No** se añaden `toastDeleted`, `toastUndo`, `a11yDeletedUndo` ni `emptyNone*`.

## 8. Fuera de alcance

- **Deshacer** tras eliminar (decisión del propietario, 2026-09-26; ADR-0011).
- La pantalla "Nada pendiente." (DEV-24).
- Papelera recuperable. Eliminar varias a la vez.

## 9. Preguntas abiertas

- **[Resuelto 2026-09-26]** Sin deshacer y sin "Nada pendiente.": tras eliminar la última se ve "Todo hecho." (propietario).
- **[Resuelto 2026-09-26, plan]** `PRAGMA secure_delete = ON` en cada conexión: el texto eliminado no queda en el archivo de la BD (test sobre archivo). Riesgos residuales aceptados en `plan.md` §6.
- **[Resuelto 2026-09-26]** ADR-0011 aceptado por el propietario.
