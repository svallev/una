# Spec 007: Tareas con foto o imagen (visor a pantalla completa)

- **Estado:** Aprobada (propietario, 2026-09-26). Reescrita ese día con sus decisiones tras la revisión (spec-reviewer, a11y-reviewer y security-reviewer)
- **Reglas de producto:** R3 (foto con la cámara, imagen de la galería), R5 (los adjuntos van arriba del todo), R8 (abrir → tarea actual rápido), **propuesta de valor 2**
- **Pantallas del prototipo:** 9 "Añadir (+)", 3 "Nueva tarea" (con adjunto), 1 "Tarea actual" (con imagen), 5 "Todas las tareas" (miniatura). El visor a pantalla completa y los errores no están en el prototipo (R-17): se hacen con los componentes existentes y se revisan en el móvil
- **Decisiones y ADR:** D5, D8, D10 (enmendada: giro solo en el visor), D17, D18, ADR-0002, ADR-0004 (y R-10), ADR-0011, DEV-01, DEV-02, DEV-18, DEV-35 a DEV-40; modelo de amenazas T-2, T-3, T-7, T-8, T-13, T-15
- **Dependencias:** 001, 002, 003, 004, 005, 006
- **Cierra lo diferido a la 007 (parte de imagen):** CA-001-02 ("+"), CA-002-09, CL-003-4, CL-003-8, CA-004-01 (etiqueta sin texto), CL-004-3, CA-005-07, CL-005-3, CA-006-02 (miniatura), CA-006-18 (tipo de adjunto) y el pendiente de `specs/006-listado/plan.md` §7 (un único servicio de purga). Documentos y URL siguen en 008 y 009

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Que un horario, un mapa o unos pasos fotografiados queden **a la vista nada más abrir la app**, sustituyendo el truco de ponerlos como fondo de la pantalla de bloqueo, y que se puedan leer en detalle a pantalla completa.

## 2. Historias de usuario

- **HU-007-1** Como asistente a un festival, quiero hacer una foto del horario y verla al abrir la app, para no tener que buscarla.
- **HU-007-2** Como usuario, quiero ver la imagen entera y ampliarla, para leer los detalles.
- **HU-007-3** Como usuario, quiero que la pantalla no se apague mientras la consulto, para no tener que desbloquear el móvil cada momento.
- **HU-007-4** Como usuario, quiero que la foto no guarde mi ubicación ni otros datos ocultos, para que mis tareas no revelen dónde estuve.

## 3. Criterios de aceptación

**Añadir una imagen**

- **CA-007-01 Hoja "Añadir a la tarea"**
  - **Dado** el editor (primera tarea, nueva tarea desde el menú, el listado o "Todo hecho.", o editar una tarea que no es web)
  - **Cuando** pulsa (+)
  - **Entonces** sube la hoja "Añadir a la tarea", como en el prototipo (hoja de CA-005-01, cierre con la X, tocando fuera, deslizando hacia abajo o con el gesto atrás, DEV-21), con cuatro filas de dos líneas:
    - "Hacer foto — Con la cámara · va arriba del todo";
    - "Subir imagen — Desde tu galería · va arriba del todo";
    - "Subir archivo — PDF, Word, Excel… · va arriba del todo" (DEV-02);
    - "Cargar URL — Una página web · va arriba del todo".
  - "Subir archivo" y "Cargar URL" se ven activas pero no hacen nada hasta las specs 008 y 009 (DEV-18).
- **CA-007-02 Hacer foto sin permisos**
  - **Dado** la hoja
  - **Cuando** elige "Hacer foto"
  - **Entonces** se abre la cámara del sistema **sin pedir ningún permiso**. Al aceptar la foto, aparece en el editor tras pasar la misma validación que una imagen de la galería (CA-007-10), y no queda en la app ninguna otra copia de lo que escribió la cámara.
- **CA-007-03 Subir imagen sin permisos**
  - **Dado** la hoja
  - **Cuando** elige "Subir imagen"
  - **Entonces** se abre el selector de fotos del sistema (en Android 8–12 sin selector de fotos, el selector de documentos), **sin pedir acceso a la galería**, y la imagen elegida aparece en el editor.
  - La app de *release* no declara permisos de cámara, de fotos ni de almacenamiento (se comprueba en CI).
