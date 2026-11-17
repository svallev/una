# Plan técnico — Spec 027: Licencias agrupadas por paquete

- **Spec:** `specs/027-licencias-por-paquete/spec.md` (estado: Aprobada, 2026-11-17)
- **ADR aplicables:** ADR-0026 (licencias en la web, revisión legal en F6), ADR-0027 (la web: Vite solo para la página de inicio), ADR-0028 (páginas de contenido con un único programa, `/lang.js`). **Sin ADR nuevo:** no cambia ninguna decisión; los desplegables son HTML nativo.
- **Estado del plan:** **Aprobado** por el propietario el 2026-11-17 (antes Borrador; revisado por `a11y-reviewer` y `security-reviewer` el mismo día, hallazgos aplicados; Q-P-1 resuelta con la recomendación)

## 1. Resumen del enfoque

Todo pasa en la construcción de la web (`landing/build.mjs`) y en su comprobación (`landing/check.mjs`); la app no cambia.

1. **Analizador puro** `parseNoticesBody(body)` en `build.mjs` (exportado, sin E/S), sobre el cuerpo que ya devuelve `parseNotices` (todo lo que sigue a la cabecera de la compilación), con los finales de línea normalizados a `\n` (`norm`, como hoy). Recorre el texto **por líneas**, con un estado (preámbulo → avisos → secciones) y **sin listas escritas a mano** (CL-027-6):
   - **Marcadores:** una línea completa `^===== (BEGIN|END) (\S+) =====$` (la forma de `tools/check-licenses.sh`). `BEGIN` dentro de otra parte = **anidada**; `END` sin su `BEGIN` o con otro nombre, o un `BEGIN` sin `END` al acabar = error. En el preámbulo **solo** se admite la pareja `BEGIN/END ENTRIES`, una vez y bien cerrada; cualquier otro marcador ahí es error. `NOTICES` va **exactamente una vez** (si falta: «ningún aviso»; una segunda pareja: error).
   - **Preámbulo:** todo lo anterior a `===== BEGIN NOTICES =====`, **tal cual** (incluidas sus líneas `BEGIN/END ENTRIES`: el preámbulo se publica entero, CA-027-03).
   - **Avisos:** las líneas entre `BEGIN NOTICES` y `END NOTICES` se parten por las líneas de **exactamente 80 guiones** (solo aquí son separadores; fuera son texto, CL-027-3). Cada trozo: la **cabecera** (líneas hasta la primera en blanco; al menos una, cada una sin espacios ni caracteres de formato invisibles: `/^[^\s\p{Cf}]+$/u`), una línea en blanco y el **texto** (el resto de líneas unidas con `\n`, con sus blancos del principio y del final). Errores: trozo vacío o sin línea en blanco, cabecera vacía o con espacios, texto vacío o solo blancos, ningún aviso, y **una cabecera que reaparece** tras otra distinta (clave = los nombres unidos por `\n`).
   - **Secciones:** tras `END NOTICES`, cada parte `BEGIN <ruta>`…`END <ruta>` es una sección con su ruta como nombre y su texto entre marcadores; ruta repetida = error. **Cualquier línea que no sea solo espacio en blanco fuera de una parte** (entre `BEGIN NOTICES` y el primer aviso no puede haberla porque el primer trozo empieza ahí; entre `END NOTICES` y la primera sección, entre secciones o tras la última) = error.
   - Devuelve `{ preamble, groups: [{ names, notices: [texto…] }], sections: [{ path, text }] }`. Los mensajes dicen **qué y en qué línea** del archivo (sumando la cabecera de la compilación). Error con `BuildError`, como el resto (falla cerrado, CA-027-05).
   - **Archivo entero, sin rutas personales ni caracteres peligrosos** (CA-027-04, CA-023-19; revisión de seguridad B-1 b): antes de analizar, la construcción falla si el archivo lleva `/Users/`, `/home/` (salvo `/home/runner/`, como `check-package.sh`) o `C:\Users\`, o caracteres de control (salvo `\n`, `\r`, `\t`) o de dirección (U+202A–202E, U+2066–2069, U+200E/F, U+2028/9). Es la regla que hoy solo vive en un test sobre el archivo real; así también la cumple lo que construye Vercel. El test de la 023 se queda. (Q-P-1)
   - Una función inversa `rebuildNoticesBody(parsed)` (cabeceras, línea en blanco, texto, separadores y marcadores). **La construcción comprueba la ida y vuelta** (revisión de seguridad I-2): si `preámbulo + rebuildNoticesBody(parsed)` no es igual al cuerpo normalizado, `BuildError`. Los tests además cuentan **por su cuenta** (partiendo el cuerpo por las líneas de 80 guiones, sin el analizador).
2. **HTML** (en `renderSite`, que hoy pone un único `<pre>`): la `<section lang="en" aria-labelledby="notices">` con su `<h2 id="notices">` se queda (es la **región con nombre** que pide CA-027-06: una `<section>` con nombre accesible es una región) y dentro va:
   ```html
   <pre lang="en" class="notices__preamble">…preámbulo…</pre>
   <p><a class="block-link" href="#notices-end"><span>{bilingüe webNoticesSkip}</span></a></p>
   <details class="group"><summary><span class="group__name">a, b</span> <span class="group__count">({bilingüe del recuento})</span></summary>
   <pre lang="en">…aviso 1…</pre>
   <pre lang="en">…aviso 2…</pre>
   </details>
   … (un <details> por cabecera, en orden, y uno por sección assets/…, con la ruta como nombre) …
   <p class="notices__end"><a id="notices-end" class="block-link" href="/third-party-notices.txt"><span>{bilingüe webLicensesFile}</span></a></p>
   ```
   - Un `<pre>` **por aviso**: el texto del DOM de cada `<pre>` es el texto del aviso, sin unir nada (CA-027-02). Escapado con `esc` (CL-027-12).
   - El recuento con `bilingual()` (cada mitad con su `lang` y su `data-l`, el separador con `data-l="sep"`): con JavaScript se oculta el del otro idioma con la misma regla de `site.css` (CA-026-09); sin él, los dos. El nombre del grupo hereda `lang="en"` de la sección.
   - Los grupos **sin** `open` (plegados, CA-027-01). Sin `id` por grupo (anclas por paquete fuera de alcance, §8).
   - **Destino del enlace de saltar** (revisión de accesibilidad, I-1, opción A): **el enlace «Ver el archivo de avisos como texto»** repetido justo tras el último grupo, dentro de la sección (CA-027-06 y 07), con `id="notices-end"`. Tiene nombre y una acción útil (un destino vacío lo saltan TalkBack y VoiceOver), es enfocable sin `tabindex`, reutiliza `webLicensesFile` (no hay clave nueva) y, como va al mismo sitio que el de las mitades, el nombre repetido cumple 2.4.4 y 3.2.4. `scroll-padding-top` lo deja bajo la cabecera fija. El test de la 023 que cuenta dos enlaces al `.txt` pasa a contar los de las mitades y este, citando CA-027-06.
   - **Textos bilingües en un `block-link`:** las tres piezas de `bilingual()` van dentro de **un solo `<span>`**, para que sin JavaScript partan línea como texto normal (`.block-link` es `flex` sin `flex-wrap`) al 400 % y con el espaciado aumentado.
   - **Ids nuevos:** `notices-end` no empieza por `es`/`en`, así que el `hashchange` de `lang.js` (`^#(es|en)(-|$)`) no lo toma por un idioma; ningún id nuevo puede empezar por `es-` o `en-`.
   - Los **paréntesis** del recuento van **fuera** de las piezas bilingües (el lector no los lee dos veces): con JavaScript, «icu (552 avisos)»; sin él, «icu (552 avisos / 552 notices)».
