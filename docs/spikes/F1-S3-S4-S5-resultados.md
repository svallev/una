# F1 · Resultados de S3 (PDF y documentos), S4 (URL) y S5 (importación y backup), Android

- **Fecha:** 2026-09-24 · **Estado:** completados en el emulador; queda repetir lo básico en un móvil físico
- **Código:** rama `spike/f1-android`, `spikes/una_spikes/` (desechable). Muestras generadas en el Mac, incluidas maliciosas
- **Entorno:** Flutter 3.47.5, *release* arm64; emulador Pixel 6a, Android 17 (API 37), `-gpu host`
- **Decisión aplicada durante el spike:** D18, **PDF de 10 MB como máximo** (del propietario)

## Resumen

| Spike | Criterio (ADR-0001) | Resultado | Veredicto |
|---|---|---|---|
| S3 PDF | Primera página < 500 ms, zoom fluido, sin red | pdfrx: visor listo en **18–20 ms** (9 MB/26 p., 300 p., PDF con JS); desplazamiento continuo; carga de páginas bajo demanda | ✅ |
| S3 visor del sistema | Abrir DOCX/XLSX sin conexión | FileProvider en solo lectura correcto. DOCX: **sin app** en el emulador (el sistema muestra "No apps can perform this action"); TXT: Chrome y HTML Viewer | ✅ técnico · ⚠️ UX (ver H-5) |
| S4 captura | Página completa legible hasta 20 000 px; endurecida | Captura nativa con la WebView de Android: Wikipedia 6263 px en 4,3 s; w3.org 15 330 px en 3,6 s; flutter.dev recortada a 16 000 px ("copia parcial") en 5,3 s | ✅ (con H-2, H-3) |
| S4 aislamiento | Sin puente JS ni acceso a archivos; navegación contenida | Sin objetos de Flutter ni Android en `window`; ventana nueva, `tel:`, `intent:` y otro dominio **bloqueados**; http, certificado caducado y autofirmado, y 404 **rechazados** | ✅ |
| S5 importación | Bytes mágicos, sin EXIF/GPS, límites, sandbox, sin bloquear la UI | 19 muestras clasificadas correctamente; EXIF/GPS eliminados; orientación aplicada; HEIC admitido; foto de 12 MP en **0,77 s** con el limpiador nativo (12 s en Dart puro) | ✅ (con I-4) |
| S5 backup | Datos en la copia del sistema | **Con adjuntos se supera la cuota de 25 MB y Android descarta la copia entera.** Sin adjuntos: la BD se copia y restaura bien | ⚠️ Replantea ADR-0004 (ver H-6) |

## S3: PDF y visor del sistema

| Archivo | Resultado |
|---|---|
| `horario_9mb.pdf` (8,9 MB, 26 p. escaneadas) | Aceptado; importación (copia + miniatura de la p. 1) 1,8 s; visor listo en 18 ms |
| `texto_300p.pdf` (105 KB, 300 p.) | Aceptado; visor listo en 19 ms; páginas bajo demanda al desplazarse |
| `js_action.pdf` (`OpenAction` con JavaScript + enlace) | Aceptado; **ningún JavaScript ejecutado** (ni `alert` ni `submitForm`); el enlace pide confirmación ("¿Abrir example.com en el navegador?") |
| `programa_130p.pdf` (42 MB) y `big_300p.pdf` (98 MB) | **Rechazados** por el límite de 10 MB (D18) |
| DOCX, XLSX, ODT, RTF, TXT, CSV | Aceptados; "Abrir" → intent `ACTION_VIEW` + FileProvider (solo lectura) |

## S4: URL (captura sin conexión y WebView en vivo)

**Cambio respecto a ADR-0007:** `flutter_inappwebview` **no se usa**. Su última versión estable (6.1.5) es de **octubre de 2024**; la 6.2 lleva en beta desde febrero de 2026. El riesgo R-04 se ha materializado. Solución probada:
- **En vivo:** `webview_flutter` 4.14.1 (oficial del equipo de Flutter, julio de 2026) + `webview_flutter_android` para desactivar el acceso a archivos, los permisos (cámara, micrófono, ubicación: denegados) y la reproducción automática.
- **Captura:** ~100 líneas de Kotlin con una WebView fuera de pantalla: `enableSlowWholeDocumentDraw`, medir la altura con JS, dibujar a `Bitmap` y comprimir a JPEG q85. Sin puente JS, sin `file://` ni `content://`, sin cookies de terceros; al terminar se borran cookies y almacenamiento.

| Prueba | Resultado |
|---|---|
| Wikipedia "Post-it" | 1080 × 6263 px, 473 KB, 4,3 s, sin franjas vacías |
| w3.org | 1080 × 15 330 px, 99 KB, 3,6 s, sin franjas vacías |
| flutter.dev | Página de 32 405 px → **copia parcial** de 16 000 px, 1,2 MB, 5,3 s; 4 de 32 franjas vacías (contenido que la web anima al hacer *scroll*) |
| `http://neverssl.com` | `ERR_CLEARTEXT_NOT_PERMITTED` ✅ |
| `expired.badssl.com` / `self-signed.badssl.com` | `ssl_error` ✅ (**tras corregir H-1**) |
| Página inexistente (404) | `http_error:404` ✅ |
| Modo avión | Error inmediato `ERR_NAME_NOT_RESOLVED`; la captura guardada sigue disponible |
| En vivo: `Object.keys(window)` | Solo propiedades estándar (`webkit*`); **ningún puente** |
| En vivo: `window.open`, `tel:`, `intent:`, otro dominio | Los 4 **bloqueados**; la URL no cambia |

