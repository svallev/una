# Spec 009: Tareas con una página web (URL)

- **Estado:** **Aprobada** (propietario, 2026-09-28), con las propuestas de §9. Reescrita ese día con sus decisiones: **se guarda solo la dirección y la página se carga en vivo cada vez; nada de la página se guarda en el móvil** (ADR-0016). Sin revisión de `spec-reviewer` (aprobada directamente por el propietario). **Enmendada el 2026-09-29 (ADR-0018): sin navegación; solo se ve la página de la dirección guardada**. Enmendada también el 2026-09-29 (propietario): sin candado con el aviso de conexión no segura (CA-009-06) y ese aviso cuando una dirección `http://` intenta, mientras carga, ir a otra `http://` (CA-009-09, CA-009-11); y el límite de recargas: a la segunda vez seguida que la página intenta ir a otra, aviso en lugar de recargar (CA-009-11, §5, §7)
- **Reglas de producto:** R3 (URL), R5 (los adjuntos van arriba del todo), R8 (abrir → tarea actual rápido). La propuesta de valor 2 **sin conexión no aplica** a la tarea web (ADR-0016)
- **Pantallas del prototipo:** 9 "Añadir (+)", 11 "Tarea web (URL)", hoja "Cargar URL", 5 "Todas las tareas" (insignia). Los errores, el estado de carga y el horizontal no están en el prototipo (R-17): se hacen con los componentes existentes y se revisan en el móvil
- **Decisiones y ADR:** **ADR-0016 (web sin copia local; sustituye a D9 y enmienda el ADR-0007)**, **ADR-0018 (sin navegación; enmienda el ADR-0007 y el ADR-0016)**, ADR-0007 (validación y WebView endurecida: se mantienen), D10 y ADR-0013/0014/0015 (giro y excepción del horizontal), ADR-0012 (completar y eliminar borran la tarea del todo), DEV-04 (cambia), DEV-18; modelo de amenazas T-4, T-5, T-6
- **Dependencias:** 001 a 008 (hoja "Añadir", giro, pantalla encendida, `LinkOpener` de la 008 para "Abrir en el navegador", listado)
- **Enmienda:** CA-007-01 (en modo editar, la hoja "Añadir a la tarea" **no muestra** "Cargar URL"; CA-009-01)
- **Cierra:** DEV-18 para "Cargar URL" y la pregunta P-6 (una URL que es un PDF: fuera de la v1, CL-009-4)

> Esta spec describe **qué** y **por qué**, sin tecnología. El **cómo** va en `plan.md`.

## 1. Objetivo

Tener **una** página web (la carta de un restaurante, la página de contacto de una web, la agenda de un congreso o de un festival) como tarea actual, **a la vista nada más abrir la app**, con el dominio real siempre visible.

Es una **consulta**, como una imagen o un PDF: se ve **solo esa dirección**. Una no es un navegador: los enlaces de la página no llevan a ninguna parte (ADR-0018).

La app **no guarda la página**: guarda la dirección y la carga cada vez que se muestra la tarea. Sin conexión, la tarea lo dice (ADR-0016).

Es una función **que necesita conexión** y de **uso ocasional**: para tener algo a mano sin cobertura están la imagen (007) y el PDF (008) (propietario, 2026-09-28).

## 2. Historias de usuario

- **HU-009-1** Como asistente a un congreso, quiero la página del programa como tarea, para verla al abrir la app sin buscarla en el navegador.
- **HU-009-2** Como usuario, quiero saber qué web estoy viendo (el dominio real) y que la tarea siga siendo esa página, toque lo que toque.
- **HU-009-3** Como usuario, quiero que la app no guarde nada de las webs que veo.

## 3. Criterios de aceptación

**Crear y editar**

