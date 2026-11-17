// Construye la web de la app (spec 023, CA-023-03, 04, 13 a 17): la política de privacidad, las licencias de
// terceros, la Ayuda y la página de error, en español e inglés en la misma dirección, sin dependencias y con solo el programa de idioma (ADR-0028); y, con
// Vite, la página de inicio (spec 025, ADR-0027) desde `landing/home/`.
//
//   npm ci --ignore-scripts      (una vez, en landing/)
//   node landing/build.mjs       escribe landing/dist/
//
// Las cuatro páginas usan solo módulos de Node (P11); Vite se carga solo para la de inicio. Lee `app/identity.yaml` (el nombre,
// P7), `design/tokens.json` (colores, fuentes y medidas, P12), los títulos de las ARB, el texto de la
// política (`docs/legal/privacy-policy.md`, la única copia, CA-023-04), el archivo de avisos de terceros
// (`landing/third-party-notices.txt`, CA-023-16), el de la propia web (`landing/web-notices.txt`, CA-025-18) y `landing/src/` (textos y Ayuda). Falla cerrada:
// lo que no entiende (Markdown fuera del subconjunto, un enlace raro, un `{…}` sin sustituir, una
// clave que falta) detiene la construcción en lugar de publicar algo distinto de lo escrito.
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export class BuildError extends Error {}
export class MarkdownError extends BuildError {}

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "..");

/** Todas las rutas que usa la construcción; los tests las sustituyen por copias temporales. */
export function defaultPaths(repoRoot = REPO_ROOT) {
  const landingDir = join(repoRoot, "landing");
  return {
    repoRoot,
    landingDir,
    identity: join(repoRoot, "app/identity.yaml"),
    tokens: join(repoRoot, "design/tokens.json"),
    arbEs: join(repoRoot, "app/lib/l10n/app_es.arb"),
    arbEn: join(repoRoot, "app/lib/l10n/app_en.arb"),
    policy: join(repoRoot, "docs/legal/privacy-policy.md"),
    srcDir: join(landingDir, "src"),
    strings: join(landingDir, "src/strings.json"),
    siteCss: join(landingDir, "src/site.css"),
    langJs: join(landingDir, "src/lang.js"),
    helpEs: join(landingDir, "src/help.es.md"),
    helpEn: join(landingDir, "src/help.en.md"),
    notices: join(landingDir, "third-party-notices.txt"),
    webNotices: join(landingDir, "web-notices.txt"),
    buildFile: join(landingDir, "build.mjs"),
    vercelJson: join(landingDir, "vercel.json"),
    fontsDir: join(repoRoot, "app/assets/fonts"),
    homeDir: join(landingDir, "home"),
    out: join(landingDir, "dist"),
  };
}

// ─── Utilidades ──────────────────────────────────────────────────────────────────────────────────

/** El programa de idioma de las cuatro páginas (spec 026, ADR-0028): su archivo en `dist/` y su ruta absoluta. */
export const LANG_FILE = "lang.js";
export const LANG_SCRIPT = `/${LANG_FILE}`;

/** Escapa el texto para HTML (también en atributos). */
export const esc = (s) =>
  String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

/** `textMuted` → `text-muted`. */
export const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

const norm = (text) => text.replace(/\r\n?/g, "\n");

function readText(path, label) {
  try {
    return readFileSync(path, "utf8");
  } catch (e) {
    throw new BuildError(`${label}: no se puede leer (${e.code ?? e.message})`);
  }
}

/** Los huecos de identidad (CA-023-01): la misma lista cerrada que la puerta de publicación. */
const GAP_WORDS = "RESPONSABLE|CONTROLLER|CONTACTO|CONTACT|FECHA|DATE|WEB|WEBSITE";
export const gapPattern = () => new RegExp(`\\[\\s*(?:${GAP_WORDS})\\s*\\]`, "gi");
const GAP_ONLY = new RegExp(`^\\[\\s*(?:${GAP_WORDS})\\s*\\]$`, "i");

// ─── Identidad ───────────────────────────────────────────────────────────────────────────────────

/** Lee `identity.yaml` con un lector mínimo: solo `clave: "texto"` y comentarios; lo demás falla. */
export function readIdentity(text, label = "identity.yaml") {
  const out = {};
  norm(text)
    .split("\n")
    .forEach((line, i) => {
      if (/^\s*(#.*)?$/.test(line)) return;
      const m = /^([A-Za-z][A-Za-z0-9]*):\s*"([^"\\]*)"\s*(#.*)?$/.exec(line);
      if (!m) {
        throw new BuildError(
          `${label}, línea ${i + 1}: no sé leer «${line.trim()}» (solo «clave: "texto"» entre comillas y comentarios)`,
        );
      }
      if (m[1] in out) throw new BuildError(`${label}, línea ${i + 1}: «${m[1]}» está repetida`);
      out[m[1]] = m[2];
    });
  for (const key of ["displayName", "wordmark"]) {
    if (!out[key]) throw new BuildError(`${label}: falta «${key}»`);
  }
  return out;
}

// ─── Markdown (subconjunto con falla cerrada) ────────────────────────────────────────────────────

const mdFail = (msg) => {
  throw new MarkdownError(msg);
};

