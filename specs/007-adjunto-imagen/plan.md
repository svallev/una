# Plan técnico — Spec 007: Tareas con foto o imagen (visor a pantalla completa)

- **Spec:** `specs/007-adjunto-imagen/spec.md` (estado: Aprobada, 2026-09-26)
- **ADR aplicables:** ADR-0002 (repositorio y esquema v1), ADR-0004 (copias, R-10), ADR-0011 (eliminar sin deshacer), ADR-0010 (web de pruebas); decisiones de los spikes I-1, I-2, I-3, I-4 y H-6/H-7
- **Estado del plan:** Aprobado (propietario, 2026-09-26). En implementación: lo que cambió al implementar está en el §8
- **Rama:** `feat/007-adjunto-imagen`, desde `main` (la 006 ya está fusionada)

## 1. Resumen del enfoque

- **Sin dependencias nuevas de Dart ni de Android.** La cámara, el selector de fotos, la limpieza de la imagen y la pantalla encendida se hacen con un **canal nativo propio en Kotlin** (`MainActivity`), con las API del sistema. Se descarta `image_picker` (ver §7).
- **Dominio (Dart puro):**
  - entidad `Attachment` (id, `kind = image`, `origin = camera | gallery`, `mime`, `byteSize`, `width`, `height`, rutas relativas) y `Task.attachment` (0..1);
  - `validateTaskContent(text, hasAttachment)`: con imagen, el texto es opcional (CA-007-04);
  - `ImageTypeSniffer`: decide el tipo **por los primeros bytes** (JPEG, PNG, WebP, GIF, HEIC/HEIF por la marca `ftyp`); rechaza SVG, AVIF, HTML, ZIP, ejecutables… (CA-007-13);
  - puertos `AttachmentStore` (archivos de la app) e `ImageImporter` (cámara, selector y limpieza, nativo);
  - casos de uso: `CreateTask` con adjunto (siempre arriba, R5), `EditTask` (texto y adjunto, conserva `rank` y `colorKey`; sustituye a `UpdateTaskText`), y **un único servicio de borrado** `AttachmentJanitor` (`discard(id)` y `sweep()`) que usan `DeleteCurrentTask`, `DeletePendingTask`, el editor y la importación (CA-007-16, cierra el pendiente de la 006).
- **Datos:**
  - **Sin cambios de esquema:** la tabla `attachments` ya existe en la v1 con todas las columnas necesarias (`originalName` y `sha256` quedan nulos).
  - `DriftTaskRepository`: la tarea actual y la cola se leen con su adjunto (una consulta con `LEFT JOIN`, en el isolate principal, I-1); `insert` y `updateTask` guardan tarea y adjunto en **una transacción**; `delete` borra la fila del adjunto en la misma transacción que la marca de borrado; `attachmentIds()` para el barrido.
  - `FileAttachmentStore`: los archivos van en `files/attachments/<id>/` (`getApplicationSupportDirectory`), **fuera de `app_flutter/`**, que es lo que entra en la copia en la nube (CA-007-18). Los temporales, en `cache/import/`.
- **Nativo (Kotlin, `MainActivity` + `ImageImport.kt`):**
  1. **Hacer foto:** `ACTION_IMAGE_CAPTURE` con `EXTRA_OUTPUT` = URI de un `FileProvider` **no exportado** sobre un único archivo de `cache/import/`, con permiso de escritura puntual. Sin permiso `CAMERA` (CA-007-02). Si no hay app: `ActivityNotFoundException` → `errNoCamera` (CL-007-1).
  2. **Subir imagen:** `MediaStore.ACTION_PICK_IMAGES` si existe (Android 13+, o 11–12 con la extensión de SDK 2); si no, `ACTION_OPEN_DOCUMENT` con `image/*` (CA-007-03).
  3. **Copia acotada:** lee la URI con `ContentResolver` en un hilo de fondo, contando bytes y abortando al pasar de 30 × 10⁶ (CA-007-14). Nunca abre rutas `file://` ni URIs de nuestro propio `FileProvider` o de `/data/data/<app>` (T-3). No usa el nombre del archivo.
  4. **Limpieza (I-4):**
     - dimensiones de la cabecera antes de reservar memoria (`ImageDecoder.OnHeaderDecodedListener` en Android 9+; `BitmapFactory` con `inJustDecodeBounds` en Android 8) → rechazo si > 64 MP;
     - decodificación con la orientación aplicada, en **sRGB** y reducida a ≤ 24 MP (`setTargetSize` exacto en Android 9+; en Android 8, `inSampleSize` + `ExifInterface` del sistema, que puede dejarla algo por debajo de 24 MP);
     - GIF: solo el primer fotograma; transparencias sobre blanco (CL-007-4);
     - **Android 14+:** se quita el *gainmap* (`setGainmap(null)`) antes de codificar, porque `Bitmap.compress` lo escribiría (Ultra HDR);
     - se codifica en JPEG con `Bitmap.compress` (sin metadatos por construcción): **versión completa** en teselas de ≤ 4096 × 4096 px (límite de textura de la GPU; una captura de 1080 × 20 000 da 5 franjas), **versión de pantalla** recortada al tamaño físico de la pantalla en vertical (I-2) y **miniatura** de 176 px de lado corto (44 dp × 4);
     - todo en un directorio de preparación `cache/import/<id>/`; cancelable; 20 s como máximo (el límite lo pone Dart).
  5. **Pantalla encendida:** `FLAG_KEEP_SCREEN_ON` activado o desactivado desde Dart.
  6. Si Android mata la app con la cámara abierta, el resultado llega a una actividad nueva sin llamada pendiente: se ignora y el temporal lo borra el barrido (CL-007-7).
