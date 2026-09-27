# Tareas — Spec 008: Tareas con PDF

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR puede agrupar varias tareas consecutivas.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-008-01 | Dependencia `pdfrx`: añadirla fijada; comprobar la licencia en CI, la descarga de PDFium (origen y sha256), sin `INTERNET` en *release*, el WASM local en web y el tamaño del APK; registrarla en `threat-model.md §5` | — | `check_licenses.dart`, `check-android-permissions.sh release`, `--analyze-size`; nota en §5 | §4 del plan |
| T-008-02 [P] | Tokens (franja, banda, insignia, "Volver a vertical", zoom); regenerar `tokens.g.dart` | — | `node tools/validate-tokens.mjs`, analyze | CA-008-08/10/11/19 |
| T-008-03 [P] | Textos ES/EN de la §7 (`/strings-add`), con el cambio de `attachPickFileHint` | — | `gen-l10n`, `/i18n-check` | §7 |
| T-008-04 [P] | Ficheros de prueba: `tools/fixtures/gen_pdf_fixtures.py` y los PDF en `app/integration_test/fixtures/` (+ uno pequeño en `app/test/fixtures/`) | — | Script reproducible; cada fichero es lo que dice su nombre | CA-008-02/12/14, CL-008-1/2/3/4/10 |
| T-008-05 | Dominio: `AttachmentKind.pdf`, `AttachmentOrigin.file`, `Attachment` con nombre y páginas, `PdfPosition`, `sanitizeFileName`, `PdfSniffer`, `taskLabel` | — | Unitarios | CA-008-02/07/09/19 |
| T-008-06 [P] | Dominio: `LinkPolicy` y `LinkTarget` | — | `link_policy_test` (todos los esquemas y casos de saneado) | CA-008-12 |
| T-008-07 | Datos: repositorios (drift y memoria) con PDF; `FileAttachmentStore`/`MemoryAttachmentStore` (`commit`, `check` y borrado de PDF, `position.json`) | 05 | Tests de contrato y del almacén | CA-008-06/16/18 |
| T-008-08 | Nativo: selector de PDF (origen `file`) sobre el canal de la 007 y `encodeJpeg` en `ImageSanitizer` | 01 | Integración en el emulador: selector sin permisos, copia acotada, JPEG correcto | CA-008-01/03/14 |
| T-008-09 | `PdfrxPdfImporter` + `ImportPdf`: sniffer, contraseña, páginas, primera página → `screen.jpg`, 20 s, cancelar, errores tipados; regenerar la versión de pantalla | 07, 08 | `pdf_import_test` (integración con los ficheros de prueba); unitarios con importador falso | CA-008-02/03/14, CL-008-1/2/3/7/8 (incluido el límite de 20 páginas) |
| T-008-10 | `AttachmentImportController` (generaliza el de la 007): "Preparando PDF…" a los 400 ms, cancelar, errores, registro de importaciones; tests de la 007 en verde | 09 | `attachment_import_controller_test` | CA-008-15 |
| T-008-11 | Hoja "Añadir": "Subir archivo" activo; editor con PDF (vista previa desplazable, quitar, sustituir por imagen o PDF, texto opcional, siempre arriba, editar sin mover, foco y anuncios) | 03, 10 | `editor_pdf_test` | CA-008-01/04/05/06/21, CL-008-9 |
| T-008-12 | Tarea actual con PDF: franja fija, banda del texto que se desplaza con las páginas, páginas al ancho con pdfrx tras el primer fotograma (con `screen.jpg` de base); semántica de la tarea | 07, 09 | `current_task_pdf_test` | CA-008-08/20, CL-008-10 |
| T-008-13 | Última posición: guardar al salir o pasar a segundo plano (y la página de esa posición como `screen.jpg`), restaurar, reglas de los 10 minutos | 12 | `current_task_pdf_test` (posición restaurada, página intermedia) | CA-008-08/09 |
| T-008-14 | Zoom: ×1–×4 que se queda, doble toque ×1/×2,5, pasos, acciones del lector y de Switch Access, teclas, desplazamiento a los lados, anuncio del nivel, reducir movimiento | 12 | `task_pdf_zoom_test` | CA-008-10/22 |
| T-008-15 | Semántica por página (texto bajo demanda, "Página n de total"), enlaces enfocables con Tab/Enter y su etiqueta, acciones de página | 12 | `pdf_a11y_test` | CA-008-20/21/22 |
| T-008-16 | Enlaces: `LinkOpener.kt` (`<queries>`, `resolveActivity`, `ACTION_VIEW`/`SENDTO`/`DIAL`), `NativeLinkOpener`, hoja de confirmación, errores, foco | 06, 15 | `link_confirm_test`; prueba a mano en el emulador con el PDF de enlaces | CA-008-12/21 |
| T-008-17 | Giro igual con imagen y con PDF: `AttachmentRotation.kt` con `backToPortrait`, `_RotatesWithAttachment`, botón "Volver a vertical" en los dos tipos (enmienda CA-007-11), casos de completar/eliminar/confirmación | 12 | `landscape_test`; prueba a mano en el emulador y el Xiaomi | CA-008-11 |
| T-008-18 | Pantalla encendida con PDF (vertical y horizontal) | 12 | `keep_screen_on_test` | CA-008-13 |
| T-008-19 | "Adjunto no disponible" con PDF (icono de documento, no gira) y regeneración de `screen.jpg` | 07, 12 | `missing_attachment_test` | CA-008-18 |
| T-008-20 | Resto de la app: insignia "PDF" en el listado, nombre como etiqueta sin texto (listado, eliminar, anuncios), cara con PDF en completar y eliminar | 05, 12 | Tests del listado, completar y eliminar | CA-008-19/20 |
| T-008-21 | Copia de seguridad (los PDF fuera de la nube) y web de pruebas (`WebPdfImporter`, memoria, sin giro) | 07, 09 | `backup_rules_test`; build web y prueba a mano | CA-008-17, CL-008-12 |
| T-008-22 | Integración en el emulador (flujo completo, malformados sin cierre) y rendimiento en el Xiaomi (arranque con PDF en la última posición, memoria con 20 páginas escaneadas, tamaño del APK); con tu permiso y `--keep-app-running` | 09–20 | `integration_test`; `docs/perf/baseline.md` | CA-008-08, CL-008-4/5 |
| T-008-23 | Accesibilidad global: texto al 200 % en 360 dp, `meetsGuideline`, tabla de foco y anuncios; TalkBack y teclado en el emulador | 11–20 | `pdf_a11y_test`; lista de la revisión | CA-008-20/21/22 |
| T-008-24 | *Goldens* (editor con PDF, tarea con PDF con y sin texto, horizontal, fila con insignia, confirmación) en Linux con la etiqueta `actualizar-goldens` | 11–20 | CI | Aspecto |
| T-008-25 | Documentos (arquitectura: canal de importación y PDF; glosario; desviaciones que aparezcan) y revisiones: `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check`, `/tokens-validate` | 22–24 | Hallazgos resueltos o registrados | DoD |

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.

