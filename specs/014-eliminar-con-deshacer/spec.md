# Spec 014: Eliminar con deshacer

- **Estado:** **Aprobada** (propietario, 2026-10-04), con el ADR-0021 aceptado y las enmiendas del §10 ya aplicadas. Revisada ese día por `spec-reviewer` y `a11y-reviewer`; sus hallazgos y las respuestas del propietario están aplicados (§9)
- **Fase:** F4b Nuevas funcionalidades (plan aprobado por el propietario el 2026-10-04). Es la primera de las specs 014–019.
- **Reglas de producto:** R10 (eliminar, ahora sin confirmación y con deshacer), R16 (deshacer al eliminar), R12 (estado vacío "Todo hecho."), R13 (eliminar desde el listado)
- **Pantallas del prototipo:** 12 "Eliminar con deshacer: la tarea" (`Deshacer.dc.html`; el tablero 6 `Eliminar.dc.html` es idéntico), 13 "Eliminar con deshacer: desde la lista" (`DeshacerLista.dc.html`) y 8 "Eliminar (se arruga)" (sin cambios). Ver `docs/design/screen-map.md`.
- **Decisiones y ADR relacionados:**
  - **D20** (propietario, 2026-10-04): deshacer de **4 s**; una eliminación nueva sustituye a la card anterior; el foco del lector va a "Deshacer"; se alarga con el tiempo de accesibilidad del sistema y no caduca mientras el foco del lector está en "Deshacer"; la hacen definitiva antes otro borrado, completar, crear o editar, abrir Ajustes y pasar a segundo plano. **Enmienda del propietario (2026-10-04, al revisar esta spec):** ir a otra pantalla mientras se ve la card la hace definitiva: «Si durante el deshacer vas a otra pantalla, la card desaparece. Eso es que no querías deshacer». Sustituye a la respuesta P-4 del plan F4b en lo del listado (P-4 decía que abrir el listado o el menú no la hacían definitiva; no es la P-4 de la spec 003).
  - **D7** (enmendada por el plan F4b): sin confirmación y con deshacer; pasado el tiempo, definitivo y sin dejar nada. Sigue sin haber "Nada pendiente." (DEV-24).
  - **ADR-0021** (Aceptado, 2026-10-04): eliminar en dos tiempos. Sustituye al **ADR-0012** solo en el momento del borrado; lo demás del ADR-0012 sigue (sin histórico, no queda nada).
  - **Completar sigue sin deshacer** (P-4 de la spec 003).
  - DEV-51 (nueva: la duración y el tiempo de accesibilidad); DEV-09, DEV-10 y DEV-23 quedan obsoletas; DEV-24, DEV-25 y DEV-26 siguen.
  - ADR-0020 (voz del sistema en los anuncios y las acciones del lector).