- **CA-009-01 Hoja "Cargar URL" (cierra DEV-18 para esta fila; enmienda CA-007-01)**
  - **Dado** la hoja "Añadir a la tarea" desde el editor de una tarea **nueva** (primera tarea, nueva tarea desde el menú, el listado o "Todo hecho.")
  - **Cuando** elige "Cargar URL — Una página web · va arriba del todo"
  - **Entonces** sube la hoja "Cargar URL", como en el prototipo:
    - el título "Cargar URL" y la X;
    - un campo con teclado de URL, sin autocorrección, sin mayúscula inicial ni sugerencias, con el marcador "https://" y el foco puesto;
    - el texto "Se abre como tarea, arriba del todo.";
    - el botón "Abrir".
  - Cerrarla (con la X, tocando fuera, deslizando hacia abajo o con el gesto atrás, DEV-21) deja el editor como estaba.
  - En modo **editar** una tarea que no es web, la hoja "Añadir a la tarea" tiene solo tres filas, sin "Cargar URL": una tarea no se convierte en web (propietario, 2026-09-28).
- **CA-009-02 Validación**
  - **Dado** la hoja con un texto
  - **Cuando** pulsa "Abrir" o Intro
  - **Entonces**, quitando antes los espacios del principio y del final:
    - vacío → "Escribe una dirección web.";
    - sin esquema → se añade `https://`;
    - esquema distinto de `http` o `https` (`javascript:`, `data:`, `file:`, `content:`, `intent:`, `about:`…) → "Solo se admiten direcciones web (http o https).";
    - no analizable, host sin punto, dirección privada o local (`localhost`, `10.x`, `192.168.x`, `127.x`…), usuario o contraseña en la dirección (`user:pass@`) o más de 2048 caracteres → "Esa dirección no parece válida.".
  - El error aparece bajo el campo, se anuncia como alerta, y el foco y el texto se quedan en el campo.
- **CA-009-03 Crear sin texto, siempre arriba (R5)**
  - **Dado** una dirección válida
  - **Cuando** pulsa "Abrir"
  - **Entonces** se crea al momento una tarea **sin texto** con esa dirección, como **tarea actual**, sin preguntar la posición y **sin cargar nada todavía** (no hace falta conexión para crearla). Se vuelve al origen:
    - a la pantalla principal mostrándola (CA-009-06);
    - o, si viene del listado, al listado con la fila en la posición 1, resaltada y con el foco (como CA-008-05).
  - Si el editor tenía texto escrito, se descarta, como en el prototipo. Si tenía una imagen o un PDF elegidos, también se descartan, sin dejar archivos (CA-008-16).
  - Un doble toque rápido en "Abrir" crea una sola tarea.
- **CA-009-04 Solo se guarda la dirección (ADR-0016)**
  - **Dado** una tarea web
  - **Cuando** se crea, se ve, se edita, se completa o se elimina
  - **Entonces**:
    - de la tarea solo se guarda la **dirección** validada (con `https://` si se añadió);
    - de la página **nunca** se guarda nada en el móvil: ni captura, ni copia, ni caché en disco, ni cookies, ni almacenamiento web (CA-009-13);
    - al completarla o eliminarla no queda nada de ella (ADR-0012).
- **CA-009-05 Editar (spec 005)**
  - **Dado** una tarea web
  - **Cuando** elige Editar, desde el menú o desde el listado
  - **Entonces** se abre directamente la hoja "Cargar URL" (no el editor), con la dirección actual en el campo:
    - "Abrir" con una dirección válida la sustituye; la tarea **conserva su posición y su color** (CA-005-05), y si es la tarea actual se carga la nueva dirección;
    - cerrar la hoja la deja como estaba;
    - la validación es la de CA-009-02.

**Ver la página**

