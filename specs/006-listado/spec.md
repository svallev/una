# Spec 006: Todas las tareas (listado)

- **Estado:** Aprobada (2026-09-26, propietario). Reescrita ese día con sus decisiones tras la revisión (spec-reviewer y a11y-reviewer). Partes diferidas marcadas en los CA (adjuntos 007–009)
- **Reglas de producto:** R7 (acceso en dos pasos), R13 (reordenar, editar y eliminar desde el listado)
- **Pantallas del prototipo:** 5 "Todas las tareas (con acciones)"
- **Decisiones y ADR:** ADR-0002 (rank), ADR-0011 (eliminar es definitivo), DEV-09 (revocada), DEV-11, DEV-14, DEV-18, DEV-21, DEV-24, DEV-27 a DEV-34
- **Tokens:** `shadow.listItem`, `shadow.listItemDragging`, `shadow.listItemFlash`, `motion.duration.listFlash` (900 ms), `motion.duration.doubleTapWindow` (350 ms), `motion.dragThreshold` (6 px lógicos), `minTouchTarget`
- **Dependencias:** 001, 002, 004, 005

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Ver y organizar la cola cuando hace falta, sin que ese acceso compita con el foco en una sola tarea: hacen falta dos interacciones para llegar (menú → "Todas mis tareas").

## 2. Historias de usuario

- **HU-006-1** Como usuario, quiero ver lo que tengo pendiente y cambiar el orden, para decidir qué viene después.
- **HU-006-2** Como usuario, quiero poner otra tarea como la actual arrastrándola arriba del todo, para cambiar de prioridad sin crear nada.
- **HU-006-3** Como usuario que no puede o no quiere arrastrar (lector de pantalla, switch, teclado o poca precisión con el dedo), quiero reordenar con botones o acciones, para no depender del gesto.

## 3. Criterios de aceptación

**Abrir, ver y volver**

- **CA-006-01 Acceso en dos pasos (R7)**
  - **Dado** la pantalla principal con ≥ 2 tareas pendientes
  - **Cuando** abre el menú y elige "Todas mis tareas"
  - **Entonces** el menú se cierra y el listado aparece sin transición, como en el prototipo. No existe ningún atajo de un solo paso (ni gesto ni botón en la pantalla principal). Con una sola tarea, "Todas mis tareas" sigue deshabilitado (CA-005-03, DEV-11).
- **CA-006-02 Contenido**
  - **Dado** el listado
  - **Cuando** se muestra
  - **Entonces**, como en el prototipo:
    - arriba, fijos: el botón "Volver a la tarea" (flecha), el título "Todas las tareas" y la ayuda "La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla.";
    - en medio, desplazable: todas las tareas pendientes en orden, cada una en una fila con su color, borde de 3 px, sombra `listItem`, su texto y los botones "Editar tarea" y "Eliminar tarea" (iconos en `ink`);
    - abajo, fijo: el botón "Nueva tarea".
  - La **primera fila** es la tarea actual: texto más grande (20 px, peso 800), **sin asa** y **sin etiqueta visible** (la etiqueta "Lo siguiente" del prototipo está oculta y no se muestra). Las demás: texto de 16 px (peso 600) y el asa a la izquierda.
  - El texto de cada fila se recorta a **3 líneas** con "…" (DEV-29); el lector de pantalla lee el texto completo.
  - *[Diferido a 007–009]* Miniatura de 44 px (imagen) o insignia con la extensión en mayúsculas (PDF, DOCX…; "WEB" para las URL) entre el asa y el texto; sin texto, se muestra el nombre del archivo o el dominio.
- **CA-006-03 Volver**
  - **Dado** el listado
  - **Cuando** pulsa "Volver a la tarea" o usa el gesto atrás
  - **Entonces** vuelve a la pantalla principal mostrando la tarea que haya quedado primera, con su color, y el foco en ella.

**Reordenar**

- **CA-006-04 Arrastrar desde el asa**
  - **Dado** una fila que no es la primera
  - **Cuando** pone el dedo en el asa y lo mueve más de 6 px en vertical
  - **Entonces** la fila se levanta al instante: sigue al dedo, se inclina −1,5° y su sombra crece a `listItemDragging`; las demás se desplazan (0,2 s) para hacerle hueco. Al soltar, queda en la nueva posición y se guarda en ese momento.