## S5: importación

| Muestra | Resultado esperado | Obtenido |
|---|---|---|
| `photo_gps.jpg` (12 MP, EXIF con GPS de Madrid, Orientation=6, Make/Model) | Aceptar, sin metadatos, orientación aplicada | ✅ 3000×4000 (girada), sin EXIF/GPS/Make; original 508 KB, pantalla 1080 px 177 KB, miniatura 30 KB; **0,77 s** |
| `photo.heic` | Aceptar | ✅ decodificada de forma nativa, 1,3 s |
| `image.png` | Aceptar | ✅ 0,11 s |
| `huge_63mp.png` (63 MP, 197 KB) | Rechazar sin decodificar | ✅ "63 MP > 50 MP" (en la cabecera, 2 ms) |
| `svg_as.png` (SVG con `onload`) | Rechazar | ✅ |
| `fake_html.pdf` (HTML con `<script>`) | Rechazar | ✅ |
| `evil.pdf.exe` (cabecera MZ) | Rechazar | ✅ "ejecutable o script" |
| `generic.zip` | Rechazar | ✅ "ZIP genérico no admitido" |
| Permisos | Ninguno para fotos, galería o archivos | ✅ Cámara del sistema (intent), Photo Picker y selector de documentos **sin diálogo de permisos**; manifiesto final: solo INTERNET |

## Hallazgos (H) y decisiones de implementación (I)

| ID | Hallazgo | Consecuencia |
|---|---|---|
| H-1 | Un certificado inválido no llega a `onReceivedError`: sin `onReceivedSslError` se guardaba **una captura en blanco como válida** | **I-5:** tratar los errores SSL (cancelar siempre) y HTTP ≥ 400 del marco principal como fallo de captura. Añadir a la checklist de seguridad y a los CA de la spec 009 |
| H-2 | Webs que animan contenido al hacer *scroll* salen con huecos | **I-6:** antes de capturar, recorrer la página con `scrollTo` por pasos y volver arriba |
| H-3 | Páginas muy largas (32 000 px) | El límite de 16 000–20 000 px y la "copia parcial" de la spec son necesarios; validado |
| H-4 | Codificar JPEG en Dart puro: 9–12 s para 12 MP | **I-4:** `ImageSanitizer` **nativo** (Android `ImageDecoder` + `Bitmap.compress`; en iOS, ImageIO). ~15 veces más rápido y sin metadatos |
| H-5 | Sin app para DOCX, Android muestra un selector vacío en inglés | **I-7:** comprobar antes con `queryIntentActivities` y mostrar nuestro mensaje (CA-008-08). Recomendación: TXT/CSV/MD **dentro de la app** como texto plano (riesgo nulo, mejor experiencia); requiere decidirlo (cambia D6) |
| H-6 | **Cuota de backup de 25 MB superada → Android descarta toda la copia** (no solo lo que sobra) | **ADR-0004 debe cambiar:** reglas estáticas con adjuntos = copia frágil. Propuesta: `BackupAgent` propio que incluya siempre BD + ajustes y añada adjuntos **por prioridad (primero el de la tarea actual)** hasta ~20 MB |
| H-7 | Tras restaurar sin adjuntos, el spike se colgó al arrancar | Confirma que la app **nunca** puede depender de que exista el archivo para arrancar (CL-007-4): "Adjunto no disponible" y test de integración de restauración |
| H-8 | Android 17 añade `ACCESS_LOCAL_NETWORK` a apps con INTERNET, sin declararlo | Hecho de plataforma; no está en el APK (verificado con aapt2). Tenerlo en cuenta en Data Safety |
| H-9 | APK arm64: 27,6 MB con pdfrx (PDFium), SQLite, WebView y selectores | Por encima del presupuesto de < 25 MB. Revisar en F2: el app bundle por ABI y sin símbolos, y medir con `--analyze-size` |

## Cambios que propongo en los documentos (pendientes de tu visto bueno)

1. **ADR-0007:** sustituir `flutter_inappwebview` por `webview_flutter` + captura nativa; añadir I-5 e I-6.
2. **ADR-0004:** `BackupAgent` con presupuesto y prioridades (H-6).
3. **ADR-0008 / D6:** decidir si TXT, CSV y MD se ven dentro de la app (H-5).
4. **Arquitectura:** `ImageSanitizer` y `WebSnapshotter` como puertos con implementación nativa (I-4).
5. **Spec 009:** criterios para certificado inválido, HTTP ≥ 400 y la captura de páginas que animan al hacer *scroll*.
6. **Presupuesto de tamaño** (H-9): se mantiene el objetivo y se mide en F2.
