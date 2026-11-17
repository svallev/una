# Plan técnico — Spec 026: Páginas de contenido

- **Spec:** `specs/026-paginas-de-contenido/spec.md` (estado: Aprobada, 2026-11-17)
- **ADR aplicables:** **ADR-0028** (programa propio de idioma en las cuatro páginas; **Aceptado** el 2026-11-17, al aprobar este plan; enmienda los ADR-0009 y 0027), ADR-0009, ADR-0027, ADR-0010 (Vercel), ADR-0026 (licencias de terceros)
- **Estado del plan:** **Aprobado** (propietario, 2026-11-17, «Aprueba el plan con la recomendación de la 2»: P-026-1 resuelta, se añade Trusted Types). Antes Borrador (2026-11-17). Revisado el mismo día por `security-reviewer` (0 bloqueantes, 3 importantes y 7 menores) y `a11y-reviewer` (0 bloqueantes, 5 importantes y 5 menores), todo aplicado

## 1. Resumen del enfoque

1. **El HTML lleva siempre los dos idiomas; el idioma lo decide una marca en `<html>`.** `build.mjs` sigue escribiendo cada página entera en ES y EN (la versión sin JavaScript, CA-026-09). Cada pieza que existe en los dos idiomas va marcada con `data-l="es"` o `data-l="en"` (y su `lang`), y los separadores que solo tienen sentido con los dos («·», « / ») con `data-l="sep"`. El programa pone `data-lang="es|en"` en `<html>`, y `site.css` oculta con `display: none` lo marcado con el otro idioma y los separadores: lo oculto ni se ve ni lo lee el lector. Sin la marca (sin JavaScript, programa bloqueado o roto) no se oculta nada.
2. **Sin salto al cargar (CA-026-08):** el programa es un `<script src="/lang.js">` **clásico y síncrono en el `<head>`**, después de las dos hojas de estilo. Se ejecuta antes de que exista el `<body>`: decide el idioma y marca `<html>` antes del primer pintado, así que el CSS ya oculta la otra mitad cuando llega el contenido. Al terminar de leerse la página (`DOMContentLoaded`) engancha el selector. No se mueve ni se reescribe nada del contenido.
3. **Un solo programa propio, sin dependencias** (`landing/src/lang.js`, ADR-0028): ni `import`, ni empaquetador, ni minificación; se copia tal cual a `dist/lang.js`. Solo toca atributos (`data-lang`, `lang`, y `role` y `aria-pressed` en las dos opciones del selector) y `document.title` (con textos que la construcción dejó en `<html data-title-es data-title-en>`); **nunca** escribe HTML ni estilos, ni nada leído del almacenamiento o de la dirección (solo los compara con `es` y `en`, P5).
4. **Nombres accesibles sin JavaScript extra:** los nombres que dependen del idioma (logotipo, grupo del selector, navegación del índice y del pie) se dan con texto oculto a la vista (`.vh`) marcado con `data-l`, no con `aria-label`: el mismo mecanismo de ocultar sirve para el lector y el programa no tiene que reescribir atributos.
5. **Una sola fuente de textos:** la cabecera y el pie usan los textos de la landing (`landing/home/src/shared/strings.{es,en}.json`: `nav.home`, `nav.download`, `nav.lang`, `footer.*`), que `build.mjs` lee directamente, con `{app}` sustituido por el nombre de `app/identity.yaml`. Sin copia en `strings.json` y sin test de «coinciden» (spec §7: el plan decide).
6. **Estilos con tokens, sin tocar la landing:** las cuatro páginas siguen con su `site.css` (solo variables de `tokens.css`, comprobado por `check.mjs`). El logotipo, «Descargar» y el pie se rehacen con tokens para verse como los de la landing sobre fondo claro (los valores de la maqueta coinciden con los tokens: `ink`, `paper`, `surface`, bordes de 3 px, sombra de 4 px); las diferencias de detalle se registran en DEV-60 y las revisa el propietario (C-026-1).
7. **Lo que solo se ve en un navegador va a las casillas.** Como en la 023 y la 025, sin bibliotecas de DOM ni navegador en la CI: el programa se prueba en Node con `node:vm` y objetos falsos de `document`, `location`, `navigator`, `localStorage` e `history`; el HTML y el CSS construidos, con las reglas de `check.mjs`. CA-026-08 y 11 (sin salto, tamaños de ventana) se verifican a mano (C-026-1 y 2).