- **CA-009-06 Tarea actual web (R8)**
  - **Dado** que la tarea actual es web
  - **Cuando** se abre la app en frío
  - **Entonces**, sin ningún toque y en el tiempo de CA-001-09 (< 1 s p50, dispositivo de referencia, *release*), se ve la tarea:
    - arriba, el logotipo y el menú; abajo, el botón de completar, como en cualquier tarea;
    - entre ellos, con borde negro arriba y abajo, la **barra negra** con el candado, el **dominio real** (CA-009-14) y la insignia "WEB", como en el prototipo (pantalla 11). **Con el aviso de conexión no segura (CA-009-09) no se ve el candado**; su hueco se queda, así el dominio y "WEB" no se mueven (propietario, 2026-09-29);
    - debajo, la página **en vivo**, al ancho, con su propio desplazamiento y el zoom que permita el sitio (la app no añade zoom propio). Solo esa página: sin navegación (CA-009-11).
  - Mientras la página carga se ve un indicador de carga. El tiempo de la página depende de la red y no cuenta para CA-001-09 (ADR-0016).
- **CA-009-07 Se carga cada vez**
  - **Dado** una tarea web
  - **Cuando** se vuelve a mostrar (desde otra pantalla, en un arranque en frío o desde segundo plano tras 10 minutos o más)
  - **Entonces** se carga **la dirección guardada** desde cero, arriba del todo, sin la sesión anterior (CA-009-13).
  - Desde segundo plano en menos de 10 minutos se ve todo igual, en la misma posición (CA-001-12). Si el sistema ha descartado la página mientras tanto, se vuelve a cargar la dirección guardada.
  - Abrir y cerrar el menú (una hoja sobre la tarea) no recarga la página.
- **CA-009-08 Sin conexión**
  - **Dado** la tarea web actual
  - **Cuando** no hay conexión, o la página no empieza a verse en 20 s
  - **Entonces**, bajo la barra, en lugar de la página: "Necesitas conexión para ver esta página." y el botón "Reintentar".
  - "Reintentar" vuelve a cargar la dirección guardada. También se reintenta sola al volver a la app o a la tarea.
- **CA-009-09 Solo conexión segura (T-6)**
  - **Dado** una dirección `http://`
  - **Cuando** se carga
  - **Entonces** se intenta como `https://`. Si el servidor no admite https (no conecta, falla el TLS o no responde nada), se ve "Esta página no usa conexión segura. Ábrela en el navegador." con el botón "Abrir en el navegador", y la barra sin candado (CA-009-06). Nunca se carga nada sin cifrar, tampoco recursos sueltos dentro de una página https (contenido mixto).
  - También se ve ese aviso si la página de `https://`, **mientras hace la carga inicial** (antes de terminar de cargar), intenta ir a otra dirección `http://` (p. ej. neverssl.com, que por https solo redirige a http con JavaScript): en lugar de quedarse en blanco (propietario, 2026-09-29; excepción de CA-009-11).
- **CA-009-10 Certificado no válido (T-6)**
  - **Dado** un sitio cuyo certificado no es válido (caducado, autofirmado, de otro dominio…)
  - **Cuando** se carga la página
  - **Entonces** **nunca** se acepta: se ve "No se ha podido cargar la página (certificado no válido)." con "Abrir en el navegador" y "Reintentar".