- **CA-007-04 Editor con imagen**
  - **Dado** una imagen elegida
  - **Cuando** se muestra el editor
  - **Entonces**, como en el prototipo:
    - la vista previa (recortada para llenar su recuadro) con el botón "Quitar adjunto" (≥ 48 dp, DEV-36);
    - el campo "Añade un texto (opcional)", sin abrir el teclado solo;
    - "Continuar" (nueva tarea con otras pendientes), "Guardar" (primera tarea o desde "Todo hecho.") o "Guardar cambios" (editar).
  - Con imagen, el texto es opcional. Pulsar (+) con una imagen ya elegida abre la hoja y la nueva imagen **sustituye** a la anterior.
- **CA-007-05 Siempre arriba (R5, cierra CA-002-09)**
  - **Dado** el editor de una tarea **nueva** con una imagen
  - **Cuando** pulsa "Continuar"
  - **Entonces** la tarea se crea como **tarea actual** sin preguntar la posición y se vuelve al origen: a la pantalla principal mostrándola, o al listado con la fila en la posición 1, resaltada y con el foco (como "Arriba del todo" en CA-006-15/17).
- **CA-007-06 Editar: añadir, sustituir o quitar la imagen (cierra CA-005-07 y CL-005-3)**
  - **Dado** el editor en modo editar
  - **Cuando** añade, sustituye o quita la imagen y pulsa "Guardar cambios"
  - **Entonces** la tarea **conserva su posición y su color** (no sube, CA-005-05).
  - Si queda sin texto ni imagen, "Guardar cambios" no guarda y el foco va al campo (DEV-17).
  - "Cancelar" deja la tarea como estaba.
- **CA-007-07 Copia propia y sin datos ocultos**
  - **Dado** una imagen importada
  - **Cuando** se guarda
  - **Entonces**:
    - la app guarda sus propias versiones (completa, de pantalla y miniatura), **recodificadas a partir de los píxeles**: no se conserva ningún byte del archivo original ni su miniatura interna;
    - no contienen metadatos de ningún tipo (EXIF, GPS, XMP, IPTC, notas del fabricante, bloques de texto de PNG, EXIF de WebP o HEIC), ni el vídeo de las "fotos con movimiento", ni la imagen HDR secundaria, ni datos tras el final de la imagen;
    - la orientación queda corregida (las 8 orientaciones EXIF) y los colores, en sRGB;
    - no se guarda el nombre original del archivo;
    - la **versión completa** es la imagen entera, reducida solo si pasa de 24 megapíxeles, conservando la proporción y **sin límite de lado** (una captura de 1080 × 20 000 se conserva entera);
    - si se borra el original de la galería, la tarea sigue mostrando la imagen;
    - la app nunca escribe en la galería ni en el almacenamiento compartido.

**Ver la imagen**

- **CA-007-08 Visible al abrir (propuesta 2, R8)**
  - **Dado** que la tarea actual tiene una imagen
  - **Cuando** se abre la app en frío
  - **Entonces**, como en el prototipo, la imagen llena la pantalla **recortada** (a sangre, detrás del logotipo, el menú y el botón de completar) y aparece en el tiempo de CA-001-09 (< 1 s p50, dispositivo de referencia, *release*), sin ningún toque.
  - El logotipo y el menú llevan fondo blanco sobre la imagen.
  - Si hay texto, se ve como pie sobre la imagen: recuadro negro con texto blanco (22 px, peso 800), 146 px por encima del borde inferior. Máximo 3 líneas con "…"; el lector lee el texto completo.
- **CA-007-09 Visor a pantalla completa (D10, DEV-35, DEV-37)**
  - **Dado** la tarea actual con imagen
  - **Cuando** toca la imagen (o la activa con el lector)
  - **Entonces** se abre el visor:
    - la imagen **al 100 % del ancho** de la pantalla, sobre el color papel;
    - si es más alta que la pantalla, se desplaza **solo en vertical**;
    - arriba a la izquierda, el botón "Cerrar" (48 dp); el gesto atrás también cierra;
    - al cerrar, se vuelve a la tarea actual con el foco en ella;
    - en tablets y plegables, el visor usa todo el ancho de la pantalla aunque el resto de la app esté limitado a 600 px (CL-001-7);
    - aparece con un fundido corto (el de las hojas); con reducir movimiento, el de 400 ms (CA-007-23).
