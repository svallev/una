// Comprobaciones de la web construida (spec 023): CA-023-04 (la política publicada es la del
// documento), CA-023-13 (páginas, idiomas), CA-023-14 (sin terceros ni rastreo, cabeceras),
// CA-023-15 (tokens, contraste, estructura, foco) y CA-023-16 (el bloque de avisos de terceros); y, con su
// propio juego de reglas (`checkHome`), la página de inicio de la spec 025 (CA-025-12 y CA-025-14), la única
// con programa. Falla cerrada: lo que no entiende es un error.
//
//   node landing/check.mjs [--dist <carpeta>]      (después de `node landing/build.mjs`)
//
// Solo módulos de Node. `checkSite` (las cuatro páginas sin JavaScript y `vercel.json`) y `checkHome` (la
// de inicio) devuelven la lista de errores (vacía si todo está bien) para poder probar cada regla con un caso
// que falla (`landing/test`).
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";
import {
  BuildError,
  FONT_DIRS,
  NOTICES_FILE,
  FONT_FILES,
  defaultPaths,
  kebab,
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

  // Sin JavaScript, sin estilos en línea, sin recursos de otro origen, sin formularios ni medios.
  for (const x of t) {
    if (x.closing) continue;
    for (const attr of Object.keys(x.attrs)) {
      if (/^on/.test(attr)) fail(`<${x.name}> lleva el manejador ${attr} (la web no usa JavaScript)`);
      if (attr === "style") fail(`<${x.name}> lleva style en línea (la CSP lo bloquearía)`);
    }
    if (x.name === "script") fail("tiene un <script> (la web no usa JavaScript)");
    else if (x.name === "style") fail("tiene un <style> en línea (la CSP lo bloquearía)");
    else if (FRAMES.includes(x.name)) fail(`tiene un <${x.name}> (nada incrustado)`);
    else if (FORMS.includes(x.name)) fail(`tiene un <${x.name}> (la web no tiene formularios)`);
    else if (MEDIA.includes(x.name)) fail(`tiene un <${x.name}> (la web no lleva imágenes ni medios)`);
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
  const scanned = html.replace(/<pre>[\s\S]*?<\/pre>/g, " ");
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
  const expected = withNotices ? 3 : 2;
  if (sections.length !== expected) {
    fail(
      withNotices
        ? `tiene ${sections.length} <section> (las dos mitades, español e inglés, y el bloque de avisos)`
        : `tiene ${sections.length} <section> (las dos mitades, español e inglés)`,
    );
    return;
  }
  const [es, en] = sections;
  if (es.attrs.lang !== "es") fail('la primera mitad (el español va primero) no está marcada con lang="es"');
  if (en.attrs.lang !== "en") fail('la segunda mitad no está marcada con lang="en"');
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
  const switchLink = (from, to, href, lang) =>
    t.find((x) => x.start >= from && x.end <= to && x.name === "a" && !x.closing && x.attrs.href === href);
  const toEn = switchLink(esFrom, esTo, "#en");
  const toEs = switchLink(enFrom, enTo, "#es");
  if (!toEn) fail("falta el enlace «#en» al inglés al principio de la mitad española");
  else if (toEn.attrs.lang !== "en") fail('el enlace al inglés no está marcado con lang="en"');
  if (!toEs) fail("falta el enlace «#es» al español al principio de la mitad inglesa");
  else if (toEs.attrs.lang !== "es") fail('el enlace al español no está marcado con lang="es"');
  if (withNotices) checkNoticesBlock(sections[2], closes[2], t, html, fail);
  const levels = (from, to) =>
    headings.filter((h) => h.start >= from && h.end <= to).map((h) => h.level).join(",");
  if (levels(esFrom, esTo) !== levels(enFrom, enTo)) {
    fail(`los encabezados de la mitad inglesa (${levels(enFrom, enTo)}) no están al mismo nivel que los de la española (${levels(esFrom, esTo)})`);
  }
}

/**
 * El bloque de avisos de terceros (CA-023-16): una tercera `<section lang="en" aria-labelledby="notices">`
 * después de las dos mitades, que empieza por su `<h2 id="notices">` y lleva el texto en un `<pre>`.
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
  if (!t.some((x) => inside(x) && x.name === "pre")) fail("el bloque de avisos no lleva el texto en un <pre>");
}

const escapeText = (s) =>
  s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");

// ─── La política publicada (CA-023-04) ───────────────────────────────────────────────────────────

function checkPolicy(paths, dist, name, errors) {
  const file = "privacy/index.html";
  const html = readFileSync(join(dist, file), "utf8");
  const expected = policyFragments(readFileSync(paths.policy, "utf8"), name);
  for (const lang of ["es", "en"]) {
    const m = new RegExp(`<section lang="${lang}" aria-labelledby="${lang}">\\n([\\s\\S]*?)\\n</section>`).exec(html);
    if (!m) {
      errors.push(`${file}: no está la mitad «${lang}» de la política`);
      continue;
    }
    const body = m[1].replace(/^<p><a class="block-link"[^\n]*<\/a><\/p>\n/, "");
    if (body !== expected[lang].html) {
      errors.push(`${file}: el texto publicado de la política (${lang}) no es el de docs/legal/privacy-policy.md`);
    }
  }
}

// ─── CSS ─────────────────────────────────────────────────────────────────────────────────────────

function parseCss(text) {
  const clean = text.replace(/\/\*[\s\S]*?\*\//g, "");
  const rules = [];
  const atRules = [...clean.matchAll(/@([a-z-]+)/gi)].map((m) => `@${m[1]}`);
  for (const m of clean.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    const selector = m[1].trim();
    if (selector.startsWith("@")) continue;
    const decls = m[2]
      .split(";")
      .map((d) => d.trim())
      .filter(Boolean)
      .map((d) => {
        const i = d.indexOf(":");
        return { prop: d.slice(0, i).trim().toLowerCase(), value: d.slice(i + 1).trim() };
      });
    rules.push({ selector, decls });
  }
  return { rules, atRules, clean };
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
const ALLOWED_PAIRS = new Set(["ink/paper", "textMuted/paper", "textMuted/surface", "error/paper", "error/surface", "ink/dangerFill", "onInk/ink", "onInkMuted/ink"]);

function checkCss(file, text, { tokens, definedVars }, errors, { strict }) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  const { rules, atRules, clean } = parseCss(text);

  // Las variables que usa tienen que existir.
  for (const m of clean.matchAll(/var\(\s*(--[a-z0-9-]+)/gi)) {
    if (!definedVars.has(m[1])) fail(`usa la variable ${m[1]}, que no está en tokens.css`);
  }
  // Recursos: ninguno de otro origen.
  for (const m of clean.matchAll(/url\(\s*(['"]?)([^)'"]*)\1\s*\)/gi)) {
    if (strict) fail(`url(${m[2]}): la hoja de estilo de la web no carga recursos`);
    else if (!isLocal(m[2])) fail(`url(${m[2]}): recurso de otro origen`);
  }
  if (/@import/i.test(clean)) fail("@import (la web no carga hojas de otro sitio)");
  if (!strict) return;

  for (const at of atRules) if (at !== "@import") fail(`regla ${at} no admitida (en site.css solo reglas simples con variables)`);

  const colorKeys = new Map(Object.keys(tokens.color).filter((k) => !k.startsWith("$")).map((k) => [kebab(k), k]));
  const focusRing = [];
  let underline = false;
  let pre = null;
  let block = null;

  for (const { selector, decls } of rules) {
    const where = `«${selector}»`;
    const get = (p) => decls.find((d) => d.prop === p)?.value;
    for (const { prop, value } of decls) {
      const loose = looseValue(prop, value);
      if (loose) fail(`valor suelto (${loose}) en ${where}: «${prop}: ${value}» (usa una variable de tokens.css)`);
      if (/^(transition|animation)/.test(prop)) fail(`${where}: «${prop}» (la web no tiene animaciones)`);
      if (prop === "scroll-behavior" && value !== "auto") fail(`${where}: scroll-behavior: ${value} (movimiento: tiene que ser auto)`);
      if (/^outline(-style|-width)?$/.test(prop) && /^(none|0|hidden)$/.test(value)) fail(`${where}: «${prop}: ${value}» oculta el foco (2.4.7)`);
      if (/^text-decoration(-line)?$/.test(prop) && /\bnone\b/.test(value)) fail(`${where}: «${prop}: ${value}» quita el subrayado de los enlaces`);
      if (prop === "height" && !/^(auto|100%|inherit)$/.test(value)) fail(`${where}: altura fija «height: ${value}» (1.4.12: usa min-height)`);
      if (prop === "width" && !/^(auto|100%|inherit|fit-content)$/.test(value)) fail(`${where}: ancho fijo «width: ${value}» (1.4.10: usa max-width)`);
      if (prop === "line-height" && !/^\d*\.?\d+$/.test(value)) fail(`${where}: interlineado fijo «line-height: ${value}» (1.4.12: sin unidades)`);
      if (/^overflow(-x)?$/.test(prop) && /\b(scroll|auto)\b/.test(value)) fail(`${where}: «${prop}: ${value}» obliga a un desplazamiento horizontal (1.4.10)`);
      if (prop === "position" && /^(sticky|fixed)$/.test(value)) fail(`${where}: position: ${value} puede tapar el elemento con el foco (2.4.11)`);
      if (prop === "font-size" && /^(html|:root)$/.test(selector)) fail(`${where}: font-size en html (hay que respetar el tamaño del texto del navegador)`);
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

    // Reglas que tienen que existir.
    if (selector.split(",").some((s) => s.trim().endsWith(":focus-visible"))) {
      if (/var\(--border-width-focus\)/.test(get("outline") ?? "")) focusRing.push(selector);
    }
    if (selector === "a" && /\bunderline\b/.test(get("text-decoration") ?? "")) underline = true;
    if (selector === "pre") pre = decls;
    if (selector === ".block-link") block = decls;
  }
  if (focusRing.length === 0) fail("falta el anillo de foco (:focus-visible con outline de var(--border-width-focus)): 2.4.7");
  if (!underline) fail("los enlaces (a) tienen que ir subrayados: text-decoration: underline");
  if (!pre || pre.find((d) => d.prop === "white-space")?.value !== "pre-wrap") fail("pre tiene que llevar white-space: pre-wrap (reflujo, 1.4.10)");
  else if (pre.find((d) => d.prop === "overflow-wrap")?.value !== "anywhere") fail("pre tiene que llevar overflow-wrap: anywhere (reflujo, 1.4.10)");
  if (!block || block.find((d) => d.prop === "min-height")?.value !== "var(--size-link-button)") {
    fail(".block-link tiene que llevar min-height: var(--size-link-button) (objetivo de 44, P6)");
  }
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
/** La de la página de inicio: la misma más programas del propio origen (spec 025, CA-025-12). */
const HOME_CSP = { ...CSP, "script-src": "'self'" };
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
  // Dos reglas que no se solapan (spec 025, plan §6.1): «/(.+)», la de siempre, para todo menos la página de
  // inicio, y «/», la misma con `script-src 'self'`; iguales en todo lo demás.
  const sources = Array.isArray(json.headers) ? json.headers.map((r) => r?.source) : [];
  if (sources.length !== 2 || !sources.includes("/(.+)") || !sources.includes("/")) {
    fail('tiene que haber dos reglas de cabeceras, con source "/(.+)" (todo menos la página de inicio) y "/" (la página de inicio)');
    return;
  }
  for (const rule of json.headers) {
    const home = rule.source === "/";
    checkHeaderRule(rule, home ? HOME_CSP : CSP, home ? (msg) => fail(`${msg} (regla «/»)`) : fail);
  }
  const rest = headerMap(json.headers.find((r) => r.source === "/(.+)"));
  const home = headerMap(json.headers.find((r) => r.source === "/"));
  for (const key of new Set([...rest.keys(), ...home.keys()])) {
    const [a, b] = key === "content-security-policy"
      ? [cspText(rest.get(key)), cspText(home.get(key), { without: "script-src" })]
      : [rest.get(key), home.get(key)];
    if (a !== b) fail(`las dos reglas de cabeceras tienen que ser iguales salvo script-src de «/»: ${key} difiere («${rest.get(key) ?? "falta"}» frente a «${home.get(key) ?? "falta"}»)`);
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

/** Una CSP en forma comparable (directivas y orígenes ordenados), sin la directiva [without]. */
function cspText(value, { without } = {}) {
  if (typeof value !== "string") return value;
  return value
    .split(";")
    .map((d) => d.trim().split(/\s+/).filter(Boolean))
    .filter((d) => d.length > 0 && d[0] !== without)
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
 * Las API de red y de almacenamiento (y la ejecución de texto) que el programa de la página de inicio no puede
 * usar (CA-025-12, plan §6.1). Es la lista de lo que se busca, no de lo permitido: el programa solo puede usar
 * `localStorage` (el idioma elegido, CA-025-09) y `history.replaceState` (quitar el `#` de la dirección, plan
 * §7.2); cualquier otra forma de pedir algo a la red o de guardar algo en el navegador falla.
 */
const FORBIDDEN_APIS = [
  [/\bfetch\s*\(/, "fetch("],
  [/\bXMLHttpRequest\b/, "XMLHttpRequest"],
  [/\bsendBeacon\b/, "navigator.sendBeacon"],
  [/\bWebSocket\b/, "WebSocket"],
  [/\bWebTransport\b/, "WebTransport"],
  [/\bEventSource\b/, "EventSource"],
  [/\bRTC(?:PeerConnection|DataChannel)\b/, "WebRTC"],
  [/\bnew\s+Request\b/, "new Request"],
  [/\bimportScripts\b/, "importScripts"],
  [/\bimport\s*\(/, "import() dinámico"],
  [/\b(?:Shared)?Worker\s*\(/, "Worker"],
  [/\bserviceWorker\b/, "serviceWorker"],
  [/\bBroadcastChannel\b/, "BroadcastChannel"],
  [/\bpostMessage\b/, "postMessage"],
  [/\bwindow\.open\b/, "window.open"],
  [/\bnew\s+Image\b/, "new Image"],
  [/\bsessionStorage\b/, "sessionStorage"],
  [/\bindexedDB\b/, "indexedDB"],
  [/\bcookie/i, "cookies"],
  [/\bcaches\b/, "Cache Storage"],
  [/\bnavigator\.storage\b/, "navigator.storage"],
  [/\bpushState\b/, "history.pushState"],
  [/\beval\s*\(/, "eval"],
  [/\bnew\s+Function\b/, "new Function"],
  [/\bdocument\.write/, "document.write"],
];

/** Una dirección `data:` con su tipo (`data:image/png;…`); `{data:x}` del código minificado no lo es. */
const DATA_URL = /\bdata:\s*[a-z]+\/[a-z0-9.+-]+[;,]/i;

/** Atributos que cargan un recurso (además de `src` del programa y `href` de la hoja de estilo). */
const RESOURCE_ATTRS = ["src", "srcset", "poster", "data", "action", "formaction", "background", "xlink:href", "ping", "manifest"];

/** Los titulares que juegan con el nombre y usan la palabra «una» (CA-025-14: lista cerrada). */
const NAME_HEADLINES = new Set(["heroTitle", "oneTitle", "endTitle"]);
/** `metaTitle` es «{appName} — <titular>»: solo se admite la segunda mitad. */
const META_TITLE_SEPARATOR = " — ";

/** Las rutas de [dir] (relativas, con «/»), recursivas. */
const filesOf = (dir) => [...walk(dir)].map((f) => relative(dir, f).split(sep).join("/"));

/**
 * El segundo juego de reglas (spec 025, CA-025-12 y CA-025-14; plan §6.1): la página de inicio, que construye
 * Vite y sí lleva un programa. Las otras cuatro páginas siguen con las de `checkSite`, sin cambios. Comprueba
 * `dist/` entera por patrón y cuenta (la página, un programa y una hoja de estilo en `assets/`, nada más que
 * lo de las otras cuatro), la página (programa solo del propio origen y por `src`; sin estilos ni manejadores
 * en línea; sin `data:`), la hoja de estilo, el programa (sin API de red ni de almacenamiento salvo las
 * admitidas, sin mapas) y el nombre de la app a mano en las fuentes de `landing/home/`.
 */
export function checkHome(paths = defaultPaths(), { dist = paths.out } = {}) {
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

  // Archivos: lo de las otras cuatro páginas, la página de inicio y un programa y una hoja en assets/.
  const others = new Set([...site.files.keys(), ...FONT_DIRS.map((d) => `fonts/${d}/OFL.txt`), ...FONT_FILES.map((f) => `fonts/${f.dir}/${f.file}`)]);
  const found = existsSync(dist) ? filesOf(dist) : [];
  const assets = { js: [], css: [] };
  for (const f of found) {
    if (others.has(f) || f === HOME_PAGE) continue;
    const asset = /^assets\/[A-Za-z0-9_-]+\.(js|css)$/.exec(f);
    if (asset) assets[asset[1]].push(f);
    else if (f.endsWith(".map")) errors.push(`${f}: mapa de código en la web publicada (CA-025-12)`);
    else if (f.endsWith(".html")) errors.push(`${f}: página HTML de más (solo las cuatro de siempre y la de inicio)`);
    else errors.push(`${f}: archivo no esperado en dist/ (solo un programa y una hoja de estilo en assets/ para la página de inicio)`);
  }
  for (const [kind, list] of Object.entries(assets)) {
    if (list.length !== 1) errors.push(`assets/: tiene ${list.length} archivo(s) .${kind} (tiene que haber uno: ${list.join(", ") || "ninguno"})`);
  }
  const js = assets.js.length === 1 ? assets.js[0] : null;
  const css = assets.css.length === 1 ? assets.css[0] : null;

  if (!found.includes(HOME_PAGE)) errors.push(`${HOME_PAGE}: falta la página de inicio (¿se ejecutó landing/build.mjs?)`);
  else checkHomePage(HOME_PAGE, readFileSync(join(dist, HOME_PAGE), "utf8"), { js, css }, errors);
  if (css) checkHomeCss(css, readFileSync(join(dist, css), "utf8"), errors);
  if (js) checkProgram(js, readFileSync(join(dist, js), "utf8"), errors);

  checkHomeName(paths, identity, errors);
  return errors;
}

/** La página de inicio construida (`dist/index.html`). */
function checkHomePage(file, html, { js, css }, errors) {
  const t = tags(html);
  const fail = (msg) => errors.push(`${file}: ${msg}`);

  if (!/<html\s[^>]*\blang="[a-z]{2,3}(-[A-Za-z0-9]+)?"/.test(html)) fail("el <html> no lleva lang");
  const viewport = t.find((x) => x.name === "meta" && x.attrs.name === "viewport");
  if (!viewport) fail("falta <meta name=\"viewport\">");
  else if (/user-scalable|maximum-scale|minimum-scale/i.test(viewport.attrs.content ?? "")) fail(`el viewport limita el zoom (${viewport.attrs.content}): 1.4.4`);
  const title = /<title>([^<]*)<\/title>/.exec(html);
  if (!title || !title[1].trim()) fail("falta el <title>");

  // El programa: uno, del propio origen, por src, sin nada escrito dentro.
  const scripts = t.filter((x) => x.name === "script" && !x.closing);
  if (scripts.length !== 1) fail(`tiene ${scripts.length} <script> (tiene que haber uno: el programa de assets/)`);
  for (const s of scripts) {
    const close = t.find((x) => x.closing && x.name === "script" && x.start >= s.end);
    if (!close || html.slice(s.end, close.start).trim() !== "") fail("un <script> con código escrito dentro de la página (los programas, solo por src)");
    const src = s.attrs.src ?? "";
    if (s.attrs.type !== "module") fail(`un <script> que no es type="module" («${s.attrs.type ?? ""}»)`);
    if (!src) fail("un <script> sin src (los programas, solo del propio origen y por src)");
    else if (!isLocal(src)) fail(`un <script> de otro origen («${src}»)`);
    else if (js && src !== `/${js}`) fail(`el <script> no carga el programa de assets/ («${src}» en lugar de «/${js}»)`);
  }

  for (const x of t) {
    if (x.closing) continue;
    for (const [attr, value] of Object.entries(x.attrs)) {
      if (/^on/.test(attr)) fail(`<${x.name}> lleva el manejador en línea ${attr} (la CSP lo bloquearía)`);
      if (attr === "style") fail(`<${x.name}> lleva style en línea (la CSP lo bloquearía)`);
      if (attr === "srcdoc") fail(`<${x.name}> lleva srcdoc`);
      if (/^\s*data:/i.test(value) || /url\(\s*['"]?\s*data:/i.test(value)) fail(`<${x.name} ${attr}> con una dirección data: (cada recurso, su archivo)`);
      if (RESOURCE_ATTRS.includes(attr) && x.name !== "script") {
        for (const url of attr === "srcset" ? value.split(",").map((s) => s.trim().split(/\s+/)[0]) : [value]) {
          if (url && !isLocal(url)) fail(`<${x.name} ${attr}> de otro origen («${url}»)`);
        }
      }
    }
    if (x.name === "style") fail("tiene un <style> en línea (la CSP lo bloquearía)");
    else if (FRAMES.includes(x.name)) fail(`tiene un <${x.name}> (nada incrustado)`);
    else if (x.name === "form") fail("tiene un <form> (la web no tiene formularios)");
    else if (x.name === "base") fail("tiene un <base>");
    else if (x.name === "meta" && "http-equiv" in x.attrs) fail("tiene un <meta http-equiv>");
    else if (x.name === "link") {
      const href = x.attrs.href ?? "";
      if (x.attrs.rel !== "stylesheet") fail(`<link rel="${x.attrs.rel ?? ""}"> no admitido (solo la hoja de estilo de assets/)`);
      else if (!href || !isLocal(href)) fail(`<link> a otro origen («${href}»): la web no usa recursos de terceros`);
      else if (css && href !== `/${css}`) fail(`el <link> no carga la hoja de estilo de assets/ («${href}» en lugar de «/${css}»)`);
    } else if (x.name === "a" && /^\s*(javascript|data|vbscript):/i.test(x.attrs.href ?? "")) {
      fail(`un enlace con ${(x.attrs.href ?? "").trim().split(":")[0]}:`);
    }
  }
  for (const re of ANALYTICS) if (re.test(html)) fail(`rastro de analítica (${re})`);
}

/** La hoja de estilo de la página de inicio: sin recursos de otro origen, sin `data:` ni `@import`. */
function checkHomeCss(file, text, errors) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  const clean = text.replace(/\/\*[\s\S]*?\*\//g, "");
  if (/@import/i.test(clean)) fail("@import (la web no carga hojas de otro sitio)");
  for (const m of clean.matchAll(/url\(\s*(['"]?)([^)'"]*)\1\s*\)/gi)) {
    if (/^\s*data:/i.test(m[2])) fail(`url(${m[2].slice(0, 40)}…): dirección data: (cada recurso, su archivo)`);
    else if (!isLocal(m[2])) fail(`url(${m[2]}): recurso de otro origen`);
  }
  if (/sourceMappingURL/.test(text)) fail("apunta a un mapa de código (sourceMappingURL)");
  for (const re of ANALYTICS) if (re.test(text)) fail(`rastro de analítica (${re})`);
}

/** El programa construido: sin API de red ni de almacenamiento salvo las admitidas, sin `data:`, sin mapas. */
function checkProgram(file, code, errors) {
  const fail = (msg) => errors.push(`${file}: ${msg}`);
  for (const [re, api] of FORBIDDEN_APIS) {
    if (re.test(code)) fail(`usa ${api} (CA-025-12: solo localStorage para el idioma y history.replaceState)`);
  }
  if (DATA_URL.test(code)) fail("lleva una dirección data: (cada recurso, su archivo)");
  if (/sourceMappingURL/.test(code)) fail("apunta a un mapa de código (sourceMappingURL)");
  for (const re of ANALYTICS) if (re.test(code)) fail(`rastro de analítica (${re})`);
}

/**
 * El HTML que genera el programa de la página de inicio (las pantallas de la app, las escenas), que no está en
 * `dist/` y `checkHome` no ve (plan §6.1): las mismas reglas de etiquetas que la página. Sin estilos ni
 * manejadores en línea, sin `<style>`, `<script>`, marcos, formularios, `<base>`, `<meta>` ni `<link>`, sin
 * `javascript:` ni `data:` y sin recursos ni enlaces de otro origen (los rótulos de las tiendas se comprueban
 * aparte, en `stores.js`). Devuelve los errores, con [label] delante.
 */
export function checkMarkup(label, html) {
  const errors = [];
  const fail = (msg) => errors.push(`${label}: ${msg}`);
  for (const x of tags(html)) {
    if (x.closing) continue;
    for (const [attr, value] of Object.entries(x.attrs)) {
      if (/^on/.test(attr)) fail(`<${x.name}> lleva el manejador en línea ${attr}`);
      if (attr === "style") fail(`<${x.name}> lleva style en línea (la CSP lo bloquearía)`);
      if (attr === "srcdoc") fail(`<${x.name}> lleva srcdoc`);
      if (/^\s*(javascript|vbscript):/i.test(value)) fail(`<${x.name} ${attr}> con ${value.trim().split(":")[0]}:`);
      if (/^\s*data:/i.test(value) || /url\(\s*['"]?\s*data:/i.test(value)) fail(`<${x.name} ${attr}> con una dirección data:`);
      if ((RESOURCE_ATTRS.includes(attr) || attr === "href") && value && !isLocal(value)) fail(`<${x.name} ${attr}> de otro origen («${value}»)`);
    }
    if (["style", "script", "base", "meta", "link", "form"].includes(x.name) || FRAMES.includes(x.name)) fail(`tiene un <${x.name}>`);
  }
  return errors;
}

/**
 * El nombre de la app escrito a mano en las fuentes de la página de inicio (P7, CA-025-14): la plantilla, la
 * configuración de Vite y `src/` (sin `gen/`, que se genera desde la identidad, ni `public/`). En los textos
 * (`strings.*.json`) se mira cada valor, y los titulares que juegan con el nombre (`heroTitle`, `oneTitle`,
 * `endTitle` y la segunda mitad de `metaTitle`) se admiten por lista cerrada.
 */
function checkHomeName(paths, identity, errors) {
  if (!existsSync(paths.homeDir)) return;
  const skip = new Set(["gen", "public", "node_modules"]);
  const names = [identity.displayName, identity.wordmark];
  const report = (where, name) => errors.push(`${where}: el nombre de la app «${name}» está escrito a mano (sale de app/identity.yaml, P7)`);
  for (const rel of filesOf(paths.homeDir)) {
    if (skip.has(rel.split("/")[0]) || !/\.(html|m?js|css|json)$/.test(rel)) continue;
    const text = readFileSync(join(paths.homeDir, rel), "utf8");
    const label = `landing/home/${rel}`;
    if (/(^|\/)strings\.[a-z]+\.json$/.test(rel)) {
      let json;
      try {
        json = JSON.parse(text);
      } catch (e) {
        errors.push(`${label}: no es JSON válido (${e.message})`);
        continue;
      }
      for (const [key, value] of stringValues(json)) {
        if (NAME_HEADLINES.has(key)) continue;
        const checked = key === "metaTitle" && value.includes(META_TITLE_SEPARATOR) ? value.slice(0, value.indexOf(META_TITLE_SEPARATOR)) : value;
        for (const name of names) if (mentionsName(checked, name)) report(`${label} («${key}»)`, name);
      }
      continue;
    }
    text.split("\n").forEach((line, i) => {
      for (const name of names) if (mentionsName(line, name)) report(`${label}:${i + 1}`, name);
    });
  }
}

/** Los textos de un JSON de textos, con su clave (la ruta con puntos: `alt.icon`, `sample.tasks.0`). */
function* stringValues(value, key = "") {
  if (typeof value === "string") yield [key, value];
  else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) yield* stringValues(v, key ? `${key}.${k}` : k);
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
  const needed = [...REQUIRED_PAGES, "tokens.css", "site.css", NOTICES_FILE];
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
  for (const page of REQUIRED_PAGES) {
    if (missing.has(page)) continue;
    checkPage(page, readFileSync(join(dist, page), "utf8"), site.meta.get(page), errors);
  }
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