- **CA-009-11 Sin navegación: solo la dirección guardada (T-5, ADR-0018)**
  - **Dado** la página en vivo
  - **Cuando** el usuario toca un enlace, envía un formulario o la página intenta ir a otra dirección
  - **Entonces**:
    - **no pasa nada**: la tarea sigue en la misma página, sin cargar otra, sin abrir el navegador ni otra app y sin preguntar. Da igual que sea del mismo sitio o de otro, que abra una ventana nueva (`target=_blank`, `window.open`), que sea `mailto:`, `tel:` o cualquier otro esquema, o una redirección de la propia página (JavaScript, `meta refresh`);
    - **excepción:** un enlace a otra parte de **la misma página** (un ancla, `#seccion`) desplaza dentro de ella, como en un navegador;
    - lo que la página hace sin cambiar de dirección (pestañas, desplegables, contenido que carga con JavaScript) funciona dentro de la página;
    - si aun así empieza a cargarse otra página (p. ej. un formulario que envía datos, que Android no deja bloquear de antemano), se para y se vuelve a cargar la dirección guardada (propietario, 2026-09-29). **A la segunda vez seguida** (sin que la dirección guardada se haya visto de forma estable entre medias; p. ej. una página que envía un formulario sola al cargar), ya no se recarga: se para y se ve "No se ha podido cargar la página (intenta abrir otra página)." con "Abrir en el navegador" y "Reintentar", que vuelve a cargar y empieza a contar de cero (propietario, 2026-09-29, enmienda);
    - **excepción (propietario, 2026-09-29):** con una dirección guardada `http://` (que se carga como `https://`), si durante la carga inicial la página intenta ir a otra dirección `http://`, no se queda en blanco: se ve el aviso de conexión no segura (CA-009-09). Después de terminar la carga inicial, un intento así no hace nada, como cualquier otro;
    - la barra muestra siempre el dominio de esa página (CA-009-14).
- **CA-009-12 Atrás**
  - **Dado** la tarea actual web
  - **Cuando** usa el gesto o el botón atrás del sistema
  - **Entonces** hace lo mismo que en cualquier tarea: la página no tiene páginas anteriores a las que volver (ADR-0018).
- **CA-009-13 Aislamiento: la página no toca la app (T-4)**
  - **Dado** la página en vivo
  - **Cuando** carga cualquier página
  - **Entonces**:
    - no tiene ningún puente con la app ni acceso a sus archivos o a los del móvil;
    - no puede pedir cámara, micrófono, ubicación ni notificaciones: todo se deniega sin preguntar;
    - no descarga archivos: una descarga iniciada desde la página no hace nada;
    - no muestra diálogos propios de la página (`alert`, `confirm`, `prompt`), no ofrece autorrellenado ni guarda contraseñas, y no pasa a pantalla completa. **Enmienda (propietario, 2026-09-29, T-009-14):** lo anterior vale para la WebView; el servicio de autorrelleno del sistema (p. ej. el de Google) sí puede actuar en los campos de la página y no se ha encontrado forma de evitarlo desde la app (`importantForAutofill` no tiene efecto): limitación aceptada (`threat-model.md §7`);
    - cookies, almacenamiento web y caché duran solo mientras se ve la tarea: se borran al salir de ella (otra pantalla, otra tarea, completar, eliminar) y, si la app se cerró sin borrarlos, en el siguiente arranque, después del primer fotograma;
    - no se puede depurar en *release*.
  - **Residual aceptado (propietario, 2026-09-29, T-009-14):** la WebView deja el origen visitado en `app_webview/Default/Preferences` y resúmenes (hash) de los orígenes en `shared_prefs/AwOriginVisitLoggerPrefs.xml`; ninguna API los borra. Ambos quedan fuera de la copia en la nube y de la transferencia (`threat-model.md §7`).
- **CA-009-14 Dominio visible e IDN (T-5)**
  - **Dado** la barra
  - **Cuando** muestra el dominio
  - **Entonces**:
    - es el **host real** de la página que se ve, sin `www.` delante (como el prototipo);
    - se muestra en punycode (`xn--…`) si mezcla alfabetos (posible homógrafo);
    - se muestra saneado, sin caracteres de control ni de cambio de dirección;
    - si no cabe, se recorta **por el principio** ("…congreso.ejemplo.com"), para que siempre se vea el final del dominio. El lector lo lee entero.