## Estado

| Tareas | Estado | Commit |
|---|---|---|
| T-008-01 | **Hecha.** `pdfrx` 2.6.5 fijada. PDFium (`chromium/7811`, sin V8) fijado por sha256 en `tools/pdfium.lock` y comprobado en CI (`tools/check-pdfium.sh`; propietario, 2026-09-27, opción 1). Release sin permisos; `url_launcher` transitivo con una actividad no exportada; licencias correctas; web con el WASM local (la CSP de la web de pruebas se revisa en T-008-21). El tamaño de CI pasa a medirse comprimido (arm64: 27 MB en disco, ~12,7 MB comprimido) | (este) |
| T-008-02, 03 | **Hecha.** Tokens del PDF (zoom ×1,5/×2,5/×4 y su duración, "Volver a vertical" 48, separación de la franja); textos ES/EN de la §7 y `attachPickFileHint` = "PDF · va arriba del todo". Los *goldens* de la hoja "Añadir" se regeneran en T-008-24 | (este) |
| T-008-04 | **Hecha.** `tools/fixtures/gen_pdf_fixtures.py` sin dependencias (el cifrado RC4 de los protegidos, a mano; Pillow solo para el escaneado de 20 páginas, que va a `out/`). Comprobado con PDFium en `flutter test`: pdfrx funciona en los tests (necesita `Pdfrx.getCacheDirectory`); el PDF cíclico lanza `RangeError` (no `PdfException`) → el importador trata cualquier error como ilegible; la bomba se abre en 0,7 s; los enlaces llegan con la URL ya codificada (`%E2%80%AE`) → `LinkPolicy` decodifica antes de sanear | (este) |
| T-008-05 | **Hecha.** `AttachmentKind.pdf`, `AttachmentOrigin.file`, `Attachment` con nombre, páginas y rutas del PDF (sin miniatura: la fila muestra la insignia), `PdfPosition`, `isPdf`/`PdfLimits`, `sanitizeFileName` (con `characters`, ya en el lock por Flutter; pasa a dependencia directa) | (este) |
| T-008-06 | **Hecha.** `LinkTarget` y `classifyLink`: página interna; `http(s)` sin `usuario@` y con el dominio en punycode si mezcla alfabetos (codificador RFC 3492 propio); `mailto:` rehecho solo con destinatarios y asunto; `tel:` solo el número; el resto, bloqueado. `stripUnsafeChars` compartido con el nombre del archivo | (este) |
| T-008-07 | **Hecha.** `StagedAttachment` cerrado (`StagedImage`, ahora clase, y `StagedPdf`); `CreateTask(attachment:)` y `ReplaceAttachment(staged)` aceptan los dos. Almacenes en disco y memoria: `commit`, `check` y `file()` para PDF (`document.pdf`, `screen.jpg`, `position.json`), `readPosition`/`writePosition` (escritura atómica; no escribe si el adjunto ya no existe). Repositorio drift: `originalName` y `pageCount` (sin cambio de esquema) | (este) |
| T-008-08, 09 | **Hecha.** Nativo: origen `file` (`ACTION_OPEN_DOCUMENT`, `application/pdf`, nombre visible por `OpenableColumns`), cabecera de copia configurable (1024 para PDF) y `encodeJpeg` (BGRA → JPEG, temporal + rename, en la preparación o en el adjunto guardado). Dart: puerto `PdfImporter`, `ImportPdf` (tipo por contenido, 10 MB, 20 páginas, contraseña, 20 s, cualquier error del motor = ilegible), `PdfEngine` (PDFium sin contraseña, fondo blanco) y `NativePdfImporter`. `isPdf` rechaza además el marcado (`<` al principio) aunque lleve `%PDF-` (CL-008-7). Emulador: `pdf_import_test` 6/6 e `image_import_test` 13/13 | (este) |
| T-008-10 | **Hecha.** `AttachmentImportController` (antes el de imagen): elige `ImportPdf` o `ImportImage` según el origen, guarda qué tipo se prepara ("Preparando PDF…"), errores de los dos tipos (`importErrorText` con los textos de la §5), un PDF sustituye a una imagen y al revés; los tests de la 007 siguen en verde | (este) |
