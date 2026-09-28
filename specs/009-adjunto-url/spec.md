# Spec 009: Tareas con una página web (URL), también sin conexión

- **Estado:** En revisión. Reescrita el 2026-09-28 tras la revisión de `spec-reviewer` frente a las decisiones de la 007, la 008 y los ADR-0012 a 0015, con las respuestas del propietario: **una URL que es un PDF queda fuera de la v1** (P-6), **la tarea web no tiene texto** (como el prototipo) y **la copia usa el zoom del PDF y no gira**
- **Reglas de producto:** R3 (URL), R5 (arriba del todo), R8 (abrir → tarea actual rápido), **propuesta de valor 2**
- **Pantallas del prototipo:** 9 "Añadir (+)", 11 "Tarea web (URL)", hoja "Cargar URL". Los errores, "Guardando una copia…", "Actualizar" y la confirmación de salida no están en el prototipo (R-17): se hacen con los componentes existentes (hoja, franja, tarjeta, confirmación de la 008) y se revisan en el móvil
- **Decisiones y ADR:** ADR-0007 (**enmendado** por esta spec: ver §10), D9, D10 (la tarea web **no** gira), D17, ADR-0004 (y R-10), ADR-0010, ADR-0011, ADR-0012 (completar borra los archivos), ADR-0013 (**no** aplica a la copia: su zoom es el del PDF, que se queda y tiene alternativas), ADR-0014 (solo PDF: una URL que es un PDF no se descarga), ADR-0015, DEV-04, DEV-17, DEV-18, DEV-21; modelo de amenazas T-4, T-5, T-6
- **Dependencias:** 001 a 008 (hoja "Añadir", editor, borrado único y barrido, "Adjunto no disponible", pantalla encendida, reglas y confirmación de enlaces de CA-008-12, zoom de CA-008-10)
- **Enmienda:** CA-008-13 ("solo PDF": la tarea web también mantiene la pantalla encendida, CA-009-23)
- **Cierra lo diferido a la 009:** CA-005-08 (editar una tarea web), la nota de CA-006-13 (un toque en una tarea web), la insignia "WEB" de CA-006-02, la lectura de la fila con web (CA-006-18), la etiqueta sin texto de CA-004-01 y CL-003-8 (el dominio), CL-003-4 (la rotura y el arrugado con web) y DEV-18 ("Cargar URL")

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.
> Los tests no usan red: los CA que cargan páginas se verifican con páginas de prueba servidas en local. **"Sin conexión"** = la carga falla por un error de red (sin red, sin DNS o servidor inalcanzable); un certificado no válido o una respuesta HTTP no cuentan como "sin conexión".

## 1. Objetivo

Convertir una página web (el horario de un festival, una receta, un mapa) en la tarea actual, visible al abrir la app **aunque no haya conexión**.

## 2. Historias de usuario

- **HU-009-1** Como usuario, quiero guardar la página del programa del congreso como tarea y verla sin cobertura.
- **HU-009-2** Como usuario, quiero saber qué web estoy viendo (dominio real) y no salir de ella sin darme cuenta.

## 3. Criterios de aceptación

**Crear y editar**

- **CA-009-01 Hoja "Cargar URL"** (cierra DEV-18)
  - **Dado** la hoja "Añadir a la tarea" (CA-007-01), al crear o al editar una tarea
  - **Cuando** elige "Cargar URL"
  - **Entonces** aparece la hoja "Cargar URL" con un campo (teclado de URL, sin autocorrección ni sugerencias) con el placeholder "https://", el texto "Se abre como tarea, arriba del todo." y el botón "Abrir". Si el editor ya tiene texto o un adjunto, el texto de ayuda es "Sustituye el texto y el adjunto de la tarea." La hoja se cierra como las demás (DEV-21) y, al cerrarla sin abrir, el editor queda como estaba.
- **CA-009-02 Validación**
  - **Dado** la hoja con un texto
  - **Cuando** pulsa "Abrir" (o Intro)
  - **Entonces**:
    - se quitan los espacios de los extremos; vacío → "Escribe una dirección web.";
    - sin esquema → se añade `https://`;
    - esquema distinto de http/https (`javascript:`, `data:`, `file:`, `content:`, `intent:`, `about:`…) → "Solo se admiten direcciones web (http o https).";
    - host sin punto, `localhost`, una IP privada, de bucle o local, credenciales `usuario:clave@` o `usuario@`, o URL no analizable → "Esa dirección no parece válida.";
    - el error se anuncia como alerta, el foco sigue en el campo y la hoja no se cierra.
