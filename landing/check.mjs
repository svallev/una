// Comprobaciones de la web construida (spec 023): CA-023-04 (la política publicada es la del
// documento), CA-023-13 (páginas, idiomas), CA-023-14 (sin terceros ni rastreo, cabeceras),
// CA-023-15 (tokens, contraste, estructura, foco) y CA-023-16 (el bloque de avisos de terceros); el programa de
// idioma de las cuatro páginas (spec 026, CA-026-13 y 15: un único `<script src="/lang.js">`, lo que el programa no
// puede usar, su tamaño y la CSP con Trusted Types); y, con su propio juego de reglas (`checkHome`), la página de
// inicio de la spec 025 (CA-025-12). Falla cerrada: lo que no entiende es un error.
//
//   node landing/check.mjs [--dist <carpeta>]      (después de `node landing/build.mjs`)
//
// Solo módulos de Node. `checkSite` (las cuatro páginas, su programa de idioma y `vercel.json`) y `checkHome` (la
// de inicio) devuelven la lista de errores (vacía si todo está bien) para poder probar cada regla con un caso
// que falla (`landing/test`).
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";
import {
  BuildError,
  DOWNLOAD_HREF,
  FONT_DIRS,
  FOOTER_LINKS,
  NOTICES_FILE,
  FONT_FILES,
  LANG_FILE,
  LANG_SCRIPT,
  defaultPaths,
  kebab,
  loadStrings,
  policyFragments,
  readIdentity,
  renderSite,
} from "./build.mjs";

/**
 * Las páginas sin JavaScript que tiene que haber: las tres webs de la app y la de error. La de inicio la
 * construye Vite (spec 025) y no pasa estas reglas: tiene las suyas, en `checkHome`.
 */
export const REQUIRED_PAGES = ["privacy/index.html", "licenses/index.html", "help/index.html", "404.html"];
export const HOME_PAGE = "index.html";

/** La página que lleva, tras las dos mitades, el bloque de avisos de terceros (CA-023-16). */
const NOTICES_PAGE = "licenses/index.html";

// ─── HTML ────────────────────────────────────────────────────────────────────────────────────────

const TAG = /<!--[\s\S]*?-->|<(\/?)([A-Za-z][A-Za-z0-9-]*)((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+))?)*)\s*\/?>/g;