- **Estado (Riverpod):**
  - `ImageImportController` (por editor): estados `idle | preparing | ready(StagedImage) | error`, cancelación, "Preparando imagen…" solo tras 400 ms, y un único vuelo a la vez;
  - `KeepScreenOnController`: se activa con la tarea actual con imagen o el visor en primer plano y el ajuste `keepScreenOn` (por defecto `true`, en `SettingsRepository`); un `Listener` en la raíz reinicia los 10 min con cada toque; se desactiva al cambiar de pantalla, pasar a segundo plano o a una tarea sin imagen (CA-007-12).
- **Presentación:**
  - `AttachSheet` (hoja "Añadir a la tarea") con `showUnaSheet` y `SheetRow` de dos líneas; "Subir archivo" y "Cargar URL" sin efecto (DEV-18).
  - Editor: vista previa (versión de pantalla, `BoxFit.cover`) con "Quitar adjunto" de 48 dp, texto opcional, "Preparando imagen…" + "Cancelar", avisos de error, foco y anuncios de CA-007-22; guardar con imagen en modo `create` salta la hoja de posición (CA-007-05).
  - `CurrentTaskScreen`: imagen a sangre (`Image.file` de la versión de pantalla, `gaplessPlayback`, sin animación de aparición), logotipo y menú con fondo blanco, pie (recuadro negro, 22 px, 800, 3 líneas, a 146 px del borde, escala de texto limitada a ×1,6), un único nodo semántico con papel de imagen, pista y acciones (CA-007-08, CA-007-21).
  - `ImageViewerScreen`: ruta propia con `InteractiveViewer` controlado por un `TransformationController`:
    - a ×1, imagen al ancho y desplazamiento solo vertical (`panAxis: vertical`); ampliada, libre;
    - doble toque por pasos ×1 → ×2,5 → ×8 → ×1 centrado en el punto (animado; salto con reducir movimiento);
    - teselas decodificadas con `cacheWidth` según el nivel (a ×1, al ancho de la pantalla) para no ocupar memoria de más;
    - acciones del lector Ampliar/Reducir/Ajustar al ancho, valor "Ampliación ×2,5" y desplazamiento; atajos + / − / 0 y flechas;
    - gira: `SystemChrome.setPreferredOrientations` con todas al abrirlo y solo `portraitUp` al cerrarlo (el manifiesto sigue en vertical; `setRequestedOrientation` lo sustituye mientras tanto) (CA-007-11);
    - fundido de 400 ms con reducir movimiento.
  - "Adjunto no disponible" (`MissingAttachmentCard`): si falta o no se puede decodificar la versión completa; si solo faltan las derivadas, se regeneran en segundo plano desde la completa (CA-007-19).
  - Listado: miniatura de 44 px (decorativa) o insignia "FOTO"/"IMAGEN"; textos "Foto"/"Imagen" en filas, confirmación de eliminar y anuncios (CA-007-20/21).
  - Completar y eliminar: la cara de la nota ya se captura como imagen (I-3); con adjunto, la cara es la imagen recortada, como en la pantalla (CL-003-4).
