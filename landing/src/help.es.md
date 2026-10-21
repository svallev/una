# Ayuda (ES)

<!-- Ayuda en español (spec 023, CA-023-17). Se redacta desde las specs implementadas (cada sección dice de cuál) y con los textos de app_es.arb. Los comentarios como este no se publican. La puerta de publicación lee este archivo entero: nada de corchetes ni llaves en los comentarios. -->

Una sola tarea cada vez, a pantalla completa: así funciona la app. Aquí se explica cómo se usa cada cosa, también con lector de pantalla (TalkBack), teclado o Switch Access.

## La tarea actual y cómo se completa

<!-- Fuente: specs 001 (CA-001-06, 12) y 003 (CA-003-01 a 05, 07). -->

La tarea actual es la primera de tu lista y la única que ves al abrir la app: una nota adhesiva a pantalla completa. Si tiene un adjunto (foto, PDF o web), se ve ahí mismo. Arriba tienes el «Menú de la tarea» y abajo, «Pulsa para completar».

Para completarla, **mantén pulsado** «Pulsa para completar» un poco más de un segundo (1,2 s): verás cómo se rellena el botón. Si sueltas antes, no se completa. Al terminar, la nota se rompe, aparece «¡Enhorabuena!» y pasas a la siguiente («Ahora a por la siguiente →»); al completar la última, verás «Todo hecho.»

- Completar **borra la tarea del todo**, con sus adjuntos: no queda histórico ni papelera, y no se puede deshacer.
- Si dejas la app en segundo plano menos de 10 minutos, la encuentras como la dejaste; si pasan 10 minutos o más, vuelves a la tarea actual.
- Con un lector de pantalla o Switch Access no hace falta mantener pulsado: usa la acción «Completar tarea» (mira «Usar la app con TalkBack»).

## Crear una tarea y elegir dónde va

<!-- Fuente: specs 001 (CA-001-02, 04), 002 (CA-002-01 a 07), 006 (CA-006-15) y 007 (CA-007-05). -->

Abre el «Menú de la tarea» y elige «Nueva tarea» (también está en «Todas las tareas» y, como «Crear una tarea», cuando ves «Todo hecho.»). Escribe lo que tienes que hacer (hasta 10 000 caracteres) y pulsa «Continuar». «Cancelar» descarta lo escrito sin preguntar.

Después te preguntamos «¿Dónde la pones?»:

- «Arriba del todo»: pasa a ser la tarea actual, la única que ves. La que tenías espera detrás.
- «A la cola»: queda la última. No la verás hasta completar las anteriores.
- «Seguir editando»: vuelves al editor con el texto intacto.

La primera vez que abres la app, el editor de la primera tarea aparece solo y «Guardar» la guarda sin preguntar dónde va, porque todavía no hay otra.

Una tarea con foto, PDF o web va siempre arriba del todo y no pregunta dónde.

## Editar una tarea

<!-- Fuente: specs 005 (CA-005-04 a 08), 006 (CA-006-13), 007 (CA-007-06) y 009 (CA-009-05). -->

Abre el «Menú de la tarea» y elige «Editar» (en «Todas las tareas», usa el botón «Editar tarea» de la fila). Cambia el texto y pulsa «Guardar cambios»: la tarea conserva su posición y su color. «Cancelar» descarta los cambios.

- Una tarea no puede quedarse vacía: sin texto y sin adjunto no se guarda. Para quitarla, usa «Eliminar».
- Con un adjunto, el editor lo muestra junto a «Quitar adjunto» y a un texto opcional. Puedes quitarlo (si queda texto) o sustituirlo con el botón (+); sustituirlo no mueve la tarea.
- En una tarea web, «Editar» abre «Cargar URL» con la dirección actual. Una tarea que no es web no se convierte en web.

## Eliminar y deshacer

<!-- Fuente: specs 014 (CA-014-01 a 14, 17), 004 (CA-004-09) y 006 (CA-006-14), con el ADR-0021. -->

Para eliminar la tarea actual, abre el «Menú de la tarea» y elige «Eliminar»; en «Todas las tareas», usa «Eliminar tarea» en su fila. No pide confirmación: la tarea sale de la lista al momento y abajo aparece una franja negra, «Tarea eliminada», con el botón «Deshacer» y una barra que se vacía.

- Tienes 4 segundos para pulsar «Deshacer». Si tu Android tiene un «Tiempo para actuar» mayor, dura ese tiempo; en Android 8 y 9, con un lector de pantalla o Switch Access activo, dura 10 segundos. Mientras el foco del lector o del teclado está en la franja, el tiempo se detiene.
- «Deshacer» devuelve la tarea a su sitio, con su texto, su color y su adjunto. Solo se puede deshacer la última tarea eliminada.
- La eliminación se vuelve definitiva antes de tiempo si eliminas o completas otra tarea, vas a otra pantalla (la lista, el editor o Ajustes), reordenas o dejas la app en segundo plano. Abrir el menú no la afecta.
- Cuando es definitiva no queda nada: ni el texto, ni los adjuntos, ni una papelera.

## Todas mis tareas y reordenar

