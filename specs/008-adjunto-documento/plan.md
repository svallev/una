# Plan técnico — Spec 008: Tareas con PDF

- **Spec:** `specs/008-adjunto-documento/spec.md` (estado: Aprobada, 2026-09-27)
- **ADR aplicables:** ADR-0014 (solo PDF en la v1), ADR-0008 (pdfrx, resultados de S3), ADR-0002 (repositorio y esquema), ADR-0004 (copias, R-10), ADR-0010 (web de pruebas), ADR-0012 (completar borra), ADR-0013 (el horizontal de la imagen, ampliado al PDF); decisiones de los spikes I-1, I-2, I-3 e I-7
- **Estado del plan:** Aprobado (propietario, 2026-09-27)
- **Rama:** `feat/008-pdf`, desde `main` (la 007 y el ADR-0012 ya están fusionados)

## 1. Resumen del enfoque

- **Una dependencia nueva: `pdfrx`** (PDFium), la misma del spike S3 (2.6.5 entonces; se fija la última 2.x estable al empezar). Dibuja, desplaza, amplía y da los enlaces y el texto de cada página. No ejecuta JavaScript ni rellena formularios (PDFium sin V8 ni XFA; confirmado en S3). Ver §4.
- **Se reutiliza el canal de importación de la 007**, generalizado de "imagen" a "adjunto":
  - el selector nativo (`ImageImport.kt`) gana el origen `file`: `ACTION_OPEN_DOCUMENT` con `application/pdf`, sin permisos, con la misma copia acotada (10 MB, contada al copiar), el mismo rechazo de URIs de la propia app y la misma cancelación;
  - después de la copia, **en Dart**: el tipo por el contenido (`PdfSniffer`: `%PDF-` en los primeros 1024 bytes), abrir con pdfrx **sin contraseña** (si la pide → `protected`), comprobar que tiene entre 1 y **20 páginas** (si no, `unreadable` o `tooManyPages`) y dibujar la primera; todo con el tiempo máximo de 20 s;
  - la **versión de pantalla** de la página es un JPEG al ancho físico (I-2). pdfrx da los píxeles y el JPEG lo codifica el `ImageSanitizer` nativo (nuevo método `encodeJpeg`, sin dependencia; en Dart es 15 veces más lento, H-4).
- **Guardado** en `attachments/<id>/`: `document.pdf` (el archivo tal cual, sin nombre original), `screen.jpg` (versión de pantalla) y `position.json` (última posición). Ninguna miniatura: el listado usa la insignia "PDF".
- **Última posición sin cambiar el esquema:** se guarda en `position.json` dentro del directorio del adjunto (página + fracción desplazada dentro de ella, CA-008-09). Así se borra con el mismo borrado del adjunto (CA-008-16), no toca la BD y, como los adjuntos no van a la copia en la nube, tras restaurar empieza por la primera página, que es lo que dice la spec.
- **Arranque en < 1 s con la última posición (CA-008-08):** al salir de la tarea o pasar a segundo plano, se vuelve a dibujar en segundo plano, como `screen.jpg`, **lo que se ve desde la última posición**: la página desde la fracción guardada y las siguientes, con su separación, hasta el alto de la pantalla (`PdfEngine.renderView`). Al importar, `screen.jpg` es la página 1. Antes de `runApp`, y solo si la tarea actual tiene PDF (con un tope de 1 s), se leen `position.json` y se decodifica `screen.jpg` (`pdf_boot.dart`), así que el primer fotograma ya la pinta. El visor de pdfrx se abre debajo y la imagen **no se quita hasta que pdfrx avisa de que ha dibujado las páginas visibles**, al primer toque o, como respaldo, a los 10 s; si no, el visor listo pero aún sin dibujar la tapaba en blanco (T-008-22). Al redibujar `screen.jpg`, la imagen anterior sale de la caché. Se mide en el Xiaomi (T-008-22).
- **Dominio (Dart puro):**
  - `AttachmentKind.pdf` y `AttachmentOrigin.file`; `Attachment` gana `originalName` y `pageCount`, y las rutas `documentPath` y `positionPath`;
  - `sanitizeFileName` (CA-008-07: sin rutas, controles ni marcas bidi, 120 grafemas conservando la extensión; vacío → null → "PDF");
  - `PdfSniffer` y `LinkPolicy` (clasifica un enlace en interno, web, correo, teléfono o bloqueado; sanea `{host}`/`{destino}`, punycode si mezcla alfabetos, rechaza `usuario@`, y reconstruye el `mailto:` solo con destinatarios y asunto);
  - `PdfPosition` (página + fracción) y su serialización;
  - `taskLabel`: la etiqueta sin texto ("Foto", "Imagen" o el nombre del PDF), usada por el listado, eliminar y los anuncios.