- **CA-007-10 Zoom opcional en el visor (D10)**
  - **Dado** el visor
  - **Cuando** pellizca, o toca dos veces
  - **Entonces**:
    - la imagen se amplía hasta ×8; el doble toque va por pasos (×1 → ×2,5 → ×8 → ×1) y centra la ampliación en el punto tocado;
    - ampliada, se puede desplazar en las dos direcciones;
    - al volver a ×1 (pellizcando o con el doble toque), vuelve el ancho completo y el desplazamiento solo vertical.
- **CA-007-11 Girar en el visor (D10 enmendada)**
  - **Dado** el visor
  - **Cuando** gira el móvil a horizontal
  - **Entonces** el visor gira y la imagen vuelve al ancho completo (×1).
  - El resto de la app sigue solo en vertical; al cerrar el visor en horizontal, la tarea actual se ve en vertical.
  - Al volver el móvil a vertical, el visor se cierra solo y se ve la tarea actual, sin pulsar "Cerrar" (propietario, 2026-09-27). Abierto en vertical, sigue abierto hasta que se cierre.
  - Gira solo, sin tocar la pantalla, y respeta el bloqueo de rotación del sistema. A ×1 la imagen va siempre al ancho, con desplazamiento vertical, también en horizontal (propietario, 2026-09-27).
- **CA-007-12 Pantalla encendida, con límite (D10)**
  - **Dado** que el ajuste "Mantener la pantalla encendida con adjuntos" está activo (por defecto sí; su pantalla llega con la spec 010)
  - **Cuando** se ve la tarea actual con imagen o su visor
  - **Entonces** la pantalla no se apaga por inactividad **mientras se use**: tras **10 minutos sin tocarla** vuelven el apagado y el bloqueo normales del teléfono.
  - Solo cuentan como uso los **toques** en la pantalla; las teclas de un teclado físico no reinician los 10 minutos (propietario, 2026-09-26).
  - También vuelven al pasar a otra pantalla de la app (menú, editor, listado), a segundo plano o a una tarea sin imagen.

**Validar, guardar y borrar**

- **CA-007-13 Tipos y límites**
  - **Dado** un archivo elegido o una foto de la cámara
  - **Cuando** se importa
  - **Entonces** el tipo se decide **por el contenido**, no por la extensión ni por el tipo declarado. Se aceptan JPEG, PNG, WebP, GIF (se toma el primer fotograma) y HEIC/HEIF (Android 9 o superior), de hasta 30 MB (30 × 10⁶ bytes) y 64 megapíxeles.
  - Si no se cumple, aparece el error correspondiente (§5) y el editor queda como estaba.
  - No se admiten SVG, AVIF (v1) ni HEIC en Android 8.
- **CA-007-14 Importación acotada**
  - **Dado** un archivo, por grande, falso o malformado que sea
  - **Cuando** se importa
  - **Entonces**:
    - el tamaño se cuenta mientras se copia y se aborta al pasar de 30 MB, aunque el declarado sea menor o desconocido;
    - el tipo y las dimensiones se leen de la cabecera **antes** de ocupar memoria con los píxeles;
    - la importación no bloquea la interfaz;
    - tras 20 s se aborta con "No hemos podido leer esta imagen.";
    - con los ficheros de prueba malformados (cabecera truncada, dimensiones falsas, bomba de descompresión PNG, GIF de miles de fotogramas, HEIC corrupto, flujo sin fin, nombre con `../`, dirección que apunta a los datos de la propia app) la app **nunca se cierra** y no escribe nada fuera de su zona temporal.
- **CA-007-15 Preparando la imagen**
  - **Dado** una importación que tarda más de 400 ms
  - **Cuando** está en curso
  - **Entonces** el editor muestra "Preparando imagen…" con el botón "Cancelar" (≥ 48 dp), dentro del recuadro de la vista previa y con una barra de progreso fina (DEV-39).
  - Mientras tanto, "+" y "Continuar" no hacen nada (sin verse desactivados, DEV-17).
  - "Cancelar" deja el editor como estaba.
