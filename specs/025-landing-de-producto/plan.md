# Plan técnico — Spec 025: Landing de producto

- **Spec:** `specs/025-landing-de-producto/spec.md` (estado: Aprobada)
- **ADR aplicables:** ADR-0027 (Vite, GSAP y Lenis; **Propuesto**, se acepta al aprobar este plan), ADR-0009 (enmendado por el 0027), ADR-0010 (Vercel), ADR-0026 (licencias de terceros)
- **Estado del plan:** **Aprobado** (propietario, 2026-11-13, al responder P-025-1 a 7, §8 y §9; la spec quedó enmendada ese día). Revisado por `security-reviewer` (2 bloqueantes, 5 importantes y 6 menores) y `a11y-reviewer` (2 bloqueantes, 7 importantes y 4 menores) el 2026-11-13, todo aplicado o resuelto por el propietario. ADR-0027 **Aceptado** el mismo día (§4). Antes Borrador (2026-11-12).
- **Origen del código:** la maqueta `UnaWeb/www`, versión A (solo lectura): `a/index.html`, `src/a/*` y `src/shared/*` (unas 1.700 líneas). No entran `b/`, `src/b/`, `propuestas/`, `index.html` (el selector), `.agents/`, `skills-lock.json` ni `three`.

## 1. Resumen del enfoque

1. **Se trae la maqueta, no se reescribe.** El recorrido (línea de tiempo, cámara, imán, entrada escalonada) entra tal cual; se cambia solo lo que la spec dice que la maqueta no cumple (spec §0, último punto) y lo que este plan ha encontrado al leerla (§7.1).
2. **Dos construcciones, un solo resultado.** `node landing/build.mjs` sigue siendo la única orden. Hace lo de siempre (política, licencias, Ayuda, error, `tokens.css`, fuentes) **menos** la página de inicio, y después llama a Vite (por su API, `import("vite")`) para construir la de inicio dentro del mismo `landing/dist/`. Las cuatro páginas no pasan por Vite y siguen sin dependencias en su resultado. `vercel.json` conserva `buildCommand: "node build.mjs"`.
3. **La landing vive en `landing/home/`** (raíz de Vite): `index.template.html`, `src/` (código propio, en inglés), `public/` (fuentes e imágenes) y `gen/` (generado, fuera de git).
4. **Una sola fuente para nombre, colores y textos de la app.** Antes de llamar a Vite, `build.mjs` escribe en `landing/home/gen/`: `site.json` (nombre y logotipo de `app/identity.yaml`, direcciones de las tiendas, y los 11 textos de la app de §2.3 leídos de las ARB), `tokens.css` (el de siempre, con los colores de la landing) e `index.html` (la plantilla con el contenido sin JavaScript ya escrito en ES y EN). El código de la landing importa `gen/site.json`; no hay ningún nombre ni color escrito a mano.
5. **Lógica pura, DOM fino.** Lo que tiene test automático se escribe como funciones sin DOM (regla de idioma, guion del recorrido, modo de la página, máquina de estados de «mantener pulsado», HTML de cada escena como texto) y se prueba con `node --test`, como el resto de `landing/test`. **No entra** ninguna biblioteca de DOM ni un navegador en la CI; lo que solo se ve en un navegador va a las casillas C-025-1 a 8.
6. **Sin estilos en línea en el HTML.** La maqueta escribe `style="--x:…"` en el HTML que genera (unas 20 veces): con la CSP de la web eso se bloquea. Se sustituyen por atributos `data-*` que el programa aplica con `el.style.setProperty(…)` y por clases; el SVG usa atributos de presentación (`font-stretch="62%"`). La CSP **no** se abre a `'unsafe-inline'` (Q-025-10 a). Lo que el programa y GSAP aplican por CSSOM (`el.style.transform = …`) no lo bloquea la CSP **[Suposición: se comprueba en T-025-01 con la CSP real y la consola del navegador]**; **[Hecho]** `ScrollTrigger.js` (líneas 2114 a 2120 de la 3.15.1) hace `body.setAttribute("style", "")` al arrancar **siempre que `<body>` no tenga atributo `style`**, y eso sí lo cuenta la CSP. Salida fijada: el programa pone una propiedad en `<body>` por CSSOM **antes** de registrar ScrollTrigger, de modo que esa rama no se ejecuta. Si aun así la consola da una infracción, **se para y se pregunta**; no se abre `'unsafe-inline'`.

## 2. Cambios por capa

La landing no tiene las capas de la app. Se listan las zonas de `landing/` y lo de fuera que cambia. **`app/` no cambia de comportamiento**; ver §3 para sus archivos generados.