- **Dependencias:** 001, 003 (animación, bloqueo e "Todo hecho."), 004 (arrugado), 005 (menú), 006 (listado), 007–009 (etiquetas y adjuntos), 012 ("Configuración y perfil", que hace de Ajustes hasta la spec 015). Sin esquema de BD nuevo, sin permisos ni dependencias nuevas **[Suposición]** (lo propone el ADR-0021).
- **Enmiendas a otras specs y documentos:** en el §10, aplicadas al aprobarla (2026-10-04).

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md` y en el ADR-0021; las notas técnicas van solo en el anexo, que no es normativo.

## 1. Objetivo

Eliminar una tarea con un solo paso, sin preguntar, y poder arrepentirse durante unos segundos. Hoy la única red de seguridad es una hoja de confirmación que se interpone cada vez. Con esta spec, la red pasa a estar **después**: la tarea se va al momento y una card negra deja recuperarla durante 4 s. Pasado ese tiempo, la eliminación es definitiva y no queda nada (ADR-0012).

## 2. Historias de usuario

- **HU-014-1** Como usuario, quiero eliminar una tarea sin que me pregunten, porque casi siempre lo hago a propósito.
- **HU-014-2** Como usuario, quiero poder recuperar una tarea que he eliminado sin querer, en el mismo sitio y tal como estaba.
- **HU-014-3** Como usuario de lector de pantalla, switch o teclado, quiero tener tiempo suficiente para deshacer y saber qué he eliminado.

## 3. Criterios de aceptación

**Eliminar sin confirmación**

- **CA-014-01 Eliminar la tarea actual**
  - **Dado** la tarea actual
  - **Cuando** el usuario elige "Eliminar" en el menú, usa la acción del lector "Eliminar tarea" (CA-014-19) o pulsa "Eliminar tarea" en la tarjeta "Adjunto no disponible" (CA-007-19)
  - **Entonces**:
    - **no** aparece ninguna confirmación: la hoja "¿Eliminar esta tarea?" deja de existir en toda la app;
    - el menú se cierra (si estaba abierto) y la eliminación se guarda **antes** de empezar la animación (como CA-004-03): la tarea sale de la cola al momento;
    - la nota se arruga y cae en la papelera exactamente como en CA-004-04 (detrás, la siguiente tarea o "Todo hecho.", DEV-26), con el bloqueo de CA-004-05: mientras dura, nada de la pantalla responde, tampoco la tarjeta "Adjunto no disponible" de la tarea que se ve detrás;
    - al terminar la animación aparece la card de deshacer (CA-014-03).
- **CA-014-02 Eliminar desde el listado**
  - **Dado** el listado
  - **Cuando** pulsa "Eliminar tarea" en cualquier fila (o usa esa acción del lector)
  - **Entonces**:
    - no hay confirmación; la eliminación se guarda al momento;
    - como hoy (CA-006-14), la fila desaparece **sin animación** y las de debajo suben; si era la primera, la siguiente pasa a ser la actual (aspecto de primera fila, sin asa);
    - si era la última pendiente, se va directamente a "Todo hecho." (sin animación);
    - la card de deshacer aparece a la vez, sobre el listado (o sobre "Todo hecho.").

**La card de deshacer**

- **CA-014-03 Aspecto (tableros 12 y 13)**
  - **Dado** una tarea recién eliminada
  - **Cuando** aparece la card
  - **Entonces**, como en el prototipo:
    - es una franja negra (`ink`) pegada abajo, a todo el ancho, que entra subiendo 24 px y fundiéndose en 0,22 s;
    - lleva el icono de la papelera, "Tarea eliminada" (Archivo 17, extranegrita, en blanco) y, debajo, la etiqueta de la tarea (Space Mono 11, gris claro, **en una sola línea con "…"**);
    - a la derecha, el botón "Deshacer" con su icono (borde blanco de 2 px, texto blanco; se ve de 44 de alto, como el prototipo, y su zona táctil mide ≥ 48 dp);
    - abajo del todo, una barra de tiempo de 6 px del **color de la nota eliminada**, sobre una pista gris oscura, que se vacía de derecha a izquierda, de forma lineal, durante todo el tiempo de la card (CA-014-06).
- **CA-014-04 Etiqueta**
  - **Dado** la card
  - **Cuando** se muestra
  - **Entonces** la etiqueta es el texto de la tarea, con los saltos de línea como espacios; si no tiene texto, la misma que usaba la confirmación: "Foto" o "Imagen" (CA-007-20), el nombre del PDF (spec 008) o el dominio (CA-009-14).
- **CA-014-05 Qué se oculta mientras se ve**
  - **Dado** la card visible
  - **Cuando** se mira la pantalla de debajo
  - **Entonces** se ocultan el botón que ocupa ese sitio y vuelven a verse cuando la card desaparece:
    - "Pulsa para completar", en la pantalla principal;
    - "Nueva tarea", en el listado;
    - "Crear una tarea", en "Todo hecho." (el prototipo solo lo tapa con la card; DEV-51).
  - El logotipo, el botón de menú, la tarea y las filas del listado siguen como siempre.
  - Nada que pueda recibir el foco queda del todo tapado por la card (WCAG 2.4.11): lo que se desplaza (el listado, el PDF) deja abajo el sitio de la card, y la fila o el elemento con el foco se desplaza por encima de ella.
- **CA-014-06 Duración y final**
  - **Dado** la card visible
  - **Cuando** pasan **4 s** desde que apareció
  - **Entonces** desaparece de golpe, sin animación, los botones ocultos vuelven a verse y la eliminación es **definitiva** (CA-014-15).
  - Si el sistema tiene configurado un tiempo para actuar mayor (ajuste de accesibilidad de Android "Tiempo para actuar"), la card dura ese tiempo y la barra se vacía en él (DEV-51; WCAG 2.2.1).
  - El sistema no tiene "Tiempo para actuar" en Android 8 y 9: ahí la card dura 4 s, salvo con un servicio de accesibilidad activo (lector, Switch Access…), con el que dura **10 s** (propietario, 2026-10-04; excepción a P6 por WCAG 2.2.1, §6).
  - La duración no cambia con "reducir movimiento" ni con "Quitar animaciones" del sistema.
  - El prototipo dice 3 s (y "5 s" en un comentario): mandan los 4 s (D20).
- **CA-014-07 La card es de su pantalla**
  - **Dado** la card visible
  - **Cuando** el usuario va a otra pantalla (CA-014-11) o abre una hoja sobre la misma
  - **Entonces**:
    - si va a otra pantalla, la card desaparece y la eliminación es definitiva: "eso es que no querías deshacer" (propietario);
    - una hoja (el menú, "Mover", la confirmación de un enlace del PDF…) no es otra pantalla: la card queda debajo de ella, no se puede pulsar y su tiempo sigue corriendo; si caduca mientras tanto, al cerrar la hoja ya no está (propietario, 2026-10-04).
- **CA-014-08 Varias eliminaciones seguidas**
  - **Dado** la card de una tarea A visible
  - **Cuando** se elimina otra tarea B
  - **Entonces** la eliminación de A pasa a ser definitiva en ese momento y:
    - desde el listado: la card se queda y cambia al texto y al color de B, y la barra vuelve a empezar llena (sin volver a entrar); el foco del lector (y el del teclado, si se usa) vuelve a la card, que se lee con la etiqueta de B, y el tiempo se cuenta de nuevo como en CA-014-17;
    - desde la pantalla principal: la card de A desaparece al empezar el arrugado de B (el prototipo la deja hasta que acaba; DEV-51) y, al terminar, aparece la de B.
  - Solo se puede deshacer la última eliminación.

**Deshacer**

- **CA-014-09 Recuperar la tarea**
  - **Dado** la card visible
  - **Cuando** pulsa "Deshacer"
  - **Entonces**:
    - la card desaparece y los botones ocultos vuelven a verse;
    - la tarea vuelve a la cola **en la misma posición** que tenía al eliminarla (la cola no ha podido cambiar entre medias: crear, editar, eliminar, completar y reordenar la hacen definitiva, CA-014-11), con su texto, su color y su adjunto tal como estaban: la imagen con sus versiones, el PDF con su última posición (spec 008) o la web con su dirección guardada;
    - no cuenta como tarea nueva: no aparece "¿Dónde la pones?", no se anuncia "Tarea añadida…" y conserva su color;
    - si vuelve a la posición 1, pasa a ser otra vez la tarea actual (la que lo era pasa a la 2).
- **CA-014-10 Dónde se queda el usuario**
  - **Dado** que se ha pulsado "Deshacer"
  - **Cuando** la tarea vuelve
  - **Entonces** el usuario sigue en la pantalla en la que eliminó, que es donde está la card (CA-014-07):
    - en la pantalla principal, se ve otra vez la tarea recuperada como actual, sin animación;
    - en el listado, la fila reaparece en su sitio, la lista se desplaza hasta ella si no está a la vista y se resalta como al crear (sombra `listItemFlash` que vuelve a `listItem` en 0,9 s, CA-006-15; con reducir movimiento, como CA-006-19);
    - en "Todo hecho." (se eliminó la última pendiente), se vuelve a la pantalla de la que se venía, como en el prototipo: "si deshaces es porque lo has hecho sin querer" (propietario, 2026-10-04). A la pantalla principal, con la tarea recuperada como actual, o al listado, con su fila resaltada como en el punto anterior.

**Cuándo es definitiva**

- **CA-014-11 Antes de tiempo**
  - **Dado** una eliminación que aún se puede deshacer (durante el arrugado o con la card visible)
  - **Cuando** ocurre cualquiera de estas cosas (durante el arrugado solo puede pasar la última, CA-014-01):
    - se elimina otra tarea (CA-014-08);
    - se completa una tarea (con el botón oculto, solo con la acción del lector "Completar tarea");
    - se va a otra pantalla (CA-014-07): el listado desde el menú, la pantalla principal desde el listado (con "Volver a la tarea" o el gesto atrás), el editor para crear o para editar (aunque luego se cancele) o "Configuración y perfil" (Ajustes desde la spec 015);
    - se edita sin ir a otra pantalla: la hoja "Cargar URL" de una tarea web o "Quitar adjunto" en "Adjunto no disponible";
    - se reordena: al levantar una fila para arrastrarla o al elegir una opción de mover (hoja "Mover" o acción del lector). "Es una interacción que indica que ya no quiero deshacer" (propietario, 2026-10-04);
    - la app pasa a segundo plano: otra app delante, la pantalla de inicio, "Recientes", la pantalla apagada o bloqueada, o el navegador al abrir un enlace;
  - **Entonces** la card desaparece en ese momento, sin animación (o ya no llega a aparecer), y la eliminación es definitiva: ya no se puede deshacer, ni al volver.
- **CA-014-12 Lo que no la hace definitiva**
  - **Dado** la card visible
  - **Cuando** el usuario hace cualquier cosa que no esté en CA-014-11, por ejemplo:
    - abrir o cerrar el menú o la hoja "Mover" sin elegir nada (CA-014-07);
    - desplazar la lista, desplazar o ampliar la imagen o el PDF, cambiar de página, abrir la confirmación de un enlace;
    - girar el móvil, bajar la cortina de notificaciones o que aparezca un diálogo del sistema sobre la app;
  - **Entonces** la card sigue y el tiempo sigue corriendo.
- **CA-014-13 La app muere**
  - **Dado** una tarea eliminada que aún se podía deshacer (durante el arrugado o con la card visible)
  - **Cuando** el sistema mata la app o se cierra a la fuerza
  - **Entonces** la eliminación es definitiva: al abrirla de nuevo se ve la tarea actual que corresponda (o "Todo hecho."), sin card, y sus archivos se borran en ese arranque después del primer fotograma, sin retrasar CA-001-09 (como CA-007-16).

**Datos**

- **CA-014-14 Fuera de la cola desde el primer momento**
  - **Dado** una tarea eliminada que aún se puede deshacer
  - **Cuando** se consulta cualquier parte de la app
  - **Entonces** la tarea ya no está: ni en la pantalla principal, ni en el listado, ni en el número de "Todas mis tareas" (CA-005-12); con una sola pendiente, "Todas mis tareas" queda deshabilitado (CA-005-03).
- **CA-014-15 Definitiva: no queda nada**
  - **Dado** una eliminación que ha pasado a ser definitiva (por tiempo, antes de tiempo o porque la app murió)
  - **Cuando** se consultan la BD y el almacenamiento de la app
  - **Entonces** no queda nada de la tarea: ni fila, ni adjunto, ni archivos (como CA-004-09 tras el ADR-0012, y CA-007-16). Sus archivos solo siguen en el disco mientras se puede deshacer; si su borrado falla, los recoge el barrido del siguiente arranque.

**Accesibilidad**

- **CA-014-16 Foco y lectura al eliminar**
  - **Dado** un lector de pantalla activo
  - **Cuando** se elimina una tarea
  - **Entonces**:
    - mientras se arruga, el lector no lee la tarea que se va ni anuncia nada;
    - al aparecer la card, el foco del lector **llega a ella**, también cuando al terminar el arrugado se vuelve a montar la pantalla de debajo: mientras se ve, la card es lo primero en el orden de lectura;
    - la card es un solo elemento con papel de botón y se lee **una sola vez**: «Deshacer. Tarea eliminada: {etiqueta}» (la etiqueta, completa);
    - la card no se anuncia sola (no es una región en vivo, a diferencia del prototipo): solo se lee al recibir el foco;
    - no hay más anuncios: sustituye a "Tarea eliminada. Siguiente: …", "Tarea eliminada. Todo hecho." y "Tarea eliminada. Quedan …" (CA-004-11 y CA-006-17).
- **CA-014-17 No caduca mientras tiene el foco**
  - **Dado** la card visible y un lector de pantalla activo (o un teclado físico en uso)
  - **Cuando** aparece la card y mientras el foco del lector (o el del teclado) está en ella
  - **Entonces**:
    - con el lector activo, el tiempo no empieza a correr hasta que la card ha recibido su foco una vez;
    - mientras el foco está en la card, el tiempo no corre (la barra se detiene);
    - cuando el foco sale, sigue desde donde se quedó.
- **CA-014-18 Deshacer con el lector**
  - **Dado** el foco del lector en la card
  - **Cuando** la activa (doble toque)
  - **Entonces** se recupera la tarea (CA-014-09), se hace **un único anuncio**, "Tarea recuperada", cuando la pantalla de destino ya se ve (para que no lo corte el cambio de pantalla), y el foco pasa:
    - en la pantalla principal (también al volver a ella desde "Todo hecho."), a la tarea actual, que es la recuperada si ha vuelto a ser la primera;
    - en el listado (también al volver a él desde "Todo hecho."), a la fila recuperada, no al título de la pantalla.
- **CA-014-19 La acción "Eliminar tarea" elimina**
  - **Dado** un lector de pantalla o acceso por switch
  - **Cuando** invoca la acción "Eliminar tarea" sobre la tarea actual (en vertical y en horizontal, specs 007–009) o sobre una fila del listado (CA-006-16, mismo orden de acciones)
  - **Entonces** elimina directamente, sin hoja, como CA-014-01 y CA-014-02. Enmienda CA-004-10 ("nunca elimina directamente") y CA-006-16.
- **CA-014-20 Teclado y switch**
  - **Dado** un teclado físico o acceso por switch
  - **Cuando** aparece la card
  - **Entonces**:
    - con un teclado físico en uso, el foco del teclado pasa a "Deshacer" (CA-014-17); con la pantalla táctil, no;
    - "Deshacer" tiene un anillo de foco que se ve sobre el negro de la card y se activa con Intro o Espacio (o con el switch); Esc no hace nada en la card;
    - tras deshacer, el foco del teclado queda donde el del lector (CA-014-18);
    - en el orden de Tab, la card ocupa el lugar del botón que oculta (CA-014-05); en el del lector, va la primera (CA-014-16);
    - si la card desaparece con el foco del teclado en ella (CA-014-11), el foco pasa a la tarea actual (o al título "Todo hecho.") o, en el listado, a la fila que ocupa el lugar de la eliminada (o a la anterior, si era la última).
- **CA-014-21 Reducir movimiento**
  - **Dado** "reducir movimiento" activado
  - **Cuando** se elimina una tarea
  - **Entonces** la tarea actual se desvanece en 0,6 s sin arrugarse (CA-004-12), la card aparece sin desplazarse (solo el fundido) y la barra de tiempo se sigue vaciando (es la única señal visual del tiempo que queda y no se mueve por la pantalla). La duración no cambia (CA-014-06).

**Errores**

- **CA-014-22 Fallo al eliminar**
  - **Dado** un fallo de escritura al eliminar
  - **Cuando** se elige "Eliminar" (menú, fila o acción del lector)
  - **Entonces** como CA-004-13 y CA-006-14: no hay animación ni card, la tarea sigue donde estaba y aparece el aviso "No hemos podido eliminar la tarea" con "Reintentar".
  - Si había una card visible de otra tarea, desaparece y esa eliminación queda definitiva igualmente: cuenta el intento de eliminar (CA-014-08), y así nunca se ven a la vez la card y el aviso.
- **CA-014-23 Fallo al deshacer**
  - **Dado** un fallo de escritura al recuperar la tarea
  - **Cuando** pulsa "Deshacer"
  - **Entonces** la card desaparece y aparece el aviso "No hemos podido recuperar la tarea" con "Reintentar" (mismo estilo que `deleteError`; si es falta de espacio, el mensaje de espacio). El aviso se lee una vez y el foco del lector (y el del teclado, si se usa) pasa a "Reintentar". Mientras el aviso se vea, "Reintentar" recupera la tarea (y entonces, como CA-014-18); lo que la hace definitiva (CA-014-11) también cierra el aviso, y entonces ya no se puede recuperar.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-014-1 | Doble pulsación rápida en "Eliminar" del menú | Se elimina una sola tarea |
| CL-014-2 | Doble pulsación rápida en "Eliminar tarea" de una fila del listado | Se elimina una sola: un segundo toque en menos de 350 ms (`doubleTapWindow`) sobre los botones de la fila que sube a ese sitio no hace nada. Eliminar varias seguidas, a un ritmo normal, sí funciona (CA-014-08) |
| CL-014-3 | Doble pulsación rápida en "Deshacer", rebote de tecla o doble pulsación del switch | Se recupera una sola vez. Además, las activaciones de "Deshacer" en los primeros 350 ms desde que aparece la card no hacen nada (el foco del teclado llega a ella al instante desde el listado) |
| CL-014-4 | "Deshacer" justo cuando se acaba el tiempo | Si el toque llega mientras la card se ve, se recupera; si ya ha desaparecido, no pasa nada |
| CL-014-5 | Texto de 10 000 caracteres | En la card, una línea con "…"; el lector lo lee completo, después de "Deshacer" (CA-014-16) |
| CL-014-6 | Texto grande (200 %) en un móvil de 360 dp | El texto de la card crece hasta el 200 % (sin el tope de la nota) y la card, en alto; con la escala ≥ 1,3, la etiqueta puede ocupar dos líneas; nada más se corta; "Deshacer" se ve entero y, si no cabe al lado del texto, pasa debajo (DEV-51; el propietario lo revisará al verlo en el móvil) |
| CL-014-7 | Eliminar en horizontal (imagen, PDF o web, con la acción del lector) | La card aparece abajo, sobre el adjunto, con las mismas reglas y con "Deshacer" siempre al lado del texto. Si la siguiente tarea no tiene adjunto, la app vuelve a vertical (CA-008-11) y la card sigue. Si después se deshace, la tarea recuperada se ve como cualquier tarea con adjunto (en horizontal si el móvil sigue así y la rotación no está bloqueada) |
| CL-014-8 | Girar el móvil con la card visible | La card sigue, el tiempo no se reinicia (CA-014-12) y, si tenía el foco del lector, lo conserva (y el tiempo sigue parado) |
| CL-014-9 | Recuperar una tarea web | La página se vuelve a cargar desde la dirección guardada; no se recupera nada de la página (ADR-0016, CA-009-13) |
| CL-014-10 | Recuperar una tarea con "Adjunto no disponible" | Vuelve igual, con la misma tarjeta |
| CL-014-11 | Se empieza a arrastrar una fila (o se elige "Mover") con la card visible | La card desaparece y la eliminación es definitiva (CA-014-11); el arrastre o el movimiento siguen con normalidad |
| CL-014-12 | Se elimina la tarea actual y, con la card, se abre el listado desde el menú | Al abrirse el listado, la card desaparece y la eliminación es definitiva (CA-014-07). **[Hecho]** El prototipo dejaba deshacer desde el listado |
| CL-014-13 | "Configuración y perfil" con la card visible | Al abrirla, la eliminación es definitiva (CA-014-11) |
| CL-014-14 | La app muere durante el arrugado | Definitiva (CA-014-13); al abrir no se repite la animación ni aparece la card |
| CL-014-15 | Pasar a segundo plano durante el arrugado o con la card, y volver en menos de 10 min (CA-001-12) | La misma pantalla, sin animación y sin card: pasar a segundo plano ya la hizo definitiva (CA-014-11) |
| CL-014-16 | Eliminar la última pendiente desde la pantalla principal | Arrugado con "Todo hecho." detrás (DEV-26); después, la card sobre "Todo hecho." sin "Crear una tarea", que aparece cuando la card desaparece |
| CL-014-17 | Gesto atrás con la card visible | En la pantalla principal y en "Todo hecho.", la app pasa a segundo plano, como hoy; en el listado, vuelve a la pantalla principal. En los dos casos la eliminación queda definitiva (CA-014-11) |

## 5. Estados vacíos y de error

| Estado | Cuándo | Qué ve el usuario |
|---|---|---|
| "Todo hecho." con la card | Se ha eliminado la última pendiente y aún se puede deshacer | "Todo hecho." sin "Crear una tarea" y la card abajo (CA-014-05, CL-014-16) |
| "Todo hecho." | La eliminación de la última ya es definitiva | Como CA-004-07 |
| Error al eliminar | Fallo de escritura al eliminar | CA-014-22 |
| Error al deshacer | Fallo de escritura al recuperar | CA-014-23 |

## 6. Accesibilidad

- **Tiempo ajustable (WCAG 2.2.1):** 4 s por defecto, o el "Tiempo para actuar" del sistema si es mayor (CA-014-06). Con el lector, el tiempo no empieza hasta que la card recibe el foco y no corre mientras lo tiene; con un teclado físico, lo mismo con su foco (CA-014-17). La duración no cambia con "reducir movimiento" ni con "Quitar animaciones".
- **Excepción a P6 (decisión del propietario, 2026-10-04; se registra en el ADR-0021):** en Android 8 y 9, que no tienen "Tiempo para actuar", la card dura 10 s con un servicio de accesibilidad activo. Para quien usa Switch Access ahí no llega a las diez veces del tiempo por defecto que pide WCAG 2.2.1 (serían 40 s). Lo mitigan que con TalkBack y con teclado el tiempo se detiene mientras la card tiene el foco, y que en Android 10 o posterior manda el ajuste del sistema. Se revisa si la beta lo señala.
- **Foco y lectura:** el foco del lector llega a la card aunque la pantalla de debajo se vuelva a montar; mientras se ve, la card es lo primero en el orden de lectura; se lee una sola vez, empezando por "Deshacer", y no es una región en vivo (CA-014-16). Al deshacer, un único anuncio cuando la pantalla ya se ve y el foco en la tarea recuperada (CA-014-18). Sin anuncios durante el arrugado (lo prefiere `a11y-reviewer`: un anuncio inicial lo cortaría el cierre del menú y duplicaría la card).
- **Alternativas:** "Deshacer" es un botón normal, sin gesto; la acción del lector "Eliminar tarea" se mantiene, ahora sin hoja (CA-014-19). Teclado y switch: CA-014-20.
- **Objetivos táctiles:** "Deshacer" se ve de 44, como el prototipo, con una zona táctil ≥ 48 dp (como los botones del listado, spec 006).
- **Contraste:** blanco sobre `ink` (≈ 18,9:1); la etiqueta gris claro del prototipo (`#D9D6CF`) sobre `ink`, ≈ 13:1; la barra contra su pista, ≥ 4,4:1 con todos los colores de nota. La barra es decorativa para el lector. El anillo de foco de "Deshacer" se ve sobre el negro (CA-014-20).
- **Foco no tapado (WCAG 2.4.11):** CA-014-05.
- **Reducir movimiento:** CA-014-21. **Texto grande:** CL-014-6. **Rebotes y dobles pulsaciones:** CL-014-2 y CL-014-3.
- **[Pendiente, auditoría en dispositivo, spec 022]** TalkBack real en el emulador y en el móvil: foco en la card tras el arrugado (vertical, horizontal y "Todo hecho.") y desde el listado; que el tiempo se detiene con el foco y al girar; deshacer desde "Todo hecho."; el "Tiempo para actuar" del sistema (10 s y 2 min en API 29 o más, y API 26); "Quitar animaciones"; teclado físico (Tab, anillo, doble Intro); Switch Access y Voice Access; texto al 200 % en vertical y en horizontal.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `undoDeletedTitle` | Tarea eliminada | Task deleted | Título de la card |
| `undoButton` | Deshacer | Undo | Botón de la card |
| `undoA11yLabel` | Deshacer. Tarea eliminada: {label} | Undo. Task deleted: {label} | Lectura de la card como un solo elemento (CA-014-16); `{label}`, completa. Empieza por el texto visible del botón (Voice Access, WCAG 2.5.3) |
| `a11yUndone` | Tarea recuperada | Task restored | Único anuncio al deshacer (CA-014-18) |
| `undoError` | No hemos podido recuperar la tarea | We couldn't restore the task | Con `retry` (CA-014-23) |

