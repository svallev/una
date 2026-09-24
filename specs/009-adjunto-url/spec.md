# Spec 009: Tareas con una página web (URL), también sin conexión

- **Estado:** En revisión
- **Reglas de producto:** R3 (URL), R5, propuesta de valor 2
- **Pantallas del prototipo:** 9 "Añadir (+)", 11 "Tarea web (URL)", hoja "Cargar URL"
- **Decisiones y ADR:** D9, ADR-0007, DEV-04; modelo de amenazas T-4, T-5, T-6
- **Dependencias:** 007 (hoja "Añadir", visor con zoom)

## 1. Objetivo

Convertir una página web (el horario de un festival, una receta, un mapa) en la tarea actual, visible al abrir la app **aunque no haya conexión**.

## 2. Historias de usuario

- **HU-009-1** Como usuario, quiero guardar la página del programa del congreso como tarea y verla sin cobertura.
- **HU-009-2** Como usuario, quiero saber qué web estoy viendo (dominio real) y no salir de ella sin darme cuenta.

## 3. Criterios de aceptación

- **CA-009-01 Hoja "Cargar URL"**
  - **Dado** la hoja "Añadir a la tarea"
  - **Cuando** elige "Cargar URL"
  - **Entonces** aparece la hoja "Cargar URL" con un campo (teclado de URL, sin autocorrección) con el placeholder "https://", el texto "Se abre como tarea, arriba del todo." y el botón "Abrir".
- **CA-009-02 Validación**
  - **Dado** la hoja con un texto
  - **Cuando** pulsa "Abrir" (o Intro)
  - **Entonces**: vacío → "Escribe una dirección web."; sin esquema → se añade `https://`; esquema distinto de http/https (`javascript:`, `data:`, `file:`, `intent:`…) → "Solo se admiten direcciones web (http o https)."; host sin punto, credenciales `user:pass@` o URL no analizable → "Esa dirección no parece válida.". El error se anuncia como alerta.
- **CA-009-03 Crear con captura**
  - **Dado** una URL válida y conexión
  - **Cuando** pulsa "Abrir"
  - **Entonces** se muestra "Guardando una copia para verla sin conexión…" (cancelable), se carga la página en una vista web aislada, se guarda una **captura de página completa** y la tarea se crea como **actual** (sin texto, sin preguntar la posición).
- **CA-009-04 Crear sin conexión o si la captura falla**
  - **Dado** una URL válida y sin conexión (o un error o *timeout* de 20 s)
  - **Cuando** pulsa "Abrir"
  - **Entonces** la tarea se crea igualmente como actual, con la marca "Copia pendiente"; la captura se intentará la próxima vez que la tarea se muestre con conexión.
- **CA-009-05 Ver en vivo**
  - **Dado** la tarea web actual y conexión
  - **Cuando** se muestra
  - **Entonces** se ve al instante la captura y, encima, la página en vivo en cuanto carga; arriba, una barra con el candado, el **dominio real** y la insignia "WEB".
- **CA-009-06 Ver sin conexión**
  - **Dado** la tarea web actual y sin conexión (o si la carga en vivo falla)
  - **Cuando** se muestra
  - **Entonces** se ve la captura con zoom y desplazamiento, el aviso "Copia del {fecha}" y el botón "Actualizar" (deshabilitado sin conexión).
- **CA-009-07 Actualizar la captura**
  - **Dado** conexión
  - **Cuando** pulsa "Actualizar"
  - **Entonces** se genera una nueva captura que sustituye a la anterior y cambia la fecha.
- **CA-009-08 Navegación contenida**
  - **Dado** la página en vivo
  - **Cuando** el usuario sigue un enlace a **otro dominio**, uno que abre ventana nueva o un esquema no web (`tel:`, `mailto:`, `intent:`…)
  - **Entonces** no navega dentro de la tarea: pregunta "¿Abrir {dominio} en el navegador?" y, si acepta, lo abre en el navegador del sistema (los esquemas no web se bloquean o se delegan al sistema tras confirmar).
- **CA-009-09 Aislamiento**
  - **Dado** la vista web
  - **Cuando** carga cualquier página
  - **Entonces** no tiene acceso a archivos de la app, no tiene puente con la app, no guarda cookies ni datos entre sesiones, no puede pedir cámara, micrófono ni ubicación, y no descarga archivos.