- **Giro igual con imagen y con PDF (CA-008-11):** `ImageRotation.kt` pasa a `AttachmentRotation`. En Dart, `_RotatesWithImage` pasa a `_RotatesWithAttachment` y `AttachmentRotation` cuenta las pantallas que quieren girar (la tarea que entra se monta antes de que salga la anterior). ~~`backToPortrait()` y el botón "Volver a vertical"~~: **quitados por el propietario (2026-09-28)**; la app vuelve a vertical solo al poner el móvil en vertical.
- **Enlaces (CA-008-12):** nuevo canal `una/links` en Kotlin. `http(s)`: `ACTION_VIEW` solo si hay navegador; `mailto:`: `ACTION_SENDTO` con la URI reconstruida; `tel:`: `ACTION_DIAL` (marca, no llama, sin permiso). Antes de lanzar, `resolveActivity` (I-7), con los `<queries>` de Android 11+ para esos tres intents. Sin permiso `INTERNET` (la app no descarga nada).
- **Accesibilidad del PDF:** pdfrx no expone semántica. Encima de cada página (con `pageOverlaysBuilder`) va un nodo "Página {n} de {total}" con su texto (con 20 páginas como máximo, el texto y los enlaces de todas se cargan al abrir la tarea, después del primer fotograma) y un nodo enfocable por enlace (`loadLinks`) con su etiqueta, alcanzable con Tab y activable con Enter. Las acciones de la tarea, las de página, zoom y desplazamiento van en el contenedor del visor. El zoom por pasos (×1 → ×1,5 → ×2,5 → ×4) y el doble toque se hacen con el controlador de pdfrx.

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | `entities/attachment.dart`, `entities/pdf_position.dart`, `entities/link_target.dart`, `services/file_name.dart`, `services/link_policy.dart`, `services/pdf_sniffer.dart`, `ports/pdf_importer.dart`, `ports/link_opener.dart`, `usecases/import_pdf.dart`, `services/task_label.dart` | Tipo `pdf`, origen `file`, nombre y páginas; saneado del nombre; política de enlaces; tipo por contenido; puerto de importación de PDF (elegir, copiar, preparar, cancelar, regenerar la versión de pantalla); puerto para abrir enlaces; etiqueta sin texto |
| Datos | `drift_task_repository.dart`, `in_memory_task_repository.dart`, `attachments/file_attachment_store.dart`, `attachments/memory_attachment_store.dart`, `import/pdfrx_pdf_importer.dart`, `import/web_pdf_importer.dart`, `links/native_link_opener.dart`, `attachments/pdf_position_store.dart` | Leer y escribir `kind = pdf`, `origin = file`, `originalName`, `pageCount` (columnas ya existentes); `commit` y `check` para PDF; importador con pdfrx; posición en `position.json` |
| Estado | `features/attachments/image_import_controller.dart` → `attachment_import_controller.dart`, `pdf_view_controller.dart`, `providers.dart` | La importación genérica (imagen o PDF: "Preparando…", 20 s, cancelar, errores); estado del visor (posición, zoom, guardado de la posición y la versión de pantalla) |
| Presentación | `current_task_screen.dart`, `features/attachments/task_pdf.dart` (nuevo), `pdf_strip.dart`, `pdf_page_semantics.dart`, `link_confirm_sheet.dart`, `attach_sheet.dart`, `attachment_preview.dart`, `missing_attachment_card.dart`, `task_list_row.dart`, `delete_confirm_sheet.dart`, controladores de completar y eliminar | Tarea con PDF (franja fija, banda del texto que se desplaza, páginas), zoom y teclado, enlaces con confirmación, horizontal igual que la imagen (sin "Volver a vertical" desde 2026-09-28), vista previa del editor, insignia y etiquetas |
| Nativo | `ImageImport.kt` (origen `file`), `ImageSanitizer.kt` (`encodeJpeg`), `ImageRotation.kt` → `AttachmentRotation.kt`, `LinkOpener.kt` (nuevo), `MainActivity.kt`, `AndroidManifest.xml` (`<queries>`) | Selector de PDF, JPEG desde píxeles, giro con imagen o PDF, abrir enlaces |
| l10n | `app_es.arb`, `app_en.arb` | Las claves de la §7 de la spec; cambia `attachPickFileHint` |
| Tokens | `design/tokens.json` → `tokens.g.dart` | Franja (11 px mono), banda del texto (24 px, 800), insignia de 44 px, ~~botón "Volver a vertical"~~ (quitado, 2026-09-28), niveles de zoom |