Se reutilizan `deleteA11yAction` ("Eliminar tarea"), `deleteError`, `retry`, `storageErrorNoSpace`, `menuDelete` y las etiquetas sin texto de las specs 007–009 (`attachmentPhoto`, `attachmentImage`, nombre del PDF, dominio). Sus descripciones en las ARB dejan de mencionar la hoja de confirmación.

Se retiran, si nada más los usa (lo comprueba el plan): `deleteTitle`, `deleteBody`, `deleteConfirm`, `a11yDeletedNext`, `a11yDeletedAllDone` y `a11yDeletedFromList`. La descripción de `editorCancel` deja de mencionar la hoja de eliminar.

## 8. Fuera de alcance

- Deshacer al **completar** (P-4 de la spec 003: sigue sin deshacer).
- Deshacer después de volver de segundo plano o de reabrir la app; papelera recuperable; deshacer más de una eliminación.
- Deshacer otras acciones (editar, reordenar, quitar un adjunto).
- Cerrar la card deslizándola o con un botón propio; cambiar la duración desde Ajustes.
- Animación al recuperar en la pantalla principal (el prototipo no la tiene: la tarea vuelve sin más).

## 9. Decisiones y preguntas

**Decisiones del propietario (2026-10-04, D20):** sin confirmación; 4 s; la última eliminación sustituye a la anterior; foco del lector en "Deshacer"; tiempo del sistema y sin caducar con el foco del lector; lo que la hace definitiva antes (CA-014-11).