- **Web de pruebas (CL-007-12):** implementación de `ImageImporter` con `<input type=file>` (con `capture` para "Hacer foto") mediante `dart:js_interop` (sin paquetes), limpieza con `createImageBitmap` + `canvas.toBlob('image/jpeg')` y `AttachmentStore` en memoria.
- **Barrido (CA-007-16):** tras el primer fotograma (`addPostFrameCallback` + `Future.delayed`), `AttachmentJanitor.sweep()` borra los directorios de `attachments/` que no están en la BD y todo `cache/import/` salvo las importaciones en curso (registro en memoria).

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `entities/attachment.dart`, `entities/task.dart`, `entities/image_type.dart` (sniffer), `ports/attachment_store.dart`, `ports/image_importer.dart`, `ports/task_repository.dart`, `usecases/create_task.dart`, `usecases/edit_task.dart` (sustituye a `update_task_text.dart`), `usecases/delete_current_task.dart`, `usecases/delete_pending_task.dart`, `services/attachment_janitor.dart` | Entidad, invariante texto-o-adjunto, tipos por contenido, puertos, casos de uso y servicio único de borrado |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart`, `attachments/file_attachment_store.dart`, `attachments/memory_attachment_store.dart`, `import/native_image_importer.dart`, `import/web_image_importer.dart`, `platform/screen_awake.dart` | Lectura con adjunto, transacciones, archivos, canal nativo y web |
| Estado | `features/attachments/image_import_controller.dart`, `features/attachments/keep_screen_on_controller.dart`, `app/providers.dart` | Importación, pantalla encendida, proveedores |
| Presentación | `features/attachments/` (`attach_sheet.dart`, `attachment_preview.dart`, `image_viewer_screen.dart`, `missing_attachment_card.dart`, `task_image.dart`); `editor/task_editor_screen.dart`, `current_task/current_task_screen.dart`, `task_list/task_list_row.dart`, `delete/…`, `complete/…`, `app/una_app.dart` (barrido y `Listener`) | Hoja, editor, pantalla principal, visor, listado, animaciones |
| Nativo | `MainActivity.kt`, `ImageImport.kt`, `ImageSanitizer.kt`, `AndroidManifest.xml` (`<provider>` no exportado), `res/xml/import_paths.xml` | Cámara, selector, copia acotada, limpieza, pantalla encendida |
| l10n | `app_es.arb`, `app_en.arb` | Claves de la §7 de la spec |
| Tokens | `design/tokens.json` → `tokens.g.dart` | Pie (22 px, 800, 146 px, ×1,6), miniatura 44, `importIndicatorDelay` 400 ms, `viewerZoom` 250 ms, zoom (2,5 y 8), texto y campo del editor con adjunto (24 px, 96 px); el fundido de 400 ms reutiliza `reducedMotionFade` (§8) |
| Documentos | `docs/architecture.md` §2/§4, `docs/PLAN.md` D18, ADR-0004 | 64 MP y 24 MP sin límite de lado (la spec manda); rutas de los adjuntos y copia |

## 3. Modelo de datos y migraciones

**Sin cambios de esquema** (`schemaVersion` sigue en 1). Se usan las columnas de `attachments` que ya existen:

| Columna | Valor en la 007 |
|---|---|
| `kind` / `origin` | `image` / `camera` o `gallery` (decide "Foto" o "Imagen") |
| `mime` | `image/jpeg` (lo guardado); el tipo de entrada no se guarda |
| `relPath` | `attachments/<id>/full` (prefijo; teselas `full-<fila>-<col>.jpg`, calculadas con `width`, `height` y 4096) |
| `displayRelPath` / `thumbRelPath` | `attachments/<id>/screen.jpg` / `attachments/<id>/thumb.jpg` |
| `byteSize`, `width`, `height` | De la versión completa |
| `originalName`, `sha256`, `sourceUrl`… | Nulos |

- **Invariante nueva en el dominio:** texto no vacío **o** adjunto. `Task.text` ya es anulable.
- **Copia de seguridad:** `files/` no está en `cloud-backup` (Android 12+) ni en las reglas de Android 9–11; sí en `device-transfer` (Android 12+). **[Hecho, plataforma]** En Android 9–11 no existe una regla solo para la transferencia entre dispositivos, así que ahí las imágenes tampoco se transfieren; lo anoto en ADR-0004.
- **Restaurar una copia sin imágenes:** la fila del adjunto existe y los archivos no → "Adjunto no disponible" (H-7, CA-007-19). El barrido nunca borra filas, solo archivos sin fila.

## 4. Dependencias nuevas

**Ninguna** en Dart. En Android, `FileProvider` es de `androidx.core`, que ya llega de forma transitiva con el *embedding* de Flutter. **[Suposición]** Lo compruebo en T-007-05; si no llegara, la alternativa es un `ContentProvider` propio de unas 60 líneas (sin dependencia) en vez de declarar `androidx.core`.

Descartados: `image_picker` (copia el archivo entero sin límite antes de devolverlo, conserva el nombre original y su recuperación tras la muerte del proceso no encaja con CL-007-7), `image` (codificar en Dart es 15 veces más lento, H-4), `photo_view` y `wakelock_plus` (lo cubren `InteractiveViewer` y una línea de Kotlin).

## 5. Estrategia de tests

**Ficheros de prueba:** `tools/fixtures/gen_image_fixtures.py` (Pillow, en el Mac; `sips` para el HEIC) genera y se versionan en `app/integration_test/fixtures/`: foto con EXIF/GPS/XMP/miniatura interna y las 8 orientaciones, PNG con `tEXt` y transparencia, WebP con EXIF, GIF de 5 000 fotogramas, HEIC y HEIC corrupto, JPEG con datos tras `FFD9`, JPEG Ultra HDR (si el emulador lo produce), 63 MP y 65 MP, 50 MP, captura de 1080 × 20 000, cabecera truncada, dimensiones falsas, bomba PNG, SVG con extensión `.png`, AVIF, 31 MB.

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-007-13 (tipos) | Unitario del sniffer con los primeros bytes de cada formato y de los rechazados | `test/domain/image_type_test.dart` |
| CA-007-04/06, invariante | Unitarios de `validateTaskContent`, `CreateTask` con adjunto (siempre arriba), `EditTask` (añadir, sustituir, quitar; conserva `rank` y color; sin texto ni imagen → error) | `test/domain/create_task_test.dart`, `edit_task_test.dart` |
| CA-007-16/17 | Unitarios de `AttachmentJanitor` con almacén falso: cada camino llama a `discard`; `sweep` borra huérfanos y temporales, respeta las completadas y las importaciones en curso; fallo de borrado → barrido | `test/domain/attachment_janitor_test.dart`, `delete_*_test.dart` |
| Datos | Contrato del repositorio (memoria y drift): tarea con adjunto en la actual y en la cola, transacción de alta y de edición, `delete` borra la fila del adjunto, `attachmentIds` | `test/data/repository_contract_test.dart` |
| Datos | `FileAttachmentStore` en un directorio temporal: `commit` atómico (rename), `discard`, `sweep`, estado de los archivos (ok, derivadas perdidas, perdido) | `test/data/file_attachment_store_test.dart` |
| CA-007-18 | Test que lee las reglas XML de copia: `files/` fuera de la nube en 9–11 y 12+, dentro de `device-transfer` | `test/app/backup_rules_test.dart` |
| CA-007-01/04/15/22 | Widget con `ImageImporter` falso: hoja y sus filas, vista previa, texto opcional, sustituir, quitar, "Preparando imagen…" a los 400 ms, cancelar, errores, foco y anuncios | `test/features/attachments/attach_sheet_test.dart`, `editor_image_test.dart` |
| CA-007-05/06, CL-007-8 | Widget de flujo: crear con imagen desde la principal y desde el listado (fila 1, resaltada, foco); editar sin mover; doble toque en "Continuar" | `test/features/attachments/image_flow_test.dart` |
| CA-007-08/21 | Widget: imagen a sangre, logotipo y menú con fondo, pie de 3 líneas, lectura y acciones | `test/features/attachments/current_task_image_test.dart` |
| CA-007-09/10/11/23 | Widget del visor: ancho completo, desplazamiento vertical, doble toque por pasos y centrado, pellizco, acciones del lector y teclas, orientaciones pedidas al abrir y cerrar, reducir movimiento | `test/features/attachments/image_viewer_test.dart` |
| CA-007-12 | Unitario de `KeepScreenOnController` con reloj falso (10 min, toques, cambio de pantalla, segundo plano) | `test/features/attachments/keep_screen_on_test.dart` |
| CA-007-19 | Widget: falta la completa, está corrupta, faltan las derivadas (regenera sin avisar); acciones de la tarjeta | `test/features/attachments/missing_attachment_test.dart` |
| CA-007-20, CL-007-9 | Widget del listado (miniatura, insignia, textos) y de completar/eliminar con imagen | `test/features/task_list/…`, `test/features/delete/…`, `test/features/complete/…` |
| CA-007-23 | Widget con texto al 200 % en 360 dp y `meetsGuideline` (tamaño, etiquetas, contraste) | `test/features/attachments/image_a11y_test.dart` |
| Aspecto | *Goldens* frente al prototipo: hoja "Añadir", editor con imagen, tarea actual con imagen y pie, fila con miniatura, visor, "Adjunto no disponible" (es/en, ×1 y ×2) | `test/goldens/image_golden_test.dart` |
| CA-007-02/03/07/13/14, CL-007-2/3/4/5/6/10 | **Integración en el emulador** con los ficheros de prueba, llamando al canal nativo: sin metadatos (se buscan `Exif`, `http://ns.adobe.com/xap`, `tEXt`, `GPS`, datos tras `FFD9` y bytes del original), orientación, sRGB, 24 MP, teselas, límites, malformados sin cierre, nada fuera de `cache/import/`, 20 s | `integration_test/image_import_test.dart` |
| CA-007-03 (permisos) | El CI ya ejecuta `tools/check-android-permissions.sh release`; se añade que el `<provider>` no esté exportado | `tools/check-android-permissions.sh` |
| CA-007-08 | Arranque en frío con imagen en el Xiaomi (*profile*), p50 < 1 s | `integration_test/startup_perf_test.dart`, `docs/perf/baseline.md` |
| Integración | Flujo completo: hacer foto (cámara del emulador), ver, visor, girar, completar; y restauración sin archivos | `integration_test/image_flow_test.dart` |

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (T-3, T-7, T-8, T-13, T-2):** tipo por contenido; límites antes de decodificar; copia contada; todo en `cache/import/` y movido de forma atómica; sin nombres de archivo; `FileProvider` no exportado con permiso puntual solo sobre el archivo de la cámara; ningún permiso nuevo; sin registros con URIs, rutas ni metadatos en *release* (CL-007-10). Revisión de `security-reviewer` antes de la PR (toca importación, almacenamiento y nativo).
- **Accesibilidad:** CA-007-21 a 23. Como en la 004 y la 006, el foco de TalkBack se prueba **en el emulador y en el Xiaomi**, no solo con tests: hoja, vuelta de la cámara, visor (acciones de zoom y desplazamiento) y cierre.
- **Rendimiento:** la pantalla principal carga solo la versión de pantalla (I-2), ya recortada; la consulta de arranque añade un `LEFT JOIN` indexado; el barrido va después del primer fotograma. Medir en el Xiaomi: arranque en frío con imagen (CA-007-08), memoria del visor con 24 MP (< 250 MB) y fluidez del zoom.