3. **Textos:** `webNoticesCountOne`, `webNoticesCountMany` (`{n}`) y `webNoticesSkip` en `landing/src/strings.json` y en `STRING_KEYS` (con `{n}` admitido solo en `webNoticesCountMany`); el recuento se elige por `n === 1` y se rellena con `fill()`, que ya existe.
4. **Estilos** (`site.css`, solo `var(--…)`):
   - `.group > summary`: `min-height: var(--size-min-touch-target)` (y `min-width`, para la regla de 44 × 44 de `check.mjs`), relleno vertical, `cursor: pointer`, **sin `height` ni `overflow: hidden`** (1.4.12); **se deja el marcador nativo** (`display: list-item` explícito, sin `list-style: none` ni `::-webkit-details-marker { display: none }`): el triángulo cambia de forma al abrir (no solo color), se pinta con `currentColor` (tinta sobre papel) y con `CanvasText` en colores forzados; los navegadores exponen el estado expandido al lector. `check.mjs` falla si `.group > summary` lleva otro `display` o `list-style: none`.
   - Una línea fina (`--color-line`) entre `details` seguidos, para recorrer los 164 grupos plegados con zoom.
   - `.group pre + pre`: `border-top: var(--border-width-hairline) solid var(--color-line)` y un espacio arriba (la separación entre avisos, CA-027-01).
   - `.group__count` en Space Mono y `--color-text-muted`, como `.meta`.
   - `summary:focus-visible` con el anillo de foco de siempre (el destino es un enlace: ya lo tiene); `.notices__end` con la línea fina arriba que cierra la lista.
   - En colores forzados, el borde entre avisos y el de cierre con `CanvasText`.
   - Sin `transition`, `animation` ni `scroll-behavior: smooth` (nada se mueve). `pre` ya parte las líneas (`pre-wrap` + `overflow-wrap: anywhere`).