| Zona | Archivos o módulos | Cambio |
|---|---|---|
| Dependencias | `landing/package.json`, `landing/package-lock.json`, `landing/.npmrc` | Nuevos. `vite` 8.3.8 (dev), `gsap` 3.15.1 y `lenis` 1.3.27, **versiones exactas**; `ignore-scripts=true`; `private: true` |
| Construcción | `landing/build.mjs` | Deja de emitir `index.html` (se retiran `webHomeTitle` y `webHomeIntro`); escribe `home/gen/`; llama a Vite; añade el bloque «Código de esta web» a `/licenses`; lee las direcciones de las tiendas de la identidad |
| Construcción | `landing/home/vite.config.mjs` | Nuevo. `outDir: ../dist`, `emptyOutDir: false`, sin mapas de código, `modulePreload.polyfill: false` (el relleno hace un `fetch`), `assetsInlineLimit: 0` (sin `data:`), conserva los comentarios legales (cabecera de GSAP) |
| Página | `landing/home/index.template.html` | Nuevo. Cabeza (título, descripción, `theme-color` desde tokens), el **contenido sin JavaScript** (§2.2) y un solo `<script type="module" src>` |
| Código | `landing/home/src/lang.js` | Regla de idioma de CA-025-09 (lista de `navigator.languages`, valor guardado validado), sin `?lang=` |
| Código | `landing/home/src/strings.es.json`, `strings.en.json` | Textos del §7 con sus claves; los de ejemplo bajo `sample.*`; sin `nav.scenes` ni `luz.locked` (Q-025-6) ni los que son de la app |
| Código | `landing/home/src/story.js` | Las siete escenas (ids en inglés: `hero`, `many`, `one`, `handy`, `awake`, `light`, `end`), colores por **nombre de token**, y el guion como funciones puras: `sceneAt`, destino del imán, ventana de visibilidad de cada escena |
| Código | `landing/home/src/mode.js` | Decide recorrido o versión apilada: «reducir movimiento», falta de soporte (`CSS.supports`) o escena que no cabe en el alto (CL-025-13) |
| Código | `landing/home/src/journey.js`, `main.js` | Lenis + ScrollTrigger + cámara de la maqueta. Cambios: sin `?motion=`, sin `window.__una`; enlace al cierre (`/#download`, CL-025-2); teclado (CL-025-6); recolocar al cambiar de tamaño (CL-025-1); lo transparente desaparece (`visibility: hidden`) y sin `inert` en lo que se ve; Tab en el borde de la escena pasa a la siguiente (§6.2) |
| Código | `landing/home/src/chrome.js` | Cabecera, pie (con «Licencias»), rótulos de las tiendas (CA-025-08 enmendado: texto propio, App Store primero, enlace solo con dirección; sin imágenes de las tiendas); nombres accesibles de ES / EN; cambio de idioma que conserva la escena (§7.2) |
| Código | `landing/home/src/app-ui.js`, `art.js`, `icons.js` | Pantallas de la app e ilustraciones; textos de la app desde `gen/site.json`; sin `style=` en el HTML |
| Código | `landing/home/src/hold.js` | Máquina de estados pura (1.200 ms, cancelar, activación simple, una sola demostración) + enlace al DOM; el nombre accesible del botón es su texto visible (WCAG 2.5.3) |
| Estilos | `landing/home/src/*.css` | `base.css`, `scene.css`, `device.css` de la maqueta con `var(--color-…)` de `tokens.css`; las `@font-face` se quitan (vienen de `tokens.css`); valores sueltos solo en las ilustraciones |
| Recursos | `landing/home/public/` | `favicon.png`, `img/icon-512.png` y fuentes `woff2`. **No entran** `app-*.jpg`, `atardecer.jpg`, `lago.jpg`, `Archivo-Black-Condensed.ttf` (la A no los usa) ni la carpeta `img/badges/` (sin insignias hasta F6) |
| Recursos | `landing/home/ASSETS.md` | Nuevo. Origen, licencia y `sha256` de cada archivo publicado (CA-025-21) |
| Comprobación | `landing/check.mjs` | Dos juegos de reglas: el de siempre para las cuatro páginas (sin cambios) y el de la de inicio (§5); CSP por página; lista de archivos esperados en `dist/` |
| Cabeceras | `landing/vercel.json`, `landing/serve.mjs` | Segunda regla de cabeceras para `/`: la misma CSP más `script-src 'self'`. `serve.mjs` aprende a servir dos reglas y el tipo `.js` (`text/javascript`; hoy no lo tiene y con `nosniff` el módulo no cargaría). `installCommand: "npm ci --ignore-scripts"` |
| Avisos | `landing/web-notices.txt` | Nuevo, a mano: aviso de GSAP (su licencia y copyright) y de Lenis (MIT), con versión. Se publica en `/licenses` bajo `licensesWebTitle` |
| l10n | `landing/src/strings.json` | Se retiran `webHomeTitle` y `webHomeIntro`; entra `licensesWebTitle` (ES y EN) |
| Tokens | `design/tokens.json`, `tools/validate-tokens.mjs`, `docs/design/tokens.md` | Grupo nuevo de primer nivel `landing` (§3) y sus pares de contraste |
| Identidad | `app/identity.yaml` | Dos claves nuevas, vacías: `googlePlayUrl` y `appStoreUrl` |
| Política | `docs/legal/privacy-policy.md` | Sección «Esta web», ES y EN (CA-025-13) |
| CI | `.github/workflows/ci.yml`, `tools/ci-detect.sh`, `.github/dependabot.yml` | «Web y ficha» instala con `npm ci --ignore-scripts` antes de construir; `ci-detect` ya cubre `landing/*`, identidad, tokens, ARB y política (se añade el test de `landing/package-lock.json`); Dependabot vigila `npm` en `/landing` |
| Repositorio | `.gitignore` | `landing/home/gen/` (`landing/dist/` y `node_modules/` ya están) |

### 2.1 Lo que se corrige respecto a la maqueta (spec §0)