## 2. Cambios por zona

La web no tiene las capas de la app. **`app/` no cambia.**

| Zona | Archivos | Cambio |
|---|---|---|
| Textos | `landing/src/strings.json` | `webOnThisPage` nuevo; se retiran `webSwitchToEnglish` y `webSwitchToSpanish` |
| Textos | `landing/home/src/shared/strings.{es,en}.json` | Sin cambios: `build.mjs` los lee (§1.5) |
| Construcción | `landing/build.mjs` | Nueva estructura de página (§2.1), índice y anclas (§2.2), fecha bajo el título, copia de `lang.js`, lectura de los textos de la landing |
| Programa | `landing/src/lang.js` | Nuevo (§2.3) |
| Estilos | `landing/src/site.css` | Cabecera fija, selector, columna, titulares, índice, pie, página actual, 44 × 44, ventanas bajas, colores forzados, reglas de ocultar (§2.4) |
| Cabeceras | `landing/vercel.json` | `script-src 'self'` en la regla `/(.+)` (§6.1) |
| Comprobación | `landing/check.mjs` | Reglas nuevas de estructura, programa, recursos y CSS; las dos reglas de cabeceras difieren solo en `style-src` (§6.1) |
| Servidor local | `landing/serve.mjs` | Sin cambios previstos (ya sirve `.js` y lee `vercel.json`) |
| Landing | `landing/home/src/a/main.js`, `shared/journey.js`, `shared/story.js` | Abrir en la escena que nombra el ancla (`/#fin`), con y sin recorrido (CA-026-16, §2.5) |
| Política | `docs/legal/privacy-policy.md` | «Esta web» en ES y EN y notas de revisión (CA-026-14) |
| Tests | `landing/test/*.test.mjs` | Los de la 023 y la 025 que cambian, citando el CA nuevo; nuevos: `lang.test.mjs`, `content-layout.test.mjs` (o dentro de los existentes) |
| Documentación | ver CA-026-17 | Al final (T-026-10) |

### 2.1 Estructura de cada página (CA-026-01, 02, 05, 09 y 10)

```html
<html lang="es" data-title-es="Privacidad · Una" data-title-en="Privacy · Una">
<head> … <title>Privacidad · Una / Privacy · Una</title>
  <link rel="stylesheet" href="/tokens.css"><link rel="stylesheet" href="/site.css">
  <script src="/lang.js"></script></head>
<body>
<header class="top">
  <a class="logo" href="/"><span aria-hidden="true">una.</span>
     <span class="vh" lang="es" data-l="es">Una, inicio</span><span class="vh" lang="en" data-l="en">Una, home</span></a>
  <a class="btn" href="/#fin"><svg class="ic" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 4v15M6 13l6 6 6-6"/></svg>
     <span class="btn__label"><span lang="es" data-l="es">Descargar</span><span data-l="sep"> / </span><span lang="en" data-l="en">Download</span></span></a>
</header>
<main>
  <div class="langs" role="group" aria-labelledby="langs-name">
    <span id="langs-name" class="vh"><span lang="es" data-l="es">Idioma</span><span lang="en" data-l="en">Language</span></span>
    <a href="#es" hreflang="es" lang="es"><span>ES</span><span class="vh">, Español</span></a>
    <a href="#en" hreflang="en" lang="en"><span>EN</span><span class="vh">, English</span></a>
  </div>
  <p><a class="back" href="/"><span aria-hidden="true">← </span><span lang="es" data-l="es">Volver al inicio</span>…</a></p>
  <h1><span lang="es" data-l="es">Privacidad</span><span data-l="sep"> · </span><span lang="en" data-l="en">Privacy</span></h1>
  <section class="half" lang="es" data-l="es" aria-labelledby="es">
    <h2 id="es" tabindex="-1" class="half__title">Política de privacidad (ES)</h2>
    <p class="date">Última actualización: [FECHA]</p>          <!-- solo la política -->
    <nav class="toc" aria-labelledby="es-toc">…</nav>         <!-- política y Ayuda -->
    …contenido (secciones <h3 id="es-…" tabindex="-1">)…
  </section>
  <section class="half" lang="en" data-l="en" aria-labelledby="en">…</section>
</main>
<footer class="end">…aviso legal · nav (Ayuda, Privacidad, Licencias; la actual con aria-current="page") · contacto…</footer>
```