- **CA-007-16 Ningún archivo huérfano (ADR-0011, cierra CL-004-3)**
  - **Dado** cualquier camino que deje una imagen sin uso:
    - eliminar la tarea desde la pantalla principal o desde el listado;
    - quitar o sustituir la imagen al editar;
    - "Quitar adjunto" en "Adjunto no disponible";
    - cancelar el editor o la importación;
    - error, tiempo agotado o falta de espacio al importar;
    - fallo al guardar;
    - la app muere con la cámara abierta.
  - **Cuando** termina la operación (una vez guardada, si la hay)
  - **Entonces** no queda ningún archivo de esa imagen (versiones completa, de pantalla y miniatura) ni ningún temporal. **Todos los caminos usan el mismo borrado.**
  - Si falla, en el siguiente arranque (después del primer fotograma, sin retrasar CA-001-09) se barren las imágenes que no pertenecen a ninguna tarea y todos los temporales. Una imagen que se está importando en ese momento nunca se barre.
- **CA-007-17 Las completadas conservan la imagen (D8)**
  - **Dado** que se completa una tarea con imagen
  - **Cuando** se consulta el almacenamiento
  - **Entonces** sus versiones se conservan y el barrido no las borra.
  - **[Pendiente, spec 010]** "Borrar archivos de tareas completadas", con el espacio que ocupan, antes de la v1.0.
  - *Enmienda (ADR-0012, aceptado 2026-09-26):* **se sustituye:** al completar una tarea con imagen, sus archivos se borran (con el mismo borrado de CA-007-16) y el barrido ya no respeta completadas. Desaparece el pendiente de la 010. Se implementa en la rama del ADR-0012, después de cerrar esta spec.
- **CA-007-18 Copia de seguridad (ADR-0004, R-10)**
  - **Dado** tareas con imágenes que ocupan más de 25 MB en total
  - **Cuando** Android hace la copia de seguridad en la nube
  - **Entonces** la copia incluye **siempre** las tareas y los ajustes. En esta spec las imágenes **no** entran en la copia en la nube; sí van en la transferencia directa entre dispositivos **en Android 12 o posterior**. En Android 9–11 la plataforma no separa la nube de la transferencia, así que tampoco se transfieren (ADR-0004, revisión de la spec 007; aclaración de T-007-25).
  - **[Pendiente, tarea antes de la v1.0]** Copia de las imágenes por prioridad, hasta 20 MB y solo cifrada de extremo a extremo (ADR-0004).
- **CA-007-19 Adjunto no disponible nunca cierra la app**
  - **Dado** que falta, está vacío o está corrupto un archivo de la imagen (p. ej., tras restaurar una copia sin imágenes)
  - **Cuando** se abre la app o se muestra la tarea
  - **Entonces** no se cierra ni se bloquea, y se ve la tarjeta "Adjunto no disponible" con **una sola acción**:
    - "Quitar adjunto", si la tarea tiene texto;
    - o "Eliminar tarea" (con la confirmación de CA-004-01), si no lo tiene.
  - Para poner otra imagen se edita la tarea (menú → Editar → (+)), como en CA-007-06.
  - La tarjeta, sobre el color de la nota: recuadro blanco con borde y sombra, el texto de la tarea (si lo hay), el aviso en rojo con el icono de imagen y la acción (DEV-40).
  - Si solo faltan la miniatura o la versión de pantalla, o no se pueden leer, se regeneran en segundo plano sin avisar; si tampoco se puede, se ve la tarjeta.
  - En el listado, la fila muestra la insignia "FOTO" o "IMAGEN" en lugar de la miniatura.

**Donde aparece la imagen**

- **CA-007-20 Tareas con imagen en el resto de la app**
  - **Dado** una tarea con imagen
  - **Cuando** aparece fuera de la pantalla principal
  - **Entonces**:
    - **Listado (cierra CA-006-02):** miniatura de 44 px, recortada, entre el asa y el texto, como el prototipo; decorativa para el lector.
    - **Sin texto:** en el listado, en la confirmación de eliminar (cierra CA-004-01) y en los anuncios, se usa "Foto" (de la cámara) o "Imagen" (de la galería).
    - **Completar y eliminar (cierra CL-003-4):** la rotura y el arrugado muestran la imagen recortada, como la tarea; con reducir movimiento, sus alternativas.

**Accesibilidad**