**Decisiones del propietario al revisar esta spec (2026-10-04):** (no queda ninguna suposición de producto abierta)

- Ir a otra pantalla con la card visible la hace definitiva: «Si durante el deshacer vas a otra pantalla, la card desaparece. Eso es que no querías deshacer». Por eso siempre se deshace en la pantalla en la que se eliminó, y el editor la hace definitiva al abrirse, aunque luego se cancele. Enmienda la respuesta P-4 del plan F4b, que no la hacía definitiva al abrir el listado.
- Una hoja (el menú, "Mover", la confirmación de un enlace) no es otra pantalla: la card sigue debajo y su tiempo corre (CA-014-07).
- Desde "Todo hecho.", deshacer vuelve a la pantalla de la que se venía, como el prototipo: «Si deshaces es porque lo has hecho sin querer. Te quedas donde venías» (CA-014-10).
- En Android 8 y 9 con un servicio de accesibilidad, la card dura 10 s (CA-014-06; excepción a P6 en el §6).

- Reordenar la hace definitiva: «Si reordeno desaparece la card de deshacer. Es una interacción que indica que ya no quiero deshacer» (CA-014-11). Por eso, mientras se puede deshacer, la cola no cambia y la tarea vuelve exactamente a su sitio.
- La cortina de notificaciones y los diálogos del sistema no cambian nada: «la card a los 4 segundos desaparece». Pasar a segundo plano (otra app, inicio, "Recientes", pantalla bloqueada) la hace definitiva, como dice D20.
- «Para el sistema, la eliminación es cuando termina el tiempo del deshacer o se cierra la card»: la tarea sale de la cola al momento y la eliminación es definitiva (y se borran sus archivos) cuando la card desaparece, por la causa que sea, también si la app muere (CA-014-13, CA-014-15).
- Confirmadas tal como se propusieron: el lector no dice nada durante el arrugado y lee la card una sola vez (CA-014-16); el foco del teclado físico también va a "Deshacer" y detiene el tiempo (CA-014-17); con reducir movimiento la barra se sigue vaciando (CA-014-21); se recupera todo, también la última posición del PDF (CA-014-09); los errores (CA-014-22 y CA-014-23); el texto grande (CL-014-6, revisable al verlo); y los 350 ms contra dobles pulsaciones (CL-014-2 y CL-014-3).