- **Encabezados en los dos modos (CA-026-10):** un `<h1>` (bilingüe sin JavaScript; con él, solo un idioma). Cada mitad empieza por su `<h2 id="es|en">`: en la política y la Ayuda, el título de su Markdown («Política de privacidad (ES)», «Ayuda (ES)»); en licencias y la página de error, `webLanguageName` («Español», «English»; responde a la duda de la spec §7: **sigue** como titular de cada mitad). Con JavaScript ese `<h2>` se oculta **a la vista** (`.vh`, no `display: none`): el lector lo sigue teniendo y no hay salto de `h1` a `h3`. Las secciones de cada mitad son `<h3>` (con la regla de 4 px, CA-026-03).
- **El `<h2>` del Markdown y la fecha:** la línea `**Última actualización:** …` de cada mitad de la política se quita del cuerpo publicado y se escribe como `<p class="date">` con `webLastUpdated`, justo tras el `<h2>` y antes del índice (CA-026-04). Sale del pie.
- **Selector:** sin JavaScript son dos enlaces a las mitades (sustituyen a «Read in English» / «Leer en español», CA-026-09). Con JavaScript, el programa les pone `role="button"` y `aria-pressed` (`true` en el elegido; como los botones de la landing, que el lector anuncia al cambiar) y, al pulsar (clic, Intro o Espacio), cambia el idioma sin navegar (CA-026-07). Nombre accesible «ES, Español» / «EN, English», marcado con su idioma: contiene el texto visible entero, también para el control por voz (WCAG 2.5.3).
- **«Descargar»:** enlace a `/#fin` (la escena de cierre de la landing, CA-026-16). El icono va en línea (SVG `aria-hidden`), **sin archivo nuevo** (CA-026-15); `check.mjs` admite ese único `<svg>`. A 520 px o menos el texto se oculta a la vista (`.vh`), como en la landing, y sigue siendo el nombre.
- **Pie:** `footer.legal` («© 2026 Una»), la navegación `footer.nav` con Ayuda, Privacidad y Licencias **en ese orden** (la de la página, `aria-current="page"`; en la de error, ninguna) y `webContact`. Todo con las dos variantes `data-l`.
- **Página de error:** sin «← Volver al inicio» encima del título (ya va en su texto: uno solo por página, CA-026-01); cada mitad: `<h2>` con `webLanguageName`, `webNotFoundBody` y su enlace «Volver al inicio».
- **Licencias:** cada mitad, igual que hoy (versión o aviso de última compilación, texto de la app, enlace al archivo); después el bloque «Código de esta web» (`<h2>` bilingüe con `data-l`) y el de avisos, una sola vez, en `<pre lang="en">`, fuera de las mitades (CA-026-12).

### 2.2 Índice y anclas (CA-026-04)

- Las anclas de las secciones se generan en `build.mjs` desde el titular: prefijo del idioma y el texto en minúsculas, sin acentos (`normalize("NFD")` y quitar marcas), con todo lo que no sea letra o número convertido en «-» y sin «-» repetidos ni en los extremos: `## Quién es el responsable` → `es-quien-es-el-responsable`. Estables mientras no cambie el titular; distintas en cada idioma por el prefijo. **Dos titulares con la misma ancla hacen fallar la construcción.**
- El índice de cada mitad es `<nav class="toc" aria-labelledby="es-toc"><p id="es-toc" class="toc__name">En esta página</p><ul>…</ul></nav>` (`webOnThisPage`, no es un encabezado) con un enlace por `<h3>` de la mitad, en orden. Cada `<h3>` lleva `tabindex="-1"`: al seguir el enlace, el navegador le pasa el foco (sin JavaScript).
- Licencias y error, sin índice. Los enlaces existentes a `/privacy#es` y `/privacy#en` (la Ayuda) siguen valiendo: apuntan a los `<h2>` de las mitades.

### 2.3 El programa (`landing/src/lang.js`, CA-026-06 a 08, CL-026-2 a 8)

Una función que se ejecuta al cargarse, dentro de `try` (si algo falla, no marca `<html>` y se ve la versión sin JavaScript, CL-026-5):

