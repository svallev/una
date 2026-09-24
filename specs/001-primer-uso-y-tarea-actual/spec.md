# Spec 001: Primer uso y tarea actual

- **Estado:** Aprobada (2026-09-24)
- **Reglas de producto:** R1, R2, R6, R8 (y R3 solo para texto; los adjuntos, en 007–009)
- **Pantallas del prototipo:** 0 "Prototipo (empieza vacío)", 1 "La tarea", 3 "Nueva tarea" (variante "Tu primera tarea")
- **Decisiones y ADR:** P1, P2, P7; ADR-0001, 0002; DEV-06, DEV-07, DEV-08
- **Dependencias:** ninguna (es la primera funcionalidad y arrastra el esqueleto técnico)

## 1. Objetivo

Que alguien que abre la app por primera vez cree su primera tarea en segundos y que, a partir de entonces, **cada vez que abra la app vea al instante su tarea actual y nada más**.

## 2. Historias de usuario

- **HU-001-1** Como persona que acaba de instalar la app, quiero que me lleve directamente a crear mi primera tarea para empezar sin tutoriales.
- **HU-001-2** Como usuario, quiero que al abrir la app lo primero que vea sea mi tarea actual, a pantalla completa y sin esperar, para centrarme en ella.
- **HU-001-3** Como usuario, quiero ver solo esa tarea para no distraerme con el resto.

## 3. Criterios de aceptación

**Primera vez (R1, R2)**

- **CA-001-01 Bienvenida**
  - **Dado** que la app se abre por primera vez (no hay tareas ni se ha completado el primer uso)
  - **Cuando** termina de cargar
  - **Entonces** se muestra el logotipo y el texto "Ya puedes crear tu primera tarea" escribiéndose letra a letra; al terminar, y tras una pausa de ~1 s, la pantalla se funde con el editor.
- **CA-001-02 Editor de la primera tarea**
  - **Dado** que ha terminado la bienvenida
  - **Cuando** aparece el editor
  - **Entonces** muestra la etiqueta "Tu primera tarea", el campo de texto con el foco y el teclado abierto, el placeholder "¿Qué es eso que tienes que hacer y no has hecho?" y el botón "Guardar" deshabilitado; **no** aparece "Cancelar" ni el acceso al menú.
- **CA-001-03 Nada más hasta crearla (R2)**
  - **Dado** que no existe ninguna tarea
  - **Cuando** el usuario intenta salir del editor (gesto atrás de Android, deslizar para cerrar o reabrir la app)
  - **Entonces** sigue en el editor de la primera tarea (el gesto atrás de Android cierra la app, que al reabrirse vuelve al editor, sin repetir la bienvenida si ya se vio).
- **CA-001-04 Guardar la primera tarea**
  - **Dado** el editor de la primera tarea con un texto no vacío (tras recortar espacios)
  - **Cuando** pulsa "Guardar"
  - **Entonces** la tarea se guarda como pendiente, pasa a ser la **tarea actual** y se muestra en la pantalla principal **sin** preguntar dónde va.
- **CA-001-05 Bienvenida una sola vez**
  - **Dado** que ya se vio la bienvenida (aunque no se guardara ninguna tarea)
  - **Cuando** se reabre la app sin tareas
  - **Entonces** se abre directamente el editor de la primera tarea, sin animación.

**Pantalla principal (R6)**

- **CA-001-06 Solo una tarea**
  - **Dado** que hay una o más tareas pendientes
  - **Cuando** se muestra la pantalla principal
  - **Entonces** se ve **solo** la primera tarea pendiente (según el orden de la cola), como nota adhesiva a pantalla completa con su color, el logotipo arriba a la izquierda, el botón de menú arriba a la derecha y el botón "Mantén pulsado para completar" abajo. No se muestra ni número ni vista previa de otras tareas.
- **CA-001-07 Tamaño del texto**
  - **Dado** una tarea de texto
  - **Cuando** se muestra
  - **Entonces** el tamaño base depende de la longitud (< 40 caracteres: 50; < 90: 40; < 160: 31; resto: 26) multiplicado por la escala de texto del sistema (límite ×1,6), y si no cabe se puede desplazar verticalmente sin cortar palabras.
- **CA-001-08 Color de la nota**
  - **Dado** que se crea una tarea
  - **Cuando** se le asigna color
  - **Entonces** recibe uno de los 5 colores de la paleta, distinto del de la tarea actual en ese momento, y lo conserva siempre (también tras reordenar o reiniciar).

**Volver a abrir (R8)**

- **CA-001-09 Arranque en frío**
  - **Dado** que existe al menos una tarea pendiente y la app no está en memoria
  - **Cuando** el usuario abre la app
  - **Entonces** lo primero que ve tras la pantalla de lanzamiento es la tarea actual, sin animaciones de entrada que la retrasen, en **< 1 s (p50)** en el dispositivo Android de referencia (compilación *release*).
- **CA-001-10 Persistencia**
  - **Dado** que el usuario creó tareas
  - **Cuando** cierra la app (o el sistema la mata) y la reabre, incluso en modo avión
  - **Entonces** las tareas, su orden y sus colores siguen igual.