**[Hecho] Aprobación (2026-10-04):** el propietario aprueba la spec y acepta el ADR-0021; el ADR-0012 pasa a "Sustituido en parte por ADR-0021 (momento del borrado)".

## 10. Enmiendas a otras specs y documentos (aplicadas al aprobar esta spec, 2026-10-04)

- **004:**
  - §1 y HU-004-2: la red de seguridad pasa a ser el deshacer (spec 014).
  - CA-004-01 y CA-004-02 (hoja y Cancelar): **retirados**; los sustituyen CA-014-01 y CA-014-02.
  - CA-004-03, CA-004-04 y CA-004-13: "al confirmar", "pulsa Eliminar" y "la hoja se cierra" pasan a "al eliminar" y "el menú se cierra".
  - CA-004-06 ("Sin deshacer"): **sustituido** por CA-014-03 a CA-014-10.
  - CA-004-07: "Crear una tarea" no se ve mientras se ve la card (CA-014-05).
  - CA-004-09: "no queda nada" se cumple **cuando la eliminación es definitiva** (CA-014-15).
  - CA-004-10: la acción elimina directamente (CA-014-19).
  - CA-004-11: sustituido por CA-014-16 y CA-014-18.
  - CL-004-1, CL-004-2 y CL-004-4 (de la hoja): obsoletos; §6, §7 y §8, según esta spec.
  - Siguen: CA-004-05, CA-004-08 y CA-004-12.
