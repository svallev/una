# Spec 002: Crear una tarea de texto y elegir dónde va

- **Estado:** Implementada (2026-09-25; aprobada por el propietario tras probarla en el móvil). Partes diferidas marcadas en los CA (listado 006, adjuntos 007–009, eliminar 004, configuración 010)
- **Reglas de producto:** R3 (texto), R4, R5 (solo la excepción: los adjuntos no preguntan; detalle en 007–009)
- **Pantallas del prototipo:** 3 "Nueva tarea", 4 "¿Dónde va?"
- **Decisiones y ADR:** ADR-0002 (rank), D5, DEV-12, DEV-17, DEV-21
- **Dependencias:** 001, 005 (el menú es el punto de entrada; se implementan juntas)

## 1. Objetivo

Apuntar algo nuevo sin perder el foco: el usuario decide si pasa a ser lo que hace ahora o si espera su turno al final de la cola.

## 2. Historias de usuario

- **HU-002-1** Como usuario con una tarea en curso, quiero apuntar otra sin que sustituya a la actual, para no olvidarla.
- **HU-002-2** Como usuario, quiero poner arriba del todo algo urgente para hacerlo ya.

## 3. Criterios de aceptación

- **CA-002-01 Abrir el editor**
  - **Dado** que hay al menos una tarea pendiente
  - **Cuando** el usuario elige "Nueva tarea" en el menú (spec 005) o "Nueva tarea" en el listado (CA-006-15)
  - **Entonces** el editor aparece con un fundido de 0,8 s, como en el prototipo: el logotipo y "Cancelar" (enlace subrayado) arriba, el campo centrado con el foco y el teclado abiertos, y abajo "+" y "Continuar →", **ambos activos** (DEV-17). La etiqueta "Nueva tarea" **no se ve**: es el nombre accesible del campo. El color de la nota se elige al abrir el editor, al azar y distinto del de la tarea actual (CA-001-08), y se conserva si se vuelve a editar.
- **CA-002-02 Preguntar la posición (R4)**
  - **Dado** el editor con un texto no vacío **y sin adjunto**
  - **Cuando** pulsa "Continuar →"
  - **Entonces** sube la hoja "¿Dónde la pones?" (ver CA-005-01 para cómo son las hojas) con el título, el texto de la tarea entre comillas y tres opciones: "Arriba del todo — Pasa a ser la única visible. La actual espera." (con el color de la nueva tarea), "A la cola — No la verás hasta completar las anteriores." y "Seguir editando".
- **CA-002-03 Arriba del todo**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "Arriba del todo"
  - **Entonces** la nueva tarea pasa a ser la tarea actual; la anterior queda en segunda posición; se vuelve a la pantalla principal mostrando la nueva, con el foco en ella.
- **CA-002-04 A la cola**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "A la cola"
  - **Entonces** la nueva tarea queda la última de la cola y se vuelve a la pantalla principal, que sigue mostrando la tarea actual. **No se ve ningún aviso** (como el prototipo; decisión del propietario); el lector de pantalla anuncia "Tarea añadida a la cola".
- **CA-002-05 Seguir editando**
  - **Dado** la hoja "¿Dónde la pones?"
  - **Cuando** elige "Seguir editando", toca fuera, desliza hacia abajo (DEV-21) o usa el gesto atrás
  - **Entonces** la hoja se cierra y el editor conserva el texto y el color.
- **CA-002-06 Sin tareas pendientes**
  - Ya cubierto por CA-003-10 (desde "Todo hecho.": sin "Cancelar", con "Guardar", sin preguntar la posición).
- **CA-002-07 Cancelar**
  - **Dado** el editor de una tarea nueva, con o sin texto
  - **Cuando** pulsa "Cancelar" o usa el gesto atrás
  - **Entonces** se descarta sin preguntar (como el prototipo; P-3 resuelto) y se vuelve a la pantalla principal (o al listado si se abrió desde él, CA-006-15).
- **CA-002-08 Volver al listado** — Sustituido por CA-006-15.
- **CA-002-09 Adjuntos no preguntan (R5)** — *[Diferido a 007–009]*.
- **CA-002-10 Continuar sin texto**
  - **Dado** el editor sin texto (o solo espacios) y sin adjunto
  - **Cuando** pulsa "Continuar →"
  - **Entonces** no pasa nada y el foco vuelve al campo (DEV-17).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-002-1 | Cientos de inserciones "Arriba del todo" seguidas | Tras 1 000 inserciones, el orden es exactamente el inverso al de creación |
| CL-002-2 | La app se cierra con la hoja abierta | No se guarda nada (P-1 de la spec 001) |
| CL-002-3 | Texto idéntico a otra tarea | Se permite (no se deduplica) |
| CL-002-4 | Doble pulsación rápida en "Arriba del todo" | Se crea una sola tarea |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Error al guardar | Fallo de escritura al colocar la tarea | La hoja se cierra; aviso `editorSaveError` (o el de falta de espacio) con "Reintentar"; el editor conserva el texto (como la spec 001) |

## 6. Accesibilidad

- La hoja es un diálogo modal: el foco va al título "¿Dónde la pones?" y queda atrapado en la hoja; Escape o el gesto atrás equivalen a "Seguir editando".
- Cada opción se lee con su título y su descripción.
- Con reducir movimiento, la hoja aparece sin desplazarse; solo el fondo se funde.
- Tras colocar la tarea, el foco va a la tarea actual.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `editorTagNew` | Nueva tarea | New task | Nombre accesible del campo (no se ve) |
| `editorCancel` | Cancelar | Cancel | |
| `editorContinue` | Continuar | Continue | Con flecha → |
| `placementTitle` | ¿Dónde la pones? | Where does it go? | |
| `placementQuoted` | “{text}” | “{text}” | Texto de la tarea bajo el título |
| `placementTop` | Arriba del todo | On top | |
| `placementTopHint` | Pasa a ser la única visible. La actual espera. | It becomes the only one you see. The current one waits. | |
| `placementEnd` | A la cola | At the end | |
| `placementEndHint` | No la verás hasta completar las anteriores. | You won't see it until you finish the ones before it. | |
| `placementKeepEditing` | Seguir editando | Keep editing | |
| `a11yQueued` | Tarea añadida a la cola | Task added to the queue | Solo lector de pantalla |

Se reutilizan `editorSaveFirst` ("Guardar"), `attachButton`, `editorSaveError`, `storageErrorNoSpace` y `retry`.

## 8. Fuera de alcance

Creación en bloque (Bloque 2), fechas límite (Bloque 1), adjuntos (007–009), listado (006).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-25] P-3:** "Cancelar" no pide confirmación (como el prototipo).
- **[Resuelto 2026-09-25]** "A la cola" sin aviso visible; las hojas se cierran también deslizando hacia abajo (DEV-21).