5. **Comprobación** (`check.mjs`): `checkNoticesBlock` pasa a exigir la nueva forma (el `<h2 id="notices">`, el `<pre lang="en">` del preámbulo, el enlace a `#notices-end` antes del primer `<details>`, al menos un `<details>`, cada uno **sin `id`, `open` ni atributos `on*`**, con `<summary>` como **primer hijo** y, después, **solo** `<pre lang="en">`; **ningún `<pre>` fuera de los grupos** salvo el del preámbulo; y el enlace `#notices-end` al `.txt` tras el último grupo y dentro de la sección). Así un error de plantilla no saca texto de un aviso fuera de un `<pre>` (fuera de la exclusión de las guardias) sin que se vea. `TOUCH_TARGETS` suma `.group > summary`, la lista del anillo de foco suma `summary:focus-visible` y `.group > summary` tiene que ser `display: list-item` sin `list-style: none`. El resto (un único `<script src="/lang.js">`, sin `style=`, CSP, lista de archivos de `dist/`) no cambia y ya cubre CA-027-04 y 08 (sin archivos ni programas nuevos).
6. **Guardias que miran el texto de los avisos** (CA-027-04): la de los **huecos de identidad** (`findGaps` en `build.mjs`) y la de **analítica** (`check.mjs`) quitan hoy los `<pre>` antes de buscar (la regex perezosa quita cada `<pre>` por separado; un `</pre>` en un texto sale escapado y no cierra nada). Cada aviso sigue en su `<pre>`, así que su texto sigue fuera de esas dos guardias. **Lo nuevo:** los **nombres de grupo** y las rutas `assets/…` van en el `<summary>`, fuera del `<pre>`, y **ahora sí los miran** las dos guardias: un nombre con `[DATE]` es un hueco y un nombre como `plausible` hace fallar `check.mjs`. Se acepta como fallo cerrado (revisión de seguridad I-1) y se prueba. Las **rutas personales y los caracteres peligrosos** se miran en todo el archivo al construir (§1.1). Ver **Q-P-1** (§7).

## 2. Cambios por capa

| Capa | Archivos o módulos | Cambio |
|---|---|---|
| Dominio | — | Sin cambios (la app no cambia). |
| Datos | — | Sin cambios. |
| Estado | — | Sin cambios. |
| Presentación (web) | `landing/build.mjs` | `parseNoticesBody`, `rebuildNoticesBody`, HTML del bloque de avisos en grupos, tres claves en `STRING_KEYS`. |
| Presentación (web) | `landing/src/site.css` | Grupos, recuento, separación entre avisos, destino del salto, foco y colores forzados. |
| Presentación (web) | `landing/check.mjs` | `checkNoticesBlock` con la nueva forma; `TOUCH_TARGETS` y anillo de foco con `summary`. |
| Presentación (web) | `landing/src/lang.js` | **Sin cambios** (no toca `<details>`; CA-027-04 se prueba en `lang.test.mjs`). |
| Nativo | — | Sin cambios. |
| l10n | `landing/src/strings.json` | `webNoticesCountOne`, `webNoticesCountMany`, `webNoticesSkip` (ES y EN, §7 de la spec). |
| Tests | `landing/test/licenses.test.mjs`, `support.mjs`, `lang.test.mjs`, `a11y.test.mjs`, otros que usan `fakeNotices` | `fakeNotices` con la estructura mínima válida (`BEGIN/END NOTICES` y un aviso); tests nuevos con su CA-027-NN. |

## 3. Modelo de datos y migraciones

Sin cambios de esquema.

## 4. Dependencias nuevas