## 7. Riesgos y alternativas

- **Canal nativo propio frente a `image_picker`.** Unas 400–500 líneas de Kotlin, pero con control total de CA-007-14 (copia contada, URIs rechazadas), CL-007-7 y sin dependencias. El spike S5 ya validó las mismas API. Si se complica, `image_picker` para elegir + nuestra limpieza, justificándolo según threat-model §5.
- **Límite de textura de la GPU.** Una sola imagen de más de ~8 000–16 000 px de lado no se puede dibujar. Por eso la versión completa se guarda en teselas de 4096 px. Alternativa, si las teselas dieran problemas de costuras al ampliar: una sola imagen ≤ 8 192 px de lado para el visor (perdería detalle solo en capturas extremas).
- **Memoria al decodificar 64 MP.** No se decodifica a tamaño completo: se pide directamente el tamaño final (≤ 24 MP ≈ 96 MB). En Android 8, `inSampleSize` a potencias de 2.
- **Ultra HDR, fotos con movimiento y datos tras el final:** los elimina la recodificación, salvo el *gainmap*, que se quita a mano en Android 14+. Lo verifica el test de integración.
- **Orientación sólo en el visor.** `setPreferredOrientations` en Android llama a `setRequestedOrientation` y prevalece sobre el manifiesto mientras el visor está abierto. En pantallas grandes (Android 16, ≥ 600 dp) el sistema ignora las restricciones de orientación: no es nuestro caso de referencia.
- **Foco de TalkBack al volver de la cámara.** La actividad de la cámara es otra app: al volver, el foco se pide cuando la ruta vuelve a estar en primer plano (lección de la 004). Se comprueba en el emulador.
- **Web de pruebas.** El `input` del navegador puede no disparar `change` si se cancela; se trata como cancelación al recuperar el foco de la ventana. Es solo para la vista previa (ADR-0010).
- **Documentos que cambian:** D18 y `architecture.md` dicen 50 MP y "original ≤ 4096 px"; la spec aprobada dice 64 MP y 24 MP sin límite de lado. Se actualizan los documentos (la spec manda).

## 8. Decisiones y cambios durante la implementación

Registro de lo que se decidió o cambió al implementar, respecto a lo escrito arriba. **[Hecho]** salvo que se indique.

### Decisiones del propietario (2026-09-26)