1. `pick()`: el idioma del ancla si `location.hash` cumple `^#(es|en)(-|$)` (sin guardarlo); si no, lo guardado en `localStorage["una-lang"]` si es exactamente `es` o `en` (leído en `try`: sin almacenamiento, se sigue); si no, `navigator.language`: `/^(es|ca)/i` → `es`, otro → `en`, vacío → `es` (la regla de `landing/home/src/shared/i18n.js`, CL-026-11). `?lang=` no se mira.
2. `apply(lang)`: `html.dataset.lang = lang`, `html.lang = lang`, `document.title = html.dataset["title" + Lang]`, y, si el selector ya está en la página, `aria-pressed` (`true` en la elegida, `false` en la otra). Lo último que hace es poner `data-lang` (si falla antes, no se oculta nada).
3. En `DOMContentLoaded`: `role="button"`, `aria-pressed`, un manejador de clic y otro de Espacio (`keydown`, que hace lo mismo que el clic) en cada `.langs a[hreflang]`: si es el idioma de ahora, `preventDefault` y nada más; si no, `preventDefault`, `apply(nuevo)`, guardar en `try` y, si el ancla de la dirección es del otro idioma, quitarla con `history.replaceState` (para que una recarga no vuelva al idioma del ancla). El foco no se mueve.
4. `hashchange`: si el ancla nueva cumple `^#(es|en)(-|$)`, `apply(pick())` (sin guardar; atrás y adelante dentro de la misma página, o un ancla escrita a mano). `pageshow` con `persisted` (página sacada de la memoria del navegador al volver atrás, CL-026-8): `apply(pick())`.
5. Nada más: ni `storage` (CL-026-7: la otra pestaña no cambia), ni temporizadores, ni red, ni HTML.

### 2.4 Estilos (`site.css`, CA-026-02, 03, 10 y 11)

- **Ocultar:** `html[data-lang="es"] [data-l="en"], html[data-lang="en"] [data-l="es"], html[data-lang] [data-l="sep"] { display: none }` y `html[data-lang] .half__title` como `.vh`.
- **Cabecera:** `position: fixed`, arriba, a lo ancho, fondo `paper` opaco, una línea `line` abajo (sin sombra); logotipo en Archivo `black` y «Descargar» con borde `strong` de tinta, fondo `surface`, sombra dura de `space-xs` (la del botón de la landing, no decorativa). `scroll-padding-top` en `html` con la altura de la cabecera en `rem` (crece con el texto) para que el foco y los saltos del índice queden por debajo (2.4.11). **Una sola variable de CSS** da la altura de la cabecera, el hueco de arriba del cuerpo y el `scroll-padding-top`, y la cabecera lleva `white-space: nowrap` (no crece en dos líneas con el espaciado de texto aumentado, 1.4.12). `@media (max-height: 539.98px)`: `position: static` y sin `scroll-padding` (CA-026-02). El cuerpo deja arriba el hueco de la cabecera.
- **Selector:** fila centrada, «ES | EN» con un separador fino; el elegido (`[aria-pressed="true"]`) en peso `black` y subrayado grueso (no depende del color y sigue con colores forzados); cada opción de 44 × 44 como mínimo. Sin JavaScript, los dos iguales.
- **Mitades:** `.half { position: relative }`, para que el `<h2>` oculto a la vista (destino de `#es`/`#en`) deje la mitad a la vista al saltar.
- **Columna:** `main` y el pie hasta `size.webContentMaxWidth` (`--size-web-content-max-width`, 1120 px; token nuevo solo de la web: `contentMaxWidth`, 600 px, sigue siendo el de la app), centrados, sobre `paper` (enmienda del propietario, 2026-11-17, al revisar C-026-1: aprovechar el ancho como superplay.co/terms; antes, 600 px).
- **Titulares:** `h1` en Archivo `black`; `h3` con `border-top` de `border-width-section` (4 px; el token ya existe); `h3:focus-visible` con el mismo contorno que `a` y `h2`; fecha, versión y aviso de compilación en Space Mono (`.date`, `.meta`).
- **Objetivos de 44 × 44:** logotipo, «Descargar», ES, EN, «← Volver al inicio», enlaces del índice y del pie (`min-height` y `min-width` con `size-min-touch-target`, o el `::after` de la landing).
- **Página actual del pie:** `aria-current="page"` en peso `bold` y sin subrayado frente a los otros, con una línea de `border-width-strong` debajo (3:1 o más; con colores forzados se ve el borde).
- **Icono de «Descargar»:** `stroke: currentColor` (a 520 px o menos es el único rótulo visible: 3:1, 1.4.11).
- **Colores forzados:** `@media (forced-colors: active)`: bordes del botón, del selector y de la página actual, y el trazo del icono, con `CanvasText`.
- **Sin movimiento:** ninguna `transition` ni `animation` (las reglas de 023 ya lo comprueban).
- `check.mjs` admite en el CSS **solo** dos valores sueltos en condiciones de `@media`: `max-height: 539.98px` (umbral de la landing, `mode.js`) y `max-width: 520px` (el de su botón); cada uno con un test que falla con otro valor. Par nuevo de contraste `ink/surface` (texto del botón; 18,9:1) en `ALLOWED_PAIRS` y en `docs/design/tokens.md`.

