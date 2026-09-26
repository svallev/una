# Tareas — Spec 007: Tareas con foto o imagen (visor a pantalla completa)

Reglas: tareas **pequeñas** (≤ medio día), **ordenadas** (las dependencias arriba) y **verificables** (cada una dice cómo se comprueba). Se marca `[P]` si puede hacerse en paralelo con la anterior. Una PR puede agrupar varias tareas consecutivas.

| ID | Tarea | Depende de | Verificación | CA |
|---|---|---|---|---|
| T-007-01 | Tokens (pie, miniatura, `viewerFade`, `importIndicatorDelay`, niveles de zoom); regenerar `tokens.g.dart` | — | `node tools/validate-tokens.mjs`, analyze | CA-007-08/10/15/20 |
| T-007-02 [P] | Textos ES/EN de la §7 (`/strings-add`) | — | `gen-l10n`, `/i18n-check` | §7 |
| T-007-03 [P] | Ficheros de prueba: `tools/fixtures/gen_image_fixtures.py` (Pillow + `sips`) y los ficheros en `app/integration_test/fixtures/` | — | Script reproducible; cada fichero tiene lo que dice su nombre (comprobado con Pillow) | CA-007-07/13/14 |
| T-007-04 | Dominio: `Attachment`, `Task.attachment`, `validateTaskContent`, `ImageTypeSniffer`, puertos `AttachmentStore` e `ImageImporter` | — | Unitarios | CA-007-04/13 |
| T-007-05 | Datos: repositorio (memoria y drift) con adjunto: lectura con `LEFT JOIN`, alta y edición en transacción, `delete` con la fila del adjunto, `attachmentIds` | 04 | Tests de contrato | CA-007-06/16/17 |
| T-007-06 | `FileAttachmentStore` y `MemoryAttachmentStore`: `commit` atómico, `discard`, `sweep`, estado de los archivos | 04 | `file_attachment_store_test` | CA-007-16/19 |
| T-007-07 | Casos de uso: `CreateTask` con adjunto (siempre arriba), `EditTask` (sustituye a `UpdateTaskText`), `AttachmentJanitor` usado por `DeleteCurrentTask` y `DeletePendingTask` | 05, 06 | Unitarios; tests de la 003–006 en verde | CA-007-05/06/16/17 |
| T-007-08 | Nativo I: canal, `FileProvider` no exportado (comprobar `androidx.core` transitiva), cámara del sistema, selector de fotos / documentos, copia acotada con rechazo de URIs propias, cancelación | — | Integración en el emulador: foto con la cámara del emulador y selector sin diálogos de permisos; `check-android-permissions.sh release` | CA-007-02/03/14, CL-007-1/6/7 |
| T-007-09 | Nativo II: `ImageSanitizer` (cabecera, 64 MP, orientación, sRGB, 24 MP, GIF, transparencia, *gainmap*, teselas, pantalla, miniatura) | 03, 08 | `image_import_test` con todos los ficheros: sin metadatos ni bytes del original, malformados sin cierre | CA-007-07/13/14, CL-007-2/4/5 |
| T-007-10 | `NativeImageImporter` (Dart) + `ImageImportController`: tipo por contenido, 20 s, "Preparando…" a los 400 ms, cancelar, errores tipados, registro de importaciones en curso | 07, 09 | Unitarios del controlador con importador falso | CA-007-13/14/15, CL-007-3 |
| T-007-11 | Hoja "Añadir a la tarea" y enganche del (+) en el editor | 02, 10 | `attach_sheet_test` | CA-007-01 |
| T-007-12 | Editor con imagen: vista previa, quitar, sustituir, texto opcional, guardar arriba sin hoja de posición (principal y listado), editar sin mover, errores, foco y anuncios | 11 | `editor_image_test`, `image_flow_test` | CA-007-04/05/06/15/22, CL-007-8 |
| T-007-13 | Pantalla principal con imagen: a sangre, logotipo y menú con fondo, pie, semántica y acciones | 07 | `current_task_image_test` | CA-007-08/21 |
| T-007-14 | Visor: ancho completo, desplazamiento vertical, zoom por pasos y pellizco, teselas por nivel, acciones del lector, teclado, girar solo aquí, fundido con reducir movimiento, foco al cerrar | 13 | `image_viewer_test` | CA-007-09/10/11/21/22/23 |
| T-007-15 | Pantalla encendida: canal nativo, `KeepScreenOnController`, `Listener` en la raíz, ajuste `keepScreenOn` por defecto | 13 | `keep_screen_on_test` | CA-007-12 |
| T-007-16 | "Adjunto no disponible" y regeneración de derivadas en segundo plano; barrido tras el primer fotograma | 06, 13 | `missing_attachment_test`; test del barrido en el arranque | CA-007-16/19 |
| T-007-17 | Resto de la app: miniatura e insignia en el listado; "Foto"/"Imagen" en filas, eliminar y anuncios; cara con imagen en completar y eliminar | 13 | Tests del listado, completar y eliminar | CA-007-20/21, CL-007-9 |
| T-007-18 | Copia de seguridad: reglas XML revisadas y test; ADR-0004 (Android 9–11 sin transferencia de imágenes) | 06 | `backup_rules_test` | CA-007-18 |
| T-007-19 | Web de pruebas: `WebImageImporter` (`<input type=file>`, `canvas` a JPEG) y almacén en memoria | 10 | Build web y prueba a mano en el navegador | CL-007-12 |
| T-007-20 | Accesibilidad global: texto al 200 % en 360 dp, `meetsGuideline`, tabla de foco y anuncios completa | 12–17 | `image_a11y_test` | CA-007-21/22/23 |
| T-007-21 | Documentos: D18 y `architecture.md` (64 MP, 24 MP sin límite de lado, rutas, teselas), glosario, desviaciones del prototipo si aparecen | 09 | Revisión | — |
| T-007-22 | *Goldens* (hoja, editor con imagen, tarea actual con imagen, fila con miniatura, visor, adjunto no disponible) en Linux con la etiqueta `actualizar-goldens` | 12–17 | CI | Aspecto |
| T-007-23 | Integración en el emulador (flujo, restauración sin archivos) y rendimiento en el Xiaomi (arranque con imagen, memoria del visor; con tu permiso y `--keep-app-running`) | 09–17 | `integration_test`; `docs/perf/baseline.md` | CA-007-08, CL-007-2/7 |
| T-007-24 | TalkBack y teclado en el emulador (hoja, vuelta de la cámara, visor, cierre) | 20 | Lista de la revisión de accesibilidad | CA-007-21/22 |
| T-007-25 | Revisiones: `a11y-reviewer`, `security-reviewer`, `/security-check`, `/i18n-check`, `/tokens-validate` | 22–24 | Hallazgos resueltos o registrados | DoD |