- **CA-007-21 Lectura**
  - **Dado** un lector de pantalla
  - **Cuando** lee una tarea con imagen
  - **Entonces** la imagen y el pie son **un único elemento**, con papel de imagen si es una foto:
    - pantalla principal: "Tarea actual: {texto}. Con foto" (o "Con imagen"), o "Tarea actual: Foto" (o "Imagen") si no hay texto (se reutilizan `attachmentPhoto`/`attachmentImage`, §7);
    - nunca se dice "imagen" dos veces: una imagen de la galería **no** lleva papel de imagen, porque su lectura ya dice "imagen" y TalkBack añadiría otra vez "imagen" (propietario, 2026-09-26);
    - con "Adjunto no disponible" (CA-007-19): "Tarea actual: {texto}. Adjunto no disponible", o "Tarea actual: Foto. Adjunto no disponible" sin texto;
    - activarla abre el visor, con la pista "ver la imagen entera";
    - acciones, en este orden: Completar tarea, Eliminar tarea;
    - fila del listado (cierra CA-006-18): "{n} de {total}: {texto}. Con foto", o "{n} de {total}: Foto" sin texto;
    - anuncios de completar y eliminar sin texto (cierra CL-003-8): "Tarea completada. Siguiente: Foto".
  - En el visor, la imagen tiene las acciones Ampliar, Reducir y Ajustar al ancho (solo las aplicables, en ese orden) y las de desplazamiento cuando se puede desplazar. El nivel se lee como valor ("Ampliación por 2,5": "por" escrito, para que todos los lectores lo digan igual; propietario, 2026-09-27).
  - Con teclado físico: + / − / 0 amplían, reducen y ajustan; las flechas desplazan.
- **CA-007-22 Foco y anuncios**
  - **Dado** un lector de pantalla activo
  - **Cuando** ocurre cada acción
  - **Entonces** se hace **un único anuncio** y el foco queda donde dice la tabla:

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Abrir la hoja "Añadir" | Título "Añadir a la tarea" (encabezado) | El nombre de la hoja |
    | Vuelve de la cámara o del selector con imagen | La vista previa | "Foto añadida" o "Imagen añadida" |
    | Cierra la hoja "Añadir" sin elegir (X, atrás o fuera) | El botón (+) | Ninguno (añadida en T-007-25) |
    | Cancela la cámara o el selector | El botón (+) | Ninguno |
    | "Preparando imagen…" | "Cancelar" | "Preparando imagen…" |
    | Quitar adjunto | El botón (+) | "Adjunto quitado" |
    | Error al importar | El botón (+) | El texto del error |
    | Abrir el visor | La imagen | "Imagen de la tarea" (nombre de la pantalla) |
    | Ampliar o reducir | No se mueve | El nuevo nivel |
    | Cerrar el visor | La tarea actual | Ninguno |

- **CA-007-23 Reducir movimiento y texto grande**
  - **Dado** "reducir movimiento" o el texto al 200 %
  - **Cuando** se usan la hoja, el editor, la pantalla principal o el visor
  - **Entonces**:
    - con reducir movimiento, el zoom salta sin animarse, el visor aparece con un fundido (400 ms) y "Preparando imagen…" no se anima;
    - con el texto al 200 % en un móvil de 360 dp:
      - las filas de la hoja crecen en alto;
      - el pie se limita a ×1,6 y 3 líneas;
      - el editor con imagen se desplaza;
      - "Adjunto no disponible" y "Preparando imagen…" se ven enteros;
      - nada se corta y todos los botones miden ≥ 48 dp.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-007-1 | No hay ninguna app de cámara (tablet, cámara desactivada) | Aviso "No hay ninguna app de cámara disponible."; el editor queda como estaba |
| CL-007-2 | Captura larga (1080 × 20 000) | Pantalla principal: recortada, como cualquier imagen. Visor: al ancho y con desplazamiento vertical; se lee el texto a ×1 |
| CL-007-3 | Sin espacio libre al importar o al guardar | "Tu teléfono no tiene espacio libre" (con "Reintentar" al guardar, como `editorSaveError`); no se crea la tarea y no quedan temporales |
| CL-007-4 | Imagen con transparencia (PNG, WebP) | Las zonas transparentes se ven sobre blanco |
| CL-007-5 | Foto de 50 MP de la cámara del móvil | Se acepta (≤ 64 MP) y se guarda reducida a 24 MP |
| CL-007-6 | Imagen de Google Fotos que solo está en la nube, sin conexión | "No hemos podido leer esta imagen."; el editor queda como estaba |
| CL-007-7 | Android mata la app con la cámara abierta | Al volver, se ve el editor sin imagen (o la tarea actual si pasaron 10 min, CA-001-12); la foto de la cámara se descarta y no queda ninguna copia |
| CL-007-8 | Doble toque rápido en "Continuar" con imagen | Se crea una sola tarea |
| CL-007-9 | Listado con 500 tareas, todas con imagen | Se cumple CA-006-20 |
| CL-007-10 | Registros (logs) en *release* | No se registra ninguna dirección, nombre, ruta ni metadato de una imagen |
| CL-007-11 | La miniatura de la app en "Recientes" | Muestra la imagen. **[Pendiente, spec 010]** Ocultarla mientras se ve un adjunto |
| CL-007-12 | Web de pruebas (ADR-0010) | "Hacer foto" y "Subir imagen" usan el selector del navegador; las imágenes se guardan solo en memoria, como las tareas |

