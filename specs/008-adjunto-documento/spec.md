# Spec 008: Tareas con PDF

- **Estado:** **Implementada** (2026-09-28; PR svallev/una#14). Aprobada (propietario, 2026-09-27). Reescrita ese día con sus respuestas a dos revisiones de `spec-reviewer`: **en la v1 solo se sube PDF** (ADR-0014). Enmendada el mismo día por el propietario: **20 páginas como máximo** (CA-008-03)
- **Reglas de producto:** R3 (documento, **solo PDF en la v1**), R5 (los adjuntos van arriba del todo), R8 (abrir → tarea actual rápido), **propuesta de valor 2**
- **Pantallas del prototipo:** 9 "Añadir (+)", 3 "Nueva tarea" (con documento), 10 "Tarea con documento (abierto)", 5 "Todas las tareas" (insignia). Los errores y el giro no están en el prototipo (R-17): se hacen con los componentes existentes y se revisan en el móvil
- **Decisiones y ADR:** **ADR-0014 (solo PDF en la v1)**, **ADR-0015 (sin "Volver a vertical", 2026-09-28)**, D5, D6 y D19 (enmendadas por el ADR-0014), D10 (enmendada: también gira la tarea con PDF), D17, D18, ADR-0004 (y R-10), ADR-0008 (enmendado por el ADR-0014), ADR-0010, ADR-0011, ADR-0012 (completar borra los archivos), ADR-0013 (**no** aplica al PDF: el zoom del PDF se queda y tiene alternativas), DEV-01, DEV-18 a DEV-42 citadas (enmendadas DEV-02, DEV-03, DEV-18, DEV-39, DEV-40 y DEV-42), DEV-36; modelo de amenazas T-2, T-3, T-5, T-7
- **Dependencias:** 001 a 007 (hoja "Añadir", editor con adjunto, importación, borrado único, "Adjunto no disponible", pantalla encendida, giro)
- **Enmienda:** CA-007-11 (~~el horizontal de la imagen añade "Volver a vertical"~~; la imagen y el PDF giran igual, CA-008-11). **Enmienda del propietario (2026-09-28):** se quita el botón "Volver a vertical" con los dos tipos; la app vuelve a vertical solo al poner el móvil en vertical. CA-007-11 queda como estaba en la 007
- **Cierra lo diferido a la 008:** CA-002-09, CL-003-4, CL-003-8, CA-004-01 (etiqueta sin texto), CL-004-3, CA-005-07, CL-005-3, CA-006-02 (insignia), CA-006-18 (tipo de adjunto), el texto para documentos sin extensión (spec 006 §7; con solo PDF, siempre hay insignia "PDF") y DEV-18 ("Subir archivo"). La URL sigue en la 009

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.
> En esta spec, **MB** = 10⁶ bytes (como en la 007).

## 1. Objetivo

Tener a mano un PDF (entradas, un programa, un horario, instrucciones) **a la vista nada más abrir la app**, sin conexión, y poder leerlo en detalle girando el móvil y ampliándolo.

Es una primera versión: **solo PDF**. Word, Excel, PowerPoint, texto y el resto de formatos quedan fuera para evitar sus riesgos (formatos complejos, depender de otras apps) hasta que haga falta.

## 2. Historias de usuario

- **HU-008-1** Como asistente a un congreso, quiero el PDF del programa a la vista al abrir la app, para no buscarlo en el correo.
- **HU-008-2** Como usuario, quiero girar el móvil y ampliar el PDF, para leer la letra pequeña.
- **HU-008-3** Como usuario, quiero que un PDF no pueda ejecutar nada ni sacarme de la app sin avisar.

## 3. Criterios de aceptación

**Añadir un PDF**

- **CA-008-01 Subir PDF sin permisos (cierra DEV-18 para esta fila)**
  - **Dado** la hoja "Añadir a la tarea" (CA-007-01)
  - **Cuando** elige la fila "Subir archivo — PDF · va arriba del todo" (el texto de la segunda línea cambia, §7)
  - **Entonces** se abre el selector de archivos del sistema, **sin pedir ningún permiso**, que ofrece solo PDF (filtrando por el tipo que declara cada archivo; lo que decide es CA-008-02); el archivo elegido se **copia** a la app y aparece en el editor (CA-008-04).
  - La copia es necesaria: el selector solo presta el archivo un momento, y el original se puede mover, borrar o estar en la nube. La tarea sigue mostrando el PDF aunque se borre el original.
  - Si cancela el selector, el editor queda como estaba.
  - La app de *release* sigue sin declarar permisos de almacenamiento (se comprueba en CI).
- **CA-008-02 Solo PDF, por el contenido**
  - **Dado** un archivo elegido
  - **Cuando** se importa
  - **Entonces** se acepta solo si su **contenido** es un PDF que se puede abrir; la extensión y el tipo declarado no cuentan. Un PDF sin extensión o con otra extensión se acepta.
  - Cualquier otra cosa (Word, Excel, texto, HTML, imágenes, ZIP, ejecutables…), aunque se llame `.pdf`, se rechaza con "Solo se pueden subir archivos PDF."
- **CA-008-03 Límites: 10 MB y 20 páginas (D18)**
  - **Dado** un archivo
  - **Cuando** pasa de 10 MB, o es un PDF de más de 20 páginas
  - **Entonces** se rechaza:
    - por tamaño, con "El PDF es demasiado grande (máx. 10 MB)."; el tamaño se comprueba antes que el contenido;
    - por páginas, con "El PDF tiene demasiadas páginas (máx. 20)."; las páginas se cuentan al abrirlo, antes de dibujar nada.
  - Motivo: la tarea con PDF es para **consulta rápida** (entradas, horarios, un mapa, instrucciones), no para leer documentos largos (propietario, 2026-09-27).
- **CA-008-04 Editor con PDF**
  - **Dado** un PDF elegido
  - **Cuando** se muestra el editor
  - **Entonces**, como en el prototipo:
    - la vista previa: la franja negra con "PDF", el nombre y el tamaño, y debajo las páginas, desplazables, empezando por la primera; con el botón "Quitar adjunto" (≥ 48 dp, DEV-36);
    - el campo "Añade un texto (opcional)", sin abrir el teclado solo;
    - "Continuar", "Guardar" o "Guardar cambios", como en CA-007-04.
  - Con PDF, el texto es opcional. Pulsar (+) con un adjunto ya elegido (PDF o imagen) abre la hoja y lo nuevo **sustituye** a lo anterior: una tarea tiene un solo adjunto.
- **CA-008-05 Siempre arriba (R5, cierra CA-002-09)**
  - **Dado** el editor de una tarea **nueva** con un PDF
  - **Cuando** pulsa "Continuar" o "Guardar"
  - **Entonces** la tarea se crea como **tarea actual** sin preguntar la posición y se vuelve al origen: a la pantalla principal mostrándola, o al listado con la fila en la posición 1, resaltada y con el foco (como CA-007-05).
- **CA-008-06 Editar: añadir, sustituir o quitar el PDF (cierra CA-005-07 y CL-005-3)**
  - **Dado** el editor en modo editar
  - **Cuando** añade, sustituye (por otro PDF o por una imagen, y al revés) o quita el PDF y pulsa "Guardar cambios"
  - **Entonces** la tarea **conserva su posición y su color** (CA-005-05). Si queda sin texto ni adjunto, "Guardar cambios" no guarda y el foco va al campo (DEV-17). "Cancelar" deja la tarea como estaba.
- **CA-008-07 Nombre del archivo**
  - **Dado** un PDF importado
  - **Cuando** se guarda
  - **Entonces** la app guarda también su **nombre** ("Programa congreso.pdf"), porque se muestra en la franja y sirve de etiqueta cuando la tarea no tiene texto (CA-008-19). Se guarda **saneado**: sin rutas, sin caracteres de control ni de cambio de dirección del texto, y recortado a 120 caracteres visibles conservando la extensión. Si queda vacío (el proveedor no da nombre o solo tenía caracteres no válidos), se usa "PDF". El archivo en sí se guarda con un nombre generado por la app.
  - Donde se muestra, ocupa una línea con "…"; el lector lo lee entero.

**Ver el PDF**

- **CA-008-08 Tarea actual con PDF (propuesta 2, R8)**
  - **Dado** que la tarea actual tiene un PDF
  - **Cuando** se abre la app en frío
  - **Entonces**, como el prototipo (pantalla 10), sin ningún toque y en el tiempo de CA-001-09 (< 1 s p50, dispositivo de referencia, *release*):
    - arriba, el logotipo y el menú; abajo, el botón de completar, como en cualquier tarea;
    - entre ellos, sobre blanco y con borde negro arriba y abajo, una zona desplazable con:
      - la **franja negra fija** con "PDF", el nombre y el tamaño ("2,4 MB" / "2.4 MB", según el idioma);
      - el texto de la tarea (si lo hay) en una banda del color de la nota, que se desplaza con las páginas;
      - las páginas del PDF **al 100 % del ancho**, una debajo de otra, con desplazamiento vertical continuo.
  - En ese tiempo se ve **la última posición vista** (CA-008-09) o, si no la hay, la primera página, aunque todavía no esté a su resolución final. Funciona igual en modo avión.
  - Si la última posición deja la banda del texto fuera de la vista, al abrir se ve la franja y las páginas; el texto está desplazando hacia arriba y el lector lo lee siempre (CA-008-20).
  - **No hay indicador de página** (propietario, 2026-09-27).
- **CA-008-09 Última posición**
  - **Dado** una tarea con PDF que ya se ha visto
  - **Cuando** se vuelve a ver: desde otra pantalla, en un arranque en frío o desde segundo plano tras 10 minutos o más
  - **Entonces** se ve en **la última posición vista** de esa tarea, al ancho (sin zoom). La posición es la página que ocupaba la parte de arriba de la zona y cuánto se había desplazado dentro de ella, así que se conserva aunque cambie el ancho (al girar o en otro dispositivo).
  - Desde segundo plano en menos de 10 minutos se ve todo igual, zoom incluido (CA-001-12).
  - Si no se puede recuperar (p. ej., tras restaurar una copia), empieza por la primera página.
- **CA-008-10 Zoom que se queda, con alternativas (P6)**
  - **Dado** la tarea actual con PDF, en vertical o en horizontal
  - **Cuando** amplía o reduce, con gestos o sin ellos
  - **Entonces**:
    - el zoom va de ×1 (al ancho, el mínimo) a ×4 y **se queda puesto** al soltar (no es como la imagen, CA-007-10);
    - el pellizco amplía o reduce de forma continua entre ×1 y ×4;
    - el doble toque alterna entre ×1 y ×2,5 alrededor del punto tocado;
    - para el lector de pantalla y Switch Access, las acciones "Ampliar", "Reducir" y "Ajustar al ancho" (solo las que se pueden hacer: a ×1 no hay "Reducir" ni "Ajustar al ancho"; a ×4 no hay "Ampliar"); cada una anuncia el nivel, "Zoom {percent} %";
    - con el foco en el PDF y teclado: `+` o `=` amplía, `-` reduce y `0` vuelve al ancho (también las del teclado numérico);
    - "Ampliar" y "Reducir" (acción o tecla) van por pasos fijos ×1 → ×1,5 → ×2,5 → ×4, alrededor del centro de lo que se ve;
    - con reducir movimiento, los cambios de zoom no se animan.
  - **Ampliado, moverse sin gestos:** las páginas se mueven en las dos direcciones; el lector y Switch Access tienen acciones de desplazamiento arriba, abajo, izquierda y derecha (solo las que se pueden hacer), y con teclado las flechas mueven lo ampliado.
  - El zoom vuelve al ancho al salir de la tarea (editor, listado, otra tarea) y en los casos de CA-008-09. Abrir y cerrar el menú (una hoja sobre la tarea) no lo cambia.
- **CA-008-11 Girar para ver en detalle: igual con imagen y con PDF (D10 enmendada; enmienda CA-007-11)**
  - **Dado** la tarea actual con PDF **o con imagen** a la vista (sin el menú, el editor ni el listado encima)
  - **Cuando** gira el móvil a horizontal
  - **Entonces** la pantalla gira sola y en horizontal se ve **lo mismo con los dos tipos** (propietario, 2026-09-27):
    - el adjunto al 100 % del ancho, con desplazamiento vertical (el PDF, además, con su zoom, CA-008-10; la imagen, con su pellizco de vistazo, CA-007-10);
    - el logotipo, como en CA-007-11;
    - ~~el botón **"Volver a vertical"**, nuevo también para la imagen;~~ (quitado, ver la nota de abajo)
    - sin menú, botón de completar, franja, pie ni texto de la tarea.
  - ~~"Volver a vertical" (≥ 48 dp, con fondo propio para verse sobre cualquier imagen o página) pone la app en vertical aunque el móvil siga en horizontal. Vuelve a girar sola la próxima vez que el móvil pase por vertical y luego a horizontal.~~
  - **Enmienda del propietario (2026-09-28):** sin "Volver a vertical", ni con imagen ni con PDF. La app vuelve a vertical solo cuando el móvil se pone en vertical.
  - Al volver a vertical se conservan la posición y, en el PDF, el zoom.
  - En horizontal se sigue pudiendo completar o eliminar con las acciones del lector (CA-003-07, CA-004-10), que lleva el adjunto (CA-008-20).
  - **No gira** con "Adjunto no disponible" (CA-008-18, CA-007-19).
  - Si se completa o se elimina en horizontal y la siguiente tarea no tiene PDF ni imagen, la app vuelve a vertical.
  - Si gira con la confirmación de un enlace abierta, la confirmación sigue abierta en la nueva orientación.
  - ~~"Volver a vertical" dura mientras se vea esa tarea: si sale de ella y vuelve con el móvil aún en horizontal, se ve en vertical hasta que el móvil pase por vertical.~~ (Sin objeto desde la enmienda de 2026-09-28.)
  - Respeta el bloqueo de rotación del sistema. En tablets y plegables, en horizontal usa todo el ancho de la pantalla (como CA-007-11).
  - *Enmienda (spec 014, aprobada 2026-10-04; se implementa con ella):* al eliminar en horizontal, además se ve la card de deshacer (CL-014-7).
  - *Enmienda (spec 016, implementada; en vigor):* el grupo de imágenes gira igual, con las acciones de foto (CA-016-12).
- **CA-008-12 Enlaces del PDF, sin nada peligroso**
  - **Dado** un PDF con JavaScript, formularios, acciones, archivos incrustados o enlaces
  - **Cuando** se muestra
  - **Entonces**:
    - no se ejecuta ningún script ni acción del PDF; los formularios se ven como están, sin poder rellenarlos; los archivos incrustados se ignoran;
    - los enlaces **siguen siendo enlaces**:
      - un enlace a otra página del PDF desplaza a esa página;
      - un enlace `https` o `http` pide confirmación, "¿Abrir {host} en el navegador?", con el dominio real (en punycode si mezcla alfabetos, T-5), y solo si se confirma se abre en el navegador del sistema;
      - un enlace `mailto:` o `tel:` pide confirmación, "¿Abrir {destino} con otra app?" (la dirección o el número), y solo si se confirma se abre la app de correo o de teléfono **sin enviar ni llamar** (el usuario lo hace allí). Del `mailto:` solo se pasan los destinatarios y el asunto (nunca adjuntos, copias ni cuerpo);
      - un enlace `http(s)` con usuario o contraseña en la dirección (`usuario@…`) no hace nada (T-5);
      - `{host}` y `{destino}` se muestran saneados (sin caracteres de control ni de cambio de dirección) y enteros, con saltos de línea si no caben;
    - los enlaces se alcanzan con el lector ("Enlace a {host}", "Enlace a la página {page}", "Enlace a {destino}") y con Tab, con el anillo de foco visible, y se activan con Enter;
    - cualquier otro enlace (`javascript:`, `file:`, `content:`, `intent:`, `data:`, lanzar una app o un archivo, esquemas desconocidos) **no hace nada**.
  - Si no hay ninguna app para abrirlo, "No hay ninguna app para abrir este enlace."
- **CA-008-13 Pantalla encendida (solo PDF)**
  - **Dado** el ajuste ~~"Mantener la pantalla encendida con adjuntos"~~ "Pantalla siempre activa" activo
  - **Cuando** se ve la tarea actual con PDF, en vertical o en horizontal
  - **Entonces** la pantalla no se apaga, ~~con el límite de 10 minutos sin tocar y~~ **sin límite de tiempo** y con las mismas condiciones de CA-007-12. **Enmienda 2026-10-05 (spec 015, implementada; en vigor)** (CA-015-04a a 04d).

**Validar, guardar y borrar**

- **CA-008-14 Importación acotada (T-3)**
  - **Dado** un archivo, por grande, falso o malformado que sea
  - **Cuando** se importa
  - **Entonces**:
    - el tamaño se cuenta mientras se copia y se aborta al pasar de 10 MB, aunque el declarado sea menor o desconocido;
    - la importación no bloquea la interfaz;
    - tras 20 s se aborta con "No hemos podido leer este PDF.";
    - un PDF se comprueba al importar: si no se puede abrir, no tiene páginas, pide contraseña para abrirse (CL-008-1) o no se puede dibujar su primera página, se rechaza;
    - con los ficheros de prueba malformados (PDF truncado, con referencias cíclicas, con una bomba de compresión, de 0 páginas, de 10 000 páginas (se rechaza por páginas sin quedarse colgada), un `.pdf` que es HTML o ZIP, nombre con `../`, dirección que apunta a los datos de la propia app) la app **nunca se cierra** y no escribe nada fuera de su zona temporal.
- **CA-008-15 Preparando el PDF**
  - **Dado** una importación que tarda más de 400 ms
  - **Cuando** está en curso
  - **Entonces** el editor muestra "Preparando PDF…" con "Cancelar", como CA-007-15 (DEV-39). "Cancelar" deja el editor como estaba.
- **CA-008-16 Ningún archivo huérfano (ADR-0011, ADR-0012; cierra CL-004-3)**
  - **Dado** cualquier camino que deje un PDF sin uso: completar o eliminar la tarea (desde la pantalla principal o el listado), quitar o sustituir el PDF al editar, "Quitar adjunto" en "Adjunto no disponible", cancelar el editor o la importación, un error, tiempo agotado o falta de espacio, o un fallo al guardar
  - **Cuando** termina la operación
  - **Entonces** no queda ningún archivo de ese PDF (el PDF, lo que la app haya preparado para mostrarlo rápido y su última posición) ni temporales, con **el mismo borrado** que la 007; si falla, lo recoge el barrido del siguiente arranque (después del primer fotograma). Un PDF que se está importando nunca se barre.
  - *Enmienda (spec 014, aprobada 2026-10-04; se implementa con ella):* al eliminar la tarea, el PDF se borra cuando la eliminación es definitiva (CA-014-15); deshacer lo recupera con su última posición (CA-014-09).
- **CA-008-17 Copia de seguridad (ADR-0004, R-10)**
  - **Dado** tareas con PDF
  - **Cuando** Android hace la copia de seguridad
  - **Entonces** los PDF siguen la regla de las imágenes (CA-007-18): **fuera** de la copia en la nube (que incluye siempre las tareas y los ajustes); en la transferencia directa entre dispositivos con Android 12 o posterior.
- **CA-008-18 Adjunto no disponible**
  - **Dado** que falta, está vacío o no se puede abrir el PDF de una tarea
  - **Cuando** se abre la app o se muestra la tarea
  - **Entonces** no se cierra ni se bloquea la app, y se ve la tarjeta de CA-007-19 con el icono de documento y **una sola acción** ("Quitar adjunto" o "Eliminar tarea"). Si solo falta lo que la app preparó para mostrarlo rápido, se regenera sin avisar.
  - *Enmienda (spec 014, aprobada 2026-10-04; se implementa con ella):* "Eliminar tarea" elimina sin confirmación y con deshacer (CA-014-01).

**Donde aparece el PDF**

- **CA-008-19 Tareas con PDF en el resto de la app**
  - **Dado** una tarea con PDF
  - **Cuando** aparece fuera de la pantalla principal
  - **Entonces**:
    - **Listado (cierra CA-006-02):** insignia negra de 44 px con "PDF" entre el asa y el texto, como el prototipo; decorativa para el lector. También con "Adjunto no disponible".
    - **Sin texto:** en el listado, en la confirmación de eliminar (cierra CA-004-01) y en los anuncios, la etiqueta es el **nombre del archivo**.
    - **Completar y eliminar (cierra CL-003-4):** la rotura y el arrugado muestran lo que se ve en la tarea (franja y página visible); con reducir movimiento, sus alternativas.
  - *Enmienda (spec 014, aprobada 2026-10-04; se implementa con ella):* la etiqueta sin texto (nombre del archivo) se usa en la card de deshacer (CA-014-04), ya no en la confirmación.

**Accesibilidad**

- **CA-008-20 Lectura**
  - **Dado** un lector de pantalla
  - **Cuando** lee una tarea con PDF
  - **Entonces**:
    - la franja y el texto de la tarea son **un único elemento**: "Tarea actual: {texto}. Con PDF, {nombre}, {tamaño}", o "Tarea actual: {nombre}. PDF, {tamaño}" sin texto;
    - con "Adjunto no disponible": "Tarea actual: {texto o nombre}. Adjunto no disponible";
    - cada página se lee como "Página {n} de {total}" seguida de su texto, en el orden del PDF, cuando lo tiene; si no (PDF escaneado), solo "Página {n} de {total}" (solo para el lector: no hay indicador visible);
    - los enlaces del PDF se pueden alcanzar y activar con el lector (con la confirmación de CA-008-12);
    - el contenedor del PDF lleva las acciones, en las dos orientaciones y en este orden: Completar tarea, Eliminar tarea, "Página siguiente", "Página anterior", las de zoom y las de desplazamiento (CA-008-10), solo las que se pueden hacer;
    - en horizontal, sin franja ni texto, la página visible se lee con el prefijo "Tarea actual: {texto o nombre}"~~, y "Volver a vertical" es un botón más~~ (enmienda del propietario, 2026-09-28);
    - fila del listado (cierra CA-006-18): "{n} de {total}: {texto}. Con PDF", o "{n} de {total}: {nombre}. PDF" sin texto;
    - anuncios de completar y eliminar sin texto (cierra CL-003-8): "Tarea completada. Siguiente: {nombre}".
- **CA-008-21 Foco y anuncios**
  - **Dado** un lector de pantalla activo
  - **Cuando** ocurre cada acción
  - **Entonces** un único anuncio y el foco donde dice la tabla (con la limitación de TalkBack aceptada en CA-007-22):

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Vuelve del selector con un PDF | La vista previa | "PDF añadido" |
    | Cancela el selector | El botón (+) | Ninguno |
    | "Preparando PDF…" | "Cancelar" | "Preparando PDF…" |
    | Error al importar | El botón (+) | El texto del error |
    | Quitar adjunto | El botón (+) | "Adjunto quitado" |
    | "Página siguiente" / "Página anterior" | La nueva página donde el lector lo permita (entonces, sin anuncio) | "Página {n} de {total}" si el foco no se mueve |
    | "Ampliar", "Reducir", "Ajustar al ancho" | Donde estaba | "Zoom {percent} %" |
    | Enlace del PDF: confirmación | "Cancelar" | El texto de la confirmación |
    | Cierra la confirmación o vuelve del navegador u otra app | El enlace | Ninguno |
    | Enlace sin app para abrirlo | El enlace | El texto del error |
    | Gira a horizontal | La página visible | Ninguno |
    | ~~"Volver a vertical"~~ (quitado, 2026-09-28) | — | — |
  - *Enmienda (spec 014, aprobada 2026-10-04; se implementa con ella):* los anuncios de eliminar pasan a la lectura de la card de deshacer (CA-014-16).

- **CA-008-22 Reducir movimiento, teclado y texto grande**
  - **Dado** "reducir movimiento", un teclado o el texto al 200 %
  - **Cuando** se usan el editor o la tarea con PDF
  - **Entonces**:
    - con reducir movimiento: el zoom, el paso de página y "Preparando PDF…" no se animan;
    - con teclado: Av Pág / Re Pág pasan de pantalla, las flechas desplazan, Tab recorre los enlaces y `+`, `-` y `0` hacen zoom (CA-008-10);
    - con el texto al 200 % en un móvil de 360 dp: la franja (nombre con "…"), "Preparando PDF…", los errores, la confirmación del enlace ~~y "Volver a vertical"~~ se ven enteros; nada se corta y todos los botones miden ≥ 48 dp. El texto de la tarea en la banda escala como mucho a ×1,6, como el pie de la imagen (CA-007-23; `imageCaptionMaxTextScale`), y se ve entero (la banda crece con él). El texto del PDF no cambia con la escala del sistema (para eso está el zoom). *(Enmienda del propietario, 2026-09-28: el límite de ×1,6 de la banda, por coherencia con la 007.)*

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-008-1 | PDF que pide contraseña para abrirse | Se rechaza al importar: "Este PDF está protegido con contraseña." |
| CL-008-2 | PDF con solo contraseña de permisos (se abre sin escribir nada) | Se acepta y se ve normal |
| CL-008-3 | PDF corrupto, de 0 páginas o cuya primera página no se puede dibujar | Se rechaza al importar: "No hemos podido leer este PDF." |
| CL-008-4 | Una página intermedia no se puede dibujar o tarda más de 5 s | Esa página se ve en blanco con el borde; las demás, bien. La app no se cierra |
| CL-008-5 | PDF de 20 páginas escaneadas de casi 10 MB (el caso más pesado admitido) | Se desplaza de la 1 a la 20 sin cerrarse, y la tarea añade < 200 MB de memoria sobre la misma tarea con texto (medida como en la 007, `architecture.md` §7) |
| CL-008-6 | Nombre con rutas, caracteres de control o de cambio de dirección | Se sanea (CA-008-07); el archivo se guarda con un nombre generado |
| CL-008-7 | Archivo de Drive que solo está en la nube, sin conexión, o documento nativo de Google Docs | "No hemos podido leer este PDF."; el editor queda como estaba |
| CL-008-8 | Sin espacio al importar o al guardar | `storageErrorNoSpace` (con "Reintentar" al guardar); no se crea la tarea ni quedan temporales |
| CL-008-9 | Doble toque rápido en "Continuar" con PDF | Se crea una sola tarea |
| CL-008-10 | Páginas de tamaños u orientaciones distintas | Cada página, al ancho, con su proporción |
| CL-008-11 | Registros (logs) en *release* | No se registra ningún nombre, ruta, dirección, enlace ni contenido de un PDF |
| CL-008-12 | Web de pruebas (ADR-0010) | "Subir archivo" usa el selector del navegador; el PDF se guarda solo en memoria; no hay giro, ni con PDF ni con imagen (enmienda del propietario, 2026-09-28, por CA-008-11) |
| CL-008-13 | La miniatura de la app en "Recientes" | Muestra el PDF. **[Resuelto por la spec 011, ADR-0019]** La miniatura no muestra contenido: se oculta siempre, no solo con adjunto (propietario, 2026-09-30). **Límites aceptados (propietario, 2026-09-30):** "Recientes" abierto desde la propia app, el gesto de cambio entre apps y la hoja parcial del selector de fotos enseñan lo que hay a la vista (CL-011-14, CL-011-6, CL-011-15); fotograma blanco al volver (CA-011-03); en Android 8–12, **[Suposición]** sin verificar hasta PD-10. Ver `specs/011-ocultar-recientes/spec.md` y `docs/adr/0019-ocultar-recientes-sin-bloquear-capturas.md` *(antes: Se oculta siempre, como en CL-007-11 *(antes spec 010; enmiendas 2026-09-29 y 2026-09-30)*)* |

## 5. Estados vacíos y de error

Los errores de importación aparecen como aviso sobre el editor (se anuncian solos), el editor queda como estaba y el foco vuelve a (+). Los de los enlaces, como aviso sobre la tarea.

| Estado | Texto |
|---|---|
| No es un PDF | "Solo se pueden subir archivos PDF." |
| Demasiado grande | "El PDF es demasiado grande (máx. 10 MB)." |
| Demasiadas páginas | "El PDF tiene demasiadas páginas (máx. 20)." |
| Protegido con contraseña | "Este PDF está protegido con contraseña." |
| Ilegible, corrupto o tiempo agotado | "No hemos podido leer este PDF." |
| Enlace sin app | "No hay ninguna app para abrir este enlace." |
| Sin espacio | `storageErrorNoSpace` |
| Adjunto perdido | CA-008-18 |

## 6. Accesibilidad

- Lectura, foco y anuncios: CA-008-20 y CA-008-21. La insignia del listado es decorativa.
- Zoom y paso de página sin gestos: CA-008-10 y CA-008-22 (P6). **No hay excepción a P6**: la del ADR-0013 es solo para la imagen.
- Desplazamiento sin gestos: acciones de desplazamiento del lector y de Switch Access (también a los lados si está ampliado), Av Pág / Re Pág y flechas con teclado; los enlaces, con Tab y Enter.
- Orientación (WCAG 1.3.4): la tarea con PDF gira igual que la de imagen (CA-008-11); el resto de la app sigue en vertical (D10). El horizontal es solo para ver el adjunto, con la misma excepción aprobada para la imagen, que se amplía al PDF (ADR-0014, constitución P6). ~~"Volver a vertical" es enfocable, así que con teclado sin lector siempre queda algo que enfocar y se puede volver a la vista completa.~~ **Enmienda del propietario (2026-09-28):** sin "Volver a vertical", en horizontal vuelve la situación aceptada en la 007 para la imagen (ADR-0013): el PDF, que lleva Completar, Eliminar, página, zoom y desplazamiento, es lo único que se puede enfocar, y la vista completa vuelve al poner el móvil en vertical.
- Contraste: franja blanca sobre negro; ~~"Volver a vertical" con fondo propio;~~ el anillo de foco, con borde blanco y negro (como en la 007).
- Objetivos táctiles ≥ 48 dp: "Quitar adjunto", "Cancelar", ~~"Volver a vertical"~~ y los botones de la confirmación del enlace.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `attachPickFileHint` (**cambia**) | PDF · va arriba del todo | PDF · goes on top | Antes "PDF, Word, Excel… · va arriba del todo" (DEV-02 enmendada) |
| `attachmentPdf` | PDF | PDF | Insignia y lectura |
| `docSizeMb` / `docSizeKb` | {size} MB / {size} KB | {size} MB / {size} KB | Como el prototipo: KB (entero) por debajo de 1 MB; MB con un decimal y el separador del idioma |
| `pdfPreparing` | Preparando PDF… | Preparing PDF… | CA-008-15 |
| `pdfPreparingCancel` | Cancelar | Cancel | |
| `pdfPageA11y` | Página {page} de {total} | Page {page} of {total} | Solo lector de pantalla |
| `pdfNextPage` / `pdfPrevPage` | Página siguiente / Página anterior | Next page / Previous page | Acciones del lector |
| `pdfZoomIn` / `pdfZoomOut` / `pdfZoomFit` | Ampliar / Reducir / Ajustar al ancho | Zoom in / Zoom out / Fit to width | Acciones del lector |
| ~~`backToPortrait`~~ | ~~Volver a vertical~~ | ~~Back to portrait~~ | Quitada (propietario, 2026-09-28) |
| `a11yWithPdf` | {text}. Con PDF, {name}, {size} | {text}. With PDF, {name}, {size} | Tarea actual con texto |
| `a11yPdfOnly` | {name}. PDF, {size} | {name}. PDF, {size} | Tarea actual sin texto |
| `a11yRowWithPdf` | {text}. Con PDF | {text}. With PDF | Fila del listado con texto |
| `a11yRowPdfOnly` | {name}. PDF | {name}. PDF | Fila del listado sin texto. **Enmienda del propietario (2026-09-28):** antes, `a11yRowWithPdf` con el nombre ("{nombre}. Con PDF"); manda CA-008-20 |
| `a11yZoomLevel` | Zoom {percent} % | Zoom {percent}% | Tras una acción de zoom |
| `pdfLinkWeb` / `pdfLinkPage` / `pdfLinkApp` | Enlace a {host} / Enlace a la página {page} / Enlace a {target} | Link to {host} / Link to page {page} / Link to {target} | Etiquetas de los enlaces |
| `a11yPdfAdded` | PDF añadido | PDF added | |
| `errPdfType` | Solo se pueden subir archivos PDF. | Only PDF files can be uploaded. | |
| `errPdfTooBig` | El PDF es demasiado grande (máx. {max} MB). | The PDF is too large (max {max} MB). | `max` = 10 |
| `errPdfTooManyPages` | El PDF tiene demasiadas páginas (máx. {max}). | The PDF has too many pages (max {max}). | `max` = 20 |
| `errPdfProtected` | Este PDF está protegido con contraseña. | This PDF is password-protected. | |
| `errPdfUnreadable` | No hemos podido leer este PDF. | We couldn't read this PDF. | |
| `errNoAppForLink` | No hay ninguna app para abrir este enlace. | There's no app to open this link. | |
| `openInBrowserConfirm` | ¿Abrir {host} en el navegador? | Open {host} in the browser? | Compartida con la 009 (sustituye a `urlLeaveConfirm`) |
| `openInAppConfirm` | ¿Abrir {target} con otra app? | Open {target} with another app? | `mailto:` y `tel:` |
| `linkConfirmOpen` / `linkConfirmCancel` | Abrir / Cancelar | Open / Cancel | Botones de la confirmación |

Se reutilizan `currentTaskSemantics` ("Tarea actual: {text}", prefijo en horizontal), `attachPickFile` ("Subir archivo"), `editorAttachmentPlaceholder`, `editorRemoveAttachment`, `a11yAttachmentRemoved`, `attachmentMissing`, `a11yAttachmentMissing` (con `text` = nombre del archivo si no hay texto), `storageErrorNoSpace`, `retry`, `editorCancel`, `deleteA11yAction` y las lecturas de las specs 001, 003, 004 y 006 con `{text}` = nombre del archivo cuando no hay texto. La 009 se actualiza para usar `openInBrowserConfirm`.

## 8. Fuera de alcance (v1)

- **Cualquier formato que no sea PDF:** Word, Excel, PowerPoint, OpenDocument, RTF, iWork, TXT, CSV y MD (enmienda de D6 y D19; propietario, 2026-09-27). Por tanto, tampoco abrir documentos con otras apps del teléfono.
- PDF protegidos con contraseña de apertura.
- Indicador de página visible.
- Anotar, firmar, rellenar formularios, buscar, seleccionar o copiar texto, imprimir, compartir o exportar el PDF.
- Varios PDF por tarea.
- La copia de los PDF en la nube (con la tarea de las imágenes antes de la v1.0) y el ajuste de "Recientes" (F5; antes spec 010, enmienda 2026-09-29).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-27, propietario]** **Solo PDF en la v1**, para ahorrar riesgos. Registrado en el **ADR-0014**, que enmienda D6, D19, el ADR-0008, DEV-02 y DEV-03 (ya actualizados en `docs/`).
- **[Resuelto 2026-09-27, propietario]** La tarea con PDF **gira exactamente igual** que la de imagen, para ver en detalle: en horizontal, el adjunto, el logotipo ~~y el botón "Volver a vertical", que también se añade a la imagen~~ (enmienda D10 y DEV-42). El botón se quita el 2026-09-28 (propietario).
- **[Resuelto 2026-09-27, propietario]** El zoom del PDF **se queda puesto** (a diferencia de la imagen), con alternativas accesibles.
- **[Resuelto 2026-09-27, propietario]** Sin indicador de página: el PDF se ve al 100 % del ancho, con desplazamiento y zoom.
- **[Resuelto 2026-09-27, propietario]** Los enlaces siguen siendo enlaces salvo los peligrosos: `http(s)`, `mailto:` y `tel:` con confirmación; el resto no hace nada.
- **[Resuelto 2026-09-27, propietario]** Al volver, la última posición vista, también tras cerrar la app. **[Suposición]** Hace falta guardar esa posición por tarea; el plan dirá dónde (si es en la base de datos, con una `schemaVersion` nueva y su test de migración).
- **[Resuelto 2026-09-27, propietario]** **20 páginas como máximo**, además de los 10 MB: la tarea con PDF es de consulta rápida (CA-008-03).
- **[Resuelto 2026-09-27, propietario]** Pantalla encendida solo con PDF (el único tipo de la v1).
- **[Resuelto 2026-09-27, propietario]** Se guarda el **nombre** del PDF, saneado (CA-008-07).
- **[Resuelto 2026-09-27, propietario]** Un PDF con contraseña de apertura se **rechaza** al importar (CL-008-1).
- ~~**[Resuelto 2026-09-27, propietario]** "Volver a vertical" también en la tarea con imagen (CA-008-11 enmienda CA-007-11; se implementa en esta spec).~~
- **[Resuelto 2026-09-28, propietario]** **Sin "Volver a vertical"**, ni con imagen ni con PDF (se había implementado en T-008-17 y se quita): la app vuelve a vertical solo al poner el móvil en vertical.
- **[Resuelto 2026-09-27]** Desviaciones del prototipo registradas: DEV-02 ("PDF · va arriba del todo"), DEV-03 (solo PDF), DEV-18 ("Subir archivo" funciona desde la 008), DEV-40 (icono de documento) y DEV-42 (también gira el PDF~~, con "Volver a vertical"~~; sin botón desde 2026-09-28).
- **[Resuelto 2026-09-27, propietario]** El horizontal es igual con imagen y con PDF, así que la excepción de accesibilidad ya aprobada para el horizontal de la imagen (WCAG 1.3.4 y 2.1.1, ADR-0013) se amplía al PDF en el ADR-0014 y en la nota de P6 de la constitución. ~~"Volver a vertical" la mitiga en los dos casos.~~ Desde el 2026-09-28 (propietario) no hay botón: la excepción queda como en el ADR-0013. **[Resuelto 2026-09-28, propietario]** ADR-0015 (enmienda el ADR-0014) y nota de P6 de la constitución actualizada (versión 1.3).
- **[Pendiente P-6, spec 009]** Si una URL apunta a un PDF, se ofrece guardarlo como tarea con PDF (esta spec), con los mismos límites (10 MB y 20 páginas).