| Qué | Dónde | CA |
|---|---|---|
| Idioma solo con `navigator.language` y `?lang=` | `lang.js` | 09, Q-025-9 |
| `?motion=reduce` | `mode.js` | Q-025-9 |
| Sin JavaScript solo dice «Activa JavaScript» | plantilla (§2.2) | 11 |
| Escenas no activas con `inert` aunque se vean | `main.js` (§6.2: solo desaparece lo transparente) | 15 |
| Textos de la app distintos de los de la app | `gen/site.json` (§2.3) | 06 |
| El enlace al cierre no abre en el cierre | `journey.js` | CL-025-2 |
| La demostración se repite al volver a la escena | `hold.js` | 07 |
| Nombre y colores a mano (`config.js`, `story.js`, `:root` de `base.css`) | `gen/` | 14 |
| Insignias oficiales sin ficha, y las de Google recortadas | Fuera: rótulos propios (P-025-1) | 08, 21 |
| Archivos sin usar; `three`; versiones con `^` | `public/`, `package.json` | 18, 21 |
| Palabra destacada crema sobre naranja | **No se corrige** (P-025-2: aceptada por el propietario) | 15 |
| Pie sin «Licencias»; sin nota en «Siempre a mano» | `chrome.js`, textos | 20, Q-025-8 |

### 2.2 Contenido sin JavaScript y «sin salto» (CA-025-11, CL-025-12, spec §5)

- El HTML construido lleva, dentro de `<main>`, un bloque `#static` con dos mitades (`lang="es"` y `lang="en"`, español primero): nombre, `heroTitle` y `heroLead`, los titulares y entradillas de las escenas 3 a 6 (las cuatro propuestas), `endLead` y los enlaces a `/help`, `/privacy` y `/licenses`. Se compone con los textos del §7; ninguno nuevo.
- **No es un `<noscript>`**: tiene que verse también si el programa no llega o falla. Regla de CSS: con `@media (scripting: none)` se ve al instante; en otro caso aparece a los **2 s** (una animación de `visibility`). Si el programa arranca bien, **quita** el bloque **al final** del montaje, que ocurre antes de los 2 s (no se ve ni se lee dos veces, CA-025-15); si falla al arrancar (un `try` alrededor del montaje, y también los fallos asíncronos del arranque), deshace lo montado sin dejar restos y lo enseña al momento.
- Mientras tanto se ve el color de fondo de la portada, no una página en blanco. `<html lang="es">` hasta que el programa lo fija.
- **[Suposición]** `scripting: none` está en Chrome 120, Firefox 113 y Safari 17; en uno más antiguo sin JavaScript el contenido tarda 2 s. Se acepta.

### 2.3 Textos que la landing toma de la app (lista cerrada, CA-025-06)

| Clave de la ARB | Dónde se ve |
|---|---|
| `completeButton` | Botón de completar de todos los móviles y del móvil de prueba |
| `menuButton` | Nombre del menú (hoy la maqueta lo oculta al lector; solo si se anuncia) |
| `listTitle`, `listHelp`, `listNewTask` | Pantalla del listado (portada); `listHelp` entera, con sus tres frases |
| `successTitle1`, `successTitle2` | **[Hecho]** La versión A no los enseña (el sello es solo el visto). No se añaden: no hay texto sin usar. Si un retoque los enseña, salen de aquí |
| `settingsKeepAwake`, `settingsKeepAwakeHint` | Fila de la escena 5 |
| `settingsLockZoom`, `settingsLockZoomHint` | Fila de la escena 6 |

`build.mjs` falla si falta alguna clave en `app_es.arb` o `app_en.arb`. `listHelp` tiene una frase más que en la maqueta: T-025-06 comprueba que cabe en el móvil de la portada.

## 3. Modelo de datos y migraciones

No hay base de datos. Lo que la spec pide que el plan diga:

- **Tokens.** Grupo nuevo de primer nivel `landing` en `design/tokens.json` (no dentro de `color`), con los fondos `magenta` `#D4145A`, `magentaDeep` `#B8146E`, `orange` `#FF8A1F`, `yellow` `#FFD21F`, **los de la maqueta, sin cambios** (P-025-2). `validate-tokens` comprueba los pares de §6.2 y lleva el par `paperFiber`/`orange` como **salvedad con nombre** (2,31:1, solo titular), no como par válido. `gen_tokens.dart` solo lee los grupos que conoce, así que **`tokens.g.dart` no cambia** **[Suposición: T-025-02 lo confirma con `dart run tool/gen_tokens.dart --check`; si cambiase, se para]**. El resto de colores de la maqueta ya son tokens (`ink`, `paper`, `surface`, `paperFiber`, `switchOn` y la paleta `classic`).
- **Identidad.** `googlePlayUrl` y `appStoreUrl` en `app/identity.yaml`, vacías (`""`) hasta F6. `gen_identity.dart` solo lee sus cinco claves obligatorias: **los generados de `app/` no cambian** **[Suposición: se confirma con `--check` en T-025-02]**. Tocar `identity.yaml` sí dispara los trabajos de la app en la CI (ya es así). `build.mjs` valida cada dirección (vacía, o `https:` del dominio de su tienda); cualquier otra cosa falla.
- **Lo que guarda el navegador.** Una clave de `localStorage`, `lang`, con valor `es` o `en`; cualquier otro valor se ignora (CL-025-16). Nada más: ni `sessionStorage`, ni cookies.

## 4. Dependencias nuevas