- **CA-009-03 Crear con copia**
  - **Dado** una URL válida y conexión
  - **Cuando** pulsa "Abrir"
  - **Entonces** se muestra "Guardando una copia para verla sin conexión…" con "Cancelar"; se carga la página en una vista web aislada (CA-009-14); se guarda una **copia de la página completa** (CA-009-19) y la tarea se crea como **actual**, arriba del todo (R5, CA-007-05), **sin texto** y sin preguntar la posición. Un doble toque en "Abrir" crea una sola tarea.
- **CA-009-04 Crear sin conexión o con tiempo agotado**
  - **Dado** una URL válida y sin conexión, o 20 s desde que pulsó "Abrir" sin tener la copia
  - **Cuando** pulsa "Abrir" (o se agotan los 20 s)
  - **Entonces** la tarea se crea igualmente como actual, con la marca "Copia pendiente"; la copia se intentará sola, sin avisar, la próxima vez que la tarea se muestre con conexión.
- **CA-009-05 Cancelar**
  - **Dado** "Guardando una copia…" (al crear, al editar o al actualizar)
  - **Cuando** pulsa "Cancelar" (o el gesto atrás)
  - **Entonces** no se crea ni cambia nada, no queda ningún archivo (CA-009-20) y se vuelve a la hoja "Cargar URL" con la dirección escrita (al actualizar, a la tarea como estaba).
- **CA-009-06 Editar** (cierra CA-005-08 y la nota de CA-006-13)
  - **Dado** una tarea web
  - **Cuando** elige Editar (spec 005, o la fila del listado, CA-006-13)
  - **Entonces** se abre directamente "Cargar URL" con la dirección actual. Al confirmar otra dirección válida: se genera la copia nueva como en CA-009-03/04; la tarea **conserva su posición y su color**, y se vuelve al origen (como CA-007-05). Si la carga falla por CA-009-15/16, la tarea conserva la dirección y la copia anteriores y la hoja sigue abierta con el mensaje. Confirmar la misma dirección no hace nada.
- **CA-009-07 Convertir una tarea en web**
  - **Dado** el editor de una tarea con texto, imagen o PDF (al crear o al editar)
  - **Cuando** abre una URL desde "Cargar URL"
  - **Entonces** la tarea pasa a ser web: el texto y el adjunto anteriores se descartan (sus archivos se borran al guardar, CA-009-20); al editar, la tarea es la misma, con su posición y su color. Convertir una tarea web en otra cosa queda fuera de alcance (§8).

**Ver**

- **CA-009-08 Ver en vivo** (R8)
  - **Dado** la tarea web actual y conexión
  - **Cuando** se muestra
  - **Entonces** la copia (o, si está pendiente, la tarjeta de CA-009-10) aparece en el tiempo de CA-001-09 (< 1 s p50, *release*), sin esperar a la vista web; encima, la página en vivo en cuanto carga. Arriba, una **franja** con el candado, el **dominio real**, la insignia "WEB" y "Actualizar".
- **CA-009-09 Ver sin conexión**
  - **Dado** la tarea web actual y sin conexión (o si la carga en vivo falla)
  - **Cuando** se muestra
  - **Entonces** se ve la copia al ancho de la pantalla, con desplazamiento vertical y **el zoom del PDF** (CA-008-10: de ×1 a ×4 y se queda; doble toque; acciones del lector y de Switch Access; teclas; sin animar con reducir movimiento), el aviso "Copia del {date}" (y "Copia parcial" si lo es, CL-009-1) y "Actualizar".
- **CA-009-10 Sin copia**
  - **Dado** una tarea web con "Copia pendiente" (o cuyo archivo de copia falta o no se puede abrir)
  - **Cuando** se muestra sin conexión
  - **Entonces** se ve una tarjeta con el dominio, "Copia pendiente: se guardará cuando haya conexión." y "Necesitas conexión para ver esta página por primera vez." Una copia que falta se trata como pendiente (la dirección basta para rehacerla): **no** se muestra "Adjunto no disponible".
