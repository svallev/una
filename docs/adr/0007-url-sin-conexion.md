# ADR-0007: URL como tarea: WebView endurecida en vivo + captura de página completa para sin conexión

- **Estado:** Provisional, pendiente del spike S4
- **Fecha:** 2026-09-24
- **Relacionado:** spec 009, modelo de amenazas (T-4, T-5, T-6), ADR-0001; riesgos R-04, R-05

## Contexto

- **[Hecho]** El prototipo muestra la página "dentro de la tarea". Una URL sin conexión no carga, y P3 exige funcionar sin conexión.
- **[Hecho]** Mostrar webs de terceros en una WebView expone a contenido no confiable.
- **[Hecho]** D9: guardar una captura de página completa al crear la tarea.

## Opciones consideradas

1. Captura de página completa (imagen)
2. PDF de la página
3. Archivo web (WebArchive/MHTML)
4. Solo en vivo

## Decisión

**Creación:**
1. Validar la URL: solo `http`/`https`; si falta el esquema, se añade `https://`. Se bloquean `javascript:`, `data:`, `file:`, `content:`, `intent:`, `about:` y el resto. El host debe tener un punto o ser una IP pública. Se rechazan credenciales en la URL (`user:pass@`). Las `http://` se intentan como `https://`; si falla, se ofrece abrirla en el navegador del sistema (ATS/`cleartextTrafficPermitted=false`).
2. Cargar la página en una WebView fuera de pantalla con la configuración endurecida (abajo), esperar a `onLoadStop` más un margen breve y capturar la **página completa** como imagen (máx. 20 000 px de alto, dividida en bloques si hace falta; ancho lógico de 390). Se guarda como `snapshot.webp`, con miniatura y `snapshotAt`.
3. Si no hay conexión al crearla: la tarea se crea con la URL, sin captura, y con el estado "Captura pendiente": se intentará la próxima vez que se abra la tarea con conexión.

**Visualización:**
- Con conexión: WebView **en vivo**, mostrando la captura debajo hasta que la página carga (arranque instantáneo, P2).
- Sin conexión o si la carga falla: la captura en el visor con zoom y el aviso "Copia del {fecha}" y el botón "Actualizar" (deshabilitado sin conexión).
- Barra superior: candado + **dominio real** (en punycode si mezcla alfabetos, contra los homógrafos IDN) + "WEB".

**WebView endurecida (obligatorio):**
- `javaScriptEnabled: true` (la mayoría de sitios lo necesitan) pero `javaScriptBridgeEnabled: false`, sin `addJavascriptInterface` ni *message handlers*.
- `allowFileAccess`, `allowContentAccess`, `allowFileAccessFromFileURLs` y `allowUniversalAccessFromFileURLs` a `false`.
- Almacén de datos **no persistente** (`WKWebsiteDataStore.nonPersistent()` en iOS; modo incógnito o borrar cookies y almacenamiento al cerrar en Android). Sin autorrellenado ni contraseñas guardadas.
- Navegación: se permite dentro del **mismo dominio registrable**. Otros dominios, `target=_blank` y `window.open` se abren en el **navegador del sistema** tras avisar. Los esquemas no http(s) se bloquean.
- Sin descargas, sin permisos (cámara, micrófono, geolocalización: todos denegados), sin depuración en *release* (`isInspectable` solo en debug).
- Se bloquea el contenido mixto.

## Motivos

- La imagen es **inerte**: no ejecuta nada sin conexión ni guarda cookies. Es fiel para horarios, mapas y recetas (propuesta 2), y reutiliza el visor con zoom.
- El PDF maqueta mal muchas webs; el archivo web guarda HTML y JS de terceros ejecutables.

## Consecuencias

- La captura ocupa espacio (≈ 1–4 MB): se muestra en el tamaño del adjunto.
- La captura de página completa en Android es la parte de más riesgo técnico → spike S4. Plan B: captura del viewport por desplazamiento y cosido, o `createPdf` y rasterizado.
- En la web de pruebas no hay WebView: se muestra la tarjeta con "Abrir página ↗" (como el prototipo) y sin captura.