## 5. Estados vacíos y de error

Los errores de importación aparecen como aviso sobre el editor (se anuncian solos), el editor queda como estaba y el foco vuelve a (+).

| Estado | Texto |
|---|---|
| Tipo no admitido | "Este tipo de imagen no se admite. Prueba con una foto JPEG, PNG o HEIC." |
| Archivo demasiado grande | "La imagen es demasiado grande (máx. 30 MB)." |
| Demasiada resolución | "La imagen tiene demasiada resolución (máx. 64 megapíxeles)." |
| Ilegible, corrupta o tiempo agotado | "No hemos podido leer esta imagen. Prueba con otra." |
| Sin app de cámara | "No hay ninguna app de cámara disponible." |
| Sin espacio | `storageErrorNoSpace` |
| Adjunto perdido | CA-007-19 |

## 6. Accesibilidad

- Lectura, foco y anuncios: CA-007-21 y CA-007-22. La miniatura del listado es decorativa.
- Alternativas a los gestos del visor (WCAG 2.5.1 y 2.5.7): el doble toque por pasos llega a ×8 con un dedo, y además hay acciones del lector y teclas. El desplazamiento tiene acciones de desplazamiento. La lupa del sistema (triple toque) sigue funcionando.
- El visor no tiene modo inmersivo: "Cerrar" siempre se ve y siempre se puede enfocar.
- Contraste:
  - logotipo y menú con fondo blanco sobre la imagen (como el prototipo);
  - pie blanco sobre negro (18,9:1);
  - el anillo de foco del teclado lleva borde blanco y negro para verse sobre cualquier foto.