- **CA-001-11 Sin conexión**
  - **Dado** que el dispositivo está en modo avión desde la instalación
  - **Cuando** se usa toda esta funcionalidad
  - **Entonces** funciona igual y no se intenta ninguna conexión de red.

## 4. Casos límite

| ID | Situación | Comportamiento esperado |
|---|---|---|
| CL-001-1 | Texto solo con espacios o saltos de línea | "Guardar" sigue deshabilitado |
| CL-001-2 | Texto de 10 000 caracteres (máximo) | Se acepta; no se pueden escribir más (contador visible a partir de 9 000); la nota se desplaza |
| CL-001-3 | Emojis, RTL, CJK, texto sin espacios (URL larga pegada) | Se muestra sin desbordar; las palabras largas se parten |
| CL-001-4 | La app se mata durante la bienvenida | Al reabrir, se abre el editor (CA-001-05) |
| CL-001-5 | La app se mata mientras se escribe la primera tarea | Al reabrir, editor vacío (el borrador no se guarda en la v1; P-1 resuelto) |
| CL-001-6 | Fallo al abrir la BD (corrupta o sin espacio) | Pantalla de error recuperable (ver §5); nunca se pierde la BD de forma silenciosa |
| CL-001-7 | Rotación o pantallas grandes (tablet, plegable) | Solo vertical en la v1 (iPad/tablet: centrado a 390–600 pt de ancho) |
| CL-001-8 | Cambio de idioma del sistema con la app abierta | Los textos se actualizan al volver a la app |
| CL-001-9 | Tamaño de texto del sistema máximo (AX5 / 200 %) | Todo sigue siendo usable; los botones crecen en alto y el texto no se corta |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| Sin tareas y primer uso completado | Nunca en la pantalla principal: se va al editor | — |
| Error de almacenamiento | La BD no abre o no se puede escribir | "No hemos podido abrir tus tareas" + "Reintentar"; si es por falta de espacio: "Tu teléfono no tiene espacio libre" |

(Los estados "Todo hecho." y "Nada pendiente." se definen en las specs 003 y 004.)

## 6. Accesibilidad

- La bienvenida se anuncia como un único texto completo ("Ya puedes crear tu primera tarea"), no letra a letra; con **reducir movimiento**, el texto aparece de golpe y el paso al editor es un fundido de 400 ms.
- Se puede saltar la bienvenida con un toque o con la tecla Intro/Espacio (y con la acción por defecto del lector de pantalla).
- La tarea actual se anuncia como "Tarea actual: {texto}". El logotipo es decorativo (excluido de la semántica). El botón de menú: "Menú de la tarea".
- Orden de foco: tarea → menú → completar.
- Contraste: texto `ink` sobre cualquier color de nota ≥ 9,8:1.
- Objetivos táctiles ≥ 44 × 44 pt.
- Al abrir el editor, el foco va al campo de texto y se anuncia la etiqueta "Tu primera tarea".

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `appName` | Una. | Una. | Centralizado; también en el logotipo |
| `welcomeTitle` | Ya puedes crear tu primera tarea | You can now create your first task | Máquina de escribir |
| `editorTagFirst` | Tu primera tarea | Your first task | |
| `editorPlaceholder` | ¿Qué es eso que tienes que hacer y no has hecho? | What's that thing you need to do and haven't done yet? | DEV-07 |
| `editorSaveFirst` | Guardar | Save | |
| `editorCharsLeft` | {count, plural, =1{Queda 1 carácter} other{Quedan {count} caracteres}} | {count, plural, =1{1 character left} other{{count} characters left}} | A partir de 9 000 |
| `currentTaskSemantics` | Tarea actual: {text} | Current task: {text} | Lector de pantalla |
| `menuButton` | Menú de la tarea | Task menu | |
| `completeButton` | Mantén pulsado para completar | Press and hold to complete | DEV-06; comportamiento en la spec 003 |
| `storageErrorTitle` | No hemos podido abrir tus tareas | We couldn't open your tasks | |
| `storageErrorNoSpace` | Tu teléfono no tiene espacio libre | Your phone is out of storage | |
| `retry` | Reintentar | Try again | |

## 8. Fuera de alcance

Posición de las tareas nuevas (002), completar (003), menú (005), adjuntos (007–009), Configuración (010).

## 9. Preguntas abiertas

- **P-1 (resuelto 2026-09-24):** el borrador del editor **no** se guarda en la v1.
- **P-2 (resuelto 2026-09-24):** al volver desde segundo plano se conserva la pantalla en la que estaba el usuario si pasaron **menos de 10 minutos**; si pasaron más, se muestra la tarea actual (se descarta lo que hubiera en el editor).

## 10. Criterio añadido al aprobar

- **CA-001-12 Vuelta desde segundo plano (P-2)**
  - **Dado** que la app pasó a segundo plano
  - **Cuando** vuelve a primer plano
  - **Entonces** si pasaron menos de 10 minutos se ve la misma pantalla; si pasaron 10 minutos o más, se ve la tarea actual (o el editor de la primera tarea si no hay ninguna).