| Tema | Decisión | Dónde queda |
|---|---|---|
| Separadores de la hoja "Añadir a la tarea" | Un solo gris, el del menú (`disabled`, `#C7C4BF`), sin token nuevo | DEV-38 |
| "Preparando imagen…" | Dentro del recuadro de la vista previa: texto en monoespaciada, barra de progreso fina (sin ella con reducir movimiento) y "Cancelar" de 48 dp; "Quitar adjunto" no se ve mientras | DEV-39, CA-007-15 |
| Lectura sin texto | "Tarea actual: Foto" / "Imagen", con mayúscula (se reutilizan `attachmentPhoto`/`attachmentImage`) | CA-007-21 |
| "Imagen" dos veces | Una imagen de la galería no lleva papel de imagen (TalkBack añadiría "imagen" a "… Con imagen"); una foto, sí | CA-007-21 |
| Pantalla encendida | Solo los toques cuentan como uso; el teclado físico no reinicia los 10 minutos | CA-007-12 |
| "Adjunto no disponible" | **Sin "Sustituir":** una sola acción, "Quitar adjunto" (con texto) o "Eliminar tarea" (sin texto). Para otra imagen, se edita la tarea | CA-007-16/19, DEV-40 |
| Un adjunto por tarea | Un solo adjunto (imagen, foto, documento o URL). En el editor, (+) sigue visible con un adjunto y lo que se cargue sustituye al anterior; no hay botón "Sustituir" en ninguna parte | CA-007-04, spec §9 |
| Nivel de zoom en voz alta (2026-09-27) | El lector dice "Ampliación por 2,5": `a11yZoomLevel` lleva "por" escrito en lugar de "×" (EN: "Zoom times 2.5") | CA-007-21, spec §7 |
| "Subir archivo" y "Cargar URL" (2026-09-27) | De momento el lector no dice nada al activarlas (sin "Próximamente"), hasta las specs 008 y 009 | DEV-18 |
| Texto nuevo | `a11yAttachmentMissing` ("{text}. Adjunto no disponible"), añadido a la §7 | CA-007-19/21 |

### Decisiones técnicas (propias, dentro de lo aprobado)

- **Proveedores y puertos nuevos:**
  - `imageImporterProvider` e `importImageProvider` (caso de uso `ImportImage`: `pick` y `ImportJob.prepare`/`cancel`, con el tiempo máximo de 20 s; al agotarse, error `unreadable`, el mismo texto que "ilegible").
  - `ImageImportController.pick` devuelve `ImportOutcome` (`added`, `unchanged`, `failed`): el editor decide así el foco y el anuncio (CA-007-22).
  - `AttachmentImages` (`data/attachments/attachment_images.dart`): cómo se dibujan los archivos, de disco en móvil (`FileImage`) y de memoria en la web y en los tests (`MemoryImage`). El dominio sigue sin Flutter.
  - `ImageServices` (`data/image_services*.dart`): almacén, imágenes e importador de la plataforma, abiertos en `bootstrap` junto a los repositorios. En la web de pruebas, `WebImageImporter` (T-007-19, abajo).
  - `NativeImageImporter` sin canal (iOS aún no lo tiene, D17): HEIC desactivado y cada llamada falla como `unreadable`; el arranque no depende de él.
  - `ImageImporter.regenerateDerived(attachment)` y el método nativo `regenerate`: rehace `screen.jpg` y `thumb.jpg` desde las teselas con `BitmapRegionDecoder`, decodificando solo la zona recortada y reducida (una captura larga no ocupa memoria de más). Se escribe aparte y se renombra.
- **Estado de los archivos al mostrar la tarea** (`attachmentHealthProvider`): comprueba los archivos sin bloquear el primer fotograma (mientras, se dibuja la imagen); si faltan las derivadas, las regenera; si la versión de pantalla existe pero no se puede decodificar, la regenera **una vez**; si vuelve a fallar o falta la completa, "Adjunto no disponible".
- **Barrido:** 2 s después del primer fotograma (`UnaApp.sweepDelay`), para no competir con la decodificación de la imagen del arranque (CA-001-09).
- **Pantalla encendida:** el ajuste `keepScreenOn` se guarda en la tabla `settings` (clave `keepScreenOn`, JSON; sin cambio de esquema), por defecto `true`, y se lee en el arranque (`BootState`). `KeepScreenOnWhileVisible` pide la pantalla encendida mientras su ruta es la de delante (`ModalRoute.isCurrent`): menú, editor y listado la apagan solos. `FLAG_KEEP_SCREEN_ON` no necesita permisos.
- **Visor:**
  - Sin token `viewerFade`: el fundido de 400 ms con reducir movimiento reutiliza `reducedMotionFade`; sin reducir movimiento, el de las hojas (`sheetIn` 200 ms / `sheetOut` 160 ms).
  - En tablets y plegables el marco de la app limita el ancho a 600 px (CL-001-7); el visor lo levanta mientras está abierto (`fullWidthRequests`) para ir al 100 % del ancho, también en horizontal.
  - "Cerrar" es un cuadrado blanco de 48 dp con borde negro, como "Quitar adjunto".
  - El valor y las acciones del lector se actualizan al terminar cada zoom o desplazamiento, no en cada fotograma del pellizco.