- **005:** CA-005-11, enmienda de la 004: "Eliminar" elimina con deshacer (spec 014).
- **006:**
  - CA-006-02 y CA-006-18: mientras se ve la card, ocupa el sitio de "Nueva tarea" en pantalla; en el orden del lector va la primera (CA-014-16).
  - CA-006-14: sin confirmación y con la card; ya no "No hay deshacer". Si era la última, "Todo hecho." con la card (y CL-006-3).
  - CA-006-16: "Eliminar tarea" elimina directamente.
  - CA-006-17: las filas de eliminar y "Cancelar la confirmación", sustituidas por CA-014-16 a CA-014-18.
  - CL-006-5: sin hoja; ver CL-014-2.
- **007:**
  - CA-007-19: "Eliminar tarea", sin confirmación y con deshacer.
  - CA-007-16: los archivos se borran cuando la eliminación es definitiva.
  - CA-007-20: la etiqueta sin texto se usa en la card, no en la confirmación.
  - CA-007-21 y el horizontal (CA-007-11): los anuncios de eliminar pasan a la lectura de la card; en horizontal, además de la imagen y el logotipo, se ve la card al eliminar.
- **008 y 009:** lo mismo que en la 007: la tarjeta de adjunto no disponible, los archivos huérfanos, la etiqueta sin texto (nombre del archivo o dominio), los anuncios de eliminar y la card en horizontal (CA-008-11 y su equivalente de la 009).
- **001:** CA-001-12, nota: pasar a segundo plano hace definitiva una eliminación que aún se podía deshacer.
- **ADR-0012:** "Sustituido en parte por ADR-0021" al aceptar este.
- **Constitución:** una línea del ADR-0021 en las excepciones de P6 (Android 8 y 9 con un servicio de accesibilidad: 10 s), al aceptarlo.
- **`docs/design/prototype-deviations.md`:**
  - DEV-51 (nueva);
  - DEV-09, DEV-10 y DEV-23, obsoletas;
  - DEV-26: "Crear una tarea" aparece cuando desaparece la card, no al caer la bola.