Ninguna. Los tests leen el texto del DOM con un decodificador mínimo de las cinco entidades que emite `esc` (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`) en `test/support.mjs`, que falla si encuentra otra entidad; no se añade jsdom ni un analizador de HTML.

## 5. Estrategia de tests

Todo con `node --test` en `landing/test/` (sin red ni navegador). Cada test cita su CA-027-NN.

| Criterio de aceptación | Tipo de test | Archivo |
|---|---|---|
| CA-027-01 | Construcción con un archivo de prueba (cabecera repetida y seguida, una compartida por varios paquetes, una de un aviso, `a, b` frente a `b, a`, `dart` frente a `dart, perfetto`, dos secciones `assets/…`): grupos, nombres con «, », recuentos ES/EN, plegados, orden. Con el archivo real: nº de grupos y suma de avisos = recuento independiente (partir por 80 guiones). | `licenses.test.mjs` (describe «CA-027-01») |
| CA-027-02 | (a) pares (cabecera, texto) del DOM = los del archivo, como multiconjunto; (b) un texto con blancos al principio y al final, comillas y, literalmente, `</pre>`, `<pre lang="x">`, `</details>`, `<script>` y `&lt;` sale entero, y el número de `<pre>`, `<details>` y `<script>` del HTML no cambia; la ida y vuelta de la construcción falla si se manipula el analizador; (c) recorrer los grupos en orden y reinsertar cabeceras, separadores y marcadores reconstruye el cuerpo desde `BEGIN NOTICES`. Con el archivo real y con el de prueba. Casos que fallan: un analizador que pierde, duplica o cambia un carácter (se simula manipulando el HTML). | `licenses.test.mjs` |
| CA-027-03 | El primer `<pre>` del bloque es el preámbulo, antes del primer `<details>`, sin plegar, igual al texto anterior a `BEGIN NOTICES`. | `licenses.test.mjs` |
| CA-027-04 | Un único `<script src="/lang.js">`, ningún `style=`, `landing/vercel.json` y `CONTENT_CSP` sin cambios (aserción explícita), lista de archivos de `dist/` igual que antes; `[DATE]` en el texto de un aviso no cuenta como hueco y en el nombre de un grupo sí; un nombre `plausible` hace fallar `check.mjs`; una ruta `/Users/…`, `/home/…` o `C:\Users\…` o un carácter de dirección en un aviso hacen fallar la construcción (ver Q-P-1); `lang.js` no toca el atributo `open` al cambiar de idioma (en `node:vm`, con un `<details>` falso). | `licenses.test.mjs`, `security.test.mjs`, `lang.test.mjs` |
| CA-027-05 | Un caso por estructura: `BEGIN` sin `END`, `END` sin `BEGIN`, anidada, sección repetida, sin avisos, otro marcador en el preámbulo, `ENTRIES` sin cerrar o anidado, una segunda pareja `NOTICES`, cabecera vacía, cabecera con espacios o con un carácter de formato (U+200B), aviso sin texto, cabecera que reaparece, texto fuera de una parte (tras `END NOTICES`, entre secciones, tras la última); cada uno con el mensaje (qué y línea). Una línea de 79 u 81 guiones dentro de un aviso y una de 80 dentro de una sección son texto. | `licenses.test.mjs` (describe «CA-027-05») |
| CA-027-06 | Región con nombre (`aria-labelledby="notices"`), enlace a `#notices-end` antes del primer grupo y destino (el enlace al `.txt`) dentro de la sección tras el último; textos bilingües de los enlaces en un solo `<span>`; `<summary>` en cada grupo; los dos recuentos con `lang` y `data-l` y los paréntesis fuera; `lang.js` no cambia de idioma con `#notices-end`; reglas de `site.css` (44 × 44 del `summary`, anillo de foco de `summary` y del destino, colores forzados, sin animación); `check.mjs` falla con un caso por regla. Lo que dice el lector y el teclado real: C-027-1. | `a11y.test.mjs`, `licenses.test.mjs` |
| CA-027-07 | `dist/third-party-notices.txt` igual byte a byte que `landing/third-party-notices.txt` (también con `\r\n`); el HTML de `/licenses` **fuera** de la `<section aria-labelledby="notices">` igual a un fragmento de referencia sacado de la construcción de `main` **antes** de esta spec (`test/fixtures/027/licenses-outside-notices.html`); el texto de un aviso sale una sola vez; `#notices` existe. | `licenses.test.mjs` |
| CA-027-08 | Con el archivo real: tamaño de `licenses/index.html` ≤ bytes UTF-8 del texto publicado (preámbulo + textos de avisos + textos de secciones, sin escapar) + 250 KB; recursos iguales que antes. Abrir `icu` en < 1 s: C-027-1. | `licenses.test.mjs` |
| CA-027-09 | Las tres claves en ES y EN con los textos de §7; los tests nuevos o cambiados citan su CA. Documentación: cierre. | `build.test.mjs` / `licenses.test.mjs`; cierre |

**C-027-1 (casilla del propietario y del coordinador, como en la 026):** Chrome (y Firefox si está a mano) de escritorio y del emulador de Android: teclado (Tab hasta un grupo, Intro y Espacio; el enlace de saltar, el foco visible al llegar y que el siguiente Tab vaya al pie; Mayúsculas+Tab hacia arriba con un grupo grande abierto y cerrar `icu` estando muy abajo, con el foco visible bajo la cabecera); zoom 200 % y 400 % a 320 px y espaciado de texto aumentado; colores forzados (marcador, líneas y anillo); sin JavaScript (los dos recuentos y los enlaces bilingües sin desbordarse); abrir `icu` en < 1 s en el emulador. Safari con VoiceOver (el marcador y el estado). TalkBack (el destino del salto se anuncia; nombre, un recuento y estado; con un grupo abierto se llega a su texto). Se anota en `specs/027-licencias-por-paquete/navegadores.md`.

## 6. Seguridad, accesibilidad y rendimiento

- **Seguridad (P4, checklist de la web):** nada nuevo que se cargue; sin `<script>` ni `style=`; CSP sin cambios; todo el texto pasa por `esc`. El archivo de avisos sigue siendo de entrada **no confiable** para el HTML (por eso se escapa) y el analizador falla cerrado. No aplica a la app.
- **Accesibilidad (P6):** desplegables nativos (teclado y estado expandido los da el navegador), enlace de saltar nativo, objetivos de 44, foco visible bajo la cabecera fija (`scroll-padding-top` ya existe), recuento en un solo idioma con JavaScript, sin movimiento, reflujo con `pre-wrap`. `a11y-reviewer` sobre el plan y al cerrar.
- **Rendimiento:** la página baja de ~1,57 MB a ~1,6 MB como mucho (se añaden ~80–100 KB de marcado); con los grupos plegados, el navegador no pinta el texto de los avisos hasta abrirlos. Abrir `icu` (552 avisos, el grupo mayor) se mide en C-027-1. Construcción: un recorrido lineal del archivo (35 000 líneas), sin coste apreciable.

## 7. Riesgos y alternativas

- **Q-P-1 [Hecho, resuelta por el propietario el 2026-11-17 con la recomendación; CA-027-04 enmendado]** CA-027-04 dice que «un `[DATE]` o una ruta de una carpeta personal en el texto de un aviso hacen fallar igual». Pero hoy un `[DATE]` dentro de un aviso **no** falla, a propósito (`findGaps` quita los `<pre>`: una licencia real puede llevar `[DATE]`; test de la 023), y la ruta personal solo la vigila un test sobre el archivo del repositorio, no la construcción que hace Vercel. **Recomendación (con la revisión de seguridad):** separar los dos casos y **enmendar CA-027-04**: (a) un `[DATE]` en el **texto** de un aviso sigue **sin** contar como hueco (como en la 023), y en el **nombre** de un grupo sí cuenta; (b) una ruta personal o un carácter de control o de dirección en **cualquier parte** del archivo **hace fallar la construcción** (§1.1), además del test de la 023. Que un `[DATE]` en un aviso hiciera fallar rompería la construcción con licencias reales y contradiría la 023.
- **Destino del salto (decidido en el plan):** un `<div tabindex="-1">` vacío lo saltan TalkBack y VoiceOver (revisión de accesibilidad). Se usa el enlace al `.txt` (§1.2). La alternativa, un texto «Fin de la lista de avisos», pediría una clave nueva y enmendar §7 de la spec.
- **Marcador nativo de `<details>`:** en Safari el marcador de `summary` se pinta con `::-webkit-details-marker` y puede desaparecer si `summary` deja de ser `list-item`; por eso no se toca su `display`. Se verifica en C-027-1.
- **«Buscar en la página»** en grupos plegados (CL-027-7): Chrome abre el grupo de la coincidencia; Safari y Firefox pueden no hacerlo. Aceptado en la spec; el archivo de texto sigue a mano.
- **Alternativa descartada:** un solo `<pre>` por grupo con los avisos unidos por una línea: rompería CA-027-02 (b) (el texto del DOM no sería el de cada aviso) y la separación visual pedida.