- **CA-009-11 Actualizar la copia**
  - **Dado** la tarea web actual, en vivo o sin conexión
  - **Cuando** pulsa "Actualizar" (siempre activo, DEV-17)
  - **Entonces**: con conexión, "Guardando una copia…" con "Cancelar" y la copia nueva sustituye a la anterior, con su fecha, **solo cuando está guardada**; sin conexión, el aviso "Necesitas conexión para actualizar la copia."; si falla (CA-009-15/16 o 20 s), se conservan la copia y la fecha anteriores y se muestra el motivo.
- **CA-009-12 No gira**
  - **Dado** la tarea web actual y el móvil en horizontal
  - **Cuando** se muestra
  - **Entonces** la app sigue en vertical (D10: solo giran la imagen y el PDF).

**Seguridad**

- **CA-009-13 Navegación contenida**
  - **Dado** la página en vivo
  - **Cuando** el usuario sigue un enlace
  - **Entonces**:
    - dentro del **mismo dominio registrable** navega sin preguntar (p. ej. de `es.wikipedia.org` a `en.wikipedia.org`);
    - a otro dominio registrable (`wikipedia.org` → `wikimedia.org`), uno que abre ventana nueva o una ventana que abre la página: no navega dentro de la tarea; pregunta "¿Abrir {host} en el navegador?" y, si acepta, lo abre en el navegador del sistema;
    - los esquemas no web siguen la regla de los enlaces del PDF (CA-008-12): `mailto:` y `tel:` con "¿Abrir {target} con otra app?" y el mismo saneado; el resto no hace nada;
    - la confirmación es la de la 008 ("Cancelar" primero y con el foco) y, sin app para abrirlo, "No hay ninguna app para abrir este enlace.";
    - la tarea no cambia de dirección: al volver a mostrarla, se carga la dirección guardada.
- **CA-009-14 Aislamiento**
  - **Dado** la vista web
  - **Cuando** carga cualquier página
  - **Entonces** no tiene acceso a archivos de la app, no tiene puente con la app, no guarda cookies ni datos entre cargas, no puede pedir cámara, micrófono ni ubicación, no rellena formularios ni guarda contraseñas y no descarga archivos (una descarga no hace nada; una URL que es un PDF, CL-009-4).
- **CA-009-15 Solo conexión segura**
  - **Dado** una URL `http://`
  - **Cuando** se intenta cargar
  - **Entonces** primero se intenta la misma dirección con `https://` (y se guarda así si funciona); si el servidor no admite https, se muestra "Esta página no usa conexión segura. Ábrela en el navegador." con "Abrir en el navegador", **no se crea la tarea** (la hoja sigue abierta) y no se crea ninguna copia.
- **CA-009-16 Certificado no válido o página de error**
  - **Dado** una URL cuyo certificado no es válido (caducado, autofirmado, de otro dominio) o cuya página principal responde con un error HTTP (≥ 400)
  - **Cuando** se intenta crear la tarea, editarla o actualizar la copia
  - **Entonces** no se guarda ninguna copia (tampoco una página en blanco ni la página de error del sitio), se muestra "No se ha podido cargar la página ({reason})." con "Abrir en el navegador" y, al crear, **no se crea la tarea** (la hoja sigue abierta). Un certificado no válido **nunca** se acepta, ni en la carga en vivo.
- **CA-009-17 Dominio visible e IDN**
  - **Dado** la franja
  - **Cuando** muestra el dominio
  - **Entonces** es el dominio **final** de la página (tras las redirecciones), completo (con `www.` si lo tiene; DEV nueva); si mezcla alfabetos (posible homógrafo), en punycode (`xn--…`), con la misma regla que los enlaces del PDF.
- **CA-009-18 Red y permisos (P4)**
  - **Dado** la app *release*
  - **Cuando** se instala y se usa
  - **Entonces** solo añade el permiso de Internet (sin diálogo) y ningún otro; la app no se conecta a nada salvo para cargar la dirección de una tarea web (al crearla, mostrarla, editarla o actualizarla); los registros no incluyen la URL ni el dominio; la ficha de privacidad sigue en "Data Not Collected".

**Guardar y borrar**