- **CA-009-10 Dominio visible e IDN**
  - **Dado** un dominio con caracteres internacionales que mezclan alfabetos (posible homógrafo)
  - **Cuando** se muestra la barra
  - **Entonces** se muestra el dominio en punycode (`xn--…`).
- **CA-009-11 Solo conexión segura**
  - **Dado** una URL `http://` cuyo servidor no admite https
  - **Cuando** se intenta cargar
  - **Entonces** se muestra "Esta página no usa conexión segura. Ábrela en el navegador." con el botón "Abrir en el navegador"; no se crea la captura.
- **CA-009-12 Editar**
  - **Dado** una tarea web
  - **Cuando** elige Editar (spec 005)
  - **Entonces** se abre "Cargar URL" con la dirección actual; al confirmar, se regenera la captura y la tarea conserva su posición.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-009-1 | Página enorme (> 20 000 px) | La captura se corta a 20 000 px con la nota "Copia parcial" |
| CL-009-2 | Página con banner de cookies o muro de registro | Se captura tal cual (no se manipula el contenido de terceros) |
| CL-009-3 | Redirecciones a otro dominio al cargar | Se permiten durante la carga inicial; el dominio mostrado es el final; se avisa si difiere del escrito |
| CL-009-4 | La URL devuelve un PDF | Se ofrece guardarlo como tarea de documento (spec 008) **[Pendiente P-6]** |
| CL-009-5 | Web de pruebas (navegador) | Sin vista web: tarjeta con el dominio y "Abrir página ↗" (como el prototipo) |

## 5. Estados de error

| Estado | Texto |
|---|---|
| URL vacía | "Escribe una dirección web." |
| Esquema no permitido | "Solo se admiten direcciones web (http o https)." |
| URL no válida | "Esa dirección no parece válida." |
| Sin https | "Esta página no usa conexión segura. Ábrela en el navegador." |
| Captura pendiente | "Copia pendiente: se guardará cuando haya conexión." |
| Sin conexión y sin captura | "Necesitas conexión para ver esta página por primera vez." |

## 6. Accesibilidad

- La página en vivo es accesible por la propia vista web; la captura se lee "Copia de {dominio} del {fecha}" con acciones de zoom.
- La barra del dominio se lee "Página web de {dominio}".
- Las confirmaciones para salir al navegador son diálogos modales.

## 7. Textos (ES / EN)

| Clave | ES | EN |
|---|---|---|
| `urlSheetTitle` | Cargar URL | Load URL |
| `urlPlaceholder` | https:// | https:// |
| `urlHelp` | Se abre como tarea, arriba del todo. | It opens as a task, on top. |
| `urlOpen` | Abrir | Open |
| `urlErrEmpty` | Escribe una dirección web. | Enter a web address. |
| `urlErrScheme` | Solo se admiten direcciones web (http o https). | Only web addresses (http or https) are supported. |
| `urlErrInvalid` | Esa dirección no parece válida. | That address doesn't look valid. |
| `urlSaving` | Guardando una copia para verla sin conexión… | Saving a copy to view offline… |
| `urlSnapshotOf` | Copia del {date} | Copy from {date} |
| `urlSnapshotPartial` | Copia parcial | Partial copy |
| `urlRefresh` | Actualizar | Refresh |
| `urlSnapshotPending` | Copia pendiente: se guardará cuando haya conexión. | Copy pending: it'll be saved when you're online. |
| `urlNeedsConnection` | Necesitas conexión para ver esta página por primera vez. | You need a connection to view this page for the first time. |
| `urlInsecure` | Esta página no usa conexión segura. Ábrela en el navegador. | This page doesn't use a secure connection. Open it in the browser. |
| `urlOpenInBrowser` | Abrir en el navegador | Open in browser |
| `urlLeaveConfirm` | ¿Abrir {host} en el navegador? | Open {host} in the browser? |
| `urlA11yBar` | Página web de {host} | Web page from {host} |
| `urlOpenPageWeb` | Abrir página ↗ | Open page ↗ |

## 8. Fuera de alcance

Guardar varias URL por tarea, lector de artículos, compartir desde el navegador hacia la app (*share extension*, futuro).

## 9. Preguntas abiertas

- **[Pendiente P-6]** Si una URL apunta directamente a un PDF: ¿descargarlo como tarea de documento? Recomendación: sí (mejor experiencia sin conexión), con el mismo límite de 10 MB (D18). Decide: producto.