### 2.5 La landing abre en el cierre (CA-026-16)

- **[Hecho, leído el 2026-11-17]** La escena de cierre es `<section id="fin">`. Sin JavaScript (versión apilada) el navegador ya salta a ella. Con JavaScript no: si el idioma no es el de la construcción, `main.js` reescribe la página (el salto del navegador se pierde) y, en el recorrido, las escenas están en 3D dentro de un elemento alto, así que el salto nativo no lleva al cierre.
- Cambio mínimo: `sceneFromHash(hash)` en `shared/story.js` (puro: el índice de la escena cuyo `id` coincide exactamente, o −1; probado en Node). En `main.js`, al terminar de montar: apilada → `scenes[i].scrollIntoView()`; recorrido → un salto **inmediato** a la escena (`journey.js`: `jumpToScene(i)`, con `lenis.scrollTo(…, { immediate: true })` tras calcular ScrollTrigger). Se registra en DEV-59 (diferencia con la maqueta).

## 3. Modelo de datos y migraciones

Sin cambios: ni esquema, ni `app/`, ni `identity.yaml`.

## 4. Dependencias nuevas

**Ninguna.** El programa es propio (ADR-0028). `landing/package.json` no cambia; las cuatro páginas no cargan nada de `node_modules`.

## 5. Estrategia de tests

`node landing/build.mjs && node landing/check.mjs && node --test landing/test/*.test.mjs` (lo mismo que la CI, «Web y ficha»). Cada regla nueva de `check.mjs` lleva un caso que falla.

| CA | Tipo | Archivo |
|---|---|---|
| 01 | HTML construido: orden de las piezas, un solo «Volver al inicio», pie con tres enlaces en orden y el actual marcado | `build.test.mjs`, `check.mjs` (`checkPage`) |
| 02 | Cabecera con logotipo y «Descargar»; reglas de `position: fixed`, `scroll-padding-top` y la excepción por altura en el CSS | `a11y.test.mjs` |
| 03 | Tokens en el CSS (la comprobación de la 023), regla de 4 px en `h3`, sin animaciones | `a11y.test.mjs` |
| 04 | Un enlace por sección, en orden, a un ancla única que existe, en cada idioma; la fecha antes del índice; anclas repetidas hacen fallar | `policy.test.mjs`, `help.test.mjs` |
| 05 | `404.html` con cabecera, selector, pie y el texto de hoy | `build.test.mjs` |
| 06 | La tabla de casos de la spec y las anclas, en `node:vm`; idioma declarado y título | `lang.test.mjs` |
| 07 | Clic y Espacio: cambio completo (atributos y título), `role="button"` y `aria-pressed`, guardado, sin almacenamiento, el mismo idioma no hace nada, ancla del otro idioma quitada | `lang.test.mjs`; grupo y nombres en el HTML, `build.test.mjs` |
| 08 | Estructura: `<script>` clásico, sin `async`/`defer`/`type`, en el `<head>` tras las hojas de estilo; reglas de ocultar en el CSS. **Además casilla C-026-2** | `security.test.mjs`, `a11y.test.mjs` |
| 09 | HTML sin ejecutar nada: mitades en orden y con su idioma, piezas comunes en los dos, ES/EN a `#es`/`#en`; programa forzado a fallar no marca `<html>` | `build.test.mjs`, `lang.test.mjs` |
| 10 | **Simulación de cada modo** sobre el HTML construido (quitar `[data-l=otro]` y `[data-l=sep]`): encabezados sin saltos, nombres del logotipo, del grupo, del índice y del pie en un solo idioma, cada enlace del índice a un `id` que sigue. Además: cada `data-l="es|en"` con su `lang` igual y su pareja; `data-l="sep"` sin `lang` ni elementos que reciban el foco; cada `aria-labelledby` a un `id` único que existe; `tabindex="-1"` solo en los `<h2>` de las mitades y los `<h3>`; zonas; orden del HTML; reglas de 44 × 44, `h3:focus-visible`, icono con `currentColor` y colores forzados en el CSS; **casilla C-026-3** | `a11y.test.mjs` |
| 11 | Solo casilla C-026-1 (sin navegador en la CI) | `navegadores.md` |
| 12 | Avisos una sola vez, en `<pre lang="en">`; título del bloque en los dos idiomas sin JavaScript; `white-space: pre-wrap` y `overflow-wrap: anywhere` | `licenses.test.mjs` |
| 13 | CSP de `vercel.json`; un único `<script src="/lang.js">` por página; en `lang.js`, sin API de red, sin `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write`, sin `.style` ni `setAttribute("style"…)`, sin `import`, `localStorage` solo con `"una-lang"`; cada regla con un caso que falla | `security.test.mjs` |
| 14 | Frases nuevas en ES y EN; la antigua ya no está; misma estructura en las dos mitades; `[FECHA]` sigue | `policy.test.mjs` |
| 15 | `lang.js` ≤ 10 240 bytes; `dist/lang.js` igual al fuente; recursos de cada página: `/tokens.css`, `/site.css`, `/lang.js` (y las fuentes por el CSS), nada más | `build.test.mjs` |
| 16 | «Descargar» apunta a `/#fin`; `sceneFromHash` | `build.test.mjs`, `home-page.test.mjs` |
| 17 | `spec-reviewer` al cerrar; CI en verde | — |

