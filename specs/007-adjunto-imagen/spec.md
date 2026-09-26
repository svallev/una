# Spec 007: Tareas con foto o imagen (visor a pantalla completa)

- **Estado:** En revisión
- **Reglas de producto:** R3 (foto con la cámara, imagen de la galería), R5, **propuesta de valor 2**
- **Pantallas del prototipo:** 9 "Añadir (+)", 3 "Nueva tarea" (con adjunto)
- **Decisiones y ADR:** D5, D8, D10, ADR-0002, ADR-0004; modelo de amenazas T-3
- **Dependencias:** 001, 002, 005

## 1. Objetivo

Que un horario, un mapa o unos pasos fotografiados queden **a pantalla completa y visibles nada más abrir la app**, sustituyendo el truco de ponerlos como fondo de la pantalla de bloqueo.

## 2. Historias de usuario

- **HU-007-1** Como asistente a un festival, quiero hacer una foto del horario y verla al abrir la app sin buscarla.
- **HU-007-2** Como usuario, quiero ampliar la imagen para leer los detalles.
- **HU-007-3** Como usuario, quiero que la pantalla no se apague mientras la consulto.
- **HU-007-4** Como usuario, quiero que la foto no guarde mi ubicación.

## 3. Criterios de aceptación

- **CA-007-01 Hoja "Añadir a la tarea"**
  - **Dado** el editor (nueva tarea, o editar una tarea que no es web)
  - **Cuando** pulsa (+)
  - **Entonces** sube la hoja "Añadir a la tarea" con: "Hacer foto — Con la cámara · va arriba del todo", "Subir imagen — Desde tu galería · va arriba del todo", "Subir archivo — PDF, Word, Excel… · va arriba del todo" y "Cargar URL — Una página web · va arriba del todo".
- **CA-007-02 Hacer foto**
  - **Dado** la hoja
  - **Cuando** elige "Hacer foto"
  - **Entonces** se pide el permiso de cámara **solo en ese momento** (si no se concedió antes), se abre la cámara y la foto aparece en el editor.
- **CA-007-03 Subir imagen sin permisos amplios**
  - **Dado** la hoja
  - **Cuando** elige "Subir imagen"
  - **Entonces** se abre el selector de fotos del sistema (sin pedir acceso a toda la galería) y la imagen elegida aparece en el editor.
- **CA-007-04 Editor con imagen**
  - **Dado** una imagen elegida
  - **Cuando** se muestra el editor
  - **Entonces** se ven la vista previa, el botón "Quitar adjunto", el campo "Añade un texto (opcional)" y "Continuar" (o "Guardar" si no hay otras tareas).
- **CA-007-05 Siempre arriba (R5)**
  - **Dado** el editor con una imagen
  - **Cuando** pulsa "Continuar"
  - **Entonces** la tarea se crea como **actual** sin preguntar la posición.
- **CA-007-06 Copia dentro de la app y sin metadatos**
  - **Dado** una imagen importada
  - **Cuando** se guarda
  - **Entonces** se guarda una **copia** en el almacenamiento privado de la app, **sin EXIF, GPS ni XMP**, con la orientación corregida; si se borra el original de la galería, la tarea sigue mostrando la imagen.
- **CA-007-07 Visible al abrir (propuesta 2)**
  - **Dado** que la tarea actual tiene una imagen
  - **Cuando** se abre la app en frío
  - **Entonces** la imagen se ve **completa** (ajustada a la pantalla) en < 1 s, sin ningún toque; si hay texto, aparece como pie.
- **CA-007-08 Zoom y desplazamiento (D10)**
  - **Dado** la imagen en la pantalla principal
  - **Cuando** pellizca o toca dos veces
  - **Entonces** se amplía (hasta ×8) y se puede desplazar; doble toque de nuevo o pellizco hacia fuera → vuelve a ajustarse a la pantalla. Mientras está ampliada, se ocultan el logotipo, el menú y el botón de completar (modo inmersivo); un toque simple los muestra u oculta.
- **CA-007-09 Pantalla encendida (D10)**
  - **Dado** que el ajuste "Mantener la pantalla encendida con adjuntos" está activo (por defecto sí)
  - **Cuando** la tarea actual con imagen está visible
  - **Entonces** la pantalla no se apaga por inactividad; al salir de la pantalla, pasar a segundo plano o cambiar a una tarea de texto, vuelve el comportamiento normal.
- **CA-007-10 Límites y tipos**
  - **Dado** un archivo elegido
  - **Cuando** es JPEG, PNG, HEIC/HEIF, WebP o GIF (se toma el primer fotograma), ≤ 30 MB y ≤ 50 megapíxeles
  - **Entonces** se acepta; si no, se muestra el error correspondiente (§5) y el editor queda como estaba. **SVG no se admite.**
