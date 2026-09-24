# Spec 002: Crear una tarea de texto y elegir dónde va

- **Estado:** En revisión
- **Reglas de producto:** R3 (texto), R4, R5 (solo la excepción: los adjuntos no preguntan; detalle en 007–009)
- **Pantallas del prototipo:** 3 "Nueva tarea", 4 "¿Dónde va?"
- **Decisiones y ADR:** ADR-0002 (rank), D5
- **Dependencias:** 001

## 1. Objetivo

Apuntar algo nuevo sin perder el foco: el usuario decide si pasa a ser lo que hace ahora o si espera su turno al final de la cola.

## 2. Historias de usuario

- **HU-002-1** Como usuario con una tarea en curso, quiero apuntar otra sin que sustituya a la actual, para no olvidarla.
- **HU-002-2** Como usuario, quiero poner arriba del todo algo urgente para hacerlo ya.

## 3. Criterios de aceptación

- **CA-002-01 Abrir el editor**
  - **Dado** que hay al menos una tarea pendiente
  - **Cuando** el usuario elige "Nueva tarea" (en el menú o en el listado)
  - **Entonces** se abre el editor con la etiqueta "Nueva tarea", el foco en el texto, "Cancelar" arriba, el botón de añadir (+) y "Continuar" (deshabilitado hasta que haya texto o un adjunto). El color de la nota del editor es el que tendrá la tarea (distinto del de la actual).
- **CA-002-02 Preguntar la posición (R4)**
  - **Dado** el editor con un texto no vacío **y sin adjunto**, y al menos otra tarea pendiente
  - **Cuando** pulsa "Continuar"
  - **Entonces** aparece la hoja "¿Dónde la pones?" con: "Arriba del todo — Pasa a ser la única visible. La actual espera.", "A la cola — No la verás hasta completar las anteriores." y "Seguir editando".
- **CA-002-03 Arriba del todo**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "Arriba del todo"
  - **Entonces** la nueva tarea pasa a ser la tarea actual; la anterior queda en segunda posición; se vuelve a la pantalla principal mostrando la nueva.
- **CA-002-04 A la cola**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "A la cola"
  - **Entonces** la nueva tarea queda la última de la cola y la pantalla principal sigue mostrando la tarea actual anterior. Se anuncia "Tarea añadida a la cola" (aviso breve visible y accesible).
- **CA-002-05 Seguir editando**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "Seguir editando", toca fuera o desliza hacia abajo
  - **Entonces** la hoja se cierra y el editor conserva el texto.
- **CA-002-06 Sin otras tareas pendientes**
  - **Dado** que no hay ninguna tarea pendiente (estado "Todo hecho." o "Nada pendiente.")
  - **Cuando** crea una tarea desde "Crear una tarea"
  - **Entonces** el botón dice "Guardar", no se pregunta la posición y la tarea pasa a ser la actual.
- **CA-002-07 Cancelar**
  - **Dado** el editor de una tarea nueva con texto escrito
  - **Cuando** pulsa "Cancelar"
  - **Entonces** se descarta sin preguntar (el texto no se guarda) y se vuelve a la pantalla de origen (principal o listado).
- **CA-002-08 Volver al listado**
  - **Dado** que el editor se abrió desde "Todas las tareas"
  - **Cuando** la tarea se coloca (arriba o a la cola)
  - **Entonces** se vuelve al listado con la nueva tarea en su posición y resaltada brevemente (0,9 s).
- **CA-002-09 Adjuntos no preguntan (R5)**
  - **Dado** el editor con un adjunto (imagen, foto, documento o URL)
  - **Cuando** pulsa "Continuar"
  - **Entonces** **no** aparece la hoja y la tarea va arriba del todo (detalle en las specs 007–009).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-002-1 | Cientos de inserciones "arriba del todo" seguidas | El orden se mantiene (orden fraccional); se renumera de forma transparente si las claves crecen |
| CL-002-2 | La app se cierra con la hoja "¿Dónde la pones?" abierta | No se guarda nada (P-1 de la spec 001) |
| CL-002-3 | Texto idéntico a otra tarea | Se permite (no se deduplica) |
| CL-002-4 | Doble pulsación rápida en "Arriba del todo" | Se crea una sola tarea |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Error al guardar | Fallo de escritura | Aviso "No se ha podido guardar. Inténtalo de nuevo."; el editor conserva el texto |

## 6. Accesibilidad

- La hoja es un diálogo modal: el foco va al título "¿Dónde la pones?" y queda atrapado en la hoja; Escape o el gesto atrás equivale a "Seguir editando".
- Cada opción se lee con su título y su descripción.
- Con reducir movimiento, la hoja aparece con un fundido, sin deslizamiento.
- El resaltado del listado (CA-002-08) se acompaña del anuncio "Tarea añadida en la posición {n}".

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `editorTagNew` | Nueva tarea | New task |
| `editorCancel` | Cancelar | Cancel |
| `editorContinue` | Continuar | Continue |
| `editorSave` | Guardar | Save |
| `placementTitle` | ¿Dónde la pones? | Where does it go? |
| `placementTop` | Arriba del todo | On top |
| `placementTopHint` | Pasa a ser la única visible. La actual espera. | It becomes the only one you see. The current one waits. |
| `placementEnd` | A la cola | At the end |
| `placementEndHint` | No la verás hasta completar las anteriores. | You won't see it until you finish the ones before it. |
| `placementKeepEditing` | Seguir editando | Keep editing |
| `toastQueued` | Tarea añadida a la cola | Task added to the queue |
| `a11yAddedAtPosition` | Tarea añadida en la posición {position} | Task added at position {position} |
| `saveError` | No se ha podido guardar. Inténtalo de nuevo. | Couldn't save. Please try again. |

## 8. Fuera de alcance

Creación en bloque (Bloque 2), fechas límite (Bloque 1), adjuntos (007–009).

## 9. Preguntas abiertas

- **[Pendiente P-3]** ¿"Cancelar" con texto escrito debe pedir confirmación? Recomendación: no (el prototipo no lo hace y el texto es corto); reconsiderarlo si se pierde contenido largo. Decide: producto.