## 6. Seguridad, accesibilidad y rendimiento

### 6.1 Seguridad (T-9, T-18; checklist, apartado de la web)

- **CSP:** la regla `/(.+)` pasa a `default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; require-trusted-types-for 'script'; trusted-types 'none'` (P-026-1). La de `/` no cambia. `checkVercel` exige que las dos reglas sean iguales **salvo `style-src`, `require-trusted-types-for` y `trusted-types`** (antes: salvo `script-src` y `style-src`), y que `/(.+)` lleve las dos de Trusted Types con esos valores exactos (un caso que falla sin ellas).
- **En las cuatro páginas:** un único `<script>`, con solo `src="/lang.js"` y sin contenido; ningún manejador `on*`, `style=` ni `<style>` (como hoy); un único `<svg>`, dentro del enlace de «Descargar», con `aria-hidden="true"` y solo `<path d>`.
- **El `<script>`:** `src` exactamente `/lang.js` (absoluto: la página de error se sirve en cualquier ruta), sin `type`, `async`, `defer` ni `nomodule`, sin contenido.
- **En `lang.js`:** las prohibiciones de `FORBIDDEN_APIS` de la landing, las de §5 (CA-026-13) y además: `location.href =`, `location.assign`, `location.replace`, `window.open`, `postMessage`, `setTimeout`, `setInterval`, `textContent`, `innerText`, `createElement`, `addEventListener("storage"`; `setAttribute` y `removeAttribute` **solo** con `"role"` y `"aria-pressed"` (lista blanca); **ningún dominio** (lista vacía, no `PROGRAM_HOSTS`). Cada patrón con un caso que falla. **[Hecho, leído el 2026-11-17]** La clave `una-lang` no la marca la regla del nombre a mano (`mentionsName` distingue mayúsculas y el logotipo lleva punto); un test lo fija (`lang.js` pasa `checkHandWrittenName`).
- **`replaceState`:** siempre `history.replaceState(history.state, "", location.pathname + location.search)`; nunca una dirección hecha con el ancla (test: el argumento no lleva `#` y es el mismo camino).
- **Ancla:** expresión anclada `^#(es|en)(-|$)`, sensible a mayúsculas; tests con `#esx`, `#ES`, `#es%2D…` y un ancla muy larga: ninguno marca idioma por error ni hace fallar el programa.
- **`data-title-*`:** pasa por `esc` de `build.mjs`; test con `"` y `&` en el nombre de la identidad y `document.title` igual al atributo.
- **Ningún HTML ni programa de más en `dist/`:** con `script-src 'self'` en `/(.+)`, cualquier `.html` sobrante podría ejecutar programas del propio origen. `check.mjs` falla si en `dist/` hay un `.html` que no sea `index.html` o una de las cuatro páginas, o un `.js` que no sea `lang.js` o `assets/*.js` (con su test).
- **`checkVercel`:** falla si el `script-src` de `/(.+)` no es exactamente `'self'` (`'unsafe-inline'`, `'unsafe-eval'`, un dominio o `data:`, cada uno con su caso).
- **Trusted Types [Hecho, P-026-1 resuelta por el propietario el 2026-11-17: «sí, métela»]:** como `lang.js` no usa ningún sumidero de HTML, `require-trusted-types-for 'script'; trusted-types 'none'` en `/(.+)` lo hace cumplir el navegador (Chromium) sin coste. Endurece, no relaja: la spec queda enmendada en CA-026-13. En C-026-2, la consola sin infracciones de Trusted Types.
- La web no sirve nada subido ni de terceros, y `nosniff` impide ejecutar como programa `/third-party-notices.txt` o las fuentes: `script-src 'self'` solo puede ejecutar `/lang.js` y el programa de la landing.