- **CA-009-15 Girar (D10; igual que imagen y PDF, CA-008-11)**
  - **Dado** la tarea actual web a la vista (sin el menú, una confirmación ni el listado encima)
  - **Cuando** gira el móvil a horizontal
  - **Entonces** la pantalla gira sola y en horizontal se ven **la página al ancho y el logotipo**, sin barra, menú, botón de completar ni pie, como con imagen y PDF (propietario, 2026-09-28). La página no se recarga al girar.
  - **No gira** con los avisos de CA-009-08, 09, 10 ni CL-009-4 (como "Adjunto no disponible").
  - El resto es como CA-008-11: vuelve a vertical al poner el móvil en vertical, respeta el bloqueo de rotación, sigue pudiendo completar o eliminar con las acciones del lector, y si se completa o se elimina en horizontal y la siguiente tarea no tiene adjunto, vuelve a vertical. Si gira con una confirmación abierta, la confirmación sigue abierta.
- **CA-009-16 Pantalla encendida**
  - **Dado** el ajuste "Mantener la pantalla encendida con adjuntos" activo
  - **Cuando** se ve la tarea actual web, en vertical o en horizontal
  - **Entonces** la pantalla no se apaga, con el límite de 10 minutos sin tocar y las condiciones de CA-007-12 (propietario, 2026-09-28).

**Donde aparece la tarea web**

- **CA-009-17 Resto de la app**
  - **Dado** una tarea web
  - **Cuando** aparece fuera de la pantalla principal
  - **Entonces**:
    - **Listado:** insignia negra de 44 px con "WEB" entre el asa y el texto, como el prototipo; decorativa para el lector;
    - **Etiqueta:** en el listado, en la confirmación de eliminar y en los anuncios, la etiqueta es el **dominio** (CA-009-14);
    - **Completar y eliminar:** la rotura y el arrugado muestran la tarea con la barra; la zona de la página puede verse en blanco (propietario, 2026-09-28: la página en vivo no se puede fotografiar de forma fiable para la animación). Con reducir movimiento, sus alternativas.

**Accesibilidad**

- **CA-009-18 Lectura**
  - **Dado** un lector de pantalla
  - **Cuando** lee una tarea web
  - **Entonces**:
    - la barra es un único elemento: "Tarea actual: Página web de {host}";
    - el contenido de la página lo lee el lector con la accesibilidad de la propia página;
    - el indicador de carga se lee "Cargando página";
    - Completar tarea y Eliminar tarea siguen disponibles como acciones del lector en las dos orientaciones (el plan dice en qué elemento; se comprueba con TalkBack en el emulador);
    - fila del listado: "{n} de {total}: {host}. Página web";
    - anuncios de completar y eliminar: "Tarea completada. Siguiente: {host}" (con `{text}` = dominio).
- **CA-009-19 Foco y anuncios**
  - **Dado** un lector de pantalla activo
  - **Cuando** ocurre cada acción
  - **Entonces** un único anuncio y el foco donde dice la tabla (con la limitación de TalkBack aceptada en CA-007-22):

    | Acción | Foco | Anuncio |
    |---|---|---|
    | Se abre "Cargar URL" | El campo | El título de la hoja |
    | Error de validación | El campo | El texto del error |
    | "Abrir" | Como CA-008-05 (la tarea o la fila del listado) | Como con imagen y PDF: ninguno en la pantalla principal; desde el listado, "Ahora es la tarea actual" (propietario, 2026-09-29) |
    | Se cierra "Cargar URL" | El botón (+) del editor | Ninguno |
    | Aviso sin conexión, sin https o de certificado | Donde estaba | El texto del aviso |
    | "Reintentar" | Donde estaba | "Cargando página" |
    | Toca un enlace de la página | Donde estaba | Ninguno (CA-009-11) |
    | Vuelve del navegador ("Abrir en el navegador") | Donde estaba | Ninguno |
    | Gira a horizontal | La página | Ninguno |

- **CA-009-20 Reducir movimiento, teclado y texto grande**
  - **Dado** "reducir movimiento", un teclado o el texto al 200 %
  - **Cuando** se usan la hoja o la tarea web
  - **Entonces**:
    - con reducir movimiento, el indicador de carga no se anima;
    - con teclado: Intro en el campo equivale a "Abrir", y Tab entra en la página y la recorre;
    - con el texto al 200 % en un móvil de 360 dp: la hoja, los errores, la barra (dominio recortado por el principio) y los avisos se ven enteros, nada se corta y todos los botones miden ≥ 48 dp. El texto de la página sigue el tamaño que decida la propia página.