- **Web de pruebas** (T-007-19, CL-007-12): `WebImageImporter` (`data/import/web_image_importer.dart`), con `dart:js_interop` y sin paquetes (ni `package:web`: lo mínimo del DOM, declarado en el propio archivo).
  - "Hacer foto" y "Subir imagen" crean un `<input type=file accept="image/*">` oculto (con `capture="environment"` para la foto), lo pulsan y lo quitan del DOM al terminar. La cancelación llega por el evento `cancel`; si el navegador no lo emite, se da por cancelada 1 s después de que la ventana recupere el foco.
  - Mismas reglas que en Android: tipo por el contenido; dimensiones leídas de la cabecera **antes de decodificar** (`readImageSize` en `image_geometry.dart`: JPEG, PNG, GIF y WebP), así que una imagen de más de 64 MP se rechaza sin reservar memoria; `createImageBitmap` con la orientación EXIF; reducción a 24 MP; teselas de 4096 px, versión de pantalla (recorte centrado al tamaño de la pantalla en vertical, en píxeles físicos) y miniatura de 176 px, dibujadas en un `canvas` blanco (transparencia sobre blanco) y codificadas con `toBlob('image/jpeg')` (calidades 90/85/80, como en Android). El original se borra de la memoria al terminar y el JPEG del `canvas` no lleva metadatos. `regenerateDerived` rehace las derivadas desde las teselas guardadas.
  - La geometría (tamaño guardado y recorte centrado) está en funciones puras compartibles (`image_geometry.dart`) con test en la VM; el importador solo compila para la web.
  - HEIC no se admite en la web (los navegadores, salvo Safari, no lo decodifican): da el error de tipo no admitido.
  - **[Hecho]** Probado en Chromium sin interfaz (Playwright) con el build real (`--wasm --no-web-resources-cdn`) y la CSP de `vercel.json`: SVG con extensión `.png` rechazado, JPEG con EXIF de giro orientado bien, PNG con transparencia sobre blanco, PNG de 81 MP rechazado por la cabecera, imagen de 6000 × 2000 en dos teselas sin costura en el visor, y el `<input>` retirado tras cada selección. Sin errores en la consola.
  - **[Suposición]** Los navegadores solo abren el selector durante unos segundos tras un toque (activación del usuario); entre el toque en la hoja y el `click()` solo está el cierre de la hoja. Si algún navegador (Safari en iOS) no lo abre, se registrará aquí; es solo la vista previa (ADR-0010).
- **Pantalla principal con imagen:** el toque en la imagen abre el visor aunque la imagen aún no se haya decodificado (`HitTestBehavior.opaque`). Logotipo con fondo blanco que sobresale 8 px a cada lado sin moverse.
- **Textos:** `editorAttachmentPlaceholder` y `editorRemoveAttachment` estaban en la spec 005 pero no en las ARB: se añadieron.
- **Tokens nuevos:** `fontSize.attachmentText` (24) y `size.attachTextField` (96), del prototipo (`hasDraftAtt`); `fontSize.badge` (10) para la insignia "FOTO"/"IMAGEN" del listado (prototipo `item.isDoc`).
- **"Foto"/"Imagen" en el resto de la app** (T-007-17): `task_labels.dart` reúne cómo se nombra una tarea sin texto (`taskLabel`: listado, confirmación de eliminar y anuncios) y cómo se lee (`taskReading`: "{texto}. Con foto"). La insignia usa el mismo texto en mayúsculas.
- **Miniatura del listado** (`TaskThumbnail`): 44 px, recortada, con borde de 2 px dibujado encima; si el adjunto no está disponible o la miniatura no se puede leer, la insignia (y se intenta regenerar, como en la pantalla principal).
- **Caras de completar y eliminar:** reutilizan la pantalla principal (I-3), así que muestran la imagen sin código nuevo. No comprueban los archivos: al eliminar ya se han borrado (CA-007-16) y la cara usa la imagen que ya estaba cargada; sin esto se vería "Adjunto no disponible" durante el arrugado.
- **Tests:** la imagen de prueba (`tinyImage`) es un PNG de 1 × 1 px que se decodifica de verdad; con la anterior (JPEG aritmético) los tests habrían mostrado siempre "Adjunto no disponible". `FakeImageImporter` (`test/support/`) simula la cámara, el selector, la copia, la limpieza, la cancelación y la regeneración.

- **Accesibilidad global** (T-007-20, `image_a11y_test`): cada pantalla con imagen (hoja, editor con imagen, "Preparando imagen…", pantalla principal, visor, "Adjunto no disponible" con y sin texto, listado con miniaturas e insignias) con el texto al 200 % en 360 dp pasa `androidTapTargetGuideline` (48 dp), `labeledTapTargetGuideline` y `textContrastGuideline`, sin desbordamientos; lo que no cabe se alcanza desplazándose y se ve entero. El editor con imagen cabe sin desplazarse; con el teclado abierto se desplaza hasta el final. La tabla de foco y anuncios (CA-007-22) queda cubierta fila a fila: abrir la hoja (el nombre de la ruta se anuncia solo y el primer elemento es el título, encabezado) en `image_a11y_test`; el resto en `editor_image_test`, `image_viewer_test` y `missing_attachment_test`.
  - **Lección:** los tests que miden deben cargar las fuentes reales (`setUpAll(loadAppFonts)`). Con la fuente de pruebas (1 em por letra) apareció un desbordamiento falso de 126 px en la cabecera del editor. Queda como regla en `CLAUDE.md`, y se añadió `loadAppFonts` a los 8 tests de texto grande que no la cargaban. `delete_confirm_test` se queda sin ella: con las fuentes reales, `textContrastGuideline` da un fallo falso en texto de 13 px (el contraste lo garantizan los tokens).