- **`docs/glossary.md`:**
  - "Eliminar", sin la frase de "hoy";
  - "Card de deshacer", "Tiempo para actuar" y "Eliminación definitiva" (ya añadidos, en Borrador).
- **`docs/architecture.md`, `docs/testing.md` y `design/tokens.json`:** los cambios que diga el plan.
- **Memoria `no-undo-no-nada-pendiente`:** al implementar, el deshacer al eliminar ya es la regla.

## Anexo: notas para `plan.md` (no normativas)

- **ADR-0021, opción propuesta:** la fila se borra de la BD al instante (como hoy) y la tarea, con su adjunto, se guarda **en memoria** hasta que la eliminación es definitiva; solo entonces se borran sus archivos. Deshacer vuelve a insertarla con el mismo id y el mismo `rank` (la cola no cambia mientras se puede deshacer). Sin esquema nuevo.
- **Barrido:** hoy solo corre al arrancar, tras el primer fotograma; aun así, el adjunto de una eliminación que se puede deshacer debe quedar protegido (como las importaciones en curso).
- **Foco tras el arrugado (hallazgo crítico de `a11y-reviewer`):** al acabar el arrugado se vuelve a montar la pantalla con un nodo `scopesRoute` nuevo (`app/lib/app/una_app.dart`). TalkBack lo toma como un cambio de ventana: enfoca el primer nodo e ignora `FocusSemanticEvent` (`specs/004-eliminar/plan.md`). Por eso la card va la primera en el orden del lector, o el final del arrugado no crea una ruta nueva. El anuncio de "Tarea recuperada" va después de la transición, como en `task_list_screen.dart`. Al volver al listado desde "Todo hecho.", lo mismo: si el listado se monta como ruta nueva, TalkBack iría al título; el foco tiene que llegar a la fila recuperada (CA-014-18). Hay que verificarlo en el emulador con TalkBack: el test del evento de foco no basta.
- **Tiempo:**
  - Se mide con un reloj inyectable, no con un `AnimationController`: Flutter acorta las animaciones con "Quitar animaciones" salvo con `AnimationBehavior.preserve`, como en `crumple_overlay.dart`.
  - **[Suposición, verificar en el plan con la documentación vigente]** El tiempo del sistema se lee con `AccessibilityManager.getRecommendedTimeoutMillis(4000, FLAG_CONTENT_CONTROLS | FLAG_CONTENT_TEXT)` (API 29+), por un canal nativo.
  - "Servicio de accesibilidad activo": `MediaQuery.accessibleNavigation` o `AccessibilityManager.isEnabled`.