- **CA-006-05 Arrastrar desde el resto de la fila (DEV-27)**
  - **Dado** una fila que no es la primera
  - **Cuando** mantiene pulsado en cualquier punto de la fila que no sea un botón y después mueve el dedo
  - **Entonces** la fila se levanta y se arrastra igual que desde el asa. Deslizar sin mantener pulsado **desplaza la lista**, no arrastra.
- **CA-006-06 Sustituir la actual**
  - **Dado** una fila arrastrada por encima de la primera
  - **Cuando** la suelta en la posición 1
  - **Entonces** pasa a ser la tarea actual (aspecto de primera fila, sin asa) y la anterior queda en segunda posición, con asa. Al volver a la pantalla principal se ve la nueva actual, con su color.
- **CA-006-07 La actual no se arrastra**
  - **Dado** la primera fila
  - **Cuando** intenta arrastrarla (con o sin mantener pulsado)
  - **Entonces** no se mueve; deslizar sobre ella desplaza la lista. Sí se pueden soltar otras por encima.
- **CA-006-08 Botón "Mover" (DEV-28)**
  - **Dado** una fila que no es la primera
  - **Cuando** **toca** el asa (sin arrastrar) o la activa con el teclado
  - **Entonces** sube una hoja como las del menú (CA-005-01, cierre como CA-005-02 y DEV-21) con la etiqueta "Mover tarea", la X y las opciones que tengan sentido para esa posición (CA-006-09). Elegir una mueve la tarea, cierra la hoja y deja el foco en la tarea en su nueva posición (CA-006-17).
  - El asa es un botón de al menos 48 × 48 dp con el nombre accesible "Mover tarea".
- **CA-006-09 Opciones de mover según la posición**
  - **Dado** una fila en la posición *p* de *N*
  - **Cuando** se abre "Mover" o las acciones del lector de pantalla (CA-006-16)
  - **Entonces** se ofrecen, siempre en este orden:
    - "Hacer actual": si *p* ≥ 2. Lleva la tarea a la posición 1;
    - "Mover arriba": si *p* ≥ 3. En la posición 2 no se ofrece, porque equivaldría a "Hacer actual";
    - "Mover abajo": si *p* < *N*.
  - La primera fila no tiene asa ni opciones de mover.
- **CA-006-10 Qué se guarda al reordenar**
  - **Dado** un cambio de orden (arrastre, "Mover" o acción del lector)
  - **Cuando** se guarda
  - **Entonces** solo cambian la posición (`rank`) y `updatedAt` de la tarea movida (ADR-0002); el color y el texto no cambian. El nuevo orden sobrevive a matar la app justo después de soltar (CA-001-10).
- **CA-006-11 Arrastre interrumpido (DEV-32)**
  - **Dado** una fila levantada
  - **Cuando** el sistema cancela el gesto (llamada, la app pasa a segundo plano, aviso del sistema)
  - **Entonces** la fila vuelve a su sitio y no se guarda nada.
- **CA-006-12 Desplazamiento automático (DEV-31)**
  - **Dado** una fila levantada
  - **Cuando** el dedo se acerca al borde superior o inferior de la zona de la lista
  - **Entonces** la lista se desplaza sola en esa dirección, para poder llevar la tarea a cualquier posición de una lista larga.

**Editar, eliminar y crear**

- **CA-006-13 Editar**
  - **Dado** una fila
  - **Cuando** toca dos veces sobre ella (dos toques en la **misma** fila en < 350 ms, fuera de los botones), pulsa "Editar tarea" o la activa con el lector de pantalla
  - **Entonces** se abre el editor en modo editar (CA-005-04). Al guardar o cancelar se vuelve al listado, con la fila en su sitio, el desplazamiento de la lista conservado y el foco en esa fila.
  - Un solo toque no hace nada. *[Tareas web: se abre la hoja "Cargar URL" (CA-005-08); diferido a 009]*
- **CA-006-14 Eliminar desde el listado**
  - **Dado** una fila
  - **Cuando** pulsa "Eliminar tarea" (o usa la acción del lector)
  - **Entonces** se abre la misma confirmación de CA-004-01, con el foco inicial en "Cancelar":
    - **Cancelar** (o tocar fuera, deslizar hacia abajo, gesto atrás): no cambia nada, se vuelve al listado y el foco vuelve a esa fila;
    - **Eliminar:** la eliminación se guarda como en CA-004-03 y CA-004-09, **sin arrugado ni animación** (como el prototipo, DEV-09 revocada): la fila desaparece y las de debajo suben. No hay deshacer (ADR-0011);
    - si era la primera, la siguiente pasa a ser la actual (aspecto de primera fila, sin asa);
    - si era la última pendiente, se va directamente a "Todo hecho." (CA-004-07, sin animación) y el listado deja de existir: el gesto atrás no vuelve a él (CL-006-3);
    - si falla la escritura: CA-004-13, con el aviso sobre el listado y la fila en su sitio.
  - Se puede eliminar cualquier fila, no solo la primera.
