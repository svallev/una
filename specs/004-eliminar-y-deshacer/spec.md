# Spec 004: Eliminar una tarea (con deshacer)

- **Estado:** En revisión
- **Reglas de producto:** R10, R12 ("Nada pendiente."), R13 (eliminar desde el listado)
- **Pantallas del prototipo:** 6 "Eliminar", 8 "Eliminar (se arruga)"
- **Decisiones y ADR:** D7, ADR-0006, DEV-09, DEV-10
- **Dependencias:** 001; 005 (menú) y 006 (listado) para los puntos de entrada

## 1. Objetivo

Quitar una tarea que ya no tiene sentido **sin** que cuente como hecha, con un gesto que se siente definitivo (papel arrugado) pero con red de seguridad.

## 2. Historias de usuario

- **HU-004-1** Como usuario, quiero eliminar una tarea que ya no aplica sin marcarla como hecha.
- **HU-004-2** Como usuario, quiero poder deshacer si me equivoco.

## 3. Criterios de aceptación

- **CA-004-01 Confirmación**
  - **Dado** la tarea actual (menú → "Eliminar") o cualquier tarea del listado (botón eliminar)
  - **Cuando** el usuario lo elige
  - **Entonces** aparece la hoja "¿Eliminar esta tarea?" con el texto "«{etiqueta}» desaparecerá sin marcarse como hecha." y los botones "Eliminar" (rojo) y "Cancelar". La etiqueta es el texto de la tarea (máx. 80 caracteres + "…"), o el nombre del archivo o el dominio si no tiene texto.
- **CA-004-02 Cancelar**
  - **Dado** la hoja de confirmación
  - **Cuando** pulsa "Cancelar", toca fuera o usa el gesto atrás
  - **Entonces** no cambia nada.
- **CA-004-03 Eliminar la tarea actual con animación**
  - **Dado** la confirmación de la tarea actual
  - **Cuando** pulsa "Eliminar"
  - **Entonces** la hoja se cierra, la nota se arruga hasta formar una bola que cae en una papelera animada (2,2 s) y después se muestra la siguiente tarea actual.
- **CA-004-04 Eliminar desde el listado**
  - **Dado** la confirmación de una tarea desde el listado
  - **Cuando** pulsa "Eliminar"
  - **Entonces** la tarea desaparece del listado sin animación de arrugado y se sigue en el listado (o se vuelve al estado vacío si no queda ninguna).
- **CA-004-05 Deshacer**
  - **Dado** que se acaba de eliminar una tarea
  - **Cuando** termina la eliminación
  - **Entonces** aparece el aviso "Tarea eliminada" con el botón "Deshacer" durante 6 s; si lo pulsa, la tarea vuelve **a su posición original** (si era la actual, vuelve a ser la actual).
- **CA-004-06 No cuenta como hecha**
  - **Dado** una tarea eliminada
  - **Cuando** se consulta la BD
  - **Entonces** no está completada ni en el histórico; tiene `deletedAt`; al vencer la ventana de deshacer se borran sus archivos y su contenido, y solo queda la marca de borrado (ADR-0006).
- **CA-004-07 Nada pendiente (R12)**
  - **Dado** que se elimina la última tarea pendiente
  - **Cuando** termina la eliminación
  - **Entonces** se muestra "Nada pendiente." / "No tienes ninguna tarea. Apunta lo siguiente cuando lo sepas." y "Crear una tarea", junto al aviso de deshacer.
- **CA-004-08 Purga al arrancar**
  - **Dado** que la app se cerró durante la ventana de deshacer
  - **Cuando** se vuelve a abrir
  - **Entonces** la eliminación es definitiva (se purga) y no se ofrece deshacer.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-004-1 | Eliminar otra tarea mientras hay un aviso de deshacer | El aviso anterior se sustituye; la primera eliminación queda firme y se purga |
| CL-004-2 | Deshacer cuando la posición original ya no existe (se reordenó) | Vuelve con su `rank` original; el orden relativo se mantiene |
| CL-004-3 | Crear una tarea durante la ventana de deshacer | El aviso sigue; deshacer restaura la eliminada en su posición |
| CL-004-4 | Tarea con adjunto grande | Los archivos solo se borran en la purga (no antes, para poder deshacer) |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Nada pendiente." | Se eliminó la última | CA-004-07 |
| Error al eliminar | Fallo de escritura | Sin animación; aviso "No se ha podido eliminar. Inténtalo de nuevo." |

## 6. Accesibilidad

- La confirmación es un diálogo modal con el foco inicial en "Cancelar" (acción segura).
- "Eliminar" en rojo **y** con texto (el color no es la única señal). Contraste `ink` sobre `dangerFill` 6,1:1.
- El aviso de deshacer se anuncia ("Tarea eliminada. Deshacer disponible"), es alcanzable con el foco y, con lector de pantalla activo, dura ≥ 10 s.
- Acción personalizada "Eliminar tarea" en la tarea actual y en cada fila del listado.
- Reducir movimiento: fundido de 0,6 s en lugar de arrugado y sin papelera.

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `deleteTitle` | ¿Eliminar esta tarea? | Delete this task? |
| `deleteBody` | «{label}» desaparecerá sin marcarse como hecha. | "{label}" will disappear without being marked as done. |
| `deleteConfirm` | Eliminar | Delete |
| `deleteCancel` | Cancelar | Cancel |
| `toastDeleted` | Tarea eliminada | Task deleted |
| `toastUndo` | Deshacer | Undo |
| `a11yDeletedUndo` | Tarea eliminada. Deshacer disponible | Task deleted. Undo available |
| `emptyNoneTitle1` / `emptyNoneTitle2` | Nada / pendiente. | Nothing / pending. |
| `emptyNoneBody` | No tienes ninguna tarea. Apunta lo siguiente cuando lo sepas. | You have no tasks. Jot down what's next when you know it. |
| `deleteError` | No se ha podido eliminar. Inténtalo de nuevo. | Couldn't delete it. Please try again. |

## 8. Fuera de alcance

Papelera recuperable (descartada, ADR-0006). Eliminar varias a la vez.