- **Teclado:** el foco del teclado solo se mueve con `FocusManager.highlightMode` en modo tradicional (teclado físico). Con la pantalla táctil no se mueve, porque si no el tiempo no correría nunca.
- **Segundo plano [Suposición]:** `AppLifecycleState` `hidden`/`paused`, no `inactive` (cortina de notificaciones).
- **Tokens:**
  - `motion.duration.undoWindow` (4000 ms, vuelve tras retirarse en la 004) y la entrada de 220 ms;
  - colores del prototipo sin token: `#D9D6CF` (p. ej. `onInkMuted`, con su par en `validate-tokens`) y la pista de la barra, `#3A3936`;
  - anillo de foco invertido en la card (`app/lib/ui/focus_ring.dart`).
- **Lector:**
  - la card es un solo nodo de botón con `undoA11yLabel`, sin `liveRegion`;
  - el foco se mueve con el patrón de la 013 (foco de teclado y evento semántico).
- **Código que cambia:**
  - `delete_confirm_sheet.dart` se retira;
  - cambian `deletion_controller.dart`, `delete_task_action.dart`, `task_list_screen.dart`, `current_task_screen.dart` y `all_done_screen.dart`;
  - `DeleteCurrentTask` y `DeletePendingTask` dejan de borrar los archivos al momento.