- **CA-006-15 Crear desde el listado**
  - **Dado** el listado
  - **Cuando** pulsa "Nueva tarea"
  - **Entonces** se abre el mismo editor de CA-002-01 (color al azar y distinto del de la tarea actual) y, al continuar, la hoja "¿Dónde la pones?" (CA-002-02). Al colocarla (arriba del todo o a la cola):
    - se vuelve al listado con la nueva tarea en su posición;
    - la lista se desplaza hasta ella si no está a la vista (DEV-30);
    - la fila se resalta: la sombra pasa a `listItemFlash` y vuelve a `listItem` en 0,9 s (`listFlash`);
    - el foco queda en la fila nueva (CA-006-17).
  - Cancelar el editor (o el gesto atrás) vuelve al listado sin guardar nada, con el foco en "Nueva tarea". Enmienda CA-002-07 y sustituye a CA-002-08.

**Accesibilidad**

- **CA-006-16 Reordenar sin arrastrar (DEV-14)**
  - **Dado** un lector de pantalla (TalkBack) o acceso por switch
  - **Cuando** abre las acciones de una fila
  - **Entonces** encuentra, en este orden: las de mover que correspondan (CA-006-09), "Editar tarea" y "Eliminar tarea". Mover cambia la posición al instante; "Eliminar tarea" abre la confirmación (nunca elimina directamente).
  - Con teclado físico, se llega con Tab al asa de cada fila y se abre "Mover" con Intro o Espacio (CA-006-08).
- **CA-006-17 Foco y anuncios**
  - **Dado** un lector de pantalla activo
  - **Cuando** ocurre cada acción
  - **Entonces** se hace **un único anuncio** y el foco queda donde dice la tabla (si la hoja se cierra, el anuncio espera a que termine de cerrarse):

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Abrir el listado | Título "Todas las tareas" (encabezado) | El nombre de la pantalla |
    | Mover (sin llegar a la 1) | La tarea movida, en su nueva posición; la lista se desplaza hasta ella | "Movida a la posición {n} de {total}" |
    | Llegar a la posición 1 por cualquier vía (arrastre, "Mover", acción, "Arriba del todo" desde el listado) | La tarea, ya primera | "Ahora es la tarea actual" |
    | Soltar en la misma posición | Sin cambios | Ninguno |
    | Editar: guardar o cancelar | La fila editada | Ninguno |
    | Eliminar una fila que no es la primera | La fila que ocupa su lugar (o la anterior, si era la última de la lista) | "Tarea eliminada. Quedan {count}" |
    | Eliminar la primera | La nueva primera | "Tarea eliminada. Siguiente: {texto}" (como CA-004-11) |
    | Eliminar la única que quedaba | Título "Todo hecho." | "Tarea eliminada. Todo hecho." |
    | Cancelar la confirmación | La fila de origen | Ninguno |
    | Crear "A la cola" (o en otra posición distinta de la 1) | La fila nueva | "Tarea añadida en la posición {n} de {total}" |
    | Volver a la pantalla principal | La tarea actual | Ninguno |
    | Error al mover o al eliminar | Sin cambios | El texto del aviso |

- **CA-006-18 Lectura de las filas**
  - **Dado** un lector de pantalla
  - **Cuando** recorre el listado
  - **Entonces**:
    - el orden de lectura es: título, ayuda, filas en orden, "Nueva tarea", "Volver a la tarea";
    - cada fila es **un único elemento**: "{posición} de {total}: {texto}" (la primera, "1 de {total}. Tarea actual: {texto}"), con la pista "Toca dos veces para editar". Los botones de la fila (asa, Editar, Eliminar) no se leen por separado: sus funciones están en las acciones de la fila (CA-006-16);
    - el lector informa de cuántas filas hay y de cuáles están a la vista;
    - con el lector activo, la ayuda dice "La primera es la que tienes ahora. Usa las acciones de cada tarea para cambiar el orden, editarla o eliminarla." (DEV-33).
  - *[Diferido a 007–009]* Tras el texto, el tipo de adjunto si hay.