- **Goldens** (T-007-22, `test/goldens/image_golden_test.dart`): hoja "Añadir a la tarea" (×1 y ×2), editor con imagen, "Preparando imagen…", tarea actual con imagen y pie (×1 y ×2), foto sin texto, visor, "Adjunto no disponible" y listado con miniaturas e insignia. La imagen de prueba es una "foto" dibujada en el propio test (un horario sobre una mesa), para que se vean el recorte, el pie y el borde; con la de 1 × 1 px saldrían en blanco.
  - Se generaron en el contenedor Linux de la nube, con la misma versión de Flutter que CI (3.47.5). Antes se comprobó que los 28 goldens existentes pasan ahí píxel a píxel, así que no hizo falta la etiqueta `actualizar-goldens`.
  - `pumpWithApp` quita la cinta "DEBUG" (`debugShowCheckedModeBanner: false`, como la app). Los goldens anteriores no cambian: capturan solo la pantalla, sin la cinta.
  - **Fallo encontrado y corregido:** con el texto al 200 %, el logotipo "una." se cortaba por abajo en el editor, en "Todo hecho." y en la bienvenida (cabecera de alto fijo 48; el logotipo mide ~74). Ahora la cabecera mide **al menos** 48 y crece. "Cancelar" del editor se queda en 48 dp (antes los heredaba de la altura fija). Test: `test/ui/wordmark_test.dart`. A ×1 no cambia nada (los goldens ×1 son idénticos).

- **Revisiones** (T-007-25, 2026-09-27): `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check` y `/tokens-validate`.
  - `/i18n-check`: sin problemas. Las 29 claves de la §7 coinciden con las ARB en ES y EN, con los mismos marcadores y sin textos incrustados.
  - `/tokens-validate`: sin problemas. `tokens.g.dart` está sincronizado y no hay valores sueltos. Las tres duraciones nuevas (barrido, tiempo máximo y espera del selector web) son de comportamiento, no de animación.
  - `/security-check`: sin secretos, sin archivos de firma, sin permisos nuevos y sin dependencias Dart nuevas. El `FileProvider` no está exportado. El modelo de amenazas (T-8) y la lista de seguridad decían "solo de lectura"; se añade la excepción ya aprobada en este plan: la cámara escribe un solo archivo, con permiso que se revoca al volver.
  - **Accesibilidad, corregido (con tests que fallan sin la corrección):**
    - el anillo de foco es negro con borde blanco por fuera (§6, WCAG 1.4.11); también cambió el golden de `BrutalButton` con foco;
    - con teclado, Tab llega a la imagen de la tarea actual e Intro o Espacio abre el visor (WCAG 2.1.1);
    - "Quitar adjunto" y "Cerrar" del visor tienen foco de teclado y anillo propios (`BoxedIconButton`);
    - en el visor, los atajos funcionan en toda la pantalla (también con el foco en "Cerrar"), Esc cierra, la imagen muestra el anillo con teclado y el lector lee la imagen antes que "Cerrar";
    - cerrar la hoja "Añadir" sin elegir devuelve el foco a (+) (fila nueva de CA-007-22);
    - el aviso de error flota encima de los botones y no tapa el (+) cuando este recibe el foco (WCAG 2.4.11);
    - mientras se prepara otra imagen, el lector no lee la imagen tapada;
    - pantalla encendida: explorar tocando con TalkBack (llega como *hover* táctil) y las acciones del lector en el visor cuentan como toques (CA-007-12). El teclado sigue sin contar, como decidió el propietario.
  - **Seguridad, corregido:**
    - **M1:** cancelar no espera en la cola de la copia. Cierra el flujo abierto (desbloquea un `read()` colgado de un proveedor sin red) y borra en un hilo propio. En Dart, al agotarse los 20 s el aviso sale sin esperar a la cancelación nativa, y "Cancelar" termina en 2 s como mucho.
    - **B1:** se rechazan las URIs con usuario en la autoridad (`0@…`) y las de cualquier proveedor de la propia app.
    - **B2:** si se cancela mientras termina la limpieza, se borra lo escrito y se devuelve "cancelado".
    - **Menores:** la caja `ftyp` que no cabe entera en la cabecera se rechaza (podría ser AVIF); el barrido protege también las importaciones que empiezan mientras barre; `FileAttachmentStore.file` solo acepta `attachments/<id>/<nombre>.jpg`; `debugCopyFile` compara la carpeta con separador.
  - **Registrado sin cambio de código:** B3, el original con metadatos puede quedar en la caché si el proceso muere a mitad (residual en T-7). CA-007-18 aclara que la transferencia entre móviles lleva las imágenes solo en Android 12 o posterior (ya estaba en ADR-0004).
  - **Aceptado:** la insignia "FOTO"/"IMAGEN" del listado no crece con el texto. Es decorativa: la fila ya se lee "… Con foto".
  - **[Pendiente, para la sesión en local]:**
    - compilar el Kotlin nuevo (T-007-16 y estas correcciones);
    - declarar `androidx.core` en Gradle con versión fijada (B4: hoy llega de forma transitiva con Flutter);
    - comprobar en el dispositivo: TalkBack (anuncios completos tras cada cambio de foco, desplazamiento horizontal ampliado, pantalla encendida solo con gestos del lector), Switch Access y teclado físico (anillo sobre foto clara y oscura).
  - **Decidido por el propietario (2026-09-27):** el zoom se lee "Ampliación por 2,5"; "Subir archivo" y "Cargar URL" siguen sin decir nada (tabla de arriba).

- **Preparación de T-007-23/24** (en la nube, sin ejecutar):
  - `integration_test/image_flow_test.dart`: flujo completo con el canal nativo, el disco y la interfaz reales; solo el selector entrega un fichero de prueba (`FixtureImporter`, en `integration_test/support/`). Cubre foto → tarea actual → visor, restauración sin archivos y la captura larga.
  - `integration_test/viewer_perf_test.dart`: fotogramas del zoom hasta ×8 y memoria (RSS) con la imagen más grande que se guarda.
  - `dispositivo.md`: guía con los comandos y las comprobaciones a mano (cámara, selector, ciclo de vida, TalkBack, Switch Access y teclado).
  - El arranque en frío con imagen se mide con `tools/measure-cold-start.sh`, como el de texto; no hace falta el `startup_perf_test.dart` previsto en el §5.