- **CA-007-11 Las completadas conservan la imagen (D8)**
  - **Dado** que se completa una tarea con imagen
  - **Cuando** se consulta el almacenamiento
  - **Entonces** los archivos de la imagen se conservan.
- **CA-007-12 Eliminar borra los archivos (spec 004, ADR-0011)**
  - **Dado** que se elimina una tarea con imagen
  - **Cuando** se confirma la eliminación
  - **Entonces** después de la transacción se borran todos sus archivos (original, versión de pantalla y miniatura): no queda nada en `attachments/<id>/`. Si falla, al siguiente arranque (después del primer fotograma, sin retrasar CA-001-09) se barren los directorios de adjuntos cuyo id no está en la BD (CL-004-3). Se hereda en las specs 008 y 009 (PDF, documentos y capturas de páginas).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-007-1 | Permiso de cámara denegado (o denegado para siempre) | Mensaje con explicación y botón "Abrir Ajustes"; en Android se puede usar la cámara del sistema por intent sin permiso **[Suposición: se valida en S5]** |
| CL-007-2 | Imagen panorámica o muy alta (captura larga) | Ajustada al ancho con desplazamiento vertical en el visor |
| CL-007-3 | Sin espacio libre | Error "Tu teléfono no tiene espacio libre"; no se crea la tarea |
| CL-007-4 | Tras restaurar un backup de Android sin adjuntos (ADR-0004) | La tarea muestra "Adjunto no disponible" con "Sustituir" y "Eliminar" |
| CL-007-5 | Imagen con perfil de color amplio (Display P3) o HDR | Se muestra correctamente (conversión a sRGB al recodificar si hace falta) |
| CL-007-6 | Importación lenta (imagen de 50 MP) | Indicador "Preparando imagen…" en el editor; se puede cancelar; la UI no se bloquea |

## 5. Estados de error

| Estado | Texto |
|---|---|
| Tipo no admitido | "Este tipo de imagen no se admite." |
| Demasiado grande | "La imagen es demasiado grande (máx. 30 MB)." |
| Ilegible o corrupta | "No hemos podido leer esta imagen." |
| Sin espacio | "Tu teléfono no tiene espacio libre." |
| Adjunto perdido | "Adjunto no disponible" + "Sustituir" / "Eliminar" |

## 6. Accesibilidad

- Imagen con descripción: el texto de la tarea si lo hay; si no, "Imagen adjunta". **[Pendiente P-5]** ¿Permitir que el usuario escriba una descripción alternativa?
- Zoom accesible: acciones "Ampliar" y "Reducir" y el zoom del sistema; el doble toque no es la única vía.
- El modo inmersivo no oculta los controles al lector de pantalla (siguen en la semántica).
- La hoja "Añadir" es un diálogo modal; filas ≥ 44 pt.

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `attachSheetTitle` | Añadir a la tarea | Add to the task |
| `attachTakePhoto` / `attachTakePhotoHint` | Hacer foto / Con la cámara · va arriba del todo | Take photo / With the camera · goes on top |
| `attachPickImage` / `attachPickImageHint` | Subir imagen / Desde tu galería · va arriba del todo | Upload image / From your gallery · goes on top |
| `attachPickFile` / `attachPickFileHint` | Subir archivo / PDF, Word, Excel… · va arriba del todo | Upload file / PDF, Word, Excel… · goes on top |
| `attachUrl` / `attachUrlHint` | Cargar URL / Una página web · va arriba del todo | Load URL / A web page · goes on top |
| `imagePreparing` | Preparando imagen… | Preparing image… |
| `imageAlt` | Imagen adjunta | Attached image |
| `errImageType` | Este tipo de imagen no se admite. | This image type isn't supported. |
| `errImageTooBig` | La imagen es demasiado grande (máx. {max} MB). | The image is too large (max {max} MB). |
| `errImageUnreadable` | No hemos podido leer esta imagen. | We couldn't read this image. |
| `errNoSpace` | Tu teléfono no tiene espacio libre. | Your phone is out of storage. |
| `attachmentMissing` | Adjunto no disponible | Attachment unavailable |
| `attachmentReplace` | Sustituir | Replace |
| `cameraPermissionRationale` | Para hacer la foto de tu tarea necesitamos la cámara. La foto se queda en tu teléfono. | To take a photo for your task we need the camera. The photo stays on your phone. |
| `openSettings` | Abrir Ajustes | Open Settings |
| `zoomIn` / `zoomOut` | Ampliar / Reducir | Zoom in / Zoom out |

## 8. Fuera de alcance

Brillo máximo y giro a horizontal (D10, futuro); edición o recorte de la imagen; varias imágenes por tarea.