- **CA-006-19 Reducir movimiento**
  - **Dado** "reducir movimiento" activado
  - **Cuando** se reordena, se crea o se desplaza la lista por programa
  - **Entonces**:
    - la fila arrastrada sigue al dedo, pero sin inclinación; la sombra cambia sin animación;
    - las demás filas cambian de sitio sin desplazarse animadas;
    - el resaltado de CA-006-15 es la sombra `listItemFlash` fija durante 0,9 s, sin transición;
    - los desplazamientos automáticos (hasta la fila movida o creada) son saltos.

**Rendimiento**

- **CA-006-20 Listado largo**
  - **Dado** 500 tareas pendientes, en el dispositivo Android de referencia (compilación *profile*)
  - **Cuando** abre el listado, lo desplaza de arriba abajo y arrastra una fila
  - **Entonces** el listado se ve completo en < 300 ms desde que se elige "Todas mis tareas", y el percentil 90 del tiempo de fotograma al desplazar y al arrastrar es ≤ 16,7 ms. Abrir la app no carga el listado (P2, CA-001-09).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-006-1 | Listado de 500 tareas | CA-006-20; el desplazamiento automático al arrastrar cerca de los bordes (CA-006-12) permite llegar a cualquier posición |
| CL-006-2 | Se elimina la penúltima y queda una | El listado muestra esa única tarea (primera fila, sin asa) con Editar y Eliminar; "Nueva tarea" sigue disponible |
| CL-006-3 | Se elimina la última desde el listado | "Todo hecho." sin animación (CA-006-14); no existe "Nada pendiente." (DEV-24); el gesto atrás no vuelve al listado |
| CL-006-4 | Soltar en la misma posición | No se escribe nada ni se anuncia nada |
| CL-006-5 | Toques sobre el asa o los botones Editar/Eliminar | Cuentan solo como ese botón: no se suman al doble toque de la fila. Si el segundo toque cae mientras sube la hoja de confirmación, no activa nada de la hoja |
| CL-006-6 | Dos toques en filas distintas en < 350 ms | No abre el editor |
| CL-006-7 | Un toque y, a continuación, un arrastre en la misma fila | Solo arrastra; no abre el editor |
| CL-006-8 | Renumeración de posiciones | Tras 1 000 movimientos alternos entre las mismas dos posiciones, el orden es el esperado y ninguna clave de `rank` supera 50 caracteres (se renumeran en una sola transacción, ADR-0002) |
| CL-006-9 | Segundo plano con el listado abierto | < 10 min: al volver, el mismo listado en la misma posición de desplazamiento; ≥ 10 min: la tarea actual (CA-001-12) |
| CL-006-10 | Texto grande (200 %) en un móvil de 360 dp | Las filas crecen en alto (siguen recortadas a 3 líneas); nada se corta ni se solapa; los botones siguen alcanzables y de ≥ 48 dp. Con la escala de texto ≥ 1,3, la cabecera y la ayuda se desplazan con la lista en lugar de quedarse fijas (DEV-34) |
| CL-006-11 | Texto de 10 000 caracteres en una fila | 3 líneas con "…"; el lector lee el texto completo |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Todo hecho." | Se eliminó la última pendiente desde el listado | CA-006-14, CA-004-07 |
| Error al mover | Fallo de escritura al reordenar | La fila vuelve a su posición anterior y aparece el aviso "No hemos podido mover la tarea" con "Reintentar" (mismo estilo que `deleteError`); "Reintentar" repite el mismo movimiento |
| Error al eliminar | Fallo de escritura al confirmar | CA-004-13, sobre el listado |

## 6. Accesibilidad