## Estado (2026-09-26)

| Tareas | Estado | Commit |
|---|---|---|
| T-007-01, 02 | **Hecha** | `3745568` |
| T-007-03 | **Hecha** | `dd0f022` |
| T-007-04 | **Hecha** | `a97de7e` |
| T-007-05 | **Hecha** | `de9aa69` |
| T-007-06 | **Hecha** | `c979bcd` |
| T-007-07 | **Hecha** | `52a6493` |
| T-007-08, 09 | **Hecha** (compilada en el Mac; integración en el emulador pendiente, T-007-23) | `b6f8750` |
| T-007-10 | **Hecha** | `60df477` |
| T-007-11 | **Hecha** (DEV-38) | `cc161d9` |
| T-007-12 | **Hecha** (DEV-39) | `6afa8bc` |
| T-007-13 | **Hecha** | `285677b` |
| T-007-14 | **Hecha** | `0d51598` |
| T-007-15 | **Hecha** | `ea613b3` |
| T-007-16 | **Hecha** (DEV-40, sin "Sustituir"); **Kotlin sin compilar** (el entorno en la nube no descarga el SDK de Android) | `1e00ed9`, `90c2a8e` |
| T-007-17 | **Hecha** | `21633c9` |
| T-007-18 | **Hecha** (las reglas ya cumplían; test y revisión del ADR-0004) | `14e51cd` |
| T-007-19 | **Hecha** (probada en Chromium con el build real y la CSP) | `3002d49` |
| T-007-20 | **Hecha** (sin fallos reales; regla de fuentes en `CLAUDE.md`) | `3cb505a` |
| T-007-21 a 25 | Pendientes | — |

Las decisiones y cambios respecto al plan están en `plan.md` §8.

## Cierre

- [ ] Todos los CA de la spec tienen test en verde.
- [ ] Definition of Done (`specs/constitution.md`) completa.
- [ ] Spec marcada como **Implementada**.