| Nombre | Versión | Va al navegador | Motivo | Licencia | Revisión (`threat-model.md` §5) |
|---|---|---|---|---|---|
| `vite` | 8.3.8 | No | Empaquetar y minificar la página de inicio | MIT | Solo construcción; sus dependencias quedan fijadas en el `package-lock.json`; instalación sin scripts |
| `gsap` | 3.15.1 | Sí (núcleo y ScrollTrigger) | Línea de tiempo ligada al scroll | Propia de GSAP, «no charge» | **Excepción de P11** del ADR-0027; no entra en la app; su cabecera de copyright tiene que conservarse |
| `lenis` | 1.3.27 | Sí | Scroll suave e imán | MIT | Sin dependencias de ejecución |

**Comprobación que pedía el ADR-0027 antes de aceptarse** (hecha el 2026-11-12, sobre los paquetes instalados en la maqueta y sobre su `dist/`):

- **[Hecho]** En `gsap` (`gsap-core.js`, `CSSPlugin.js`, `ScrollTrigger.js`, `Observer.js`) y en `lenis` (`dist/lenis.mjs`) no aparece `fetch(`, `XMLHttpRequest`, `sendBeacon`, `WebSocket`, `EventSource`, `localStorage`, `sessionStorage`, `document.cookie`, `indexedDB`, `new Image` ni `importScripts`.
- **[Hecho]** En el programa construido de la maqueta aparecen: un `fetch(` (es el relleno de `modulepreload` de **Vite**, no de los paquetes; se desactiva) y dos `localStorage` (el idioma, código propio). Ninguno de los paquetes tiene scripts de instalación.
- **[Hecho]** La minificación de la maqueta **quita la cabecera de copyright de GSAP** (no queda ningún comentario `/*!`). La licencia prohíbe quitar sus avisos: T-025-01 la conserva y un test lo exige.
- **Conclusión:** la condición del ADR se cumple; se propone **Aceptarlo** al aprobar este plan. La comprobación queda además como test permanente sobre `dist/` (§5, CA-025-12).

## 5. Estrategia de tests

Todos con `node --test` en `landing/test/` (los nuevos, `home-*.test.mjs`), sin red y sin navegador. Cada test cita su CA. Lo de accesibilidad de §6.2 tiene su test en `home-a11y.test.mjs` y `home-hold.test.mjs`.

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-025-01 (cinco páginas; `/help` y 404 idénticas byte a byte) | Web construida, frente a una captura de las dos páginas tomada en T-025-01 antes de tocar nada | `home-build.test.mjs`, `test/fixtures/023/` |
| CA-025-02 (siete escenas, orden, encabezados, textos ES y EN) | HTML de las escenas como texto; textos frente a la tabla del §7 | `home-scenes.test.mjs` |
| CA-025-03 (sin zonas muertas, sin movimiento lateral, sin perder opacidad al crecer) | Guion puro: muestreo de 0 a 6,42 cada 0,01; `DRIFT` todo a cero; opacidad no decreciente mientras la escena se acerca | `home-story.test.mjs` |
| CA-025-04 (se asienta en reposo; ≤ 1,5 s) | Guion puro: el destino del imán desde cada punto es el reposo de una escena; espera (170 ms) + duración máxima (1,2 s) ≤ 1,5 s | `home-story.test.mjs` |
| CA-025-05 | Solo casilla C-025-2 | `navegadores.md` |
| CA-025-06 (textos de la app; dominios reservados) | `gen/site.json` frente a las ARB; dominios de los textos de ejemplo | `home-app-strings.test.mjs` |
| CA-025-07 (mantener, cancelar, teclado, activación simple, una demostración, sin ella con «reducir movimiento») | Máquina de estados con reloj inyectado | `home-hold.test.mjs` |
| CA-025-08 (con dirección y sin ella) | HTML de las tiendas con las dos, una y ninguna | `home-stores.test.mjs` |
| CA-025-09 (regla de idioma, recuerdo, idioma declarado, mismas claves) | Tabla de casos de la spec; almacenamiento simulado y roto (CL-025-3 y 16); claves ES = EN | `home-lang.test.mjs` |
| CA-025-10 (no monta el recorrido; siete encabezados e insignias) | `mode.js` puro + HTML apilado | `home-mode.test.mjs` |
| CA-025-11 (HTML sin ejecutar nada; programa bloqueado; error al arrancar) | HTML construido; la regla de CSS del bloque `#static`; el `try` del montaje con un fallo forzado | `home-static.test.mjs` |
| CA-025-12 (orígenes, programas en línea, `style=`, cookies, analítica, mapas, lo que se guarda, cabeceras por página) | `check.mjs` (reglas de la de inicio) + rastreo del programa construido: lista cerrada de API de red y almacenamiento | `home-security.test.mjs`, `security.test.mjs` |
| CA-025-13 (las dos mitades; no queda «sin JavaScript» para todas) | Política | `policy.test.mjs` (se amplía) |
| CA-025-14 (nombre; colores y fuentes de tokens) | `check.mjs`: nombre a mano (con la lista cerrada de titulares), CSS solo con `var(--…)` salvo `art.js` y lo marcado como ilustración | `home-tokens.test.mjs` + `validate-tokens` |
| CA-025-15 (contraste, encabezados, descripciones, orden) | Contraste calculado de cada par texto/fondo declarado en `story.js`, con **una** salvedad por lista cerrada (la palabra destacada sobre `orange`; el test falla si aparece otro par por debajo o si la salvedad deja de hacer falta); un `h1` y seis `h2`; cada móvil con descripción u oculto | `home-a11y.test.mjs` |
| CA-025-16 (elementos principales dentro de pantalla) | **[Suposición]** Sin navegador no se mide un diseño: el test comprueba que ninguna regla oculta un elemento marcado `data-main` en ningún punto de corte; lo demás, C-025-6 | `home-a11y.test.mjs` |
| CA-025-17 (peso) | Suma comprimida (gzip) de lo que carga una primera visita en cada idioma | `home-weight.test.mjs` |
| CA-025-18 (versiones fijadas; aviso de cada pieza) | `package.json` sin rangos; lockfile con sumas; cada dependencia de navegador en `web-notices.txt` con su versión; cabecera de GSAP en `dist/` | `home-deps.test.mjs`, `licenses.test.mjs` |
| CA-025-19 (detección de cambios) | Casos nuevos en el test de `ci-detect` | `app/test/tool/ci_detect_test.dart` |
| CA-025-20 (enlaces) | HTML de cabecera y pie: destinos; ningún enlace externo sin dirección de tienda | `home-scenes.test.mjs` |
| CA-025-21 (cada archivo publicado, en la lista y usado) | `dist/` frente a `ASSETS.md` y frente a las referencias del programa y del CSS | `home-assets.test.mjs` |
| CA-025-22 | `spec-reviewer` al cerrar | — |