## 3. Modelo de datos y migraciones

**Sin cambios de esquema** (sigue la v2). La tabla `attachments` ya tiene `kind` (`pdf`), `origin` (`file`), `originalName`, `pageCount` y `byteSize`. `relPath` apunta a `document.pdf`, `displayRelPath` a `screen.jpg` y `thumbRelPath` queda nulo. `width` y `height` guardan el tamaño de la primera página en puntos (para reservar el alto antes de dibujar).

La última posición **no** va en la BD (§1): va en `position.json` junto al PDF. Si el propietario prefiere tenerla en la BD, haría falta la v3 con su test de migración.

## 4. Dependencias nuevas

- **`pdfrx`** (2.x; trae `pdfrx_engine`, `pdfium_dart` y `pdfium_flutter`). Licencia MIT; PDFium es BSD-3. Publicador verificado en pub.dev; en mantenimiento activo. Motivo: no hay forma razonable de dibujar PDF con el SDK (Android `PdfRenderer` no da texto, enlaces ni web); ya se validó en S3 (ADR-0008).
  - **Cadena de confianza [Pendiente, T-008-01]:** `pdfium_flutter` **descarga al compilar** los binarios de PDFium (como `sqlite3`). Se comprueba de dónde (se espera `bblanchon/pdfium-binaries` en GitHub) y con qué verificación (sha256 fijado), y se documenta en `threat-model.md §5`.
  - **Sin red en tiempo de ejecución [Pendiente, T-008-01]:** pdfrx puede abrir URLs (trae `http`). Solo se usa `openFile`/`openData`; se comprueba que el manifiesto de *release* sigue sin `INTERNET` (`check-android-permissions.sh`) y que en web el WASM de PDFium sale de los assets del paquete y no de un CDN (P4 y la CSP de la web de pruebas).
  - **Tamaño (R-19):** el APK crecerá unos MB por PDFium (27,6 MB arm64 en el spike, con todo); se mide con `--analyze-size`.
  - `check_licenses.dart` en CI debe aceptarlas.
- **Sin más dependencias:** los enlaces, el selector, el JPEG y el giro, en Kotlin propio. Se descartan `url_launcher` (una línea de `Intent` por esquema, y así controlamos qué esquemas salen), `file_picker` (copia sin límite) y `open_filex` (no hace falta: no hay "Abrir con otra app").

## 5. Estrategia de tests

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-008-01 | Integración (emulador): selector sin diálogo de permisos; `check-android-permissions.sh release` en CI | `integration_test/pdf_flow_test.dart` |
| CA-008-02, 03, 14; CL-008-1, 2, 3, 7 | Unitarios (sniffer, errores tipados del importador falso) + integración con los ficheros de prueba | `test/domain/pdf_sniffer_test.dart`, `test/features/attachments/attachment_import_controller_test.dart`, `integration_test/pdf_import_test.dart` |
| CA-008-04, 05, 06; CL-008-9 | Widget | `test/features/editor/editor_pdf_test.dart` |
| CA-008-07; CL-008-6 | Unitario | `test/domain/file_name_test.dart` |
| CA-008-08, 09 | Widget (franja, banda, posición restaurada con un almacén falso) + rendimiento en el Xiaomi | `test/features/current_task/current_task_pdf_test.dart`; `docs/perf/baseline.md` |
| CA-008-10 | Widget (acciones, teclas, pasos, límites) | `test/features/attachments/task_pdf_zoom_test.dart` |
| CA-008-11 | Widget (horizontal con imagen y con PDF: lo mismo, sin botón) + Kotlin probado a mano en el emulador y el Xiaomi | `test/features/current_task/landscape_test.dart` |
| CA-008-12 | Unitarios de `LinkPolicy` (todos los esquemas, `usuario@`, bidi, punycode, `mailto` con `attach`/`cc`/`body`) + widget de la confirmación | `test/domain/link_policy_test.dart`, `test/features/attachments/link_confirm_test.dart` |
| CA-008-13 | Widget | `test/features/attachments/keep_screen_on_test.dart` (ampliado) |
| CA-008-15 | Widget | `attachment_import_controller_test.dart` |
| CA-008-16 | Unitarios del almacén y del janitor + casos de uso | `test/data/file_attachment_store_test.dart`, `test/domain/attachment_janitor_test.dart` |
| CA-008-17 | Reglas de copia | `test/app/backup_rules_test.dart` |
| CA-008-18 | Widget | `test/features/attachments/missing_attachment_test.dart` |
| CA-008-19 | Widget (listado, eliminar, completar) | tests existentes del listado, eliminar y completar, ampliados |
| CA-008-20, 21, 22 | Widget con `SemanticsTester`, `meetsGuideline`, texto al 200 % en 360 dp (`loadAppFonts`) + TalkBack y teclado en el emulador | `test/features/attachments/pdf_a11y_test.dart` |
| CL-008-4, 5 | Integración + memoria en el Xiaomi | `integration_test/pdf_import_test.dart`; `docs/perf/baseline.md` |
| CL-008-10 | Widget | `current_task_pdf_test.dart` |
| CL-008-11 | Revisión del código + `security-reviewer` | — |
| CL-008-12 | Build web y prueba a mano | — |
| Aspecto | *Goldens* (editor con PDF, tarea con PDF con y sin texto, horizontal, fila con insignia, confirmación de enlace) | `test/goldens/pdf_golden_test.dart` |

