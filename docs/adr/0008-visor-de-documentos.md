# ADR-0008: PDF dentro de la tarea (pdfrx); el resto de documentos, con el visor del sistema

- **Estado:** Provisional, pendiente del spike S3
- **Fecha:** 2026-09-24
- **Relacionado:** spec 008, DEV-03, modelo de amenazas (T-3)

## Contexto

- **[Hecho]** El brief dice "se abren con el visor del teléfono"; el prototipo muestra PDF, Word, Excel y TXT dentro de la tarea. D6: PDF dentro y el resto con el sistema.
- **[Hecho]** iOS tiene QuickLook (PDF, DOCX, XLSX, PPTX, Pages, Numbers, TXT, imágenes) sin conexión. Android no tiene visor universal: depende de las apps instaladas (Drive, Word, WPS…).

## Decisión

- **PDF:** visor propio con **pdfrx** (PDFium), a pantalla completa, con zoom, desplazamiento continuo y sin conexión. JavaScript de PDF, formularios activos y enlaces externos desactivados (los enlaces se abren en el navegador del sistema tras confirmar). La primera página se renderiza como miniatura al importar, para el arranque instantáneo.
- **Word, Excel, PowerPoint, TXT, CSV, RTF, ODF, Pages/Numbers/Keynote:** tarjeta a pantalla completa (tipo, nombre, tamaño, el texto de la tarea) con el botón **"Abrir"**:
  - iOS: `QLPreviewController` (sin conexión, dentro de la app).
  - Android: `ACTION_VIEW` con `FileProvider` (URI `content://` temporal, `FLAG_GRANT_READ_URI_PERMISSION` y ningún permiso de escritura). Si no hay ninguna app, se muestra "No hay ninguna app para abrir este archivo" con la sugerencia de instalar un visor.
- **Tipos admitidos** (por bytes mágicos + extensión coherente): PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, ODT/ODS/ODP, RTF, TXT, CSV, MD, Pages/Numbers/Keynote. **Rechazados:** HTML/HTM/SVG/XML, ejecutables, scripts, APK/IPA, ZIP y otros contenedores genéricos.

## Motivos

- El PDF cubre los casos centrales de la propuesta 2 (horarios, entradas, mapas exportados) con fidelidad total.
- Convertir Word o Excel dentro de la app da una fidelidad pobre y añade parsers de formatos complejos sobre archivos no confiables.

## Consecuencias

- En Android la experiencia con documentos no PDF depende del usuario → texto de ayuda y estado de error diseñados.
- Versión web de pruebas: pdfrx funciona con WASM; el resto se descarga o se muestra la tarjeta.