<!-- Fuente: specs 005 (CA-005-03, 12), 006 (CA-006-01 a 16) y 014 (CA-014-02). -->

Para ver todas las tareas pendientes, abre el «Menú de la tarea» y elige «Todas mis tareas» (muestra cuántas hay; con una sola tarea no se puede abrir: «Solo tienes esta tarea»). La primera fila es la tarea actual. «Nueva tarea» crea otra y «Volver a la tarea» te lleva a la pantalla principal.

Para cambiar el orden hay tres formas:

- Arrastrar: pon el dedo en el asa, a la izquierda de la fila, y arrastra; o mantén pulsada la fila un momento y arrástrala. El orden se guarda al soltar. La tarea actual no se arrastra, pero puedes soltar otra encima de ella para que ocupe su lugar.
- Sin arrastrar: toca el asa («Mover tarea») y elige «Hacer actual», «Mover arriba» o «Mover abajo» (solo salen las que tienen sentido en esa posición).
- Con un lector de pantalla o Switch Access: cada fila tiene esas mismas opciones como acciones (mira «Usar la app con TalkBack»).

Para editar una tarea, usa «Editar tarea» o toca dos veces seguidas sobre su fila; para eliminarla, «Eliminar tarea».

## Fotos, PDF y páginas web

<!-- Fuente: specs 007 (CA-007-02, 03, 09, 11, 13, 19), 008 (CA-008-03, 09 a 12), 009 (CA-009-01 a 11, 15) y 016 (CA-016-02, 09, 12). -->

Al crear o editar una tarea, el botón (+) abre «Añadir a la tarea». No hace falta dar permiso a la cámara, a las fotos ni a los archivos: la app abre la cámara o el selector del sistema y solo recibe lo que tú eliges.

- «Hacer foto» abre la cámara del sistema.
- «Subir imágenes» abre el selector de fotos del sistema: elige una o varias, hasta 10 fotos. Se aceptan JPEG, PNG, WebP, GIF y HEIC (este último en Android 9 o posterior), de hasta 30 MB y 64 megapíxeles por foto. La app guarda su propia copia sin metadatos (ubicación, fecha, cámara); tu original no se toca.
- Con varias fotos, la tarea es un carrusel: ves una a la vez y deslizas un dedo hacia los lados para cambiar de foto (tras la última viene la primera). Un punto por foto indica cuál ves. Si eliges más de 10, se usan las 10 primeras.
- «Subir archivo» admite solo PDF, de hasta 10 MB y 20 páginas: está pensado para consultar entradas, horarios o mapas. La app recuerda por dónde ibas. Los enlaces del PDF piden confirmación antes de abrirse; los scripts y los formularios del PDF no funcionan.
- «Cargar URL» muestra una página web en vivo dentro de la tarea. **Necesita conexión**: sin ella verás «Necesitas conexión para ver esta página.» y «Reintentar». Solo se carga con conexión segura (`https`); la app guarda únicamente la dirección y no se puede navegar por la página (sus enlaces no hacen nada).

Con una foto, un PDF o una web, gira el móvil a horizontal para ver el adjunto más grande, sin menú ni botón de completar; vuelve a vertical para usarlos. Si falta el archivo de un adjunto (por ejemplo, al restaurar una copia de seguridad), verás «Adjunto no disponible».

## Ajustes

<!-- Fuente: specs 015 (CA-015-01b, 04a a 04c, 05, 08, 09, 12a), 017 (CA-017-01, 06 a 09, 13), 019 (CA-019-03, 08, 10, 15, 19a, 20, 29) y 010 (CA-010-01, 02). -->

Abre el «Menú de la tarea» y elige «Ajustes». Allí encuentras:

- «Idioma»: «Como el sistema» (la opción de partida: usa el primer idioma de tu móvil que la app admita, español o inglés; si no hay ninguno, inglés), «Español» o «English». Cambia al momento, sin reiniciar la app.
- «Notificaciones» (solo en Android; vienen apagadas): enciéndelas y elige «Notificaciones al día», 1, 2 o 3, a las 08:55, 13:55 y 18:55 (hora de tu móvil; no se pueden cambiar). Cada una te enseña tu tarea actual; no llegan si no te queda ninguna tarea ni si estás mirando la app, y al tocarla se abre la app en la tarea actual. Antes de encenderlas, Ajustes te avisa: «La notificación muestra tu tarea actual. Con el móvil bloqueado también se ve, salvo que ocultes el contenido sensible en los ajustes de tu móvil.» Con Android 13 o posterior, el sistema te pide permiso al encenderlas; si están bloqueadas, la fila lo dice y «Abrir los ajustes de notificaciones» te lleva a los ajustes del sistema.
- «Pantalla siempre activa» (apagada por defecto): con una tarea con foto, PDF o web a la vista, la pantalla no se apaga ni se bloquea, sin límite de tiempo. Con una tarea de solo texto no actúa.
- «Bloquear zoom» (apagado por defecto; solo para fotos): la foto de la tarea actual no se amplía con el pellizco ni se mueve al tocarla; se queda donde está. Cambiar de foto deslizando, las acciones del lector de pantalla y la lupa del sistema siguen funcionando.
- «Política de privacidad», «Licencias de terceros» y «Ayuda», bajo «Información», abren esta web en tu navegador y necesitan conexión.