El mínimo de tests de «Web y ficha» sigue siendo un suelo (100); no se toca.

**Casillas** (`specs/025-landing-de-producto/navegadores.md`, T-025-13): C-025-1 a 8 como en la spec §11. C-025-5 suma VoiceOver con Safari de macOS, zoom al 400 % a 1280 px, espaciado de texto (1.4.12), tamaño de letra de Chrome de Android y Voice Access («Español» / «English» frente a «ES» / «EN»). Switch Control y VoiceOver de iOS quedan sin verificar y aceptados (Q-025-11). Las de Chrome de Android en el Xiaomi las hace el coordinador con permiso del propietario.

## 6. Seguridad, accesibilidad y rendimiento

### 6.1 Seguridad y privacidad

- **CSP de `/`:** `default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`. Las otras rutas, la de hoy. **Dos reglas que no se solapan**, cada una con las siete cabeceras completas: `source: "/"` (con `script-src 'self'`) y `source: "/(.+)"` (la de hoy). `check.mjs` exige exactamente esas dos, iguales salvo esa directiva, con lista cerrada de directivas (sin `'unsafe-*'` ni `connect-src`); `serve.mjs` las sirve igual, y su test comprueba que `/help`, una ruta que no existe y `/assets/*.js` reciben la estricta. En Vercel de verdad se comprueba en F6 (C-023-2, ya pendiente).
- **HTML generado en el navegador:** todo sale de los JSON de textos y de `gen/site.json` y pasa por **una sola** función `esc` (los cinco caracteres, comilla simple incluida). La maqueta no lo hace siempre (`chrome.js` y `main.js` interpolan textos sin escapar; `hold.js` reinyecta `innerHTML`, que pasa a `cloneNode(true)`): se corrige al traer cada archivo, y un test mete un texto hostil en los JSON y en `site.json`. El idioma guardado y el `#` de la dirección se comparan **por igualdad con una lista** (`es`/`en`; los siete ids), nunca como selector ni como clave de objeto (P5). Sin `eval`.
- **El HTML de las escenas no está en `dist/`** (lo genera el programa), así que `check.mjs` no lo ve: `home-security.test.mjs` genera todas las escenas (ES y EN, recorrido y apilada) y les aplica las mismas reglas de etiquetas (sin `style=`, `on…=`, `<style>`, direcciones externas ni `javascript:`).
- **CSP en los navegadores de verdad:** «consola sin infracciones de CSP» se mira en T-025-01, 09 y 10 y en C-025-7 (Chrome, Safari, Firefox y Chrome de Android).
- **Cadena de suministro:** versiones exactas y lista cerrada de tres dependencias, `package.json` sin `scripts`, `vite.config.mjs` sin `plugins`, lockfile con todo `resolved` en `registry.npmjs.org` y con `integrity`, `npm ci --ignore-scripts` en la CI (sin `npm install` ni `npx`) y en Vercel (`installCommand`, que `check.mjs` exige), Dependabot para `/landing`. Cada punto, con su test. `check.mjs` compara `dist/` con lo esperado **por patrón y cuenta** (un `.js` y un `.css` en `assets/`, el `.js` es el único `<script type="module" src>`, ningún `.map` ni HTML de más). **[Suposición, T-025-01]** el lockfile hecho en macOS trae los binarios opcionales de Linux de Vite 8 y la construcción funciona sin scripts.
- **Direcciones de las tiendas:** `new URL`, `https:`, anfitrión exacto (`apps.apple.com`, `play.google.com`), sin credenciales ni puerto; el enlace lleva `rel="noopener noreferrer"`.
- **Checklist:** el apartado de la web gana las reglas de la de inicio (T-025-14). T-18 y T-9 se reescriben con la superficie nueva.

### 6.2 Accesibilidad