- **CA-009-19 Copia de la página completa**
  - **Dado** una página que carga o anima contenido al desplazarse
  - **Cuando** se genera la copia
  - **Entonces** la copia incluye ese contenido (la página se recorre antes de copiarla), mide como mucho 20 000 puntos de alto a un ancho de 390 puntos (CL-009-1) y se guarda con: la dirección (normalizada), el dominio final, la fecha de la copia y si es parcial. Una tarea pendiente guarda la dirección y que está pendiente.
- **CA-009-20 Ningún archivo huérfano** (ADR-0011, ADR-0012)
  - **Dado** cualquier camino que deje una copia sin uso: completar o eliminar la tarea (desde la pantalla principal o el listado), editar la dirección, convertir la tarea (CA-009-07), "Actualizar", cancelar, un error, tiempo agotado, falta de espacio, un fallo al guardar o la app cerrada por el sistema a mitad de la copia
  - **Cuando** termina la operación
  - **Entonces** no queda ningún archivo de esa copia ni temporales, con **el mismo borrado** que la 007 y la 008 (CA-008-16); si falla, lo recoge el barrido del siguiente arranque. Una copia que se está guardando nunca se barre.
- **CA-009-21 Sin espacio y fallo al guardar**
  - **Dado** que no queda espacio o falla el guardado
  - **Cuando** se crea, edita o actualiza una tarea web
  - **Entonces** "Tu teléfono no tiene espacio libre" con "Reintentar", o "No hemos podido guardar la tarea", como en la 007; nada a medias.
- **CA-009-22 Copia de seguridad** (ADR-0004, R-10)
  - **Dado** tareas web
  - **Cuando** Android hace la copia de seguridad
  - **Entonces** la dirección va con la tarea y las copias de las páginas siguen la regla de las imágenes (CA-007-18): **fuera** de la copia en la nube.
- **CA-009-23 Pantalla encendida** (enmienda CA-008-13)
  - **Dado** el ajuste "Mantener la pantalla encendida con adjuntos" activo
  - **Cuando** se ve la tarea web actual (en vivo o la copia)
  - **Entonces** la pantalla no se apaga, con el límite de 10 minutos sin tocar y las condiciones de CA-007-12.

**Donde aparece la tarea web**

- **CA-009-24 Resto de la app** (cierra CA-006-02 "WEB", CA-004-01, CL-003-4, CL-003-8)
  - **Dado** una tarea web
  - **Cuando** aparece fuera de la pantalla principal
  - **Entonces**:
    - **Listado:** insignia negra de 44 px con "WEB" entre el asa y el texto, como el PDF; decorativa para el lector;
    - **Etiqueta:** en el listado, la confirmación de eliminar y los anuncios, el **dominio**;
    - **Completar y eliminar:** la rotura y el arrugado muestran lo que se ve (franja y copia o página en vivo); con reducir movimiento, sus alternativas.

**Accesibilidad**

- **CA-009-25 Lectura**
  - **Dado** un lector de pantalla
  - **Cuando** lee una tarea web
  - **Entonces**:
    - la franja es un único elemento: "Tarea actual: {host}. Página web", seguido de "Copia del {date}" o "Copia pendiente" cuando no se ve en vivo;
    - la copia se lee "Copia de {host} del {date}" y lleva las acciones de zoom y desplazamiento (CA-008-10);
    - la página en vivo es accesible por la propia vista web;
    - **Completar tarea** y **Eliminar tarea** están en la franja y en la copia (TalkBack solo ofrece las acciones del nodo enfocado; lo que falló en la 008), además del botón y el menú;
    - fila del listado: "{n} de {total}: {host}. Página web";
    - anuncios de completar y eliminar: "Tarea completada. Siguiente: {host}".