## Recientes

<!-- Fuente: specs 011 (CA-011-01, 02, 04) y 001 (CA-001-12). -->

La app **no enseña tus tareas en «Recientes»** (la lista de apps recientes de Android): ni el texto, ni las fotos, ni los PDF, ni las páginas web, en ninguna de sus pantallas. Lo que se ve en su lugar lo decide el sistema.

- Las capturas de pantalla y las grabaciones sí salen con el contenido: solo se oculta en «Recientes».
- Al volver a la app, si han pasado 10 minutos o más en segundo plano ves la tarea actual; si no, la misma pantalla de antes.

## Copias de seguridad

<!-- Fuente: specs 007 (CA-007-18) y 019 (CA-019-23), y la sección de copias de seguridad de la política de privacidad. -->

Android puede copiar los datos de las apps a tu cuenta de Google y pasarlos a un móvil nuevo. En esta app:

- Se copian tus tareas (texto, orden y, si las tienen, el nombre del PDF o la dirección de la web) y tus ajustes, solo si la copia va cifrada de extremo a extremo, lo que pide un bloqueo de pantalla (Android 9 o posterior). En Android 8 no se copia nada.
- Los archivos de las fotos y de los PDF no se suben a la nube: al restaurar, esas tareas dicen «Adjunto no disponible» y puedes quitar el adjunto o eliminar la tarea.
- Al pasar los datos directamente de un móvil a otro (con cable o Wi-Fi), en Android 12 o posterior se transfiere todo, adjuntos incluidos; en Android 9 a 11, los archivos de fotos y de PDF tampoco.
- Esas copias las gestiona Google en tu cuenta: puedes desactivarlas en los ajustes de Android. Si reinstalas la app con la copia activada, puede que recuperes tus tareas.

## Ampliar

<!-- Fuente: specs 007 (CA-007-10), 008 (CA-008-10), 009 (CA-009-06), 017 (CA-017-13) y los ADR-0013 y 0022. -->

Hay varias formas de ampliar, según lo que veas:

- Fotos: pellizca para ampliar de vistazo, hasta ×8; al soltar, la foto vuelve a su tamaño. No hay un zoom que se quede puesto: para eso, usa la lupa del sistema.
- PDF: el zoom va de ×1 a ×4 y se queda puesto. Amplía con el pellizco, con doble toque (alterna entre ×1 y ×2,5) o con las acciones «Ampliar», «Reducir» y «Ajustar al ancho»; con teclado, con las teclas `+`, `-` y `0` (la última vuelve al ancho).
- Páginas web: se ven con el zoom que permita el propio sitio.
- La lupa del sistema (en los ajustes de accesibilidad de Android, en Ampliación; el nombre cambia según el móvil) funciona en toda la app, también con «Bloquear zoom» encendido.
- El texto de las tareas sigue el tamaño de letra de Android: en la tarea actual crece hasta 1,6 veces y, si no cabe, se desplaza.

## Usar la app con TalkBack

<!-- Fuente: specs 003 (CA-003-07), 006 (CA-006-09, 16, 17), 008 (CA-008-10, 20), 014 (CA-014-16 a 20), 016 (CA-016-09, 20, 21) y 013, con los ADR-0013, 0020, 0022 y 0023. -->

Casi todos los gestos tienen una alternativa para TalkBack, Switch Access, el control por voz y el teclado. Las acciones se eligen en el menú de acciones de tu lector sobre la tarea o sobre la fila:

- Completar: la acción «Completar tarea», sin mantener pulsado. El doble toque sobre «Pulsa para completar» no completa, para evitar accidentes.
- Eliminar: la acción «Eliminar tarea». La franja con «Deshacer» es lo primero que lee el lector y su tiempo se detiene mientras tiene el foco.
- En «Todas mis tareas», cada fila ofrece «Hacer actual», «Mover arriba», «Mover abajo», «Editar tarea» y «Eliminar tarea» (solo las que se pueden hacer).
- Varias fotos: «Foto siguiente» y «Foto anterior», o desplazar a izquierda y derecha; el lector anuncia qué foto es. Con teclado, las flechas izquierda y derecha.
- PDF: «Página siguiente», «Página anterior», «Ampliar», «Reducir», «Ajustar al ancho» y las acciones de desplazamiento.
- Pellizco: ampliar una foto con el pellizco no tiene alternativa dentro de la app; usa la lupa del sistema.
- Si eliges en «Ajustes» un idioma distinto del primero de tu móvil, algunos anuncios y nombres de acciones los lee la voz del sistema, en su idioma.

## Cómo contactar

<!-- Fuente: spec 023 (CA-023-17) y la sección «Quién es el responsable» de la política de privacidad. El contacto es un hueco de identidad que se rellena en F6. -->

Para cualquier duda sobre la app o sobre tu privacidad, escribe a [CONTACTO]. La [política de privacidad](/privacy#es) explica qué guarda la app y dónde.