## 4. Casos límite

| ID | Situación | Comportamiento |
|---|---|---|
| CL-009-1 | Redirecciones del servidor al cargar la dirección guardada, también a otro dominio | Se siguen durante esa carga inicial. La barra muestra el dominio final. Si el dominio final (sin `www.`) no es el de la dirección guardada, se avisa una vez: "Esta dirección te ha llevado a {host}." (también entre subdominios, p. ej. `m.ejemplo.com`: sin lista de sufijos públicos, ADR-0018). Una redirección de la propia página (JavaScript, `meta refresh`) no se sigue (CA-009-11) |
| CL-009-2 | Banner de cookies o muro de registro | Se ve tal cual (no se manipula el contenido de terceros). Sin cookies guardadas, puede volver a salir cada vez (ADR-0016) |
| CL-009-3 | Sitio que exige iniciar sesión | No se conserva la sesión entre visitas (CA-009-13) |
| CL-009-4 | La dirección es un PDF u otro archivo, no una página (P-6: **fuera de la v1**, propietario 2026-09-28) | "Esta dirección no es una página web. Ábrela en el navegador." con "Abrir en el navegador". No se descarga nada |
| CL-009-5 | Web de pruebas (ADR-0010) | Sin página en vivo: tarjeta con el dominio, la dirección y "Abrir página ↗" (pestaña nueva), como el prototipo. Sin giro |
| CL-009-6 | La página responde con un error del sitio (404, 500…) | Se ve la página de error del sitio, como en un navegador (propietario, 2026-09-28: sin captura, ya no hace falta tratarlo como fallo) |
| CL-009-7 | Página que nunca termina de cargar (anuncios, conexiones abiertas) | Se ve lo que haya llegado. Los 20 s de CA-009-08 cuentan solo si no se ha visto nada |
| CL-009-8 | Dirección muy larga, con espacios internos o caracteres internacionales en la ruta | Más de 2048 caracteres: no válida. El resto se normaliza (se codifica) como haría un navegador |
| CL-009-9 | Registros (logs) en *release* | No se registra ninguna dirección, dominio ni contenido de páginas |
| CL-009-10 | La miniatura de la app en "Recientes" | Muestra la página. **[Pendiente, spec 010]** Ocultarla, como CL-007-11 y CL-008-13 |
| CL-009-11 | Se completa o se elimina mientras la página carga | La carga se cancela y no queda nada (CA-009-13) |
| CL-009-12 | Página que cambia su contenido sin cambiar de dirección (aplicación de una sola página, `history.pushState`) | Funciona dentro de la página: la WebView no avisa de esos cambios y no se pueden impedir. Sigue siendo el mismo dominio (ADR-0018) |
| CL-009-13 | Enlace a la misma dirección sin ancla, o con otra consulta (`?dia=2`) | No hace nada: sería cargar otra página (CA-009-11) |

## 5. Estados de error

Los errores de validación aparecen bajo el campo de la hoja. Los de la página, en lugar de la página, bajo la barra. Todos se anuncian solos.

| Estado | Texto | Acciones |
|---|---|---|
| Dirección vacía | "Escribe una dirección web." | — |
| Esquema no permitido | "Solo se admiten direcciones web (http o https)." | — |
| Dirección no válida | "Esa dirección no parece válida." | — |
| Sin conexión o tiempo agotado | "Necesitas conexión para ver esta página." | "Reintentar" |
| Sin https (la barra, sin candado: CA-009-06) | "Esta página no usa conexión segura. Ábrela en el navegador." | "Abrir en el navegador" |
| Certificado no válido | "No se ha podido cargar la página (certificado no válido)." | "Abrir en el navegador", "Reintentar" |
| No es una página | "Esta dirección no es una página web. Ábrela en el navegador." | "Abrir en el navegador" |
| La página intenta ir a otra dos veces seguidas (CA-009-11; propietario, 2026-09-29) | "No se ha podido cargar la página (intenta abrir otra página)." | "Abrir en el navegador", "Reintentar" |