function parseAttrs(text) {
  const attrs = {};
  for (const m of text.matchAll(/([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g)) {
    attrs[m[1].toLowerCase()] = m[2] ?? m[3] ?? m[4] ?? "";
  }
  return attrs;
}

/** Las etiquetas de [html] en orden, con su posición. */
function tags(html) {
  const out = [];
  for (const m of html.matchAll(TAG)) {
    if (m[0].startsWith("<!--")) continue;
    out.push({
      name: m[2].toLowerCase(),
      closing: m[1] === "/",
      attrs: parseAttrs(m[3] ?? ""),
      start: m.index,
      end: m.index + m[0].length,
    });
  }
  return out;
}

const count = (list, name) => list.filter((t) => t.name === name && !t.closing).length;

/** Un origen propio: una ruta absoluta del sitio (no `//otro`) o relativa, sin protocolo. */
const isLocal = (url) => !/^[A-Za-z][A-Za-z0-9+.-]*:/.test(url) && !url.startsWith("//");

const MEDIA = ["img", "picture", "video", "audio", "source", "track", "canvas", "svg", "image", "use"];
const FRAMES = ["iframe", "frame", "frameset", "object", "embed", "applet"];
const FORMS = ["form", "input", "button", "textarea", "select"];
const ANALYTICS = [/_vercel\//i, /vercel-insights/i, /speed-insights/i, /googletagmanager/i, /google-analytics/i, /plausible/i, /matomo/i, /gtag\(/i];

function checkPage(file, html, meta, errors) {
  const t = tags(html);
  const fail = (msg) => errors.push(`${file}: ${msg}`);

  // Lo mínimo de la página.
  if (!/<html\s[^>]*\blang="[a-z]{2,3}(-[A-Za-z0-9]+)?"/.test(html)) fail("el <html> no lleva lang");
  const viewport = t.find((x) => x.name === "meta" && x.attrs.name === "viewport");
  if (!viewport) fail("falta <meta name=\"viewport\">");
  else {
    const c = viewport.attrs.content ?? "";
    if (!/width=device-width/.test(c)) fail(`el viewport no es width=device-width (${c})`);
    if (/user-scalable|maximum-scale|minimum-scale/i.test(c)) fail(`el viewport limita el zoom (${c}): 1.4.4`);
  }
  const title = /<title>([^<]*)<\/title>/.exec(html);
  if (!title || !title[1].trim()) fail("falta el <title>");
  else if (meta && title[1] !== escapeText(meta.title)) fail(`el <title> no es el esperado («${title[1]}»)`);
  for (const [name, label] of [["header", "<header>"], ["main", "<main>"], ["footer", "<footer>"]]) {
    const n = count(t, name);
    if (n !== 1) fail(`tiene ${n} ${label} (tiene que haber uno)`);
  }

  // Solo el programa de idioma (spec 026), sin estilos en línea, sin recursos de otro origen, sin formularios ni
  // medios.
  checkScript(html, t, fail);
  for (const x of t) {
    if (x.closing) continue;
    for (const attr of Object.keys(x.attrs)) {
      if (/^on/.test(attr)) fail(`<${x.name}> lleva el manejador ${attr} (la CSP lo bloquearía: los programas, solo por src)`);
      if (attr === "style") fail(`<${x.name}> lleva style en línea (la CSP lo bloquearía)`);
    }
    if (x.name === "script") continue;
    else if (x.name === "style") fail("tiene un <style> en línea (la CSP lo bloquearía)");
    else if (FRAMES.includes(x.name)) fail(`tiene un <${x.name}> (nada incrustado)`);
    else if (FORMS.includes(x.name)) fail(`tiene un <${x.name}> (la web no tiene formularios)`);
    else if (MEDIA.includes(x.name) && x.name !== "svg") fail(`tiene un <${x.name}> (la web no lleva imágenes ni medios)`);
    else if (x.name === "base") fail("tiene un <base>");
    else if (x.name === "meta" && "http-equiv" in x.attrs) fail("tiene un <meta http-equiv>");
    else if (x.name === "link") {
      const href = x.attrs.href ?? "";
      if (x.attrs.rel !== "stylesheet") fail(`<link rel="${x.attrs.rel ?? ""}"> no admitido (solo hojas de estilo)`);
      if (!href || !isLocal(href)) fail(`<link> a otro origen («${href}»): la web no usa recursos de terceros`);
    } else if (x.name === "a") {
      const href = x.attrs.href ?? "";
      if (/^\s*(javascript|data|vbscript):/i.test(href)) fail(`un enlace con ${href.split(":")[0]}:`);
    }
  }
  // El bloque de avisos de terceros (un `<pre>` con los textos de las licencias) no cuenta: una licencia
  // puede nombrar cualquier cosa.
  const scanned = html.replace(/<pre\b[^>]*>[\s\S]*?<\/pre>/g, " ");
  for (const re of ANALYTICS) if (re.test(scanned)) fail(`rastro de analítica (${re})`);

  // Estructura: un <h1> y niveles sin saltos.
  const headings = t.filter((x) => /^h[1-6]$/.test(x.name) && !x.closing).map((x) => ({ ...x, level: Number(x.name[1]) }));
  const h1s = headings.filter((h) => h.level === 1);
  if (h1s.length !== 1) fail(`tiene ${h1s.length} <h1> (tiene que haber uno)`);
  let prev = 0;
  for (const h of headings) {
    if (h.level > prev + 1) fail(`la estructura de encabezados salta del nivel ${prev} al ${h.level}`);
    prev = h.level;
  }
  if (h1s.length === 1 && meta) {
    const close = t.find((x) => x.closing && x.name === "h1");
    const inner = close ? html.slice(h1s[0].end, close.start) : "";
    if (inner !== meta.h1) fail(`el título (<h1>) no es el esperado, el de las ARB y la identidad («${inner}» en lugar de «${meta.h1}»)`);
  }

  // Los dos idiomas: primero el español, cada uno con su lang y el enlace al otro.
  const sections = t.filter((x) => x.name === "section" && !x.closing);
  const withNotices = file === NOTICES_PAGE;
  const expected = withNotices ? 4 : 2;
  if (sections.length !== expected) {
    fail(
      withNotices
        ? `tiene ${sections.length} <section> (las dos mitades, español e inglés, el código de esta web y el bloque de avisos)`
        : `tiene ${sections.length} <section> (las dos mitades, español e inglés)`,
    );
    return;
  }
  const [es, en] = sections;
  if (es.attrs.lang !== "es") fail('la primera mitad (el español va primero) no está marcada con lang="es"');
  if (en.attrs.lang !== "en") fail('la segunda mitad no está marcada con lang="en"');
  for (const [half, lang] of [[es, "es"], [en, "en"]]) {
    if (half.attrs["data-l"] !== lang || !hasClass(half, "half")) fail(`la mitad «${lang}» tiene que ser <section class="half" data-l="${lang}"> (CA-026-09)`);
  }
  if (es.attrs["aria-labelledby"] !== "es" || en.attrs["aria-labelledby"] !== "en") {
    fail("las mitades tienen que llevar aria-labelledby=\"es\" y \"en\"");
  }
  const closes = t.filter((x) => x.name === "section" && x.closing);
  const range = (open, i) => [open.end, closes[i]?.start ?? html.length];
  const [esFrom, esTo] = range(es, 0);
  const [enFrom, enTo] = range(en, 1);
  for (const [id, from, to] of [["es", esFrom, esTo], ["en", enFrom, enTo]]) {
    const target = t.find((x) => x.start >= from && x.end <= to && x.name === "h2" && x.attrs.id === id);
    if (!target) fail(`la mitad «${id}» no empieza por un <h2 id="${id}"> (destino del salto de idioma)`);
  }
  checkLayout(file, html, t, meta, { es: [esFrom, esTo], en: [enFrom, enTo] }, fail);
  checkToc(file, t, { es: [esFrom, esTo], en: [enFrom, enTo] }, fail);
  if (withNotices) {
    checkWebCodeBlock(sections[2], closes[2], t, html, fail);
    checkNoticesBlock(sections[3], closes[3], t, html, fail);
  }
  const levels = (from, to) =>
    headings.filter((h) => h.start >= from && h.end <= to).map((h) => h.level).join(",");
  if (levels(esFrom, esTo) !== levels(enFrom, enTo)) {
    fail(`los encabezados de la mitad inglesa (${levels(enFrom, enTo)}) no están al mismo nivel que los de la española (${levels(esFrom, esTo)})`);
  }
}

const hasClass = (x, name) => (x.attrs.class ?? "").split(/\s+/).includes(name);

/** La etiqueta que cierra [open] (la primera del mismo nombre que la equilibra), o `undefined`. */
function closeOf(t, open) {
  let depth = 0;
  for (const x of t) {
    if (x.start < open.end || x.name !== open.name) continue;
    if (!x.closing) depth += 1;
    else if (depth === 0) return x;
    else depth -= 1;
  }
  return undefined;
}

/** Las etiquetas de apertura entre [open] y su cierre. */
function inside(t, open) {
  const close = closeOf(t, open);
  const to = close?.start ?? Infinity;
  return t.filter((x) => !x.closing && x.start >= open.end && x.end <= to);
}

/** Lo único que carga cada página, en este orden (CA-026-15): las dos hojas y el programa de idioma. */
const PAGE_RESOURCES = ["/tokens.css", "/site.css", LANG_SCRIPT];

/**
 * El programa de idioma en la página (spec 026, CA-026-08 y 13; plan §6.1): un único `<script src="/lang.js">`,
 * clásico y síncrono (sin `type`, `async`, `defer`, `nomodule` ni ningún otro atributo), vacío, en el `<head>`
 * después de las hojas de estilo; y la página no carga nada más que esas hojas y ese programa.
 */
function checkScript(html, t, fail) {
  const open = t.filter((x) => !x.closing);
  const scripts = open.filter((x) => x.name === "script");
  if (scripts.length !== 1) fail(`tiene ${scripts.length} <script> (tiene que haber uno: <script src="${LANG_SCRIPT}">, CA-026-13)`);
  const headEnd = t.find((x) => x.closing && x.name === "head");
  const sheets = open.filter((x) => x.name === "link");
  for (const s of scripts) {
    const close = t.find((x) => x.closing && x.name === "script" && x.start >= s.end);
    if (!close || html.slice(s.end, close.start) !== "") fail("un <script> con código escrito dentro de la página (el programa, solo por src)");
    const src = s.attrs.src;
    if (src === undefined) fail("un <script> sin src (el programa, solo por src)");
    else if (src !== LANG_SCRIPT) fail(`un <script> que no carga ${LANG_SCRIPT} («${src}»): solo el programa de idioma, por su ruta absoluta`);
    const extra = Object.keys(s.attrs).filter((a) => a !== "src");
    if (extra.length > 0) fail(`un <script> con el atributo ${extra.join(", ")} (clásico y síncrono: solo src, CA-026-08)`);
    if (!headEnd || s.start > headEnd.start) fail("el <script> tiene que ir en el <head> (CA-026-08)");
    if (sheets.some((l) => l.start > s.start)) fail("el <script> tiene que ir después de las hojas de estilo (CA-026-08)");
  }
  const loaded = [];
  for (const x of open) {
    for (const [attr, value] of Object.entries(x.attrs)) {
      if (RESOURCE_ATTRS.includes(attr) || (x.name === "link" && attr === "href")) loaded.push(value);
    }
  }
  if (loaded.join(" ") !== PAGE_RESOURCES.join(" ")) {
    fail(`carga ${loaded.join(", ") || "nada"} (recursos de cada página: ${PAGE_RESOURCES.join(", ")}, en ese orden, y nada más, CA-026-15)`);
  }
}

/**
 * Las piezas de la página de la spec 026 (CA-026-01, 05 y 09; plan §2.1): cabecera con el logotipo y «Descargar»
 * (con su único `<svg>`), el selector de idioma, un solo «← Volver al inicio», el título, las mitades y el pie de la
 * landing con la página actual marcada; y las marcas `data-l` de lo que va en los dos idiomas. [halves] da el
 * rango de cada mitad; [meta], los títulos que le tocan.
 */
function checkLayout(file, html, t, meta, halves, fail) {
  const open = t.filter((x) => !x.closing);
  const isError = file === "404.html";
  const htmlTag = open.find((x) => x.name === "html");
  for (const lang of ["es", "en"]) {
    const title = htmlTag?.attrs[`data-title-${lang}`];
    const want = meta?.[lang === "es" ? "titleEs" : "titleEn"];
    if (!title) fail(`el <html> no lleva data-title-${lang} (el título de la pestaña en ese idioma)`);
    else if (want !== undefined && title !== escapeText(want)) fail(`data-title-${lang} no es el esperado («${title}»)`);
  }

  // Cabecera: el logotipo a la landing y «Descargar» al cierre de la landing (CA-026-02 y 16), nada más.
  const header = open.find((x) => x.name === "header");
  const main = open.find((x) => x.name === "main");
  const footer = open.find((x) => x.name === "footer");
  const links = header ? inside(t, header).filter((x) => x.name === "a") : [];
  const [logo, download] = links;
  if (links.length !== 2) fail(`la cabecera tiene ${links.length} enlaces (tienen que ser el logotipo y «Descargar»)`);
  if (!logo || !hasClass(logo, "logo") || logo.attrs.href !== "/") fail('la cabecera no empieza por el logotipo (<a class="logo" href="/">)');
  if (!download || download.attrs.href !== DOWNLOAD_HREF) fail(`«Descargar» no lleva a la escena de cierre de la landing (${DOWNLOAD_HREF}, CA-026-16)`);

  // El único <svg>: el icono de «Descargar», decorativo y solo con trazos.
  const svgs = open.filter((x) => x.name === "svg");
  if (svgs.length !== 1) fail(`tiene ${svgs.length} <svg> (solo el icono de «Descargar»)`);
  for (const svg of svgs) {
    if (!download || !inside(t, download).includes(svg)) fail("el <svg> no está dentro de «Descargar»");
    if (svg.attrs["aria-hidden"] !== "true") fail('el <svg> de «Descargar» no lleva aria-hidden="true"');
    if (svg.attrs.focusable !== "false") fail('el <svg> de «Descargar» no lleva focusable="false"');
    for (const x of inside(t, svg)) {
      if (x.name !== "path" || Object.keys(x.attrs).join() !== "d") fail(`el <svg> de «Descargar» lleva <${x.name} ${Object.keys(x.attrs).join(" ")}> (solo <path d>)`);
    }
  }
  for (const x of open) if (x.name === "path" && !svgs.some((svg) => inside(t, svg).includes(x))) fail("un <path> fuera del <svg>");

  // El selector: un grupo con nombre y dos enlaces a las mitades (CA-026-07 y 09).
  const langs = open.filter((x) => x.name === "div" && hasClass(x, "langs"));
  const selector = langs[0];
  if (langs.length !== 1) fail(`tiene ${langs.length} selectores de idioma (<div class="langs">; tiene que haber uno)`);
  else {
    if (selector.attrs.role !== "group" || !selector.attrs["aria-labelledby"]) fail('el selector de idioma no es un grupo con nombre (role="group" y aria-labelledby)');
    const options = inside(t, selector).filter((x) => x.name === "a");
    const got = options.map((a) => `${a.attrs.href}|${a.attrs.hreflang}|${a.attrs.lang}`).join(", ");
    if (got !== "#es|es|es, #en|en|en") fail(`el selector tiene que llevar ES y EN, en ese orden, a #es y #en con su hreflang y su lang (lleva ${got || "nada"})`);
  }

  // «← Volver al inicio»: uno solo por página. En la de error, uno en cada mitad (su texto) y ninguno fuera.
  const inHalf = (x, lang) => x.start >= halves[lang][0] && x.end <= halves[lang][1];
  const homeLinks = open.filter((x) => x.name === "a" && x.attrs.href === "/" && !hasClass(x, "logo"));
  const outside = homeLinks.filter((x) => !inHalf(x, "es") && !inHalf(x, "en"));
  for (const lang of ["es", "en"]) {
    const n = homeLinks.filter((x) => inHalf(x, lang)).length;
    if (n !== (isError ? 1 : 0)) fail(`la mitad «${lang}» tiene ${n} enlaces «Volver al inicio» (${isError ? "la página de error lleva uno en su texto" : "va uno solo, encima del título"})`);
  }
  if (outside.length !== (isError ? 0 : 1)) fail(`tiene ${outside.length} «← Volver al inicio» encima del título (${isError ? "la página de error no lo lleva: ya va en su texto" : "tiene que haber uno"})`);

  // El orden de arriba abajo (CA-026-01).
  const h1 = open.find((x) => x.name === "h1");
  const firstHalf = open.find((x) => x.name === "section");
  const order = [
    ["la cabecera", header],
    ["el selector de idioma", selector],
    ...(isError ? [] : [["«← Volver al inicio»", outside[0]]]),
    ["el título", h1],
    ["las mitades", firstHalf],
    ["el pie", footer],
  ];
  for (let i = 1; i < order.length; i++) {
    const [a, x] = order[i - 1];
    const [b, y] = order[i];
    if (x && y && x.start > y.start) fail(`${a} tiene que ir antes que ${b} (CA-026-01)`);
  }
  if (main && selector && !inside(t, main).includes(selector)) fail("el selector de idioma tiene que ir dentro de <main>");

  // El pie de la landing: Ayuda, Privacidad y Licencias, en ese orden, y la página actual marcada.
  const navs = footer ? inside(t, footer).filter((x) => x.name === "nav") : [];
  if (navs.length !== 1) fail(`el pie tiene ${navs.length} <nav> (tiene que haber uno, con Ayuda, Privacidad y Licencias)`);
  else {
    const nav = navs[0];
    if (!nav.attrs["aria-labelledby"]) fail("la navegación del pie no tiene nombre (aria-labelledby)");
    const navLinks = inside(t, nav).filter((x) => x.name === "a");
    const hrefs = navLinks.map((a) => a.attrs.href).join(", ");
    const want = FOOTER_LINKS.map(([, href]) => href).join(", ");
    if (hrefs !== want) fail(`el pie tiene que enlazar ${want}, en ese orden (enlaza ${hrefs || "nada"})`);
    const current = FOOTER_LINKS.find(([, , page]) => page === file)?.[1];
    const marked = navLinks.filter((a) => a.attrs["aria-current"] === "page").map((a) => a.attrs.href);
    if (marked.join() !== (current ?? "")) fail(`el pie tiene que marcar con aria-current="page" ${current ? `solo ${current}` : "ningún enlace (la página de error no está en el pie)"} (marca ${marked.join(", ") || "ninguno"})`);
  }
  for (const x of open) {
    if ("aria-current" in x.attrs && !(x.name === "a" && navs.length === 1 && inside(t, navs[0]).includes(x) && x.attrs["aria-current"] === "page")) {
      fail(`<${x.name} aria-current="${x.attrs["aria-current"]}"> fuera de la navegación del pie`);
    }
  }

  // Lo que va en los dos idiomas (CA-026-09): cada parte con su lang y su pareja; los separadores, solo texto.
  const marks = open.filter((x) => "data-l" in x.attrs);
  for (const x of marks) {
    const l = x.attrs["data-l"];
    if (l === "es" || l === "en") {
      if (x.attrs.lang !== l) fail(`<${x.name} data-l="${l}"> sin lang="${l}"`);
    } else if (l === "sep") {
      if ("lang" in x.attrs) fail('un separador (data-l="sep") con lang');
      if (inside(t, x).length > 0) fail('un separador (data-l="sep") con etiquetas dentro (solo texto)');
    } else fail(`data-l="${l}" no admitido (solo es, en y sep)`);
  }
  const n = (l) => marks.filter((x) => x.attrs["data-l"] === l).length;
  if (n("es") !== n("en")) fail(`hay ${n("es")} piezas en español (data-l="es") y ${n("en")} en inglés: cada una tiene que tener su pareja`);

  // Cada aria-labelledby, a un id que existe una sola vez.
  const ids = open.map((x) => x.attrs.id).filter(Boolean);
  for (const id of new Set(ids)) if (ids.filter((i) => i === id).length > 1) fail(`el id «${id}» está repetido`);
  for (const x of open) {
    const ref = x.attrs["aria-labelledby"];
    if (ref && !ids.includes(ref)) fail(`<${x.name} aria-labelledby="${ref}"> apunta a un id que no existe`);
  }
}

/** Las páginas con índice (CA-026-04) y, de ellas, la que lleva la fecha de «última actualización». */
const TOC_PAGES = ["privacy/index.html", "help/index.html"];
const DATED_PAGE = "privacy/index.html";

/**
 * El índice, las anclas y la fecha (spec 026, CA-026-04; plan §2.2): en la política y la Ayuda, cada mitad lleva
 * tras su `<h2>` (y, en la política, tras la fecha) un único `<nav class="toc">` con nombre propio y un enlace por
 * sección (`<h3 id="es-…" tabindex="-1">`), en orden. En licencias y la de error, ni índice ni fecha. Fuera de los
 * `<h2>` de las mitades y los `<h3>`, ningún `tabindex`.
 */
function checkToc(file, t, halves, fail) {
  const open = t.filter((x) => !x.closing);
  const withToc = TOC_PAGES.includes(file);
  const dated = file === DATED_PAGE;
  for (const x of open) {
    if (!("tabindex" in x.attrs)) continue;
    const half = x.name === "h2" && (x.attrs.id === "es" || x.attrs.id === "en");
    if (x.attrs.tabindex !== "-1" || !(half || x.name === "h3")) {
      fail(`<${x.name} tabindex="${x.attrs.tabindex}"> (solo los <h2> de las mitades y las secciones <h3> llevan tabindex="-1")`);
    }
  }
  for (const lang of ["es", "en"]) {
    const [from, to] = halves[lang];
    const here = open.filter((x) => x.start >= from && x.end <= to);
    const navs = here.filter((x) => x.name === "nav" && hasClass(x, "toc"));
    const dates = here.filter((x) => x.name === "p" && hasClass(x, "date"));
    const h2 = here.find((x) => x.name === "h2" && x.attrs.id === lang);
    const h3s = here.filter((x) => x.name === "h3");
    if (!withToc) {
      if (navs.length > 0) fail(`la mitad «${lang}» lleva un índice (solo la política y la Ayuda, CA-026-04)`);
      if (dates.length > 0) fail(`la mitad «${lang}» lleva la fecha de «última actualización» (solo la política)`);
      continue;
    }
    for (const h of h3s) {
      if (!h.attrs.id?.startsWith(`${lang}-`)) fail(`una sección <h3> de la mitad «${lang}» sin un ancla con el prefijo «${lang}-» (${h.attrs.id ?? "sin id"})`);
      if (h.attrs.tabindex !== "-1") fail(`la sección ${h.attrs.id ?? "sin id"} no lleva tabindex="-1" (el índice le pasa el foco)`);
    }
    if (navs.length !== 1) {
      fail(`la mitad «${lang}» tiene ${navs.length} índices (<nav class="toc">; tiene que haber uno)`);
      continue;
    }
    const nav = navs[0];
    const name = `${lang}-toc`;
    const label = inside(t, nav).find((x) => x.name === "p" && x.attrs.id === name && hasClass(x, "toc__name"));
    if (nav.attrs["aria-labelledby"] !== name || !label) fail(`el índice de la mitad «${lang}» no tiene su nombre (aria-labelledby="${name}" y <p id="${name}" class="toc__name">)`);
    const hrefs = inside(t, nav).filter((x) => x.name === "a").map((a) => a.attrs.href);
    const want = h3s.map((h) => `#${h.attrs.id}`);
    if (hrefs.join(" ") !== want.join(" ")) fail(`el índice de la mitad «${lang}» no lleva un enlace por sección, en orden (lleva ${hrefs.join(" ") || "nada"}; las secciones son ${want.join(" ") || "ninguna"})`);
    if (h2 && nav.start < h2.start) fail(`el índice de la mitad «${lang}» va antes del título`);
    if (h3s[0] && nav.start > h3s[0].start) fail(`el índice de la mitad «${lang}» va después de la primera sección`);
    if (dated) {
      if (dates.length !== 1) fail(`la mitad «${lang}» tiene ${dates.length} fechas de «última actualización» (tiene que haber una, bajo el título)`);
      else if ((h2 && dates[0].start < h2.start) || dates[0].start > nav.start) fail(`la fecha de la mitad «${lang}» tiene que ir bajo el título y antes del índice`);
    } else if (dates.length > 0) fail(`la mitad «${lang}» lleva la fecha de «última actualización» (solo la política)`);
  }
}

/** La página que sirve cada ruta del sitio (para los enlaces con ancla a otra página). */
const PAGE_OF_PATH = { "/privacy": "privacy/index.html", "/help": "help/index.html", "/licenses": "licenses/index.html" };

/**
 * CA-026-04: cada enlace con ancla de las cuatro páginas (`#x` a la misma página o `/privacy#x` a otra) apunta a un
 * `id` que existe. `/#…` es de la página de inicio, que comprueba `checkHome`.
 */
function checkAnchors(pages, errors) {
  const ids = new Map();
  for (const [file, html] of pages) ids.set(file, new Set(tags(html).filter((x) => !x.closing && x.attrs.id).map((x) => x.attrs.id)));
  for (const [file, html] of pages) {
    for (const a of tags(html)) {
      if (a.closing || a.name !== "a") continue;
      const m = /^([^#]*)#(.*)$/.exec(a.attrs.href ?? "");
      if (!m || m[1] === "/") continue;
      const target = m[1] === "" ? file : PAGE_OF_PATH[m[1]];
      if (!target) errors.push(`${file}: el enlace ${a.attrs.href} lleva un ancla a una página que no es de la web`);
      else if (!ids.get(target)?.has(m[2])) errors.push(`${file}: el enlace ${a.attrs.href} apunta a un id que no existe${target === file ? "" : ` en ${target}`}`);
    }
  }
}

/**
 * El bloque del código de esta web (spec 025, CA-025-18): una tercera `<section aria-labelledby="web-code">`, tras
 * las dos mitades y antes de los avisos de la app, con su `<h2 id="web-code">` y el texto en un `<pre lang="en">`.
 */
function checkWebCodeBlock(open, close, t, html, fail) {
  if (open.attrs["aria-labelledby"] !== "web-code") fail('el bloque del código de esta web (la tercera <section>) tiene que llevar aria-labelledby="web-code"');
  const from = open.end;
  const to = close?.start ?? html.length;
  const inside = (x) => x.start >= from && x.end <= to && !x.closing;
  if (!t.some((x) => inside(x) && x.name === "h2" && x.attrs.id === "web-code")) {
    fail('el bloque del código de esta web no empieza por un <h2 id="web-code">');
  }
  if (!t.some((x) => inside(x) && x.name === "pre" && x.attrs.lang === "en")) {
    fail('el bloque del código de esta web no lleva el texto en un <pre lang="en">');
  }
}

/**
 * El bloque de avisos de terceros (CA-023-16): una tercera `<section lang="en" aria-labelledby="notices">`
 * después de las dos mitades, que empieza por su `<h2 id="notices">` y lleva el texto en un `<pre lang="en">`.
 */
function checkNoticesBlock(open, close, t, html, fail) {
  if (open.attrs.lang !== "en") fail('el bloque de avisos (la tercera <section>) no está marcado con lang="en"');
  if (open.attrs["aria-labelledby"] !== "notices") fail('el bloque de avisos tiene que llevar aria-labelledby="notices"');
  const from = open.end;
  const to = close?.start ?? html.length;
  const inside = (x) => x.start >= from && x.end <= to && !x.closing;
  if (!t.some((x) => inside(x) && x.name === "h2" && x.attrs.id === "notices")) {
    fail('el bloque de avisos no empieza por un <h2 id="notices">');
  }
  const pre = t.find((x) => inside(x) && x.name === "pre");
  if (!pre) fail("el bloque de avisos no lleva el texto en un <pre>");
  else if (pre.attrs.lang !== "en") fail('el bloque de avisos no lleva el texto en un <pre lang="en"> (CA-026-12)');
}

const escapeText = (s) =>
  s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");

// ─── La política publicada (CA-023-04) ───────────────────────────────────────────────────────────

function checkPolicy(paths, dist, name, errors) {
  const file = "privacy/index.html";
  const html = readFileSync(join(dist, file), "utf8");
  const strings = loadStrings(readFileSync(paths.strings, "utf8"));
  const expected = policyFragments(readFileSync(paths.policy, "utf8"), name, strings);
  for (const lang of ["es", "en"]) {
    const m = new RegExp(`<section class="half" lang="${lang}" data-l="${lang}" aria-labelledby="${lang}">\\n([\\s\\S]*?)\\n</section>`).exec(html);
    if (!m) {
      errors.push(`${file}: no está la mitad «${lang}» de la política`);
      continue;
    }
    if (m[1] !== expected[lang].html) {
      errors.push(`${file}: el texto publicado de la política (${lang}) no es el de docs/legal/privacy-policy.md`);
    }
  }
}

// ─── CSS ─────────────────────────────────────────────────────────────────────────────────────────

/**
 * Las reglas de una hoja: `{ selector, decls, media }` (`media`: la condición del `@media` que la contiene, o
 * `null`), las reglas @ (`{ name, cond, nested }`) y el texto sin comentarios. Un solo nivel de `@media`.
 */
function parseCss(text) {
  const clean = text.replace(/\/\*[\s\S]*?\*\//g, "");
  const rules = [];
  const atRules = [...clean.matchAll(/@([a-z-]+)/gi)].map((m) => `@${m[1].toLowerCase()}`);
  const blocks = [];
  const walk = (body, media) => {
    let i = 0;
    while (i < body.length) {
      const open = body.indexOf("{", i);
      if (open < 0) break;
      let depth = 1;
      let j = open + 1;
      for (; j < body.length && depth > 0; j++) {
        if (body[j] === "{") depth++;
        else if (body[j] === "}") depth--;
      }
      const prelude = body.slice(i, open).trim();
      const inner = body.slice(open + 1, j - 1);
      i = j;
      if (prelude.startsWith("@")) {
        const m = /^@([a-z-]+)\s*([\s\S]*)$/i.exec(prelude);
        blocks.push({ name: `@${m[1].toLowerCase()}`, cond: m[2].trim().replace(/\s+/g, " "), nested: media !== null });
        if (m[1].toLowerCase() === "media" && media === null) walk(inner, m[2].trim().replace(/\s+/g, " "));
        continue;
      }
      const decls = inner
        .split(";")
        .map((d) => d.trim())
        .filter(Boolean)
        .map((d) => {
          const k = d.indexOf(":");
          return { prop: d.slice(0, k).trim().toLowerCase(), value: d.slice(k + 1).trim() };
        });
      rules.push({ selector: prelude.replace(/\s+/g, " "), decls, media });
    }
  };
  walk(clean, null);
  return { rules, atRules, blocks, clean };
}

const NAMED_COLORS = new Set(
  "black white red green blue yellow orange purple pink gray grey brown cyan magenta lime navy teal maroon olive silver aqua fuchsia gold beige ivory khaki lavender salmon tomato violet turquoise indigo crimson coral azure".split(" "),
);

/** Por qué un valor es «suelto» (no sale de un token), o `null`. */
function looseValue(prop, value) {
  const v = value.replace(/var\(--[a-z0-9-]+\)/gi, " ");
  if (/#[0-9a-f]{3,8}\b/i.test(v)) return "color hexadecimal";
  if (/\b(rgb|rgba|hsl|hsla|hwb|lab|lch|oklab|oklch|color-mix|color)\s*\(/i.test(v)) return "función de color";
  if (/(?<![\w.])-?\d*\.?\d+(px|rem|em|ch|ex|cap|ic|lh|rlh|vw|vh|vi|vb|vmin|vmax|svw|svh|lvw|lvh|dvw|dvh|pt|pc|cm|mm|q|in|fr|deg|rad|turn|ms|s)\b/i.test(v)) {
    return "medida";
  }
  for (const m of v.matchAll(/(\d+(?:\.\d+)?)%/g)) if (m[1] !== "100") return "porcentaje";
  if (/color|^background|^border|^outline|^text-decoration|^fill$|^stroke$/.test(prop)) {
    for (const w of v.toLowerCase().split(/[^a-z-]+/)) if (NAMED_COLORS.has(w)) return "color con nombre";
  }
  if (/^(font-family|font-size|font-weight|letter-spacing|word-spacing)$/.test(prop)) {
    if (v.trim() && !/^(inherit|initial|unset|normal)$/i.test(v.trim())) return `valor propio en ${prop}`;
  }
  if (prop !== "line-height" && /(^|[\s,(])(-?\d*\.\d+|[1-9]\d*)(?=[\s,)]|$)/.test(v)) return "número";
  return null;
}

function luminance([r, g, b]) {
  const f = (c) => ((c /= 255) <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
const ratio = (a, b) => {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};
const hexRgb = (hex) => [0, 2, 4].map((i) => parseInt(hex.slice(1 + i, 3 + i), 16));

/** Los pares de texto y fondo de `docs/design/tokens.md` (tabla de contraste) que usa la web. */
const ALLOWED_PAIRS = new Set(["ink/paper", "ink/surface", "textMuted/paper", "textMuted/surface", "error/paper", "error/surface", "ink/dangerFill", "onInk/ink", "onInkMuted/ink"]);

/**
 * Las únicas condiciones de `@media` de `site.css` (spec 026, plan §2.4): las dos medidas sueltas que admite la
 * hoja son los umbrales de la landing (`max-height: 539.98px` de `mode.js` y `max-width: 520px` de su botón).
 */
const MEDIA_HEIGHT = "(max-height: 539.98px)";
const MEDIA_WIDTH = "(max-width: 520px)";
const MEDIA_FORCED = "(forced-colors: active)";
const ALLOWED_MEDIA = new Set([MEDIA_HEIGHT, MEDIA_WIDTH, MEDIA_FORCED]);

/** Los selectores que llevan los objetivos de 44 × 44 de CA-026-10. */
const TOUCH_TARGETS = [".logo", ".btn", ".langs a", ".back", ".toc a", ".end a"];
/** Las reglas de ocultar el otro idioma y los separadores (plan §2.4). */
const HIDE_SELECTORS = ['html[data-lang="es"] [data-l="en"]', 'html[data-lang="en"] [data-l="es"]', 'html[data-lang] [data-l="sep"]'];
/** Lo que oculta a la vista sin ocultar al lector (`.vh`, y el texto de «Descargar» a 520 px o menos). */
const VISUALLY_HIDDEN = { position: "absolute", overflow: "hidden", "clip-path": "circle(0)", "white-space": "nowrap" };

const selectorParts = (selector) => selector.split(",").map((s) => s.trim().replace(/\s+/g, " "));

function checkCss(file, text, { tokens, definedVars }, errors, { strict }) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  const { rules, atRules, blocks, clean } = parseCss(text);

  // Variables propias de la hoja: solo en `html` (la altura de la cabecera, plan §2.4) y con valores de tokens.
  const ownVars = new Set();
  if (strict) {
    for (const { selector, decls, media } of rules) {
      for (const { prop } of decls) {
        if (!prop.startsWith("--")) continue;
        if (selector === "html" && media === null) ownVars.add(prop);
        else fail(`«${selector}»: variable propia ${prop} fuera de «html» (solo la altura de la cabecera, en html)`);
      }
    }
  }
  // Las variables que usa tienen que existir.
  for (const m of clean.matchAll(/var\(\s*(--[a-z0-9-]+)/gi)) {
    if (!definedVars.has(m[1]) && !ownVars.has(m[1])) fail(`usa la variable ${m[1]}, que no está en tokens.css`);
  }
  // Recursos: ninguno de otro origen.
  for (const m of clean.matchAll(/url\(\s*(['"]?)([^)'"]*)\1\s*\)/gi)) {
    if (strict) fail(`url(${m[2]}): la hoja de estilo de la web no carga recursos`);
    else if (!isLocal(m[2])) fail(`url(${m[2]}): recurso de otro origen`);
  }
  if (/@import/i.test(clean)) fail("@import (la web no carga hojas de otro sitio)");
  if (!strict) return;

  for (const at of atRules) if (at !== "@import" && at !== "@media") fail(`regla ${at} no admitida (en site.css solo reglas simples con variables y tres @media)`);
  for (const b of blocks) {
    if (b.name !== "@media") continue;
    if (b.nested) fail(`@media ${b.cond} dentro de otro @media (no se admite)`);
    else if (!ALLOWED_MEDIA.has(b.cond)) fail(`@media ${b.cond} no admitido (solo ${[...ALLOWED_MEDIA].join(", ")})`);
  }

  const colorKeys = new Map(Object.keys(tokens.color).filter((k) => !k.startsWith("$")).map((k) => [kebab(k), k]));
  const focusRing = [];
  let underline = false;

  for (const { selector, decls, media } of rules) {
    const where = media ? `«${selector}» (@media ${media})` : `«${selector}»`;
    const parts = selectorParts(selector);
    const get = (p) => decls.find((d) => d.prop === p)?.value;
    for (const { prop, value } of decls) {
      // z-index: solo la cabecera fija, por encima de las mitades (que llevan position: relative).
      if (prop === "z-index") {
        if (selector !== ".top" || media !== null || value !== "1") fail(`${where}: «z-index: ${value}» (solo «.top» con z-index: 1)`);
        continue;
      }
      const loose = looseValue(prop, value);
      if (loose) fail(`valor suelto (${loose}) en ${where}: «${prop}: ${value}» (usa una variable de tokens.css)`);
      if (/^(transition|animation)/.test(prop)) fail(`${where}: «${prop}» (la web no tiene animaciones)`);
      if (prop === "scroll-behavior" && value !== "auto") fail(`${where}: scroll-behavior: ${value} (movimiento: tiene que ser auto)`);
      if (/^outline(-style|-width)?$/.test(prop) && /^(none|0|hidden)$/.test(value)) fail(`${where}: «${prop}: ${value}» oculta el foco (2.4.7)`);
      // Sin subrayado solo el logotipo, «Descargar» (como en la landing) y la página actual del pie (que lleva su
      // línea, CA-026-10).
      if (/^text-decoration(-line)?$/.test(prop) && /\bnone\b/.test(value)) {
        const allowed = media === null && parts.every((s) => s === ".logo" || s === ".btn" || s === '.end a[aria-current="page"]');
        if (!allowed) fail(`${where}: «${prop}: ${value}» quita el subrayado de los enlaces`);
      }
      if (prop === "height" && !/^(auto|100%|inherit)$/.test(value)) fail(`${where}: altura fija «height: ${value}» (1.4.12: usa min-height)`);
      if (prop === "width" && !/^(auto|100%|inherit|fit-content)$/.test(value)) fail(`${where}: ancho fijo «width: ${value}» (1.4.10: usa max-width)`);
      if (prop === "line-height" && !/^\d*\.?\d+$/.test(value)) fail(`${where}: interlineado fijo «line-height: ${value}» (1.4.12: sin unidades)`);
      if (/^overflow(-x)?$/.test(prop) && /\b(scroll|auto)\b/.test(value)) fail(`${where}: «${prop}: ${value}» obliga a un desplazamiento horizontal (1.4.10)`);
      if (prop === "position" && value === "sticky") fail(`${where}: position: sticky puede tapar el elemento con el foco (2.4.11)`);
      if (prop === "position" && value === "fixed" && (selector !== ".top" || media !== null)) {
        fail(`${where}: position: fixed puede tapar el elemento con el foco (2.4.11; solo la cabecera, «.top»)`);
      }
      if (prop === "font-size" && /^(html|:root)$/.test(selector)) fail(`${where}: font-size en html (hay que respetar el tamaño del texto del navegador)`);
      if (prop === "display" && value === "none" && parts.some((s) => /half__title|btn__label/.test(s))) {
        fail(`${where}: display: none quita el nombre al lector (se oculta solo a la vista, como .vh)`);
      }
    }

    // Pares de color.
    const fgDecl = get("color");
    const bgDecl = get("background-color") ?? get("background");
    if (fgDecl || bgDecl) {
      const key = (v) => {
        const m = v && /var\(--color-([a-z0-9-]+)\)/.exec(v);
        return m ? colorKeys.get(m[1]) : undefined;
      };
      const inheritsFg = fgDecl && /^(inherit|currentcolor)$/i.test(fgDecl);
      const fg = fgDecl ? key(fgDecl) : "ink";
      const bg = bgDecl ? key(bgDecl) : "paper";
      if (!inheritsFg && fg && bg) {
        const pair = `${fg}/${bg}`;
        const n = ratio(hexRgb(tokens.color[fg].$value), hexRgb(tokens.color[bg].$value));
        if (!ALLOWED_PAIRS.has(pair)) fail(`${where}: el par de colores ${pair} no está en la tabla de contraste de docs/design/tokens.md`);
        else if (n < 4.5) fail(`${where}: el par ${pair} tiene un contraste de ${n.toFixed(2)} (mínimo 4,5)`);
      }
    }

    if (media === null && parts.some((s) => s.endsWith(":focus-visible"))) {
      if (/var\(--border-width-focus\)/.test(get("outline") ?? "")) focusRing.push(...parts);
    }
    if (media === null && selector === "a" && /\bunderline\b/.test(get("text-decoration") ?? "")) underline = true;
  }

  /** El último valor de [prop] para el selector [part] (sin `@media`, o dentro de [media]), como en la cascada. */
  const valueOf = (part, prop, media = null) => {
    let found;
    for (const r of rules) {
      if (r.media !== media || !selectorParts(r.selector).includes(part)) continue;
      for (const d of r.decls) if (d.prop === prop) found = d.value;
    }
    return found;
  };
  const visuallyHidden = (part, media = null) => Object.entries(VISUALLY_HIDDEN).every(([p, v]) => valueOf(part, p, media) === v);

  if (focusRing.length === 0) fail("falta el anillo de foco (:focus-visible con outline de var(--border-width-focus)): 2.4.7");
  else if (!focusRing.includes("h3:focus-visible")) fail("falta h3:focus-visible con el anillo de foco (los <h3> reciben el foco desde el índice, CA-026-10)");
  if (!underline) fail("los enlaces (a) tienen que ir subrayados: text-decoration: underline");
  if (valueOf("pre", "white-space") !== "pre-wrap") fail("pre tiene que llevar white-space: pre-wrap (reflujo, 1.4.10)");
  else if (valueOf("pre", "overflow-wrap") !== "anywhere") fail("pre tiene que llevar overflow-wrap: anywhere (reflujo, 1.4.10)");
  if (valueOf(".block-link", "min-height") !== "var(--size-link-button)") {
    fail(".block-link tiene que llevar min-height: var(--size-link-button) (objetivo de 44, P6)");
  }

  // Ocultar el otro idioma (CA-026-06 y 08) y, con JavaScript, el titular de cada mitad solo a la vista (CA-026-10).
  if (!HIDE_SELECTORS.every((s) => valueOf(s, "display") === "none")) {
    fail(`faltan las reglas de ocultar el otro idioma: ${HIDE_SELECTORS.join(", ")} { display: none } (CA-026-08)`);
  }
  if (!visuallyHidden(".vh")) fail(`.vh tiene que ocultar solo a la vista (${Object.entries(VISUALLY_HIDDEN).map(([p, v]) => `${p}: ${v}`).join("; ")})`);
  if (!visuallyHidden("html[data-lang] .half__title")) fail("html[data-lang] .half__title tiene que ocultarse como .vh (el lector lo sigue teniendo, CA-026-10)");
  if (valueOf(".half", "position") !== "relative") fail(".half tiene que llevar position: relative (el salto a #es y #en deja la mitad a la vista)");

  // La cabecera fija (CA-026-02): una sola variable da su altura, el hueco del cuerpo y el scroll-padding-top.
  const top = (p, media) => valueOf(".top", p, media);
  if (top("position") !== "fixed") fail("la cabecera (.top) tiene que llevar position: fixed (CA-026-02)");
  if (top("background-color") !== "var(--color-paper)") fail("la cabecera (.top) tiene que ir sobre papel opaco: background-color: var(--color-paper)");
  if (top("white-space") !== "nowrap") fail("la cabecera (.top) tiene que llevar white-space: nowrap (no crece en dos líneas, 1.4.12)");
  const height = /^var\((--[a-z0-9-]+)\)$/.exec(top("min-height") ?? "")?.[1];
  if (!height) fail("la altura de la cabecera (.top) tiene que ser min-height: var(--…) (la misma variable que scroll-padding-top)");
  else {
    if (valueOf("html", "scroll-padding-top") !== `var(${height})`) fail(`html: scroll-padding-top tiene que usar la misma variable que la altura de la cabecera (var(${height}), 2.4.11)`);
    if (valueOf("body", "padding-top") !== `var(${height})`) fail(`body: padding-top tiene que usar la misma variable que la altura de la cabecera (var(${height}))`);
  }
  if (!blocks.some((b) => b.name === "@media" && b.cond === MEDIA_HEIGHT)) fail(`falta @media ${MEDIA_HEIGHT}: en ventanas bajas la cabecera no es fija (CA-026-02)`);
  else {
    if (top("position", MEDIA_HEIGHT) !== "static") fail(`@media ${MEDIA_HEIGHT}: la cabecera (.top) tiene que llevar position: static`);
    if (valueOf("html", "scroll-padding-top", MEDIA_HEIGHT) !== "0") fail(`@media ${MEDIA_HEIGHT}: html tiene que llevar scroll-padding-top: 0`);
    if (valueOf("body", "padding-top", MEDIA_HEIGHT) !== "0") fail(`@media ${MEDIA_HEIGHT}: body tiene que llevar padding-top: 0`);
  }
  // «Descargar» solo con su icono a 520 px o menos, sin perder su nombre (CA-026-11).
  if (!visuallyHidden(".btn__label", MEDIA_WIDTH)) fail(`@media ${MEDIA_WIDTH}: .btn__label tiene que ocultarse solo a la vista, como .vh (CA-026-11)`);
  if (valueOf(".ic", "stroke") !== "currentColor") fail(".ic tiene que llevar stroke: currentColor (el icono es el rótulo a 520 px o menos, 1.4.11)");

  // Titulares, textos de apoyo y columna (CA-026-01 y 03).
  if (valueOf("h1", "font-weight") !== "var(--font-weight-black)") fail("h1 tiene que llevar font-weight: var(--font-weight-black) (el peso más fuerte, CA-026-03)");
  if (!/^var\(--border-width-section\) solid var\(--color-ink\)$/.test(valueOf("h3", "border-top") ?? "")) {
    fail("h3 tiene que llevar border-top: var(--border-width-section) solid var(--color-ink) (la regla de 4 px, CA-026-03)");
  }
  for (const s of [".date", ".meta"]) {
    if (valueOf(s, "font-family") !== "var(--font-family-mono)") fail(`${s} tiene que llevar font-family: var(--font-family-mono) (Space Mono, CA-026-03)`);
  }
  for (const s of ["main", ".end"]) {
    if (valueOf(s, "max-width") !== "var(--size-content-max-width)") fail(`${s} tiene que llevar max-width: var(--size-content-max-width) (la columna de 600 px, CA-026-01)`);
  }

  // Objetivos de 44 × 44, marcas del elegido y de la página actual, colores forzados (CA-026-07 y 10).
  for (const s of TOUCH_TARGETS) {
    const ok = ["min-width", "min-height"].every((p) => valueOf(s, p) === "var(--size-min-touch-target)");
    if (!ok) fail(`${s} tiene que llevar min-width y min-height: var(--size-min-touch-target) (44 × 44, CA-026-10)`);
  }
  const pressed = '.langs a[aria-pressed="true"]';
  if (valueOf(pressed, "font-weight") !== "var(--font-weight-black)" || valueOf(pressed, "text-decoration-thickness") !== "var(--border-width-strong)") {
    fail(`el idioma elegido (${pressed}) tiene que llevar font-weight: var(--font-weight-black) y text-decoration-thickness: var(--border-width-strong)`);
  }
  const current = '.end a[aria-current="page"]';
  if (valueOf(current, "font-weight") !== "var(--font-weight-bold)" || !/^var\(--border-width-strong\) solid /.test(valueOf(`${current} > [lang]`, "border-bottom") ?? "")) {
    fail(`la página actual del pie (${current}) tiene que ir en negrita y con una línea de var(--border-width-strong) bajo el texto (CA-026-10)`);
  }
  if (!blocks.some((b) => b.name === "@media" && b.cond === MEDIA_FORCED)) fail(`falta @media ${MEDIA_FORCED} (las marcas y el icono con colores forzados, CA-026-10)`);
  else if (valueOf(".ic", "stroke", MEDIA_FORCED) !== "CanvasText") fail(`@media ${MEDIA_FORCED}: .ic tiene que llevar stroke: CanvasText`);
}

// ─── vercel.json ─────────────────────────────────────────────────────────────────────────────────

const CSP = {
  "default-src": "'none'",
  "style-src": "'self'",
  "font-src": "'self'",
  "img-src": "'self'",
  "object-src": "'none'",
  "base-uri": "'none'",
  "form-action": "'none'",
  "frame-ancestors": "'none'",
};
/**
 * La de la página de inicio (spec 025, segunda enmienda): la misma con programas del propio origen y estilos en
 * línea (la maqueta usa atributos `style=`).
 */
const HOME_CSP = { ...CSP, "script-src": "'self'", "style-src": "'self' 'unsafe-inline'" };
/**
 * La de las cuatro páginas (spec 026, CA-026-13 y su enmienda): programas solo del propio origen (`/lang.js`) y
 * Trusted Types, que el navegador hace cumplir (el programa no usa ningún sumidero de HTML).
 */
const CONTENT_CSP = { ...CSP, "script-src": "'self'", "require-trusted-types-for": "'script'", "trusted-types": "'none'" };
/** Las directivas en que pueden diferir las CSP de las dos reglas (la de «/» y la de las cuatro páginas). */
const CSP_DIFFERENCES = ["style-src", "require-trusted-types-for", "trusted-types"];
/** Cómo instala Vercel las dependencias de la página de inicio (lo mismo que la CI). */
const INSTALL_COMMAND = "npm ci --ignore-scripts";
const PERMISSIONS = ["accelerometer", "autoplay", "camera", "display-capture", "geolocation", "gyroscope", "interest-cohort", "magnetometer", "microphone", "payment", "usb"];

function checkVercel(path, errors) {
  const fail = (msg) => errors.push(`vercel.json: ${msg}`);
  let json;
  try {
    json = JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    fail(`no se puede leer (${e.message})`);
    return;
  }
  if (json.cleanUrls !== true) fail("cleanUrls tiene que ser true");
  if (json.trailingSlash !== false) fail("trailingSlash tiene que ser false");
  if (json.framework !== null) fail("framework tiene que ser null");
  if (json.buildCommand !== "node build.mjs") fail('buildCommand tiene que ser "node build.mjs"');
  // Vercel instala como la CI: lo del lockfile, sin scripts de instalación (spec 025, plan §6.1).
  if (json.installCommand !== INSTALL_COMMAND) fail(`installCommand tiene que ser "${INSTALL_COMMAND}" (es ${JSON.stringify(json.installCommand)})`);
  if (json.outputDirectory !== "dist") fail('outputDirectory tiene que ser "dist"');
  for (const key of ["rewrites", "redirects", "routes"]) if (key in json) fail(`la web no necesita «${key}»`);
  // Dos reglas que no se solapan (spec 025): «/(.+)», para todo menos la página de inicio, con `script-src 'self'` y
  // Trusted Types (spec 026), y «/», con `script-src 'self'` y `style-src 'self' 'unsafe-inline'`; iguales en todo
  // lo demás.
  const sources = Array.isArray(json.headers) ? json.headers.map((r) => r?.source) : [];
  if (sources.length !== 2 || !sources.includes("/(.+)") || !sources.includes("/")) {
    fail('tiene que haber dos reglas de cabeceras, con source "/(.+)" (todo menos la página de inicio) y "/" (la página de inicio)');
    return;
  }
  for (const rule of json.headers) {
    const home = rule.source === "/";
    checkHeaderRule(rule, home ? HOME_CSP : CONTENT_CSP, home ? (msg) => fail(`${msg} (regla «/»)`) : fail);
  }
  const rest = headerMap(json.headers.find((r) => r.source === "/(.+)"));
  const home = headerMap(json.headers.find((r) => r.source === "/"));
  for (const key of new Set([...rest.keys(), ...home.keys()])) {
    const [a, b] = key === "content-security-policy"
      ? [cspText(rest.get(key), { without: CSP_DIFFERENCES }), cspText(home.get(key), { without: CSP_DIFFERENCES })]
      : [rest.get(key), home.get(key)];
    if (a !== b) fail(`las dos reglas de cabeceras tienen que ser iguales salvo style-src y Trusted Types (require-trusted-types-for, trusted-types): ${key} difiere («${rest.get(key) ?? "falta"}» frente a «${home.get(key) ?? "falta"}»)`);
  }
}

/** Las cabeceras de una regla (nombre en minúsculas → valor). */
function headerMap(rule) {
  const out = new Map();
  for (const h of Array.isArray(rule?.headers) ? rule.headers : []) {
    if (typeof h?.key === "string") out.set(h.key.toLowerCase(), h.value);
  }
  return out;
}

/** Una CSP en forma comparable (directivas y orígenes ordenados), sin las directivas de [without]. */
function cspText(value, { without = [] } = {}) {
  if (typeof value !== "string") return value;
  return value
    .split(";")
    .map((d) => d.trim().split(/\s+/).filter(Boolean))
    .filter((d) => d.length > 0 && !without.includes(d[0]))
    .map(([name, ...rest]) => [name, ...rest.sort()].join(" "))
    .sort()
    .join("; ");
}

/** Las cabeceras de una regla de `vercel.json`, con la CSP [cspSpec]. */
function checkHeaderRule(rule, cspSpec, fail) {
  const headers = new Map();
  for (const h of rule.headers ?? []) headers.set(h.key.toLowerCase(), h.value);
  if (headers.has("set-cookie")) fail("pone una cookie (Set-Cookie): la web no usa cookies");
  if (/noindex/i.test(headers.get("x-robots-tag") ?? "")) fail("X-Robots-Tag: noindex (la política tiene que poder encontrarse)");
  const need = (key, ok, expected) => {
    const v = headers.get(key.toLowerCase());
    if (v === undefined) fail(`falta la cabecera ${key}`);
    else if (!ok(v)) fail(`${key} tiene que ser ${expected} (es «${v}»)`);
  };
  need("Referrer-Policy", (v) => v === "no-referrer", "no-referrer");
  need("X-Content-Type-Options", (v) => v === "nosniff", "nosniff");
  need("X-Frame-Options", (v) => v === "DENY", "DENY");
  need("Cross-Origin-Opener-Policy", (v) => v === "same-origin", "same-origin");
  need(
    "Strict-Transport-Security",
    (v) => Number(/max-age=(\d+)/.exec(v)?.[1] ?? 0) >= 63072000 && /includeSubDomains/.test(v),
    "max-age=63072000 (como mínimo) con includeSubDomains",
  );

  const csp = headers.get("content-security-policy");
  if (csp === undefined) fail("falta la cabecera Content-Security-Policy");
  else {
    const actual = new Map(
      csp.split(";").map((d) => d.trim()).filter(Boolean).map((d) => {
        const [name, ...sources] = d.split(/\s+/);
        return [name, sources.sort().join(" ")];
      }),
    );
    for (const [d, v] of Object.entries(cspSpec)) {
      if (!actual.has(d)) fail(`Content-Security-Policy: falta ${d} ${v}`);
      else if (actual.get(d) !== v) fail(`Content-Security-Policy: ${d} tiene que ser ${v} (es ${actual.get(d)})`);
    }
    for (const d of actual.keys()) if (!(d in cspSpec)) fail(`Content-Security-Policy: ${d} no se admite`);
  }

  const perms = headers.get("permissions-policy");
  if (perms === undefined) fail("falta la cabecera Permissions-Policy");
  else {
    const actual = new Map(perms.split(",").map((p) => p.trim().split("=")).map(([k, v]) => [k, v]));
    for (const d of PERMISSIONS) {
      if (!actual.has(d)) fail(`Permissions-Policy: falta ${d}=()`);
      else if (actual.get(d) !== "()") fail(`Permissions-Policy: ${d} tiene que ser () (es ${actual.get(d)})`);
    }
  }
}

// ─── El nombre de la app, a mano ─────────────────────────────────────────────────────────────────

function* walk(dir) {
  for (const name of readdirSync(dir).sort()) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* walk(p);
    else yield p;
  }
}

/** El nombre escrito como palabra suelta (no dentro de otra: «ninguna.» contiene «una.»). */
const literal = (name) =>
  new RegExp(`(?<![\\p{L}\\p{N}_])${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![\\p{L}\\p{N}_])`, "u");

/**
 * Lo que va delante de una palabra que abre frase: nada o el final de otra, con una viñeta o un título de
 * Markdown y comillas de apertura (la clave de una línea de JSON acaba en «:»). («Una», el artículo, abre frase con mayúscula.)
 */
const beforeSentenceStart = /(?:^|[.!?¿¡:…]|\\n)\s*(?:[-*>#]+\s+)?["'«(\-—]*\s*$/u;

/** Lo que va detrás cuando la palabra sigue con más texto: otra palabra o un marcador `{…}`. */
const followedByMoreText = /^\s+[\p{L}{]/u;

/**
 * ¿Aparece [name] como palabra suelta en [line]? Un nombre que es una palabra del español («Una», el artículo)
 * no cuenta al abrir frase y seguido de más texto («Una sola tarea…»); en cualquier otro sitio sí, porque el
 * artículo va en minúscula y la mayúscula a mitad de frase es el nombre.
 */
export function mentionsName(line, name) {
  const bareWord = /\p{L}$/u.test(name);
  const all = new RegExp(literal(name).source, "gu");
  for (const m of line.matchAll(all)) {
    const article = bareWord
      && beforeSentenceStart.test(line.slice(0, m.index))
      && followedByMoreText.test(line.slice(m.index + m[0].length));
    if (!article) return true;
  }
  return false;
}

function checkHandWrittenName(paths, identity, errors) {
  const files = [paths.buildFile, ...(existsSync(paths.srcDir) ? walk(paths.srcDir) : [])];
  for (const file of files) {
    const rel = file === paths.buildFile ? "build.mjs" : `src/${relative(paths.srcDir, file)}`;
    readFileSync(file, "utf8").split("\n").forEach((line, i) => {
      for (const name of [identity.displayName, identity.wordmark]) {
        if (mentionsName(line, name)) {
          errors.push(`landing/${rel}:${i + 1}: el nombre de la app «${name}» está escrito a mano (sale de app/identity.yaml, P7)`);
        }
      }
    });
  }
}

// ─── La página de inicio (spec 025) ──────────────────────────────────────────────────────────────

/**
 * Lo que el programa de la página de inicio no puede usar: ninguna forma de pedir algo a la red (CA-025-12), de
 * guardar algo más que el idioma ni de ejecutar texto. Es la lista de lo que se busca, no de lo permitido.
 */
const FORBIDDEN_APIS = [
  [/\bfetch\s*\(/, "fetch("],
  [/\bXMLHttpRequest\b/, "XMLHttpRequest"],
  [/\bsendBeacon\b/, "navigator.sendBeacon"],
  [/\bWebSocket\b/, "WebSocket"],
  [/\bWebTransport\b/, "WebTransport"],
  [/\bEventSource\b/, "EventSource"],
  [/\bRTC(?:PeerConnection|DataChannel)\b/, "WebRTC"],
  [/\bimportScripts\b/, "importScripts"],
  [/\bimport\s*\(/, "import() dinámico"],
  [/\bserviceWorker\b/, "serviceWorker"],
  [/\beval\s*\(/, "eval"],
  // Lo que guarda (CA-025-12 y la política, CA-025-13): solo el idioma, en `localStorage`; nada más.
  [/\bsessionStorage\b/, "sessionStorage"],
  [/\bindexedDB\b/, "indexedDB"],
  [/\bcookieStore\b/, "cookieStore"],
  [/\.cookie\b/, "document.cookie"],
  [/\bcaches\s*\.\s*open\b/, "caches.open"],
  [/\bnew\s+Function\b/, "new Function"],
];

/**
 * Los dominios que puede nombrar el programa sin pedirles nada: el espacio de nombres de SVG (GSAP), la web de
 * GSAP en su aviso de licencia y sus mensajes, y las fichas de las tiendas (enlaces, de `identity.yaml`, que
 * `build.mjs` valida). Cualquier otro dominio es un error.
 */
const PROGRAM_HOSTS = new Set(["www.w3.org", "gsap.com", "apps.apple.com", "play.google.com"]);

/** Las rutas de [dir] (relativas, con «/»), recursivas. */
const filesOf = (dir) => [...walk(dir)].map((f) => relative(dir, f).split(sep).join("/"));

/**
 * El juego de reglas de la página de inicio (spec 025, segunda enmienda): la de la maqueta, que construye Vite
 * y sí lleva programa. Lo mínimo: un único `<script type="module" src>` del propio origen, sin nada escrito
 * dentro; sin recursos de otro origen; ningún mapa de código en `dist/`; y, en el programa, sin API de red ni
 * dominios externos. La CSP se comprueba en `vercel.json` (`checkSite`).
 */
export function checkHome(paths = defaultPaths(), { dist = paths.out } = {}) {
  const errors = [];
  const found = existsSync(dist) ? filesOf(dist) : [];
  for (const f of found) if (f.endsWith(".map")) errors.push(`${f}: mapa de código en la web publicada (CA-025-12)`);
  if (!found.includes(HOME_PAGE)) {
    errors.push(`${HOME_PAGE}: falta la página de inicio (¿se ejecutó landing/build.mjs?)`);
    return errors;
  }
  const html = readFileSync(join(dist, HOME_PAGE), "utf8");
  const fail = (msg) => errors.push(`${HOME_PAGE}: ${msg}`);
  const t = tags(html);

  const scripts = t.filter((x) => x.name === "script" && !x.closing);
  if (scripts.length !== 1) fail(`tiene ${scripts.length} <script> (tiene que haber uno: el programa de assets/)`);
  for (const s of scripts) {
    const close = t.find((x) => x.closing && x.name === "script" && x.start >= s.end);
    if (!close || html.slice(s.end, close.start).trim() !== "") fail("un <script> con código escrito dentro de la página (los programas, solo por src)");
    const src = s.attrs.src ?? "";
    if (s.attrs.type !== "module") fail(`un <script> que no es type="module" («${s.attrs.type ?? ""}»)`);
    if (!src) fail("un <script> sin src (los programas, solo del propio origen y por src)");
    else if (!isLocal(src)) fail(`un <script> de otro origen («${src}»)`);
    else if (!found.includes(src.replace(/^\//, ""))) fail(`el <script> carga un programa que no está en dist/ («${src}»)`);
  }
  // Todo lo que Vite deja en assets/, esté enlazado o no (un trozo suelto también se publica): cada programa
  // con las reglas del programa y cada hoja sin `@import` ni recursos de otro origen.
  for (const f of found) {
    if (!f.startsWith("assets/")) continue;
    if (f.endsWith(".js")) checkProgram(f, readFileSync(join(dist, f), "utf8"), errors);
    else if (f.endsWith(".css")) checkAssetCss(f, readFileSync(join(dist, f), "utf8"), errors);
  }

  for (const x of t) {
    if (x.closing) continue;
    for (const [attr, value] of Object.entries(x.attrs)) {
      if (/^on/.test(attr)) fail(`<${x.name}> lleva el manejador en línea ${attr} (la CSP lo bloquearía)`);
      if ((RESOURCE_ATTRS.includes(attr) || (x.name === "link" && attr === "href")) && value && !isLocal(value)) {
        fail(`<${x.name} ${attr}> de otro origen («${value}»): la web no usa recursos de terceros`);
      }
      if (attr === "href" && /^\s*(javascript|data|vbscript):/i.test(value)) fail(`un href con ${value.trim().split(":")[0].toLowerCase()}:`);
    }
    if (FRAMES.includes(x.name)) fail(`tiene un <${x.name}> (nada incrustado)`);
    else if (x.name === "base") fail("tiene un <base>");
    else if (x.name === "meta" && "http-equiv" in x.attrs) fail("tiene un <meta http-equiv>");
  }
  for (const re of ANALYTICS) if (re.test(html)) fail(`rastro de analítica (${re})`);
  return errors;
}

/** Atributos que cargan un recurso. */
const RESOURCE_ATTRS = ["src", "srcset", "poster", "data", "action", "formaction", "background", "xlink:href", "ping", "manifest"];

/** Una hoja construida de la página de inicio: sin `@import` y sin `url()` que no sea del propio origen. */
function checkAssetCss(file, text, errors) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  const clean = text.replace(/\/\*[\s\S]*?\*\//g, " ");
  if (/@import/i.test(clean)) fail("@import (la web no carga hojas de otro sitio)");
  for (const m of clean.matchAll(/url\(\s*(['"]?)([^)'"]*)\1\s*\)/gi)) {
    if (!isLocal(m[2].trim())) fail(`url(${m[2]}): recurso de otro origen`);
  }
}

/** El programa construido: sin API de red, sin dominios externos, sin analítica y sin mapas. */
function checkProgram(file, code, errors) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  for (const [re, api] of FORBIDDEN_APIS) if (re.test(code)) fail(`usa ${api} (CA-025-12: sin red y sin guardar más que el idioma)`);
  for (const m of code.matchAll(/\b(?:https?|wss?):\/\/([A-Za-z0-9.-]+)/g)) {
    if (!PROGRAM_HOSTS.has(m[1].toLowerCase())) fail(`nombra un dominio externo («${m[1]}»)`);
  }
  if (/sourceMappingURL/.test(code)) fail("apunta a un mapa de código (sourceMappingURL)");
  for (const re of ANALYTICS) if (re.test(code)) fail(`rastro de analítica (${re})`);
}

// ─── El programa de idioma (spec 026) ────────────────────────────────────────────────────────────

/** Lo que más puede pesar `lang.js` sin comprimir (CA-026-15). */
export const LANG_MAX_BYTES = 10_240;

/**
 * Lo que el programa de idioma no puede usar además de `FORBIDDEN_APIS` (CA-026-13, plan §6.1): escribir HTML,
 * texto o estilos, crear elementos, navegar, hablar con otras ventanas, temporizadores, escuchar el almacenamiento
 * de otras pestañas (CL-026-7) ni cargar dependencias. Es la lista de lo que se busca, no de lo permitido.
 */
const LANG_FORBIDDEN = [
  [/\binnerHTML\b/, "innerHTML"],
  [/\bouterHTML\b/, "outerHTML"],
  [/\binsertAdjacent(?:HTML|Element|Text)\b/, "insertAdjacentHTML"],
  [/\bdocument\s*\.\s*write/, "document.write"],
  [/\btextContent\b/, "textContent"],
  [/\binnerText\b/, "innerText"],
  [/\bcreateElement/, "createElement"],
  [/\.\s*style\b/, ".style"],
  [/\bsetAttributeNS\b/, "setAttributeNS"],
  [/\btoggleAttribute\b/, "toggleAttribute"],
  [/\bimport\b/, "import"],
  [/\brequire\s*\(/, "require("],
  [/\blocation\s*\.\s*href\s*=(?!=)/, "location.href ="],
  [/\blocation\s*=(?!=)/, "location ="],
  [/\blocation\s*\.\s*(?:assign|replace)\b/, "location.assign o location.replace"],
  [/\bopen\s*\(/, "window.open"],
  [/\bpostMessage\b/, "postMessage"],
  [/\bsetTimeout\b/, "setTimeout"],
  [/\bsetInterval\b/, "setInterval"],
  [/\bonstorage\b/, "onstorage"],
  [/addEventListener\s*\(\s*["'`]storage/, 'addEventListener("storage"'],
];

/** Los únicos atributos que el programa pone o quita (lista blanca, plan §6.1). */
const LANG_ATTRIBUTES = /^\s*(["'])(?:role|aria-pressed)\1/;
/** El único uso de `localStorage`: leer o escribir el idioma con la clave de la landing. */
const LANG_STORAGE = /^\s*\.\s*(?:getItem|setItem)\s*\(\s*(["'])una-lang\1/;

/** `dist/lang.js`: lo que no puede usar, ningún dominio (ni los de la página de inicio) y su tamaño. */
function checkLangProgram(file, bytes, errors) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  const code = bytes.toString("utf8");
  if (bytes.length > LANG_MAX_BYTES) fail(`pesa ${bytes.length} bytes (${LANG_MAX_BYTES} como mucho, CA-026-15)`);
  for (const [re, api] of [...FORBIDDEN_APIS, ...LANG_FORBIDDEN]) if (re.test(code)) fail(`usa ${api} (CA-026-13)`);
  for (const m of code.matchAll(/\b(setAttribute|removeAttribute)\s*\(/g)) {
    const rest = code.slice(m.index + m[0].length);
    if (!LANG_ATTRIBUTES.test(rest)) fail(`usa ${m[1]} con «${rest.slice(0, 20).split("\n")[0]}…» (solo "role" y "aria-pressed", CA-026-13)`);
  }
  for (const m of code.matchAll(/\blocalStorage\b/g)) {
    const rest = code.slice(m.index + m[0].length);
    if (!LANG_STORAGE.test(rest)) fail(`usa localStorage con «${rest.slice(0, 20).split("\n")[0]}…» (solo getItem y setItem de "una-lang", CA-026-13)`);
  }
  for (const m of code.matchAll(/\b[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\s"'`)]*/g)) fail(`nombra un dominio («${m[0]}»): el programa no nombra ninguno`);
  for (const m of code.matchAll(/["'`]\s*\/\/[^\s"'`]+/g)) fail(`nombra un dominio sin protocolo («${m[0]}»)`);
  if (/sourceMappingURL/.test(code)) fail("apunta a un mapa de código (sourceMappingURL)");
  for (const re of ANALYTICS) if (re.test(code)) fail(`rastro de analítica (${re})`);
}

/** Las páginas que puede haber en `dist/`: con `script-src 'self'`, un `.html` de más podría ejecutar programas. */
const ALLOWED_HTML = new Set([HOME_PAGE, ...REQUIRED_PAGES]);
/** Los programas que puede haber en `dist/`: el de idioma y los de la página de inicio (Vite, en `assets/`). */
const allowedProgram = (f) => f === LANG_FILE || /^assets\/[^/]+\.js$/.test(f);

/** Ningún `.html` ni programa de más en [dist] (plan §6.1). */
function checkDistFiles(dist, errors) {
  for (const f of existsSync(dist) ? filesOf(dist) : []) {
    if (/\.x?html?$/i.test(f) && !ALLOWED_HTML.has(f)) errors.push(`${f}: un .html de más en dist/ (solo la de inicio y las cuatro páginas, CA-026-13)`);
    else if (/\.(?:[cm]?js|jsx|wasm)$/i.test(f) && !allowedProgram(f)) errors.push(`${f}: un programa de más en dist/ (solo ${LANG_FILE} y assets/*.js, CA-026-13)`);
  }
}

// ─── Todo junto ──────────────────────────────────────────────────────────────────────────────────

/** Las comprobaciones de la web ya construida en [dist]. Devuelve los errores (vacía si todo bien). */
export function checkSite(paths = defaultPaths(), { dist = paths.out } = {}) {
  const errors = [];
  let site;
  let identity;
  try {
    identity = readIdentity(readFileSync(paths.identity, "utf8"));
    site = renderSite(paths);
  } catch (e) {
    if (!(e instanceof BuildError)) throw e;
    return [`no se puede construir la web desde sus fuentes: ${e.message}`];
  }

  // Archivos.
  const needed = [...REQUIRED_PAGES, "tokens.css", "site.css", LANG_FILE, NOTICES_FILE];
  for (const d of FONT_DIRS) needed.push(`fonts/${d}/OFL.txt`);
  for (const f of FONT_FILES) needed.push(`fonts/${f.dir}/${f.file}`);
  const missing = new Set(needed.filter((f) => !existsSync(join(dist, f))));
  for (const f of missing) errors.push(`${f}: falta en ${relative(paths.repoRoot, dist) || dist} (¿se ejecutó landing/build.mjs?)`);

  // Que lo publicado sea lo que construyen las fuentes.
  for (const [file, expected] of site.files) {
    if (missing.has(file)) continue;
    if (readFileSync(join(dist, file), "utf8") !== expected) {
      errors.push(`${file}: no coincide con lo que construye la web desde sus fuentes (¿falta ejecutar landing/build.mjs?)`);
    }
  }

  // Páginas.
  const pages = new Map();
  for (const page of REQUIRED_PAGES) {
    if (missing.has(page)) continue;
    pages.set(page, readFileSync(join(dist, page), "utf8"));
    checkPage(page, pages.get(page), site.meta.get(page), errors);
  }
  checkAnchors(pages, errors);
  if (!missing.has(LANG_FILE)) checkLangProgram(LANG_FILE, readFileSync(join(dist, LANG_FILE)), errors);
  checkDistFiles(dist, errors);
  if (!missing.has("privacy/index.html")) checkPolicy(paths, dist, identity.displayName, errors);

  // CSS.
  if (!missing.has("tokens.css") && !missing.has("site.css")) {
    const tokensText = readFileSync(join(dist, "tokens.css"), "utf8");
    const tokens = JSON.parse(readFileSync(paths.tokens, "utf8"));
    const definedVars = new Set([...tokensText.matchAll(/^\s*(--[a-z0-9-]+):/gm)].map((m) => m[1]));
    const ctx = { tokens, definedVars };
    checkCss("tokens.css", tokensText, ctx, errors, { strict: false });
    checkCss("site.css", readFileSync(join(dist, "site.css"), "utf8"), ctx, errors, { strict: true });
  }

  if (existsSync(paths.vercelJson)) checkVercel(paths.vercelJson, errors);
  else errors.push("vercel.json: falta");
  checkHandWrittenName(paths, identity, errors);
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const paths = defaultPaths();
  const at = args.indexOf("--dist");
  const dist = at >= 0 ? args[at + 1] : paths.out;
  const errors = [...checkSite(paths, { dist }), ...checkHome(paths, { dist })];
  if (errors.length > 0) {
    for (const e of errors) console.error(`error: ${e}`);
    console.error(`\n${errors.length} error(es) en la web.`);
    process.exit(1);
  }
  console.log(`Web comprobada (${REQUIRED_PAGES.length} páginas y la de inicio): sin errores.`);
}