- **Sesión en local (2026-09-27), dispositivo.md §1–2:**
  - El Kotlin compila (`build apk --debug` y `--release`). `androidx.core:core:1.13.1` declarada en Gradle con la versión que ya llegaba de forma transitiva (B4); el árbol resuelto no cambia.
  - **Corregido, fallo encontrado en el emulador:** con una foto vertical, la vista previa del editor crecía con la imagen y "Guardar" quedaba fuera de la pantalla. `SliverFillRemaining` mide la columna por su altura intrínseca máxima y la de `Image` sigue la proporción de la foto. La imagen va ahora en `Positioned.fill` (no cuenta en la altura intrínseca del `Stack`), con un mínimo en el que cabe "Quitar adjunto". Los tests de widgets usaban un PNG de 1 × 1 y no lo veían: el test nuevo lo decodifica de verdad. El golden `editor_image_es` no debería cambiar (foto 3:4 en pantalla alta), **[Pendiente]** confirmarlo en CI.
  - `image_flow_test`: además, la captura larga cierra el visor antes de desmontar la app.
  - **Presupuesto de memoria redefinido por el propietario (§3 de dispositivo.md):** "< 250 MB con el visor abierto" era inalcanzable, porque la app ya ocupa ~350 MB de RSS en la pantalla principal del Xiaomi. Ahora: ampliar a ×8 añade < 200 MB sobre la tarea actual, medido con `dumpsys meminfo` en un proceso nuevo (`docs/architecture.md` §7). Medido: +150 MB de PSS. `viewer_perf_test` ya no usa `maxRss`, que incluía el pico de la importación de 50 MP (~620 MB): comprueba el aumento de la RSS al abrir el visor como aviso. **[Pendiente, R-02]** El pico de la importación en gama media.

  - **Pruebas a mano (§4 de dispositivo.md):** giro correcto en el Xiaomi y en el emulador. El propietario confirma que a ×1 la imagen va **siempre al ancho, con desplazamiento vertical**, también en horizontal (CA-007-09 sin cambios). **[Pendiente]** El pellizco en el Xiaomi (según el propietario, no funciona; en los tests sí) y el selector que a veces no vuelve a la app tras elegir una foto.

  - **Giro del visor en el Xiaomi, corregido:** con `SCREEN_ORIENTATION_USER` el visor solo giraba tras tocar la pantalla. El sensor de orientación del sistema (`dev_orient`, MTK) no emitía hasta el siguiente toque, mientras que la Galería, que lee el acelerómetro, giraba sola. Ahora, mientras el visor está abierto, `ViewerRotation.kt` (`OrientationEventListener`, sin permisos) fija `PORTRAIT`, `LANDSCAPE` o `REVERSE_LANDSCAPE`, con márgenes para no oscilar. Con el bloqueo de rotación activo, se queda en vertical, y no lee el sensor en segundo plano. `SystemChrome` sigue pidiendo las orientaciones (iOS, tests). Comprobado en el emulador con el acelerómetro simulado.
  - **Cambio de CA-007-11 pedido por el propietario:** al volver a vertical, el visor se cierra solo. "Cerrar" en horizontal sigue funcionando. Tests en `image_viewer_test.dart`.
  - **Segundo cambio de CA-007-11 pedido por el propietario:** en el Xiaomi seguía "haciendo falta tocar". El registro mostró que el visor ya giraba solo, pero la tarea actual (siempre en vertical) no abría el visor al girar. Ahora, con la tarea con imagen a la vista y como pantalla de arriba, `ViewerRotation.kt` vigila el acelerómetro y avisa a Dart (`landscape`) para abrir el visor. No abre un segundo visor: `_openViewer` comprueba `ModalRoute.isCurrent` en el momento. El propietario vio dos visores apilados ("dos X"). Comprobado en el emulador.
  - **Giro desde el arranque:** el aviso de horizontal solo saltaba al pasar de vertical a horizontal, así que al abrir la app ya girada hacía falta tocar. Ahora salta siempre que la tarea está a la vista en horizontal, salvo tras cerrar el visor con "Cerrar" en horizontal, hasta volver a vertical.
  - **Encaje al ancho (DEV-41, CA-007-08 cambiado por el propietario):** `screen.jpg` se genera al ancho de la pantalla, sin recortar los lados, y, si es más alta, solo la parte de arriba (`fitWidthCrop` en Kotlin y en Dart, también al regenerar). `TaskImage` usa `BoxFit.fitWidth`. Las imágenes guardadas antes del cambio conservan su `screen.jpg` recortada: la app no está publicada y el propietario las vuelve a añadir. **[Pendiente]** Los goldens de la tarea actual con imagen cambian: hay que regenerarlos en Linux (CI o la nube, `docs/testing.md`).
  - **[Pendiente]** El pellizco en el Xiaomi: sin registros de Flutter en *release*, falta saber qué gestos llegan.

### Pendiente de verificar

- **[Hecho 2026-09-27]** Compilar el Kotlin nuevo de T-007-16 (`regenerate` en `ImageImport.kt` y `ImageSanitizer.regenerateDerived`) en el Mac.
- **[Pendiente]** Todo lo que depende del dispositivo (T-007-23/24): cámara y selector reales, giro, pellizco, TalkBack, pantalla encendida y rendimiento en el Xiaomi.