En los tests de widget, pdfrx se sustituye por un visor falso detrás de una interfaz (`PdfView`) para no depender del motor en los tests de interfaz. **[Hecho, T-008-04]** PDFium sí carga en `flutter test` (macOS y Linux, con `Pdfrx.getCacheDirectory` apuntando a un temporal): el importador y los tests de texto y enlaces usan el real con los ficheros de prueba.

Ficheros de prueba: `tools/fixtures/gen_pdf_fixtures.py` escribe PDF a mano, sin dependencias (válido, truncado, referencias cíclicas, bomba de compresión, 0 páginas, 21 páginas, 10 000 páginas, con JavaScript y formulario, con enlaces de todos los esquemas, con páginas de tamaños distintos, `.pdf` que es HTML o ZIP). El protegido con contraseña se cifra con `qpdf` si está instalado. **[Pendiente]** Si no lo está, se genera una vez y se versiona el binario con su procedencia.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (T-3, T-5, T-8):**
  - PDFium solo lee archivos ya copiados a la app, con 10 MB, 20 páginas y 20 s como máximo;
  - sin JavaScript, sin formularios (las anotaciones se dibujan tal cual, sin edición), sin archivos incrustados;
  - enlaces solo por `LinkPolicy`, siempre con confirmación y resolución previa;
  - `<queries>` limitado a tres intents; ningún componente exportado ni FileProvider nuevo;
  - el nombre saneado nunca se registra (CL-008-11); la posición no tiene contenido.
  - Se pasan `security-reviewer` y `/security-check`.
- **Accesibilidad:**
  - ninguna excepción nueva a P6 (el zoom tiene alternativas);
  - el horizontal usa la excepción ya ampliada (constitución 1.2); ~~con "Volver a vertical"~~ sin botón desde el 2026-09-28 (propietario);
  - se pasan `a11y-reviewer` y TalkBack en el emulador, con la limitación de foco ya aceptada en la 007.
- **Rendimiento:**
  - el arranque no abre el PDF antes del primer fotograma: decodifica `screen.jpg` antes de `runApp`, la pinta y abre pdfrx después, sin quitarla hasta que ha dibujado;
  - la memoria de CL-008-5 (20 páginas escaneadas, casi 10 MB) se mide con `dumpsys meminfo` en el Xiaomi (con permiso y `--keep-app-running`);
  - el tamaño del APK, con `--analyze-size`.

## 7. Riesgos y alternativas

| Riesgo | Mitigación / alternativa |
|---|---|
| La banda del texto tiene que desplazarse **con** las páginas, pero `PdfViewer` es su propia zona de desplazamiento | Hueco arriba en `layoutPages` y banda pintada como capa que sigue a la matriz del controlador. Si no queda bien en el móvil, la banda fija sobre el visor (desviación nueva, se consulta al propietario) |
| pdfrx no expone semántica ni foco por teclado de enlaces | Capa propia por página (§1); con 20 páginas como máximo, se carga todo al abrir, después del primer fotograma |
| La descarga de PDFium al compilar sin verificación | Si no hay sha256 fijado, se compila con un binario local verificado o se para y se consulta |
| pdfrx en web carga PDFium desde un CDN | Configurarlo para usar el asset del paquete; si no se puede, el PDF en la web de pruebas se limita a la tarjeta (CL-008-12 cambiaría: se consulta) |
| `encodeJpeg` nativo añade memoria (RGBA de una página al ancho: ~4 MB) | Se libera enseguida; se dibuja a la resolución de pantalla, nunca más |
| La restauración de la posición falla con PDF de páginas de tamaños distintos | La posición es página + fracción, independiente del ancho; test con páginas mixtas |
| ~~El giro con el sensor (HyperOS) y "Volver a vertical" interfieren~~ | Sin objeto: el botón se quita (propietario, 2026-09-28). El giro con el sensor se prueba a mano en el Xiaomi |