- **Lo que llega a transparente desaparece (decisión del propietario, 2026-11-13: «cuando las cosas lleguen a transparente deben desaparecer»).** En el recorrido, una escena (o una pieza) con opacidad 0 se quita del todo con `visibility: hidden`, como en la maqueta: no se pinta, no se enfoca y el lector no la lee. Sustituye a lo que proponía este plan el 2026-11-12 (opacidad 0 y todo en el árbol). En reposo solo es visible la escena activa (la siguiente tiene opacidad 0 hasta que empieza el viaje). La maqueta además ponía `inert` a las escenas no activas aunque se vieran: eso se quita; manda solo la transparencia.
  - **Teclado:** con Tab desde el último elemento enfocable de la escena activa (o Mayús+Tab desde el primero), la página pasa **al instante** a la escena siguiente (o la anterior) y lleva el foco a su encabezado (`tabindex="-1"`); así el teclado recorre las siete en orden (2.1.1, 2.4.3) y el foco nunca queda en algo invisible (2.4.7, 2.4.11). Las flechas, AvPág, Inicio y Fin, como el scroll (CL-025-6). El logotipo y «Descargar» llevan también el foco al encabezado de destino.
  - **Lector de pantalla:** al leer de corrido, el lector solo encuentra la escena a la vista, la cabecera y el pie; las demás se alcanzan desplazando la página (el gesto de desplazamiento del lector), con la cabecera o con el teclado. **Aceptado** por el propietario (P-025-7 b; CA-025-15 enmendado), sin excepción de P6. La versión apilada lee las siete en orden.
  - Se comprueba con TalkBack **al final de T-025-10**: en el recorrido lee la escena a la vista sin repeticiones ni cosas ocultas, y al desplazar con el gesto del lector pasa a la siguiente completa; en la versión apilada, las siete en orden. **Si no se cumple, se para y se pregunta.**
- **Cabecera fija y foco (WCAG 2.4.11):** `scroll-padding-top` con el alto de la cabecera en la versión apilada; en el recorrido, la escena en reposo ya deja el margen de la cabecera.
- **Titulares:** las líneas son `span`; el lector lee una frase. Las oscilaciones de la palabra destacada y de las piezas solo existen en el recorrido.
- **Contraste, calculado hoy** (WCAG; texto ≥ 4,5, titular grande ≥ 3):

  | Fondo | Texto | Razón | ¿Cumple? |
  |---|---|---|---|
  | `magenta` | `paper` (entradilla, «Muy pronto», pie) | 4,60 | Sí. La nota pequeña lleva `opacity: 0.92`: **se quita** |
  | `magenta` | amarillo de nota (palabra destacada) | 4,11 | Sí (titular) |
  | `magentaDeep` | `paper` / amarillo de nota | 5,54 / 4,94 | Sí |
  | `orange` | `ink` | 8,01 | Sí |
  | `orange` | `paperFiber` (palabra destacada, escenas 2 y 5) | **2,31** | **No.** Se queda así: aceptado por el propietario el 2026-11-13, sin excepción de P6 (spec, CA-025-15 y §6) |
  | `yellow` | `ink` | 13,03 | Sí |
  | `yellow` | `magenta` (palabra destacada, escenas 3 y 6) | 3,58 | Sí (titular) |

- **Objetivos de 44:** los botones ES / EN miden 44 × 42 en la maqueta: pasan a 44 × 44. Enlaces del pie con área de 44. Un test comprueba los mínimos declarados en el CSS.
- **Contraste no textual (1.4.11):** cabecera, anillo de foco y borde de los rótulos sobre los cuatro fondos, ≥ 3:1, en `home-a11y.test.mjs`. La palabra destacada sobre `magenta` (4,11) y sobre `yellow` (3,58) solo vale como texto grande: el test comprueba su tamaño mínimo a 320 px.
- **Rótulos sin ficha:** «(muy pronto)» va en un `span` oculto a la vista dentro del texto del rótulo, no en un `aria-label`; sin `role`, `tabindex` ni `aria-disabled` (test).
- **Anuncio al completar (4.1.3):** la región `aria-live` se vacía antes de cada anuncio para que se repita; la demostración automática **no** anuncia (la maqueta sí: se corrige y se prueba).
- **Cambio de idioma (§7.2):** tras recargar, el foco va al botón del idioma activo. El `#` se quita con `history.replaceState`, que entra en la lista cerrada de API de CA-025-12.
- **Cambio a la versión apilada (CL-025-13):** `mode.js` mide con `ResizeObserver` y después de `document.fonts.ready` (el tamaño de letra y el espaciado de texto no lanzan `resize`); una vez apilada, no vuelve al recorrido en esa visita, y conserva la escena y el foco.
- **Contenido sin JavaScript tardío (§2.2):** si el programa llega después de los 2 s y quita `#static`, lleva el foco al `h1` si estaba dentro. Test: un solo `h1` en cada momento, y ninguna regla de «reducir movimiento» anula el retardo.
- **Movimiento de más de 5 s (2.2.2):** el reloj de la escena 5 y las oscilaciones en reposo se paran al salir de la escena y no existen con «reducir movimiento» (spec §6); se anota en DEV-59.
- **Sin excepción a P6**; la salvedad de arriba es un incumplimiento conocido y aceptado, no una excepción.
- **Rótulos de las tiendas:** texto real (no imagen); sin dirección no son enlaces ni botones, y para el lector su nombre lleva `storeSoonAlt`; con dirección, enlaces con área de 44.

### 6.3 Rendimiento y peso (Q-025-4)

