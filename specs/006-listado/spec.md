# Spec 006: Todas las tareas (listado)

- **Estado:** En revisión
- **Reglas de producto:** R7, R13
- **Pantallas del prototipo:** 5 "Todas las tareas (con acciones)"
- **Decisiones y ADR:** ADR-0002 (rank), DEV-11, DEV-14
- **Dependencias:** 001, 002, 004, 005

## 1. Objetivo

Ver y organizar la cola cuando hace falta, sin que ese acceso compita con el foco en una sola tarea (hacen falta dos interacciones).

## 2. Historias de usuario

- **HU-006-1** Como usuario, quiero ver lo que tengo pendiente y cambiar el orden.
- **HU-006-2** Como usuario, quiero poner otra tarea como la actual arrastrándola arriba del todo.
- **HU-006-3** Como usuario de lector de pantalla, quiero reordenar sin arrastrar.

## 3. Criterios de aceptación

- **CA-006-01 Acceso en dos pasos (R7)**
  - **Dado** la pantalla principal con ≥ 2 tareas pendientes
  - **Cuando** abre el menú y elige "Todas mis tareas"
  - **Entonces** se abre el listado. No existe ningún atajo de un solo paso (ni gesto ni botón en la pantalla principal).
- **CA-006-02 Contenido**
  - **Dado** el listado
  - **Cuando** se muestra
  - **Entonces** aparecen el título "Todas las tareas", el botón "Volver a la tarea", la ayuda "La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla.", todas las tareas pendientes en orden, cada una con su color, miniatura (imagen) o insignia (PDF, DOC, WEB…), su texto o nombre y los botones Editar y Eliminar, y el botón "Nueva tarea" abajo. La primera lleva la etiqueta **"Lo siguiente"** y no tiene asa de arrastre.
- **CA-006-03 Reordenar arrastrando (R13)**
  - **Dado** una tarea que no es la primera
  - **Cuando** la arrastra (umbral de 6 px) a otra posición y la suelta
  - **Entonces** la tarea se levanta (se inclina y la sombra crece), las demás se desplazan para hacerle hueco y, al soltarla, queda en la nueva posición (se guarda al instante).
- **CA-006-04 Sustituir la actual**
  - **Dado** una tarea arrastrada por encima de la primera
  - **Cuando** la suelta en la posición 1
  - **Entonces** pasa a ser la tarea actual (con la etiqueta "Lo siguiente") y la anterior queda en segunda posición. Al volver a la pantalla principal se ve la nueva actual.
- **CA-006-05 La actual no se arrastra**
  - **Dado** la primera tarea
  - **Cuando** intenta arrastrarla
  - **Entonces** no se mueve (sí se pueden mover otras encima).
- **CA-006-06 Doble toque para editar**
  - **Dado** una tarea del listado
  - **Cuando** toca dos veces sobre ella (en < 350 ms)
  - **Entonces** se abre el editor en modo editar (spec 005) y al guardar se vuelve al listado.
- **CA-006-07 Editar y eliminar con botones**
  - **Dado** una fila
  - **Cuando** pulsa Editar o Eliminar
  - **Entonces** abre el editor (spec 005) o la confirmación (spec 004, sin arrugado).
- **CA-006-08 Crear desde el listado**
  - **Dado** el listado
  - **Cuando** pulsa "Nueva tarea" y la coloca
  - **Entonces** vuelve al listado con la tarea resaltada (spec 002, CA-002-08).
- **CA-006-09 Volver**
  - **Dado** el listado
  - **Cuando** pulsa "Volver a la tarea" o usa el gesto atrás
  - **Entonces** vuelve a la pantalla principal mostrando la tarea actual (la que haya quedado primera).
- **CA-006-10 Reordenar sin arrastrar**
  - **Dado** un lector de pantalla, teclado o switch
  - **Cuando** usa las acciones de una fila "Mover arriba", "Mover abajo" o "Hacer actual"
  - **Entonces** la tarea cambia de posición y se anuncia "Movida a la posición {n} de {total}" (o "Ahora es la tarea actual").

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-006-1 | Listado largo (500 tareas) | Desplazamiento fluido (lista perezosa); desplazamiento automático al arrastrar cerca de los bordes |
| CL-006-2 | Se elimina la penúltima y queda una | El listado muestra esa única tarea y sus acciones; "Nueva tarea" sigue disponible |
| CL-006-3 | Se eliminan todas desde el listado | Se vuelve a "Todo hecho." (CA-004-07; no existe "Nada pendiente.") |
| CL-006-4 | Soltar en la misma posición | No se escribe nada |
| CL-006-5 | Doble toque sobre los botones Editar/Eliminar | Cuenta solo como el botón (no dispara el doble toque de la fila) |
| CL-006-6 | Tarea sin texto (solo adjunto) | Se muestra el nombre del archivo o el dominio |

## 5. Accesibilidad

- Cada fila se lee "{posición} de {total}: {texto}. {tipo de adjunto si hay}"; la primera, "Lo siguiente: {texto}".
- Acciones personalizadas por fila: Hacer actual, Mover arriba, Mover abajo, Editar, Eliminar (en la primera, solo Editar y Eliminar).
- El asa de arrastre es decorativa para el lector. El doble toque de la fila **no** es la única forma de editar (hay un botón).
- Reducir movimiento: sin inclinación ni desplazamiento animado; el cambio de orden es inmediato.
- Botones de fila ≥ 44 × 44 pt.

## 6. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `listTitle` | Todas las tareas | All tasks |
| `listBack` | Volver a la tarea | Back to the task |
| `listHelp` | La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla. | The first one is the one you have now. Drag another above it to take its place. Double-tap a task to edit it. |
| `listUpNext` | Lo siguiente | Up next |
| `listEdit` | Editar tarea | Edit task |
| `listDelete` | Eliminar tarea | Delete task |
| `listNewTask` | Nueva tarea | New task |
| `listMoveUp` | Mover arriba | Move up |
| `listMoveDown` | Mover abajo | Move down |
| `listMakeCurrent` | Hacer actual | Make current |
| `a11yRowPosition` | {position} de {total}: {text} | {position} of {total}: {text} |
| `a11yMovedTo` | Movida a la posición {position} de {total} | Moved to position {position} of {total} |
| `a11yNowCurrent` | Ahora es la tarea actual | It's now the current task |
| `badgeWeb` | WEB | WEB |

## 7. Fuera de alcance

Agrupación por fecha (Bloque 1), completar desde el listado, selección múltiple, búsqueda.