### 6.2 Accesibilidad

- Lo de §2.1 y §2.4. El orden del teclado sale del orden del HTML: logotipo, «Descargar», ES, EN, «← Volver al inicio», índice, contenido y pie (CA-026-10).
- Con colores forzados, el subrayado y los bordes siguen; se mira en C-026-3.
- **TalkBack** con Chrome en el emulador, en C-026-3 (zonas, titulares en los dos modos, anuncio del cambio de idioma, nombre del grupo, página actual, «Descargar» solo con icono); si no se puede, «sin verificar» con el motivo (spec §11). También en C-026-3: Voice Access (Android) diciendo «ES»/«EN»; teclado (orden, Intro y Espacio en el selector, Mayús+Tab con la cabecera fija y el espaciado aumentado, foco visible en los `<h3>` del índice); VoiceOver de macOS con Safari si el propietario lo mira; VoiceOver de iOS y Switch Control, sin dispositivo: «sin verificar».
- **Salvedades aceptables (se anotan en C-026-3):** con JavaScript el lector lee el título y después el `<h2>` oculto («Privacidad», «Política de privacidad (ES)»; en licencias y error, «Español»); sin JavaScript los nombres bilingües («Idioma Language») se leen con la voz del idioma de la página; el selector va dentro de `<main>` (orden fijado por la spec), así que saltar a la zona principal cae en él.

### 6.3 Rendimiento

- Un archivo de ≤ 10 KB, síncrono, del propio origen y que se guarda en caché: bloquea el análisis un instante. Se mira en C-026-2 (Slow 4G, sin caché). La página de licencias (≈ 1,5 MB) no se descarga dos veces: cambiar de idioma no recarga (CL-026-9).

## 7. Riesgos y alternativas

| Riesgo | Mitigación |
|---|---|
| El navegador pinta antes de que se ejecute `lang.js` (salto, CA-026-08) | Un `<script>` síncrono en el `<head>` bloquea el pintado del `<body>` hasta ejecutarse; se comprueba con la tira de imágenes (C-026-2). Si se viera el salto, **se para y se pregunta** (no se añaden programas en la página: la CSP no los admite) |
| `scroll-padding-top` no cubre una cabecera que crece con texto grande | Altura en `rem`; C-026-3 con 200 % y 400 %. Por debajo de 540 px de alto la cabecera no es fija |
| Ocultar con `display: none` deja anclas en la mitad oculta | El idioma sale del ancla (paso 1): la mitad del ancla siempre es la visible |
| El salto inmediato de la landing al cierre choca con el imán o con Lenis | Se hace tras calcular ScrollTrigger y con `immediate`; casilla C-026-1 con y sin recorrido. Si no queda estable, se para y se pregunta |
| Diferencias de aspecto con la landing (tokens frente a los valores de la maqueta) | DEV-60 y revisión del propietario (C-026-1) |

**Alternativas descartadas:** reutilizar el programa de la landing (Vite, ADR-0028, opción 3); cambiar el idioma recargando la página (la de licencias pesa 1,5 MB); escribir los nombres accesibles con `aria-label` y reescribirlos desde el programa (más código y más superficie que el texto oculto con `data-l`).