- Objetivos táctiles ≥ 48 dp: "Quitar adjunto" (40 en el prototipo, DEV-36), X de la hoja, "Cerrar" del visor, "Cancelar", "Quitar adjunto" y "Eliminar tarea".
- Orientación (WCAG 1.3.4): el visor gira (CA-007-11); el resto de la app queda en vertical, como excepción registrada (D10).
- **[Pendiente P-5, v1.1]** Descripción de la imagen escrita por el usuario.

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `attachSheetTitle` | Añadir a la tarea | Add to the task | Título y nombre de la hoja |
| `attachSheetClose` | Cerrar | Close | X de la hoja |
| `attachTakePhoto` / `attachTakePhotoHint` | Hacer foto / Con la cámara · va arriba del todo | Take photo / With the camera · goes on top | El lector lee "Hacer foto. Con la cámara, va arriba del todo" |
| `attachPickImage` / `attachPickImageHint` | Subir imagen / Desde tu galería · va arriba del todo | Upload image / From your gallery · goes on top | |
| `attachPickFile` / `attachPickFileHint` | Subir archivo / PDF, Word, Excel… · va arriba del todo | Upload file / PDF, Word, Excel… · goes on top | DEV-02 |
| `attachUrl` / `attachUrlHint` | Cargar URL / Una página web · va arriba del todo | Load URL / A web page · goes on top | |
| `editorAttachmentPlaceholder` | Añade un texto (opcional) | Add some text (optional) | Definida en la spec 005 |
| `editorRemoveAttachment` | Quitar adjunto | Remove attachment | Definida en la spec 005 |
| `imagePreparing` | Preparando imagen… | Preparing image… | |
| `imagePreparingCancel` | Cancelar | Cancel | |
| `attachmentPhoto` | Foto | Photo | Tarea sin texto (listado, eliminar, anuncios); insignia "FOTO" |
| `attachmentImage` | Imagen | Image | Ídem, desde la galería |
| `a11yWithPhoto` | {text}. Con foto | {text}. With photo | Lectura con texto |
| `a11yWithImage` | {text}. Con imagen | {text}. With image | |
| `a11yPhotoAdded` | Foto añadida | Photo added | |
| `a11yImageAdded` | Imagen añadida | Image added | |
| `a11yAttachmentRemoved` | Adjunto quitado | Attachment removed | |
| `imageOpenHint` | ver la imagen entera | see the whole image | Pista de activación |
| `viewerTitle` | Imagen de la tarea | Task image | Nombre de la pantalla del visor |
| `viewerClose` | Cerrar | Close | |
| `zoomIn` / `zoomOut` / `zoomFit` | Ampliar / Reducir / Ajustar al ancho | Zoom in / Zoom out / Fit to width | |
| `a11yZoomLevel` | Ampliación por {level} | Zoom times {level} | Solo para el lector; `level` con formato local (2,5 / 2.5). Antes "×{level}" (propietario, 2026-09-27) |
| `errImageType` | Este tipo de imagen no se admite. Prueba con una foto JPEG, PNG o HEIC. | This image type isn't supported. Try a JPEG, PNG or HEIC photo. | |
| `errImageTooBig` | La imagen es demasiado grande (máx. {max} MB). | The image is too large (max {max} MB). | |
| `errImageTooManyPixels` | La imagen tiene demasiada resolución (máx. {max} megapíxeles). | The image resolution is too high (max {max} megapixels). | |
| `errImageUnreadable` | No hemos podido leer esta imagen. Prueba con otra. | We couldn't read this image. Try another one. | |
| `errNoCamera` | No hay ninguna app de cámara disponible. | There's no camera app available. | |
| `attachmentMissing` | Adjunto no disponible | Attachment unavailable | |
| `a11yAttachmentMissing` | {text}. Adjunto no disponible | {text}. Attachment unavailable | Lectura de la tarea con el adjunto perdido; `text` = texto de la tarea o "Foto"/"Imagen" (CA-007-19/21). Añadida en la implementación (propietario, 2026-09-26) |

Se reutilizan `storageErrorNoSpace`, `retry`, `editorCancel`, `deleteA11yAction` ("Eliminar tarea"), `attachButton` y las lecturas de las specs 001, 003, 004 y 006 con `{text}` = "Foto"/"Imagen" cuando no hay texto. **No** se añaden `cameraPermissionRationale` ni `openSettings` (en Android no hay permiso; quedan para F-iOS).

## 8. Fuera de alcance

- Brillo máximo (D10); editar o recortar la imagen; varias imágenes por tarea; girar fuera del visor.
- Descripción alternativa escrita por el usuario (P-5, v1.1).
- La copia de las imágenes en la nube (tarea propia antes de la v1.0) y el ajuste de "Recientes" (spec 010).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-26, propietario]** En la pantalla principal, la imagen recortada como el prototipo; al tocarla, visor a pantalla completa al ancho, con desplazamiento vertical y zoom opcional (DEV-35, DEV-37).
- **[Resuelto 2026-09-26, propietario]** Girar solo en el visor (D10 enmendada).
- **[Resuelto 2026-09-26, propietario]** Pantalla encendida hasta 10 minutos sin tocarla.
- **[Resuelto 2026-09-26, propietario]** "Adjunto no disponible" sin "Sustituir": la interacción, lo más simple posible (una sola acción).
- **[Resuelto 2026-09-26, propietario]** Un solo adjunto por tarea (imagen, foto, documento o URL). No hay botón "Sustituir" en ninguna parte: en el editor, (+) sigue visible con un adjunto y lo que se cargue sustituye al que había (CA-007-04).
- **[Resuelto 2026-09-26, propietario, con la recomendación de la revisión]**:
  - cámara del sistema sin permisos;
  - imágenes fuera de la copia en la nube por ahora;
  - "Foto"/"Imagen" sin guardar el nombre original;
  - editar no mueve la tarea;
  - "Subir archivo" y "Cargar URL" inactivas hasta 008 y 009;
  - zoom por pasos con acciones accesibles y sin modo inmersivo;
  - pie de 3 líneas;
  - P-5 en la v1.1;
  - tipos por contenido (sin AVIF, sin HEIC en Android 8);
  - completadas conservan la imagen, con borrado en la 010;
  - "Recientes" en la 010;
  - visor y errores con los componentes existentes.