/** Un enlace admitido: `https:`, `mailto:`, relativo o `#…`. */
function checkUrl(url) {
  if (!url) mdFail("enlace vacío");
  if (/[\s"'<>`\\\u0000-\u001f]/.test(url)) mdFail(`enlace no admitido (caracteres no válidos): «${url}»`);
  if (url.startsWith("#")) {
    if (!/^#[A-Za-z0-9_-]+$/.test(url)) mdFail(`enlace no admitido: «${url}»`);
    return { external: false };
  }
  if (url.startsWith("//")) mdFail(`enlace no admitido (sin protocolo, a otro sitio): «${url}»`);
  const scheme = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(url);
  if (!scheme) return { external: false }; // relativo
  const name = scheme[1].toLowerCase();
  if (name === "https") {
    const authority = /^https:\/\/([^/?#]*)/i.exec(url)?.[1];
    if (!authority || authority.includes("@")) mdFail(`enlace https no admitido: «${url}»`);
    return { external: true };
  }
  if (name === "mailto") {
    if (url.length <= "mailto:".length) mdFail(`enlace mailto vacío: «${url}»`);
    return { external: false };
  }
  return mdFail(`enlace no admitido (solo https, mailto, relativos y #): «${url}»`);
}

function inline(src, gaps) {
  let out = "";
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === "`") {
      if (src[i + 1] === "`") mdFail("no se admiten los acentos graves dobles");
      const end = src.indexOf("`", i + 1);
      if (end < 0) mdFail(`código sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<code>${esc(src.slice(i + 1, end))}</code>`;
      i = end + 1;
    } else if (c === "\\") {
      mdFail("no se admite la barra invertida");
    } else if (c === "!" && src[i + 1] === "[") {
      mdFail("no se admiten imágenes");
    } else if (c === "*" && src[i + 1] === "*") {
      const end = src.indexOf("**", i + 2);
      if (end < 0 || end === i + 2) mdFail(`negrita sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<strong>${inline(src.slice(i + 2, end), gaps)}</strong>`;
      i = end + 2;
    } else if (c === "*") {
      let end = i + 1;
      while (end < src.length && !(src[end] === "*" && src[end - 1] !== "*" && src[end + 1] !== "*")) end++;
      if (end >= src.length || end === i + 1) mdFail(`cursiva sin cerrar: «${src.slice(i, i + 30)}»`);
      out += `<em>${inline(src.slice(i + 1, end), gaps)}</em>`;
      i = end + 1;
    } else if (c === "[") {
      const close = src.indexOf("]", i + 1);
      if (close < 0) mdFail(`corchete sin cerrar: «${src.slice(i, i + 30)}»`);
      const text = src.slice(i + 1, close);
      if (src[close + 1] === "(") {
        const endUrl = src.indexOf(")", close + 2);
        if (endUrl < 0) mdFail(`enlace sin cerrar: «${src.slice(i, i + 40)}»`);
        const url = src.slice(close + 2, endUrl);
        if (!text.trim()) mdFail(`enlace sin texto: «${url}»`);
        if (text.includes("[")) mdFail(`enlace con corchetes dentro: «${text}»`);
        const { external } = checkUrl(url);
        const rel = external ? ' rel="noopener noreferrer"' : "";
        out += `<a href="${esc(url)}"${rel}>${inline(text, gaps)}</a>`;
        i = endUrl + 1;
      } else {
        const group = src.slice(i, close + 1);
        if (!GAP_ONLY.test(group)) {
          mdFail(`texto entre corchetes que no es un hueco de identidad ni un enlace: «${group}»`);
        }
        gaps.push(group);
        out += esc(group);
        i = close + 1;
      }
    } else {
      out += esc(c);
      i++;
    }
  }
  return out;
}

/** Falla con lo que el subconjunto no admite al empezar (o continuar) un bloque. */
function rejectUnsupported(line) {
  if (/^ {4,}\S/.test(line)) mdFail("no se admite el código con sangría");
  if (/^\s*(```|~~~)/.test(line)) mdFail("no se admiten los bloques de código");
  if (/^\|/.test(line) || (line.includes("-") && /^[ |:-]*\|[ |:-]*$/.test(line))) {
    mdFail("no se admiten las tablas");
  }
  if (/^\s*(-{3,}|\*{3,}|_{3,}|=+)\s*$/.test(line)) {
    mdFail("no se admiten las líneas horizontales ni los encabezados subrayados");
  }
  if (/^\s*\d+[.)]\s/.test(line)) mdFail("no se admiten las listas numeradas");
  if (/^\s*[*+]\s/.test(line)) mdFail("las listas van con «- » (no con «*» ni «+»)");
  if (/^#{4,}(\s|$)/.test(line)) mdFail("solo se admiten los encabezados de «#» a «###»");
}

/**
 * El ancla de una sección (spec 026, CA-026-04; plan §2.2): el prefijo del idioma [lang] y el titular [title] en
 * minúsculas, sin acentos, con lo que no es letra o número convertido en «-» y sin «-» repetidos ni en los extremos
 * (`es-quien-es-el-responsable`). Estable mientras no cambie el titular. Falla si no queda nada.
 */
export function sectionAnchor(lang, title) {
  const slug = title
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "-")
    .replace(/^-+|-+$/g, "");
  if (!slug) mdFail(`la sección «${title}» no da ancla (sin letras ni números)`);
  return `${lang}-${slug}`;
}

/**
 * Convierte [md] (el subconjunto: encabezados `#`–`###`, párrafos, listas con «- » y anidadas,
 * citas, **negrita**, *cursiva*, `código` y enlaces) a HTML. [shift] desplaza el nivel de los
 * encabezados; [firstHeadingAttrs] son los atributos del primero. Con [anchors] (`es` o `en`), cada sección
 * (`## …`) lleva su ancla (`sectionAnchor`) y `tabindex="-1"`, para que el índice le pase el foco; dos con la
 * misma ancla fallan. Devuelve el HTML, los encabezados que leyó (las secciones, con `id` y el texto sin marcas,
 * `label`) y los huecos de identidad que dejó tal cual.
 */
export function convertMarkdown(md, { shift = 0, firstHeadingAttrs = "", anchors = null } = {}) {
  const text = norm(md);
  if (text.includes("\t")) mdFail("no se admiten los tabuladores");
  const placeholder = /\{[^{}\n]*\}/.exec(text);
  if (placeholder) mdFail(`marcador sin sustituir: ${placeholder[0]}`);

  const lines = text.split("\n");
  const blocks = [];
  const headings = [];
  const gaps = [];
  let firstHeading = true;
  let i = 0;

  const startsBlock = (line) => /^#/.test(line) || /^>/.test(line) || /^- /.test(line);

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "") {
      i++;
      continue;
    }
    rejectUnsupported(line);

    const heading = /^(#{1,3}) +(\S.*)$/.exec(line);
    if (heading) {
      const level = heading[1].length + shift;
      const title = heading[2].trim();
      let attrs = firstHeading && firstHeadingAttrs ? ` ${firstHeadingAttrs}` : "";
      firstHeading = false;
      const content = inline(title, gaps);
      if (anchors && heading[1].length === 2) {
        const id = sectionAnchor(anchors, title);
        const twin = headings.find((h) => h.id === id);
        if (twin) mdFail(`dos secciones con la misma ancla, ${id}: «${twin.text}» y «${title}»`);
        attrs += ` id="${id}" tabindex="-1"`;
        headings.push({ level, text: title, id, label: content.replace(/<[^>]*>/g, "") });
      } else {
        headings.push({ level, text: title });
      }
      blocks.push(`<h${level}${attrs}>${content}</h${level}>`);
      i++;
      continue;
    }
    if (/^#/.test(line)) mdFail(`encabezado no válido: «${line.slice(0, 30)}»`);

    if (/^>/.test(line)) {
      const parts = [];
      while (i < lines.length && /^>/.test(lines[i])) {
        const content = lines[i].replace(/^> ?/, "");
        if (content.trim() === "") mdFail("no se admiten las citas con varios párrafos");
        parts.push(content.trim());
        i++;
      }
      blocks.push(`<blockquote>\n<p>${inline(parts.join(" "), gaps)}</p>\n</blockquote>`);
      continue;
    }

    if (/^ *- /.test(line)) {
      const items = [];
      while (i < lines.length && lines[i].trim() !== "") {
        const l = lines[i];
        const item = /^( *)- (.*)$/.exec(l);
        if (item) {
          const indent = item[1].length;
          const prev = items.length ? items[items.length - 1].indent : -2;
          if (indent % 2 !== 0 || indent > prev + 2 || (items.length === 0 && indent !== 0)) {
            mdFail(`sangría no admitida en la lista (de dos en dos espacios): «${l.trim().slice(0, 30)}»`);
          }
          if (!item[2].trim()) mdFail("punto de lista vacío");
          rejectUnsupported(item[2]);
          items.push({ indent, text: item[2].trim() });
        } else if (/^ +\S/.test(l)) {
          const last = items[items.length - 1];
          if (l.length - l.trimStart().length !== last.indent + 2) {
            mdFail(`sangría no admitida en la continuación de un punto: «${l.trim().slice(0, 30)}»`);
          }
          rejectUnsupported(l.trim());
          last.text += ` ${l.trim()}`;
        } else if (startsBlock(l)) {
          break;
        } else {
          mdFail(`línea sin sangría tras una lista: «${l.slice(0, 30)}»`);
        }
        i++;
      }
      blocks.push(renderItems(items, 0, 0, gaps)[0]);
      continue;
    }

    const parts = [];
    while (i < lines.length && lines[i].trim() !== "" && !startsBlock(lines[i])) {
      rejectUnsupported(lines[i]);
      if (/^\s/.test(lines[i])) mdFail(`sangría inesperada: «${lines[i].trim().slice(0, 30)}»`);
      parts.push(lines[i].trim());
      i++;
    }
    blocks.push(`<p>${inline(parts.join(" "), gaps)}</p>`);
  }
  return { html: blocks.join("\n"), headings, gaps };
}

function renderItems(items, idx, indent, gaps) {
  const li = [];
  while (idx < items.length && items[idx].indent === indent) {
    let inner = inline(items[idx].text, gaps);
    idx++;
    if (idx < items.length && items[idx].indent > indent) {
      const [nested, next] = renderItems(items, idx, items[idx].indent, gaps);
      inner += `\n${nested}`;
      idx = next;
    }
    li.push(`<li>${inner}</li>`);
  }
  return [`<ul>\n${li.join("\n")}\n</ul>`, idx];
}

// ─── La política ─────────────────────────────────────────────────────────────────────────────────

const ES_START = "# Política de privacidad (ES)";
const EN_START = "# Privacy policy (EN)";
const NOTES_START = "## Notas para la revisión";

/**
 * Las dos partes publicadas de `privacy-policy.md`, en Markdown: de «# Política de privacidad (ES)»
 * a «# Privacy policy (EN)» y de ahí a las notas. La cabecera y las notas de revisión no se publican.
 */
export function extractPolicy(md) {
  const lines = norm(md).split("\n");
  const find = (needle, exact) => {
    const at = [];
    lines.forEach((l, i) => {
      if (exact ? l === needle : l.startsWith(needle)) at.push(i);
    });
    if (at.length === 0) throw new BuildError(`la política: no está la línea «${needle}»`);
    if (at.length > 1) throw new BuildError(`la política: «${needle}» aparece más de una vez`);
    return at[0];
  };
  const es = find(ES_START, true);
  const en = find(EN_START, true);
  const notes = find(NOTES_START, false);
  if (!(es < en && en < notes)) {
    throw new BuildError("la política: el orden tiene que ser español, inglés y notas de revisión");
  }
  const half = (from, to) =>
    lines
      .slice(from, to)
      .join("\n")
      .replace(/\n+---\s*$/, "")
      .trim();
  return { es: half(es, en), en: half(en, notes) };
}

/** Un enlace `https:` (la política) y cualquier enlace `[texto](destino)` (la Ayuda, que enlaza a la política). */
const LINK_HTTPS = /\]\(https:/g;
const LINK_ANY = /\]\([^)]*\)/g;

/** Secciones `##` de una parte con lo que hay que mantener igual en las dos lenguas. */
function sectionSignatures(half, linkPattern = LINK_HTTPS) {
  const sections = [];
  let cur = null;
  const flush = () => {
    if (cur) sections.push(cur);
  };
  let block = [];
  const closeBlock = () => {
    if (!cur || block.length === 0) return;
    if (!block.every((l) => /^\s*- /.test(l))) cur.paragraphs++;
    block = [];
  };
  for (const line of half.split("\n")) {
    if (line.startsWith("## ")) {
      closeBlock();
      flush();
      cur = { title: line.slice(3).trim(), bullets: 0, paragraphs: 0, gaps: [], links: 0 };
      continue;
    }
    if (!cur) continue;
    if (line.trim() === "") {
      closeBlock();
      continue;
    }
    if (/^\s*- /.test(line)) cur.bullets++;
    block.push(line);
    for (const g of line.match(gapPattern()) ?? []) cur.gaps.push(gapKind(g));
    cur.links += (line.match(linkPattern) ?? []).length;
  }
  closeBlock();
  flush();
  return sections;
}

/** `[CONTACTO]` y `[CONTACT]` son el mismo hueco en las dos lenguas. */
function gapKind(g) {
  const word = g.replace(/[\[\]\s]/g, "").toUpperCase();
  return (
    { RESPONSABLE: "RESPONSABLE", CONTROLLER: "RESPONSABLE", CONTACTO: "CONTACTO", CONTACT: "CONTACTO", FECHA: "FECHA", DATE: "FECHA", WEB: "WEB", WEBSITE: "WEB" }[word] ?? word
  );
}

/**
 * CA-023-03: la parte española y la inglesa tienen las mismas secciones, en el mismo orden, y en cada
 * una los mismos puntos (viñetas, párrafos, enlaces y huecos). Devuelve la lista de diferencias.
 */
export function comparePolicyStructure(md) {
  const { es, en } = extractPolicy(md);
  return compareSignatures(sectionSignatures(es), sectionSignatures(en));
}

/** Las diferencias entre las secciones de la parte española [a] y las de la inglesa [b]. */
function compareSignatures(a, b) {
  const errors = [];
  if (a.length !== b.length) {
    errors.push(`la parte española tiene ${a.length} secciones y la inglesa ${b.length}`);
    return errors;
  }
  a.forEach((s, i) => {
    const t = b[i];
    const where = `sección ${i + 1} («${s.title}» / «${t.title}»)`;
    if (s.bullets !== t.bullets) {
      errors.push(`${where}: ${s.bullets} viñetas en español y ${t.bullets} en inglés`);
    }
    if (s.paragraphs !== t.paragraphs) {
      errors.push(`${where}: ${s.paragraphs} párrafos en español y ${t.paragraphs} en inglés`);
    }
    if (s.links !== t.links) {
      errors.push(`${where}: ${s.links} enlaces en español y ${t.links} en inglés`);
    }
    if (s.gaps.join(",") !== t.gaps.join(",")) {
      errors.push(`${where}: huecos de identidad distintos (${s.gaps.join(" ")} / ${t.gaps.join(" ")})`);
    }
  });
  return errors;
}

const DATE_LINE = {
  es: /^\*\*Última actualización:\*\*[ \t]*(.+)$\n?/gm,
  en: /^\*\*Last updated:\*\*[ \t]*(.+)$\n?/gm,
};
const DATE_KEY = { es: "fecha", en: "date" };

/**
 * El índice de una mitad (spec 026, CA-026-04; plan §2.2): «En esta página» (`webOnThisPage`, no es un encabezado)
 * y un enlace a cada sección de [headings], en orden.
 */
function tableOfContents(lang, s, headings) {
  const sections = headings.filter((h) => h.id);
  const name = `${lang}-toc`;
  const clash = sections.find((h) => h.id === name);
  if (clash) throw new BuildError(`la sección «${clash.text}» da el ancla ${name}, la del nombre del índice`);
  return [
    `<nav class="toc" aria-labelledby="${name}">`,
    `<p id="${name}" class="toc__name">${esc(s[lang].webOnThisPage)}</p>`,
    "<ul>",
    ...sections.map((h) => `<li><a href="#${h.id}">${h.label}</a></li>`),
    "</ul>",
    "</nav>",
  ].join("\n");
}

/** [html] (que empieza por el `<h2>` de la mitad, en su propia línea) con [extra] justo después del `<h2>`. */
function afterTitle(html, extra) {
  const nl = html.indexOf("\n");
  return nl < 0 ? [html, ...extra].join("\n") : [html.slice(0, nl), ...extra, html.slice(nl + 1)].join("\n");
}

/**
 * El HTML de las dos partes de la política con el nombre de la app, y los huecos que dejan. Desde la spec 026
 * (CA-026-04) la línea de «última actualización» de cada parte sale del cuerpo y va bajo el título con
 * `webLastUpdated`, seguida del índice; [s] son los textos de `strings.json`.
 */
export function policyFragments(md, appName, s) {
  const { es, en } = extractPolicy(md);
  const result = {};
  for (const [lang, half] of [["es", es], ["en", en]]) {
    const text = half.replaceAll("{appName}", appName);
    const dates = [...text.matchAll(DATE_LINE[lang])];
    const line = lang === "es" ? "**Última actualización:**" : "**Last updated:**";
    if (dates.length === 0) throw new BuildError(`la política (${lang}): falta la línea «${line}»`);
    if (dates.length > 1) throw new BuildError(`la política (${lang}): la línea «${line}» aparece más de una vez`);
    const date = dates[0][1].trim();
    const converted = convertMarkdown(text.replace(DATE_LINE[lang], ""), {
      shift: 1,
      firstHeadingAttrs: HALF_TITLE_ATTRS(lang),
      anchors: lang,
    });
    // La fecha pasa por el mismo conversor (falla cerrada, huecos de identidad) y sale sin su párrafo.
    const dateHtml = convertMarkdown(date).html.replace(/^<p>|<\/p>$/g, "");
    const dateLine = `<p class="date">${fill(esc(s[lang].webLastUpdated), { [DATE_KEY[lang]]: dateHtml })}</p>`;
    const html = afterTitle(converted.html, [dateLine, tableOfContents(lang, s, converted.headings)]);
    result[lang] = { html, gaps: converted.gaps, date };
  }
  return result;
}

// ─── La Ayuda ────────────────────────────────────────────────────────────────────────────────────

/**
 * Quita los comentarios HTML de [md] (`<!-- … -->`): solo valen los que ocupan líneas enteras (empiezan
 * la línea y acaban con ella), de una o de varias líneas; cada uno deja una línea en blanco. Cualquier
 * otro uso (a mitad de un párrafo, anidado, sin cerrar o un cierre suelto) falla. Sirven para anotar
 * de qué spec sale cada sección de la Ayuda sin publicarlo.
 */
export function stripComments(md) {
  const out = [];
  let inside = false;
  for (const line of norm(md).split("\n")) {
    const open = line.indexOf("<!--");
    const close = line.indexOf("-->");
    if (!inside) {
      if (open < 0) {
        if (close >= 0) mdFail(`comentario: cierre «-->» sin abrir: «${line.trim().slice(0, 30)}»`);
        out.push(line);
        continue;
      }
      if (open !== 0) mdFail(`comentario que no empieza la línea: «${line.trim().slice(0, 30)}»`);
      if (line.indexOf("<!--", 4) >= 0) mdFail(`comentario anidado: «${line.trim().slice(0, 30)}»`);
      out.push("");
      if (close < 0) {
        inside = true;
        continue;
      }
      if (line.slice(close + 3).trim() !== "") mdFail(`comentario seguido de texto en la misma línea: «${line.trim().slice(0, 30)}»`);
    } else {
      if (open >= 0) mdFail(`comentario anidado: «${line.trim().slice(0, 30)}»`);
      if (close >= 0) {
        if (line.slice(close + 3).trim() !== "") mdFail(`comentario seguido de texto en la misma línea: «${line.trim().slice(0, 30)}»`);
        inside = false;
      }
    }
  }
  if (inside) mdFail("comentario sin cerrar («<!--» sin su «-->»)");
  return out.join("\n");
}

/**
 * El HTML de una mitad de la Ayuda ([lang] `es` o `en`) con el nombre de la app, y los huecos que deja.
 * Tiene que empezar por un único título `# …` (sale como `<h2 id="es|en">`, igual que la política) y
 * cada tema es un `## …` (`<h3>`). [label] es el archivo, para los mensajes.
 */
export function helpFragment(md, appName, lang, label, s) {
  try {
    const text = stripComments(md).replaceAll("{appName}", appName);
    const converted = convertMarkdown(text, { shift: 1, firstHeadingAttrs: HALF_TITLE_ATTRS(lang), anchors: lang });
    const levels = converted.headings.map((h) => h.level);
    if (levels[0] !== 2 || levels.filter((l) => l === 2).length !== 1) {
      throw new BuildError("tiene que empezar por un único título «# …» (y no llevar otro)");
    }
    // El índice, bajo el título (spec 026, CA-026-04).
    return { ...converted, html: afterTitle(converted.html, [tableOfContents(lang, s, converted.headings)]) };
  } catch (e) {
    if (e instanceof BuildError) throw new BuildError(`${label}: ${e.message}`);
    throw e;
  }
}

/** CA-023-17: la Ayuda en español y en inglés tiene las mismas secciones y los mismos puntos. */
export function compareHelpStructure(esMd, enMd) {
  return compareSignatures(
    sectionSignatures(stripComments(esMd), LINK_ANY),
    sectionSignatures(stripComments(enMd), LINK_ANY),
  );
}

// ─── El archivo de avisos de terceros ────────────────────────────────────────────────────────────

const VERSION_HEADER = /^Versión: (\d+\.\d+\.\d+\+\d+)$/;
const BUILD_HEADER =
  /^Compilación de main: ([0123456789abcdef]{40}) \(trabajo de publicación, modo testers, ejecución (\d{1,20})\)$/;

/**
 * El archivo de avisos (CA-023-16): una cabecera de una línea, una línea en blanco y el archivo que
 * emite `tools/check-licenses.sh`. La cabecera dice de dónde sale: `Versión: X.Y.Z+N` o
 * `Compilación de main: <sha> (trabajo de publicación, modo testers, ejecución <id>)`. Devuelve
 * `{ kind: "version", version, body }` o `{ kind: "build", sha, runId, body }`; lo demás falla.
 */
export function parseNotices(text, label = "third-party-notices.txt") {
  if (!text.trim()) throw new BuildError(`${label}: está vacío`);
  const nl = text.indexOf("\n");
  const first = nl < 0 ? text : text.slice(0, nl);
  let header;
  const version = VERSION_HEADER.exec(first);
  const build = BUILD_HEADER.exec(first);
  if (version) header = { kind: "version", version: version[1] };
  else if (build) header = { kind: "build", sha: build[1], runId: build[2] };
  else {
    throw new BuildError(
      `${label}: la primera línea tiene que ser la cabecera «Versión: X.Y.Z+N» o «Compilación de main: <sha> (trabajo de publicación, modo testers, ejecución <número>)» (es «${first.slice(0, 60)}»)`,
    );
  }
  if (nl < 0 || text[nl + 1] !== "\n") throw new BuildError(`${label}: tiene que haber una línea en blanco tras la cabecera`);
  const body = text.slice(nl + 2);
  if (!body.trim()) throw new BuildError(`${label}: sin cuerpo (falta el archivo de avisos tras la cabecera)`);
  if (!body.startsWith("Third-party notices")) {
    throw new BuildError(`${label}: tras la cabecera tiene que venir el archivo de avisos, que empieza por «Third-party notices»`);
  }
  return { ...header, body };
}

/** Un marcador de parte del archivo de avisos (la forma de `tools/check-licenses.sh`). */
const NOTICES_MARKER = /^===== (BEGIN|END) (\S+) =====$/;
/** El separador de avisos: exactamente 80 guiones, y solo dentro de la parte `NOTICES` (CL-027-3). */
const NOTICES_SEPARATOR = "-".repeat(80);
/** Cada línea de la cabecera de un aviso: un nombre de paquete, sin espacios ni caracteres de formato invisibles. */
const NOTICE_NAME = /^[^\s\p{Cf}]+$/u;
/** Las partes que no son secciones `assets/…`: no pueden reaparecer tras los avisos. */
const RESERVED_PARTS = new Set(["ENTRIES", "NOTICES"]);

/**
 * El archivo entero no puede llevar rutas de una carpeta personal de la máquina de compilación ni caracteres de
 * control (salvo salto de línea, retorno de carro y tabulador) o de dirección (spec 027, CA-027-04; CA-023-19).
 * `/home/runner/` es la carpeta de la CI, como en `check-package.sh`. Falla con `BuildError` y la línea.
 */
export function checkNoticesText(text, label = "third-party-notices.txt") {
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const where = `${label}, línea ${i + 1}`;
    const home = /\/home\/(?!runner\/)/.exec(line);
    const personal = /\/Users\//.exec(line) ?? home ?? /[A-Za-z]:\\Users\\/i.exec(line);
    if (personal) throw new BuildError(`${where}: lleva una ruta de una carpeta personal («${personal[0]}»)`);
    for (const c of line) {
      const n = c.codePointAt(0);
      const control = (n < 32 && c !== "\r" && c !== "\t") || (n >= 0x7f && n <= 0x9f);
      const bidi =
        (n >= 0x202a && n <= 0x202e) || (n >= 0x2066 && n <= 0x2069) || n === 0x200e || n === 0x200f || n === 0x2028 || n === 0x2029;
      if (control || bidi) {
        const code = `U+${n.toString(16).toUpperCase().padStart(4, "0")}`;
        throw new BuildError(`${where}: lleva un carácter de ${control ? "control" : "dirección"} (${code})`);
      }
    }
  }
}

/**
 * Analiza el cuerpo del archivo de avisos (spec 027, CA-027-05), ya con los finales de línea en `\n`: el
 * preámbulo (todo lo anterior a `===== BEGIN NOTICES =====`, con su `BEGIN/END ENTRIES`), los avisos de la parte
 * `NOTICES` agrupados por cabecera exacta (en el orden del archivo) y las secciones `assets/…` que van detrás.
 * Puro y sin listas escritas a mano (CL-027-6). [firstLine] es la línea del archivo en que empieza el cuerpo, para
 * los mensajes. Devuelve `{ preamble, groups: [{ names, notices }], sections: [{ path, text, gap }], tail }`, donde
 * `gap` son las líneas en blanco antes de la sección y `tail` las del final (solo para reconstruir el cuerpo con
 * `rebuildNoticesBody`). Cualquier estructura que no reconoce falla con `BuildError` (qué y en qué línea).
 */
export function parseNoticesBody(body, { label = "third-party-notices.txt", firstLine = 1 } = {}) {
  const lines = body.split("\n");
  const fail = (i, what) => {
    throw new BuildError(`${label}, línea ${firstLine + i}: ${what}`);
  };
  const marker = (line) => {
    const m = NOTICES_MARKER.exec(line);
    return m ? { kind: m[1], name: m[2] } : null;
  };
  const blank = (line) => line.trim() === "";

  // El preámbulo: hasta `BEGIN NOTICES`, con una sola pareja `BEGIN/END ENTRIES` (opcional) bien cerrada.
  let i = 0;
  let entries = "none"; // none → open → closed
  let entriesAt = -1;
  for (; i < lines.length; i++) {
    const m = marker(lines[i]);
    if (!m) continue;
    if (m.kind === "BEGIN" && m.name === "NOTICES") {
      if (entries === "open") fail(i, `la parte «NOTICES» empieza dentro de «ENTRIES» (anidada; «ENTRIES» se abrió en la línea ${firstLine + entriesAt})`);
      break;
    }
    if (m.name !== "ENTRIES") fail(i, `marcador «${lines[i]}» en el preámbulo (solo se admite la pareja «ENTRIES»)`);
    if (m.kind === "BEGIN") {
      if (entries === "open") fail(i, "«BEGIN ENTRIES» dentro de «ENTRIES» (anidada)");
      if (entries === "closed") fail(i, "una segunda pareja «ENTRIES»");
      entries = "open";
      entriesAt = i;
    } else {
      if (entries !== "open") fail(i, "«END ENTRIES» sin su «BEGIN ENTRIES»");
      entries = "closed";
    }
  }
  if (entries === "open") fail(entriesAt, "«BEGIN ENTRIES» sin su «END ENTRIES»");
  if (i >= lines.length) fail(lines.length - 1, "ningún aviso (falta la parte «===== BEGIN NOTICES =====»)");
  const noticesAt = i;
  const preamble = lines.slice(0, noticesAt).map((l) => `${l}\n`).join("");

  // Los avisos: trozos entre separadores de 80 guiones, hasta `END NOTICES`.
  const groups = [];
  const seen = new Map(); // clave de cabecera → línea de su primer aviso
  let chunk = [];
  let chunkAt = noticesAt + 1;
  const closeChunk = () => {
    if (chunk.length === 0) fail(chunkAt, "un aviso vacío (dos separadores seguidos, o uno junto a un marcador)");
    const sep = chunk.indexOf("");
    if (sep < 0) fail(chunkAt, "un aviso sin la línea en blanco que separa la cabecera del texto");
    if (sep === 0) fail(chunkAt, "un aviso con la cabecera vacía");
    const names = chunk.slice(0, sep);
    names.forEach((n, k) => {
      if (!NOTICE_NAME.test(n)) fail(chunkAt + k, `cabecera no válida («${n}»): un nombre de paquete por línea, sin espacios`);
    });
    const text = chunk.slice(sep + 1).join("\n");
    if (text.trim() === "") fail(chunkAt, `el aviso de «${names.join(", ")}» no tiene texto`);
    const key = names.join("\n");
    const last = groups.at(-1);
    if (last && last.names.join("\n") === key) last.notices.push(text);
    else {
      if (seen.has(key)) {
        fail(chunkAt, `la cabecera «${names.join(", ")}» reaparece lejos de su primer tramo (línea ${firstLine + seen.get(key)}): sus avisos tienen que ir seguidos`);
      }
      seen.set(key, chunkAt);
      groups.push({ names, notices: [text] });
    }
  };
  for (i = noticesAt + 1; i < lines.length; i++) {
    const line = lines[i];
    const m = marker(line);
    if (m) {
      if (m.kind === "BEGIN") fail(i, `«${line}» dentro de la parte «NOTICES» (anidada)`);
      if (m.name !== "NOTICES") fail(i, `«${line}» sin su «BEGIN ${m.name}» (dentro de la parte «NOTICES»)`);
      break;
    }
    if (line === NOTICES_SEPARATOR) {
      closeChunk();
      chunk = [];
      chunkAt = i + 1;
    } else chunk.push(line);
  }
  if (i >= lines.length) fail(noticesAt, "«BEGIN NOTICES» sin su «END NOTICES»");
  closeChunk();

  // Las secciones `assets/…`: cada una entre su `BEGIN` y su `END`; fuera de ellas, solo líneas en blanco.
  const sections = [];
  const paths = new Map();
  let gap = [];
  for (i += 1; i < lines.length; i++) {
    const line = lines[i];
    const m = marker(line);
    if (!m) {
      if (!blank(line)) fail(i, `texto fuera de una parte («${line.slice(0, 60)}»)`);
      gap.push(line);
      continue;
    }
    if (m.kind === "END") fail(i, `«${line}» sin su «BEGIN ${m.name}»`);
    if (m.name === "NOTICES") fail(i, "una segunda pareja «NOTICES»");
    if (RESERVED_PARTS.has(m.name)) fail(i, `«${line}» fuera del preámbulo`);
    if (paths.has(m.name)) fail(i, `la sección «${m.name}» está repetida (la primera, en la línea ${firstLine + paths.get(m.name)})`);
    paths.set(m.name, i);
    const begin = i;
    const text = [];
    for (i += 1; i < lines.length; i++) {
      const inner = marker(lines[i]);
      if (!inner) {
        text.push(lines[i]);
        continue;
      }
      if (inner.kind === "BEGIN") fail(i, `«${lines[i]}» dentro de la sección «${m.name}» (anidada)`);
      if (inner.name !== m.name) fail(i, `«${lines[i]}» sin su «BEGIN ${inner.name}» (dentro de la sección «${m.name}»)`);
      break;
    }
    if (i >= lines.length) fail(begin, `«BEGIN ${m.name}» sin su «END ${m.name}»`);
    if (text.join("\n").trim() === "") fail(begin, `la sección «${m.name}» no tiene texto`);
    sections.push({ path: m.name, text: text.join("\n"), gap });
    gap = [];
  }
  return { preamble, groups, sections, tail: gap };
}

/**
 * La inversa de `parseNoticesBody` (sin el preámbulo): desde `===== BEGIN NOTICES =====`, con las cabeceras, la
 * línea en blanco, el texto de cada aviso, los separadores y los marcadores de cada parte (CA-027-02 c).
 */
export function rebuildNoticesBody(parsed) {
  const lines = ["===== BEGIN NOTICES ====="];
  const notices = parsed.groups.flatMap((g) => g.notices.map((text) => [...g.names, "", text].join("\n")));
  lines.push(notices.join(`\n${NOTICES_SEPARATOR}\n`), "===== END NOTICES =====");
  for (const s of parsed.sections) lines.push(...s.gap, `===== BEGIN ${s.path} =====`, s.text, `===== END ${s.path} =====`);
  lines.push(...parsed.tail);
  return lines.join("\n");
}

/**
 * La ida y vuelta (spec 027, revisión de seguridad I-2): el preámbulo y lo reconstruido desde los grupos tienen que
 * dar el cuerpo tal cual. Si no, el analizador perdió, repitió o cambió algo y la construcción falla.
 */
export function assertNoticesRoundTrip(body, parsed, label = "third-party-notices.txt") {
  if (parsed.preamble + rebuildNoticesBody(parsed) === body) return;
  throw new BuildError(`${label}: los avisos agrupados no reconstruyen el archivo (el analizador perdió, repitió o cambió algo)`);
}

/**
 * Los avisos del código de terceros de la propia web (spec 025, CA-025-18): `landing/web-notices.txt`, escrito a
 * mano, en inglés. Empieza por «Third-party code in this website» y nombra cada paquete que va al navegador en
 * una línea `Package: <nombre> <versión>` (los tests la cruzan con `package.json`). Devuelve `{ body, packages }`.
 */
export function parseWebNotices(text, label = "web-notices.txt") {
  const body = norm(text);
  if (!body.trim()) throw new BuildError(`${label}: está vacío`);
  if (!body.startsWith("Third-party code in this website\n")) {
    throw new BuildError(`${label}: tiene que empezar por la línea «Third-party code in this website»`);
  }
  const packages = [...body.matchAll(/^Package: (\S+) (\S+)/gm)].map((m) => ({ name: m[1], version: m[2] }));
  if (packages.length === 0) throw new BuildError(`${label}: no nombra ningún paquete (líneas «Package: <nombre> <versión>»)`);
  return { body, packages };
}

// ─── Textos (strings.json) ───────────────────────────────────────────────────────────────────────

/** Las claves de `strings.json` y los marcadores que admite cada una (por idioma). */
const STRING_KEYS = {
  webPageTitle: { es: ["página", "appName"], en: ["page", "appName"] },
  webNotFoundTitle: { es: [], en: [] },
  webNotFoundBody: { es: [], en: [] },
  webContact: { es: [], en: [] },
  webLastUpdated: { es: ["fecha"], en: ["date"] },
  webBackHome: { es: [], en: [] },
  webLicensesVersion: { es: ["versión"], en: ["version"] },
  webLicensesLatestBuild: { es: [], en: [] },
  webLicensesInApp: { es: [], en: [] },
  webLicensesFile: { es: [], en: [] },
  webLanguageName: { es: [], en: [] },
  // Título del bloque de avisos del código de la web en /licenses (spec 025, CA-025-18).
  licensesWebTitle: { es: [], en: [] },
  // Nombre visible de la navegación del índice de la política y la Ayuda (spec 026, CA-026-04).
  webOnThisPage: { es: [], en: [] },
  // Recuento de cada grupo y enlace de saltar del bloque de avisos de /licenses (spec 027, CA-027-01 y 06).
  webNoticesCountOne: { es: [], en: [] },
  webNoticesCountMany: { es: ["n"], en: ["n"] },
  webNoticesSkip: { es: [], en: [] },
};
const LANG_ONLY = { webNoticesTitle: { en: [] } };

export function loadStrings(text, label = "strings.json") {
  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    throw new BuildError(`${label}: no es JSON válido (${e.message})`);
  }
  const top = Object.keys(json ?? {}).sort();
  if (top.join() !== "en,es") throw new BuildError(`${label}: tiene que tener solo «es» y «en» (tiene ${top.join(", ")})`);
  for (const lang of ["es", "en"]) {
    const spec = {};
    for (const [k, v] of Object.entries(STRING_KEYS)) spec[k] = v[lang];
    for (const [k, v] of Object.entries(LANG_ONLY)) if (v[lang]) spec[k] = v[lang];
    const obj = json[lang];
    for (const k of Object.keys(spec)) {
      if (typeof obj[k] !== "string") throw new BuildError(`${label}: falta «${lang}.${k}» (texto)`);
    }
    for (const [k, v] of Object.entries(obj)) {
      if (!(k in spec)) throw new BuildError(`${label}: «${lang}.${k}» no es una clave conocida`);
      for (const m of v.matchAll(/\{([^{}]*)\}/g)) {
        if (!spec[k].includes(m[1])) throw new BuildError(`${label}: «${lang}.${k}» lleva el marcador {${m[1]}}, que no admite`);
      }
    }
  }
  return json;
}

/**
 * Los textos de la landing que usan la cabecera y el pie de las cuatro páginas (spec 026, plan §1.5): una sola
 * fuente, `landing/home/src/shared/strings.{es,en}.json`, sin copia en `strings.json`.
 */
export const LANDING_STRING_KEYS = ["nav.home", "nav.download", "nav.lang", "footer.help", "footer.privacy", "footer.licenses", "footer.legal", "footer.nav"];

/**
 * Lee de los textos de la landing las claves de [LANDING_STRING_KEYS], con `{app}` sustituido por [appName]
 * (tal cual: sin interpretar `$&`). Falla si falta alguna, si no es un texto o si lleva otro marcador.
 * Devuelve `{ es: { nav: {…}, footer: {…} }, en: … }`.
 */
export function loadLandingStrings(paths, appName) {
  const out = {};
  for (const lang of ["es", "en"]) {
    const label = `home/src/shared/strings.${lang}.json`;
    const text = readText(join(paths.homeDir, "src/shared", `strings.${lang}.json`), label);
    let json;
    try {
      json = JSON.parse(text);
    } catch (e) {
      throw new BuildError(`${label}: no es JSON válido (${e.message})`);
    }
    out[lang] = {};
    for (const key of LANDING_STRING_KEYS) {
      const [group, leaf] = key.split(".");
      const value = json?.[group]?.[leaf];
      if (typeof value !== "string" || value.trim() === "") throw new BuildError(`${label}: falta «${key}» (texto)`);
      for (const m of value.matchAll(/\{([^{}]*)\}/g)) {
        if (m[1] !== "app") throw new BuildError(`${label}: «${key}» lleva el marcador {${m[1]}}, que no admite (solo {app})`);
      }
      (out[lang][group] ??= {})[leaf] = value.replaceAll("{app}", () => appName);
    }
  }
  return out;
}

export function fill(template, values) {
  return template.replace(/\{([^{}]+)\}/g, (m, name) => {
    if (!(name in values)) throw new BuildError(`marcador sin valor: ${m}`);
    return values[name];
  });
}

// ─── CSS de los tokens ───────────────────────────────────────────────────────────────────────────

const REM = 16;
const num = (n) => String(Number(n.toFixed(4)));
const dim = (v, toRem) => {
  if (v.unit === "px") return toRem ? `${num(v.value / REM)}rem` : `${num(v.value)}px`;
  return `${num(v.value)}${v.unit}`;
};
const familyValue = (list) => list.map((f, i) => (i === 0 ? `"${f}"` : f)).join(", ");

/** Las fuentes que se publican: archivo, carpeta de `app/assets/fonts/` y peso (según los tokens). */
export const FONT_FILES = [
  { family: "display", dir: "archivo", file: "Archivo-Variable.ttf", weight: "range" },
  { family: "mono", dir: "space_mono", file: "SpaceMono-Regular.ttf", weight: "regular" },
  { family: "mono", dir: "space_mono", file: "SpaceMono-Bold.ttf", weight: "bold" },
];
export const FONT_DIRS = [...new Set(FONT_FILES.map((f) => f.dir))];

/**
 * `tokens.css`: las variables de `design/tokens.json` (rem para texto y espacios) y las fuentes (las cuatro
 * páginas de contenido, sin dependencias; la de inicio trae sus propios estilos, los de la maqueta).
 */
export function tokensCss(tokens) {
  const vars = [];
  const emit = (name, value) => vars.push(`  --${name}: ${value};`);
  for (const [k, v] of Object.entries(tokens.color)) if (!k.startsWith("$")) emit(`color-${kebab(k)}`, v.$value);
  for (const [k, v] of Object.entries(tokens.font.family)) if (!k.startsWith("$")) emit(`font-family-${kebab(k)}`, familyValue(v.$value));
  for (const [k, v] of Object.entries(tokens.font.weight)) if (!k.startsWith("$")) emit(`font-weight-${kebab(k)}`, v.$value);
  for (const [k, v] of Object.entries(tokens.font.size)) if (!k.startsWith("$")) emit(`font-size-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.font.letterSpacing)) if (!k.startsWith("$")) emit(`font-letter-spacing-${kebab(k)}`, dim(v.$value, false));
  for (const [k, v] of Object.entries(tokens.space)) if (!k.startsWith("$")) emit(`space-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.size)) if (!k.startsWith("$")) emit(`size-${kebab(k)}`, dim(v.$value, true));
  for (const [k, v] of Object.entries(tokens.border.width)) if (!k.startsWith("$")) emit(`border-width-${kebab(k)}`, dim(v.$value, false));
  for (const [k, v] of Object.entries(tokens.border.radius)) if (!k.startsWith("$")) emit(`border-radius-${kebab(k)}`, dim(v.$value, false));

  const weights = Object.entries(tokens.font.weight).filter(([k]) => !k.startsWith("$")).map(([, v]) => v.$value);
  const faces = FONT_FILES.map((f) => {
    const family = tokens.font.family[f.family].$value[0];
    const weight =
      f.weight === "range" ? `${Math.min(...weights)} ${Math.max(...weights)}` : tokens.font.weight[f.weight].$value;
    return [
      "@font-face {",
      `  font-family: "${family}";`,
      `  src: url("/fonts/${f.dir}/${f.file}") format("truetype");`,
      `  font-weight: ${weight};`,
      "  font-display: swap;",
      "}",
    ].join("\n");
  });
  return [
    "/* Generado por landing/build.mjs desde design/tokens.json. No editar a mano. */",
    ...faces,
    ":root {",
    ...vars,
    "}",
    "",
  ].join("\n");
}

// ─── Páginas ─────────────────────────────────────────────────────────────────────────────────────

/**
 * Las cuatro páginas (spec 026, plan §2.1): cabecera (logotipo y «Descargar»), selector de idioma, «← Volver al
 * inicio» (salvo en la de error), el título, las mitades y el pie de la landing. Lo que existe en los dos idiomas va
 * marcado con `data-l="es|en"` (y su `lang`) y los separadores con `data-l="sep"`: sin JavaScript se ve todo.
 */
function shell({ titleEs, titleEn, h1, back, main, chrome }) {
  // El programa de idioma, clásico y síncrono tras las hojas de estilo: marca <html> antes del primer pintado
  // (CA-026-08, plan §1.2).
  return `<!doctype html>
<html lang="es" data-title-es="${esc(titleEs)}" data-title-en="${esc(titleEn)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${esc(`${titleEs} / ${titleEn}`)}</title>
<link rel="stylesheet" href="/tokens.css">
<link rel="stylesheet" href="/site.css">
<script src="${LANG_SCRIPT}"></script>
</head>
<body>
${chrome.header}
<main>
${chrome.langs}
${back ? `${chrome.back}\n` : ""}<h1>${h1}</h1>
${main}
</main>
${chrome.footer}
</body>
</html>
`;
}

function loadSite(paths) {
  const identity = readIdentity(readText(paths.identity, "identity.yaml"), basename(paths.identity));
  const strings = loadStrings(readText(paths.strings, "strings.json"), basename(paths.strings));
  const tokens = JSON.parse(readText(paths.tokens, "tokens.json"));
  // La cabecera y el pie (spec 026): se leen ya aquí para que un texto que falta haga fallar la construcción.
  const landing = loadLandingStrings(paths, identity.displayName);
  const arb = {};
  for (const [lang, path] of [["es", paths.arbEs], ["en", paths.arbEn]]) {
    const json = JSON.parse(readText(path, `app_${lang}.arb`));
    arb[lang] = {};
    for (const [key, name] of [["privacy", "settingsPrivacy"], ["licenses", "settingsThirdPartyLicenses"], ["help", "settingsHelp"]]) {
      if (typeof json[name] !== "string") throw new BuildError(`app_${lang}.arb: falta «${name}»`);
      arb[lang][key] = json[name];
    }
  }
  return { identity, strings, landing, tokens, arb };
}

/** El archivo de avisos tal como se publica (CA-023-16). */
export const NOTICES_FILE = "third-party-notices.txt";

/** Un texto en los dos idiomas: cada parte con su `lang` y su `data-l`, y el separador con `data-l="sep"`. */
function bilingual(es, en, sep = " / ") {
  return `<span lang="es" data-l="es">${esc(es)}</span><span data-l="sep">${esc(sep)}</span><span lang="en" data-l="en">${esc(en)}</span>`;
}

/** El título de la página en los dos idiomas («Privacidad · Privacy»). */
const bilingualH1 = (es, en) => bilingual(es, en, " · ");

/** Un nombre accesible en los dos idiomas, sin separador (oculto a la vista o dentro de un `.vh`). */
function bilingualName(es, en, cls = "") {
  const c = cls ? ` class="${cls}"` : "";
  return `<span${c} lang="es" data-l="es">${esc(es)}</span><span${c} lang="en" data-l="en">${esc(en)}</span>`;
}

/**
 * Un `<pre>` con [text] tal cual en el DOM: el HTML se salta un salto de línea justo tras `<pre>`, así que un texto
 * que empieza por uno lleva otro delante (CA-027-02 b). [attrs] van en la etiqueta.
 */
const preOf = (text, attrs = 'lang="en"') => `<pre ${attrs}>${text.startsWith("\n") ? "\n" : ""}${esc(text)}</pre>`;

/**
 * El bloque de avisos de terceros agrupado por cabecera (spec 027, plan §1.2): la región con su `<h2 id="notices">`,
 * el preámbulo tal cual y sin plegar (CA-027-03), el enlace de saltar la lista, un `<details>` plegado por cabecera
 * y por sección `assets/…` (nombre con «, », recuento en los dos idiomas con los paréntesis fuera; un `<pre>` por
 * aviso, CA-027-01 y 02) y, tras el último, el destino del salto: el enlace al archivo de texto (CA-027-06).
 */
function noticesSectionHtml(parsed, s) {
  const count = (n) => {
    const key = n === 1 ? "webNoticesCountOne" : "webNoticesCountMany";
    return bilingual(fill(s.es[key], { n: String(n) }), fill(s.en[key], { n: String(n) }));
  };
  const group = (names, texts) =>
    [
      `<details class="group"><summary><span class="group__name">${esc(names.join(", "))}</span> <span class="group__count">(${count(texts.length)})</span></summary>`,
      ...texts.map((text) => preOf(text)),
      "</details>",
    ].join("\n");
  const blockLink = (attrs, key) => `<a ${attrs} class="block-link"><span>${bilingual(s.es[key], s.en[key])}</span></a>`;
  return [
    '<section lang="en" aria-labelledby="notices">',
    `<h2 id="notices">${esc(s.en.webNoticesTitle)}</h2>`,
    preOf(parsed.preamble, 'lang="en" class="notices__preamble"'),
    `<p>${blockLink('href="#notices-end"', "webNoticesSkip")}</p>`,
    ...parsed.groups.map((g) => group(g.names, g.notices)),
    ...parsed.sections.map((sec) => group([sec.path], [sec.text])),
    `<p class="notices__end">${blockLink(`id="notices-end" href="/${NOTICES_FILE}"`, "webLicensesFile")}</p>`,
    "</section>",
  ].join("\n");
}

/** Cada mitad de la página (plan §2.1): la oculta el programa cuando se elige el otro idioma. */
function section(lang, body) {
  return `<section class="half" lang="${lang}" data-l="${lang}" aria-labelledby="${lang}">\n${body}\n</section>`;
}

/** El atributo del `<h2>` con que empieza cada mitad (destino de `#es` y `#en`). */
const HALF_TITLE_ATTRS = (lang) => `id="${lang}" tabindex="-1" class="half__title"`;

const langHeading = (lang, s) => `<h2 ${HALF_TITLE_ATTRS(lang)}>${esc(s[lang].webLanguageName)}</h2>`;

/** El trazo de la flecha de «Descargar»: el `arrowDown` de la landing (`home/src/shared/icons.js`). */
export const DOWNLOAD_ICON_PATH = "M12 4v15M6 13l6 6 6-6";

/** El ancla de la escena de cierre de la landing, la de las tiendas (CA-026-16). */
export const DOWNLOAD_HREF = "/#fin";

/** Los enlaces del pie, en este orden (CA-026-01), y la página de cada uno. */
export const FOOTER_LINKS = [
  ["help", "/help", "help/index.html"],
  ["privacy", "/privacy", "privacy/index.html"],
  ["licenses", "/licenses", "licenses/index.html"],
];

/**
 * Las piezas comunes de una página (plan §2.1) para [file]: la cabecera, el selector, «← Volver al inicio» y
 * el pie, con el enlace de [file] marcado como página actual.
 */
function chrome(file, { identity, strings: s, landing: l }) {
  const header = [
    '<header class="top">',
    `<a class="logo" href="/"><span aria-hidden="true">${esc(identity.wordmark)}</span>${bilingualName(l.es.nav.home, l.en.nav.home, "vh")}</a>`,
    `<a class="btn" href="${DOWNLOAD_HREF}"><svg class="ic" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="${DOWNLOAD_ICON_PATH}"/></svg><span class="btn__label">${bilingual(l.es.nav.download, l.en.nav.download)}</span></a>`,
    "</header>",
  ].join("\n");
  const option = (lang) =>
    `<a href="#${lang}" hreflang="${lang}" lang="${lang}"><span>${lang.toUpperCase()}</span><span class="vh">, ${esc(s[lang].webLanguageName)}</span></a>`;
  const langs = [
    '<div class="langs" role="group" aria-labelledby="langs-name">',
    `<span id="langs-name" class="vh">${bilingualName(l.es.nav.lang, l.en.nav.lang, "vh")}</span>`,
    option("es"),
    option("en"),
    "</div>",
  ].join("\n");
  const back = `<p><a class="back" href="/"><span aria-hidden="true">← </span>${bilingual(s.es.webBackHome, s.en.webBackHome)}</a></p>`;
  const legal =
    l.es.footer.legal === l.en.footer.legal
      ? `<p>${esc(l.es.footer.legal)}</p>`
      : `<p lang="es" data-l="es">${esc(l.es.footer.legal)}</p>\n<p lang="en" data-l="en">${esc(l.en.footer.legal)}</p>`;
  const links = FOOTER_LINKS.map(
    ([key, href, page]) => `<a href="${href}"${page === file ? ' aria-current="page"' : ""}>${bilingual(l.es.footer[key], l.en.footer[key])}</a>`,
  );
  const footer = [
    '<footer class="end">',
    legal,
    '<nav aria-labelledby="footer-nav">',
    `<span id="footer-nav" class="vh">${bilingualName(l.es.footer.nav, l.en.footer.nav, "vh")}</span>`,
    ...links,
    "</nav>",
    `<p lang="es" data-l="es">${esc(s.es.webContact)}</p>`,
    `<p lang="en" data-l="en">${esc(s.en.webContact)}</p>`,
    "</footer>",
  ].join("\n");
  return { header, langs, back, footer };
}

/** El título de la pestaña en cada idioma (`webPageTitle`). */
function pageTitles(s, name, es, en) {
  return {
    titleEs: fill(s.es.webPageTitle, { página: es, appName: name }),
    titleEn: fill(s.en.webPageTitle, { page: en, appName: name }),
  };
}

/**
 * Todas las páginas en memoria: `files` (ruta de salida → contenido) y `meta` (de cada página, el
 * `<title>`, los títulos de cada idioma y el `<h1>` que le tocan según las ARB, la identidad y `strings.json`).
 */
export function renderSite(paths, { parseBody = parseNoticesBody } = {}) {
  const site = loadSite(paths);
  const { identity, strings: s, tokens, arb } = site;
  const name = identity.displayName;
  const files = new Map();
  const meta = new Map();
  const page = (file, spec) => {
    const title = `${spec.titleEs} / ${spec.titleEn}`;
    meta.set(file, { title, titleEs: spec.titleEs, titleEn: spec.titleEn, h1: spec.h1 });
    files.set(file, shell({ ...spec, chrome: chrome(file, site) }));
  };

  // La página de inicio ya no sale de aquí: la construye Vite desde `landing/home/` (spec 025, `buildHome`).

  // Política: el texto es el de docs/legal/privacy-policy.md (CA-023-04).
  const policy = policyFragments(readText(paths.policy, "privacy-policy.md"), name, s);
  page("privacy/index.html", {
    ...pageTitles(s, name, arb.es.privacy, arb.en.privacy),
    h1: bilingualH1(arb.es.privacy, arb.en.privacy),
    back: true,
    main: `${section("es", policy.es.html)}\n${section("en", policy.en.html)}`,
  });

  // Error (CL-023-6, CA-026-05): sin «← Volver al inicio» encima del título; cada mitad lleva el suyo.
  const notFound = (lang) =>
    `${langHeading(lang, s)}\n<p>${esc(s[lang].webNotFoundBody)}</p>\n<p><a class="block-link" href="/">${esc(s[lang].webBackHome)}</a></p>`;
  page("404.html", {
    ...pageTitles(s, name, s.es.webNotFoundTitle, s.en.webNotFoundTitle),
    h1: bilingualH1(s.es.webNotFoundTitle, s.en.webNotFoundTitle),
    back: false,
    main: `${section("es", notFound("es"))}\n${section("en", notFound("en"))}`,
  });

  // Licencias de terceros (CA-023-16): la versión (o la última compilación) y el archivo de avisos,
  // que se publica una sola vez, en inglés, después de las dos mitades.
  const noticesText = readText(paths.notices, "third-party-notices.txt");
  checkNoticesText(noticesText);
  const notices = parseNotices(noticesText);
  // Spec 027 (CA-027-05): la estructura del cuerpo, que se reconoce entero o la construcción falla, y la ida y
  // vuelta: el HTML de los grupos sale solo de lo que reconstruye el archivo tal cual (CA-027-02).
  const noticesBody = norm(notices.body);
  const groupedNotices = parseBody(noticesBody, { firstLine: 3 });
  assertNoticesRoundTrip(noticesBody, groupedNotices);
  const versionLine = (lang) =>
    notices.kind === "version"
      ? fill(s[lang].webLicensesVersion, { [lang === "es" ? "versión" : "version"]: notices.version })
      : s[lang].webLicensesLatestBuild;
  const licensesBody = (lang) =>
    [
      langHeading(lang, s),
      `<p class="meta">${esc(versionLine(lang))}</p>`,
      `<p>${esc(s[lang].webLicensesInApp)}</p>`,
      `<p><a class="block-link" href="/${NOTICES_FILE}">${esc(s[lang].webLicensesFile)}</a></p>`,
    ].join("\n");
  // El código de la propia web (spec 025, CA-025-18): corto, antes de los avisos de la app, con el título en los
  // dos idiomas y el texto en inglés.
  const webNotices = parseWebNotices(readText(paths.webNotices, "web-notices.txt"));
  const webSection = `<section aria-labelledby="web-code">\n<h2 id="web-code">${bilingualH1(s.es.licensesWebTitle, s.en.licensesWebTitle)}</h2>\n<pre lang="en">${esc(webNotices.body)}</pre>\n</section>`;
  const noticesSection = noticesSectionHtml(groupedNotices, s);
  page("licenses/index.html", {
    ...pageTitles(s, name, arb.es.licenses, arb.en.licenses),
    h1: bilingualH1(arb.es.licenses, arb.en.licenses),
    back: true,
    main: `${section("es", licensesBody("es"))}\n${section("en", licensesBody("en"))}\n${webSection}\n${noticesSection}`,
  });
  files.set(NOTICES_FILE, noticesText);

  // Ayuda (CA-023-17): los textos de landing/src/help.{es,en}.md.
  const help = {
    es: helpFragment(readText(paths.helpEs, "help.es.md"), name, "es", "help.es.md", s),
    en: helpFragment(readText(paths.helpEn, "help.en.md"), name, "en", "help.en.md", s),
  };
  page("help/index.html", {
    ...pageTitles(s, name, arb.es.help, arb.en.help),
    h1: bilingualH1(arb.es.help, arb.en.help),
    back: true,
    main: `${section("es", help.es.html)}\n${section("en", help.en.html)}`,
  });

  files.set("tokens.css", tokensCss(tokens));
  files.set("site.css", readText(paths.siteCss, "site.css"));
  // El programa de idioma, tal cual: sin empaquetar ni minificar (ADR-0028, CA-026-15).
  files.set(LANG_FILE, readText(paths.langJs, "lang.js"));
  return { files, meta };
}

/** Los huecos de identidad que quedan en lo que se publica, por archivo. */
function findGaps(files) {
  const found = [];
  for (const [file, content] of files) {
    if (!file.endsWith(".html")) continue;
    // El bloque de avisos de terceros no es de la identidad: una licencia puede llevar «[DATE]».
    const text = content.replace(/<pre\b[^>]*>[\s\S]*?<\/pre>/g, " ").replace(/<[^>]*>/g, " ");
    const kinds = new Set(text.match(gapPattern()) ?? []);
    for (const g of kinds) found.push({ file, gap: g });
  }
  return found;
}

/**
 * Construye la web en `paths.out`. Con `VERCEL_ENV=production` un hueco de identidad hace fallar la
 * construcción (así la integración Git de Vercel no puede publicar una web a medias); en cualquier
 * otro entorno es un aviso. Devuelve los avisos.
 */
export function build(paths = defaultPaths(), { env = process.env } = {}) {
  if (basename(paths.out) !== "dist") {
    throw new BuildError(`la carpeta de salida tiene que llamarse «dist» (es «${paths.out}»): no se borra otra`);
  }
  const { files } = renderSite(paths);
  const gaps = findGaps(files);
  const warnings = gaps.map((g) => `aviso: hueco de identidad ${g.gap} en ${g.file} (se rellena en F6)`);
  if (env.VERCEL_ENV === "production" && gaps.length > 0) {
    throw new BuildError(
      `no se publica con huecos de identidad (VERCEL_ENV=production): ${gaps.map((g) => `${g.gap} en ${g.file}`).join("; ")}`,
    );
  }

  // Las fuentes, con su licencia, dentro de la web (CA-023-14).
  const copies = [];
  for (const dir of FONT_DIRS) {
    const names = [...FONT_FILES.filter((f) => f.dir === dir).map((f) => f.file), "OFL.txt"];
    for (const file of names) {
      const from = join(paths.fontsDir, dir, file);
      if (!existsSync(from)) throw new BuildError(`falta la fuente ${from}`);
      copies.push([from, join(paths.out, "fonts", dir, file)]);
    }
  }

  rmSync(paths.out, { recursive: true, force: true });
  for (const [file, content] of files) {
    const target = join(paths.out, file);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
  for (const [from, to] of copies) {
    mkdirSync(dirname(to), { recursive: true });
    cpSync(from, to);
  }
  return { warnings, files: [...files.keys(), ...copies.map(([, to]) => to.slice(paths.out.length + 1))] };
}

// ─── La página de inicio (spec 025) ──────────────────────────────────────────────────────────────

/** La carpeta de lo generado para Vite (fuera de git): `landing/home/gen/`. */
export const homeGenDir = (paths) => join(paths.homeDir, "gen");

/**
 * Las direcciones de las fichas de las tiendas (spec 025, CA-025-08; plan §6.1), de `identity.yaml`: las dos
 * claves tienen que estar; vacía (`""`) quiere decir «sin ficha todavía» (`null`). Si no está vacía, tiene que
 * ser `https://` con el anfitrión exacto de su tienda, sin usuario, contraseña ni puerto, y sin caracteres que
 * no van en una dirección; lo demás falla. Se mira el texto crudo, no solo lo que normaliza `URL` (que
 * decodifica `%` en el anfitrión y quita `:443`).
 */
export const STORE_HOSTS = { appStoreUrl: "apps.apple.com", googlePlayUrl: "play.google.com" };

export function storeUrls(identity, label = "identity.yaml") {
  const out = {};
  for (const [key, host] of Object.entries(STORE_HOSTS)) {
    const value = identity[key];
    if (typeof value !== "string") throw new BuildError(`${label}: falta «${key}» (vacía, "", hasta que haya ficha)`);
    if (value === "") {
      out[key] = null;
      continue;
    }
    const bad = (why) => new BuildError(`${label}: «${key}» no es una dirección de ficha de ${host} (${why}): «${value}»`);
    if (/[\s"'<>`\\{}|^\u0000-\u001f\u007f-\uffff]/.test(value)) throw bad("caracteres no válidos");
    const raw = /^https:\/\/([^/?#]*)(?:[/?#]|$)/.exec(value);
    if (!raw) throw bad("tiene que empezar por https://");
    if (raw[1] !== host) throw bad(`el anfitrión tiene que ser exactamente ${host}, sin usuario ni puerto`);
    let url;
    try {
      url = new URL(value);
    } catch {
      throw bad("no se puede leer");
    }
    if (url.protocol !== "https:" || url.hostname !== host || url.port !== "" || url.username !== "" || url.password !== "") {
      throw bad(`el anfitrión tiene que ser exactamente ${host}, sin usuario ni puerto`);
    }
    out[key] = value;
  }
  return out;
}

/**
 * `gen/site.json`, lo que la página de inicio toma de la identidad (`identity.yaml`): el nombre, el logotipo y
 * las direcciones de las tiendas (`null` sin ficha).
 */
export function homeSite(paths) {
  const identity = readIdentity(readText(paths.identity, "identity.yaml"), basename(paths.identity));
  return {
    appName: identity.displayName,
    wordmark: identity.wordmark,
    stores: storeUrls(identity, basename(paths.identity)),
  };
}

/** Escribe `landing/home/gen/site.json` (lo único que Vite necesita generado). Devuelve la lista de archivos. */
export function writeHomeGen(paths = defaultPaths()) {
  const gen = homeGenDir(paths);
  rmSync(gen, { recursive: true, force: true });
  mkdirSync(gen, { recursive: true });
  writeFileSync(join(gen, "site.json"), `${JSON.stringify(homeSite(paths), null, 2)}\n`);
  return ["site.json"];
}

/**
 * Construye la página de inicio con Vite (por su API) dentro de `paths.out`, después de `build`, que ya vació
 * la carpeta y escribió las otras cuatro páginas. La configuración es la de `landing/home/vite.config.mjs`,
 * que escribe en `landing/home/../dist`: tiene que ser `paths.out`.
 */
export async function buildHome(paths = defaultPaths()) {
  if (resolve(paths.homeDir, "..", "dist") !== resolve(paths.out)) {
    throw new BuildError(`la página de inicio se construye en ${resolve(paths.homeDir, "..", "dist")}, no en ${paths.out}`);
  }
  writeHomeGen(paths);
  let vite;
  try {
    vite = await import("vite");
  } catch (e) {
    throw new BuildError(`no se puede cargar Vite (¿falta «npm ci --ignore-scripts» en landing/?): ${e.message}`);
  }
  const config = (await import(pathToFileURL(join(paths.homeDir, "vite.config.mjs")).href)).default;
  await vite.build({ ...config, configFile: false });
  const index = join(paths.out, "index.html");
  writeFileSync(index, await fillHomePage(readFileSync(index, "utf8"), paths));
}

/** La marca de `landing/home/index.html` donde va la página entera. */
export const HOME_PAGE_MARK = "<!-- page -->";

/**
 * Escribe en el `index.html` que deja Vite la página entera en el idioma por defecto (cabecera, las siete
 * escenas y el pie) y su idioma, título y descripción, con los mismos constructores que usa el programa
 * (`landing/home/src/a/page.js`): sin JavaScript se ve la versión apilada; con él, el programa la anima.
 * Necesita `gen/site.json` (`writeHomeGen`).
 */
export async function fillHomePage(html, paths = defaultPaths()) {
  const from = (...path) => import(pathToFileURL(join(paths.homeDir, "src", ...path)).href);
  const page = await from("a", "page.js");
  // El escape de la página de inicio, el mismo que usan sus constructores.
  const { esc } = await from("shared", "html.js");
  const meta = page.pageMeta();
  const once = (text, pattern, replacement, what) => {
    let n = 0;
    const out = text.replace(pattern, () => {
      n += 1;
      return replacement;
    });
    if (n !== 1) throw new BuildError(`landing/home/index.html: tiene que haber un(a) ${what} y hay ${n}`);
    return out;
  };
  let out = once(html, /<html lang="[^"]*">/g, `<html lang="${esc(meta.lang)}">`, '<html lang="…">');
  out = once(out, /<title>[^<]*<\/title>/g, `<title>${esc(meta.title)}</title>`, "<title>");
  out = once(out, /<meta name="description" content="[^"]*">/g, `<meta name="description" content="${esc(meta.description)}">`, '<meta name="description">');
  return once(out, new RegExp(HOME_PAGE_MARK, "g"), page.pageHtml(), `marca ${HOME_PAGE_MARK}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const { warnings, files } = build();
    for (const w of warnings) console.warn(w);
    await buildHome();
    console.log(`Web construida en landing/dist (${files.length} archivos y la página de inicio).`);
  } catch (e) {
    if (!(e instanceof BuildError)) throw e;
    console.error(`error: ${e.message}`);
    process.exit(1);
  }
}
