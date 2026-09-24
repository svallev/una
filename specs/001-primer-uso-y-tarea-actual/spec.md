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
  - **Entonces** se ve como el prototipo: el logotipo arriba, el campo de texto **centrado** en la nota (del mismo color que la bienvenida) con el foco y el teclado abierto, el placeholder "¿Qué es eso que tienes que hacer y no has hecho?" y, abajo, el botón cuadrado "+" a la izquierda y "Guardar →" a la derecha, **ambos activos y con sombra**. La etiqueta "Tu primera tarea" **no se ve**: es el nombre accesible del campo. **No** aparece "Cancelar" ni el acceso al menú.
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
  - **Entonces** se ve **solo** la primera tarea pendiente (según el orden de la cola), como nota adhesiva a pantalla completa con su color, el logotipo arriba a la izquierda, el botón de menú arriba a la derecha y el botón "Pulsa para completar" abajo, en una sola línea. No se muestra ni número ni vista previa de otras tareas.
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
| CL-001-1 | Texto solo con espacios o saltos de línea | "Guardar" no guarda nada y devuelve el foco al campo (el botón nunca se ve desactivado) |
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
| Error de almacenamiento | La BD no abre | Pantalla "No hemos podido abrir tus tareas" + "Reintentar"; si es por falta de espacio: "Tu teléfono no tiene espacio libre" |
| Error al guardar | No se puede escribir la tarea | Aviso "No hemos podido guardar la tarea" (o el de falta de espacio) con "Reintentar"; el texto escrito se conserva |

(Los estados "Todo hecho." y "Nada pendiente." se definen en las specs 003 y 004.)

## 6. Accesibilidad

- La bienvenida se anuncia como un único texto completo ("Ya puedes crear tu primera tarea"), no letra a letra; con **reducir movimiento**, el texto aparece de golpe y el paso al editor es un fundido de 400 ms.
- Se puede saltar la bienvenida con un toque o con la tecla Intro/Espacio (y con la acción por defecto del lector de pantalla, que se anuncia como "Toca dos veces para continuar"). **Con el lector de pantalla activo la bienvenida no avanza sola**: espera a que el usuario la salte, para no cortar la lectura.
- Todo lo que se pulsa se alcanza con teclado e interruptores y muestra el anillo de foco del prototipo (3 px `ink`, desplazado 3 px).
- El contador de caracteres se anuncia al aparecer (9 000) y al llegar al máximo.
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
| `completeButton` | Pulsa para completar | Press to complete | Una sola línea; texto del prototipo (DEV-06 revocada); comportamiento en la spec 003 |
| `storageErrorTitle` | No hemos podido abrir tus tareas | We couldn't open your tasks | |
| `storageErrorNoSpace` | Tu teléfono no tiene espacio libre | Your phone is out of storage | |
| `retry` | Reintentar | Try again | |
| `skipIntroHint` | continuar | continue | Acción del lector: "Toca dos veces para continuar" |
| `editorSaveError` | No hemos podido guardar la tarea | We couldn't save your task | §5 |
| `webPreviewBanner` | Versión de pruebas · los datos se borran al recargar | Test version · data is erased when you reload | Solo en la web de pruebas (ADR-0010) |

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

## 11. Ajustes durante la implementación (aprobados por el propietario el 2026-09-24)

Salen de las revisiones de cierre (subagentes `spec-reviewer`, `a11y-reviewer` y `security-reviewer`). No cambian ningún CA; concretan accesibilidad y errores:

- §5: nueva fila "Error al guardar" (antes la BD que no escribe mostraba el mensaje de "no hemos podido abrir").
- §6: la bienvenida no avanza sola con lector de pantalla; foco visible y teclado en todos los botones; anuncio del contador.
- §7: textos `skipIntroHint` y `editorSaveError`.
- CL-001-4: el primer uso se marca al **mostrarse** la bienvenida (antes, al terminar), para que al matar la app a mitad se abra el editor.
- Privacidad (decisión del propietario): el teclado del sistema **no aprende** del texto de las tareas (`enableIMEPersonalizedLearning: false`; en Android, `IME_FLAG_NO_PERSONALIZED_LEARNING`).
- Texto del botón de completar (decisión del propietario): **"Pulsa para completar"** en una sola línea, como en el prototipo. Se revoca DEV-06.
- CA-001-07 (hallado con los goldens): si la palabra más larga no cabe en una línea, el tamaño de la nota se reduce lo justo (sin bajar de `noteS`) para no partirla; por debajo de `noteS`, las palabras enormes se parten (CL-001-3).
- Fidelidad al prototipo (decisión del propietario, 2026-09-25): editor sin etiqueta visible y con el texto centrado; botones "+" y "Guardar →" (alineado a la derecha); la bienvenida con el color de la primera nota, texto de 52 px centrado y cursor de bloque; las notas sin marco; iconos del sistema de diseño (trazos SVG del prototipo, `UnaIcons`), no los de Material. **Ningún botón se ve desactivado**: "+" (specs 007–009), el menú (005) y completar (003) aún no hacen nada hasta sus specs.