- **Peso medido en la maqueta** (gzip, primera visita en un idioma): programa 66 KB, CSS 8 KB, HTML 1 KB, fuentes `woff2` 259 KB (no se comprimen más), icono 10 KB e insignias unos 20 KB (que ya no entran): **unos 365 KB**. Los TTF de la app pesarían 856 KB: la de inicio usa `woff2`.
- **Límite:** **450 KB** (P-025-3, aceptado; CA-025-17 enmendado).
- **«Sin tirones» (CA-025-17, C-025-8):** en Chrome, grabación de 10 s del recorrido completo en el panel de rendimiento: media ≥ 50 fotogramas por segundo y ningún fotograma de más de 100 ms. En Safari y Firefox, con su herramienta equivalente; se anota la cifra y la máquina.
- **Cuándo se da la versión apilada:** «reducir movimiento»; navegador sin `transform-style: preserve-3d` o sin unidades `svh`; o escena que no cabe en el alto (CL-025-13). **No** se mide la fluidez en marcha para cambiar de versión (sería más código que el problema que evita); si una casilla de C-025-8 falla, se pregunta.
- Lo transparente se quita con `visibility: hidden` (§6.2): solo se pintan la escena activa y, durante el viaje, la siguiente.

## 7. Riesgos y alternativas

### 7.1 Hallazgos al leer la maqueta que la spec no listaba

1. La cabecera de copyright de GSAP desaparece al minificar (§4).
2. Hay `style="…"` en el HTML generado y en el SVG; con la CSP se bloquean (§1.6).
3. Los botones ES / EN no llegan a 44 de alto (§6.2).
4. El botón de completar del móvil de prueba lleva un `aria-label` («Mantén pulsado para completar la tarea») que no contiene su texto visible: incumple WCAG 2.5.3 (CA-025-15). Se quita.
5. Las fuentes de la landing son `woff2` y las de las otras páginas, los TTF de la app: su origen se anota en `ASSETS.md`. **[Pendiente]** con qué se convirtieron (P-025-4).

### 7.2 Cambio de idioma y escena (CL-025-5, Q-025-4)

Al cambiar de idioma se guarda la elección, se pone en la dirección el `#` de la escena en la que se está y se recarga; al arrancar, la página se coloca en esa escena sin animación y quita el `#`. Es el mismo mecanismo del enlace al cierre (CL-025-2), así que no cuesta código aparte: **la escena se conserva**. Repintar sin recargar se descarta: habría que rehacer la línea de tiempo en caliente.

### 7.3 Riesgos

| Riesgo | Prob. | Impacto | Qué se hace |
|---|---|---|---|
| GSAP o Lenis necesitan algo que la CSP sin `'unsafe-inline'` bloquea | Media | Alto | T-025-01 lo prueba lo primero, con la CSP real. Si falla: se para y se pregunta (Q-025-10 admite la excepción solo demostrada) |
| Vite 8 no deja conservar la cabecera de GSAP | Baja | Medio | Se añade como `banner` del programa; el test lo exige |
| Convivencia de las dos construcciones más enredada de lo previsto | Baja | Medio | El ADR-0027 manda preguntar antes de mover las cuatro páginas a Vite |
| Las reglas de `check.mjs` para la de inicio dejan pasar algo | Media | Alto | Cada regla nueva, con su caso que falla en `landing/test`; `security-reviewer` al cerrar |
| Regresión visual al quitar los `style=` y pasar a tokens | Media | Medio | Comparación a ojo con la maqueta en C-025-1 y C-025-6; DEV-59 |
| Vercel combina las cabeceras de otra forma | Baja | Alto | T-025-03 con su documentación; se verifica de verdad en F6 (C-023-2 sobre Vercel, ya pendiente) |
| Normas de las insignias | — | — | Resuelto: sin insignias hasta F6 (P-025-1); entra en la lista cerrada de F6 |

### 7.4 Alternativas descartadas

- **Pasar las cinco páginas a Vite:** cambia las garantías de las cuatro que no hay que tocar (CA-025-01).
- **Probar con un navegador en la CI (Playwright):** una dependencia grande más; lo que cubriría va a las casillas, como en la 023.
- **`'unsafe-inline'` en `style-src`:** Q-025-10 lo deja como último recurso.

## 8. Preguntas para el propietario (respondidas el 2026-11-13)

**Respuestas:** P-025-1, **a)** («acepto la recomendación»): rótulos propios, sin insignias hasta F6. P-025-2, **ninguna de las tres: «se queda como está»**: la palabra destacada sobre naranja no cambia; aceptado sin excepción de P6, anotado en la spec (CA-025-15 y §6). P-025-3, **sí**: 450 KB. P-025-4, **no lo recuerda**: T-025-12 regenera las `woff2` desde los TTF de la app y anota la herramienta; si no se puede sin instalar nada, se pregunta. Las preguntas se conservan como se hicieron:

- **P-025-1 · Las insignias (Q-025-7).** Normas leídas el 2026-11-12:
  - **Apple** (`developer.apple.com/app-store/marketing/guidelines/`): la licencia del material dice que se usa «only in connection with Your applications that are available for download on the App Store». Además: alto mínimo de 40 px, margen de un cuarto del alto, no modificar, insignia negra y **la primera** si hay otras tiendas, y una línea de crédito de marcas donde vayan los avisos legales.
  - **Google** (`partnermarketinghub.withgoogle.com/…/lockups-icons-badges/`, adonde redirige `play.google.com/intl/en_us/badges/`): no dice que tenga que enlazar ni prohíbe «muy pronto», pero tiene una insignia aparte de prerregistro; alto mínimo de 28 px, margen de un cuarto del alto, «don't […] adjust the badge in any way» (el recorte de la maqueta no vale), **igual o mayor** que las de otras tiendas, y en el idioma de la campaña. No pide línea de atribución en esa página. La descarga del material pasa por un formulario.
  - **Conclusión:** la de App Store **no admite** el uso sin ficha; la de Google, dudoso. La spec manda parar y preguntar.
  - **a) (Recomendado)** Hasta que haya ficha, **sin insignias oficiales**: dos rótulos propios con el nombre de cada tienda y «Muy pronto», con el estilo de la página. Las insignias oficiales, sin recortar, con App Store primero y la línea de crédito, entran en F6 con cada ficha (se añade a la lista cerrada de F6). Enmienda breve de CA-025-02 (filas 1 y 7), CA-025-08 y CA-025-21, y Q-025-3 pasa a F6 entera.
  - **b)** Se dejan como en la maqueta (corrigiendo recorte, orden y tamaño) y se anota en F6 que no se publica sin ficha o sin revisar las normas. La web no se publica hoy, así que el incumplimiento no llega a ocurrir; pero el repositorio guarda material de marca que hoy no tiene derecho a usar.
  - **c)** Solo la de Google Play; App Store, como rótulo propio.
- **P-025-2 · La palabra destacada sobre naranja (escenas 2 y 5): 2,31:1, hace falta 3:1.**
  - **a) (Recomendado)** Oscurecer el naranja de fondo hasta que el crema llegue a 3:1 (un naranja tostado; el valor exacto lo calcula T-025-02 y se le enseña). Conserva el aspecto de la palabra en relieve; el texto en tinta sigue por encima de 4,5.
  - **b)** La palabra pasa a `surface` sobre una plaqueta de tinta.
  - **c)** La palabra pasa a tinta, como el resto del titular (solo la distingue el relieve).
- **P-025-3 · El peso.** ¿Baja el límite de CA-025-17 de 600 a **450 KB** (medidos unos 365)?
- **P-025-4 · Las fuentes `woff2`.** ¿Recuerda con qué se convirtieron los TTF de la app en la maqueta? Si no, T-025-12 las regenera desde `app/assets/fonts/` con una herramienta anotada en `ASSETS.md` (sin dependencia nueva en el repositorio) o, si no se puede sin instalar nada, se pregunta.

## 9. Preguntas que dejan los revisores (2026-11-13)

**Respuestas del propietario (2026-11-13):** P-025-5 y P-025-6, **a)** («acepto la recomendación»); CA-025-07 y CA-025-16, enmendados. Además, sobre el §6.2: «cuando las cosas lleguen a transparente deben desaparecer», que abre P-025-7; P-025-7, **b)** («Enmendar 025-15»): CA-025-15 enmendado.

- **P-025-5 · Cómo se completa sin mantener pulsado (CA-025-07; `a11y-reviewer`, bloqueante).** La maqueta solo reconoce la activación del lector por `click` con `detail === 0`, que VoiceOver de iOS, el control por voz y los conmutadores **[Suposición]** no siempre envían; y con el teclado exige mantener Intro o espacio 1,2 s, lo que choca con WCAG 2.1.1 (no exigir tiempos a una tecla).
  - **a) (Recomendado)** Intro o espacio **completan al pulsarlos**, sin mantener (como la acción accesible de la app). Un `click` que no venga de una pulsación de dedo o ratón sobre el botón también completa. Con el dedo o el ratón se mantiene 1,2 s y soltar antes cancela. Enmienda de CA-025-07: quita «con el foco en él, Intro o espacio» de la pulsación mantenida.
  - **b)** Cualquier `click` completa, también un toque corto con el dedo o el ratón. Se pierde «soltar antes lo cancela» y deja de enseñar el gesto de la app.
- **P-025-6 · El test de «fuera de pantalla» de CA-025-16 (`a11y-reviewer`, importante).** Sin un navegador en los tests no se puede medir dónde cae cada elemento.
  - **a) (Recomendado)** Esa parte se verifica solo con la casilla C-025-6 (seis tamaños, ES y EN); el test se queda en que ninguna regla de CSS oculta un elemento principal. Enmienda de la línea «Verificable» de CA-025-16.
  - **b)** Se añade un navegador sin interfaz a los tests (Playwright, solo para construir y probar): una dependencia grande con su revisión de §5 y su tiempo de CI.
- **P-025-7 [Resuelta, propietario, 2026-11-13: b)] · El lector de pantalla con las escenas que desaparecen (CA-025-15).** Con lo transparente quitado del árbol, al leer de corrido el lector solo encuentra la escena a la vista; CA-025-15 pide que recorra las siete en orden.
  - **a) (Recomendado)** Al final de cada escena (salvo la última), un botón **oculto a la vista y visible al recibir el foco**, «Siguiente: {titular de la escena siguiente}» / «Next: {…}», que lleva a esa escena y pone el foco en su encabezado. El lector lo encuentra al acabar la escena y el teclado lo usa con Tab. Es una clave nueva del §7 (`navNext`) y un retoque de diseño (solo se ve con el foco); CA-025-15 no cambia.
  - **b)** Enmendar CA-025-15: con el recorrido, el lector lee la escena a la vista y pasa a las demás desplazando la página o con el teclado; quien necesite leerlo todo de corrido tiene la versión apilada con «reducir movimiento». Incumple WCAG 2.4.3 para quien no active esa preferencia: sería aceptarlo como la palabra sobre naranja, sin excepción de P6.