- **CA-009-26 Foco y anuncios**
  - **Dado** un lector de pantalla activo
  - **Cuando** ocurre cada acción
  - **Entonces** un único anuncio y el foco donde dice la tabla (con la limitación de TalkBack aceptada en CA-007-22):

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Abre "Cargar URL" | El campo | El título de la hoja |
    | Error de validación | El campo | El texto del error |
    | "Guardando una copia…" | "Cancelar" | "Guardando una copia para verla sin conexión…" |
    | Cancela | El campo (o "Actualizar") | Ninguno |
    | Tarea creada o editada | Como CA-007-05 | Como CA-007-05 |
    | Error de carga (CA-009-15/16) | "Abrir en el navegador" | El texto del error |
    | Copia actualizada | "Actualizar" | "Copia actualizada" |
    | "Actualizar" sin conexión | "Actualizar" | "Necesitas conexión para actualizar la copia." |
    | Confirmación de salida | "Cancelar" | El texto de la confirmación |
    | Cierra la confirmación o vuelve del navegador | Donde estaba | Ninguno |
    | Ampliar, Reducir, Ajustar al ancho (copia) | Donde estaba | "Zoom {percent} %" |

- **CA-009-27 Reducir movimiento, teclado y texto grande**
  - **Dado** "reducir movimiento", un teclado o el texto al 200 %
  - **Cuando** se usan la hoja o la tarea web
  - **Entonces**: con reducir movimiento, el zoom de la copia y "Guardando una copia…" no se animan; con teclado, lo de CA-008-22 sobre la copia, e Intro en el campo equivale a "Abrir"; con el texto al 200 % en un móvil de 360 dp, la hoja, la franja (dominio con "…"), los avisos, los errores y la confirmación se ven enteros y todos los botones ("Abrir", "Cancelar", "Actualizar", "Abrir en el navegador") miden ≥ 48 dp.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-009-1 | Página de más de 20 000 puntos de alto | La copia se corta a 20 000 con la nota "Copia parcial" |
| CL-009-2 | Página con banner de cookies o muro de registro | Se copia tal cual (no se manipula el contenido de terceros) |
| CL-009-3 | Redirecciones a otro dominio al cargar | Se permiten durante la carga inicial; el dominio mostrado es el final; si difiere del escrito, se avisa "Esta dirección te ha llevado a {host}." |
| CL-009-4 | La URL devuelve un PDF (u otro archivo) | **Fuera de la v1** (P-6, ADR-0014): no se descarga ni se crea la tarea; "Esta dirección es un archivo, no una página. Descárgalo y súbelo con «Subir archivo»." con "Abrir en el navegador" |
| CL-009-5 | Web de pruebas (navegador) | Sin vista web ni copia: tarjeta con el dominio y "Abrir página ↗" (como el prototipo, DEV-04); solo en memoria, sin "Copia pendiente" |
| CL-009-6 | La app se cierra a mitad de "Guardando una copia…" | Al crear: no hay tarea ni archivos. Al actualizar: la copia anterior sigue |
| CL-009-7 | Tarea pendiente y la copia automática falla | Sigue pendiente, sin avisar; "Actualizar" muestra el motivo |

## 5. Estados de error

| Estado | Texto |
|---|---|
| URL vacía | "Escribe una dirección web." |
| Esquema no permitido | "Solo se admiten direcciones web (http o https)." |
| URL no válida | "Esa dirección no parece válida." |
| Sin https | "Esta página no usa conexión segura. Ábrela en el navegador." |
| Certificado o error HTTP | "No se ha podido cargar la página ({reason})." |
| La URL es un archivo | "Esta dirección es un archivo, no una página. Descárgalo y súbelo con «Subir archivo»." |
| Copia pendiente | "Copia pendiente: se guardará cuando haya conexión." |
| Sin conexión y sin copia | "Necesitas conexión para ver esta página por primera vez." |
| Actualizar sin conexión | "Necesitas conexión para actualizar la copia." |
| Sin espacio / fallo al guardar | `storageErrorNoSpace` + `retry` / `editorSaveError` (se reutilizan) |
| Sin app para un enlace | `errNoAppForLink` (se reutiliza) |

## 6. Accesibilidad

Ver CA-009-25 a CA-009-27. Las confirmaciones para salir al navegador son las de la 008 (modales, "Cancelar" primero). "Guardando una copia…" es una espera anunciada con alternativa ("Cancelar").

## 7. Textos (ES / EN)

Se reutilizan: `attachUrl` (título de la hoja: "Cargar URL"), `openInBrowserConfirm`, `openInAppConfirm`, `linkConfirmCancel`, `errNoAppForLink`, `storageErrorNoSpace`, `retry`, `editorSaveError`. `{date}` es la fecha corta del idioma (ES "28/09/2026", EN "Sep 28, 2026").