"Abrir en el navegador" abre la dirección guardada en el navegador del sistema. No pide confirmación, porque el botón ya dice lo que hace.

## 6. Accesibilidad

- Lectura, foco y anuncios: CA-009-18 y CA-009-19. La insignia del listado es decorativa.
- La página en vivo es accesible con la accesibilidad de la propia página: la app no puede arreglar una web mal hecha.
- Orientación (WCAG 1.3.4): la tarea web gira igual que la de imagen y la de PDF (CA-009-15), con la misma excepción del horizontal ya aprobada (ADR-0013, ADR-0014, ADR-0015; constitución P6), que se amplía a la tarea web. En horizontal, lo único que se puede enfocar es la página.
- Sin confirmaciones para salir: los enlaces de la página no hacen nada (ADR-0018).
- Contraste: la barra, blanco sobre negro. El anillo de foco, con borde blanco y negro (como en la 007).
- Objetivos táctiles ≥ 48 dp: "Abrir", la X, "Reintentar", y "Abrir en el navegador".

## 7. Textos (ES / EN)

| Clave | ES | EN | Notas |
|---|---|---|---|
| `urlSheetTitle` | Cargar URL | Load URL | |
| `urlPlaceholder` | https:// | https:// | |
| `urlHelp` | Se abre como tarea, arriba del todo. | It opens as a task, on top. | |
| `urlOpen` | Abrir | Open | |
| `urlErrEmpty` | Escribe una dirección web. | Enter a web address. | |
| `urlErrScheme` | Solo se admiten direcciones web (http o https). | Only web addresses (http or https) are supported. | |
| `urlErrInvalid` | Esa dirección no parece válida. | That address doesn't look valid. | |
| `urlNeedsConnection` | Necesitas conexión para ver esta página. | You need a connection to view this page. | Cambia: antes "…por primera vez" |
| `urlInsecure` | Esta página no usa conexión segura. Ábrela en el navegador. | This page doesn't use a secure connection. Open it in the browser. | |
| `urlLoadFailed` | No se ha podido cargar la página ({reason}). | Couldn't load the page ({reason}). | |
| `urlReasonCertificate` | certificado no válido | invalid certificate | |
| `urlReasonKeepsLeaving` | intenta abrir otra página | it keeps trying to open another page | CA-009-11. Enmienda del propietario, 2026-09-29 (límite de recargas) |
| `urlNotAPage` | Esta dirección no es una página web. Ábrela en el navegador. | This address isn't a web page. Open it in the browser. | CL-009-4 |
| `urlRedirected` | Esta dirección te ha llevado a {host}. | This address took you to {host}. | CL-009-1 |
| `urlOpenInBrowser` | Abrir en el navegador | Open in browser | |
| `urlLoadingA11y` | Cargando página | Loading page | Solo lector de pantalla |
| `urlA11yBar` | Página web de {host} | Web page from {host} | Con el prefijo `currentTaskSemantics` |
| `attachmentWeb` | WEB | WEB | Insignia |
| `a11yRowWeb` | {host}. Página web | {host}. Web page | Fila del listado |
| `urlOpenPageWeb` | Abrir página ↗ | Open page ↗ | Solo web de pruebas |

Se reutilizan `attachUrl` ("Cargar URL"), `attachUrlHint`, `attachSheetClose`, `retry`, `currentTaskSemantics` y las lecturas de las specs 001, 003, 004 y 006 con `{text}` = dominio.

