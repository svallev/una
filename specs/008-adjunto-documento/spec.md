# Spec 008: Tareas con documento (PDF dentro; el resto, con el visor del sistema)

- **Estado:** En revisión
- **Reglas de producto:** R3 (documento), R5, propuesta de valor 2
- **Pantallas del prototipo:** 9 "Añadir (+)", 10 "Tarea con documento (abierto)"
- **Decisiones y ADR:** D5, D6, D8, ADR-0008, DEV-01, DEV-02, DEV-03; modelo de amenazas T-3
- **Dependencias:** 007 (hoja "Añadir" y canal de importación)

## 1. Objetivo

Tener a mano un PDF (entradas, un programa, instrucciones) a pantalla completa y sin conexión, y poder abrir otros documentos con el visor del teléfono.

## 2. Historias de usuario

- **HU-008-1** Como asistente a un congreso, quiero el PDF del programa a pantalla completa al abrir la app.
- **HU-008-2** Como usuario, quiero adjuntar un Word o un Excel a una tarea y abrirlo cuando lo necesite.

## 3. Criterios de aceptación

- **CA-008-01 Elegir un archivo**
  - **Dado** la hoja "Añadir a la tarea"
  - **Cuando** elige "Subir archivo"
  - **Entonces** se abre el selector de archivos del sistema (sin permisos de almacenamiento) y el archivo elegido se **copia** a la app.
- **CA-008-02 Validación**
  - **Dado** un archivo elegido
  - **Cuando** su contenido (bytes mágicos) corresponde a un tipo admitido (PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, ODT/ODS/ODP, RTF, TXT, CSV, MD, Pages/Numbers/Keynote) y respeta el límite (PDF ≤ **10 MB** (D18); resto ≤ 25 MB)
  - **Entonces** se acepta. Si no, se muestra el error (§5). HTML, SVG, XML, ejecutables, scripts y ZIP genéricos se rechazan aunque la extensión sea engañosa.
- **CA-008-03 Siempre arriba (R5, D5)**
  - **Dado** el editor con un documento
  - **Cuando** pulsa "Continuar"
  - **Entonces** la tarea se crea como actual, **sin** preguntar la posición.
- **CA-008-04 PDF a pantalla completa y sin conexión**
  - **Dado** que la tarea actual tiene un PDF
  - **Cuando** se abre la app (incluso en modo avión)
  - **Entonces** se muestra la primera página a pantalla completa en < 1 s (miniatura pregenerada, luego a resolución completa) con desplazamiento vertical continuo entre páginas, zoom (pellizco y doble toque) y el indicador "Página {n} de {total}"; modo inmersivo igual que en 007.
- **CA-008-05 PDF seguro**
  - **Dado** un PDF con JavaScript, formularios o enlaces
  - **Cuando** se muestra
  - **Entonces** no se ejecuta ningún script; los enlaces externos piden confirmación y se abren en el navegador del sistema.
- **CA-008-06 Documento no PDF**
  - **Dado** que la tarea actual tiene un documento no PDF
  - **Cuando** se muestra
  - **Entonces** aparece una tarjeta a pantalla completa con la insignia del tipo (DOCX, XLSX…), el nombre, el tamaño, el texto de la tarea (si lo hay) y el botón **"Abrir"**.
- **CA-008-07 Abrir con el visor del sistema**
  - **Dado** la tarjeta de un documento
  - **Cuando** pulsa "Abrir"
  - **Entonces** en iOS se abre la vista previa del sistema (QuickLook) dentro de la app, sin conexión; en Android se ofrece abrirlo con las apps instaladas, que reciben el archivo **solo en lectura**.
- **CA-008-08 Sin app compatible (Android)**
  - **Dado** que ninguna app puede abrir el tipo
  - **Cuando** pulsa "Abrir"
  - **Entonces** se muestra "No hay ninguna app para abrir este archivo. Instala un visor de documentos."
- **CA-008-09 Pantalla encendida**
  - **Dado** el ajuste activo
  - **Cuando** la tarea actual con PDF o documento está visible
  - **Entonces** la pantalla no se apaga (como en 007).

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-008-1 | PDF protegido con contraseña | Se acepta; se muestra la tarjeta "PDF protegido" con "Abrir" (visor del sistema) |
| CL-008-2 | PDF corrupto | Se rechaza al importar: "No hemos podido leer este archivo." |
| CL-008-3 | PDF con muchas páginas (p. ej. 300 páginas de texto en < 10 MB) | Carga perezosa; memoria acotada |
| CL-008-4 | Nombre de archivo con rutas o caracteres raros | Se sanea el nombre que se muestra; el archivo se guarda con un nombre generado |
| CL-008-5 | Extensión incoherente con el contenido (`.pdf` que es HTML) | Se rechaza como tipo no admitido |

## 5. Estados de error

| Estado | Texto |
|---|---|
| Tipo no admitido | "Este tipo de archivo no se admite." |
| Demasiado grande | "El archivo es demasiado grande (máx. {max} MB)." |
| Ilegible | "No hemos podido leer este archivo." |
| Sin app (Android) | "No hay ninguna app para abrir este archivo. Instala un visor de documentos." |
| Adjunto perdido | Como en 007 |

## 6. Accesibilidad

- Cada página del PDF expone su texto al lector de pantalla cuando el PDF lo contiene; si no, "Página {n} de {total}, {nombre}".
- Acciones "Página siguiente" y "Página anterior", además del desplazamiento.
- La tarjeta del documento se lee "{tipo} {nombre}, {tamaño}. Abrir".

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `docPageOf` | Página {page} de {total} | Page {page} of {total} |
| `docOpen` | Abrir | Open |
| `docProtected` | PDF protegido | Protected PDF |
| `docOpening` | Abriendo documento… | Opening document… |
| `errFileType` | Este tipo de archivo no se admite. | This file type isn't supported. |
| `errFileTooBig` | El archivo es demasiado grande (máx. {max} MB). | The file is too large (max {max} MB). |
| `errFileUnreadable` | No hemos podido leer este archivo. | We couldn't read this file. |
| `errNoViewerApp` | No hay ninguna app para abrir este archivo. Instala un visor de documentos. | No app can open this file. Install a document viewer. |
| `externalLinkConfirm` | ¿Abrir {host} en el navegador? | Open {host} in the browser? |
| `docNextPage` / `docPrevPage` | Página siguiente / Página anterior | Next page / Previous page |

## 8. Fuera de alcance

Ver Word o Excel dentro de la app (DEV-03), anotar o firmar PDF, buscar dentro del PDF.