| Clave | ES | EN |
|---|---|---|
| `urlPlaceholder` | https:// | https:// |
| `urlHelp` | Se abre como tarea, arriba del todo. | It opens as a task, on top. |
| `urlHelpReplaces` | Sustituye el texto y el adjunto de la tarea. | It replaces the task's text and attachment. |
| `urlOpen` | Abrir | Open |
| `urlErrEmpty` | Escribe una dirección web. | Enter a web address. |
| `urlErrScheme` | Solo se admiten direcciones web (http o https). | Only web addresses (http or https) are supported. |
| `urlErrInvalid` | Esa dirección no parece válida. | That address doesn't look valid. |
| `urlSaving` | Guardando una copia para verla sin conexión… | Saving a copy to view offline… |
| `urlSavingCancel` | Cancelar | Cancel |
| `urlSnapshotOf` | Copia del {date} | Copy from {date} |
| `urlSnapshotPartial` | Copia parcial | Partial copy |
| `urlRefresh` | Actualizar | Refresh |
| `urlRefreshed` | Copia actualizada | Copy updated |
| `urlRefreshOffline` | Necesitas conexión para actualizar la copia. | You need a connection to update the copy. |
| `urlSnapshotPending` | Copia pendiente: se guardará cuando haya conexión. | Copy pending: it'll be saved when you're online. |
| `urlPendingShort` | Copia pendiente | Copy pending |
| `urlNeedsConnection` | Necesitas conexión para ver esta página por primera vez. | You need a connection to view this page for the first time. |
| `urlInsecure` | Esta página no usa conexión segura. Ábrela en el navegador. | This page doesn't use a secure connection. Open it in the browser. |
| `urlIsFile` | Esta dirección es un archivo, no una página. Descárgalo y súbelo con «Subir archivo». | This address is a file, not a page. Download it and add it with "Upload file". |
| `urlRedirected` | Esta dirección te ha llevado a {host}. | This address took you to {host}. |
| `urlOpenInBrowser` | Abrir en el navegador | Open in browser |
| `urlOpenPageWeb` | Abrir página ↗ | Open page ↗ |
| `urlLoadFailed` | No se ha podido cargar la página ({reason}). | Couldn't load the page ({reason}). |
| `urlReasonCertificate` | certificado no válido | invalid certificate |
| `urlReasonHttp` | error {code} del sitio | site error {code} |
| `urlReasonTimeout` | tarda demasiado | it takes too long |
| `attachmentWeb` | WEB | WEB |
| `a11yWebOnly` | {host}. Página web | {host}. Web page |
| `a11yRowWebOnly` | {host}. Página web | {host}. Web page |
| `a11yWebSnapshot` | Copia de {host} del {date} | Copy of {host} from {date} |

El texto de "Subir archivo" en `urlIsFile` debe coincidir con `attachUploadFile` en cada idioma. Glosario: "Copia", "Copia pendiente", "Copia parcial" y "Franja" (también para la web).

## 8. Fuera de alcance

Guardar varias URL por tarea; texto en una tarea web; convertir una tarea web en otra cosa (se elimina y se crea otra); descargar un PDF o un archivo desde una URL (P-6, v1); lector de artículos; compartir desde el navegador hacia la app (*share extension*, futuro); la miniatura en "Recientes" (spec 010).

## 9. Preguntas abiertas

Ninguna. **P-6** decidida por el propietario (2026-09-28): una URL que es un PDF **no** se descarga en la v1 (CL-009-4).

## 10. Cambios en otros documentos al implementar

- **ADR-0007** (enmienda): `mailto:` y `tel:` con confirmación, como los enlaces del PDF (antes: "los esquemas no http(s) se bloquean"); la copia usa el zoom del PDF (no hay visor de imágenes, ADR-0013); sin descargas, tampoco de PDF (P-6).
- **`threat-model.md` T-5:** la navegación de la tarea web sigue las reglas de los enlaces del PDF.
- **`docs/PLAN.md`:** P-6 cerrada ("No en la v1").
- **`prototype-deviations.md`:** DEV nueva por el dominio con `www.`; DEV-04 y DEV-18 al día.
- **Specs 005, 006 y 008:** notas "cerrado por la 009" en lo diferido y la enmienda de CA-008-13.