- Alternativas a arrastrar: el botón "Mover" en el asa, visible para todos (CA-006-08, WCAG 2.5.7) y las acciones del lector (CA-006-16).
- Alternativa al doble toque: el botón "Editar tarea" y la activación de la fila con el lector (CA-006-13).
- Foco, anuncios y lectura: CA-006-17 y CA-006-18. Cada fila es un solo elemento para el lector (una parada por fila).
- Reducir movimiento: CA-006-19. Texto grande: CL-006-10 (DEV-34).
- Objetivos táctiles: asa, "Editar tarea", "Eliminar tarea" y "Volver a la tarea", ≥ 48 × 48 dp en Android (44 pt en iOS); "Nueva tarea", 64 de alto como el prototipo.
- La tarea actual no se distingue solo por el aspecto: la ayuda lo dice ("La primera es la que tienes ahora") y el lector la lee como "Tarea actual".
- Contraste: `ink` sobre todos los colores de nota (clásica y neón) ya cumple AA; los iconos de la fila van en `ink`. El anillo de foco del teclado no se recorta por el borde de la fila ni por los márgenes de la lista.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `listTitle` | Todas las tareas | All tasks | Título y nombre de la pantalla |
| `listBack` | Volver a la tarea | Back to the task | Nombre accesible del botón con flecha |
| `listHelp` | La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla. | The first one is the one you have now. Drag another above it to take its place. Double-tap a task to edit it. | |
| `listHelpScreenReader` | La primera es la que tienes ahora. Usa las acciones de cada tarea para cambiar el orden, editarla o eliminarla. | The first one is the one you have now. Use each task's actions to change the order, edit it or delete it. | Con lector activo (DEV-33) |
| `listEdit` | Editar tarea | Edit task | Botón de la fila y acción del lector. Clave propia: contexto distinto de `editorTagEdit` |
| `listEditHint` | editar | edit | Pista de activación de la fila ("Toca dos veces para editar") |
| `listNewTask` | Nueva tarea | New task | Clave propia: contexto distinto de `menuNewTask` |
| `listMove` | Mover tarea | Move task | Nombre del asa y etiqueta de la hoja "Mover" |
| `listMakeCurrent` | Hacer actual | Make current | |
| `listMoveUp` | Mover arriba | Move up | |
| `listMoveDown` | Mover abajo | Move down | |
| `listMoveError` | No hemos podido mover la tarea | We couldn't move the task | Con `retry` |
| `a11yRowPosition` | {position} de {total}: {text} | {position} of {total}: {text} | Filas 2…N |
| `a11yRowCurrent` | 1 de {total}. Tarea actual: {text} | 1 of {total}. Current task: {text} | Primera fila |
| `a11yMovedTo` | Movida a la posición {position} de {total} | Moved to position {position} of {total} | |
| `a11yNowCurrent` | Ahora es la tarea actual | It's now the current task | |
| `a11yAddedAt` | Tarea añadida en la posición {position} de {total} | Task added at position {position} of {total} | Crear desde el listado |
| `a11yDeletedFromList` | {count, plural, =1{Tarea eliminada. Queda 1} other{Tarea eliminada. Quedan {count}}} | {count, plural, =1{Task deleted. 1 left} other{Task deleted. {count} left}} | Eliminar una fila que no es la primera |

Se reutilizan `deleteA11yAction` ("Eliminar tarea": botón de la fila y acción del lector), `a11yDeletedNext`, `a11yDeletedAllDone`, `deleteError`, `retry`, `menuClose` (X de la hoja "Mover") y los textos de las specs 002, 004 y 005. **No** se añaden `listUpNext` ("Lo siguiente" no se muestra) ni `listDelete` (sería `deleteA11yAction`). *[Diferido a 007–009]* La insignia "WEB", el texto para documentos sin extensión y el tipo de adjunto en la lectura de la fila.

## 8. Fuera de alcance

- Agrupación por fecha (Bloque 1), completar desde el listado, selección múltiple, búsqueda.
- La etiqueta visible "Lo siguiente" (oculta en el prototipo; decisión del propietario, 2026-09-26).
- Atajos de teclado para mover (p. ej. Alt+↑/↓): el teclado usa el botón "Mover" (CA-006-16).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-26, propietario]** "Lo siguiente" oculto, como el prototipo.
- **[Resuelto 2026-09-26, propietario]** Arrastre: al instante desde el asa y con pulsación larga desde el resto de la fila (DEV-27).
- **[Resuelto 2026-09-26, propietario]** Alternativa visible a arrastrar: tocar el asa abre "Mover" (DEV-28).
- **[Resuelto 2026-09-26, propietario]** Textos largos: 3 líneas con "…" (DEV-29).
- **[Resuelto 2026-09-26, propietario, con la recomendación de la revisión]** Una parada por fila para el lector, activarla edita, foco inicial en el título, el foco sigue a la tarea movida, anuncios de CA-006-17, desplazarse y resaltar tras crear (DEV-30), desplazamiento automático (DEV-31), arrastre interrumpido sin guardar (DEV-32), error al mover con "Reintentar", ayuda distinta con lector (DEV-33) y cabecera desplazable con texto grande (DEV-34).