**Quitadas** respecto a la versión anterior de esta spec (ADR-0016): `urlSaving`, `urlSnapshotOf`, `urlSnapshotPartial`, `urlRefresh`, `urlSnapshotPending` y `urlReasonHttp`. Desde el ADR-0018 la tarea web **ya no reutiliza** `openInBrowserConfirm`, `openInAppConfirm`, `linkConfirmOpen`, `linkConfirmCancel` ni `errNoAppForLink` (siguen para los enlaces del PDF).

## 8. Fuera de alcance (v1)

- **Ver la página sin conexión**, cualquier copia local, la caché o una sesión que dure (ADR-0016).
- Guardar como PDF una dirección que apunta a un PDF (P-6, CL-009-4).
- Convertir una tarea en web al editarla, o una web en otro tipo de tarea (se crea otra y se elimina la anterior).
- Texto en una tarea web.
- **Navegar** (ADR-0018): seguir enlaces, ir atrás o adelante, abrir enlaces de la página en el navegador o en otra app (también `mailto:` y `tel:`). Solo se admiten las anclas de la misma página.
- Barra de direcciones, botones de navegación, recargar a mano (fuera de "Reintentar"), buscar en la página, compartir.
- Varias URL por tarea, lector de artículos, compartir desde el navegador hacia la app (*share extension*, futuro).

## 9. Preguntas abiertas

- **[Resuelto 2026-09-28, propietario]** Se guarda **solo la dirección** y la página se carga en vivo cada vez; no se guarda nada de la página (ADR-0016, que sustituye a D9 y enmienda el ADR-0007). ADR-0016 aceptado y excepción a P3 en la constitución (versión 1.4), el mismo día.
- **[Resuelto 2026-09-28, propietario]** Tarea web **sin texto**, creada directamente desde "Cargar URL". El texto del editor se descarta, y en modo editar no aparece "Cargar URL" (CA-009-01, CA-009-03).
- **[Resuelto 2026-09-28, propietario]** Sin conexión: aviso y "Reintentar", que también se reintenta solo al volver a la app o a la tarea (sin vigilar la red).
- ~~**[Resuelto 2026-09-28, propietario]** Atrás vuelve a la página anterior mientras la haya (CA-009-12).~~ Sustituida por la siguiente.
- **[Resuelto 2026-09-29, propietario]** **Sin navegación** (ADR-0018): solo se ve la página de la dirección guardada, como una imagen o un PDF; ningún enlace hace nada, tampoco `mailto:` ni `tel:`; las anclas de la misma página sí; atrás, como en cualquier tarea; se quita la lista de sufijos públicos (CA-009-11, CA-009-12, CL-009-1).
- **[Resuelto 2026-09-28, propietario]** Gira igual que la imagen y el PDF (CA-009-15).
- **[Resuelto 2026-09-28, propietario]** Pantalla encendida igual que con imagen y PDF (CA-009-16).
- **[Resuelto 2026-09-28, propietario]** P-6: una dirección que es un PDF queda fuera de la v1 (CL-009-4).
- **[Resuelto 2026-09-28, propietario, al aprobar la spec]** Un error del sitio (404, 500…) se ve como lo manda el sitio (CL-009-6). La versión anterior lo trataba como fallo porque no quería guardar una captura de una página de error.
- **[Resuelto 2026-09-28, propietario, al aprobar la spec]** En las animaciones de completar y eliminar, la zona de la página puede verse en blanco (CA-009-17).
- **[Resuelto 2026-09-28, propietario, al aprobar la spec]** Aviso único cuando la dirección redirige a otro sitio (CL-009-1), y dominio recortado por el principio (CA-009-14).
- **[Resuelto 2026-09-28]** Desviaciones del prototipo: DEV-04 cambia (en vivo, sin copia; con los avisos de §5) y DEV-18 se cierra para "Cargar URL" (actualizadas en `prototype-deviations.md`; DEV-18 se da por cerrada al fusionar la 009).
